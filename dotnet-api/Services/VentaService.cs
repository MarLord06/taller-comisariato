using Comisariato.Api.DTOs;
using Comisariato.Api.Repositories;
using Npgsql;
using Polly.Retry;

namespace Comisariato.Api.Services;

public sealed class VentaService(
    NpgsqlDataSource dataSource,
    IVentaRepository repository,
    AsyncRetryPolicy deadlockRetry,
    ILogger<VentaService> logger) : IVentaService
{
    public async Task<VentaResponse> RegistrarAsync(VentaRequest request, CancellationToken cancellationToken)
    {
        var venta = await deadlockRetry.ExecuteAsync(
            token => EjecutarTransaccionAsync(
                (transaction, ct) => repository.RegistrarAsync(transaction, request, ct), token),
            cancellationToken);

        logger.LogInformation("Venta {VentaId} registrada para el empleado {EmpleadoId}.",
            venta.VentaId, venta.EmpleadoId);
        return venta;
    }

    public async Task<VentaResponse> AnularAsync(
        int ventaId, AnulacionRequest request, CancellationToken cancellationToken)
    {
        var venta = await deadlockRetry.ExecuteAsync(
            token => EjecutarTransaccionAsync(
                (transaction, ct) => repository.AnularAsync(transaction, ventaId, request.EmpleadoId, ct), token),
            cancellationToken);

        logger.LogInformation("Venta {VentaId} anulada por el empleado {EmpleadoId}.",
            venta.VentaId, request.EmpleadoId);
        return venta;
    }

    public Task<IReadOnlyList<VentaResponse>> ListarPorEmpleadoAsync(
        int empleadoId, CancellationToken cancellationToken) =>
        repository.ListarPorEmpleadoAsync(empleadoId, cancellationToken);

    private async Task<VentaResponse> EjecutarTransaccionAsync(
        Func<NpgsqlTransaction, CancellationToken, Task<VentaResponse>> operacion,
        CancellationToken cancellationToken)
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            var venta = await operacion(transaction, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return venta;
        }
        catch
        {
            try
            {
                await transaction.RollbackAsync(CancellationToken.None);
            }
            catch (Exception rollbackError)
            {
                logger.LogError(rollbackError, "Falló la reversión de la transacción de venta.");
            }

            throw;
        }
    }
}
