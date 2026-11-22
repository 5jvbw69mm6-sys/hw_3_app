структура~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
├── Dockerfile
├── .dockerignore
├── .env.example
├── compose.yaml
├── app/
│   ├── app.py
│   └── requirements.txt
└── scripts/
    └── check.sh


команды~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


cp .env.example .env
docker compose up -d --build

приложение тут http://127.0.0.1:8080/

настройки ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

APP_PORT  8080 - порт в хосте через который доступно приложение
GREETING  wasap docker - приветствие (неформально :) )

режим задан в compose.yaml: STORAGE=redis, REDIS_URL=redis://redis:6379/0 использую имяm серв redis, не localhost

на 6-8~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

compose.yaml поднимает  app и redis с healthcheck у каждого и volume redis-data чтобы не менялись данные redis


$ docker compose ps
NAME                 IMAGE              COMMAND             SERVICE   STATUS
ipr_docker-app-1     ipr_docker-app     "python app.py"     app       Up (healthy)   0.0.0.0:8080->8000/tcp
ipr_docker-redis-1   redis:7.4-alpine   "docker-entrypoint…" redis     Up (healthy)   6379/tcp


проверка~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

$ curl http://127.0.0.1:8080/
{"greeting": "wasap docker", "count": 0, "hostname": "29e55cee159f", "storage": "redis"}

$ curl -X POST http://127.0.0.1:8080/increment
{"greeting": "wasap docker", "count": 1, "hostname": "29e55cee159f", "storage": "redis"}


проверка redis~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

$ docker compose stop redis
✔ Container ipr_docker-redis-1 Stopped

$ curl http://127.0.0.1:8080/healthz
{"status": "alive"}

$ curl -i http://127.0.0.1:8080/readyz
HTTP/1.0 503 Service Unavailable
{"error": "storage_unavailable"}

$ curl -i -X POST http://127.0.0.1:8080/increment
HTTP/1.0 503 Service Unavailable
{"error": "storage_unavailable"}

$ docker compose start redis
✔ Container ipr_docker-redis-1 Started

$ curl -i http://127.0.0.1:8080/readyz
HTTP/1.0 200 OK
{"status": "ready", "storage": "redis"}

$ curl http://127.0.0.1:8080/
{"greeting": "wasap docker", "count": 1, "hostname": "29e55cee159f", "storage": "redis"}

$ curl -X POST http://127.0.0.1:8080/increment
{"greeting": "wasap docker", "count": 2, "hostname": "29e55cee159f", "storage": "redis"}


в итоге пока redis недоступен healthz остаётся 200  при жтом readyz и increment дают по 503
после восстановления Redis приложение работает, счётчик не сброшен и растет с того же значения.

проверка сохранности данных после пересоздании контейнера~~~~~~~~~~~~~~~~~~~~~~~~~~
$ curl http://127.0.0.1:8080/
{"greeting": "wasap docker", "count": 2, "hostname": "29e55cee159f", "storage": "redis"}

$ docker compose down
✔ Container ipr_docker-app-1    Removed
✔ Container ipr_docker-redis-1  Removed
✔ Network ipr_docker_default    Removed

$ docker compose up -d
✔ Network ipr_docker_default    Created
✔ Container ipr_docker-redis-1  Healthy
✔ Container ipr_docker-app-1    Started

$ curl http://127.0.0.1:8080/
{"greeting": "wasap docker", "count": 2, "hostname": "7c96880e789b", "storage": "redis"}


получилось что после полного удаления и пересоздания контейнеров счётчик остался равным `2` то есть данные хранятся в volume `redis-data`, не в самом контейнере.

образы~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- python:3.13-slim — к приложению
- redis:7.4-alpine — к хранилищю

info~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Server Version: 29.9.3
Storage Driver: overlay2
OSType: linux / Docker Desktop
