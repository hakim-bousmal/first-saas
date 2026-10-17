package com.firstsaas.project;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProjectServiceTest {

	private static final Instant NOW = Instant.parse("2026-01-01T10:00:00Z");

	private ProjectService service;

	@BeforeEach
	void setUp() {
		service = new ProjectService(Clock.fixed(NOW, ZoneOffset.UTC));
	}

	@Test
	void createStripsNameAndSetsCreationDate() {
		Project project = service.create(new CreateProjectRequest("  Billing  ", "Invoices"));

		assertThat(project.id()).isNotNull();
		assertThat(project.name()).isEqualTo("Billing");
		assertThat(project.description()).isEqualTo("Invoices");
		assertThat(project.createdAt()).isEqualTo(NOW);
	}

	@Test
	void getReturnsCreatedProject() {
		Project created = service.create(new CreateProjectRequest("Billing", null));

		assertThat(service.get(created.id())).isEqualTo(created);
	}

	@Test
	void getUnknownProjectThrows() {
		UUID id = UUID.randomUUID();

		assertThatThrownBy(() -> service.get(id)).isInstanceOf(ProjectNotFoundException.class)
			.hasMessageContaining(id.toString());
	}

	@Test
	void listReturnsAllProjects() {
		service.create(new CreateProjectRequest("A", null));
		service.create(new CreateProjectRequest("B", null));

		assertThat(service.list()).extracting(Project::name).containsExactlyInAnyOrder("A", "B");
	}

}
