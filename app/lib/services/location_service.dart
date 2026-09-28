import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

/// Requests location permission and streams the device's GPS position.
///
/// Previously this used a plain LocationSettings, which Android silently
/// stops delivering once the app is backgrounded — fatal for a convoy trip,
/// since the whole point is tracking cars whose drivers won't keep the
/// screen on. Now:
///   - Android runs the stream inside a foreground service (a persistent,
///     low-priority notification), which is what Android requires before
///     it'll keep delivering location updates to a backgrounded app.
///   - iOS requests "always" permission and disables the automatic pausing
///     iOS otherwise applies when it thinks the device has stopped moving,
///     which reads as a good battery optimization but actively breaks a
///     "where is everyone right now" convoy view.
/// Both need matching native manifest/plist entries — see PLATFORM_SETUP.md.
class LocationService {
  StreamSubscription<Position>? _sub;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled &&
        (permission == LocationPermission.always || permission == LocationPermission.whileInUse);
  }

  Future<Position?> getLastKnownPosition() async {
    try {
      final ok = await ensurePermission();
      if (!ok) return null;
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final ok = await ensurePermission();
      if (!ok) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  void startStreaming(void Function(double lat, double lng) onPosition) {
    final settings = _platformSettings();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      onPosition(pos.latitude, pos.longitude);
    });
  }

  LocationSettings _platformSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Convoy is tracking your position',
          notificationText: 'Sharing your location with the group while this trip is active.',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
