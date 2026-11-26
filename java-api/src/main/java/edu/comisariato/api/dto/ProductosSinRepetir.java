package edu.comisariato.api.dto;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.Target;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static java.lang.annotation.ElementType.FIELD;
import static java.lang.annotation.ElementType.PARAMETER;
import static java.lang.annotation.ElementType.RECORD_COMPONENT;
import static java.lang.annotation.RetentionPolicy.RUNTIME;

@Documented
@Target({FIELD, PARAMETER, RECORD_COMPONENT})
@Retention(RUNTIME)
@Constraint(validatedBy = ProductosSinRepetir.Validador.class)
public @interface ProductosSinRepetir {

    String message() default "Cada producto debe aparecer una sola vez.";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class Validador implements ConstraintValidator<ProductosSinRepetir, List<VentaDetalleRequest>> {

        @Override
        public boolean isValid(List<VentaDetalleRequest> detalles, ConstraintValidatorContext context) {
            if (detalles == null) {
                return true;
            }

            Set<Integer> productos = new HashSet<>();
            for (VentaDetalleRequest detalle : detalles) {
                if (detalle != null && detalle.productoId() != null && !productos.add(detalle.productoId())) {
                    return false;
                }
            }
            return true;
        }
    }
}
