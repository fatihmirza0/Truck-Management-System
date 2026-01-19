
export interface PaymentGateway {
    /**
     * Create a new subscription for a user.
     * @param planId The internal plan ID (e.g., 'starter', 'professional')
     * @param user User details (email, name, id)
     * @returns The checkout URL or payment init data
     */
    createSubscription(planId: string, user: UserDetails): Promise<SubscriptionResult>;

    /**
     * Cancel an existing subscription
     * @param subscriptionId The external subscription ID
     */
    cancelSubscription(subscriptionId: string): Promise<void>;

    /**
     * Verify a webhook signature
     * @param headers Request headers
     * @param body Request body
     */
    verifyWebhook(headers: any, body: any): boolean;
}

export interface UserDetails {
    uid: string;
    email: string;
    name: string;
    country: string;
    phone?: string;
    address?: string;
    identityNumber?: string; // For TR (TCKN)
}

export interface SubscriptionResult {
    status: 'active' | 'pending' | 'requires_action';
    externalId?: string; // Provider's subscription ID
    checkoutUrl?: string; // URL to redirect user to
    clientSecret?: string; // For frontend SDKs if needed
}
