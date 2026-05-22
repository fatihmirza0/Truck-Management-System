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
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateSmartRoute = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const axios_1 = __importStar(require("axios"));
// ── Secret ───────────────────────────────────────────────────────────────────
const GOOGLE_MAPS_API_KEY = (0, params_1.defineSecret)('GOOGLE_MAPS_API_KEY');
const ROUTE_METADATA = [
    {
        id: 'route-a',
        label: 'Rota A – Birincil Güzergah',
        description: 'Google\'ın önerdiği birincil güzergah. Trafik ve yükseklik koşullarına göre değerlendirilir.',
        elevationMultiplier: 1.38,
        trafficPenaltyTL: 310,
        tollCostTL: 620,
        riskLevel: 'medium',
        tags: ['Birincil Rota', 'Trafik Optimizeli'],
    },
    {
        id: 'route-b',
        label: 'Rota B – Alternatif Güzergah',
        description: 'Alternatif güzergah. Genellikle daha uzun fakat daha sakin ve düz bir yol profili sunar.',
        elevationMultiplier: 1.06,
        trafficPenaltyTL: 90,
        tollCostTL: 920,
        riskLevel: 'low',
        tags: ['Alternatif Rota', 'Düz Yol', 'Konforlu'],
    },
];
// ── Cost Engine Constants ────────────────────────────────────────────────────
const BASE_CONSUMPTION_PER_100KM = 28; // litre (10 ton referans araç)
const BASE_TONNAGE = 10; // ton
const TONNAGE_FUEL_FACTOR = 0.8; // her ek ton için +0.8 L/100km
const DRIVER_HOURLY_RATE_TL = 200; // TL/saat
// ── Cost Engine ──────────────────────────────────────────────────────────────
function calcFuelConsumptionPer100km(cargoTonnage) {
    const extra = Math.max(0, cargoTonnage - BASE_TONNAGE);
    return BASE_CONSUMPTION_PER_100KM + extra * TONNAGE_FUEL_FACTOR;
}
function calcRouteCost(distanceKm, durationMin, meta, fuelPrice, cargoTonnage) {
    const consumptionPer100 = calcFuelConsumptionPer100km(cargoTonnage);
    const baseFuelLiters = (distanceKm / 100) * consumptionPer100;
    const elevationExtra = baseFuelLiters * (meta.elevationMultiplier - 1);
    const totalFuelLiters = Math.round(baseFuelLiters + elevationExtra);
    const fuelCostTL = Math.round(totalFuelLiters * fuelPrice);
    const elevationPenaltyTL = Math.round(elevationExtra * fuelPrice);
    const driverCostTL = Math.round((durationMin / 60) * DRIVER_HOURLY_RATE_TL);
    const totalCostTL = fuelCostTL +
        meta.trafficPenaltyTL +
        driverCostTL +
        meta.tollCostTL;
    return {
        fuelLiters: totalFuelLiters,
        fuelCostTL,
        elevationPenaltyTL,
        trafficPenaltyTL: meta.trafficPenaltyTL,
        driverCostTL,
        tollCostTL: meta.tollCostTL,
        totalCostTL,
    };
}
// ── Formatters ───────────────────────────────────────────────────────────────
function fmtDistance(km) {
    return `${km} km`;
}
function fmtDuration(minutes) {
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return m > 0 ? `${h}sa ${m}dk` : `${h}sa`;
}
// ── Google Routes API helper ─────────────────────────────────────────────────
const ROUTES_API_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';
const FIELD_MASK = 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline';
async function fetchGoogleRoutes(origin, destination, apiKey) {
    const body = {
        origin: {
            location: {
                latLng: { latitude: origin.lat, longitude: origin.lng },
            },
        },
        destination: {
            location: {
                latLng: { latitude: destination.lat, longitude: destination.lng },
            },
        },
        travelMode: 'TRUCK',
        routingPreference: 'TRAFFIC_AWARE_OPTIMAL',
        computeAlternativeRoutes: true,
    };
    const response = await axios_1.default.post(ROUTES_API_URL, body, {
        headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': FIELD_MASK,
        },
        timeout: 10000,
    });
    const routes = response.data.routes;
    if (!routes || routes.length === 0) {
        throw new https_1.HttpsError('not-found', 'Google Routes API bu iki nokta arasında uygun bir karayolu güzergahı bulamadı.');
    }
    return routes;
}
// ── Duration parser: "3720s" → 62 (dakika) ──────────────────────────────────
function parseDurationToMinutes(duration) {
    const seconds = parseInt(duration.replace('s', ''), 10);
    if (isNaN(seconds) || seconds <= 0) {
        throw new https_1.HttpsError('internal', `Geçersiz süre formatı Google API\'den döndü: "${duration}"`);
    }
    return Math.round(seconds / 60);
}
// ── Cloud Function ───────────────────────────────────────────────────────────
exports.calculateSmartRoute = (0, https_1.onCall)({
    region: 'us-central1',
    secrets: [GOOGLE_MAPS_API_KEY],
}, async (request) => {
    var _a, _b, _c, _d, _e;
    const data = request.data;
    // ── Input validation ──────────────────────────────────────────────────
    const missing = [];
    if (!data.origin)
        missing.push('origin');
    if (!data.destination)
        missing.push('destination');
    if (data.fuelPrice == null)
        missing.push('fuelPrice');
    if (data.cargoTonnage == null)
        missing.push('cargoTonnage');
    if (missing.length > 0) {
        throw new https_1.HttpsError('invalid-argument', `Eksik parametreler: ${missing.join(', ')}`);
    }
    if (typeof data.origin.lat !== 'number' || typeof data.origin.lng !== 'number') {
        throw new https_1.HttpsError('invalid-argument', 'origin.lat ve origin.lng sayısal olmalıdır.');
    }
    if (typeof data.destination.lat !== 'number' || typeof data.destination.lng !== 'number') {
        throw new https_1.HttpsError('invalid-argument', 'destination.lat ve destination.lng sayısal olmalıdır.');
    }
    if (data.fuelPrice <= 0) {
        throw new https_1.HttpsError('invalid-argument', 'fuelPrice sıfırdan büyük olmalıdır.');
    }
    if (data.cargoTonnage <= 0 || data.cargoTonnage > 60) {
        throw new https_1.HttpsError('invalid-argument', 'cargoTonnage 0–60 ton arasında olmalıdır.');
    }
    // ── Fetch routes from Google ──────────────────────────────────────────
    let googleRoutes;
    try {
        googleRoutes = await fetchGoogleRoutes(data.origin, data.destination, GOOGLE_MAPS_API_KEY.value());
    }
    catch (err) {
        // HttpsError'ları olduğu gibi yeniden fırlat
        if (err instanceof https_1.HttpsError)
            throw err;
        // Axios HTTP hataları
        if (err instanceof axios_1.AxiosError) {
            const status = (_a = err.response) === null || _a === void 0 ? void 0 : _a.status;
            const message = (_e = (_d = (_c = (_b = err.response) === null || _b === void 0 ? void 0 : _b.data) === null || _c === void 0 ? void 0 : _c.error) === null || _d === void 0 ? void 0 : _d.message) !== null && _e !== void 0 ? _e : err.message;
            if (status === 400) {
                throw new https_1.HttpsError('invalid-argument', `Google Routes API geçersiz istek: ${message}`);
            }
            if (status === 403 || status === 401) {
                throw new https_1.HttpsError('permission-denied', 'Google Maps API anahtarı geçersiz veya eksik yetkisi var.');
            }
            if (status === 429) {
                throw new https_1.HttpsError('resource-exhausted', 'Google Maps API kota limiti aşıldı.');
            }
            throw new https_1.HttpsError('unavailable', `Google Routes API erişilemiyor: ${message}`);
        }
        throw new https_1.HttpsError('internal', 'Rota hesaplaması sırasında beklenmeyen bir hata oluştu.');
    }
    // ── Map Google routes → RouteResult ──────────────────────────────────
    // Google en fazla 3 rota döndürür; sadece ilk 2'sini (profile sayımız kadar) kullanırız.
    const usable = googleRoutes.slice(0, ROUTE_METADATA.length);
    const results = usable.map((gRoute, idx) => {
        var _a, _b;
        const meta = ROUTE_METADATA[idx];
        const distanceKm = Math.round(gRoute.distanceMeters / 1000);
        const durationMin = parseDurationToMinutes(gRoute.duration);
        const breakdown = calcRouteCost(distanceKm, durationMin, meta, data.fuelPrice, data.cargoTonnage);
        return {
            id: meta.id,
            label: meta.label,
            description: meta.description,
            polyline: (_b = (_a = gRoute.polyline) === null || _a === void 0 ? void 0 : _a.encodedPolyline) !== null && _b !== void 0 ? _b : '',
            distanceKm,
            durationMin,
            distance: fmtDistance(distanceKm),
            duration: fmtDuration(durationMin),
            costBreakdown: breakdown,
            totalCost: breakdown.totalCostTL,
            isRecommended: false, // aşağıda set edilecek
            color: '#94a3b8',
            riskLevel: meta.riskLevel,
            tags: meta.tags,
        };
    });
    // Google tek rota döndürdüyse mock metadatadan ikinci rotayı senkronize et
    // (alternatif rota üretilememişse birincil rota tek sonuç olarak döner)
    if (results.length === 1) {
        results[0].label = 'Tek Güzergah';
        results[0].description = 'Bu iki nokta arasında yalnızca tek bir karayolu güzergahı mevcut.';
    }
    // ── İsRecommended: en düşük toplam maliyet ────────────────────────────
    const cheapestIdx = results.reduce((minIdx, r, idx) => r.totalCost < results[minIdx].totalCost ? idx : minIdx, 0);
    results.forEach((r, idx) => {
        r.isRecommended = idx === cheapestIdx;
        r.color = r.isRecommended ? '#10b981' : '#94a3b8';
    });
    return results;
});
//# sourceMappingURL=calculateSmartRoute.js.map