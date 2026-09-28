# Platform Setup (Android + iOS) — Mapbox & In-Car Systems

This guide explains how to configure native platform settings for Convoy, including Mapbox Maps, backend connectivity, in-car systems (**Android Auto** and **Apple CarPlay**), screen wakelock keep-awake, background GPS tracking, push-to-talk microphone audio, universal adaptive app icons, and social authentication.

---

## 1. Mapbox Access Tokens

Mapbox splits access into two tokens:
1. **Public token (starts with `pk.`)**: Used at runtime by the Flutter app to load map styles, render vector tiles, and geocode locations. Passed via `--dart-define=MAPBOX_PUBLIC_TOKEN=pk....`.
2. **Secret downloads token (starts with `sk.`, requires `DOWNLOADS:READ` scope)**: Used only during builds to download native Mapbox SDK binaries via Gradle or CocoaPods. It is never bundled into the app binary.

Create both at [account.mapbox.com/access-tokens](https://account.mapbox.com/access-tokens/).

---

## 2. Android Configuration

### A. Secret Downloads Token
Add your downloads token to `android/gradle.properties` (or `~/.gradle/gradle.properties` to keep it global and out of version control):

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.your-secret-downloads-token
```

### B. Mapbox Maven Repository
In `android/build.gradle` (or `settings.gradle.kts` depending on Gradle setup), ensure the authenticated Mapbox Maven repository is declared:

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url 'https://api.mapbox.com/downloads/v2/releases/maven'
            authentication { basic(BasicAuthentication) }
            credentials {
                username = "mapbox"
                password = project.properties['MAPBOX_DOWNLOADS_TOKEN'] ?: ""
            }
        }
    }
}
```

### C. SDK Requirements
In `android/app/build.gradle.kts` (or `build.gradle`), set:
- **`minSdk = 23`** (Mandatory requirement for Android Auto `androidx.car.app:app:1.4.0`)
- **`compileSdk = 34`**
- **`targetSdk = 34`**

```kotlin
android {
    defaultConfig {
        applicationId = "com.example.convoy"
        minSdk = 23
        targetSdk = 34
        ...
    }
}

dependencies {
    // Android Auto App Library
    implementation("androidx.car.app:app:1.4.0")
}
```

### D. Android Auto Native In-Car Integration
Convoy includes native head-unit support for vehicle dashboards running Android Auto:
1. **Automotive App Descriptor** (`android/app/src/main/res/xml/automotive_app_desc.xml`):
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <automotiveApp>
       <uses name="template" />
   </automotiveApp>
   ```

2. **Permissions & Service Declaration** in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <!-- Android Auto Car App Permissions -->
   <uses-permission android:name="androidx.car.app.ACCESS_SURFACE" />
   <uses-permission android:name="androidx.car.app.NAVIGATION_TEMPLATES" />

   <application ...>
       <!-- Car App Metadata -->
       <meta-data
           android:name="com.google.android.gms.car.application"
           android:resource="@xml/automotive_app_desc" />
       <meta-data
           android:name="androidx.car.app.minCarApiLevel"
           android:value="1" />

       <!-- Car App Service -->
       <service
           android:name=".ConvoyCarAppService"
           android:exported="true">
           <intent-filter>
               <action android:name="androidx.car.app.CarAppService" />
               <category android:name="androidx.car.app.category.NAVIGATION" />
           </intent-filter>
       </service>
   </application>
   ```

3. **Kotlin Car Services**:
   - `ConvoyCarAppService.kt`: Entry point service extending `CarAppService`.
   - `ConvoyCarSession.kt`: Manages the in-car session lifecycle.
   - `ConvoyCarScreen.kt`: Renders high-contrast, automotive-safe navigation templates showing convoy leader status, distance gap, active vehicle count, and radio status.
   - `CarBridge.kt`: Event bridge synchronizing live convoy telemetry between Flutter and the car display.

4. **Testing with Desktop Head Unit (DHU)**:
   - Install the **Desktop Head Unit** via Android Studio SDK Manager (`Extras > Android Auto Desktop Head Unit emulator`).
   - Enable Developer Settings in the Android Auto app on your mobile test device or emulator.
   - Start the head unit server: `adb forward tcp:5277 tcp:5277`
   - Run the DHU binary: `desktop-head-unit` to simulate an in-dash automotive screen.

### E. Screen Wakelock & Drive Mode HUD
Road trips require the navigation screen to remain active without dimming or locking while driving:
- **Permission**: Ensure `<uses-permission android:name="android.permission.WAKE_LOCK" />` is present in `AndroidManifest.xml`.
- **Behavior**: Entering **Drive Mode HUD** in the app automatically acquires a display wakelock, ensuring uninterrupted glanceable telemetry.

### F. Permissions & Background Location
In `android/app/src/main/AndroidManifest.xml`, ensure the following permissions are present:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- GPS & Background Location -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

    <!-- Push-to-Talk Walkie-Talkie Microphone -->
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>

    <!-- In-Car & Display -->
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="androidx.car.app.ACCESS_SURFACE"/>
    <uses-permission android:name="androidx.car.app.NAVIGATION_TEMPLATES"/>

    <!-- Networking -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### G. Universal Adaptive App Icons (Square, Circle, Squircle)
Convoy provides full adaptive icon support conforming to all Android launcher mask shapes (Circle, Squircle, Rounded Square, Teardrop):
- **Vector / Resource definitions**:
  - `res/mipmap-anydpi-v26/ic_launcher.xml`
  - `res/mipmap-anydpi-v26/ic_launcher_round.xml`
- **Asset breakdown**:
  - **Background**: Solid automotive dark canvas `@color/ic_launcher_background` (`#0F1216`).
  - **Foreground**: High-resolution centered emblem `@mipmap/ic_launcher_foreground` scaled within the safe zone (66dp inner circle) to prevent clipping under squircle and circular masks.
  - **Fallback raster icons**: Densities from `mdpi` through `xxxhdpi` are configured for both `ic_launcher.png` and `ic_launcher_round.png`.

### H. Google Sign-In Setup & Gradle Configuration
Google Sign-In on Android requires proper Gradle plugin integration, an OAuth Android client with your machine's debug SHA-1, and an OAuth Web client ID for backend verification.

#### 1. Gradle Plugins Configuration
In `android/settings.gradle.kts`, declare the Google Services plugin:
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

In `android/app/build.gradle.kts`, apply the plugin at the top:
```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
```
*(Note: Never add `id("dev.flutter.flutter-gradle-plugin")` to the root `android/build.gradle.kts`, as that will cause task name collisions like `Cannot add task 'generateLockfiles'`)*.

#### 2. Generate Debug SHA-1 Fingerprint
Run in your terminal to get the SHA-1 of your machine's debug keystore:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```
*(On macOS if `keytool` is not in your PATH)*:
```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### 3. Register in Google Cloud Console / Firebase Console
1. Under **OAuth 2.0 Client IDs** (or Firebase Project Settings > Your Android App), create/edit the **Android Client ID**.
2. Set Package Name: `com.example.convoy` (must match `applicationId` in `android/app/build.gradle.kts`).
3. Add the **SHA-1** fingerprint retrieved above.
4. Download the updated `google-services.json` and place it in `android/app/google-services.json`.

#### 4. Web Client ID for Server Verification
Google Sign-In requires an OAuth **Web Application** Client ID to produce an `idToken` for the backend:
- Pass the Web Client ID at runtime:
  `--dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com`
- If you encounter `ApiException: 7` (`network_error`), ensure the emulator has working internet access (toggle Airplane mode to refresh DNS) and that your machine's SHA-1 matches the registered client.

---

## 3. iOS Configuration

### A. Secret Downloads Token (`.netrc`)
In your user home directory (or inside `ios/.netrc`, ignored by git), add:

```
machine api.mapbox.com
login mapbox
password sk.your-secret-downloads-token
```

Then configure Xcode:
```bash
defaults write com.apple.dt.Xcode IDEPackageSupportUseBuiltinSCM YES
```

### B. Apple CarPlay Native Integration
Convoy supports in-car dashboard displays via native CarPlay templates:
1. **Multi-Scene Manifest** in `ios/Runner/Info.plist`:
   ```xml
   <key>UIApplicationSceneManifest</key>
   <dict>
       <key>UIApplicationSupportsMultipleScenes</key>
       <true/>
       <key>UISceneConfigurations</key>
       <dict>
           <key>CPTemplateApplicationSceneSessionRoleApplication</key>
           <array>
               <dict>
                   <key>UISceneClassName</key>
                   <string>CPTemplateApplicationScene</string>
                   <key>UISceneConfigurationName</key>
                   <string>CarPlay</string>
                   <key>UISceneDelegateClassName</key>
                   <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
               </dict>
           </array>
           <key>UIWindowSceneSessionRoleApplication</key>
           <array>
               <dict>
                   <key>UISceneClassName</key>
                   <string>UIWindowScene</string>
                   <key>UISceneConfigurationName</key>
                   <string>flutter</string>
                   <key>UISceneDelegateClassName</key>
                   <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                   <key>UISceneStoryboardFile</key>
                   <string>Main</string>
               </dict>
           </array>
       </dict>
   </dict>
   ```

2. **Swift CarPlay Architecture**:
   - `CarPlaySceneDelegate.swift`: Adopts `CPTemplateApplicationSceneDelegate`, creating a `CPInformationTemplate` or `CPNavigationAlert` showing convoy status, lead car gap, and radio status.
   - `SceneDelegate.swift`: Manages the standard phone window UI independently from the car screen.
   - `CarBridge.swift`: Manages communication between Flutter's telemetry stream and CarPlay templates.

3. **CarPlay Entitlement**:
   - For distribution or device testing, request the CarPlay Navigation entitlement from Apple (`com.apple.developer.carplay-maps`).
   - For simulator testing, Xcode provides an interactive CarPlay simulator window under `I/O > External Displays > CarPlay`.

### C. Info.plist Permissions & Mapbox Token
Ensure `ios/Runner/Info.plist` contains the following keys:

```xml
<!-- Mapbox Public Access Token -->
<key>MBXAccessToken</key>
<string>pk.your-public-token</string>

<!-- Location Permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Convoy tracks your vehicle's position to show your location on the group convoy map.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Convoy keeps your vehicle's position synchronized with the group while the app is in the background.</string>

<!-- Microphone Permission (Push-to-Talk Radio) -->
<key>NSMicrophoneUsageDescription</key>
<string>Convoy uses your microphone for the push-to-talk voice radio with your convoy.</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
</array>
```

### D. Apple Sign-In
In Xcode, open `ios/Runner.xcworkspace`:
1. Select the **Runner** target.
2. Go to **Signing & Capabilities**.
3. Click **+ Capability** and add **Sign In with Apple**.

---

## 4. Connecting the App to the Convoy Backend

Pass the runtime configuration keys to Flutter using `--dart-define`:

```bash
flutter run \
  --dart-define=MAPBOX_PUBLIC_TOKEN=pk.your-mapbox-public-token \
  --dart-define=CONVOY_API_BASE_URL=http://10.0.2.2:4000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

### Server URL Targets by Environment:

| Target Environment | `CONVOY_API_BASE_URL` | Description |
|---|---|---|
| **Android Emulator** | `http://10.0.2.2:4000` | Points to host machine's `localhost:4000` via Android loopback |
| **iOS Simulator** | `http://localhost:4000` | Points directly to local machine server |
| **Physical Phone (Wi-Fi)** | `http://192.168.1.X:4000` | Replace `192.168.1.X` with your computer's local Wi-Fi IP |
| **Hosted Production Server** | `https://api.yourdomain.com` | Production server with full WebSocket support |

---

## 5. Opening Routes in External Maps

The app provides one-tap handoff to external navigation apps using standard URI schemes:
- **Google Maps**:
  `https://www.google.com/maps/dir/?api=1&origin=...&destination=...&waypoints=...`
- **Apple Maps**:
  `https://maps.apple.com/?saddr=...&daddr=...`

These links hand off cleanly without requiring custom URL scheme declarations.
