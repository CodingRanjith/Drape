/// Web: skip geolocator (avoids MissingPluginException). IP used by caller.
Future<({double lat, double lon, String? place})?> deviceLocation() async =>
    null;
