import 'dart:io';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../theme/theme.dart';

/// Minimalist automotive-grade dialog informing the user that an internet connection is required.
class NoInternetDialog extends StatefulWidget {
  final String? action;
  final VoidCallback? onRetry;

  const NoInternetDialog({
    super.key,
    this.action,
    this.onRetry,
  });

  static Future<bool> show(
    BuildContext context, {
    String? action,
    VoidCallback? onRetry,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => NoInternetDialog(action: action, onRetry: onRetry),
    );
    return result ?? false;
  }

  @override
  State<NoInternetDialog> createState() => _NoInternetDialogState();
}

class _NoInternetDialogState extends State<NoInternetDialog> {
  bool _checking = false;
  String? _statusMessage;

  Future<void> _handleRetry() async {
    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    final isOnline = await ConnectivityService.instance.checkConnection();

    if (!mounted) return;

    if (isOnline) {
      widget.onRetry?.call();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _checking = false;
        _statusMessage = 'Still offline. Please check your Wi-Fi or mobile data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionText = widget.action != null
        ? 'to ${widget.action}'
        : 'for this action';

    return AlertDialog(
      backgroundColor: ConvoyColors.panel2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ConvoyColors.stroke, width: 1),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ConvoyColors.alert.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ConvoyColors.alert.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: ConvoyColors.alert,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'No Internet Connection',
                  style: TextStyle(
                    color: ConvoyColors.paint,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'An active internet connection is required $actionText. Please reconnect to Wi-Fi or mobile data and try again.',
            style: const TextStyle(
              color: ConvoyColors.muted,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ConvoyColors.alert.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ConvoyColors.alert.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: ConvoyColors.alert),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(
                        color: ConvoyColors.alert,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: ConvoyColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: const Text('Dismiss', style: TextStyle(fontSize: 13.5)),
        ),
        ElevatedButton(
          onPressed: _checking ? null : _handleRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: ConvoyColors.amber,
            foregroundColor: const Color(0xFF14110A),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF14110A),
                  ),
                )
              : const Text(
                  'Retry',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}

