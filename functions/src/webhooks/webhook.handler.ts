import { onRequest } from "firebase-functions/v2/https";
import * as admin from 'firebase-admin';
import { PaymentFactory } from '../payment/PaymentFactory';
import { InvoiceGenerator } from '../invoicing/InvoiceGenerator';

export const webhookHandler = onRequest(async (req, res) => {
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
    } else if (req.headers['paddle-signature']) {
        providerName = 'paddle';
        countryCode = 'US';
    } else {
        // Fallback or unknown
        console.warn("Unknown webhook provider", req.headers);
        res.status(400).send('Unknown Provider');
        return;
    }

    const gateway = PaymentFactory.getProvider(countryCode);

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
            userId = event.custom_data?.uid;
            // planId extraction...
        } else {
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
                await InvoiceGenerator.generateInvoice({
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

    } catch (e) {
        console.error("Webhook processing failed", e);
        res.status(500).send('Internal Server Error');
    }
});
