.PHONY: deps tidy verify clean main install

deps:
	go mod download

tidy:
	go mod tidy
	go mod verify

verify: tidy
	@echo "Dependencies have been verified!"

clean:
	go clean -modcache

main:
	bash ./modules.sh

install: main tidy 

	@read -p "POSTGRES_USER: " POSTGRES_USER; \
	read -s -p "POSTGRES_PASSWORD: " POSTGRES_PASSWORD; echo ""; \
	read -p "POSTGRES_DB: " POSTGRES_DB; \
	read -p "JWT_SECRECY: " JWT_SECRECY; \
	echo ""; \
	echo "Creating .env file..."; \
	cat > .env <<EOF
POSTGRES_USER=$$POSTGRES_USER
POSTGRES_PASSWORD=$$POSTGRES_PASSWORD
POSTGRES_DB=$$POSTGRES_DB
JWT_SECRECY=$$JWT_SECRECY

PORT=8080

DB_HOST=localhost
DB_PORT=5433
DB_USER=$$POSTGRES_USER
DB_PASSWORD=$$POSTGRES_PASSWORD
DB_NAME=$$POSTGRES_DB
DB_SSLMODE=disable

JWT_SECRET=$$JWT_SECRECY
JWT_EXPIRY_MINUTES=120
EOF

	cd deployments && \
	set -a && \
	. ../.env && \
	set +a && \
	sudo docker compose --env-file ../.env up --build -d

	@until docker exec flashcards_postgres pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB > /dev/null 2>&1; do \
		echo "Waiting for DB..."; \
		sleep 2; \
	done

	set -a; \
	. ../.env; \
	set +a; \
	psql \
	-h localhost \
	-p 5433 \
	-U $$POSTGRES_USER \
	-d $$POSTGRES_DB \
	-f ../migrations/init_scheme.sql

	set -a && \
	. ../.env && \
	set +a && \
	psql \
	-h localhost \
	-p 5433 \
	-U $$POSTGRES_USER \
	-d $$POSTGRES_DB \
	-f ../migrations/init_scheme.sql