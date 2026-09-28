# Convoy (Mapbox Edition)

A real-time group road-trip app for convoys travelling across multiple vehicles. One person hosts a trip and locks a route; everyone who joins follows that same route. The app tracks who's out front, how spread out the group is along the actual highway, groups travelers into vehicles with automotive car markers, provides push-to-talk voice radio, and handles shared trip expenses with fair-share splitting and trip archiving.

This variant uses **Mapbox** end-to-end (Directions API on the backend for multi-stop routing alternatives, and the Mapbox Maps SDK in the app for the interactive live map) paired with **PostgreSQL & Prisma ORM** for high-performance relational data storage and real-time Socket.IO WebSockets.

---

## Project Layout

```
convoy/
  server/   Node.js + Express + Socket.IO + PostgreSQL (Prisma ORM)
  app/      Flutter app (iOS + Android + Android Auto + Apple CarPlay from one codebase)
```

---

## Key Features & Architecture

### 1. Robust PostgreSQL & Prisma Data Architecture
- **PostgreSQL**: Industry-standard ACID-compliant relational database.
- **Prisma ORM**: Type-safe client, declarative migrations, and relational integrity.
- **Relational Data Model**:
  - `User`: Profiles with bcrypt password hashes and OAuth bindings.
  - `Convoy`: Trips with join codes, host references, locked polyline, and distance calculations.
  - `ConvoyMember`: Vehicle grouping, traveler role (host/client), seat occupancy, live GPS coordinates, and highway distance progression.
  - `Waypoint`: Intermediate planning points influencing route geometry.
  - `Stop`: Fuel, food, and rest stops plotted along the locked highway route.
  - `Message`: Chat and quick pings.
  - `RouteProposal`: Dynamic alternate route suggestions.
  - `Person`: Active traveler roster for expense tracking.
  - `ExpenseCategory`: Default and custom colored categories.
  - `Expense`: Itemized expenditure with payer and category relations.
  - `ExpenseSession`: Completed trip archives with serialized fair-share settlement breakdowns.

### 2. Vehicle Grouping & Interactive Car Markers
- **Vehicle Roster**: Multiple travelers can join the convoy under the same vehicle name (e.g. "Subaru Outback", "Ford Bronco").
- **Automotive Map Markers**: Vehicles appear as distinctive automotive car markers on the Mapbox map, displaying vehicle names and total passenger counts.
- **Unified Telemetry**: Location updates from any passenger in a vehicle update the vehicle's position on the convoy map.
- **Interactive Vehicle Sheet**: Tapping a vehicle marker reveals who is inside, their roles (driver/passenger), and their current lead or gap distance.

### 3. Drive Mode HUD & Screen Wakelock (Phase 1)
- **Glanceable Automotive HUD**: Jumbo 56pt high-contrast distance and gap readouts designed for safe glanceability while driving.
- **Display Wakelock**: Automatically prevents the phone screen from dimming or locking while in active driving mode.
- **Oversized PTT Controls**: Large, accessible push-to-talk button with tactile haptic feedback.
- **Road-Accurate Lead/Gap Tracking**: Telemetry projected onto the actual road curve using `distanceAlongRoute()` to compute true highway miles rather than straight-line Euclidean distance.
- **Straggler Alerts**: Instant notification if any car lags farther behind the convoy leader than the alert threshold (default 7,000 meters).

### 4. In-Car Head-Unit Integration: Android Auto & Apple CarPlay (Phase 2)
- **Android Auto**:
  - Native integration powered by `androidx.car.app:app:1.4.0` (`minSdk = 23`).
  - `ConvoyCarAppService` and `ConvoyCarScreen` render driver-safe navigation templates directly on the vehicle's dashboard.
  - Bidirectional telemetry bridge (`CarBridge.kt`) syncing leader distance, car gap, and radio status with the head-unit.
- **Apple CarPlay**:
  - Multi-scene architecture (`CPTemplateApplicationSceneSessionRoleApplication`) in `Info.plist`.
  - `CarPlaySceneDelegate.swift` and `CarBridge.swift` rendering native CarPlay information templates on the car console.
  - Independent phone and car screen lifecycles.

### 5. Smart Route Locking & Multi-Destination Planning
- **Mapbox Directions API**: Host enters origin, intermediate waypoints, and final destination. The backend queries Mapbox (`overview=full`) for driving alternatives.
- **Route Lock**: Locking writes the encoded polyline to PostgreSQL and broadcasts `route:locked` to everyone in the convoy room.
- **Dynamic Route Proposals**: Clients can propose alternate routes or new final destinations. The host can accept with a single tap, which immediately recalculates and auto-relocks the route for the entire convoy.
- **External Navigation Handoff**: Quick button to hand off the active route directly to Google Maps or Apple Maps.

### 6. Push-to-Talk Convoy Walkie-Talkie (Radio)
- **Live Voice Streaming**: Instant low-latency voice communication between all vehicles over WebSockets (`voice:status` and `voice:receive`).
- **Driver Indicator**: Real-time avatar banner displaying who is currently talking on the radio.
- **Mute & Privacy**: One-tap radio mute toggle so drivers can silence incoming chatter when needed.

### 7. Shared Trip Expenses & Fair-Share Split Tracker
- **Itemized Expenses**: Log expenses on the fly with title, amount, category, and payer.
- **Default & Custom Categories**: Preloaded with Fuel, Food & Drinks, Tolls, Lodging, Parking, and Other, plus support for creating, editing, and coloring custom categories.
- **Multi-Traveler Fair-Share Calculation**: Automatically computes total trip expenditure, individual contributions, and each traveler's net balance:
  - `+$XX.XX back` (green) for overpayers.
  - `-$XX.XX owes` (red) for underpayers.
  - `Settled` for even shares.
- **Trip Completion & History Archiving**:
  - Name and archive past road trip expense sessions with full itemized history.
  - **Detailed History Summary**: View exact participants list, amounts contributed by each traveler, fair-share settlement balances, and full transaction receipts.
  - **Clean Slate Reset**: Completing trip tracking clears the traveler roster and resets active expenses for the next adventure.

### 8. Minimalist Automotive UI & Universal Adaptive Icons
- **Minimalist Dialogs**: Streamlined, modern popups with high contrast and clean typography.
- **Automotive Dark Theme**: Road (`#0F1216`), Panel (`#181D24`), Stroke (`#262D37`), Amber accent (`#FFB300`), Signal Green (`#26A69A`), and Alert Red (`#EF5350`).
- **Universal Adaptive App Icons**: Full adaptive icon configuration (`mipmap-anydpi-v26`) supporting Square, Circle, Squircle, and Teardrop launcher shapes seamlessly.

---

## Getting the Server Running

### Prerequisites
- Node.js 18+ (tested on Node v25)
- Docker & Docker Compose (or a local/cloud PostgreSQL instance)
- Mapbox access token

### Steps

```bash
cd server
cp .env.example .env
```

Edit `server/.env` with your values:

```env
DATABASE_URL="postgresql://convoy:convoy@localhost:5432/convoy?schema=public"
JWT_SECRET="generate-a-long-random-string"
MAPBOX_ACCESS_TOKEN="pk.your-mapbox-directions-token"
PORT=4000
```

#### 1. Start PostgreSQL (Docker)
```bash
npm run docker:up
```

#### 2. Run Database Migrations
```bash
npm run prisma:generate
npm run prisma:migrate
```

#### 3. Start the Server
```bash
npm run dev
```

Verify server health:
```bash
curl http://localhost:4000/health
# Returns: {"ok":true}
```

Optional: inspect data in a web UI:
```bash
npm run prisma:studio
```

---

## Getting the App Running

### 1. Platform Setup & Mapbox Tokens
Mapbox requires two tokens:
1. **Public token (`pk.*`)**: Used at runtime by the app to load tiles and render maps.
2. **Secret downloads token (`sk.*`)**: Configured once in `android/gradle.properties` and `ios/.netrc` to allow Gradle and CocoaPods to download the Mapbox Maps SDK binaries.

👉 **See [`app/PLATFORM_SETUP.md`](app/PLATFORM_SETUP.md) for full Android Auto, Apple CarPlay, Screen Wakelock, Adaptive App Icon, and permissions configuration.**

### 2. Running Flutter

```bash
cd app
flutter pub get
flutter run \
  --dart-define=MAPBOX_PUBLIC_TOKEN=pk.your-mapbox-public-token \
  --dart-define=CONVOY_API_BASE_URL=http://10.0.2.2:4000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

#### Network Target Table:
| Environment | `CONVOY_API_BASE_URL` |
|---|---|
| **Android Emulator** | `http://10.0.2.2:4000` |
| **iOS Simulator** | `http://localhost:4000` |
| **Physical Phone (Local Wi-Fi)** | `http://192.168.1.X:4000` |
| **Hosted Backend** | `https://api.yourdomain.com` |

> [!TIP]
> - For instant local testing without Google Cloud Console setup, you can register and sign in with any email and password directly on the login screen.

---

## API & Socket Events Overview

### REST Endpoints

| Category | Endpoint | Method | Description |
|---|---|---|---|
| **Auth** | `/auth/register` | `POST` | Register with email & password |
| | `/auth/login` | `POST` | Login with email & password |
| | `/auth/google` | `POST` | Google Sign-In with ID token |
| | `/auth/apple` | `POST` | Apple Sign-In with Identity token |
| **Convoys** | `/convoys` | `POST` | Create a convoy and fetch initial route options |
| | `/convoys/join` | `POST` | Join a convoy with a 6-character code and vehicle info |
| | `/convoys/:code/options` | `GET` | Retrieve route alternatives |
| | `/convoys/:code/lock` | `POST` | Lock selected route & stops |
| | `/convoys/:code/reroute`| `POST` | Update active route destination or waypoints |
| | `/convoys/:code/end` | `POST` | End convoy (host only) |
| **Expenses** | `/expenses` | `GET` | Fetch active expenses, categories, and travelers |
| | `/expenses` | `POST` | Add a new expense |
| | `/expenses/:id` | `DELETE` | Delete an expense |
| | `/expenses/people` | `POST` | Add a traveler to active tracking |
| | `/expenses/people/:id` | `DELETE` | Remove a traveler from active tracking |
| | `/expenses/categories` | `POST` | Add a custom category |
| | `/expenses/categories/:id` | `PATCH`/`DELETE` | Edit or delete a category |
| | `/expenses/complete-session` | `POST` | Archive trip expenses to history and reset active people |
| | `/expenses/history` | `GET` | List past trips with detailed participant breakdown |
| | `/expenses/history/:id` | `DELETE` | Delete a past trip record |

### Real-Time Socket.IO Events

| Event | Direction | Payload / Purpose |
|---|---|---|
| `convoy:enter` | Client → Server | Join convoy room (`code`) |
| `location:ping` | Client → Server | Stream device latitude/longitude and vehicle status |
| `convoy:ranked` | Server → Room | Broadcast real-time order, car markers, and lead/gap meters |
| `convoy:straggler-alert` | Server → Room | Trigger alert when vehicle exceeds max gap |
| `voice:status` | Bidirectional | Broadcast transmitting state for PTT Walkie-Talkie |
| `voice:receive` | Server → Room | Low-latency audio packet delivery |
| `expense:new` | Server → Room | Broadcast newly logged expense |
| `expense:deleted` | Server → Room | Broadcast deleted expense |
| `person:new` / `person:deleted` | Server → Room | Sync active travelers across devices |
| `expense:session_completed` | Server → Room | Broadcast trip completion & reset to all devices |
| `route:locked` | Server → Room | Broadcast locked polyline and stops |
| `proposal:new` / `proposal:resolved` | Bidirectional | Client route proposals and host response |
