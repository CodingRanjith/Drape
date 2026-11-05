import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'live_weather_location_stub.dart'
    if (dart.library.io) 'live_weather_location_io.dart'
    if (dart.library.html) 'live_weather_location_web.dart' as location;

enum WeatherSkyKind { sunny, cloudy, rainy }

class LiveWeatherSnapshot {
  const LiveWeatherSnapshot({
    required this.kind,
    required this.temperatureC,
    required this.label,
    required this.placeName,
    required this.isDay,
    required this.weatherCode,
  });

  final WeatherSkyKind kind;
  final double temperatureC;
  final String label;
  final String placeName;
  final bool isDay;
  final int weatherCode;

  String get tempLabel => '${temperatureC.round()}°';
}

class LiveWeather {
  LiveWeather._();
  static final instance = LiveWeather._();

  LiveWeatherSnapshot? _cache;
  DateTime? _fetchedAt;
  Future<LiveWeatherSnapshot>? _inFlight;

  /// Chennai fallback when location is unavailable.
  static const _fallbackLat = 13.0827;
  static const _fallbackLon = 80.2707;
  static const _fallbackPlace = 'Chennai';

  Future<LiveWeatherSnapshot> load({bool force = false}) {
    if (!force &&
        _cache != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 20)) {
      return Future.value(_cache!);
    }
    if (!force && _inFlight != null) return _inFlight!;
    return _inFlight = _loadFresh().whenComplete(() => _inFlight = null);
  }

  Future<LiveWeatherSnapshot> _loadFresh() async {
    try {
      final coords = await _resolveCoords();
      final weather = await _fetchWeather(coords.lat, coords.lon);
      final place = coords.place ??
          await _reversePlace(coords.lat, coords.lon) ??
          _fallbackPlace;

      final snap = LiveWeatherSnapshot(
        kind: weather.kind,
        temperatureC: weather.temp,
        label: weather.label,
        placeName: place,
        isDay: weather.isDay,
        weatherCode: weather.code,
      );
      _cache = snap;
      _fetchedAt = DateTime.now();
      return snap;
    } catch (e) {
      debugPrint('Weather load failed: $e');
      final fallback = _cache ??
          const LiveWeatherSnapshot(
            kind: WeatherSkyKind.cloudy,
            temperatureC: 29,
            label: 'Overcast',
            placeName: _fallbackPlace,
            isDay: true,
            weatherCode: 3,
          );
      _cache = fallback;
      _fetchedAt = DateTime.now();
      return fallback;
    }
  }

  Future<({double lat, double lon, String? place})> _resolveCoords() async {
    final device = await location.deviceLocation();
    if (device != null) return device;

    final ip = await _ipCoords();
    if (ip != null) return ip;

    return (lat: _fallbackLat, lon: _fallbackLon, place: _fallbackPlace);
  }

  /// Approximate location for web / when GPS is unavailable.
  Future<({double lat, double lon, String? place})?> _ipCoords() async {
    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final lat = (json['latitude'] as num?)?.toDouble();
      final lon = (json['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      final city = (json['city'] as String?)?.trim();
      return (
        lat: lat,
        lon: lon,
        place: (city != null && city.isNotEmpty) ? city : null,
      );
    } catch (e) {
      debugPrint('IP location failed: $e');
      return null;
    }
  }

  Future<({WeatherSkyKind kind, double temp, String label, bool isDay, int code})>
      _fetchWeather(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'temperature_2m,weather_code,is_day,precipitation,cloud_cover',
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw StateError('Weather HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>? ?? const {};
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28;
    final isDay = (current['is_day'] as num?)?.toInt() == 1;
    final mapped = _mapCode(code);
    return (
      kind: mapped.kind,
      temp: temp,
      label: mapped.label,
      isDay: isDay,
      code: code,
    );
  }

  Future<String?> _reversePlace(double lat, double lon) async {
    try {
      final uri = Uri.https(
        'api.bigdatacloud.net',
        '/data/reverse-geocode-client',
        {
          'latitude': lat.toStringAsFixed(4),
          'longitude': lon.toStringAsFixed(4),
          'localityLanguage': 'en',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final city = (json['city'] as String?)?.trim();
      final locality = (json['locality'] as String?)?.trim();
      final name = (city != null && city.isNotEmpty)
          ? city
          : (locality != null && locality.isNotEmpty)
              ? locality
              : null;
      return name;
    } catch (_) {
      return null;
    }
  }

  ({WeatherSkyKind kind, String label}) _mapCode(int code) {
    if (code == 0) return (kind: WeatherSkyKind.sunny, label: 'Clear');
    if (code == 1) return (kind: WeatherSkyKind.sunny, label: 'Mostly clear');
    if (code == 2) return (kind: WeatherSkyKind.cloudy, label: 'Partly cloudy');
    if (code == 3) return (kind: WeatherSkyKind.cloudy, label: 'Overcast');
    if (code == 45 || code == 48) {
      return (kind: WeatherSkyKind.cloudy, label: 'Foggy');
    }
    if (code >= 51 && code <= 67) {
      return (kind: WeatherSkyKind.rainy, label: 'Rain');
    }
    if (code >= 71 && code <= 77) {
      return (kind: WeatherSkyKind.cloudy, label: 'Snow');
    }
    if (code >= 80 && code <= 82) {
      return (kind: WeatherSkyKind.rainy, label: 'Showers');
    }
    if (code >= 85 && code <= 86) {
      return (kind: WeatherSkyKind.cloudy, label: 'Snow showers');
    }
    if (code >= 95) {
      return (kind: WeatherSkyKind.rainy, label: 'Thunderstorm');
    }
    return (kind: WeatherSkyKind.cloudy, label: 'Cloudy');
  }
}
