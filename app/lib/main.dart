import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'services/connectivity_service.dart';
import 'state/convoy_state.dart';
import 'theme/theme.dart';
import 'screens/splash_screen.dart';

/// Mapbox's *public* token, used by the map widget at runtime. This is
/// separate from the server's MAPBOX_ACCESS_TOKEN (used for Directions API
/// calls) — same account, but keep them as distinct tokens in production
/// so you can scope/rotate each independently. See app/PLATFORM_SETUP.md.
const String mapboxPublicToken = String.fromEnvironment(
  'MAPBOX_PUBLIC_TOKEN',
  defaultValue: 'pk.your-mapbox-public-token',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxPublicToken);
  runApp(const ConvoyApp());
}

class ConvoyApp extends StatelessWidget {
  const ConvoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConvoyState()..restoreSession(),
      child: MaterialApp(
        title: 'Convoy',
        debugShowCheckedModeBanner: false,
        navigatorKey: ConnectivityService.navigatorKey,
        theme: buildConvoyTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
