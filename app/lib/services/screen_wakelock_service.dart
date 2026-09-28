import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to keep the phone screen awake during active convoy navigation.
class ScreenWakelockService {
  static const MethodChannel _channel = MethodChannel('com.example.convoy/screen_wakelock');
  static bool _isEnabled = false;

  static bool get isEnabled => _isEnabled;

  static Future<void> enable() async {
    if (_isEnabled) return;
    try {
      await _channel.invokeMethod('enable');
      _isEnabled = true;
    } catch (e) {
      debugPrint('ScreenWakelockService enable error: $e');
    }
  }

  static Future<void> disable() async {
    if (!_isEnabled) return;
    try {
      await _channel.invokeMethod('disable');
      _isEnabled = false;
    } catch (e) {
      debugPrint('ScreenWakelockService disable error: $e');
    }
  }

  static Future<void> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
  }
}

