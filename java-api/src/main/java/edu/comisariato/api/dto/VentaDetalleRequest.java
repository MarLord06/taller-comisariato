package edu.comisariato.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record VentaDetalleRequest(
        @NotNull @Positive Integer productoId,
        @NotNull @Positive Integer cantidad
) {}
