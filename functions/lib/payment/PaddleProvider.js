"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaddleProvider = void 0;
const paddle_node_sdk_1 = require("@paddle/paddle-node-sdk");
class PaddleProvider {
    constructor(config) {
        this.paddle = new paddle_node_sdk_1.Paddle((config === null || config === void 0 ? void 0 : config.apiKey) || process.env.PADDLE_API_KEY || 'sandbox-key', {
            environment: ((config === null || config === void 0 ? void 0 : config.environment) || process.env.PADDLE_ENV) === 'production' ? paddle_node_sdk_1.Environment.production : paddle_node_sdk_1.Environment.sandbox
        });
    }
    async createSubscription(planId, user) {
        var _a, _b;
        // Paddle uses Price IDs. We need a map from Internal Plan ID -> Paddle Price ID
        const priceId = this.mapPlanToPaddlePrice(planId);
        // Paddle Transaction API to generate a checkout
        try {
            // Create or get customer first to satisfy SDK strict types
            let customerId;
            try {
                // Check for existing customer by email
                // We await the response. Using 'any' cast to access data if types are restrictive
                const response = await this.paddle.customers.list({ email: [user.email] });
                const customers = response.data || [];
                if (customers.length > 0) {
                    customerId = customers[0].id;
                }
                else {
                    const newCustomer = await this.paddle.customers.create({
                        email: user.email,
                        name: user.name,
                        customData: { uid: user.uid }
                    });
                    customerId = newCustomer.id;
                }
                const transaction = await this.paddle.transactions.create({
                    items: [{ priceId: priceId, quantity: 1 }],
                    customerId: customerId,
                    customData: {
                        uid: user.uid
                    },
                    // Paddle often configures return URL in the Dashboard, but some APIs allow override.
                    // For inline checkout or API generated flows, we might look for return_url params.
                    // This is SDK dependent. Assuming we configure it in Paddle Dashboard to:
                    // https://logipro-callback.web.app/success
                });
                const result = transaction;
                return {
                    status: 'pending',
                    checkoutUrl: ((_b = (_a = result.details) === null || _a === void 0 ? void 0 : _a.checkout) === null || _b === void 0 ? void 0 : _b.url) || result.url || '',
                    externalId: result.id
                };
            }
            catch (err) {
                console.error("Paddle Customer/Transaction Error", err);
                throw err;
            }
        }
        catch (e) {
            console.error("Paddle Create Error", e);
            throw e;
        }
    }
    async cancelSubscription(subscriptionId) {
        await this.paddle.subscriptions.cancel(subscriptionId, {
            effectiveFrom: 'next_billing_period'
        });
    }
    verifyWebhook(headers, body) {
        const signature = headers['paddle-signature'];
        // Use paddle-node-sdk webhook validator
        // return this.paddle.webhooks.unmarshal(body, functions.config().paddle.webhook_secret, signature);
        return !!signature; // TODO: Implement strict check
    }
    mapPlanToPaddlePrice(planId) {
        const map = {
            'starter': 'pri_starter_123',
            'professional': 'pri_pro_456',
            'enterprise': 'pri_ent_789'
        };
        return map[planId] || 'pri_default';
    }
}
exports.PaddleProvider = PaddleProvider;
//# sourceMappingURL=PaddleProvider.js.map