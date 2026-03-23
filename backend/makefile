.PHONY: deps tidy verify clean main install-linux

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
	go env -w GOPROXY=https://proxy.golang.org,direct
	go env -w GOSUMDB=sum.golang.org
	go get github.com/gin-gonic/gin@latest || true
	go get github.com/gofiber/fiber/v2@latest || true
	go get gofr.dev@latest || true
	go get github.com/lib/pq@latest || true
	go get github.com/joho/godotenv@latest || true
	go get github.com/golang-jwt/jwt/v5@latest || true
	go mod tidy
	go mod verify

install-linux: main
	cd deployments
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
	printf "DB_HOST=flashcards_postgres\n" >> .env; \
	printf "DB_PORT=5433\n" >> .env; \
	printf "GO_PORT=5432\n" >> .env; \
	printf "DB_USER=%s\n" "$$POSTGRES_USER" >> .env; \
	printf "DB_PASSWORD=%s\n" "$$POSTGRES_PASSWORD" >> .env; \
	printf "DB_NAME=%s\n" "$$POSTGRES_DB" >> .env; \
	printf "DB_SSLMODE=disable\n\n" >> .env; \
	printf "JWT_SECRET=%s\n" "$$JWT_SECRECY" >> .env; \
	printf "JWT_EXPIRY_MINUTES=120\n" >> .env;
	sudo bash ./deployments/do.sh

install-win: main
	cd deployments
	./ps.bat