namespace Comisariato.Api.DTOs;

public sealed record VentaResponse(
    int VentaId,
    string NumeroFactura,
    int? ClienteId,
    int EmpleadoId,
    DateTime FechaVenta,
    decimal Subtotal,
    decimal Iva,
    decimal Total,
    string FormaPago,
    string Estado);
