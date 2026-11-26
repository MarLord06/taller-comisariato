using Comisariato.Api.DTOs;
using Comisariato.Api.Repositories;

namespace Comisariato.Api.Services;

public sealed class ProductoService(IProductoRepository repository) : IProductoService
{
    public Task<IReadOnlyList<StockBajoResponse>> ListarStockBajoAsync(CancellationToken cancellationToken) =>
        repository.ListarStockBajoAsync(cancellationToken);

    public Task<IReadOnlyList<MovimientoResponse>> ListarMovimientosAsync(
        int productoId, CancellationToken cancellationToken) =>
        repository.ListarMovimientosAsync(productoId, cancellationToken);
}
