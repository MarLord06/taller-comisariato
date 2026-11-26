using System.ComponentModel.DataAnnotations;

namespace Comisariato.Api.DTOs;

public sealed record AnulacionRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "El identificador del empleado debe ser positivo.")]
    public int EmpleadoId { get; init; }
}
