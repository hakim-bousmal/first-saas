package com.firstsaas.project;

import java.time.Clock;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

/**
 * In-memory store for now. Replace with a Spring Data repository once a database is introduced.
 */
@Service
public class ProjectService {

	private final Map<UUID, Project> projects = new ConcurrentHashMap<>();

	private final Clock clock;

	public ProjectService(Clock clock) {
		this.clock = clock;
	}

	public Project create(CreateProjectRequest request) {
		Project project = new Project(UUID.randomUUID(), request.name().strip(), request.description(),
				Instant.now(clock));
		projects.put(project.id(), project);
		return project;
	}

	public Project get(UUID id) {
		Project project = projects.get(id);
		if (project == null) {
			throw new ProjectNotFoundException(id);
		}
		return project;
	}

	public List<Project> list() {
		return projects.values().stream().sorted(Comparator.comparing(Project::createdAt)).toList();
	}

}
