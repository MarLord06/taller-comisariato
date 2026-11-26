package edu.comisariato.api.service;

import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.repository.VentaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VentaTransaccionalService {

    private final VentaRepository repository;

    public VentaTransaccionalService(VentaRepository repository) {
        this.repository = repository;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public VentaResponse registrar(VentaRequest request) {
        int ventaId = repository.registrar(request);
        return repository.obtener(ventaId);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public VentaResponse anular(int ventaId, int empleadoId) {
        repository.anular(ventaId, empleadoId);
        return repository.obtener(ventaId);
    }
}
