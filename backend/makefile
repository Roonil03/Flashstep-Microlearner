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
	set -e; \
	printf "POSTGRES_USER: "; \
	read POSTGRES_USER; \
	printf "DB Password: "; \
	stty -echo; \
	read POSTGRES_PASSWORD; \
	stty echo; \
	printf "\n"; \
	printf "POSTGRES_DB: "; \
	read POSTGRES_DB; \
	printf "JWT_SECRECY: "; \
	read JWT_SECRECY; \
	printf "\n"; \
	\
	rm -f .env; \
	printf "POSTGRES_USER=%s\n" "$$POSTGRES_USER" >> .env; \
	printf "POSTGRES_PASSWORD=%s\n" "$$POSTGRES_PASSWORD" >> .env; \
	printf "POSTGRES_DB=%s\n" "$$POSTGRES_DB" >> .env; \
	printf "JWT_SECRECY=%s\n\n" "$$JWT_SECRECY" >> .env; \
	printf "PORT=8080\n\n" >> .env; \
	printf "DB_HOST=localhost\n" >> .env; \
	printf "DB_PORT=5433\n" >> .env; \
	printf "DB_USER=%s\n" "$$POSTGRES_USER" >> .env; \
	printf "DB_PASSWORD=%s\n" "$$POSTGRES_PASSWORD" >> .env; \
	printf "DB_NAME=%s\n" "$$POSTGRES_DB" >> .env; \
	printf "DB_SSLMODE=disable\n\n" >> .env; \
	printf "JWT_SECRET=%s\n" "$$JWT_SECRECY" >> .env; \
	printf "JWT_EXPIRY_MINUTES=120\n" >> .env; \
	\
	cd deployments && \
	set -a ; \
	. ../.env ; \
	set +a ; \
	sudo docker compose --env-file ../.env up --build -d; \
	\
	set -a ; \
	. ../.env ; \
	set +a ; \
	until sudo docker exec flashcards_postgres pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB >/dev/null 2>&1; do \
		sleep 2; \
	done; \
	\
	set -a; \
	. ../.env; \
	set +a; \
	psql \
	-h localhost \
	-p 5433 \
	-U $$POSTGRES_USER \
	-d $$POSTGRES_DB \
	-f ../migrations/init_scheme.sql ; \
	set -a; \
	. ../.env; \
	set +a; \
	psql \
	-h localhost \
	-p 5433 \
	-U $$POSTGRES_USER \
	-d $$POSTGRES_DB \
	-f ../migrations/init_scheme.sql ; \
	