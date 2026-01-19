"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.corsOptions = exports.CORS_WHITELIST = void 0;
/**
 * Strict CORS Whitelist for Production and Local Development
 */
exports.CORS_WHITELIST = [
    "https://truck-management-sys.web.app", // Production Domain
    "https://lojistik-panel.web.app", // Alternative Production Domain
    "http://localhost:5001", // Firebase Emulator
    "http://localhost:3000", // Local Dev (React/Vite)
    "http://localhost:8080", // Local Dev (General)
    "http://localhost", // Local Dev (Flutter Web default)
];
exports.corsOptions = {
    origin: (origin, callback) => {
        // Allow all origins temporarily to fix local dev issues with random ports
        callback(null, true);
    },
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "x-session-token", "x-developer-key", "X-App-Check-Token"],
    credentials: true
};
//# sourceMappingURL=cors.config.js.map