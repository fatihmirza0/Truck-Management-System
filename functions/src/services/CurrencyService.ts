import axios from 'axios';
import * as xml2js from 'xml2js';
import * as admin from 'firebase-admin';

export class CurrencyService {
    private static TCMB_URL = 'https://www.tcmb.gov.tr/kurlar/today.xml';

    /**
     * Fetch daily exchange rates from TCMB and update Firestore
     */
    static async syncRates(): Promise<void> {
        try {
            const response = await axios.get(this.TCMB_URL);
            const parser = new xml2js.Parser({ explicitArray: false });
            const result = await parser.parseStringPromise(response.data);

            const usdRate = result.Tarih_Date.Currency.find((c: any) => c.$.Kod === 'USD');

            if (!usdRate) {
                throw new Error('USD rate not found in TCMB response');
            }

            const forexBuying = parseFloat(usdRate.ForexBuying);
            const forexSelling = parseFloat(usdRate.ForexSelling);

            await admin.firestore().collection('system_metadata').doc('rates').set({
                USD: {
                    buying: forexBuying,
                    selling: forexSelling,
                },
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                source: 'TCMB'
            });

            console.log(`Rates synced: 1 USD = ${forexSelling} TRY`);
        } catch (error) {
            console.error('Error syncing rates:', error);
            throw error;
        }
    }

    /**
     * Get current USD selling rate from Firestore
     */
    static async getUSDRate(): Promise<number> {
        const doc = await admin.firestore().collection('system_metadata').doc('rates').get();
        if (!doc.exists) {
            // Fallback or fetch fresh
            await this.syncRates();
            const newDoc = await admin.firestore().collection('system_metadata').doc('rates').get();
            return newDoc.data()?.USD?.selling || 30.0;
        }
        return doc.data()?.USD?.selling || 30.0;
    }
}
