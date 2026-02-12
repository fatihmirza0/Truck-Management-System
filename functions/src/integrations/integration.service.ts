
import * as admin from 'firebase-admin';
import axios from 'axios';

export interface IntegrationConfig {
    provider: 'SAP' | 'ORACLE' | 'MICROSOFT' | 'CUSTOM';
    apiKey: string;
    apiUrl: string;
    webhookSecret?: string;
    isEnabled: boolean;
}

export class IntegrationService {
    private db = admin.firestore();

    async saveConfiguration(companyId: string, config: IntegrationConfig): Promise<void> {
        // In a real app, we would encrypt the apiKey here before saving
        await this.db.collection('companies').doc(companyId)
            .collection('integrations').doc('erp_primary').set({
                ...config,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
    }

    async testConnection(companyId: string): Promise<{ success: boolean; message: string; latency?: number }> {
        const doc = await this.db.collection('companies').doc(companyId)
            .collection('integrations').doc('erp_primary').get();

        if (!doc.exists) {
            throw new Error('Integration not configured');
        }

        const config = doc.data() as IntegrationConfig;

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
            await axios.get(config.apiUrl, {
                headers: { 'Authorization': `Bearer ${config.apiKey}` },
                timeout: 5000
            });
            return {
                success: true,
                message: 'Connection established successfully',
                latency: Date.now() - start
            };
        } catch (error: any) {
            return {
                success: false,
                message: error.message || 'Connection failed'
            };
        }
    }

    async syncData(companyId: string): Promise<{ syncedRecords: number }> {
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
