# ChargeAlarm 🔋⚡
### 80% Battery Protection, Music Alarm (Spotify / JioSaavn) & In-App APK Sharing

**ChargeAlarm** is an Android application that protects your phone's battery health. When the battery reaches **80%** while plugged in, it triggers a high-priority alert notification and automatically launches/plays your preferred song on **Spotify**, **JioSaavn**, or a custom audio stream.

It also features a built-in **"SHARE APK"** button powered by `share_plus` to send the compiled `.apk` directly to contacts via WhatsApp, Telegram, or Nearby Share.

---

## 🚀 Quick Setup & Build Instructions

### 1. Clone & Open
```bash
git clone https://github.com/<your-username>/ChargeAlarm.git
cd ChargeAlarm
```

### 2. Fetch Dependencies
```bash
flutter pub get
```

### 3. Build the Debug APK (.apk)
```bash
flutter build apk --debug
```
The compiled APK will be generated at:
```
build/app/outputs/flutter-apk/app-debug.apk
```

*(For a release build: `flutter build apk --release` -> Output: `build/app/outputs/flutter-apk/app-release.apk`)*

---

## 📲 How to Install & Share via WhatsApp

### Option A: Direct Installation via ADB (Fastest)
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Option B: In-App WhatsApp Sharing
1. Install the APK once onto any Android phone.
2. Tap the **SHARE APK** button in the dashboard (or top-right share icon).
3. The Android system share sheet will open with **WhatsApp**.
4. Select any chat or contact to send the `.apk` file directly so they can install it immediately!

---

## 📦 Project Architecture

```
ChargeAlarm/
├── .gitignore                                        # Standard Flutter & Android exclusions
├── pubspec.yaml                                      # battery_plus, url_launcher, share_plus, etc.
├── android/
│   ├── app/
│   │   ├── build.gradle                              # compileSdk 34, desugaring enabled
│   │   └── src/main/
│   │       ├── AndroidManifest.xml                   # Battery, Foreground service & Intent queries
│   │       └── kotlin/com/chargealarm/app/
│   │           └── MainActivity.kt                   # Native APK path provider MethodChannel
│   ├── build.gradle
│   ├── gradle.properties
│   └── settings.gradle
└── lib/
    ├── main.dart                                     # Dashboard UI with Share APK via WhatsApp
    └── services/
        └── battery_service.dart                      # Battery monitor, notification & music triggers
```

---

## 🎵 Supported Music Platforms & Formats

| Platform | Format Example | Action on 80% Trigger |
| :--- | :--- | :--- |
| **Spotify** | `spotify:track:4cOdK2wGLETKBW3PvgPWqT` or web link | Launches Spotify app directly or opens web player fallback |
| **JioSaavn** | `jiosaavn://` or `https://www.jiosaavn.com/song/...` | Launches JioSaavn app directly or web player |
| **Default Ringtone/URL** | `https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg` | Streams web alarm audio stream via device browser / audio handler |
