import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/convoy.dart';
import '../theme/theme.dart';

/// Opens the convoy's already-chosen route (start → waypoints → final
/// destination, in order) in an external maps app, so someone can navigate
/// with the turn-by-turn app they actually trust instead of this app's own
/// map. Deliberately uses each provider's universal *https* link format
/// rather than a custom URL scheme (e.g. comgooglemaps://): those https
/// links work identically on iOS and Android, hand off to the native app
/// if it's installed, fall back to the mobile website if it isn't, and —
/// unlike custom schemes — don't require declaring LSApplicationQueriesSchemes
/// in Info.plist just to check whether the app exists.
class ExternalMaps {
  /// https://developers.google.com/maps/documentation/urls/get-started
  static Uri googleMapsUrl(Convoy convoy) {
    final origin = '${convoy.startLat},${convoy.startLng}';
    // Google's "destination" param name is historical — it always means the
    // final stop, not literally convoy.destLabel; kept as-is for clarity here.
    final destination = '${convoy.destLat},${convoy.destLng}';
    final waypoints = convoy.waypoints.map((w) => '${w.lat},${w.lng}').join('|');

    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': origin,
      'destination': destination,
      if (waypoints.isNotEmpty) 'waypoints': waypoints,
      'travelmode': 'driving',
    });
  }

  /// Apple Maps doesn't support multi-waypoint links the way Google's does
  /// — the public URL scheme only takes a single origin/destination pair.
  /// For a trip with intermediate stops, this links to the *first* leg
  /// (start → first waypoint) rather than silently dropping the rest of
  /// the trip and pretending it's the whole route.
  static Uri appleMapsUrl(Convoy convoy) {
    final origin = '${convoy.startLat},${convoy.startLng}';
    final firstLeg = convoy.waypoints.isNotEmpty
        ? '${convoy.waypoints.first.lat},${convoy.waypoints.first.lng}'
        : '${convoy.destLat},${convoy.destLng}';

    return Uri.https('maps.apple.com', '/', {
      'saddr': origin,
      'daddr': firstLeg,
      'dirflg': 'd', // driving
    });
  }

  static Future<bool> openGoogleMaps(Convoy convoy) => launchUrl(
        googleMapsUrl(convoy),
        mode: LaunchMode.externalApplication,
      );

  static Future<bool> openAppleMaps(Convoy convoy) => launchUrl(
        appleMapsUrl(convoy),
        mode: LaunchMode.externalApplication,
      );

  /// Shows a small chooser so the person picks which app opens — Convoy
  /// itself has no way to know which one they actually have installed or
  /// prefer, and guessing wrong is worse than asking once.
  static Future<void> showChooser(BuildContext context, Convoy convoy) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: ConvoyColors.panel2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Open route in', style: TextStyle(color: ConvoyColors.muted, fontSize: 12.5)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map, color: ConvoyColors.amber),
                title: const Text('Google Maps'),
                subtitle: convoy.waypoints.isNotEmpty
                    ? null
                    : const Text('Opens with your route already filled in', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  openGoogleMaps(convoy);
                },
              ),
              if (Platform.isIOS)
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: ConvoyColors.signal),
                  title: const Text('Apple Maps'),
                  subtitle: convoy.waypoints.isNotEmpty
                      ? const Text('Only supports the first leg of a multi-stop trip', style: TextStyle(fontSize: 12))
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openAppleMaps(convoy);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
