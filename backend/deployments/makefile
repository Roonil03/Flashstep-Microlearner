.PHONY: db redo stop start

db:
	set -a; \
	. ../.env; \
	set +a; \
	echo "$$POSTGRES_PASSWORD" ; \
	psql \
	-h localhost \
	-p 5433 \
	-U $$POSTGRES_USER \
	-d $$POSTGRES_DB \
	-f ../migrations/init_scheme.sql

redo:
	sudo bash ./restart.sh

stop:
	sudo docker compose down -v --remove-orphans --rmi all
	sudo docker builder prune -a -f
	sudo docker system prune -a -f
	sudo docker ps -a
	sudo docker images -a
	sudo docker volume ls

start:
	set -a
	. ../.env
	set +a
	sudo docker compose --env-file ../.env up --build -d