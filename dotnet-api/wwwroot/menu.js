const lineas = document.querySelector("#lineas");
const agregar = document.querySelector("#agregar");
const plantilla = document.querySelector("#plantilla-linea");

function actualizarControles() {
  const botones = lineas.querySelectorAll(".remove");
  for (const [indice, boton] of botones.entries()) {
    boton.disabled = botones.length === 1;
    boton.setAttribute("aria-label", `Quitar producto de la línea ${indice + 1}`);
  }
}

function agregarLinea(enfocar) {
  const nueva = plantilla.content.firstElementChild.cloneNode(true);
  nueva.querySelector(".remove").addEventListener("click", () => {
    const anterior = nueva.previousElementSibling ?? nueva.nextElementSibling;
    nueva.remove();
    actualizarControles();
    anterior?.querySelector("[name=productoId]").focus();
  });
  lineas.append(nueva);
  actualizarControles();
  if (enfocar) {
    nueva.querySelector("[name=productoId]").focus();
  }
}

agregar.addEventListener("click", () => agregarLinea(true));
agregarLinea(false);

function conectarFormulario(id, crearSolicitud) {
  const formulario = document.getElementById(id);
  const seccion = formulario.closest("section");
  const estado = seccion.querySelector(".status");
  const resultado = seccion.querySelector(".result");
  const boton = formulario.querySelector("button[type=submit]");

  formulario.addEventListener("submit", async evento => {
    evento.preventDefault();
    const { ruta, cuerpo } = crearSolicitud(new FormData(formulario));
    boton.disabled = true;
    estado.textContent = "Consultando la API…";
    delete estado.dataset.tone;
    resultado.hidden = true;

    try {
      const opciones = cuerpo === undefined ? undefined : {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(cuerpo)
      };
      const respuesta = await fetch(ruta, opciones);
      const texto = await respuesta.text();
      if (respuesta.headers.get("content-type")?.includes("json")) {
        const datos = JSON.parse(texto);
        resultado.textContent = JSON.stringify(datos, null, 2);
        estado.textContent = respuesta.ok
          ? `HTTP ${respuesta.status} · Operación completada`
          : `HTTP ${respuesta.status} · ${datos.title ?? "Error en la solicitud"}`;
      } else {
        resultado.textContent = texto;
        estado.textContent = `HTTP ${respuesta.status}`;
      }
      estado.dataset.tone = respuesta.ok ? "success" : "error";
      resultado.hidden = false;
    } catch {
      estado.textContent = "No se pudo obtener una respuesta de la API.";
      estado.dataset.tone = "error";
    } finally {
      boton.disabled = false;
    }
  });
}

conectarFormulario("venta-form", datos => ({
  ruta: "/api/ventas",
  cuerpo: {
    numeroFactura: datos.get("numeroFactura").trim(),
    clienteId: datos.get("clienteId") ? Number(datos.get("clienteId")) : null,
    empleadoId: Number(datos.get("empleadoId")),
    formaPago: datos.get("formaPago"),
    detalles: [...lineas.querySelectorAll(".linea")].map(linea => ({
      productoId: linea.querySelector("[name=productoId]").valueAsNumber,
      cantidad: linea.querySelector("[name=cantidad]").valueAsNumber
    }))
  }
}));

conectarFormulario("anulacion-form", datos => ({
  ruta: `/api/ventas/${Number(datos.get("ventaId"))}/anular`,
  cuerpo: { empleadoId: Number(datos.get("empleadoId")) }
}));

conectarFormulario("stock-form", () => ({ ruta: "/api/productos/stock-bajo" }));
conectarFormulario("empleado-form", datos => ({
  ruta: `/api/empleados/${Number(datos.get("empleadoId"))}/ventas`
}));
conectarFormulario("movimientos-form", datos => ({
  ruta: `/api/productos/${Number(datos.get("productoId"))}/movimientos`
}));
