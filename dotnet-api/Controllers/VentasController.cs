using System.ComponentModel.DataAnnotations;
using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Comisariato.Api.Controllers;

[ApiController]
[Route("api/ventas")]
public sealed class VentasController(IVentaService service) : ControllerBase
{
    [HttpPost]
    [ProducesResponseType<VentaResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<VentaResponse>> Registrar(
        [FromBody] VentaRequest request, CancellationToken cancellationToken)
    {
        var venta = await service.RegistrarAsync(request, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, venta);
    }

    [HttpPost("{ventaId}/anular")]
    [ProducesResponseType<VentaResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<VentaResponse>> Anular(
        [FromRoute, Range(1, int.MaxValue)] int ventaId, [FromBody] AnulacionRequest request,
        CancellationToken cancellationToken)
    {
        var venta = await service.AnularAsync(ventaId, request, cancellationToken);
        return Ok(venta);
    }
}
