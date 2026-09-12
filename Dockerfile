# syntax=docker/dockerfile:1

# STAGE 1: Safe Concurrent Compilation Phase
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Freeze dependency layers independently
COPY pom.xml .

# Isolated 'private' cache prevents file corruption during simultaneous mass builds
RUN --mount=type=cache,target=/root/.m2,sharing=private \
    mvn -B dependency:go-offline

COPY src src

# Offline flag (-o) blocks network latency; sharing=private secures parallel builds
RUN --mount=type=cache,target=/root/.m2,sharing=private \
    mvn -B package -DskipTests -o

# STAGE 2: Secure Production Runner
FROM eclipse-temurin:21-jre
WORKDIR /app

# Hadolint & Kubernetes compliant: hardcoded numeric UIDs allow runtime engine parsing
RUN groupadd -r -g 10001 javauser && \
    useradd -r -u 10001 -g 10001 javauser
USER 10001

# Pull the final artifact out of the installer sandbox using explicit numeric IDs
COPY --chown=10001:10001 --from=build /app/target/*.jar app.jar

# Explicit dynamic production port exposure from Backstage template values
EXPOSE 8915
ENTRYPOINT ["java", "-jar", "app.jar"]