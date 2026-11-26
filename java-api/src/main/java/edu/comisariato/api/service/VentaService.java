package edu.comisariato.api.service;

import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.repository.VentaRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.SQLException;
import java.util.List;
import java.util.function.Supplier;

@Service
public class VentaService {

    private static final Logger LOG = LoggerFactory.getLogger(VentaService.class);
    private static final long ESPERA_DEADLOCK_MS = 1_000;

    private final VentaTransaccionalService transacciones;
    private final VentaRepository repository;

    public VentaService(VentaTransaccionalService transacciones, VentaRepository repository) {
        this.transacciones = transacciones;
        this.repository = repository;
    }

    public VentaResponse registrar(VentaRequest request) {
        VentaResponse venta = conReintento(() -> transacciones.registrar(request), "registrar", request.empleadoId());
        LOG.info("Venta registrada ventaId={} empleadoId={}", venta.ventaId(), venta.empleadoId());
        return venta;
    }

    public VentaResponse anular(int ventaId, int empleadoId) {
        VentaResponse venta = conReintento(() -> transacciones.anular(ventaId, empleadoId), "anular", ventaId);
        LOG.info("Venta anulada ventaId={} empleadoId={}", ventaId, empleadoId);
        return venta;
    }

    public List<VentaResponse> porEmpleado(int empleadoId) {
        List<VentaResponse> ventas = repository.porEmpleado(empleadoId);
        LOG.info("Ventas consultadas empleadoId={} resultados={}", empleadoId, ventas.size());
        return ventas;
    }

    private VentaResponse conReintento(Supplier<VentaResponse> operacion, String accion, Object referencia) {
        try {
            return operacion.get();
        } catch (RuntimeException exception) {
            if (!esDeadlock(exception)) {
                throw exception;
            }
            LOG.error("Deadlock al {} una venta referencia={}. Reintento en {} ms",
                    accion, referencia, ESPERA_DEADLOCK_MS, exception);
        }

        try {
            Thread.sleep(ESPERA_DEADLOCK_MS);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Se interrumpió el reintento de la venta.", exception);
        }
        return operacion.get();
    }

    private static boolean esDeadlock(Throwable exception) {
        for (Throwable causa = exception; causa != null; causa = causa.getCause()) {
            if (causa instanceof SQLException sql && "40P01".equals(sql.getSQLState())) {
                return true;
            }
        }
        return false;
    }
}
