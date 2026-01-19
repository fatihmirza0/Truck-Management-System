import { PaymentGateway, UserDetails, SubscriptionResult } from './PaymentGateway';
import Iyzipay = require('iyzipay');


export class IyzicoProvider implements PaymentGateway {
    // @ts-ignore
    private iyzipay: any;

    constructor(config?: { apiKey: string, secretKey: string, uri?: string }) {
        this.iyzipay = new Iyzipay({
            apiKey: config?.apiKey || process.env.IYZICO_API_KEY || 'sandbox-api-key',
            secretKey: config?.secretKey || process.env.IYZICO_SECRET_KEY || 'sandbox-secret-key',
            uri: config?.uri || process.env.IYZICO_URI || 'https://sandbox-api.iyzipay.com'
        });
    }

    async createSubscription(planId: string, user: UserDetails): Promise<SubscriptionResult> {
        // Iyzico Subscription API logic
        // Note: Iyzico primarily uses 'CheckoutForm' for initial payments or 'Subscription' API tailored for plans.
        // For this implementation, we assume we are generating a Checkout Form for the initial subscription payment
        // or using their Reference Code logic if available for Recurring.

        // STARTING LOGIC: Generate Checkout Form for initial payment + card storage
        // Detailed implementation to follow in next steps based on specific Iyzico Subscription API docs usage.

        // Placeholder return for factory pattern setup
        // In real implementation, this would be:
        /*
        const request = {
            // ... other params
            callbackUrl: 'https://logipro-callback.web.app/sub/callback', // Function that redirects to success/fail
            // OR directly:
            // callbackUrl: 'https://logipro-callback.web.app/success' // if Iyzico supports direct static redirect
        };
        */
        return {
            status: 'pending',
            checkoutUrl: 'https://sandbox-api.iyzipay.com/payment-page/placeholder?successUrl=https://logipro-callback.web.app/success&failUrl=https://logipro-callback.web.app/fail'
        };
    }

    async cancelSubscription(subscriptionId: string): Promise<void> {
        // Iyzico cancel logic
    }

    verifyWebhook(headers: any, body: any): boolean {
        // Implement Iyzico signature verification
        // Usually header: x-iyzico-checksum or similar
        return true; // TODO: Implement actual verification
    }
}
