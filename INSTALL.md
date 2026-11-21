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
> FOR PREVIOUS 1.2.0 USERS:
### Upgrade an existing PostgreSQL database to v1.3.0

Version 1.3.0 uses the PostgreSQL schema already present in version 1.2.0. Deploying it over that schema requires no migration. A new, empty database uses `backend/migrations/01_init.sql` through Docker initialization or `make backend-migrate`.

Keep the existing database connection when deploying the new backend. Startup checks the schema without applying migrations. Deck and card deletions remain recorded for offline devices. Sync identifies cards by UUID, so two separately created cards can have identical text and retain independent review histories.

The first API request after a restart schedules a background account check after two seconds. Health probes and an idle process do not schedule checks. Each process starts at most one pass per 15 minutes, with a five-second timeout. Concurrent replicas use a PostgreSQL advisory lock. A pass can remove up to 100 accounts marked deleted for at least 24 hours. This includes accounts already marked deleted before deployment. PostgreSQL cascades that deletion to their decks, cards, and dependent study records. The cooldown starts fresh on restart.

Earlier drafts of this branch included two additional migration scripts. They have been removed. If those drafts were applied to a separate database, check that database's foreign keys and review behavior before using it with this release.

Keep the existing strong `JWT_SECRET` across deploys. The API requires at least 32 characters. If the old secret needs replacement, existing users will have to sign in again. Set `TRUSTED_PROXY_CIDRS` only to the known addresses of reverse proxies that sanitize forwarding headers. Direct deployments can leave it unset.

### Public bug reporting

Enable Issues and Actions on the repository. GitHub can dispatch the bug report workflow after it is present on the default branch. Set `BUG_REPORT_GITHUB_TOKEN` in the backend host to a fine-grained token restricted to this repository with Actions write permission. The workflow uses its own token with Issues write permission to post a confirmed report. Keep the backend credential out of the app.

> FOR NEW USERS
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

For device integration tests, set `FLASHSTEP_DEVICE_TEST=true` when building the debug APK. The test package is `com.example.frontend.uitest`. Before installing on a phone with Flashstep already installed, inspect the built APK with `aapt dump badging` and confirm its `package` line names `com.example.frontend.uitest`. When using `flutter drive`, pass that inspected file with `--use-application-binary`.

## Build APKs

The release targets generate Drift code and refresh Android plugin registration
for release, including immediately after a device test. Keep `integration_test`
in `dev_dependencies`. If invoking Flutter directly, use `flutter build apk --release`
after code generation. For a CI job that compiles with `--no-pub`, run
`make apk-release-prepare` after the last debug build or test. It uses
`flutter build apk --release --config-only` to generate the release registration
that `flutter build apk --release --no-pub` will reuse.

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
