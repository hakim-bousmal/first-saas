package com.firstsaas.project;

import java.util.UUID;

public class ProjectNotFoundException extends RuntimeException {

	public ProjectNotFoundException(UUID id) {
		super("Project " + id + " not found");
	}

}
