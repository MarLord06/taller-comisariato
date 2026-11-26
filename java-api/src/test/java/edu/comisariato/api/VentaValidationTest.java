package edu.comisariato.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class VentaValidationTest {

    @Autowired
    MockMvc mvc;

    @Test
    void rechazaProductosRepetidosAntesDeConsultarLaBase() throws Exception {
        mvc.perform(post("/api/ventas")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "numeroFactura": "PRUEBA-1",
                          "clienteId": null,
                          "empleadoId": 1,
                          "formaPago": "Efectivo",
                          "detalles": [
                            {"productoId": 7, "cantidad": 1},
                            {"productoId": 7, "cantidad": 2}
                          ]
                        }
                        """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.errors['detalles']").exists());
    }
}
