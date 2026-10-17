---
name: spring-unit-tests
description: Conventions and templates for writing unit tests in this Spring Boot 4 / Java 25 project (JUnit 5, AssertJ, Mockito, @WebMvcTest with MockMvcTester). Use whenever writing, fixing or reviewing tests in src/test.
---

# Unit tests in first-saas

## Which kind of test

| Class under test | Test style |
|---|---|
| Service, domain logic, mappers | Plain JUnit 5, no Spring context. Instantiate with `new`, pass a fixed `Clock` |
| `@RestController` | `@WebMvcTest(XxxController.class)` + `@MockitoBean` for services + `MockMvcTester` |
| Exception → HTTP mapping | Covered in the controller test (`@Import(GlobalExceptionHandler.class)`) |
| Whole app wiring | Only the existing `FirstSaasApplicationTests` smoke test. Do not add `@SpringBootTest` tests |

## Rules

- File `src/test/java/<same package>/<ClassName>Test.java`, package-private class and methods.
- Method names describe behavior: `createWithBlankNameReturns400`, `getUnknownProjectThrows`.
- Arrange / act / assert separated by blank lines. One behavior per test.
- AssertJ only (`assertThat`, `assertThatThrownBy`), BDD Mockito (`given(...).willReturn(...)`).
- No `Thread.sleep`, no real network, no randomness in assertions; time comes from `Clock.fixed(...)`.
- Each acceptance criterion of the ticket gets at least one test; then cover validation errors, not-found and
  empty results.

## Spring Boot 4 imports (Boot 3 names do not compile)

```java
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
```

## Controller test template

```java
@WebMvcTest(ProjectController.class)
@Import(GlobalExceptionHandler.class)
class ProjectControllerTest {

	@Autowired
	private MockMvcTester mvc;

	@MockitoBean
	private ProjectService projectService;

	@Test
	void getUnknownReturns404ProblemDetail() {
		UUID id = UUID.randomUUID();
		given(projectService.get(id)).willThrow(new ProjectNotFoundException(id));

		assertThat(mvc.get().uri("/api/v1/projects/{id}", id)).hasStatus(HttpStatus.NOT_FOUND)
			.bodyJson()
			.extractingPath("$.status")
			.isEqualTo(404);
	}

}
```

Reference implementations: `ProjectServiceTest` and `ProjectControllerTest`.

## Done means

`./mvnw -B verify` is green, including the JaCoCo gate (≥ 80% lines).
