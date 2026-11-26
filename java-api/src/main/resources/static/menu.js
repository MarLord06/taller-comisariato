const detalles = document.querySelector("#detalles");
const plantilla = document.querySelector("#linea");
const agregar = document.querySelector("#agregar");

function ajustarBotonesQuitar() {
  const botones = detalles.querySelectorAll("[data-quitar]");
  botones.forEach((boton, indice) => {
    boton.disabled = botones.length === 1;
    boton.setAttribute("aria-label", `Quitar producto de la línea ${indice + 1}`);
  });
}

function agregarDetalle(enfocar = false) {
  const linea = plantilla.content.firstElementChild.cloneNode(true);
  linea.querySelector("[data-quitar]").addEventListener("click", () => {
    linea.remove();
    ajustarBotonesQuitar();
    agregar.focus();
  });
  detalles.append(linea);
  ajustarBotonesQuitar();
  if (enfocar) {
    linea.querySelector("[data-producto]").focus();
  }
}

agregar.addEventListener("click", () => agregarDetalle(true));
agregarDetalle();

const operaciones = {
  venta: campos => {
    const cliente = campos.get("clienteId");
    const lineas = Array.from(detalles.children, linea => ({
      productoId: linea.querySelector("[data-producto]").valueAsNumber,
      cantidad: linea.querySelector("[data-cantidad]").valueAsNumber
    }));

    return ["/api/ventas", {
      numeroFactura: campos.get("numeroFactura"),
      clienteId: cliente === "" ? null : Number(cliente),
      empleadoId: Number(campos.get("empleadoId")),
      formaPago: campos.get("formaPago"),
      detalles: lineas
    }];
  },
  anulacion: campos => [`/api/ventas/${Number(campos.get("ventaId"))}/anular`, {
    empleadoId: Number(campos.get("empleadoId"))
  }],
  stock: () => ["/api/productos/stock-bajo"],
  empleado: campos => [`/api/empleados/${Number(campos.get("empleadoId"))}/ventas`],
  movimientos: campos => [`/api/productos/${Number(campos.get("productoId"))}/movimientos`]
};

function mensajeResultado(operacion, respuesta) {
  if (Array.isArray(respuesta)) {
    return respuesta.length === 1 ? "1 resultado" : `${respuesta.length} resultados`;
  }
  if (operacion === "venta") {
    return `Venta ${respuesta.ventaId} registrada. Total: ${respuesta.total}.`;
  }
  return `Venta ${respuesta.ventaId} anulada.`;
}

async function ejecutar(evento) {
  evento.preventDefault();

  const formulario = evento.currentTarget;
  const operacion = formulario.dataset.operacion;
  const boton = formulario.querySelector('[type="submit"]');
  const estado = formulario.querySelector('[role="status"]');
  const salida = formulario.querySelector("pre");
  const [ruta, cuerpo] = operaciones[operacion](new FormData(formulario));
  boton.disabled = true;
  estado.removeAttribute("data-error");
  estado.textContent = "Procesando…";
  salida.hidden = true;

  try {
    const opciones = cuerpo === undefined ? {} : {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(cuerpo)
    };
    const respuesta = await fetch(ruta, opciones);
    const datos = await respuesta.json();
    salida.textContent = JSON.stringify(datos, null, 2);
    salida.hidden = false;

    if (respuesta.ok) {
      estado.textContent = mensajeResultado(operacion, datos);
    } else {
      estado.setAttribute("data-error", "");
      estado.textContent = `HTTP ${respuesta.status}. ${datos.detail || "La solicitud no se completó."}`;
    }
  } catch {
    estado.setAttribute("data-error", "");
    estado.textContent = "No se pudo leer la respuesta del servicio.";
  } finally {
    boton.disabled = false;
  }
}

document.querySelectorAll("[data-operacion]").forEach(formulario => {
  formulario.addEventListener("submit", ejecutar);
});
