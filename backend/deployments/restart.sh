docker compose down -v --remove-orphans --rmi all
docker builder prune -a -f
docker system prune -a -f
docker ps -a
docker images -a
docker volume ls
docker volume rm deployments_postgres_data
set -a
. ../.env
set +a
docker compose --env-file ../.env up --build -d