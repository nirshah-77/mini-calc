# ── Stage 1: Build & Test ─────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn test package -q        # tests MUST pass before image is built

# ── Stage 2: Minimal runtime image ────────────────────────────────
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/mini-calc.jar mini-calc.jar
# Keep container alive — connect interactively with:
#   docker exec -it mini-calc java -cp mini-calc.jar calc
CMD ["tail", "-f", "/dev/null"]


