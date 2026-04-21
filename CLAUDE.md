# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Wordwonk

A multiplayer word game platform. Players connect via WebSocket and compete to form words from shared letter tiles. Supports English, Spanish, French, German, and Russian.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, Vite 5, i18next, Framer Motion, Nginx |
| Backend | Perl 5.36+, Mojolicious 9.31, DBIx::Class, Moose |
| Word Validation | Rust (2021 edition), Actix-web 4, Tokio |
| Database | PostgreSQL 16 |
| Orchestration | Kubernetes (Kind for local), Helm 3 |
| Auth | OAuth2 (Google, Discord), WebAuthn/Passkeys |

## Common Commands

### Backend (Perl/Mojolicious) — `srv/backend/`
```bash
make deps        # Install CPAN deps via cpanm
make test        # Run tests: prove -lr t/
make run         # Dev server via morbo
make migrate     # Run pending DB migrations
```

### Frontend (React/Vite) — `srv/frontend/`
```bash
npm run dev      # Dev server on :3000, proxies /auth /ws /players to :8080
npm run build    # Production build
```

### Root-level (Kubernetes/Helm)
```bash
make build       # Build and push all Docker images (frontend, backend, wordd, ollama)
make deploy      # Install/upgrade Helm umbrella chart
make <service>   # Build, push, and restart a single service (e.g. make backend)
make migrate     # Run DB migrations inside the cluster
make backup      # Create timestamped SQL backup
make lexicons    # Regenerate word lexicons from Hunspell dictionaries
```

## Architecture

### Three Services

**Backend** (`srv/backend/`) is the core. A Mojolicious app that owns authentication, game logic, WebSocket connections, and the database. Key namespaces:
- `Wordwonk::Game::*` — game lifecycle (`Manager`), scoring (`StateProcessor`), real-time fan-out (`Broadcaster`)
- `Wordwonk::Web::*` — route handlers for auth (`Auth`), WebSocket (`Game`), leaderboard (`Stats`)
- `Wordwonk::Service::Wordd` — HTTP client that talks to the Rust word service

**Wordd** (`srv/wordd/`) is a Rust/Actix-web service for high-performance word validation. It loads pre-compiled Hunspell lexicons at startup. Endpoints: `/check/{lang}/{word}`, `/validate/{lang}/{word}`, `/rand/*` (random tiles/words). The backend calls it synchronously via HTTP.

**Frontend** (`srv/frontend/`) is a React SPA. All game state flows through a single WebSocket (`/ws`). Key hooks:
- `usePlayerAuth` — identity and session
- `useGameState` / `useGameSocket` — WebSocket lifecycle and incoming message parsing
- `useGameController` — dispatches player actions (join, play, chat)

### WebSocket Protocol

The client connects to `/ws`, sends its UUID (or generates a random one), and receives an `identity` message with server config (tile set, tile values, supported languages). From there all game events are JSON messages over the same socket. `Wordwonk::Game::Broadcaster` fans messages out to all clients in a game.

### Database Migrations

Migrations live in `srv/backend/schema/migrations/` as numbered SQL files (`001_...sql`). The `bin/migrate.pl` script applies unapplied ones and records the version in the `schema_migrations` table. The backend runs migrations automatically on startup.

### Lexicons

Word lexicons are pre-compiled from Hunspell dictionaries via `make lexicons` and stored in `srv/wordd/share/words/{lang}/lexicon.txt`. These are baked into the wordd Docker image.

## Configuration

- **Backend config**: `srv/backend/wordwonk.yml` (Mojolicious YAML config)
- **Helm values**: `helm/values.yaml` — game tuning (maxPlayers, gameDuration), feature flags (Ko-fi, PayPal)
- **Helm secrets**: `helm/secrets.yaml` — OAuth client secrets, Discord webhooks, DB credentials
- **Vite dev proxy**: `srv/frontend/vite.config.js` forwards `/auth`, `/ws`, `/players` to `:8080`

## Integration Tests

See `srv/backend/t/integration/README.md` for setup. Integration tests require a live database and are separate from unit tests (`prove -lr t/`).
