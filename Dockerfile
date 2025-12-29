# Stage 1: Build complet
FROM maven:3.8.5-openjdk-17 AS build

WORKDIR /workspace

# Copier les fichiers sources
COPY pom.xml .
COPY src src

# Builder en deux étapes pour optimisation du cache
RUN mvn dependency:go-offline -B
RUN mvn clean package -DskipTests

# Stage 2: Extraction des couches JAR (pour démarrage plus rapide)
FROM openjdk:17-jdk-slim AS extractor
WORKDIR /app
ARG JAR_FILE=*.jar
COPY --from=build /workspace/target/${JAR_FILE} app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# Stage 3: Image runtime finale
FROM openjdk:17-jre-slim

# Installation de curl pour les health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Création utilisateur non-root
RUN addgroup --system --gid 1001 springapp && \
    adduser --system --uid 1001 --gid 1001 springapp

WORKDIR /app

# Copier les couches extraites
COPY --from=extractor --chown=springapp:springapp /app/dependencies/ ./
COPY --from=extractor --chown=springapp:springapp /app/spring-boot-loader/ ./
COPY --from=extractor --chown=springapp:springapp /app/snapshot-dependencies/ ./
COPY --from=extractor --chown=springapp:springapp /app/application/ ./

USER 1001

EXPOSE 8080

ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]