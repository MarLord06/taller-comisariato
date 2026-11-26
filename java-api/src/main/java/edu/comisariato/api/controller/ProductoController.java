package edu.comisariato.api.controller;

import edu.comisariato.api.dto.MovimientoResponse;
import edu.comisariato.api.dto.ProductoStockBajoResponse;
import edu.comisariato.api.service.ProductoService;
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
@RequestMapping("/api/productos")
public class ProductoController {

    private final ProductoService service;

    public ProductoController(ProductoService service) {
        this.service = service;
    }

    @GetMapping("/stock-bajo")
    @Operation(summary = "Listar productos con stock igual o inferior al mínimo")
    @ApiResponse(responseCode = "200", description = "Productos con stock bajo")
    public List<ProductoStockBajoResponse> stockBajo() {
        return service.stockBajo();
    }

    @GetMapping("/{productoId}/movimientos")
    @Operation(summary = "Consultar movimientos de inventario de un producto")
    @ApiResponse(responseCode = "200", description = "Movimientos registrados")
    @ApiResponse(responseCode = "400", description = "Identificador inválido",
            content = @Content(mediaType = APPLICATION_PROBLEM_JSON_VALUE,
                    schema = @Schema(implementation = ProblemDetail.class)))
    @ApiResponse(responseCode = "404", description = "Producto inexistente",
            content = @Content(mediaType = APPLICATION_PROBLEM_JSON_VALUE,
                    schema = @Schema(implementation = ProblemDetail.class)))
    public List<MovimientoResponse> movimientos(@PathVariable @Positive int productoId) {
        return service.movimientos(productoId);
    }
}
