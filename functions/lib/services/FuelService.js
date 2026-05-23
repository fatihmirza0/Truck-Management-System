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
exports.FuelService = void 0;
const axios_1 = __importDefault(require("axios"));
const admin = __importStar(require("firebase-admin"));
class FuelService {
    /**
     * Fetch fuel prices from Opet API for the target provinces,
     * calculate the average diesel (Motorin) price,
     * and update system metadata and company settings.
     */
    static async syncFuelPrices() {
        try {
            const prices = [];
            for (const provinceCode of this.TARGET_PROVINCES) {
                try {
                    const response = await axios_1.default.get(`${this.OPET_PRICE_URL}?ProvinceCode=${provinceCode}`, {
                        timeout: 10000,
                        headers: {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                            'Accept': 'application/json'
                        }
                    });
                    if (Array.isArray(response.data)) {
                        response.data.forEach((district) => {
                            if (district.prices && Array.isArray(district.prices)) {
                                // Find Motorin (UltraForce or EcoForce)
                                const motorinPrice = district.prices.find((p) => p.productShortName === 'MT_ULT' || p.productShortName === 'MT_ECO');
                                if (motorinPrice && typeof motorinPrice.amount === 'number' && motorinPrice.amount > 0) {
                                    prices.push(motorinPrice.amount);
                                }
                            }
                        });
                    }
                }
                catch (provErr) {
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
                var _a;
                const companyData = doc.data();
                // Update only if they have not disabled autoUpdateFuel
                if (((_a = companyData.settings) === null || _a === void 0 ? void 0 : _a.autoUpdateFuel) !== false) {
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
        }
        catch (error) {
            console.error('Error syncing fuel prices:', error);
            throw error;
        }
    }
}
exports.FuelService = FuelService;
FuelService.OPET_PRICE_URL = 'https://api.opet.com.tr/api/fuelprices/prices';
FuelService.TARGET_PROVINCES = [34, 934, 6, 35]; // İstanbul Anadolu, İstanbul Avrupa, Ankara, İzmir
//# sourceMappingURL=FuelService.js.map