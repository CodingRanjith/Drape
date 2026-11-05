import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Mobile / desktop GPS via geolocator.
Future<({double lat, double lon, String? place})?> deviceLocation() async {
  try {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return (lat: pos.latitude, lon: pos.longitude, place: null);
  } on MissingPluginException catch (e) {
    debugPrint('GPS plugin missing: $e');
    return null;
  } on PlatformException catch (e) {
    debugPrint('GPS platform error: $e');
    return null;
  } catch (e) {
    debugPrint('GPS failed: $e');
    return null;
  }
}
