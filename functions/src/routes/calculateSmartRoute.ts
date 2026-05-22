import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import axios, { AxiosError } from 'axios';

// ── Secret ───────────────────────────────────────────────────────────────────

const GOOGLE_MAPS_API_KEY = defineSecret('GOOGLE_MAPS_API_KEY');

// ── Input / Output Types ─────────────────────────────────────────────────────

interface LatLng {
  lat: number;
  lng: number;
}

interface CalculateRouteRequest {
  origin: LatLng;
  destination: LatLng;
  fuelPrice: number;      // TL/litre
  cargoTonnage: number;   // metric ton
}

interface CostBreakdown {
  fuelLiters: number;
  fuelCostTL: number;
  elevationPenaltyTL: number;
  trafficPenaltyTL: number;
  driverCostTL: number;
  tollCostTL: number;
  totalCostTL: number;
}

interface RouteResult {
  id: string;
  label: string;
  description: string;
  polyline: string;
  distanceKm: number;
  durationMin: number;
  distance: string;
  duration: string;
  costBreakdown: CostBreakdown;
  totalCost: number;
  isRecommended: boolean;
  color: string;
  riskLevel: 'low' | 'medium' | 'high';
  tags: string[];
}

// ── Google Routes API v2 response types ──────────────────────────────────────

interface GoogleRoute {
  distanceMeters: number;
  duration: string;               // "3720s"
  polyline?: {
    encodedPolyline: string;
  };
}

interface GoogleRoutesResponse {
  routes?: GoogleRoute[];
}

// ── Route Profile Metadata ───────────────────────────────────────────────────
// Google sadece mesafe ve süre döndürür; eğim/trafik profili rota sıralamasına
// göre statik olarak atanır (ilk rota = kısa/zor, ikinci = uzun/kolay).

interface RouteMetadata {
  id: string;
  label: string;
  description: string;
  elevationMultiplier: number;  // 1.0 = düz, 1.4 = yokuşlu
  trafficPenaltyTL: number;
  tollCostTL: number;
  riskLevel: 'low' | 'medium' | 'high';
  tags: string[];
}

const ROUTE_METADATA: RouteMetadata[] = [
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

const BASE_CONSUMPTION_PER_100KM = 28;  // litre (10 ton referans araç)
const BASE_TONNAGE                = 10;  // ton
const TONNAGE_FUEL_FACTOR         = 0.8; // her ek ton için +0.8 L/100km
const DRIVER_HOURLY_RATE_TL       = 200; // TL/saat

// ── Cost Engine ──────────────────────────────────────────────────────────────

function calcFuelConsumptionPer100km(cargoTonnage: number): number {
  const extra = Math.max(0, cargoTonnage - BASE_TONNAGE);
  return BASE_CONSUMPTION_PER_100KM + extra * TONNAGE_FUEL_FACTOR;
}

function calcRouteCost(
  distanceKm: number,
  durationMin: number,
  meta: RouteMetadata,
  fuelPrice: number,
  cargoTonnage: number,
): CostBreakdown {
  const consumptionPer100 = calcFuelConsumptionPer100km(cargoTonnage);

  const baseFuelLiters     = (distanceKm / 100) * consumptionPer100;
  const elevationExtra     = baseFuelLiters * (meta.elevationMultiplier - 1);
  const totalFuelLiters    = Math.round(baseFuelLiters + elevationExtra);

  const fuelCostTL         = Math.round(totalFuelLiters * fuelPrice);
  const elevationPenaltyTL = Math.round(elevationExtra * fuelPrice);
  const driverCostTL       = Math.round((durationMin / 60) * DRIVER_HOURLY_RATE_TL);

  const totalCostTL =
    fuelCostTL +
    meta.trafficPenaltyTL +
    driverCostTL +
    meta.tollCostTL;

  return {
    fuelLiters:       totalFuelLiters,
    fuelCostTL,
    elevationPenaltyTL,
    trafficPenaltyTL: meta.trafficPenaltyTL,
    driverCostTL,
    tollCostTL:       meta.tollCostTL,
    totalCostTL,
  };
}

// ── Formatters ───────────────────────────────────────────────────────────────

function fmtDistance(km: number): string {
  return `${km} km`;
}

function fmtDuration(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}sa ${m}dk` : `${h}sa`;
}

// ── Google Routes API helper ─────────────────────────────────────────────────

const ROUTES_API_URL =
  'https://routes.googleapis.com/directions/v2:computeRoutes';

const FIELD_MASK =
  'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline';

async function fetchGoogleRoutes(
  origin: LatLng,
  destination: LatLng,
  apiKey: string,
): Promise<GoogleRoute[]> {
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

  const response = await axios.post<GoogleRoutesResponse>(
    ROUTES_API_URL,
    body,
    {
      headers: {
        'Content-Type':      'application/json',
        'X-Goog-Api-Key':    apiKey,
        'X-Goog-FieldMask':  FIELD_MASK,
      },
      timeout: 10_000,
    },
  );

  const routes = response.data.routes;

  if (!routes || routes.length === 0) {
    throw new HttpsError(
      'not-found',
      'Google Routes API bu iki nokta arasında uygun bir karayolu güzergahı bulamadı.',
    );
  }

  return routes;
}

// ── Duration parser: "3720s" → 62 (dakika) ──────────────────────────────────

function parseDurationToMinutes(duration: string): number {
  const seconds = parseInt(duration.replace('s', ''), 10);
  if (isNaN(seconds) || seconds <= 0) {
    throw new HttpsError('internal', `Geçersiz süre formatı Google API\'den döndü: "${duration}"`);
  }
  return Math.round(seconds / 60);
}

// ── Cloud Function ───────────────────────────────────────────────────────────

export const calculateSmartRoute = onCall<CalculateRouteRequest, Promise<RouteResult[]>>(
  {
    region: 'us-central1',
    secrets: [GOOGLE_MAPS_API_KEY],
  },
  async (request) => {
    const data = request.data;

    // ── Input validation ──────────────────────────────────────────────────
    const missing: string[] = [];
    if (!data.origin)              missing.push('origin');
    if (!data.destination)         missing.push('destination');
    if (data.fuelPrice    == null)  missing.push('fuelPrice');
    if (data.cargoTonnage == null)  missing.push('cargoTonnage');

    if (missing.length > 0) {
      throw new HttpsError(
        'invalid-argument',
        `Eksik parametreler: ${missing.join(', ')}`,
      );
    }
    if (typeof data.origin.lat !== 'number' || typeof data.origin.lng !== 'number') {
      throw new HttpsError('invalid-argument', 'origin.lat ve origin.lng sayısal olmalıdır.');
    }
    if (typeof data.destination.lat !== 'number' || typeof data.destination.lng !== 'number') {
      throw new HttpsError('invalid-argument', 'destination.lat ve destination.lng sayısal olmalıdır.');
    }
    if (data.fuelPrice <= 0) {
      throw new HttpsError('invalid-argument', 'fuelPrice sıfırdan büyük olmalıdır.');
    }
    if (data.cargoTonnage <= 0 || data.cargoTonnage > 60) {
      throw new HttpsError('invalid-argument', 'cargoTonnage 0–60 ton arasında olmalıdır.');
    }

    // ── Fetch routes from Google ──────────────────────────────────────────
    let googleRoutes: GoogleRoute[];

    try {
      googleRoutes = await fetchGoogleRoutes(
        data.origin,
        data.destination,
        GOOGLE_MAPS_API_KEY.value(),
      );
    } catch (err) {
      // HttpsError'ları olduğu gibi yeniden fırlat
      if (err instanceof HttpsError) throw err;

      // Axios HTTP hataları
      if (err instanceof AxiosError) {
        const status  = err.response?.status;
        const message = (err.response?.data as { error?: { message?: string } })
          ?.error?.message ?? err.message;

        if (status === 400) {
          throw new HttpsError('invalid-argument', `Google Routes API geçersiz istek: ${message}`);
        }
        if (status === 403 || status === 401) {
          throw new HttpsError('permission-denied', 'Google Maps API anahtarı geçersiz veya eksik yetkisi var.');
        }
        if (status === 429) {
          throw new HttpsError('resource-exhausted', 'Google Maps API kota limiti aşıldı.');
        }
        throw new HttpsError('unavailable', `Google Routes API erişilemiyor: ${message}`);
      }

      throw new HttpsError('internal', 'Rota hesaplaması sırasında beklenmeyen bir hata oluştu.');
    }

    // ── Map Google routes → RouteResult ──────────────────────────────────
    // Google en fazla 3 rota döndürür; sadece ilk 2'sini (profile sayımız kadar) kullanırız.
    const usable = googleRoutes.slice(0, ROUTE_METADATA.length);

    const results: RouteResult[] = usable.map((gRoute, idx) => {
      const meta        = ROUTE_METADATA[idx];
      const distanceKm  = Math.round(gRoute.distanceMeters / 1000);
      const durationMin = parseDurationToMinutes(gRoute.duration);
      const breakdown   = calcRouteCost(distanceKm, durationMin, meta, data.fuelPrice, data.cargoTonnage);

      return {
        id:          meta.id,
        label:       meta.label,
        description: meta.description,
        polyline:    gRoute.polyline?.encodedPolyline ?? '',
        distanceKm,
        durationMin,
        distance:    fmtDistance(distanceKm),
        duration:    fmtDuration(durationMin),
        costBreakdown: breakdown,
        totalCost:   breakdown.totalCostTL,
        isRecommended: false,   // aşağıda set edilecek
        color:         '#94a3b8',
        riskLevel:   meta.riskLevel,
        tags:        meta.tags,
      };
    });

    // Google tek rota döndürdüyse mock metadatadan ikinci rotayı senkronize et
    // (alternatif rota üretilememişse birincil rota tek sonuç olarak döner)
    if (results.length === 1) {
      results[0].label       = 'Tek Güzergah';
      results[0].description = 'Bu iki nokta arasında yalnızca tek bir karayolu güzergahı mevcut.';
    }

    // ── İsRecommended: en düşük toplam maliyet ────────────────────────────
    const cheapestIdx = results.reduce(
      (minIdx, r, idx) => r.totalCost < results[minIdx].totalCost ? idx : minIdx,
      0,
    );
    results.forEach((r, idx) => {
      r.isRecommended = idx === cheapestIdx;
      r.color         = r.isRecommended ? '#10b981' : '#94a3b8';
    });

    return results;
  },
);
