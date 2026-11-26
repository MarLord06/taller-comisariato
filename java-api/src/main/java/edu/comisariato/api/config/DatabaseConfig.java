package edu.comisariato.api.config;

import edu.comisariato.api.exception.BusinessException;
import edu.comisariato.api.exception.ConflictException;
import edu.comisariato.api.exception.InvalidRequestException;
import edu.comisariato.api.exception.NotFoundException;
import org.postgresql.util.PSQLException;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.SQLExceptionSubclassTranslator;

import javax.sql.DataSource;
import java.sql.SQLException;

@Configuration(proxyBeanMethods = false)
public class DatabaseConfig {

    @Bean
    JdbcTemplate jdbcTemplate(DataSource dataSource) {
        var jdbc = new JdbcTemplate(dataSource);
        var translator = new SQLExceptionSubclassTranslator();
        translator.setCustomTranslator((task, sql, failure) ->
            switch (String.valueOf(failure.getSQLState())) {
                case "P0400" -> throw new InvalidRequestException(mensajePostgres(failure), failure);
                case "P0404" -> throw new NotFoundException(mensajePostgres(failure), failure);
                case "P0409" -> throw new ConflictException(mensajePostgres(failure), failure);
                case "P0422" -> throw new BusinessException(mensajePostgres(failure), failure);
                default -> null;
            });
        jdbc.setExceptionTranslator(translator);
        return jdbc;
    }

    private static String mensajePostgres(SQLException failure) {
        if (failure instanceof PSQLException postgres && postgres.getServerErrorMessage() != null) {
            return postgres.getServerErrorMessage().getMessage();
        }
        return "La operación fue rechazada por la base de datos.";
    }
}
