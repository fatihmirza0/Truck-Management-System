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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.IntegrationService = void 0;
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
class IntegrationService {
    constructor() {
        this.db = admin.firestore();
    }
    async saveConfiguration(companyId, config) {
        // In a real app, we would encrypt the apiKey here before saving
        await this.db.collection('companies').doc(companyId)
            .collection('integrations').doc('erp_primary').set(Object.assign(Object.assign({}, config), { updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
    }
    async testConnection(companyId) {
        const doc = await this.db.collection('companies').doc(companyId)
            .collection('integrations').doc('erp_primary').get();
        if (!doc.exists) {
            throw new Error('Integration not configured');
        }
        const config = doc.data();
        // Mock Logic for Demo Purposes
        if (config.apiUrl.includes('mock') || config.apiKey === 'demo-key') {
            await new Promise(resolve => setTimeout(resolve, 800)); // Simulate network delay
            return {
                success: true,
                message: `Successfully connected to ${config.provider} (Mock Environment)`,
                latency: 124
            };
        }
        // Real Connection Attempt
        try {
            const start = Date.now();
            await axios_1.default.get(config.apiUrl, {
                headers: { 'Authorization': `Bearer ${config.apiKey}` },
                timeout: 5000
            });
            return {
                success: true,
                message: 'Connection established successfully',
                latency: Date.now() - start
            };
        }
        catch (error) {
            return {
                success: false,
                message: error.message || 'Connection failed'
            };
        }
    }
    async syncData(companyId) {
        // Logic to push recent jobs to the ERP
        const recentJobs = await this.db.collection('companies').doc(companyId)
            .collection('jobs')
            .where('status', '==', 'completed')
            .limit(10)
            .get();
        // Simulate processing
        await new Promise(resolve => setTimeout(resolve, 2000));
        return { syncedRecords: recentJobs.size };
    }
}
exports.IntegrationService = IntegrationService;
//# sourceMappingURL=integration.service.js.map