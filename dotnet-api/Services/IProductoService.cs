using Comisariato.Api.DTOs;

namespace Comisariato.Api.Services;

public interface IProductoService
{
    Task<IReadOnlyList<StockBajoResponse>> ListarStockBajoAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<MovimientoResponse>> ListarMovimientosAsync(
        int productoId, CancellationToken cancellationToken);
}
