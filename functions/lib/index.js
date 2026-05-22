"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateSmartRoute = exports.saveMarketingContentHttp = exports.getEstimatedJobCosts = exports.getPublicJobStatus = exports.webhookHandler = exports.syncExchangeRates = exports.createSubscription = void 0;
const admin = __importStar(require("firebase-admin"));
const v2_1 = require("firebase-functions/v2");
// Initialize Firebase Admin before anything else
if (!admin.apps.length) {
    admin.initializeApp();
}
// Global Options for v2 functions
(0, v2_1.setGlobalOptions)({
    maxInstances: 10,
    region: 'us-central1'
});
// Export subscription functions
var subscription_controller_1 = require("./subscriptions/subscription.controller");
Object.defineProperty(exports, "createSubscription", { enumerable: true, get: function () { return subscription_controller_1.createSubscription; } });
Object.defineProperty(exports, "syncExchangeRates", { enumerable: true, get: function () { return subscription_controller_1.syncExchangeRates; } });
var webhook_handler_1 = require("./webhooks/webhook.handler");
Object.defineProperty(exports, "webhookHandler", { enumerable: true, get: function () { return webhook_handler_1.webhookHandler; } });
var general_1 = require("./legacy/general");
Object.defineProperty(exports, "getPublicJobStatus", { enumerable: true, get: function () { return general_1.getPublicJobStatus; } });
var general_2 = require("./legacy/general");
Object.defineProperty(exports, "getEstimatedJobCosts", { enumerable: true, get: function () { return general_2.getEstimatedJobCosts; } });
// Legacy exports (restored)
__exportStar(require("./legacy/general"), exports);
__exportStar(require("./legacy/developer"), exports);
var developer_1 = require("./legacy/developer");
Object.defineProperty(exports, "saveMarketingContentHttp", { enumerable: true, get: function () { return developer_1.saveMarketingContentHttp; } });
// Export integration functions
__exportStar(require("./integrations/integration.controller"), exports);
// Export routing functions
var calculateSmartRoute_1 = require("./routes/calculateSmartRoute");
Object.defineProperty(exports, "calculateSmartRoute", { enumerable: true, get: function () { return calculateSmartRoute_1.calculateSmartRoute; } });
//# sourceMappingURL=index.js.map