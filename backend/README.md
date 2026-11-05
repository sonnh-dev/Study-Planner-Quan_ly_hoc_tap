# Study Planner API

Spring Boot REST API for the Flutter app.

## Run with Docker Compose

Start Docker Desktop, [create a local `.env`](../README.md#chạy-backend), and run this command from the repository root:

```powershell
docker compose --env-file .env up -d --build backend
```

Compose starts PostgreSQL and the API. The API connects to `postgres:5432` using the `study_planner` database and user. `SERVER_PORT` sets the published API port and defaults to `8080`.

## Local requirements

- Java 21
- Docker Desktop (or an existing PostgreSQL 16+ server)
- Maven is provided by the Maven Wrapper; no global Maven installation or `mvn` on PATH is needed. The first run needs internet access to download Maven and dependencies.

## Run Spring Boot locally

[Create a local `.env`](../README.md#chạy-backend) in the repository root if needed, then start PostgreSQL:

```powershell
docker compose --env-file .env up -d postgres
```

Docker exposes PostgreSQL on host port `5433`, so it can coexist with a native PostgreSQL installation on port `5432`. The example connects to `jdbc:postgresql://localhost:5433/study_planner` with database, username, and local password `study_planner`. To use an existing PostgreSQL server instead, create the database and role there and adjust the connection settings in `.env`.

Then change to `backend/` and run on Windows:

```powershell
$env:SPRING_CONFIG_IMPORT = 'file:../.env[.properties]'
.\mvnw.cmd spring-boot:run
```

On Linux/macOS:

```sh
SPRING_CONFIG_IMPORT='file:../.env[.properties]' ./mvnw spring-boot:run
```

Spring Boot imports the root `.env` through `SPRING_CONFIG_IMPORT`. In an IDE, set the same variable relative to the selected working directory, or provide configuration as process environment variables. Process environment variables override values in `.env`.

Flyway applies the schema migration at startup. Check health at http://localhost:8080/actuator/health.

## Configuration

| Variable | Example/local value | Purpose |
|---|---|---|
| SERVER_PORT | 8080 | HTTP listener |
| DB_URL | jdbc:postgresql://localhost:5433/study_planner | PostgreSQL JDBC URL; matches the Docker host port |
| DB_USERNAME | study_planner | Database account |
| DB_PASSWORD | study_planner | Local development only |
| JWT_SECRET | A unique secret of at least 32 UTF-8 bytes | HMAC signing secret |
| APP_CORS_ORIGINS | `http://localhost:8386,http://127.0.0.1:8386` | Comma-separated Flutter Web origins. Defaults to both loopback origins on port 8386. |

When running Spring Boot directly, supply the database and JWT values through `.env` or process environment variables. `SERVER_PORT` defaults to `8080`. If an existing `APP_CORS_ORIGINS` overrides the default, add the new Web origin and restart Spring Boot.

Changing `DB_PASSWORD` in `.env` does not change the password stored in an existing PostgreSQL Docker volume. Use that volume's current password, or change the database role's password and update `.env` to match.

The business API uses `http://localhost:8080/api` locally. See the [REST API reference](../docs/api.md) for endpoints, JWT authentication, and examples.
