.ONESHELL:
.DEFAULT_GOAL := help

PROJECT_NAME := Flashstep Microlearner
ROOT_DIR := $(CURDIR)
BACKEND_DIR := backend
FRONTEND_DIR := frontend
DEPLOY_DIR := $(BACKEND_DIR)/deployments
MIGRATION_FILE := $(BACKEND_DIR)/migrations/01.\ init.sql
BACKEND_ENV := $(BACKEND_DIR)/$(DEPLOY_DIR)/.env
DOCKER ?= docker
GO ?= go
FLUTTER ?= flutter
DART ?= dart
ADB ?= adb

ifeq ($(OS),Windows_NT)
DETECTED_OS := windows
SHELL := powershell.exe
.SHELLFLAGS := -NoProfile -ExecutionPolicy Bypass -Command
MAKE_HINT := Use GNU Make on Windows (for example, mingw32-make from Git Bash, MSYS2, or WSL).
else
DETECTED_OS := linux
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
MAKE_HINT := GNU Make is already available on most Linux distributions.
endif

help:
	@echo "$(PROJECT_NAME) Makefile"
	@echo ""
	@echo "Detected OS: $(DETECTED_OS)"
	@echo "$(MAKE_HINT)"
	@echo ""
	@echo "Setup / install"
	@echo "  make doctor                 Check required tools"
	@echo "  make backend-env            Create backend/.env interactively"
	@echo "  make backend-env-defaults   Create backend/.env with dev defaults"
	@echo "  make deps                   Download backend + frontend dependencies"
	@echo "  make bootstrap-dev          Full local dev bootstrap"
	@echo ""
	@echo "Backend"
	@echo "  make backend-up             Start backend Docker stack"
	@echo "  make backend-down           Stop backend Docker stack"
	@echo "  make backend-reset          Rebuild backend stack and remove volumes"
	@echo "  make backend-migrate        Run PostgreSQL migrations"
	@echo "  make backend-logs           View backend stack logs"
	@echo "  make backend-psql           Open psql in the postgres container"
	@echo "  make backend-run-local      Run Go API on host against dockerized DB"
	@echo ""
	@echo "Frontend"
	@echo "  make frontend-deps          flutter pub get"
	@echo "  make frontend-codegen       drift/build_runner code generation"
	@echo "  make frontend-run           Run Flutter app locally"
	@echo "  make phone-dev              Run app on an Android phone against local backend"
	@echo "  make apk-debug              Build a debug APK"
	@echo "  make apk-release            Build a universal release APK"
	@echo "  make apk-release-split      Build split-per-abi release APKs"
	@echo "  make apk-install-debug      Install debug APK on a connected Android device"
	@echo "  make apk-install-release    Install universal release APK on a connected Android device"
	@echo ""
	@echo "Common flows"
	@echo "  make run-local              Start backend stack, then run Flutter locally"
	@echo "  make phone-install-dev      Start backend stack, adb reverse, then flutter run"
	@echo ""
	@echo "Important"
	@echo "  Release APKs only behave like a normal user app if the frontend points to a reachable backend URL."
	@echo "  If api_config.dart still uses localhost, only 'make phone-dev' with adb reverse will work on a real Android phone."


doctor:
ifeq ($(OS),Windows_NT)
	$$tools = @('$(DOCKER)', '$(GO)', '$(FLUTTER)', '$(DART)')
	foreach ($$tool in $$tools) {
	  if (-not (Get-Command $$tool -ErrorAction SilentlyContinue)) {
	    Write-Error "Missing required tool: $$tool"
	    exit 1
	  }
	}
	Write-Host 'Optional for Android-on-phone targets: adb'
	Write-Host 'All required core tools were found.' -ForegroundColor Green
else
	for tool in "$(DOCKER)" "$(GO)" "$(FLUTTER)" "$(DART)"; do
	  command -v "$$tool" >/dev/null || { echo "Missing required tool: $$tool"; exit 1; }
	done
	echo "Optional for Android-on-phone targets: adb"
	echo "All required core tools were found."
endif

backend-env:
ifeq ($(OS),Windows_NT)
	$$postgresUser = Read-Host 'PostgreSQL Username (default: postgres)'
	if ([string]::IsNullOrWhiteSpace($$postgresUser)) { $$postgresUser = 'postgres' }
	$$postgresPassword = Read-Host 'PostgreSQL Password (default: postgres)' -AsSecureString
	$$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($$postgresPassword))
	if ([string]::IsNullOrWhiteSpace($$plainPassword)) { $$plainPassword = 'postgres' }
	$$postgresDB = Read-Host 'PostgreSQL Database name (default: flashcards)'
	if ([string]::IsNullOrWhiteSpace($$postgresDB)) { $$postgresDB = 'flashcards' }
	$$jwtSecret = Read-Host 'JWT Secret (default: change-me-in-production)' -AsSecureString
	$$plainJwtSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($$jwtSecret))
	if ([string]::IsNullOrWhiteSpace($$plainJwtSecret)) { $$plainJwtSecret = 'change-me-in-production' }
	@(
	  "POSTGRES_USER=$$postgresUser",
	  "POSTGRES_PASSWORD=$$plainPassword",
	  "POSTGRES_DB=$$postgresDB",
	  "PORT=8080",
	  "DB_HOST=flashcards_postgres",
	  "DB_PORT=5432",
	  "DB_USER=$$postgresUser",
	  "DB_PASSWORD=$$plainPassword",
	  "DB_NAME=$$postgresDB",
	  "DB_SSLMODE=disable",
	  "JWT_SECRET=$$plainJwtSecret",
	  "JWT_EXPIRY_MINUTES=120"
	) | Set-Content -Path '$(BACKEND_ENV)'
	Write-Host 'Created $(BACKEND_ENV)' -ForegroundColor Green
else
	read -rp "PostgreSQL Username [postgres]: " postgres_user
	postgres_user=$${postgres_user:-postgres}
	read -rsp "PostgreSQL Password [postgres]: " postgres_password
	echo
	postgres_password=$${postgres_password:-postgres}
	read -rp "PostgreSQL Database name [flashcards]: " postgres_db
	postgres_db=$${postgres_db:-flashcards}
	read -rsp "JWT Secret [change-me-in-production]: " jwt_secret
	echo
	jwt_secret=$${jwt_secret:-change-me-in-production}
	printf '%s\n' \
	  "POSTGRES_USER=$$postgres_user" \
	  "POSTGRES_PASSWORD=$$postgres_password" \
	  "POSTGRES_DB=$$postgres_db" \
	  "PORT=8080" \
	  "DB_HOST=flashcards_postgres" \
	  "DB_PORT=5432" \
	  "DB_USER=$$postgres_user" \
	  "DB_PASSWORD=$$postgres_password" \
	  "DB_NAME=$$postgres_db" \
	  "DB_SSLMODE=disable" \
	  "JWT_SECRET=$$jwt_secret" \
	  "JWT_EXPIRY_MINUTES=120" > '$(BACKEND_ENV)'
	echo "Created $(BACKEND_ENV)"
endif

backend-env-defaults:
ifeq ($(OS),Windows_NT)
	@(
	  "POSTGRES_USER=postgres",
	  "POSTGRES_PASSWORD=postgres",
	  "POSTGRES_DB=flashcards",
	  "PORT=8080",
	  "DB_HOST=flashcards_postgres",
	  "DB_PORT=5432",
	  "DB_USER=postgres",
	  "DB_PASSWORD=postgres",
	  "DB_NAME=flashcards",
	  "DB_SSLMODE=disable",
	  "JWT_SECRET=change-me-in-production",
	  "JWT_EXPIRY_MINUTES=120"
	) | Set-Content -Path '$(BACKEND_ENV)'
	Write-Host 'Created $(BACKEND_ENV) with development defaults.' -ForegroundColor Yellow
else
	printf '%s\n' \
	  "POSTGRES_USER=postgres" \
	  "POSTGRES_PASSWORD=postgres" \
	  "POSTGRES_DB=flashcards" \
	  "PORT=8080" \
	  "DB_HOST=flashcards_postgres" \
	  "DB_PORT=5432" \
	  "DB_USER=postgres" \
	  "DB_PASSWORD=postgres" \
	  "DB_NAME=flashcards" \
	  "DB_SSLMODE=disable" \
	  "JWT_SECRET=change-me-in-production" \
	  "JWT_EXPIRY_MINUTES=120" > '$(BACKEND_ENV)'
	echo "Created $(BACKEND_ENV) with development defaults."
endif

backend-deps:
	cd '$(BACKEND_DIR)'
	$(GO) mod download
	$(GO) mod tidy
	$(GO) mod verify

frontend-deps:
	cd $(FRONTEND_DIR)
	$(FLUTTER) pub get

deps: backend-deps frontend-deps

backend-up:
ifeq ($(OS),Windows_NT)
	if (-not (Test-Path '$(BACKEND_ENV)')) { Write-Error 'backend/.env not found. Run make backend-env or make backend-env-defaults first.'; exit 1 }
	Set-Location '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env up --build -d
else
	[ -f '$(BACKEND_ENV)' ] || { echo 'backend/.env not found. Run make backend-env or make backend-env-defaults first.'; exit 1; }
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env up --build -d
endif

backend-down:
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env down --remove-orphans

backend-reset:
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env down -v --remove-orphans
	$(DOCKER) builder prune -a -f
	$(DOCKER) system prune -a -f
	$(DOCKER) compose --env-file ../.env up --build -d

backend-migrate:
ifeq ($(OS),Windows_NT)
	if (-not (Test-Path '$(BACKEND_ENV)')) { Write-Error 'backend/.env not found. Run make backend-env or make backend-env-defaults first.'; exit 1 }
	$$envMap = @{}
	Get-Content '$(BACKEND_ENV)' | ForEach-Object {
	  if ($$_ -match '^[A-Za-z_][A-Za-z0-9_]*=') {
	    $$parts = $$_ -split '=', 2
	    $$envMap[$$parts[0]] = $$parts[1]
	  }
	}
	Get-Content '$(MIGRATION_FILE)' -Raw | $(DOCKER) exec -i flashcards_postgres psql -U $$envMap['POSTGRES_USER'] -d $$envMap['POSTGRES_DB']
else
	set -a
	. '$(BACKEND_ENV)'
	set +a
	cat '$(MIGRATION_FILE)' | $(DOCKER) exec -i flashcards_postgres psql -U $$POSTGRES_USER -d $$POSTGRES_DB
endif

backend-logs:
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env logs -f

backend-psql:
ifeq ($(OS),Windows_NT)
	$$envMap = @{}
	Get-Content '$(BACKEND_ENV)' | ForEach-Object {
	  if ($$_ -match '^[A-Za-z_][A-Za-z0-9_]*=') {
	    $$parts = $$_ -split '=', 2
	    $$envMap[$$parts[0]] = $$parts[1]
	  }
	}
	$(DOCKER) exec -it flashcards_postgres psql -U $$envMap['POSTGRES_USER'] -d $$envMap['POSTGRES_DB']
else
	set -a
	. '$(BACKEND_ENV)'
	set +a
	$(DOCKER) exec -it flashcards_postgres psql -U $$POSTGRES_USER -d $$POSTGRES_DB
endif

backend-run-local:
ifeq ($(OS),Windows_NT)
	if (-not (Test-Path '$(BACKEND_ENV)')) { Write-Error 'backend/.env not found. Run make backend-env or make backend-env-defaults first.'; exit 1 }
	Get-Content '$(BACKEND_ENV)' | ForEach-Object {
	  if ($$_ -match '^[A-Za-z_][A-Za-z0-9_]*=') {
	    $$parts = $$_ -split '=', 2
	    [System.Environment]::SetEnvironmentVariable($$parts[0], $$parts[1], 'Process')
	  }
	}
	[System.Environment]::SetEnvironmentVariable('DB_HOST', 'localhost', 'Process')
	[System.Environment]::SetEnvironmentVariable('DB_PORT', '5433', 'Process')
	Set-Location '$(BACKEND_DIR)'
	$(GO) run ./cmd/server/main.go
else
	set -a
	. '$(BACKEND_ENV)'
	set +a
	export DB_HOST=localhost
	export DB_PORT=5433
	cd '$(BACKEND_DIR)'
	$(GO) run ./cmd/server/main.go
endif

frontend-codegen: frontend-deps
	cd $(FRONTEND_DIR)
	$(DART) run build_runner build --delete-conflicting-outputs

frontend-icons: frontend-deps
	cd $(FRONTEND_DIR)
	$(DART) run flutter_launcher_icons

frontend-run:
	cd $(FRONTEND_DIR)
	$(FLUTTER) run

phone-dev:
	$(ADB) reverse tcp:8080 tcp:8080
	cd $(FRONTEND_DIR)
	$(FLUTTER) run

apk-debug:
	cd $(FRONTEND_DIR)
	$(FLUTTER) build apk --debug

apk-release:
	cd $(FRONTEND_DIR)
	$(FLUTTER) build apk --release

apk-release-split:
	cd $(FRONTEND_DIR)
	$(FLUTTER) build apk --release --split-per-abi

apk-install-debug: apk-debug
	$(ADB) install -r '$(FRONTEND_DIR)/build/app/outputs/flutter-apk/app-debug.apk'

apk-install-release: apk-release
	$(ADB) install -r '$(FRONTEND_DIR)/build/app/outputs/flutter-apk/app-release.apk'

bootstrap-dev: doctor backend-env-defaults deps backend-up backend-migrate frontend-codegen
	@echo "Development bootstrap complete."
	@echo "For desktop/emulator dev: make frontend-run"
	@echo "For a connected Android phone against local backend: make phone-dev"

run-local: backend-up frontend-run

phone-install-dev: backend-up phone-dev

clean:
	cd $(FRONTEND_DIR)
	$(FLUTTER) clean

