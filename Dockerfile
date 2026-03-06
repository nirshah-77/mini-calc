# ── Stage 1: Build & Test ─────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

# Copy pom first so dependency layer is cached unless pom changes
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Copy source then run tests + package
COPY src ./src
RUN mvn test package -q

# ── Stage 2: Minimal runtime image ───────────────────────────────
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

COPY --from=build /app/target/mini-calc.jar mini-calc.jar

CMD ["java", "-jar", "mini-calc.jar"]
