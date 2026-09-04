# syntax=docker/dockerfile:1

# --- Build ---
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Resolve dependencies first so they're cached until pom.xml changes.
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw -B -q dependency:go-offline

COPY src src
RUN ./mvnw -B -q -DskipTests package

# --- Run ---
FROM eclipse-temurin:21-jre
WORKDIR /app

RUN useradd --system --uid 10001 hearthway
USER hearthway

COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
