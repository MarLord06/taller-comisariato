using System.ComponentModel.DataAnnotations;
using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Comisariato.Api.Controllers;

[ApiController]
[Route("api/empleados")]
public sealed class EmpleadosController(IVentaService service) : ControllerBase
{
    [HttpGet("{empleadoId}/ventas")]
    [ProducesResponseType<IReadOnlyList<VentaResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IReadOnlyList<VentaResponse>>> Ventas(
        [FromRoute, Range(1, int.MaxValue)] int empleadoId, CancellationToken cancellationToken) =>
        Ok(await service.ListarPorEmpleadoAsync(empleadoId, cancellationToken));
}
