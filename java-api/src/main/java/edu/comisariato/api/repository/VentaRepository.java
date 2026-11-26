package edu.comisariato.api.repository;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import org.springframework.dao.DataRetrievalFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.Types;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public class VentaRepository {

    private static final String CAMPOS_VENTA = """
            ventaid, numerofactura, clienteid, empleadoid, fechaventa,
            subtotal, iva, total, formapago, estado
            """;

    private static final RowMapper<VentaResponse> VENTA = (row, index) -> new VentaResponse(
            row.getInt("ventaid"),
            row.getString("numerofactura"),
            row.getObject("clienteid", Integer.class),
            row.getInt("empleadoid"),
            row.getObject("fechaventa", LocalDateTime.class),
            row.getBigDecimal("subtotal"),
            row.getBigDecimal("iva"),
            row.getBigDecimal("total"),
            row.getString("formapago"),
            row.getString("estado"));

    private final JdbcTemplate jdbc;
    private final ObjectMapper json;

    public VentaRepository(JdbcTemplate jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    public int registrar(VentaRequest request) {
        String detalles;
        try {
            detalles = json.writeValueAsString(request.detalles());
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("No se pudieron serializar los detalles de la venta.", exception);
        }

        return jdbc.query("""
                CALL public.usp_RegistrarVenta(?, ?, ?, ?, CAST(? AS jsonb), NULL)
                """, statement -> {
            statement.setString(1, request.numeroFactura());
            statement.setObject(2, request.clienteId(), Types.INTEGER);
            statement.setInt(3, request.empleadoId());
            statement.setString(4, request.formaPago().name());
            statement.setString(5, detalles);
        }, result -> {
            if (result.next()) {
                Integer ventaId = result.getObject(1, Integer.class);
                if (ventaId != null) {
                    return ventaId;
                }
            }
            throw new DataRetrievalFailureException("El procedimiento no devolvió el ID de la venta.");
        });
    }

    public void anular(int ventaId, int empleadoId) {
        jdbc.update("CALL public.usp_AnularVenta(?, ?)", ventaId, empleadoId);
    }

    public VentaResponse obtener(int ventaId) {
        return jdbc.queryForObject("SELECT " + CAMPOS_VENTA + """
                FROM public.ventas
                WHERE ventaid = ?
                """, VENTA, ventaId);
    }

    public List<VentaResponse> porEmpleado(int empleadoId) {
        return jdbc.query("SELECT " + CAMPOS_VENTA + """
                FROM public.fn_VentasPorEmpleado(?)
                ORDER BY fechaventa DESC, ventaid DESC
                """, VENTA, empleadoId);
    }
}
