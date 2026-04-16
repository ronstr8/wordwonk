mod models;
mod utils;
mod services;
mod handlers;

use actix_web::{web, App, HttpServer};
use std::collections::HashMap;
use clap::{Command, Arg};
use log::info;
use std::fs::OpenOptions;

use models::AppState;
use services::{word_loader, distribution, letter_classifier};

// Function to initialize logging
fn init_logging(log_file: Option<&String>) {
    if let Some(file) = log_file {
        let log_output = OpenOptions::new()
            .create(true)
            .append(true)
            .open(file)
            .expect("Failed to open log file");

        env_logger::Builder::new()
            .target(env_logger::Target::Pipe(Box::new(log_output)))
            .init();
    } else {
        env_logger::init();
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let matches = Command::new("wordd")
        .version("1.14.0")
        .author("Ron Straight <straightre@gmail.com>")
        .about("Polyglot word validity and lookup service")
        .arg(Arg::new("listen-host").long("listen-host").num_args(1).default_value("0.0.0.0:2345"))
        .arg(Arg::new("log-file").long("log-file").num_args(1))
        .arg(Arg::new("share-dir").long("share-dir").num_args(1).default_value("./share"))
        .arg(Arg::new("langs").long("langs").num_args(1).default_value("en,es,fr"))
        .arg(Arg::new("total-tiles").long("total-tiles").num_args(1).default_value("100"))
        .arg(Arg::new("rack-size").long("rack-size").env("DEFAULT_RANDOM_WORD_LETTER_COUNT").num_args(1).default_value("7"))
        .get_matches();

    let log_file = matches.get_one::<String>("log-file");
    init_logging(log_file);

    let share_dir = matches.get_one::<String>("share-dir").map(|s| s.as_str()).unwrap_or("./share");
    let langs_str = matches.get_one::<String>("langs").map(|s| s.as_str()).unwrap_or("en");
    
    let total_tiles = matches.get_one::<String>("total-tiles")
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(100);
        
    let rack_size = matches.get_one::<String>("rack-size")
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(7);

    let listen_host = matches.get_one::<String>("listen-host")
        .cloned()
        .unwrap_or_else(|| "0.0.0.0:2345".to_string());

    info!("Starting wordd on {} with share-dir: {}", listen_host, share_dir);

    // Bootstrap application state
    let state = bootstrap_state(share_dir, langs_str, total_tiles, rack_size);
    let shared_state = web::Data::new(state);

    HttpServer::new(move || {
        App::new()
            .app_data(shared_state.clone())
            .service(handlers::config::get_langs)
            .service(handlers::config::get_config)
            .service(handlers::validation::check_word_lang)
            .service(handlers::validation::check_word)
            .service(handlers::validation::validate_word_lang)
            .service(handlers::validation::validate_word)
            .service(handlers::random::rand_letter)
            .service(handlers::random::rand_vowel)
            .service(handlers::random::rand_consonant)
            .service(handlers::random::rand_unicorn)
            .service(handlers::random::rand_word)
    })
    .bind(&listen_host)?
    .run()
    .await
}

fn bootstrap_state(share_dir: &str, langs_str: &str, total_tiles: usize, rack_size: usize) -> AppState {
    let mut word_lists = HashMap::new();
    let mut supported_langs = Vec::new();
    let mut tile_bags = HashMap::new();
    let mut vowel_sets = HashMap::new();
    let mut consonant_sets = HashMap::new();
    let mut unicorn_sets = HashMap::new();

    for lang in langs_str.split(',') {
        let lang = lang.trim().to_lowercase();
        if lang.is_empty() { continue; }

        info!("Loading language: {} (rack_size: {})", lang, rack_size);
        let words = word_loader::load_filtered_words(share_dir, &lang, rack_size);
        
        // Calculate distribution and components
        let freq = distribution::calculate_distribution_from_set(&words);
        let bag = distribution::compute_tile_bag(&freq, total_tiles);
        let (vowels, consonants, unicorns) = letter_classifier::classify_letters(&freq, &lang);
        
        // Store pre-computed metrics
        word_lists.insert(lang.clone(), words);
        supported_langs.push(lang.clone());
        tile_bags.insert(lang.clone(), bag);
        vowel_sets.insert(lang.clone(), vowels);
        consonant_sets.insert(lang.clone(), consonants);
        unicorn_sets.insert(lang.clone(), unicorns);
    }

    AppState {
        word_lists,
        supported_langs,
        tile_bags,
        vowel_sets,
        consonant_sets,
        unicorn_sets,
    }
}
