using System.ComponentModel.DataAnnotations;

namespace Comisariato.Api.DTOs;

public sealed record VentaRequest
{
    [Required(ErrorMessage = "Ingresa el número de factura.")]
    [StringLength(20, ErrorMessage = "El número de factura admite hasta 20 caracteres.")]
    public string NumeroFactura { get; init; } = "";

    [Range(1, int.MaxValue, ErrorMessage = "El identificador del cliente debe ser positivo.")]
    public int? ClienteId { get; init; }

    [Range(1, int.MaxValue, ErrorMessage = "El identificador del empleado debe ser positivo.")]
    public int EmpleadoId { get; init; }

    [Required(ErrorMessage = "Selecciona la forma de pago.")]
    [RegularExpression("Efectivo|Tarjeta|Transferencia", ErrorMessage = "Selecciona Efectivo, Tarjeta o Transferencia.")]
    public string FormaPago { get; init; } = "";

    [Required(ErrorMessage = "Ingresa los detalles de la factura.")]
    [MinLength(1, ErrorMessage = "Ingresa al menos un producto.")]
    [DetallesVenta]
    public DetalleVentaRequest[] Detalles { get; init; } = [];
}

public sealed record DetalleVentaRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "El identificador del producto debe ser positivo.")]
    public int ProductoId { get; init; }

    [Range(1, int.MaxValue, ErrorMessage = "La cantidad debe ser un entero positivo.")]
    public int Cantidad { get; init; }
}

[AttributeUsage(AttributeTargets.Property)]
internal sealed class DetallesVentaAttribute : ValidationAttribute
{
    public override bool IsValid(object? value)
    {
        if (value is not DetalleVentaRequest[] detalles)
        {
            return true;
        }

        var productos = new HashSet<int>();
        foreach (var detalle in detalles)
        {
            if (detalle is null || !productos.Add(detalle.ProductoId))
            {
                return false;
            }
        }

        return true;
    }

    public override string FormatErrorMessage(string name) =>
        "Cada detalle requiere un producto y los productos no se pueden repetir.";
}
