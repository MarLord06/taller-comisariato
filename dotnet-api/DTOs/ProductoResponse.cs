namespace Comisariato.Api.DTOs;

public sealed record StockBajoResponse(
    int ProductoId,
    string Nombre,
    int Stock,
    int StockMinimo,
    string Categoria);

public sealed record MovimientoResponse(
    long MovimientoId,
    int ProductoId,
    string TipoMovimiento,
    int Cantidad,
    int StockAnterior,
    int StockNuevo,
    string? ReferenciaTipo,
    int? ReferenciaId,
    DateTime FechaMovimiento,
    int? EmpleadoId);
