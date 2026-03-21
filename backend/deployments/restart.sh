sudo docker compose down -v --remove-orphans --rmi all
sudo docker builder prune -a -f
sudo docker system prune -a -f
sudo docker ps -a
sudo docker images -a
sudo docker volume ls
sudo docker volume rm deployments_postgres_data
set -a
. ../.env
set +a
sudo docker compose --env-file ../.env up --build -d