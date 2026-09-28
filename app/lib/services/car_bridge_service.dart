import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Two-way bridge between Convoy Flutter app and in-car infotainment displays
/// (Android Auto CarAppService & Apple CarPlay CPTemplateApplicationScene).
class CarBridgeService {
  static const MethodChannel _channel = MethodChannel('com.example.convoy/car_bridge');

  VoidCallback? onCarPushToTalkDown;
  VoidCallback? onCarPushToTalkUp;
  VoidCallback? onCarToggleMute;

  static final CarBridgeService _instance = CarBridgeService._internal();
  factory CarBridgeService() => _instance;

  CarBridgeService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPushToTalkDown':
        onCarPushToTalkDown?.call();
        break;
      case 'onPushToTalkUp':
        onCarPushToTalkUp?.call();
        break;
      case 'onToggleMute':
        onCarToggleMute?.call();
        break;
      default:
        debugPrint('CarBridgeService unhandled method: ${call.method}');
    }
  }

  /// Pushes the latest convoy metrics to the car display (Android Auto / CarPlay).
  Future<void> updateCarState({
    required String? convoyName,
    required String? convoyCode,
    required String? myVehicleName,
    required bool isLead,
    required int position,
    required int totalVehicles,
    required double gapToLeadM,
    required bool isStraggler,
    required bool isRadioMuted,
    required bool isTransmitting,
    required String? activeSpeakerName,
  }) async {
    try {
      await _channel.invokeMethod('updateConvoyStatus', {
        'convoyName': convoyName ?? 'Convoy',
        'convoyCode': convoyCode ?? '',
        'myVehicleName': myVehicleName ?? 'My Car',
        'isLead': isLead,
        'position': position,
        'totalVehicles': totalVehicles,
        'gapToLeadM': gapToLeadM,
        'gapToLeadKm': (gapToLeadM / 1000).toStringAsFixed(1),
        'isStraggler': isStraggler,
        'isRadioMuted': isRadioMuted,
        'isTransmitting': isTransmitting,
        'activeSpeakerName': activeSpeakerName,
      });
    } catch (e) {
      // Non-fatal if head unit is disconnected
    }
  }

  /// Clears in-car display state when the convoy ends or user leaves.
  Future<void> clearCarState() async {
    try {
      await _channel.invokeMethod('clearConvoyStatus');
    } catch (_) {}
  }
}

