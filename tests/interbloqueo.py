"""Provoca un interbloqueo real en una base de prueba con dos sesiones."""

from concurrent.futures import ThreadPoolExecutor
import argparse
import json
import time
from uuid import uuid4

import psycopg

from integracion import request


def verify_deadlock(url, label, dsn):
    invoice = f"DEAD-{uuid4().hex[:8]}"
    payload = {
        "numeroFactura": invoice, "empleadoId": 2, "formaPago": "Tarjeta",
        "detalles": [{"productoId": 6, "cantidad": 1}, {"productoId": 7, "cantidad": 1}],
    }
    with (ThreadPoolExecutor(max_workers=1) as executor,
          psycopg.connect(dsn, autocommit=True) as monitor,
          psycopg.connect(dsn) as blocker):
        blocker.execute("SET LOCAL deadlock_timeout = '8s'")
        blocker.execute("SELECT 1 FROM productos WHERE productoid = 7 FOR NO KEY UPDATE")
        start = time.monotonic()
        future = executor.submit(request, url, "/api/ventas", payload)
        while not monitor.execute(
            "SELECT EXISTS (SELECT 1 FROM pg_stat_activity "
            "WHERE datname = current_database() AND %s = ANY(pg_blocking_pids(pid)))",
            (blocker.info.backend_pid,),
        ).fetchone()[0]:
            if future.done():
                raise AssertionError(future.result())
            if time.monotonic() - start > 5:
                raise AssertionError("No apareció una sesión bloqueada.")
            time.sleep(0.02)
        # La API posee el bloqueo de producto 6 y espera el producto 7.
        # Esta sesión invierte el orden. PostgreSQL cancela la transacción que detecta el ciclo.
        blocker.execute("SELECT 1 FROM productos WHERE productoid = 6 FOR NO KEY UPDATE")
        blocker.commit()
        status, body = future.result(timeout=8)
        elapsed = time.monotonic() - start
        assert status == 201 and elapsed >= 1.0, (status, body, elapsed)
        sale_id = body["ventaId"]
        count = monitor.execute(
            "SELECT (SELECT count(*) FROM ventas WHERE numerofactura = %s), "
            "(SELECT count(*) FROM movimientosinventario WHERE referenciatipo = 'Venta' "
            "AND referenciaid = %s AND tipomovimiento = 'Salida')",
            (invoice, sale_id),
        ).fetchone()
        assert count == (1, 2), (sale_id, count)
    assert request(url, f"/api/ventas/{sale_id}/anular", {"empleadoId": 2})[0] == 200
    print(json.dumps({
        "api": label, "deadlock": "40P01", "statusTrasReintento": status,
        "segundos": round(elapsed, 2), "facturas": count[0], "salidas": count[1],
    }, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="http://127.0.0.1:8081")
    parser.add_argument("--dotnet", default="http://127.0.0.1:5080")
    parser.add_argument("--dsn", default="", help="Conexión libpq. Por defecto usa las variables PG*.")
    args = parser.parse_args()
    verify_deadlock(args.java.rstrip("/"), "Java", args.dsn)
    verify_deadlock(args.dotnet.rstrip("/"), ".NET", args.dsn)
