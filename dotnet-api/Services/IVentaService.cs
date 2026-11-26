using Comisariato.Api.DTOs;

namespace Comisariato.Api.Services;

public interface IVentaService
{
    Task<VentaResponse> RegistrarAsync(VentaRequest request, CancellationToken cancellationToken);

    Task<VentaResponse> AnularAsync(int ventaId, AnulacionRequest request, CancellationToken cancellationToken);

    Task<IReadOnlyList<VentaResponse>> ListarPorEmpleadoAsync(
        int empleadoId, CancellationToken cancellationToken);
}
