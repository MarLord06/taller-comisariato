package edu.comisariato.api.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.ServletWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;

@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(InvalidRequestException.class)
    ProblemDetail peticionInvalida(InvalidRequestException exception, HttpServletRequest request) {
        return problema(HttpStatus.BAD_REQUEST, exception.getMessage(), exception, request);
    }

    @ExceptionHandler(NotFoundException.class)
    ProblemDetail noEncontrado(NotFoundException exception, HttpServletRequest request) {
        return problema(HttpStatus.NOT_FOUND, exception.getMessage(), exception, request);
    }

    @ExceptionHandler(ConflictException.class)
    ProblemDetail conflicto(ConflictException exception, HttpServletRequest request) {
        return problema(HttpStatus.CONFLICT, exception.getMessage(), exception, request);
    }

    @ExceptionHandler(BusinessException.class)
    ProblemDetail negocio(BusinessException exception, HttpServletRequest request) {
        return problema(HttpStatus.UNPROCESSABLE_ENTITY, exception.getMessage(), exception, request);
    }

    @ExceptionHandler(Exception.class)
    ProblemDetail errorInterno(Exception exception, HttpServletRequest request) {
        return problema(HttpStatus.INTERNAL_SERVER_ERROR,
                "Ocurrió un error al procesar la solicitud.", exception, request);
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException exception, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        var errors = new LinkedHashMap<String, List<String>>();
        for (FieldError error : exception.getBindingResult().getFieldErrors()) {
            errors.computeIfAbsent(error.getField(), key -> new ArrayList<>())
                    .add(error.getDefaultMessage());
        }

        ProblemDetail body = ProblemDetail.forStatusAndDetail(status, "Revise los campos de la solicitud.");
        body.setProperty("errors", errors);
        return handleExceptionInternal(exception, body, headers, status, request);
    }

    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(
            HttpMessageNotReadableException exception, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        ProblemDetail body = ProblemDetail.forStatusAndDetail(status,
                "El cuerpo JSON es obligatorio y debe respetar los tipos del contrato.");
        return handleExceptionInternal(exception, body, headers, status, request);
    }

    @Override
    protected ResponseEntity<Object> handleHandlerMethodValidationException(
            HandlerMethodValidationException exception, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        boolean cuerpoInvalido = exception.getParameterValidationResults().stream()
                .anyMatch(result -> result.getMethodParameter().hasParameterAnnotation(RequestBody.class));
        String detalle = cuerpoInvalido ? "Revise los campos de la solicitud."
                : "Los identificadores de la ruta deben ser enteros positivos.";
        ProblemDetail body = ProblemDetail.forStatusAndDetail(status, detalle);
        return handleExceptionInternal(exception, body, headers, status, request);
    }

    @Override
    protected ResponseEntity<Object> handleExceptionInternal(
            Exception exception, Object body, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        if (request instanceof ServletWebRequest servletRequest) {
            registrarError(status, exception, servletRequest.getRequest());
        }
        return super.handleExceptionInternal(exception, body, headers, status, request);
    }

    private static ProblemDetail problema(
            HttpStatus status, String detail, Exception exception, HttpServletRequest request) {
        registrarError(status, exception, request);
        return ProblemDetail.forStatusAndDetail(status, detail);
    }

    private static void registrarError(HttpStatusCode status, Exception exception, HttpServletRequest request) {
        LOG.error("Solicitud {} {} falló con estado {}", request.getMethod(), request.getRequestURI(),
                status.value(), exception);
    }
}
