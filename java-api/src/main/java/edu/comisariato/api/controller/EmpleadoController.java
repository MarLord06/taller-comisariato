package edu.comisariato.api.controller;

import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.service.VentaService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import jakarta.validation.constraints.Positive;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

import static org.springframework.http.MediaType.APPLICATION_PROBLEM_JSON_VALUE;

@ApiResponse(responseCode = "500", description = "Error interno",
        content = @Content(mediaType = APPLICATION_PROBLEM_JSON_VALUE,
                schema = @Schema(implementation = ProblemDetail.class)))
@RestController
@RequestMapping("/api/empleados")
public class EmpleadoController {

    private final VentaService service;

    public EmpleadoController(VentaService service) {
        this.service = service;
    }

    @GetMapping("/{empleadoId}/ventas")
    @Operation(summary = "Consultar ventas registradas por un empleado")
    @ApiResponse(responseCode = "200", description = "Ventas del empleado")
    @ApiResponse(responseCode = "400", description = "Identificador inválido",
            content = @Content(mediaType = APPLICATION_PROBLEM_JSON_VALUE,
                    schema = @Schema(implementation = ProblemDetail.class)))
    @ApiResponse(responseCode = "404", description = "Empleado inexistente",
            content = @Content(mediaType = APPLICATION_PROBLEM_JSON_VALUE,
                    schema = @Schema(implementation = ProblemDetail.class)))
    public List<VentaResponse> ventas(@PathVariable @Positive int empleadoId) {
        return service.porEmpleado(empleadoId);
    }
}
