"""Pruebas HTTP reproducibles sobre una base de prueba común recién instalada."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from uuid import uuid4


def request(url, path, payload=None):
    headers = {"Accept": "*/*"}
    data = None
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    req = Request(url + path, data=data, headers=headers)
    try:
        response = urlopen(req, timeout=20)
    except HTTPError as error:
        response = error
    with response:
        raw = response.read().decode("utf-8")
        content_type = response.headers.get("Content-Type", "")
        body = json.loads(raw) if raw and "json" in content_type else raw
        return response.status, body


def run(java_url, dotnet_url):
    java = ("Java", java_url)
    dotnet = (".NET", dotnet_url)
    evidence = []
    suffix = uuid4().hex[:8]

    def send(api, path, expected, payload=None, label=None):
        status, body = request(api[1], path, payload)
        if status != expected:
            raise AssertionError(f"{api[0]} {path}: esperaba {expected}, recibió {status}: {body}")
        if expected >= 400:
            assert isinstance(body, dict) and body.get("status") == expected, (api, path, body)
            assert body.get("instance") == path and body.get("detail"), (api, path, body)
        if label:
            evidence.append({
                "api": api[0], "path": path, "method": "POST" if payload is not None else "GET",
                "request": payload, "status": status, "body": body, "label": label,
            })
        return body

    def sale(number, details, employee=1):
        return {
            "numeroFactura": f"{number}-{suffix}", "clienteId": None,
            "empleadoId": employee, "formaPago": "Efectivo", "detalles": details,
        }

    def line(product, quantity):
        return {"productoId": product, "cantidad": quantity}

    for api, health, swagger, openapi in (
        (java, "/actuator/health", "/swagger-ui.html", "/v3/api-docs"),
        (dotnet, "/health", "/swagger/index.html", "/swagger/v1/swagger.json"),
    ):
        assert "Comisariato" in send(api, "/", 200)
        send(api, health, 200)
        assert "swagger" in send(api, swagger, 200).lower()
        paths = send(api, openapi, 200)["paths"]
        for expected in (
            "/api/ventas", "/api/ventas/{ventaId}/anular", "/api/productos/stock-bajo",
            "/api/empleados/{empleadoId}/ventas", "/api/productos/{productoId}/movimientos",
        ):
            assert expected in paths, (api, expected, list(paths))
        assert send(api, "/api/empleados/3/ventas", 200) == []
        send(api, "/api/empleados/999999/ventas", 404, label="Empleado inexistente")
        send(api, "/api/productos/999999/movimientos", 404)
        send(api, "/api/ventas/999999/anular", 404, {"empleadoId": 2})
        send(api, "/api/ventas/999999/anular", 400, {"EmpleadoId": 2})
        send(api, "/api/ventas", 400, {"numeroFactura": "INCOMPLETA"}, "Campos obligatorios")
        send(api, "/api/ventas", 400, sale("SIN-DET", []))
        send(api, "/api/ventas", 400, sale("NULO", [None]))
        send(api, "/api/ventas", 400, sale("REPETIDO", [line(1, 1), line(1, 2)]))
        send(api, "/api/ventas", 400, sale("NEGATIVO", [line(1, -1)]))
        send(api, "/api/ventas", 404, sale("SIN-PROD", [line(999999, 1)]))
        send(api, "/api/ventas", 404, sale("SIN-EMP", [line(1, 1)], employee=999999))

    for index, (origen, consulta) in enumerate(((java, dotnet), (dotnet, java)), start=1):
        movements = send(consulta, "/api/productos/1/movimientos", 200)
        listed = send(consulta, "/api/empleados/1/ventas", 200)
        send(origen, "/api/ventas", 422,
             sale(f"SIN-STOCK{index}", [line(1, 1), line(2, 999)]),
             "Stock insuficiente en la segunda línea")
        assert send(consulta, "/api/productos/1/movimientos", 200) == movements
        assert send(consulta, "/api/empleados/1/ventas", 200) == listed

        payload = sale(f"DEMO{index}", [line(1, 80), line(2, 2)])
        completed = send(origen, "/api/ventas", 201, payload, "Registro de dos productos")
        assert completed["estado"] == "Completada"
        assert completed["clienteId"] is None
        assert (completed["subtotal"], completed["iva"], completed["total"]) == (95.60, 14.34, 109.94)
        sale_id = completed["ventaId"]
        send(origen, "/api/ventas", 409, payload, "Factura duplicada")

        products = send(consulta, "/api/productos/stock-bajo", 200, label="Stock en el umbral")
        assert any(row["productoId"] == 1 and row["stock"] == row["stockMinimo"] == 20 for row in products)
        rows = send(consulta, "/api/empleados/1/ventas", 200, label="Venta visible desde la otra API")
        assert completed in rows, (completed, rows)

        canceled = send(consulta, f"/api/ventas/{sale_id}/anular", 200, {"empleadoId": 2},
                        "Anulación desde la otra API")
        assert canceled == {**completed, "estado": "Anulada"}
        send(origen, f"/api/ventas/{sale_id}/anular", 409, {"empleadoId": 2}, "Anulación repetida")
        for product, initial_stock, sold in ((1, 100, 80), (2, 40, 2)):
            movements = send(origen, f"/api/productos/{product}/movimientos", 200,
                             label="Bitácora de inventario" if product == 1 else None)
            pair = [m for m in movements if m["referenciaId"] == sale_id and m["referenciaTipo"] == "Venta"]
            entry, exit_ = pair
            assert entry["tipoMovimiento"] == "Entrada" and entry["empleadoId"] == 2
            assert exit_["tipoMovimiento"] == "Salida" and exit_["empleadoId"] == 1
            assert (entry["stockAnterior"], entry["stockNuevo"], entry["cantidad"]) == (
                initial_stock - sold, initial_stock, sold,
            )
            assert (exit_["stockAnterior"], exit_["stockNuevo"], exit_["cantidad"]) == (
                initial_stock, initial_stock - sold, sold,
            )
        assert all(row["productoId"] != 1 for row in send(origen, "/api/productos/stock-bajo", 200))

    with ThreadPoolExecutor(max_workers=2) as executor:
        receipts = [
            executor.submit(request, api[1], "/api/ventas", sale(f"CARRERA{index}", [line(5, 50)]))
            for index, api in enumerate((java, dotnet), start=1)
        ]
        race = [task.result() for task in receipts]
        assert sorted(status for status, _ in race) == [201, 422], race
        sale_id = next(body["ventaId"] for status, body in race if status == 201)
        path = f"/api/ventas/{sale_id}/anular"
        cancellations = [executor.submit(request, api[1], path, {"empleadoId": 2}) for api in (java, dotnet)]
        cancellation = [task.result() for task in cancellations]
        assert sorted(status for status, _ in cancellation) == [200, 409], cancellation

    pair = [m for m in send(java, "/api/productos/5/movimientos", 200)
            if m["referenciaId"] == sale_id and m["referenciaTipo"] == "Venta"]
    assert [(m["tipoMovimiento"], m["stockAnterior"], m["stockNuevo"]) for m in pair] == [
        ("Entrada", 30, 80), ("Salida", 80, 30),
    ]
    for (name, _), (status, _), (cancel_status, _) in zip((java, dotnet), race, cancellation):
        evidence.append({"api": name, "status": status, "cancelStatus": cancel_status,
                         "label": "Concurrencia entre ambas APIs"})
    return evidence


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", default="http://127.0.0.1:8081")
    parser.add_argument("--dotnet", default="http://127.0.0.1:5080")
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args()
    checkpoints = run(args.java.rstrip("/"), args.dotnet.rstrip("/"))
    for check in checkpoints:
        print(f"{check['api']:5} HTTP {check['status']} | {check['label']}")
    if args.evidence:
        args.evidence.write_text(json.dumps(checkpoints, ensure_ascii=False, indent=2), encoding="utf-8")
    print("OK | Las dos APIs y las pruebas de concurrencia pasaron.")
