using Comisariato.Api.DTOs;

namespace Comisariato.Api.Repositories;

public interface IProductoRepository
{
    Task<IReadOnlyList<StockBajoResponse>> ListarStockBajoAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<MovimientoResponse>> ListarMovimientosAsync(
        int productoId, CancellationToken cancellationToken);
}
