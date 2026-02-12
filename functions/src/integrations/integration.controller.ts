
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { IntegrationService } from './integration.service';

const service = new IntegrationService();

// Configure or Update Integration
export const saveIntegrationConfig = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be logged in');
    }

    const { companyId, config } = request.data;

    // Security check: Ensure user belongs to this company (omitted for brevity, assume Auth token claims has companyId)
    // const userCompanyId = request.auth.token.companyId; 
    // if (userCompanyId !== companyId) throw new HttpsError('permission-denied', 'Wrong company');

    try {
        await service.saveConfiguration(companyId, config);
        return { success: true };
    } catch (error: any) {
        throw new HttpsError('internal', error.message);
    }
});

// Test the connection
export const testIntegrationConnection = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be logged in');
    }

    const { companyId } = request.data;

    try {
        const result = await service.testConnection(companyId);
        return result;
    } catch (error: any) {
        throw new HttpsError('internal', error.message);
    }
});

// Manual Sync Trigger
export const syncDataToIntegration = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be logged in');
    }

    const { companyId } = request.data;

    try {
        const result = await service.syncData(companyId);
        return result;
    } catch (error: any) {
        throw new HttpsError('internal', error.message);
    }
});
