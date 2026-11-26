using System.ComponentModel.DataAnnotations;
using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Comisariato.Api.Controllers;

[ApiController]
[Route("api/productos")]
public sealed class ProductosController(IProductoService service) : ControllerBase
{
    [HttpGet("stock-bajo")]
    [ProducesResponseType<IReadOnlyList<StockBajoResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IReadOnlyList<StockBajoResponse>>> StockBajo(CancellationToken cancellationToken) =>
        Ok(await service.ListarStockBajoAsync(cancellationToken));

    [HttpGet("{productoId}/movimientos")]
    [ProducesResponseType<IReadOnlyList<MovimientoResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IReadOnlyList<MovimientoResponse>>> Movimientos(
        [FromRoute, Range(1, int.MaxValue)] int productoId, CancellationToken cancellationToken) =>
        Ok(await service.ListarMovimientosAsync(productoId, cancellationToken));
}
