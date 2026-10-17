package com.firstsaas.project;

import java.net.URI;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects")
public class ProjectController {

	private final ProjectService projectService;

	public ProjectController(ProjectService projectService) {
		this.projectService = projectService;
	}

	@PostMapping
	public ResponseEntity<Project> create(@Valid @RequestBody CreateProjectRequest request) {
		Project project = projectService.create(request);
		return ResponseEntity.created(URI.create("/api/v1/projects/" + project.id())).body(project);
	}

	@GetMapping("/{id}")
	public Project get(@PathVariable UUID id) {
		return projectService.get(id);
	}

	@GetMapping
	public List<Project> list() {
		return projectService.list();
	}

}
