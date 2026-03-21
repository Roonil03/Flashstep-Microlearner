.PHONY: deps tidy verify clean main

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
	