.PHONY: deps tidy verify clean main db

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
	
db:
	psql -h localhost -U postgres -d flashcards -f migrations/init_schema.sql