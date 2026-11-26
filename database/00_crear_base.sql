-- BLOQUE 0. Ejecutar conectado a postgres y con autocommit.
-- Si ya existe una base vacía con ese nombre, abrirla directamente.
CREATE DATABASE comisariato_taller
    WITH TEMPLATE template0 ENCODING 'UTF8';
