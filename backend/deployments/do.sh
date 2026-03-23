sudo docker compose down -v --remove-orphans --rmi all
sudo docker builder prune -a -f
sudo docker system prune -a -f
sudo docker ps -a
sudo docker images -a
sudo docker volume ls
sudo docker compose up --build -d;
sudo docker logs flashcards_postgres
sudo docker logs flashcards_backend