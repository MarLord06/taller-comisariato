-- BLOQUE 2. Ejecutar después de 01_esquema_y_datos.sql.
-- Las aplicaciones son responsables de confirmar o revertir la transacción.

BEGIN;

-- 2.1. Registrar una factura con uno o más productos.
CREATE OR REPLACE PROCEDURE public.usp_RegistrarVenta(
    IN p_NumeroFactura varchar,
    IN p_ClienteID integer,
    IN p_EmpleadoID integer,
    IN p_FormaPago varchar,
    IN p_Detalles jsonb,
    INOUT p_VentaID integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_TotalLineas bigint;
    v_ProductosDistintos bigint;
    v_LineasInvalidas bigint;
    v_Detalle record;
    v_Stock integer;
    v_Precio numeric(10,2);
    v_Subtotal numeric := 0;
    v_IVA numeric;
    v_Total numeric;
BEGIN
    p_NumeroFactura := btrim(p_NumeroFactura);

    IF p_NumeroFactura IS NULL
       OR p_NumeroFactura !~ '[^[:space:]]'
       OR char_length(p_NumeroFactura) > 20
       OR p_EmpleadoID IS NULL OR p_EmpleadoID <= 0
       OR p_ClienteID <= 0
       OR p_FormaPago IS NULL
       OR p_FormaPago NOT IN ('Efectivo', 'Tarjeta', 'Transferencia') THEN
        RAISE EXCEPTION USING ERRCODE = 'P0400',
            MESSAGE = 'Revisa el número de factura, los identificadores y la forma de pago.';
    END IF;

    IF jsonb_typeof(p_Detalles) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION USING ERRCODE = 'P0400',
            MESSAGE = 'La venta requiere una lista de detalles.';
    END IF;

    BEGIN
        SELECT count(*), count(DISTINCT d."productoId"),
               count(*) FILTER (
                   WHERE d."productoId" IS NULL OR d."productoId" <= 0
                      OR d.Cantidad IS NULL OR d.Cantidad <= 0
               )
        INTO v_TotalLineas, v_ProductosDistintos, v_LineasInvalidas
        FROM jsonb_to_recordset(p_Detalles) AS d("productoId" integer, Cantidad integer);
    EXCEPTION
        WHEN invalid_parameter_value OR invalid_text_representation
             OR numeric_value_out_of_range THEN
            RAISE EXCEPTION USING ERRCODE = 'P0400',
                MESSAGE = 'Cada detalle requiere un producto y una cantidad enteros positivos.';
    END;

    IF v_TotalLineas = 0 OR v_LineasInvalidas > 0 THEN
        RAISE EXCEPTION USING ERRCODE = 'P0400',
            MESSAGE = 'Ingresa al menos un detalle con producto y cantidad positivos.';
    END IF;
    IF v_ProductosDistintos <> v_TotalLineas THEN
        RAISE EXCEPTION USING ERRCODE = 'P0400',
            MESSAGE = 'Cada producto puede aparecer una sola vez por factura.';
    END IF;

    PERFORM 1 FROM public.Empleados WHERE EmpleadoID = p_EmpleadoID FOR KEY SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0404', MESSAGE = 'El empleado no existe.';
    END IF;

    IF p_ClienteID IS NOT NULL THEN
        PERFORM 1 FROM public.Clientes WHERE ClienteID = p_ClienteID FOR KEY SHARE;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = 'P0404', MESSAGE = 'El cliente no existe.';
        END IF;
    END IF;

    -- La restricción UNIQUE resuelve también solicitudes simultáneas.
    -- Los importes se actualizan antes de que otra sesión pueda ver la venta.
    INSERT INTO public.Ventas
        (NumeroFactura, ClienteID, EmpleadoID, Subtotal, IVA, Total, FormaPago)
    VALUES (p_NumeroFactura, p_ClienteID, p_EmpleadoID, 0, 0, 0, p_FormaPago)
    ON CONFLICT ON CONSTRAINT uq_ventas_numerofactura DO NOTHING
    RETURNING VentaID INTO p_VentaID;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0409',
            MESSAGE = 'El número de factura ya existe.';
    END IF;

    -- Venta y anulación bloquean productos en el mismo orden.
    FOR v_Detalle IN
        SELECT d."productoId" AS ProductoID, d.Cantidad
        FROM jsonb_to_recordset(p_Detalles) AS d("productoId" integer, Cantidad integer)
        ORDER BY d."productoId"
    LOOP
        SELECT Stock, PrecioVenta INTO v_Stock, v_Precio
        FROM public.Productos
        WHERE ProductoID = v_Detalle.ProductoID AND Activo
        FOR NO KEY UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El producto % no existe o está inactivo.', v_Detalle.ProductoID
                USING ERRCODE = 'P0404';
        END IF;
        IF v_Stock < v_Detalle.Cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para el producto %. Disponible: %.',
                v_Detalle.ProductoID, v_Stock USING ERRCODE = 'P0422';
        END IF;

        v_Subtotal := v_Subtotal + v_Detalle.Cantidad * v_Precio;
        IF v_Subtotal > 99999999.99 THEN
            RAISE EXCEPTION USING ERRCODE = 'P0422',
                MESSAGE = 'El importe supera el máximo admitido por la factura.';
        END IF;

        INSERT INTO public.DetalleVenta (VentaID, ProductoID, Cantidad, PrecioUnitario)
        VALUES (p_VentaID, v_Detalle.ProductoID, v_Detalle.Cantidad, v_Precio);

        UPDATE public.Productos SET Stock = v_Stock - v_Detalle.Cantidad
        WHERE ProductoID = v_Detalle.ProductoID;

        INSERT INTO public.MovimientosInventario
            (ProductoID, TipoMovimiento, Cantidad, StockAnterior, StockNuevo,
             ReferenciaTipo, ReferenciaID, EmpleadoID)
        VALUES
            (v_Detalle.ProductoID, 'Salida', v_Detalle.Cantidad, v_Stock,
             v_Stock - v_Detalle.Cantidad, 'Venta', p_VentaID, p_EmpleadoID);
    END LOOP;

    -- Tasa didáctica del ejercicio de Comisariato.
    v_IVA := round(v_Subtotal * 0.15, 2);
    v_Total := v_Subtotal + v_IVA;
    IF v_Total > 99999999.99 THEN
        RAISE EXCEPTION USING ERRCODE = 'P0422',
            MESSAGE = 'El importe supera el máximo admitido por la factura.';
    END IF;

    UPDATE public.Ventas SET Subtotal = v_Subtotal, IVA = v_IVA, Total = v_Total
    WHERE VentaID = p_VentaID;
END;
$$;

-- 2.2. Anular una venta completada y devolver las unidades de su detalle.
CREATE OR REPLACE PROCEDURE public.usp_AnularVenta(
    IN p_VentaID integer,
    IN p_EmpleadoID integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_Estado varchar(20);
    v_Detalle record;
    v_Stock integer;
BEGIN
    IF p_VentaID IS NULL OR p_VentaID <= 0 OR p_EmpleadoID IS NULL OR p_EmpleadoID <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = 'P0400',
            MESSAGE = 'Los identificadores de venta y empleado deben ser positivos.';
    END IF;

    SELECT Estado INTO v_Estado
    FROM public.Ventas
    WHERE VentaID = p_VentaID
    FOR NO KEY UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0404', MESSAGE = 'La venta no existe.';
    END IF;
    IF v_Estado <> 'Completada' THEN
        RAISE EXCEPTION 'La venta no se puede anular desde el estado %.', v_Estado
            USING ERRCODE = 'P0409';
    END IF;

    PERFORM 1 FROM public.Empleados WHERE EmpleadoID = p_EmpleadoID FOR KEY SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0404', MESSAGE = 'El empleado no existe.';
    END IF;

    UPDATE public.Ventas SET Estado = 'Anulada' WHERE VentaID = p_VentaID;

    FOR v_Detalle IN
        SELECT ProductoID, Cantidad FROM public.DetalleVenta
        WHERE VentaID = p_VentaID
        ORDER BY ProductoID
    LOOP
        SELECT Stock INTO v_Stock FROM public.Productos
        WHERE ProductoID = v_Detalle.ProductoID
        FOR NO KEY UPDATE;

        IF v_Stock::bigint + v_Detalle.Cantidad > 2147483647 THEN
            RAISE EXCEPTION 'El stock del producto % supera el máximo admitido.', v_Detalle.ProductoID
                USING ERRCODE = 'P0422';
        END IF;

        UPDATE public.Productos SET Stock = v_Stock + v_Detalle.Cantidad
        WHERE ProductoID = v_Detalle.ProductoID;

        INSERT INTO public.MovimientosInventario
            (ProductoID, TipoMovimiento, Cantidad, StockAnterior, StockNuevo,
             ReferenciaTipo, ReferenciaID, EmpleadoID)
        VALUES
            (v_Detalle.ProductoID, 'Entrada', v_Detalle.Cantidad, v_Stock,
             v_Stock + v_Detalle.Cantidad, 'Venta', p_VentaID, p_EmpleadoID);
    END LOOP;
END;
$$;

-- 2.3. Incluir el límite exacto del stock mínimo.
CREATE OR REPLACE VIEW public.vw_ProductosStockBajo AS
SELECT p.ProductoID, p.Nombre, p.Stock, p.StockMinimo, c.Nombre AS Categoria
FROM public.Productos p
JOIN public.Categorias c USING (CategoriaID)
WHERE p.Stock <= p.StockMinimo;

-- 2.4. Distinguir un empleado inexistente de uno que aún no tiene ventas.
CREATE OR REPLACE FUNCTION public.fn_VentasPorEmpleado(p_EmpleadoID integer)
RETURNS SETOF public.Ventas
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.Empleados WHERE EmpleadoID = p_EmpleadoID) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0404', MESSAGE = 'El empleado no existe.';
    END IF;

    RETURN QUERY SELECT v.* FROM public.Ventas v WHERE v.EmpleadoID = p_EmpleadoID;
END;
$$;

COMMIT;
