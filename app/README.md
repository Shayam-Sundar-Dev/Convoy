# Convoy Flutter App

The client application for Convoy, built with Flutter, Provider, Mapbox Maps SDK, and Socket.IO.

## Getting Started

1. Follow the platform setup instructions in [`PLATFORM_SETUP.md`](PLATFORM_SETUP.md) for Mapbox download tokens and permissions.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run \
     --dart-define=MAPBOX_PUBLIC_TOKEN=pk.your-mapbox-public-token \
     --dart-define=CONVOY_API_BASE_URL=http://10.0.2.2:4000
   ```

For architecture, feature breakdowns, and backend setup, see the root [`README.md`](../README.md).
