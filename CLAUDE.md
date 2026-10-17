# first-saas

Spring Boot 4.1 / Java 25 REST service. Features come from Jira and are mostly implemented by Claude Code
(see the `implement-jira-feature` skill), then reviewed by a human through a pull request.

## Commands

- Build + all tests + coverage gate: `./mvnw -B verify` (must pass before any commit)
- Run a single test class: `./mvnw -B test -Dtest=ProjectServiceTest`
- Run the app: `./mvnw spring-boot:run` → http://localhost:8080/actuator/health
- Jira helper: `scripts/jira.sh get <KEY>` / `scripts/jira.sh comment <KEY> "<text>"`

On Windows use `mvnw.cmd`. JAVA_HOME must point to a JDK 25.

## Architecture

- Package by feature under `com.firstsaas.<feature>` (e.g. `project/`): record DTOs, `*Service`, `*Controller`,
  feature exceptions. Cross-cutting code lives in `com.firstsaas.common`.
- Controllers are thin: validation (`@Valid` + Jakarta constraints) and HTTP mapping only. Logic goes in services.
- Errors are returned as RFC 9457 `ProblemDetail`, mapped in `common/GlobalExceptionHandler`.
- Time comes from the injected `java.time.Clock` bean, never `Instant.now()` without a clock.
- Storage is in-memory for now; no database yet.

## Conventions

- Java 25: records for DTOs, `var` only when the type is obvious, no Lombok.
- Constructor injection only, no field `@Autowired` in main code.
- REST paths are versioned: `/api/v1/...`. Plural nouns, `201 Created` + `Location` on create.
- Tabs for indentation (Spring style), imports ordered: java, jakarta, third-party, org.springframework, static.
- Every behavior change ships with unit tests — follow the `spring-unit-tests` skill.
- JaCoCo line coverage must stay ≥ 80% (`jacoco.minimum.coverage` in `pom.xml`). Never lower it.

## Spring Boot 4 gotchas

- Web starter is `spring-boot-starter-webmvc`; test slices moved: `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`.
- Use `@MockitoBean` (not the removed `@MockBean`) and prefer `MockMvcTester` (AssertJ) over `MockMvc`.
- Jackson 3 is the default (`tools.jackson.*` packages).

## Do not touch without an explicit request in the ticket

`Jenkinsfile`, `jenkins/`, `deploy/`, `infra/`, `.claude/`, the Spring Boot parent version, the coverage threshold.
