-- COMISARIATO | PostgreSQL
-- Ejecutar completo sobre una base vacía. En pgAdmin, abrir Query Tool
-- sobre comisariato_taller después de ejecutar 00_crear_base.sql.
-- Convierte el script inicial de SQL Server y carga sus 21 filas.
-- Los identificadores sin comillas se guardan en minúscula.

BEGIN;
SET LOCAL client_encoding = 'UTF8';

-- TABLAS CATÁLOGO / MAESTRAS

CREATE TABLE public.Categorias (
    CategoriaID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(255) NULL,
    Activa BOOLEAN NOT NULL DEFAULT (TRUE),
    CONSTRAINT PK_Categorias PRIMARY KEY (CategoriaID),
    CONSTRAINT UQ_Categorias_Nombre UNIQUE (Nombre)
);

CREATE TABLE public.Proveedores (
    ProveedorID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    RUC VARCHAR(13) NOT NULL,
    RazonSocial VARCHAR(150) NOT NULL,
    Telefono VARCHAR(20) NULL,
    Email VARCHAR(100) NULL,
    Direccion VARCHAR(255) NULL,
    Activo BOOLEAN NOT NULL DEFAULT (TRUE),
    CONSTRAINT PK_Proveedores PRIMARY KEY (ProveedorID),
    CONSTRAINT UQ_Proveedores_RUC UNIQUE (RUC)
);

CREATE TABLE public.Clientes (
    ClienteID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    Cedula VARCHAR(10) NOT NULL,
    Nombres VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Telefono VARCHAR(20) NULL,
    Email VARCHAR(100) NULL,
    FechaRegistro TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT (CAST(clock_timestamp() AS TIMESTAMP(0) WITHOUT TIME ZONE)),
    CONSTRAINT PK_Clientes PRIMARY KEY (ClienteID),
    CONSTRAINT UQ_Clientes_Cedula UNIQUE (Cedula)
);

CREATE TABLE public.Empleados (
    EmpleadoID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    Cedula VARCHAR(10) NOT NULL,
    Nombres VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Cargo VARCHAR(50) NOT NULL,
    FechaIngreso DATE NOT NULL,
    Salario DECIMAL(10,2) NOT NULL,
    Activo BOOLEAN NOT NULL DEFAULT (TRUE),
    CONSTRAINT PK_Empleados PRIMARY KEY (EmpleadoID),
    CONSTRAINT UQ_Empleados_Cedula UNIQUE (Cedula),
    CONSTRAINT CK_Empleados_Salario CHECK (Salario > 0)
);

-- ============================================================
-- PRODUCTOS
-- ============================================================

CREATE TABLE public.Productos (
    ProductoID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    CodigoBarras VARCHAR(50) NOT NULL,
    Nombre VARCHAR(150) NOT NULL,
    CategoriaID INT NOT NULL,
    ProveedorID INT NULL,
    PrecioCompra DECIMAL(10,2) NOT NULL,
    PrecioVenta DECIMAL(10,2) NOT NULL,
    Stock INT NOT NULL DEFAULT (0),
    StockMinimo INT NOT NULL DEFAULT (0),
    Activo BOOLEAN NOT NULL DEFAULT (TRUE),
    CONSTRAINT PK_Productos PRIMARY KEY (ProductoID),
    CONSTRAINT UQ_Productos_CodigoBarras UNIQUE (CodigoBarras),
    CONSTRAINT FK_Productos_Categorias
        FOREIGN KEY (CategoriaID) REFERENCES public.Categorias(CategoriaID),
    CONSTRAINT FK_Productos_Proveedores
        FOREIGN KEY (ProveedorID) REFERENCES public.Proveedores(ProveedorID),
    CONSTRAINT CK_Productos_PrecioCompra CHECK (PrecioCompra >= 0),
    CONSTRAINT CK_Productos_PrecioVenta CHECK (PrecioVenta >= 0),
    -- Regla didáctica: el comisariato no vende por debajo del costo.
    -- Eliminar esta restricción si se desea modelar promociones o pérdidas.
    CONSTRAINT CK_Productos_Margen CHECK (PrecioVenta >= PrecioCompra),
    CONSTRAINT CK_Productos_Stock CHECK (Stock >= 0),
    CONSTRAINT CK_Productos_StockMin CHECK (StockMinimo >= 0)
);

-- ============================================================
-- VENTAS (cabecera + detalle)
-- ============================================================

CREATE TABLE public.Ventas (
    VentaID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    NumeroFactura VARCHAR(20) NOT NULL,
    ClienteID INT NULL, -- NULL representa consumidor final no identificado.
    EmpleadoID INT NOT NULL,
    FechaVenta TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT (CAST(clock_timestamp() AS TIMESTAMP(0) WITHOUT TIME ZONE)),
    Subtotal DECIMAL(10,2) NOT NULL,
    IVA DECIMAL(10,2) NOT NULL,
    Total DECIMAL(10,2) NOT NULL,
    FormaPago VARCHAR(30) NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT ('Completada'),
    CONSTRAINT PK_Ventas PRIMARY KEY (VentaID),
    CONSTRAINT UQ_Ventas_NumeroFactura UNIQUE (NumeroFactura),
    CONSTRAINT FK_Ventas_Clientes
        FOREIGN KEY (ClienteID) REFERENCES public.Clientes(ClienteID),
    CONSTRAINT FK_Ventas_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES public.Empleados(EmpleadoID),
    CONSTRAINT CK_Ventas_Subtotal CHECK (Subtotal >= 0),
    CONSTRAINT CK_Ventas_IVA CHECK (IVA >= 0),
    CONSTRAINT CK_Ventas_Total CHECK (Total >= 0),
    CONSTRAINT CK_Ventas_FormaPago
        CHECK (FormaPago IN ('Efectivo', 'Tarjeta', 'Transferencia')),
    CONSTRAINT CK_Ventas_Estado
        CHECK (Estado IN ('Pendiente', 'Completada', 'Anulada'))
);

CREATE TABLE public.DetalleVenta (
    DetalleVentaID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    VentaID INT NOT NULL,
    ProductoID INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(10,2) NOT NULL,
    Descuento DECIMAL(10,2) NOT NULL DEFAULT (0),
    SubtotalLinea DECIMAL(12,2) GENERATED ALWAYS AS (Cantidad * PrecioUnitario - Descuento) STORED,
    CONSTRAINT PK_DetalleVenta PRIMARY KEY (DetalleVentaID),
    CONSTRAINT FK_DetalleVenta_Ventas
        FOREIGN KEY (VentaID) REFERENCES public.Ventas(VentaID),
    CONSTRAINT FK_DetalleVenta_Productos
        FOREIGN KEY (ProductoID) REFERENCES public.Productos(ProductoID),
    CONSTRAINT CK_DV_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DV_Precio CHECK (PrecioUnitario >= 0),
    CONSTRAINT CK_DV_Descuento CHECK (Descuento >= 0),
    CONSTRAINT CK_DV_DescuentoMaximo
        CHECK (Descuento <= Cantidad * PrecioUnitario),
    CONSTRAINT UQ_DV_Venta_Producto UNIQUE (VentaID, ProductoID)
);

-- ============================================================
-- COMPRAS A PROVEEDORES (cabecera + detalle)
-- ============================================================

CREATE TABLE public.Compras (
    CompraID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    NumeroOrden VARCHAR(20) NOT NULL,
    ProveedorID INT NOT NULL,
    EmpleadoID INT NOT NULL,
    FechaCompra TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT (CAST(clock_timestamp() AS TIMESTAMP(0) WITHOUT TIME ZONE)),
    Total DECIMAL(10,2) NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT ('Recibida'),
    CONSTRAINT PK_Compras PRIMARY KEY (CompraID),
    CONSTRAINT UQ_Compras_NumeroOrden UNIQUE (NumeroOrden),
    CONSTRAINT FK_Compras_Proveedores
        FOREIGN KEY (ProveedorID) REFERENCES public.Proveedores(ProveedorID),
    CONSTRAINT FK_Compras_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES public.Empleados(EmpleadoID),
    CONSTRAINT CK_Compras_Total CHECK (Total >= 0),
    CONSTRAINT CK_Compras_Estado
        CHECK (Estado IN ('Pendiente', 'Recibida', 'Anulada'))
);

CREATE TABLE public.DetalleCompra (
    DetalleCompraID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    CompraID INT NOT NULL,
    ProductoID INT NOT NULL,
    Cantidad INT NOT NULL,
    CostoUnitario DECIMAL(10,2) NOT NULL,
    SubtotalLinea DECIMAL(12,2) GENERATED ALWAYS AS (Cantidad * CostoUnitario) STORED,
    CONSTRAINT PK_DetalleCompra PRIMARY KEY (DetalleCompraID),
    CONSTRAINT FK_DetalleCompra_Compras
        FOREIGN KEY (CompraID) REFERENCES public.Compras(CompraID),
    CONSTRAINT FK_DetalleCompra_Productos
        FOREIGN KEY (ProductoID) REFERENCES public.Productos(ProductoID),
    CONSTRAINT CK_DC_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DC_Costo CHECK (CostoUnitario >= 0),
    -- Un producto solo puede aparecer una vez en cada orden de compra.
    CONSTRAINT UQ_DC_Compra_Producto UNIQUE (CompraID, ProductoID)
);

-- ============================================================
-- BITÁCORA DE MOVIMIENTOS DE INVENTARIO
-- ============================================================

CREATE TABLE public.MovimientosInventario (
    MovimientoID BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    ProductoID INT NOT NULL,
    TipoMovimiento VARCHAR(20) NOT NULL, -- Entrada / Salida / Ajuste
    Cantidad INT NOT NULL,
    StockAnterior INT NOT NULL,
    StockNuevo INT NOT NULL,
    ReferenciaTipo VARCHAR(20) NULL, -- Venta / Compra / Ajuste
    ReferenciaID INT NULL,            -- Se valida en la lógica transaccional.
    FechaMovimiento TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT (CAST(clock_timestamp() AS TIMESTAMP(0) WITHOUT TIME ZONE)),
    EmpleadoID INT NULL,
    CONSTRAINT PK_MovimientosInventario PRIMARY KEY (MovimientoID),
    CONSTRAINT FK_MovInv_Productos
        FOREIGN KEY (ProductoID) REFERENCES public.Productos(ProductoID),
    CONSTRAINT FK_MovInv_Empleados
        FOREIGN KEY (EmpleadoID) REFERENCES public.Empleados(EmpleadoID),
    CONSTRAINT CK_MovInv_Tipo
        CHECK (TipoMovimiento IN ('Entrada', 'Salida', 'Ajuste')),
    CONSTRAINT CK_MovInv_RefTipo
        CHECK (ReferenciaTipo IN ('Venta', 'Compra', 'Ajuste')
               OR ReferenciaTipo IS NULL),
    CONSTRAINT CK_MovInv_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_MovInv_StockAnterior CHECK (StockAnterior >= 0),
    CONSTRAINT CK_MovInv_StockNuevo CHECK (StockNuevo >= 0),
    CONSTRAINT CK_MovInv_DeltaEntrada
        CHECK (TipoMovimiento <> 'Entrada'
               OR StockNuevo = StockAnterior + Cantidad),
    CONSTRAINT CK_MovInv_DeltaSalida
        CHECK (TipoMovimiento <> 'Salida'
               OR StockNuevo = StockAnterior - Cantidad),
    CONSTRAINT CK_MovInv_ReferenciaCompleta
        CHECK (
            (ReferenciaTipo IS NULL AND ReferenciaID IS NULL)
            OR
            (ReferenciaTipo IS NOT NULL AND ReferenciaID IS NOT NULL)
        )
);

-- ============================================================
-- ÍNDICES DE APOYO
-- Los índices UNIQUE compuestos ya cubren búsquedas por la primera
-- columna (VentaID / CompraID), por eso no se crean índices duplicados.
-- ============================================================

CREATE INDEX IX_Productos_CategoriaID
    ON public.Productos(CategoriaID);

CREATE INDEX IX_Productos_ProveedorID
    ON public.Productos(ProveedorID);

CREATE INDEX IX_Ventas_ClienteID
    ON public.Ventas(ClienteID);

CREATE INDEX IX_Ventas_EmpleadoID
    ON public.Ventas(EmpleadoID);

CREATE INDEX IX_Ventas_FechaVenta
    ON public.Ventas(FechaVenta);

-- No se crea IX_DetalleVenta_VentaID: lo cubre UQ_DV_Venta_Producto.
CREATE INDEX IX_DetalleVenta_ProductoID
    ON public.DetalleVenta(ProductoID);

CREATE INDEX IX_Compras_ProveedorID
    ON public.Compras(ProveedorID);

CREATE INDEX IX_Compras_EmpleadoID
    ON public.Compras(EmpleadoID);

CREATE INDEX IX_DetalleCompra_ProductoID
    ON public.DetalleCompra(ProductoID);

CREATE INDEX IX_MovInv_ProductoID
    ON public.MovimientosInventario(ProductoID);

CREATE INDEX IX_MovInv_EmpleadoID
    ON public.MovimientosInventario(EmpleadoID);

-- ============================================================
-- DATOS DE PRUEBA
-- Ejecutar este bloque una sola vez después de crear las tablas.
-- ============================================================

INSERT INTO public.Categorias (Nombre, Descripcion) VALUES
('Lácteos', 'Leche, quesos, yogures'),
('Bebidas', 'Gaseosas, jugos, agua'),
('Aseo', 'Detergentes, jabones'),
('Snacks', 'Papas, galletas, dulces'),
('Granos', 'Arroz, azúcar, sal');

INSERT INTO public.Proveedores (RUC, RazonSocial, Telefono, Email) VALUES
('1790012345001', 'Distribuidora Andina S.A.', '022345678', 'ventas@andina.com'),
('1790098765001', 'Lácteos del Valle Cía. Ltda.', '022987654', 'contacto@lactvalle.com'),
('1790055555001', 'Importadora El Sol', '022111222', 'info@elsol.com');

INSERT INTO public.Clientes (Cedula, Nombres, Apellidos, Telefono) VALUES
('1712345678', 'María Fernanda', 'Gómez Ruiz', '0991111111'),
('1798765432', 'Carlos Andrés', 'Pérez López', '0992222222'),
('1700112233', 'Ana Lucía', 'Torres Mena', '0993333333');

INSERT INTO public.Empleados
    (Cedula, Nombres, Apellidos, Cargo, FechaIngreso, Salario) VALUES
('1700000001', 'Juan', 'Cajero Uno', 'Cajero', '2022-01-10', 450.00),
('1700000002', 'Pedro', 'Bodeguero Uno', 'Bodeguero', '2021-05-20', 500.00),
('1700000003', 'Lucía', 'Supervisora', 'Supervisor', '2020-03-15', 800.00);

INSERT INTO public.Productos
    (CodigoBarras, Nombre, CategoriaID, ProveedorID,
     PrecioCompra, PrecioVenta, Stock, StockMinimo) VALUES
('7501000000011', 'Leche Entera 1L',       1, 2, 0.75, 1.10, 100, 20),
('7501000000028', 'Queso Fresco 500g',     1, 2, 2.50, 3.80,  40, 10),
('7502000000010', 'Gaseosa Cola 2L',      2, 3, 1.20, 1.90,  60, 15),
('7503000000015', 'Detergente 1kg',       3, 1, 2.10, 3.00,  30, 10),
('7504000000012', 'Papas Fritas 150g',    4, 3, 0.60, 1.00,  80, 20),
('7505000000019', 'Arroz 5lb',            5, 1, 2.40, 3.20,  50, 15),
('7505000000026', 'Azúcar 2kg',           5, 1, 1.50, 2.10,  45, 10);

-- ============================================================

COMMIT;
