/// Mapbox configuration — token and style URLs.
/// Copy this file to mapbox_config.dart and fill in your real access token.
/// mapbox_config.dart is gitignored and will NOT be committed.
class MapboxConfig {
  MapboxConfig._();

  static const String accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

  /// Dark blue style with golden freeway lines — same as Cruise app
  static const String styleNavigation =
      'mapbox://styles/mapbox/navigation-night-v1';
}
