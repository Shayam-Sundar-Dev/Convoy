import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/no_internet_dialog.dart';

/// Global connectivity monitor and enforcement service for Convoy.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  factory ConnectivityService() => instance;
  ConnectivityService._internal();

  /// Global navigator key to enable dialog prompts from anywhere in the app.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Reactive online status notifier.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Timer? _timer;
  bool _isChecking = false;

  /// Starts periodic connectivity checks (default: every 6 seconds).
  void startMonitoring({Duration interval = const Duration(seconds: 6)}) {
    _timer?.cancel();
    checkConnection();
    _timer = Timer.periodic(interval, (_) => checkConnection());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  /// Verifies active internet connectivity using DNS lookups and raw IP socket checks.
  Future<bool> checkConnection() async {
    if (_isChecking) return isOnline.value;
    _isChecking = true;

    bool connected = false;
    try {
      // 1. Google DNS domain lookup
      final googleCheck = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      connected = googleCheck.isNotEmpty && googleCheck[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        // 2. Cloudflare DNS domain lookup
        final cloudflareCheck = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 4));
        connected = cloudflareCheck.isNotEmpty && cloudflareCheck[0].rawAddress.isNotEmpty;
      } catch (_) {
        try {
          // 3. Raw TCP socket to Google Public DNS (8.8.8.8:53) - zero DNS dependency
          final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 3));
          socket.destroy();
          connected = true;
        } catch (_) {
          try {
            // 4. Raw TCP socket to Cloudflare DNS (1.1.1.1:53)
            final socket = await Socket.connect('1.1.1.1', 53, timeout: const Duration(seconds: 3));
            socket.destroy();
            connected = true;
          } catch (_) {
            connected = false;
          }
        }
      }
    } finally {
      _isChecking = false;
    }

    if (isOnline.value != connected) {
      isOnline.value = connected;
    }

    return connected;
  }

  /// Directly set to offline (e.g. called when an HTTP request fails with SocketException).
  void setOffline() {
    if (isOnline.value) {
      isOnline.value = false;
    }
  }

  /// Directly set to online.
  void setOnline() {
    if (!isOnline.value) {
      isOnline.value = true;
    }
  }

  bool _dialogOpen = false;

  /// Directly displays the [NoInternetDialog] if not already open.
  Future<bool> showNoInternetDialog({
    BuildContext? context,
    String? action,
    VoidCallback? onRetry,
  }) async {
    if (_dialogOpen) return false;
    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext != null && targetContext.mounted) {
      _dialogOpen = true;
      try {
        return await NoInternetDialog.show(
          targetContext,
          action: action,
          onRetry: onRetry,
        );
      } finally {
        _dialogOpen = false;
      }
    }
    return false;
  }

  /// Checks if internet is available. If not, automatically pops up the [NoInternetDialog].
  /// Returns `true` if connected, or `false` if offline.
  Future<bool> ensureConnected({
    BuildContext? context,
    String? action,
    VoidCallback? onRetry,
  }) async {
    final connected = await checkConnection();
    if (connected) return true;

    return showNoInternetDialog(
      context: context,
      action: action,
      onRetry: onRetry,
    );
  }
}
