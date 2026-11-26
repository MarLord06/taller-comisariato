package edu.comisariato.api.dto;

public record ProductoStockBajoResponse(
        int productoId,
        String nombre,
        int stock,
        int stockMinimo,
        String categoria
) {}
