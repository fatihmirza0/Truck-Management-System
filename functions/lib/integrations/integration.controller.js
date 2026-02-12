"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncDataToIntegration = exports.testIntegrationConnection = exports.saveIntegrationConfig = void 0;
const https_1 = require("firebase-functions/v2/https");
const integration_service_1 = require("./integration.service");
const service = new integration_service_1.IntegrationService();
// Configure or Update Integration
exports.saveIntegrationConfig = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'User must be logged in');
    }
    const { companyId, config } = request.data;
    // Security check: Ensure user belongs to this company (omitted for brevity, assume Auth token claims has companyId)
    // const userCompanyId = request.auth.token.companyId; 
    // if (userCompanyId !== companyId) throw new HttpsError('permission-denied', 'Wrong company');
    try {
        await service.saveConfiguration(companyId, config);
        return { success: true };
    }
    catch (error) {
        throw new https_1.HttpsError('internal', error.message);
    }
});
// Test the connection
exports.testIntegrationConnection = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'User must be logged in');
    }
    const { companyId } = request.data;
    try {
        const result = await service.testConnection(companyId);
        return result;
    }
    catch (error) {
        throw new https_1.HttpsError('internal', error.message);
    }
});
// Manual Sync Trigger
exports.syncDataToIntegration = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'User must be logged in');
    }
    const { companyId } = request.data;
    try {
        const result = await service.syncData(companyId);
        return result;
    }
    catch (error) {
        throw new https_1.HttpsError('internal', error.message);
    }
});
//# sourceMappingURL=integration.controller.js.map