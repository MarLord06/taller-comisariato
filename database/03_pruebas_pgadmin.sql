-- BLOQUE 3. Ejecutar sobre la instalación de prueba recién cargada.
-- PostgreSQL revierte los cambios de las pruebas al llegar al ROLLBACK.
-- Las secuencias de identidad pueden avanzar al consumir identificadores.

BEGIN;

DO $$
DECLARE
    v_VentaID integer;
    v_SegundaVentaID integer;
BEGIN
    -- Bloque 3.1. Dos productos, dos salidas y total calculado en PostgreSQL.
    CALL public.usp_RegistrarVenta('PRUEBA-01', NULL, 1, 'Efectivo',
        '[{"productoId":1,"cantidad":2},{"productoId":2,"cantidad":3}]',
        v_VentaID);

    IF NOT EXISTS (
        SELECT 1 FROM public.Ventas
        WHERE VentaID = v_VentaID AND ClienteID IS NULL
          AND Subtotal = 13.60 AND IVA = 2.04 AND Total = 15.64
          AND Estado = 'Completada'
    ) OR (SELECT COUNT(*) FROM public.DetalleVenta WHERE VentaID = v_VentaID) <> 2
      OR (SELECT Stock FROM public.Productos WHERE ProductoID = 1) <> 98
      OR (SELECT Stock FROM public.Productos WHERE ProductoID = 2) <> 37
      OR (SELECT COUNT(*) FROM public.MovimientosInventario
          WHERE ReferenciaTipo = 'Venta' AND ReferenciaID = v_VentaID
            AND TipoMovimiento = 'Salida') <> 2
    THEN
        RAISE EXCEPTION 'La venta de dos productos dejó importes, stock o movimientos incorrectos.';
    END IF;
    RAISE NOTICE 'Venta de dos productos: subtotal 13.60, IVA 2.04, total 15.64 y dos salidas.';

    -- Bloque 3.2. La segunda línea falla, después de procesar la primera.
    BEGIN
        CALL public.usp_RegistrarVenta('PRUEBA-02', 1, 1, 'Tarjeta',
            '[{"productoId":1,"cantidad":1},{"productoId":2,"cantidad":999}]',
            v_SegundaVentaID);
        RAISE EXCEPTION 'Se esperaba P0422 por stock insuficiente.';
    EXCEPTION WHEN SQLSTATE 'P0422' THEN
        RAISE NOTICE 'Stock insuficiente en la segunda línea: SQLSTATE P0422.';
    END;

    IF EXISTS (SELECT 1 FROM public.Ventas WHERE NumeroFactura = 'PRUEBA-02')
      OR (SELECT Stock FROM public.Productos WHERE ProductoID = 1) <> 98
      OR (SELECT COUNT(*) FROM public.MovimientosInventario) <> 2 THEN
        RAISE EXCEPTION 'Quedaron efectos parciales después del error de stock.';
    END IF;

    BEGIN
        CALL public.usp_RegistrarVenta('PRUEBA-01', NULL, 1, 'Efectivo',
            '[{"productoId":1,"cantidad":1}]', v_SegundaVentaID);
        RAISE EXCEPTION 'Se esperaba P0409 por factura duplicada.';
    EXCEPTION WHEN SQLSTATE 'P0409' THEN
        RAISE NOTICE 'Factura duplicada: SQLSTATE P0409.';
    END;

    -- Bloque 3.3. Consulta por empleado y anulación de toda la factura.
    IF (SELECT COUNT(*) FROM public.fn_VentasPorEmpleado(1)
        WHERE VentaID = v_VentaID) <> 1
      OR EXISTS (SELECT 1 FROM public.fn_VentasPorEmpleado(3)) THEN
        RAISE EXCEPTION 'La función de ventas devolvió filas para el empleado equivocado.';
    END IF;
    BEGIN
        PERFORM * FROM public.fn_VentasPorEmpleado(999);
        RAISE EXCEPTION 'Se esperaba P0404 para el empleado que no existe.';
    EXCEPTION WHEN SQLSTATE 'P0404' THEN
        RAISE NOTICE 'Empleado inexistente: SQLSTATE P0404.';
    END;

    CALL public.usp_AnularVenta(v_VentaID, 2);
    IF NOT EXISTS (
        SELECT 1 FROM public.Ventas
        WHERE VentaID = v_VentaID AND Estado = 'Anulada' AND Total = 15.64
    ) OR (SELECT Stock FROM public.Productos WHERE ProductoID = 1) <> 100
      OR (SELECT Stock FROM public.Productos WHERE ProductoID = 2) <> 40
      OR (SELECT COUNT(*) FROM public.MovimientosInventario
          WHERE ReferenciaTipo = 'Venta' AND ReferenciaID = v_VentaID
            AND TipoMovimiento = 'Entrada' AND EmpleadoID = 2) <> 2
    THEN
        RAISE EXCEPTION 'La anulación no restituyó el stock o la bitácora.';
    END IF;
    BEGIN
        CALL public.usp_AnularVenta(v_VentaID, 2);
        RAISE EXCEPTION 'Se esperaba P0409 al repetir la anulación.';
    EXCEPTION WHEN SQLSTATE 'P0409' THEN
        RAISE NOTICE 'Anulación repetida: SQLSTATE P0409. Stock restaurado a 100 y 40.';
    END;

    -- Bloque 3.4. El umbral se cumple cuando el stock es igual al mínimo.
    CALL public.usp_RegistrarVenta('PRUEBA-03', 1, 1, 'Transferencia',
        '[{"productoId":1,"cantidad":80}]', v_SegundaVentaID);
    IF NOT EXISTS (
        SELECT 1 FROM public.vw_ProductosStockBajo
        WHERE ProductoID = 1 AND Stock = 20 AND StockMinimo = 20
    ) THEN
        RAISE EXCEPTION 'La vista excluyó a un producto en el límite.';
    END IF;
    RAISE NOTICE 'Producto 1 incluido en stock bajo con 20 unidades.';
END;
$$;

ROLLBACK;
