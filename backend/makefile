.PHONY: deps tidy verify clean

deps:
	go mod download

tidy:
	go mod tidy
	go mod verify

verify: tidy
	@echo "Dependencies have been verified!"

clean:
	go clean -modcache
