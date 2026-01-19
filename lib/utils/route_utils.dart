import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class RouteUtils {

  static const String apiKey = "AIzaSyBW9ivbOndjriQ50cwHN6d3VUiWmQJ9VdE";

  /// 🔹 adres → koordinat
  static Future<Map<String, double>?> geocode(String address) async {
    try {
      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      if (data["status"] == "OK") {
        final loc = data["results"][0]["geometry"]["location"];
        return {
          "lat": loc["lat"] * 1.0,
          "lng": loc["lng"] * 1.0,
        };
      }
    } catch (e) {
      print("Geocode error (likely CORS on Web): $e");
    }
    return null;
  }

  /// 🔥 Google Directions API ile gerçek rota km'si
  static Future<double> getRouteKm(double lat1, double lng1, double lat2, double lng2) async {
    try {
      final url =
          "https://maps.googleapis.com/maps/api/directions/json?origin=$lat1,$lng1&destination=$lat2,$lng2&key=$apiKey";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      if (data["routes"] != null && data["routes"].isNotEmpty) {
        final meters = data["routes"][0]["legs"][0]["distance"]["value"];
        return meters / 1000; // 🔥 metre → km
      }
    } catch (e) {
      print("getRouteKm error (likely CORS on Web): $e");
    }
    return 0;
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
