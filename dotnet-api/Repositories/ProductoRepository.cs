using Comisariato.Api.DTOs;
using Comisariato.Api.Infrastructure;
using Npgsql;
using NpgsqlTypes;

namespace Comisariato.Api.Repositories;

public sealed class ProductoRepository(NpgsqlDataSource dataSource) : IProductoRepository
{
    public async Task<IReadOnlyList<StockBajoResponse>> ListarStockBajoAsync(CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT productoid, nombre, stock, stockminimo, categoria
            FROM public.vw_ProductosStockBajo
            ORDER BY productoid
            """;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var productos = new List<StockBajoResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            productos.Add(new StockBajoResponse(reader.GetInt32(0), reader.GetString(1),
                reader.GetInt32(2), reader.GetInt32(3), reader.GetString(4)));
        }

        return productos;
    }

    public async Task<IReadOnlyList<MovimientoResponse>> ListarMovimientosAsync(
        int productoId, CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT m.movimientoid, p.productoid, m.tipomovimiento, m.cantidad,
                   m.stockanterior, m.stocknuevo, m.referenciatipo, m.referenciaid,
                   m.fechamovimiento, m.empleadoid
            FROM public.productos p
            LEFT JOIN public.movimientosinventario m USING (productoid)
            WHERE p.productoid = $1
            ORDER BY m.movimientoid DESC
            """;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add(new NpgsqlParameter { NpgsqlDbType = NpgsqlDbType.Integer, Value = productoId });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new RecursoNoEncontradoException("El producto no existe.");
        }

        // El LEFT JOIN permite diferenciar un producto sin movimientos de uno que no existe.
        var movimientos = new List<MovimientoResponse>();
        do
        {
            if (!reader.IsDBNull(0))
            {
                movimientos.Add(new MovimientoResponse(reader.GetInt64(0), reader.GetInt32(1),
                    reader.GetString(2), reader.GetInt32(3), reader.GetInt32(4), reader.GetInt32(5),
                    reader.IsDBNull(6) ? null : reader.GetString(6),
                    reader.IsDBNull(7) ? null : reader.GetInt32(7),
                    reader.GetDateTime(8), reader.IsDBNull(9) ? null : reader.GetInt32(9)));
            }
        } while (await reader.ReadAsync(cancellationToken));

        return movimientos;
    }
}
