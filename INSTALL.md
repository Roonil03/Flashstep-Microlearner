# Installation Guide:

## Requirements
Common:
- Docker + Docker Compose
- Go with automatic toolchain selection enabled, or Go 1.27.4 (the version used for the production server image)
- Flutter SDK
- Dart SDK (usually bundled with Flutter)
- GNU Make

Android phone targets additionally need:
- `adb`
- USB debugging enabled on the phone

### Windows note
Native Windows builds use the Bash shell bundled with Git for Windows. Alternatively, run GNU Make and Bash inside WSL.

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

### Upgrade an existing PostgreSQL database to v1.3.0

Back up the existing database. Apply both v1.3.0 migrations to the database that serves the API **before deploying** the new backend. An existing Docker volume does not run initialization scripts again.

For the local Compose stack, run `make backend-migrate`. For a hosted PostgreSQL instance, use the deployment's migration connection with `psql` from the repository root:

```sh
psql -v ON_ERROR_STOP=1 -f backend/migrations/02_daily_login_purge.sql
psql -v ON_ERROR_STOP=1 -f backend/migrations/02_bug_reports.sql
```

These commands use the connection configured for `psql`. Check the target database before running them. A new, empty database requires `backend/migrations/01_init.sql` first. The daily cleanup migration preserves historical review references when cards are permanently removed. Applying it can take locks while it backfills those references.

Keep the existing strong `JWT_SECRET` across deploys. The API requires at least 32 characters. If the old secret needs replacement, existing users will have to sign in again. Set `TRUSTED_PROXY_CIDRS` only to the known addresses of reverse proxies that sanitize forwarding headers. Direct deployments can leave it unset. Public bug reporting requires additional GitHub configuration. [Bug reporting setup](docs/bug_reporting.md)

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

To run against the local backend over USB, use:

```bash
make phone-dev
```

That runs:
- `adb reverse tcp:8080 tcp:8080`
- `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1`

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
