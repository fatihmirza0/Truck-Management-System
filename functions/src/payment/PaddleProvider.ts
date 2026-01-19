import { PaymentGateway, UserDetails, SubscriptionResult } from './PaymentGateway';
import { Paddle, Environment } from '@paddle/paddle-node-sdk';


export class PaddleProvider implements PaymentGateway {
    private paddle: Paddle;

    constructor(config?: { apiKey: string, environment?: string }) {
        this.paddle = new Paddle(config?.apiKey || process.env.PADDLE_API_KEY || 'sandbox-key', {
            environment: (config?.environment || process.env.PADDLE_ENV) === 'production' ? Environment.production : Environment.sandbox
        });
    }

    async createSubscription(planId: string, user: UserDetails): Promise<SubscriptionResult> {
        // Paddle uses Price IDs. We need a map from Internal Plan ID -> Paddle Price ID
        const priceId = this.mapPlanToPaddlePrice(planId);

        // Paddle Transaction API to generate a checkout
        try {
            // Create or get customer first to satisfy SDK strict types
            let customerId: string;

            try {
                // Check for existing customer by email
                // We await the response. Using 'any' cast to access data if types are restrictive
                const response = await this.paddle.customers.list({ email: [user.email] });
                const customers = (response as any).data || [];

                if (customers.length > 0) {
                    customerId = customers[0].id;
                } else {
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

                const result: any = transaction;
                return {
                    status: 'pending',
                    checkoutUrl: result.details?.checkout?.url || result.url || '',
                    externalId: result.id
                };

            } catch (err: any) {
                console.error("Paddle Customer/Transaction Error", err);
                throw err;
            }

        } catch (e) {
            console.error("Paddle Create Error", e);
            throw e;
        }
    }

    async cancelSubscription(subscriptionId: string): Promise<void> {
        await this.paddle.subscriptions.cancel(subscriptionId, {
            effectiveFrom: 'next_billing_period'
        });
    }

    verifyWebhook(headers: any, body: any): boolean {
        const signature = headers['paddle-signature'];
        // Use paddle-node-sdk webhook validator
        // return this.paddle.webhooks.unmarshal(body, functions.config().paddle.webhook_secret, signature);
        return !!signature; // TODO: Implement strict check
    }

    private mapPlanToPaddlePrice(planId: string): string {
        const map: { [key: string]: string } = {
            'starter': 'pri_starter_123',
            'professional': 'pri_pro_456',
            'enterprise': 'pri_ent_789'
        };
        return map[planId] || 'pri_default';
    }
}
