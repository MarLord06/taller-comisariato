using Comisariato.Api.DTOs;
using Npgsql;

namespace Comisariato.Api.Repositories;

public interface IVentaRepository
{
    Task<VentaResponse> RegistrarAsync(
        NpgsqlTransaction transaction, VentaRequest request, CancellationToken cancellationToken);

    Task<VentaResponse> AnularAsync(
        NpgsqlTransaction transaction, int ventaId, int empleadoId, CancellationToken cancellationToken);

    Task<IReadOnlyList<VentaResponse>> ListarPorEmpleadoAsync(
        int empleadoId, CancellationToken cancellationToken);
}
