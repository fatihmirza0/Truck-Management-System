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
Object.defineProperty(exports, "__esModule", { value: true });
exports.webhookHandler = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const PaymentFactory_1 = require("../payment/PaymentFactory");
const InvoiceGenerator_1 = require("../invoicing/InvoiceGenerator");
exports.webhookHandler = (0, https_1.onRequest)(async (req, res) => {
    var _a;
    const method = req.method;
    if (method !== 'POST') {
        res.status(405).send('Method Not Allowed');
        return;
    }
    // Determine Provider
    // Strategy: Check headers or path parameter if we use different URLs.
    // For unified URL, we check signature headers.
    let providerName = '';
    let countryCode = 'US'; // Default to Global/Paddle
    if (req.headers['x-iyzico-checksum']) {
        providerName = 'iyzico';
        countryCode = 'TR';
    }
    else if (req.headers['paddle-signature']) {
        providerName = 'paddle';
        countryCode = 'US';
    }
    else {
        // Fallback or unknown
        console.warn("Unknown webhook provider", req.headers);
        res.status(400).send('Unknown Provider');
        return;
    }
    const gateway = PaymentFactory_1.PaymentFactory.getProvider(countryCode);
    // Verify Signature
    if (!gateway.verifyWebhook(req.headers, req.body)) {
        console.error(`Invalid ${providerName} signature`);
        res.status(401).send('Invalid Signature');
        return;
    }
    // Process Event
    try {
        const event = req.body;
        // Normalize event data (Provider specific mapping needed here)
        // This is a simplified mapping logic.
        let eventType = '';
        let userId = '';
        // let planId = ''; // Extract if needed
        if (providerName === 'paddle') {
            eventType = event.event_type; // Paddle v2
            userId = (_a = event.custom_data) === null || _a === void 0 ? void 0 : _a.uid;
            // planId extraction...
        }
        else {
            // Iyzico event mapping
        }
        console.log(`Processing ${providerName} event: ${eventType} for user ${userId}`);
        if (eventType === 'transaction.completed' || eventType === 'subscription.created') {
            // Grant Access
            if (userId) {
                await admin.firestore().collection('subscriptions').doc(userId).set({
                    status: 'active',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    // Add plan details
                }, { merge: true });
                // Generate Invoice
                await InvoiceGenerator_1.InvoiceGenerator.generateInvoice({
                    userId,
                    amount: 100, // TODO: Extract from payload
                    currency: providerName === 'iyzico' ? 'TRY' : 'USD',
                    items: [{ name: 'Subscription', price: 100 }],
                    taxRate: providerName === 'iyzico' ? 20 : 0
                });
            }
        }
        // Handle cancellation, failure etc.
        res.status(200).send('OK');
    }
    catch (e) {
        console.error("Webhook processing failed", e);
        res.status(500).send('Internal Server Error');
    }
});
//# sourceMappingURL=webhook.handler.js.map