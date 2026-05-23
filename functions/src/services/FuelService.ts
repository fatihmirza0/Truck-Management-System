import axios from 'axios';
import * as admin from 'firebase-admin';

export class FuelService {
    private static OPET_PRICE_URL = 'https://api.opet.com.tr/api/fuelprices/prices';
    private static TARGET_PROVINCES = [34, 934, 6, 35]; // İstanbul Anadolu, İstanbul Avrupa, Ankara, İzmir

    /**
     * Fetch fuel prices from Opet API for the target provinces,
     * calculate the average diesel (Motorin) price,
     * and update system metadata and company settings.
     */
    static async syncFuelPrices(): Promise<number> {
        try {
            const prices: number[] = [];

            for (const provinceCode of this.TARGET_PROVINCES) {
                try {
                    const response = await axios.get(`${this.OPET_PRICE_URL}?ProvinceCode=${provinceCode}`, {
                        timeout: 10000,
                        headers: {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                            'Accept': 'application/json'
                        }
                    });

                    if (Array.isArray(response.data)) {
                        response.data.forEach((district: any) => {
                            if (district.prices && Array.isArray(district.prices)) {
                                // Find Motorin (UltraForce or EcoForce)
                                const motorinPrice = district.prices.find(
                                    (p: any) => p.productShortName === 'MT_ULT' || p.productShortName === 'MT_ECO'
                                );

                                if (motorinPrice && typeof motorinPrice.amount === 'number' && motorinPrice.amount > 0) {
                                    prices.push(motorinPrice.amount);
                                }
                            }
                        });
                    }
                } catch (provErr: any) {
                    console.warn(`Failed to fetch fuel price for province ${provinceCode}:`, provErr.message);
                }
            }

            if (prices.length === 0) {
                throw new Error('No diesel prices could be fetched from Opet API');
            }

            // Calculate average
            const sum = prices.reduce((a, b) => a + b, 0);
            const average = Number((sum / prices.length).toFixed(2));

            // 1. Update global config in Firestore
            await admin.firestore().collection('system_metadata').doc('fuel').set({
                averageDieselPrice: average,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                source: 'Opet API',
                provincesChecked: this.TARGET_PROVINCES
            });

            console.log(`Global fuel price synced: ${average} ₺/lt`);

            // 2. Query all companies and update their settings.fuelPrice if autoUpdateFuel is not explicitly false
            const companiesSnap = await admin.firestore().collection('companies').get();
            const batch = admin.firestore().batch();
            let updateCount = 0;

            companiesSnap.forEach(doc => {
                const companyData = doc.data();
                // Update only if they have not disabled autoUpdateFuel
                if (companyData.settings?.autoUpdateFuel !== false) {
                    batch.update(doc.ref, {
                        'settings.fuelPrice': average,
                        'settings.updatedAt': admin.firestore.FieldValue.serverTimestamp()
                    });
                    updateCount++;
                }
            });

            if (updateCount > 0) {
                await batch.commit();
                console.log(`Auto-updated fuel price to ${average} ₺/lt for ${updateCount} companies.`);
            }

            return average;
        } catch (error) {
            console.error('Error syncing fuel prices:', error);
            throw error;
        }
    }
}
