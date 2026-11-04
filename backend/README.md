# Study Planner API

Spring Boot REST API for the Flutter app.

## Requirements

- Java 21
- Docker Desktop (or an existing PostgreSQL 16+ server)
- Maven is provided by the Maven Wrapper; no global Maven installation or `mvn` on PATH is needed. The first run needs internet access to download Maven and dependencies.

## Run

From the repository root, create your local configuration if it does not already exist:

```powershell
Copy-Item backend/.env.example .env
```

On Linux/macOS, use `cp backend/.env.example .env`. Keep any existing `.env` and update its settings as needed.

Start PostgreSQL from the repository root:

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
| JWT_SECRET | Development example in `.env.example` | HMAC signing secret; use a separate secret of at least 32 UTF-8 bytes outside local development |
| APP_CORS_ORIGINS | http://localhost:5000 | Comma-separated Flutter Web origins |

The database, JWT, and CORS values must be supplied through `.env` or process environment variables; only `SERVER_PORT` defaults to `8080` without configuration. The example JWT secret is for local development.

Changing `DB_PASSWORD` in `.env` does not change the password stored in an existing PostgreSQL Docker volume. Use that volume's current password, or change the database role's password and update `.env` to match.

Passwords are stored with BCrypt. Private endpoints require Authorization: Bearer token. Successful responses use {requestId, errorCode, errorMessage, result}.
