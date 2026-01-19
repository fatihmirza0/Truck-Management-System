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
exports.CurrencyService = void 0;
const axios_1 = __importDefault(require("axios"));
const xml2js = __importStar(require("xml2js"));
const admin = __importStar(require("firebase-admin"));
class CurrencyService {
    /**
     * Fetch daily exchange rates from TCMB and update Firestore
     */
    static async syncRates() {
        try {
            const response = await axios_1.default.get(this.TCMB_URL);
            const parser = new xml2js.Parser({ explicitArray: false });
            const result = await parser.parseStringPromise(response.data);
            const usdRate = result.Tarih_Date.Currency.find((c) => c.$.Kod === 'USD');
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
        }
        catch (error) {
            console.error('Error syncing rates:', error);
            throw error;
        }
    }
    /**
     * Get current USD selling rate from Firestore
     */
    static async getUSDRate() {
        var _a, _b, _c, _d;
        const doc = await admin.firestore().collection('system_metadata').doc('rates').get();
        if (!doc.exists) {
            // Fallback or fetch fresh
            await this.syncRates();
            const newDoc = await admin.firestore().collection('system_metadata').doc('rates').get();
            return ((_b = (_a = newDoc.data()) === null || _a === void 0 ? void 0 : _a.USD) === null || _b === void 0 ? void 0 : _b.selling) || 30.0;
        }
        return ((_d = (_c = doc.data()) === null || _c === void 0 ? void 0 : _c.USD) === null || _d === void 0 ? void 0 : _d.selling) || 30.0;
    }
}
exports.CurrencyService = CurrencyService;
CurrencyService.TCMB_URL = 'https://www.tcmb.gov.tr/kurlar/today.xml';
//# sourceMappingURL=CurrencyService.js.map