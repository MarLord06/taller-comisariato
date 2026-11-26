package edu.comisariato.api.service;

import edu.comisariato.api.dto.MovimientoResponse;
import edu.comisariato.api.dto.ProductoStockBajoResponse;
import edu.comisariato.api.exception.NotFoundException;
import edu.comisariato.api.repository.ProductoRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ProductoService {

    private static final Logger LOG = LoggerFactory.getLogger(ProductoService.class);

    private final ProductoRepository repository;

    public ProductoService(ProductoRepository repository) {
        this.repository = repository;
    }

    public List<ProductoStockBajoResponse> stockBajo() {
        List<ProductoStockBajoResponse> productos = repository.stockBajo();
        LOG.info("Stock bajo consultado resultados={}", productos.size());
        return productos;
    }

    public List<MovimientoResponse> movimientos(int productoId) {
        if (!repository.existe(productoId)) {
            throw new NotFoundException("No existe el producto con ID " + productoId + ".");
        }
        List<MovimientoResponse> movimientos = repository.movimientos(productoId);
        LOG.info("Movimientos consultados productoId={} resultados={}", productoId, movimientos.size());
        return movimientos;
    }
}
