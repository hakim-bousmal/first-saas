package com.firstsaas.project;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.firstsaas.common.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;

@WebMvcTest(ProjectController.class)
@Import(GlobalExceptionHandler.class)
class ProjectControllerTest {

	private static final Project PROJECT = new Project(UUID.fromString("11111111-1111-1111-1111-111111111111"),
			"Billing", "Invoices", Instant.parse("2026-01-01T10:00:00Z"));

	@Autowired
	private MockMvcTester mvc;

	@MockitoBean
	private ProjectService projectService;

	@Test
	void createReturns201WithLocation() {
		given(projectService.create(any())).willReturn(PROJECT);

		assertThat(mvc.post()
			.uri("/api/v1/projects")
			.contentType(MediaType.APPLICATION_JSON)
			.content("""
					{"name": "Billing", "description": "Invoices"}
					"""))
			.hasStatus(HttpStatus.CREATED)
			.hasHeader("Location", "/api/v1/projects/" + PROJECT.id())
			.bodyJson()
			.extractingPath("$.name")
			.isEqualTo("Billing");
	}

	@Test
	void createWithBlankNameReturns400() {
		assertThat(mvc.post().uri("/api/v1/projects").contentType(MediaType.APPLICATION_JSON).content("""
				{"name": ""}
				""")).hasStatus(HttpStatus.BAD_REQUEST);
	}

	@Test
	void getReturnsProject() {
		given(projectService.get(PROJECT.id())).willReturn(PROJECT);

		assertThat(mvc.get().uri("/api/v1/projects/{id}", PROJECT.id())).hasStatusOk()
			.bodyJson()
			.extractingPath("$.description")
			.isEqualTo("Invoices");
	}

	@Test
	void getUnknownReturns404ProblemDetail() {
		UUID id = UUID.randomUUID();
		given(projectService.get(id)).willThrow(new ProjectNotFoundException(id));

		assertThat(mvc.get().uri("/api/v1/projects/{id}", id)).hasStatus(HttpStatus.NOT_FOUND)
			.bodyJson()
			.extractingPath("$.status")
			.isEqualTo(404);
	}

	@Test
	void listReturnsProjects() {
		given(projectService.list()).willReturn(List.of(PROJECT));

		assertThat(mvc.get().uri("/api/v1/projects")).hasStatusOk()
			.bodyJson()
			.extractingPath("$.length()")
			.isEqualTo(1);
	}

}
