package edu.comisariato.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.util.List;

public record VentaRequest(
        @NotBlank @Size(max = 20) String numeroFactura,
        @Schema(nullable = true) @Positive Integer clienteId,
        @NotNull @Positive Integer empleadoId,
        @NotNull FormaPago formaPago,
        @Schema(description = "Líneas de venta con un producto distinto por línea")
        @NotEmpty @ProductosSinRepetir List<@NotNull @Valid VentaDetalleRequest> detalles
) {}
