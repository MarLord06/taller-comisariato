using System.Text.Json;
using Comisariato.Api.DTOs;
using Npgsql;
using NpgsqlTypes;

namespace Comisariato.Api.Repositories;

public sealed class VentaRepository(NpgsqlDataSource dataSource) : IVentaRepository
{
    private const string ColumnasVenta =
        "ventaid, numerofactura, clienteid, empleadoid, fechaventa, subtotal, iva, total, formapago, estado";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<VentaResponse> RegistrarAsync(
        NpgsqlTransaction transaction, VentaRequest request, CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            "CALL public.usp_RegistrarVenta($1, $2, $3, $4, $5::jsonb, NULL)",
            transaction.Connection, transaction);
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Varchar, Value = request.NumeroFactura });
        command.Parameters.Add(new NpgsqlParameter
        {
            NpgsqlDbType = NpgsqlDbType.Integer,
            Value = (object?)request.ClienteId ?? DBNull.Value
        });
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Integer, Value = request.EmpleadoId });
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Varchar, Value = request.FormaPago });
        command.Parameters.Add(new NpgsqlParameter
        {
            NpgsqlDbType = NpgsqlDbType.Jsonb,
            Value = JsonSerializer.Serialize(request.Detalles, JsonOptions)
        });

        var result = await command.ExecuteScalarAsync(cancellationToken);
        if (result is not int ventaId)
        {
            throw new InvalidOperationException("El procedimiento no devolvió el identificador de la venta.");
        }

        return await CargarVentaAsync(transaction, ventaId, cancellationToken);
    }

    public async Task<VentaResponse> AnularAsync(
        NpgsqlTransaction transaction, int ventaId, int empleadoId, CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            "CALL public.usp_AnularVenta($1, $2)", transaction.Connection, transaction);
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Integer, Value = ventaId });
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Integer, Value = empleadoId });
        await command.ExecuteNonQueryAsync(cancellationToken);

        return await CargarVentaAsync(transaction, ventaId, cancellationToken);
    }

    public async Task<IReadOnlyList<VentaResponse>> ListarPorEmpleadoAsync(
        int empleadoId, CancellationToken cancellationToken)
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            $"""
            SELECT {ColumnasVenta}
            FROM public.fn_VentasPorEmpleado($1)
            ORDER BY fechaventa DESC, ventaid DESC
            """, connection);
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Integer, Value = empleadoId });

        var ventas = new List<VentaResponse>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            ventas.Add(LeerVenta(reader));
        }

        return ventas;
    }

    private static async Task<VentaResponse> CargarVentaAsync(
        NpgsqlTransaction transaction, int ventaId, CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            $"SELECT {ColumnasVenta} FROM public.ventas WHERE ventaid = $1",
            transaction.Connection, transaction);
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Integer, Value = ventaId });

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException($"No se encontró la venta {ventaId} después de ejecutar el procedimiento.");
        }

        return LeerVenta(reader);
    }

    private static VentaResponse LeerVenta(NpgsqlDataReader reader) => new(
        reader.GetInt32(0),
        reader.GetString(1),
        reader.IsDBNull(2) ? null : reader.GetInt32(2),
        reader.GetInt32(3),
        reader.GetDateTime(4),
        reader.GetDecimal(5),
        reader.GetDecimal(6),
        reader.GetDecimal(7),
        reader.GetString(8),
        reader.GetString(9));
}
