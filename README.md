# TrackIT

TrackIT is a personal health-data tracker. The Flutter Android app reads data
from Health Connect, stores a local copy on the phone, and uploads records to a
FastAPI + SQLite server that you control.

```text
Wearable/watch -> Health Connect -> TrackIT Android app
                                      |
                                      v
                              FastAPI + SQLite server
```

## Features

- Reads steps, distance, heart rate, calories, sleep, weight, and height from Health Connect.
- Persists fetched records locally on the phone using SQLite.
- Restores previously fetched data when the app starts.
- Checks Health Connect permissions automatically on startup.
- Merges newly fetched records without local duplicates.
- Uploads records to a local server with server-side deduplication.
- Configurable fetch range from 1 to 365 days.
- Optional weekly background sync using Android WorkManager.
- Light/dark mode toggle.
- Blue TrackIT launcher icon.
- FastAPI web dashboard and interactive API documentation.

## Repository Layout

```text
mobile/   Flutter Android app
server/   FastAPI + SQLite server
```

## Server With Docker

The Docker server listens on port `4031`. Its SQLite database is stored in the
Linux host directory `server/data/`.

```bash
cd server
docker compose up -d --build
```

Useful URLs on the host machine:

```text
Dashboard: http://localhost:4031/
API docs:  http://localhost:4031/docs
Health:    http://localhost:4031/health
```

From another device on the same LAN, replace `localhost` with the server's LAN
IP, for example:

```text
http://192.168.50.76:4031/
```

The phone and server must be on the same network. The Linux firewall must also
allow incoming TCP connections on port `4031` if the phone cannot connect.

To inspect logs:

```bash
docker compose logs -f
```

To stop the server:

```bash
docker compose down
```

Do not map `./stats.db` directly as a Docker file volume. The compose file
maps `./data` to `/app/data` and sets `DATA_DIR=/app/data` so SQLite can create
its database and WAL files correctly.

## Server Without Docker

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 4031
```

The database is created as `server/stats.db` when `DATA_DIR` is not set.

## API Endpoints

- `GET /` - web dashboard
- `GET /health` - server heartbeat
- `POST /api/records/batch` - upload records from the app
- `GET /api/records` - list stored records
- `GET /api/summary` - aggregate records by type
- `GET /api/summary/daily` - aggregate records by calendar day
- `GET /docs` - Swagger API documentation

## Flutter Prerequisites

- Flutter SDK
- Android SDK and platform tools
- Android 9/API 28 or newer
- Android device or emulator with Health Connect available
- A wearable or app that has written data into Health Connect

Check the local Flutter setup with:

```bash
flutter doctor
```

## Android Health Connect Setup

The Android platform files are already included in this repository. If the
`mobile/android/` directory is missing in a fresh checkout, generate it with:

```bash
cd mobile
flutter create --org com.example --platforms android .
```

The project manifest includes the required Health Connect read permissions,
Health Connect package visibility, the permission-rationale intent filter, and
the permission usage activity alias. `MainActivity` extends
`FlutterFragmentActivity`, which is required by the Health Connect permission
activity-result flow on newer Android versions.

Health Connect must be installed and configured on the phone. After installing
TrackIT, open Health Connect → App permissions → TrackIT and verify that the
desired data types, especially Sleep, are allowed.

## Run the App Locally

```bash
cd mobile
flutter pub get
flutter run
```

In the app:

1. Grant Health Connect access the first time.
2. Open Settings and enter the server URL, for example `http://192.168.50.76:4031`.
3. Choose the history range, up to 365 days.
4. Fetch stats. Records are saved locally on the phone.
5. Upload the records to the server.
6. Optionally enable weekly auto-sync in Settings.

After the first successful authorization, TrackIT checks the existing Health
Connect permission automatically when it starts. You should not need to grant
access again unless the permission is revoked or the app is reinstalled.

## Build an APK

```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```

The APK is generated at:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Install it with Android Debug Bridge when the phone is connected and USB
debugging is enabled:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Background Sync Notes

Enable **Auto-sync weekly** in Settings after saving the server URL and granting
Health Connect access. WorkManager schedules the task when network connectivity
is available.

Android may delay background work because of battery optimization, Doze mode,
manufacturer restrictions, or Health Connect background-access rules. For more
reliable testing, exclude TrackIT from battery optimization on the phone.

The server must be reachable from the phone at the configured LAN address. A
server URL using `localhost` will not work from a physical phone because it
refers to the phone itself.

## Data Storage

The app stores its fetched records in a local SQLite database on the phone.
Settings such as the server URL, fetch range, and auto-sync preference use
SharedPreferences.

The server stores uploaded records in SQLite. Docker stores the database under
`server/data/` so it survives container rebuilds and restarts.

## Customizing Tracked Data

Edit the `_types` list in:

```text
mobile/lib/services/health_connect_service.dart
```

When adding a Health Connect type, also add its matching Android read
permission to `mobile/android/app/src/main/AndroidManifest.xml`. The watch or
source app must first sync that data type into Health Connect.

## Main Files

### Mobile

- `lib/main.dart` - app entry point and WorkManager initialization
- `lib/screens/home_screen.dart` - permissions, fetching, persistence, upload, and stat cards
- `lib/screens/settings_screen.dart` - server URL, history range, and auto-sync
- `lib/screens/about_screen.dart` - app information and privacy description
- `lib/services/health_connect_service.dart` - Health Connect access
- `lib/services/local_storage_service.dart` - local SQLite records
- `lib/services/background_sync_service.dart` - weekly background sync
- `lib/services/api_service.dart` - server communication
- `lib/services/settings_service.dart` - saved preferences
- `lib/models/health_data.dart` - health record model

### Server

- `main.py` - FastAPI routes and dashboard
- `database.py` - SQLite storage and aggregation queries
- `schemas.py` - API request models
- `Dockerfile` - server image
- `docker-compose.yml` - server deployment and persistent storage
