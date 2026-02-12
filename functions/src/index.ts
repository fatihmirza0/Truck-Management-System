import * as admin from 'firebase-admin';

import { setGlobalOptions } from 'firebase-functions/v2';

// Initialize Firebase Admin before anything else
if (!admin.apps.length) {
    admin.initializeApp();
}

// Global Options for v2 functions
setGlobalOptions({
    maxInstances: 10,
    region: 'us-central1'
});

// Export subscription functions
export { createSubscription, syncExchangeRates } from './subscriptions/subscription.controller';
export { webhookHandler } from './webhooks/webhook.handler';
export { getPublicJobStatus } from './legacy/general';
export { getEstimatedJobCosts } from './legacy/general';

// Legacy exports (restored)
export * from './legacy/general';
export * from './legacy/developer';
export { saveMarketingContentHttp } from './legacy/developer';


// Export integration functions
export * from './integrations/integration.controller';
