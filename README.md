# Comisariato

Taller de integración con dos APIs independientes sobre la misma base PostgreSQL. Cada aplicación tiene su propio menú, documentación Swagger y comprobación de salud.

## 1. Instalar la base en pgAdmin

Se requiere PostgreSQL 12 o superior. La instalación y las pruebas se verificaron con PostgreSQL 18.

1. Conéctate al servidor y abre **Query Tool** en la base `postgres`. Ejecuta `database/00_crear_base.sql` con autocommit para crear `comisariato_taller`.
2. Actualiza la lista de bases y abre otro **Query Tool** en `comisariato_taller`. Ejecuta `database/01_esquema_y_datos.sql` completo. Es la instalación inicial de las 10 tablas y 21 filas de prueba.
3. En la misma base, ejecuta `database/02_rutinas_taller.sql`. Crea los dos procedimientos, la vista y la función.
4. Para verificar las operaciones en SQL, ejecuta `database/03_pruebas_pgadmin.sql` sobre la instalación recién cargada. Revisa **Messages** en pgAdmin. El bloque termina en `ROLLBACK`. Los contadores de identidad pueden avanzar.

El SQL usa el esquema `public`. Los campos `Activo` y `Activa` son booleanos. La instalación requiere permiso para crear la base y sus objetos. Para ejecutar las APIs con el mismo usuario que instaló el esquema, usa sus credenciales en las variables indicadas a continuación.

## 2. Ejecutar las dos APIs

Requisitos locales. Java 17 o superior y Maven 3.6.3 o superior para Java. SDK de .NET 8 para .NET. Los ejemplos usan el puerto 5432 de PostgreSQL. Sustituye el usuario y la contraseña de ejemplo por las credenciales de tu conexión de pgAdmin.

En una terminal, desde la raíz del repositorio:

```bash
cd java-api
export DB_URL='jdbc:postgresql://localhost:5432/comisariato_taller'
export DB_USER='postgres'
export DB_PASSWORD='tu_contraseña'
mvn clean package
java -jar target/comisariato-api-1.0.0.jar
```

En otra terminal, desde la raíz del repositorio:

```bash
cd dotnet-api
export ConnectionStrings__Comisariato='Host=localhost;Port=5432;Database=comisariato_taller;Username=postgres;Password=tu_contraseña'
dotnet run --project Comisariato.Api.csproj
```

En PowerShell, sustituye `export VARIABLE='valor'` por `$env:VARIABLE = 'valor'`. Los archivos de ejemplo describen la misma configuración. `SERVER_PORT` y `ASPNETCORE_URLS` permiten configurar otros puertos.

| Aplicación | Menú | Swagger | Salud |
|---|---|---|---|
| Java | [8081](http://localhost:8081/) | `/swagger-ui.html` | `/actuator/health` |
| .NET | [5080](http://localhost:5080/) | `/swagger` | `/health` |

## 3. Probar las operaciones

| Operación | Endpoint | Objeto de PostgreSQL |
|---|---|---|
| Registrar venta | `POST /api/ventas` | `usp_RegistrarVenta` |
| Anular venta | `POST /api/ventas/{ventaId}/anular` | `usp_AnularVenta` |
| Consultar stock bajo | `GET /api/productos/stock-bajo` | `vw_ProductosStockBajo` |
| Consultar ventas por empleado | `GET /api/empleados/{empleadoId}/ventas` | `fn_VentasPorEmpleado` |
| Consultar movimientos | `GET /api/productos/{productoId}/movimientos` | `MovimientosInventario` |

En el menú o Swagger, envía esta venta de dos productos. Los identificadores corresponden a los datos de instalación.

```json
{
  "numeroFactura": "FAC-001",
  "clienteId": null,
  "empleadoId": 1,
  "formaPago": "Efectivo",
  "detalles": [
    { "productoId": 1, "cantidad": 2 },
    { "productoId": 2, "cantidad": 3 }
  ]
}
```

Resultado esperado. **201** con subtotal **13.60**, IVA **2.04** y total **15.64**. El procedimiento lee el precio vigente de cada producto y aplica un IVA didáctico del 15 %. Cambia `numeroFactura` al registrar otra factura. `clienteId` puede ser `null` para consumidor final. Cada producto tiene una línea y las formas de pago disponibles son `Efectivo`, `Tarjeta` y `Transferencia`.

Para anular, envía `{"empleadoId": 2}` con el identificador devuelto en `ventaId`. La API devuelve **200** con estado `Anulada`. Consulta los movimientos de ambos productos para ver la salida y su entrada de reversión.

Los errores tienen formato Problem Details. **400** indica datos inválidos, **404** recurso inexistente, **409** factura duplicada o conflicto de estado, **422** stock insuficiente u otra regla de negocio y **500** error inesperado. Ante SQLSTATE `40P01`, cada API espera un segundo y ejecuta un único reintento en una transacción nueva.

### Prueba de integración

Con ambas APIs conectadas a la misma base de prueba recién instalada, ejecuta desde la raíz:

```bash
python3 tests/integracion.py
```

La prueba usa HTTP y registra ventas que luego anula. Comprueba las cinco operaciones en ambas aplicaciones, los códigos de error, el rollback de la segunda línea, lectura cruzada y dos solicitudes simultáneas de venta y anulación. Usa `--java` y `--dotnet` para cambiar las direcciones.

### Prueba de interbloqueo

`tests/interbloqueo.py` usa dos sesiones deliberadamente en orden inverso para provocar un interbloqueo real. Después verifica una factura confirmada, dos movimientos y una anulación. Ejecútalo sobre la misma base de prueba de ambas APIs, con `psycopg` instalado y una cuenta de prueba con permiso para configurar `deadlock_timeout`.

```bash
python3 -m pip install 'psycopg[binary]'
export PGHOST=localhost PGPORT=5432 PGDATABASE=comisariato_taller PGUSER=postgres
python3 tests/interbloqueo.py
```

Configura la autenticación de PostgreSQL de la misma forma que para tus conexiones locales. El código `40P01` y el reintento se pueden ver en los logs de ambas APIs.

## Adaptación a PostgreSQL

Spring JDBC usa pgJDBC. En ASP.NET Core, ADO.NET usa Npgsql y su objeto `NpgsqlTransaction`. PostgreSQL implementa los procedimientos en PL/pgSQL y reporta interbloqueos con SQLSTATE `40P01`. Se conservan el contrato HTTP, la arquitectura en capas y los límites de transacción del enunciado.
