package edu.comisariato.api;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@OpenAPIDefinition(info = @Info(title = "Comisariato API Java", version = "1.0"))
public class ComisariatoApplication {

    public static void main(String[] args) {
        SpringApplication.run(ComisariatoApplication.class, args);
    }
}
