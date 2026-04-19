export const CONFIG = {
    // Donation Settings
    PAYPAL_EMAIL: window.WORDWONK_CONFIG?.PAYPAL_EMAIL || import.meta.env.VITE_PAYPAL_EMAIL || 'quinnfazigu@gmail.com',

    // Feature Toggles
    KOFI_ID: window.WORDWONK_CONFIG?.KOFI_ID || import.meta.env.VITE_KOFI_ID || 'wordwonk',
    KOFI_ENABLED: window.WORDWONK_CONFIG?.KOFI_ENABLED !== undefined ? window.WORDWONK_CONFIG.KOFI_ENABLED : (import.meta.env.VITE_KOFI_ENABLED !== 'false'),
    PAYPAL_ENABLED: window.WORDWONK_CONFIG?.PAYPAL_ENABLED !== undefined ? window.WORDWONK_CONFIG.PAYPAL_ENABLED : (import.meta.env.VITE_PAYPAL_ENABLED !== 'false'),

    // Runtime Configuration
    LOG_LEVEL: window.WORDWONK_CONFIG?.LOG_LEVEL || import.meta.env.VITE_LOG_LEVEL || 'info',
    PROJECT_CODE_LINK: window.WORDWONK_CONFIG?.PROJECT_CODE_LINK || import.meta.env.VITE_PROJECT_CODE_LINK || 'https://github.com/ronstr8/wordwonk',
};

export default CONFIG;
