package edu.comisariato.api.repository;

import edu.comisariato.api.dto.MovimientoResponse;
import edu.comisariato.api.dto.ProductoStockBajoResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public class ProductoRepository {

    private final JdbcTemplate jdbc;

    public ProductoRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<ProductoStockBajoResponse> stockBajo() {
        return jdbc.query("""
                SELECT productoid, nombre, stock, stockminimo, categoria
                FROM public.vw_ProductosStockBajo
                ORDER BY productoid
                """, (row, index) -> new ProductoStockBajoResponse(
                row.getInt("productoid"),
                row.getString("nombre"),
                row.getInt("stock"),
                row.getInt("stockminimo"),
                row.getString("categoria")));
    }

    public boolean existe(int productoId) {
        return Boolean.TRUE.equals(jdbc.queryForObject("""
                SELECT EXISTS (SELECT 1 FROM public.productos WHERE productoid = ?)
                """, Boolean.class, productoId));
    }

    public List<MovimientoResponse> movimientos(int productoId) {
        return jdbc.query("""
                SELECT movimientoid, productoid, tipomovimiento, cantidad, stockanterior, stocknuevo,
                       referenciatipo, referenciaid, fechamovimiento, empleadoid
                FROM public.movimientosinventario
                WHERE productoid = ?
                ORDER BY movimientoid DESC
                """, (row, index) -> new MovimientoResponse(
                row.getLong("movimientoid"),
                row.getInt("productoid"),
                row.getString("tipomovimiento"),
                row.getInt("cantidad"),
                row.getInt("stockanterior"),
                row.getInt("stocknuevo"),
                row.getString("referenciatipo"),
                row.getObject("referenciaid", Integer.class),
                row.getObject("fechamovimiento", LocalDateTime.class),
                row.getObject("empleadoid", Integer.class)), productoId);
    }
}
