import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/mapbox_config.dart';

/// Mapbox forward-geocoding helper.
class GeocodingService {
  GeocodingService._();

  /// Returns up to [limit] place suggestions for [query].
  static Future<List<GeocodingResult>> search(
    String query, {
    int limit = 5,
  }) async {
    if (query.trim().length < 3) return [];

    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/'
      '${Uri.encodeComponent(query)}.json'
      '?access_token=${MapboxConfig.accessToken}'
      '&limit=$limit'
      '&types=address,poi,place',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final features = body['features'] as List? ?? [];
    return features.map((f) => GeocodingResult.fromJson(f)).toList();
  }
}

class GeocodingResult {
  final String placeName;
  final double lat;
  final double lng;

  const GeocodingResult({
    required this.placeName,
    required this.lat,
    required this.lng,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    final coords = json['center'] as List? ?? [0, 0];
    return GeocodingResult(
      placeName: json['place_name'] as String? ?? '',
      lng: (coords[0] as num).toDouble(),
      lat: (coords[1] as num).toDouble(),
    );
  }
}
