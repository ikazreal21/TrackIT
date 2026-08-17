# TrackIT

A personal health analytics pipeline. A **Flutter** mobile app reads stats from
**Health Connect** (the data that your third-party watch writes to the Google
Fit / Health Connect app) and posts them to a local **FastAPI + SQLite** server
for you to store and analyze.

```
 Wearable watch
      │  (syncs automatically)
 Google Fit / Health Connect app  ── Android OS
      │                                   │
      └── Health Connect API ────────────┐│
                                         ▼
                              Flutter app (TrackIT)
                                         │  POST /api/records/batch
                                         ▼
                          FastAPI server + SQLite (local, LAN)
                                         │  analysis endpoints
                                         ▼
                                   charts / SQL / notebooks
```

## Features

- **Dark/Light mode** — toggle in app bar
- Reads health data from Health Connect (steps, heart rate, distance, calories, sleep, weight, height)
- Uploads data to local FastAPI server for storage and analysis
- Configurable day range for fetching data
- Server-side deduplication

---

## Why Health Connect and not Google Fit REST?

Google is deprecating the Google Fit REST API in favor of **Health Connect**.
Health Connect is where wearable data (steps, heart rate, sleep, weight, etc.)
now lives, so reading from it is the future-proof path and works without a
Google Cloud OAuth project.

---

## Repository layout

```
mobile/   Flutter app (reads Health Connect, pushes to server)
server/   Python FastAPI + SQLite server (storage & analysis)
```

---

## Part 1 — Run the FastAPI server

```bash
cd server
python -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

- Open `http://localhost:8000/docs` for interactive API docs.
- Endpoints:
  - `GET /health` — heartbeat
  - `POST /api/records/batch` — receive records from the app
  - `GET /api/records` — list stored records
  - `GET /api/summary` — totals/avg/min/max, grouped
  - `GET /api/summary/daily` — day-by-day totals for trend charts

Data is stored in `server/stats.db` (SQLite) — query it directly or import `database.py` for analysis.

> Make sure your phone and computer are on the **same Wi-Fi network**, and let
> the app reach your PC's LAN IP (e.g. `http://192.168.1.50:8000`), not
> `localhost`.

---

## Part 2 — Build & run the Flutter app

### Prerequisites

- Flutter SDK installed
- Android SDK (minSdkVersion 26)
- An Android device/emulator with the **Health Connect** app installed (Google Play).

### 1. Generate the platform scaffolding

```bash
cd mobile
flutter create --org com.example --platforms android .
flutter pub get
```

### 2. Add the Health Connect permissions

Edit `mobile/android/app/src/main/AndroidManifest.xml` and add:

```xml
<!-- Declare the Health Connect package so the OS can discover it -->
<queries>
    <package android:name="com.google.android.apps.healthdata" />
</queries>

<!-- Read permissions for the data types the app uses -->
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_SLEEP_SESSION"/>
<uses-permission android:name="android.permission.health.READ_WEIGHT"/>
<uses-permission android:name="android.permission.health.READ_HEIGHT"/>

<application
    ...>
    <!-- Declare Health Connect launcher -->
    <meta-data android:name="com.google.android.healthconnect.permission.HEALTH_DATA_INTENT"
               android:resource="@string/health_app_resource"/>
</application>
```

Then in `mobile/android/app/src/main/res/values/strings.xml` add:

```xml
<resources>
    <string name="health_app_resource">org.medic.health</string>
</resources>
```

### 3. Build & run

```bash
cd mobile
flutter run
```

### Using the app

1. **Toggle dark mode** — use the sun/moon icon in the app bar
2. **Grant access** — opens the Health Connect permission screen
3. **Fetch stats** — pulls steps / distance / calories / sleep
4. **Upload to server** — in Settings, enter `http://<your-PC-IP>:8000`, then upload. Records are deduplicated server-side.
5. Analyze via `/api/summary`, `/api/summary/daily`, or SQL on `stats.db`.

---

## Customizing which stats are tracked

Edit the `_types` list in `mobile/lib/services/health_connect_service.dart`.
Add the matching `<uses-permission>` line to the manifest for each new type.
The app reads whatever the watch + Health Connect expose; your watch simply has
to sync its sensor data into Health Connect in the first place.

---

## Files

**Mobile (Flutter)**
- `lib/main.dart` — app entry, theme configuration
- `lib/screens/home_screen.dart` — grant / fetch / upload flow + summary cards
- `lib/screens/settings_screen.dart` — server URL + date range
- `lib/services/health_connect_service.dart` — Health Connect reads
- `lib/services/api_service.dart` — HTTP upload to server
- `lib/services/settings_service.dart` — saved preferences
- `lib/models/health_data.dart` — serializable record model
- `lib/widgets/stat_card.dart` — stat display card

**Server (FastAPI)**
- `main.py` — API routes
- `database.py` — SQLite storage + aggregation queries
- `schemas.py` — request models
