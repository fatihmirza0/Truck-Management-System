import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class RouteUtils {
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static String get _safeApiKey {
    if (_apiKey.isEmpty) {
      throw const FormatException(
          'Google Maps API anahtarı eksik. --dart-define=GOOGLE_MAPS_API_KEY ile geçin.');
    }
    return _apiKey;
  }

  /// 🔹 adres → koordinat
  static Future<Map<String, double>?> geocode(String address) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_safeApiKey";

    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);

    if (data["status"] == "OK") {
      final loc = data["results"][0]["geometry"]["location"];
      return {
        "lat": loc["lat"] * 1.0,
        "lng": loc["lng"] * 1.0,
      };
    }
    return null;
  }

  /// 🔥 Google Directions API ile gerçek rota km'si
  static Future<double> getRouteKm(double lat1, double lng1, double lat2, double lng2) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$lat1,$lng1&destination=$lat2,$lng2&key=$_safeApiKey";

    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body);

    if (data["routes"] == null || data["routes"].isEmpty) return 0;

    final meters = data["routes"][0]["legs"][0]["distance"]["value"];
    return meters / 1000; // 🔥 metre → km
  }

  /// fallback (adres bulamazsa — sen bunu zaten kullanıyorsun)
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);

    final a =
        (sin(dLat/2) * sin(dLat/2)) +
            cos(_deg(lat1)) * cos(_deg(lat2)) *
                sin(dLon/2) * sin(dLon/2);

    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  static double _deg(double n) => n * (pi/180);
}
