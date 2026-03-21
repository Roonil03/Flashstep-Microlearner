docker compose down -v --remove-orphans --rmi all
docker builder prune -a -f
docker system prune -a -f
docker ps -a
docker images -a
docker volume ls
docker compose up --build -d
- name: Create .env
  run: |
    echo "POSTGRES_PASSWORD=${{ secrets.DB_PASSWORD }}" >> .env
    echo "JWT_SECRET=${{ secrets.JWT_SECRET }}" >> .env