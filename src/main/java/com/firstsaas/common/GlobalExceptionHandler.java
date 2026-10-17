package com.firstsaas.common;

import com.firstsaas.project.ProjectNotFoundException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Maps domain exceptions to RFC 9457 problem details. Validation errors are handled by Spring's defaults.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

	@ExceptionHandler(ProjectNotFoundException.class)
	public ProblemDetail handleNotFound(ProjectNotFoundException ex) {
		return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
	}

}
