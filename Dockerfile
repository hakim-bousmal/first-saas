# Packages the jar built by `./mvnw verify` (CI builds it once, the image just layers it).
# Local: ./mvnw -B package && docker build -t first-saas .

FROM eclipse-temurin:25-jre AS extract
WORKDIR /app
COPY target/first-saas-*.jar app.jar
RUN java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted

FROM eclipse-temurin:25-jre
WORKDIR /app
# One layer per change frequency so image pushes only ship the application layer most of the time
COPY --from=extract /app/extracted/dependencies/ ./
COPY --from=extract /app/extracted/spring-boot-loader/ ./
COPY --from=extract /app/extracted/snapshot-dependencies/ ./
COPY --from=extract /app/extracted/application/ ./
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "org.springframework.boot.loader.launch.JarLauncher"]
