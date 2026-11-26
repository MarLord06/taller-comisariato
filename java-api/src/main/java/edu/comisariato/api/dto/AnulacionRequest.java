package edu.comisariato.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record AnulacionRequest(@NotNull @Positive Integer empleadoId) {}
