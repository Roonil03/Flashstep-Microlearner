.ONESHELL:
.DEFAULT_GOAL := help

PROJECT_NAME := Flashstep Microlearner
ROOT_DIR := $(CURDIR)
BACKEND_DIR := backend
FRONTEND_DIR := frontend
DEPLOY_DIR := $(BACKEND_DIR)/deployments
BACKEND_ENV := $(BACKEND_DIR)/.env
DOCKER ?= docker
GO ?= go
FLUTTER ?= flutter
DART ?= dart
ADB ?= adb

ifeq ($(OS),Windows_NT)
DETECTED_OS := windows
# Native GNU Make wraps multiline PowerShell recipes in a batch file. Use
# the Bash shipped with Git for Windows for the same recipes on both platforms.
SHELL := $(shell git --exec-path)/../../../bin/bash.exe
else
DETECTED_OS := linux
SHELL := /bin/bash
endif
.SHELLFLAGS := -eu -o pipefail -c
MAKE_HINT := On Windows, install Git for Windows or run make inside WSL.

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
	for tool in "$(DOCKER)" "$(GO)" "$(FLUTTER)" "$(DART)"; do
	  command -v "$$tool" >/dev/null || { echo "Missing required tool: $$tool"; exit 1; }
	done
	echo "Optional for Android-on-phone targets: adb"
	echo "All required core tools were found."

backend-env:
	umask 077
	read -rp "PostgreSQL Username [postgres]: " postgres_user
	postgres_user=$${postgres_user:-postgres}
	read -rsp "PostgreSQL Password [postgres]: " postgres_password
	echo
	postgres_password=$${postgres_password:-postgres}
	read -rp "PostgreSQL Database name [flashcards]: " postgres_db
	postgres_db=$${postgres_db:-flashcards}
	read -rsp "JWT signing secret [generate]: " jwt_secret
	echo
	if [ -z "$$jwt_secret" ]; then jwt_secret=$$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n'); fi
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

backend-env-defaults:
	umask 077
	[ ! -f '$(BACKEND_ENV)' ] || exit 0
	jwt_secret=$$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
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
	  "JWT_SECRET=$$jwt_secret" \
	  "JWT_EXPIRY_MINUTES=120" > '$(BACKEND_ENV)'
	echo "Created $(BACKEND_ENV) with development defaults."

backend-deps:
	cd '$(BACKEND_DIR)'
	$(GO) mod download
	$(GO) mod verify

frontend-deps:
	cd $(FRONTEND_DIR)
	$(FLUTTER) pub get

deps: backend-deps frontend-deps

backend-up:
	[ -f '$(BACKEND_ENV)' ] || { echo 'backend/.env not found. Run make backend-env or make backend-env-defaults first.'; exit 1; }
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env up --build -d

backend-down:
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env down --remove-orphans

backend-reset:
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env down -v --remove-orphans
	$(DOCKER) compose --env-file ../.env up --build -d

backend-migrate:
	$(DOCKER) exec flashcards_postgres sh -ec 'for migration in /docker-entrypoint-initdb.d/*.sql; do psql -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f "$$migration"; done'

backend-logs:
	cd '$(DEPLOY_DIR)'
	$(DOCKER) compose --env-file ../.env logs -f

backend-psql:
	$(DOCKER) exec -it flashcards_postgres sh -ec 'exec psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

backend-run-local:
	while IFS= read -r entry || [ -n "$$entry" ]; do
	  if [[ "$$entry" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then export "$${entry%$$'\r'}"; fi
	done < '$(BACKEND_ENV)'
	export DB_HOST=localhost
	export DB_PORT=5433
	cd '$(BACKEND_DIR)'
	$(GO) run ./cmd/server/main.go

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
	$(FLUTTER) run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1

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

