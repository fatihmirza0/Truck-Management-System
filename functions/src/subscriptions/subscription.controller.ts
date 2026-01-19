import * as admin from 'firebase-admin';
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { CORS_WHITELIST } from "../config/cors.config";
import { PaymentFactory } from '../payment/PaymentFactory';
import { UserDetails } from '../payment/PaymentGateway';

// Define Secrets for Secret Manager
const IYZICO_API_KEY = defineSecret("IYZICO_API_KEY");
const IYZICO_SECRET_KEY = defineSecret("IYZICO_SECRET_KEY");
const PADDLE_API_KEY = defineSecret("PADDLE_API_KEY");
const PADDLE_AUTH_TOKEN = defineSecret("PADDLE_AUTH_TOKEN");

/**
 * Create a new subscription checkout URL using the appropriate gateway.
 * Enforces App Check for Web security.
 */
export const createSubscription = onCall({
    cors: CORS_WHITELIST,
    maxInstances: 10,
    enforceAppCheck: true, // 🛡️ App Check Enforcement
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY, PADDLE_API_KEY, PADDLE_AUTH_TOKEN] // 🔑 Secret Manager Injection
}, async (request) => {
    // 1. Auth Check - onCall'da otomatik gelir
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be logged in');
    }

    const uid = request.auth.uid;
    const { planId, country = 'US' } = request.data;

    if (!planId) {
        throw new HttpsError('invalid-argument', 'Plan ID is required');
    }

    try {
        // 2. Get User Details from Firestore
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        const userData = userDoc.data();

        if (!userData) {
            throw new HttpsError('not-found', 'User profile not found');
        }

        const userDetails: UserDetails = {
            uid,
            email: userData.email,
            name: userData.name || 'Unknown',
            country: country,
            phone: userData.phone,
            identityNumber: userData.identityNumber
        };

        // 3. Select Provider with Secrets
        const gateway = PaymentFactory.getProvider(country, {
            iyzico: {
                apiKey: IYZICO_API_KEY.value(),
                secretKey: IYZICO_SECRET_KEY.value(),
                uri: process.env.IYZICO_URI
            },
            paddle: {
                apiKey: PADDLE_API_KEY.value(),
                environment: process.env.PADDLE_ENV
            }
        });

        // 4. Create Subscription Init
        const result = await gateway.createSubscription(planId, userDetails);

        return result;

    } catch (error: any) {
        // Detailed logging for debugging
        console.error("--- Create Subscription Detailed Error ---");
        console.error("Error Name:", error.name);
        console.error("Error Message:", error.message);
        console.error("Error Stack:", error.stack);
        if (error.response) {
            console.error("API Response Data:", JSON.stringify(error.response.data));
            console.error("API Response Status:", error.response.status);
        }
        console.error("-------------------------------------------");

        throw new HttpsError('internal', error.message || 'Subscription creation failed');
    }
});

/**
 * Scheduled task to sync exchange rates.
 */
export const syncExchangeRates = onSchedule("every 24 hours", async (event) => {
    const { CurrencyService } = await import('../services/CurrencyService');
    await CurrencyService.syncRates();
});
