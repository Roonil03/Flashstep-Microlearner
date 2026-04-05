# Installation Guide:

## Requirements
Common:
- Docker + Docker Compose
- Go
- Flutter SDK
- Dart SDK (usually bundled with Flutter)
- GNU Make

Android phone targets additionally need:
- `adb`
- USB debugging enabled on the phone

### Windows note
Use GNU Make from one of these:
- Git Bash
- MSYS2
- WSL
- mingw32-make

## Recommended first-time setup
From the repository root:

```bash
make bootstrap-dev
```

That will:
1. check the required tools
2. create `backend/.env` with development defaults
3. install Go and Flutter dependencies
4. start the backend Docker stack
5. run the PostgreSQL migrations
6. run Flutter code generation

## If you want custom backend credentials

Instead of defaults, run:

```bash
make backend-env
make deps
make backend-up
make backend-migrate
make frontend-codegen
```

## Local development flows

### Run the full app locally

Start the backend stack:

```bash
make backend-up
```

Then run Flutter:

```bash
make frontend-run
```

### Run the Go API on your host machine

If you want the API process to run outside Docker, while PostgreSQL stays in Docker:

```bash
make backend-up
make backend-run-local
```
<!-- 
That target temporarily overrides the DB connection to `localhost:5433` for the host-run Go process. -->

## Android phone development

If the app still points to `localhost:8080`, a real phone cannot reach your laptop directly.
For development, use:

```bash
make phone-dev
```

That runs:
- `adb reverse tcp:8080 tcp:8080`
- `flutter run`

So the phone can talk to your local backend through USB.

## Build APKs

### Debug APK

```bash
make apk-debug
```

### Universal release APK

```bash
make apk-release
```

Output:
- `frontend/build/app/outputs/flutter-apk/app-release.apk`

### Split-per-ABI release APKs

```bash
make apk-release-split
```

## Install on a connected Android phone

### Debug

```bash
make apk-install-debug
```

### Release

```bash
make apk-install-release
```

## Use it like a normal user

A release APK only behaves like a normal end-user app if the frontend is configured to talk to a backend URL the phone can actually reach.

That means one of these must be true:
- the backend is deployed publicly, and `frontend/lib/core/config/api_config.dart` points to that public host
- the phone is on the same network and `api_config.dart` points to your computer's LAN IP
- or you are doing development over USB with `make phone-dev`

If `api_config.dart` still uses `localhost`, only the USB/ADB dev flow will work on a real phone.

## Useful backend targets

```bash
make backend-logs
make backend-psql
make backend-down
make backend-reset
```

## Clean Flutter build artifacts

```bash
make clean
```
