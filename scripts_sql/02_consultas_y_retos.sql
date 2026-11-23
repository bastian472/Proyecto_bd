-- =====================================================================
-- SABORES Y RUTAS DE SUCRE - ARCHIVO 2 DE 2: CONSULTAS Y RETOS
-- Motor: MySQL 8.0.16+ o MariaDB 10.4+ (XAMPP). Probado en ambos.
--
-- Requisito: haber ejecutado antes el archivo 1 (creación y datos).
--
-- Contenido:
--   1. Procedimientos operativos, vistas y consultas de la Etapa 06
--   2. Transacciones (TCL) y permisos (DCL) de la Etapa 06
--   3. Retos técnicos del Modelo de Negocio 3: triggers, funciones,
--      procedimientos, vistas, JOIN, subconsultas, TCL y DCL
--   4. Verificación final
--
-- Para repetirlo, ejecute de nuevo el archivo 1 y después este: las
-- pruebas de los retos consumen cupos y crean reservas de demostración.
-- =====================================================================

SET NAMES utf8mb4;
SET SQL_SAFE_UPDATES = 0;
USE sabores_rutas_sucre;

-- =====================================================================
-- 5. PROCEDIMIENTOS ALMACENADOS
-- =====================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_crear_reserva$$
CREATE PROCEDURE sp_crear_reserva(
    IN p_id_visitante INT,
    IN p_id_programacion INT,
    IN p_cantidad INT
)
BEGIN
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_monto DECIMAL(12,2);
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La cantidad de personas debe ser mayor que cero';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_existe
    FROM visitantes
    WHERE id_visitante = p_id_visitante;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El visitante indicado no existe';
    END IF;

    SELECT e.precio_base_cop
      INTO v_precio
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE p.id_programacion = p_id_programacion
      AND p.estado_programacion = 'PROGRAMADA';

    SET v_monto = fn_calcular_total_reserva(v_precio, p_cantidad);

    INSERT INTO reservas
      (id_visitante, id_programacion, cantidad_personas,
       monto_total_cop, estado_reserva)
    VALUES
      (p_id_visitante, p_id_programacion, p_cantidad,
       v_monto, 'CONFIRMADA');

    COMMIT;

    SELECT LAST_INSERT_ID() AS id_reserva_creada,
           v_monto AS monto_total_cop,
           'Reserva creada correctamente' AS mensaje;
END$$

DROP PROCEDURE IF EXISTS sp_registrar_pago$$
CREATE PROCEDURE sp_registrar_pago(
    IN p_id_reserva INT,
    IN p_monto DECIMAL(12,2),
    IN p_metodo VARCHAR(20),
    IN p_referencia VARCHAR(64)
)
BEGIN
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_estado VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT monto_total_cop, estado_reserva
      INTO v_total, v_estado
    FROM reservas
    WHERE id_reserva = p_id_reserva
    FOR UPDATE;

    IF v_estado = 'CANCELADA' THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'No se puede pagar una reserva cancelada';
    END IF;

    IF p_monto <= 0 OR p_monto > v_total THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El monto del pago no es válido';
    END IF;

    INSERT INTO pagos
      (id_reserva, monto_cop, metodo_pago, estado_pago,
       referencia_transaccion)
    VALUES
      (p_id_reserva, p_monto, p_metodo, 'APROBADO', p_referencia);

    COMMIT;
    SELECT 'Pago registrado correctamente' AS mensaje;
END$$

DROP PROCEDURE IF EXISTS sp_cancelar_reserva$$
CREATE PROCEDURE sp_cancelar_reserva(IN p_id_reserva INT)
BEGIN
    DECLARE v_estado VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT estado_reserva INTO v_estado
    FROM reservas
    WHERE id_reserva = p_id_reserva
    FOR UPDATE;

    IF v_estado = 'CANCELADA' THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La reserva ya se encuentra cancelada';
    END IF;

    UPDATE reservas
    SET estado_reserva = 'CANCELADA',
        fecha_cancelacion = CURRENT_TIMESTAMP
    WHERE id_reserva = p_id_reserva;

    -- El trigger trg_reservas_devolver_cupos devuelve los cupos.
    COMMIT;
    SELECT 'Reserva cancelada correctamente' AS mensaje;
END$$

DELIMITER ;

-- =====================================================================
-- 6. VISTAS - REPORTES DE NEGOCIO
-- =====================================================================

CREATE OR REPLACE VIEW vw_experiencias_turisticas AS
SELECT
    e.id_experiencia,
    e.titulo,
    e.descripcion,
    c.nombre AS categoria,
    m.nombre AS municipio,
    o.nombre_comercial AS operador,
    e.duracion_horas,
    e.precio_base_cop,
    e.capacidad_max,
    e.estado_experiencia
FROM experiencias e
JOIN categorias c ON c.id_categoria = e.id_categoria
JOIN municipios m ON m.id_municipio = e.id_municipio
JOIN operadores o ON o.id_operador = e.id_operador;

CREATE OR REPLACE VIEW vw_resumen_reservas AS
SELECT
    r.id_reserva,
    CONCAT(v.nombre, ' ', v.apellido) AS visitante,
    e.titulo AS experiencia,
    m.nombre AS municipio,
    p.fecha_actividad,
    r.cantidad_personas,
    r.monto_total_cop,
    r.estado_reserva,
    r.fecha_reserva
FROM reservas r
JOIN visitantes v ON v.id_visitante = r.id_visitante
JOIN programacion p ON p.id_programacion = r.id_programacion
JOIN experiencias e ON e.id_experiencia = p.id_experiencia
JOIN municipios m ON m.id_municipio = e.id_municipio;

CREATE OR REPLACE VIEW vw_ingresos_por_experiencia AS
SELECT
    e.id_experiencia,
    e.titulo AS experiencia,
    COUNT(DISTINCT r.id_reserva) AS total_reservas,
    COALESCE(SUM(
      CASE WHEN pg.estado_pago = 'APROBADO'
           THEN pg.monto_cop ELSE 0 END
    ), 0) AS ingresos_confirmados_cop
FROM experiencias e
LEFT JOIN programacion p ON p.id_experiencia = e.id_experiencia
LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
LEFT JOIN pagos pg ON pg.id_reserva = r.id_reserva
GROUP BY e.id_experiencia, e.titulo;

-- =====================================================================
-- 7. DML - CONSULTAS DE DEMOSTRACIÓN
-- =====================================================================

-- INNER JOIN: reservas con visitante y programación.
SELECT r.id_reserva, v.nombre, v.apellido,
       p.fecha_actividad, r.monto_total_cop
FROM reservas r
INNER JOIN visitantes v ON v.id_visitante = r.id_visitante
INNER JOIN programacion p ON p.id_programacion = r.id_programacion;

-- LEFT JOIN: mostrar todas las experiencias, tengan o no reservas.
SELECT e.titulo, COUNT(r.id_reserva) AS cantidad_reservas
FROM experiencias e
LEFT JOIN programacion p ON p.id_experiencia = e.id_experiencia
LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
GROUP BY e.id_experiencia, e.titulo;

-- Combinación de varias tablas.
SELECT v.nombre, v.apellido, e.titulo, m.nombre AS municipio,
       r.cantidad_personas, r.estado_reserva
FROM reservas r
JOIN visitantes v ON v.id_visitante = r.id_visitante
JOIN programacion p ON p.id_programacion = r.id_programacion
JOIN experiencias e ON e.id_experiencia = p.id_experiencia
JOIN municipios m ON m.id_municipio = e.id_municipio;

-- Subconsulta no correlacionada: experiencias con precio superior
-- al precio promedio de todas las experiencias.
SELECT titulo, precio_base_cop
FROM experiencias
WHERE precio_base_cop > (
    SELECT AVG(precio_base_cop) FROM experiencias
);

-- Subconsulta correlacionada: experiencias que tienen reservas.
SELECT e.id_experiencia, e.titulo
FROM experiencias e
WHERE EXISTS (
    SELECT 1
    FROM programacion p
    JOIN reservas r ON r.id_programacion = p.id_programacion
    WHERE p.id_experiencia = e.id_experiencia
);

-- Funciones agregadas, GROUP BY y HAVING.
SELECT m.nombre AS municipio,
       COUNT(DISTINCT e.id_experiencia) AS experiencias,
       COUNT(r.id_reserva) AS reservas,
       COALESCE(SUM(r.monto_total_cop), 0) AS valor_reservado
FROM municipios m
LEFT JOIN experiencias e ON e.id_municipio = m.id_municipio
LEFT JOIN programacion p ON p.id_experiencia = e.id_experiencia
LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
GROUP BY m.id_municipio, m.nombre
HAVING COUNT(r.id_reserva) >= 1;

-- Función de ventana: ranking de experiencias por cantidad de reservas.
SELECT
    e.titulo,
    COUNT(r.id_reserva) AS total_reservas,
    DENSE_RANK() OVER (ORDER BY COUNT(r.id_reserva) DESC) AS posicion
FROM experiencias e
LEFT JOIN programacion p ON p.id_experiencia = e.id_experiencia
LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
GROUP BY e.id_experiencia, e.titulo;

-- Consultar las vistas.
SELECT * FROM vw_experiencias_turisticas;
SELECT * FROM vw_resumen_reservas;
SELECT * FROM vw_ingresos_por_experiencia;

-- =====================================================================
-- 8. TCL - TRANSACCIONES, COMMIT, ROLLBACK Y SAVEPOINT
-- =====================================================================

-- COMMIT: confirmar un cambio de prueba.
START TRANSACTION;
UPDATE visitantes
SET telefono = '3009990000'
WHERE email = 'visitante1@demo.sabores.test';
COMMIT;

-- ROLLBACK: deshacer un cambio de prueba.
START TRANSACTION;
UPDATE visitantes
SET telefono = '0000000000'
WHERE email = 'visitante2@demo.sabores.test';
ROLLBACK;

-- SAVEPOINT: deshacer solamente una parte de la transacción.
START TRANSACTION;
UPDATE visitantes
SET telefono = '3008880000'
WHERE email = 'visitante3@demo.sabores.test';

SAVEPOINT punto_seguro;

UPDATE visitantes
SET telefono = '1111111111'
WHERE email = 'visitante4@demo.sabores.test';

ROLLBACK TO SAVEPOINT punto_seguro;
COMMIT;

-- UPDATE y DELETE controlados con condición y transacción.
START TRANSACTION;
UPDATE visitantes
SET telefono = '3007770000'
WHERE email = 'visitante5@demo.sabores.test';
COMMIT;

-- DELETE de un registro de demostración específico.
-- Se crea un visitante sin reservas y luego se elimina, para respetar la FK.
INSERT IGNORE INTO visitantes (nombre, apellido, email, telefono)
VALUES ('Registro', 'Temporal', 'visitante.borrar@demo.sabores.test', '3000000000');

START TRANSACTION;
DELETE FROM visitantes
WHERE email = 'visitante.borrar@demo.sabores.test'
  AND NOT EXISTS (
    SELECT 1 FROM reservas r
    WHERE r.id_visitante = visitantes.id_visitante
  );
COMMIT;

-- =====================================================================
-- 9. DCL - ROLES, USUARIOS, GRANT Y REVOKE
-- =====================================================================

-- Los roles separan permisos según las funciones de cada usuario.
CREATE ROLE IF NOT EXISTS 'rol_lectura';
CREATE ROLE IF NOT EXISTS 'rol_escritura';
CREATE ROLE IF NOT EXISTS 'rol_admin';

-- Menor privilegio: lectura solo de consultas y reportes.
GRANT SELECT ON sabores_rutas_sucre.* TO 'rol_lectura';

-- Escritura: lectura e inserción/actualización en tablas operativas.
GRANT SELECT ON sabores_rutas_sucre.* TO 'rol_escritura';
GRANT INSERT, UPDATE ON sabores_rutas_sucre.visitantes TO 'rol_escritura';
GRANT INSERT, UPDATE ON sabores_rutas_sucre.reservas TO 'rol_escritura';
GRANT INSERT ON sabores_rutas_sucre.pagos TO 'rol_escritura';

-- Administración: permisos sobre objetos de la base de datos.
GRANT ALL PRIVILEGES ON sabores_rutas_sucre.* TO 'rol_admin';

-- Ejemplos de usuarios locales para pruebas.
-- Cambiar las contraseñas de ejemplo antes de usar en un entorno real.
CREATE USER IF NOT EXISTS 'usuario_lectura'@'localhost'
  IDENTIFIED BY 'Cambiar_Lectura_2026!';
CREATE USER IF NOT EXISTS 'usuario_escritura'@'localhost'
  IDENTIFIED BY 'Cambiar_Escritura_2026!';
CREATE USER IF NOT EXISTS 'usuario_admin'@'localhost'
  IDENTIFIED BY 'Cambiar_Admin_2026!';

GRANT 'rol_lectura' TO 'usuario_lectura'@'localhost';
GRANT 'rol_escritura' TO 'usuario_escritura'@'localhost';
GRANT 'rol_admin' TO 'usuario_admin'@'localhost';

-- MySQL y MariaDB escriben distinto la asignación del rol por defecto:
--   MySQL 8 : ALTER USER usuario DEFAULT ROLE rol   (o SET DEFAULT ROLE ... TO)
--   MariaDB : SET DEFAULT ROLE rol FOR usuario
-- Este procedimiento detecta el servidor con VERSION() y ejecuta la forma
-- correcta con SQL dinámico (PREPARE / EXECUTE).
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_asignar_rol_por_defecto$$
CREATE PROCEDURE sp_asignar_rol_por_defecto(IN p_rol VARCHAR(64), IN p_usuario VARCHAR(64))
BEGIN
    IF VERSION() LIKE '%MariaDB%' THEN
        SET @sql_rol = CONCAT('SET DEFAULT ROLE ', QUOTE(p_rol),
                              ' FOR ', QUOTE(p_usuario), '@''localhost''');
    ELSE
        SET @sql_rol = CONCAT('ALTER USER ', QUOTE(p_usuario),
                              '@''localhost'' DEFAULT ROLE ', QUOTE(p_rol));
    END IF;
    PREPARE st_rol FROM @sql_rol;
    EXECUTE st_rol;
    DEALLOCATE PREPARE st_rol;
END$$
DELIMITER ;

CALL sp_asignar_rol_por_defecto('rol_lectura', 'usuario_lectura');
CALL sp_asignar_rol_por_defecto('rol_escritura', 'usuario_escritura');
CALL sp_asignar_rol_por_defecto('rol_admin', 'usuario_admin');

-- Ejemplo de REVOKE: retirar permiso de inserción a un rol.
-- Se deja comentado para no alterar el conjunto de permisos al ejecutar.
-- REVOKE INSERT ON sabores_rutas_sucre.visitantes FROM 'rol_escritura';

-- Consultar permisos asignados.
SHOW GRANTS FOR 'rol_lectura';
SHOW GRANTS FOR 'rol_escritura';
SHOW GRANTS FOR 'rol_admin';

-- =====================================================================
-- 10. PRUEBAS DE PROCEDIMIENTOS (EJECUTAR MANUALMENTE)
-- =====================================================================

-- Crear reserva para el visitante 1 en la primera programación disponible.
-- CALL sp_crear_reserva(1, 1, 2);

-- Registrar un pago para una reserva existente.
-- CALL sp_registrar_pago(1, 50000, 'TRANSFERENCIA', 'REF-DEMO-001');

-- Cancelar una reserva existente; el trigger devuelve los cupos.
-- CALL sp_cancelar_reserva(1);

-- =====================================================================
-- 11. VERIFICACIÓN DE MÍNIMOS Y RESULTADOS
-- =====================================================================

SELECT 'visitantes' AS tabla, COUNT(*) AS registros FROM visitantes
UNION ALL
SELECT 'reservas', COUNT(*) FROM reservas
UNION ALL
SELECT 'experiencias', COUNT(*) FROM experiencias
UNION ALL
SELECT 'programacion', COUNT(*) FROM programacion;

-- Verificar objetos procedimentales.
SHOW FULL TABLES IN sabores_rutas_sucre WHERE TABLE_TYPE = 'VIEW';
SHOW FUNCTION STATUS WHERE Db = 'sabores_rutas_sucre';
SHOW PROCEDURE STATUS WHERE Db = 'sabores_rutas_sucre';
SHOW TRIGGERS FROM sabores_rutas_sucre;

-- FIN DE LA ETAPA 06

-- =====================================================================
-- SCRIPT 4 - RETOS TÉCNICOS DEL MODELO DE NEGOCIO 3
-- Cada bloque indica el reto del documento al que responde.
-- Los retos DDL A, B y C están resueltos en el Script 1 (tablas).
-- =====================================================================

USE sabores_rutas_sucre;

-- Visitante usado en las demostraciones de este script.
INSERT IGNORE INTO visitantes (nombre, apellido, email, telefono)
VALUES ('Ana', 'Mercado Salgado', 'ana.turista@correo.test', '3014567890');


-- =====================================================================
-- 4.1 TRIGGERS
-- (Se crean primero porque los procedimientos y las pruebas los usan.)
-- =====================================================================

-- RETO TRIGGER A: descontar cupos automáticamente después de una reserva.
-- Reemplaza al trigger trg_reservas_descontar_cupos del Script 2, que
-- hacía lo mismo con otro nombre.
-- La variable de sesión @cupos_por_procedimiento permite que los
-- procedimientos sp_procesar_reserva y sp_confirmar_reserva_integral
-- (que por enunciado actualizan programacion ellos mismos) eviten que
-- los cupos se descuenten dos veces.
DROP TRIGGER IF EXISTS trg_reservas_descontar_cupos;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_actualizar_cupos_despues_reserva$$
CREATE TRIGGER trg_actualizar_cupos_despues_reserva
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estado_reserva <> 'CANCELADA'
       AND IFNULL(@cupos_por_procedimiento, 0) = 0 THEN
        UPDATE programacion
        SET cupos_disponibles = cupos_disponibles - NEW.cantidad_personas
        WHERE id_programacion = NEW.id_programacion;
    END IF;
END$$

-- RETO TRIGGER B: impedir que los cupos disponibles queden negativos
-- ante reservas concurrentes. Se lanza un error con SIGNAL SQLSTATE.
DROP TRIGGER IF EXISTS trg_prevenir_sobreventa_cupos$$
CREATE TRIGGER trg_prevenir_sobreventa_cupos
BEFORE UPDATE ON programacion
FOR EACH ROW
BEGIN
    IF NEW.cupos_disponibles < 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Sobreventa bloqueada: los cupos disponibles no pueden ser negativos';
    END IF;
END$$
DELIMITER ;

-- RETO TRIGGER C: tabla de auditoría de cancelaciones.
CREATE TABLE IF NOT EXISTS auditoria_cancelaciones (
  id_auditoria      INT           NOT NULL AUTO_INCREMENT,
  id_reserva        INT           NOT NULL,
  fecha_cancelacion DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  usuario_bd        VARCHAR(100)  NOT NULL,
  monto_perdido_cop DECIMAL(12,2) NOT NULL,
  motivo            VARCHAR(255)  NULL,
  PRIMARY KEY (id_auditoria),
  CONSTRAINT fk_auditoria_reservas FOREIGN KEY (id_reserva)
    REFERENCES reservas (id_reserva)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;


-- =====================================================================
-- 4.2 FUNCIONES
-- =====================================================================

DELIMITER $$

-- RETO FUNCIÓN A: cupos disponibles de una fecha programada.
-- Devuelve 0 si la programación no existe o no está activa (PROGRAMADA).
DROP FUNCTION IF EXISTS fn_consultar_cupos_disponibles$$
CREATE FUNCTION fn_consultar_cupos_disponibles(p_id_programacion INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_cupos INT DEFAULT NULL;

    SELECT cupos_disponibles INTO v_cupos
    FROM programacion
    WHERE id_programacion = p_id_programacion
      AND estado_programacion = 'PROGRAMADA'
    LIMIT 1;

    RETURN IFNULL(v_cupos, 0);
END$$

-- RETO FUNCIÓN B: satisfacción promedio de un operador (1 a 5).
-- Une experiencias, programacion, reservas y valoraciones.
-- Si el operador aún no tiene valoraciones devuelve 0.00.
DROP FUNCTION IF EXISTS fn_promedio_satisfaccion_operador$$
CREATE FUNCTION fn_promedio_satisfaccion_operador(p_id_operador INT)
RETURNS NUMERIC(3,2)
READS SQL DATA
BEGIN
    DECLARE v_promedio NUMERIC(3,2);

    SELECT ROUND(AVG(va.puntuacion_estrellas), 2) INTO v_promedio
    FROM experiencias e
    JOIN programacion p ON p.id_experiencia = e.id_experiencia
    JOIN reservas r     ON r.id_programacion = p.id_programacion
    JOIN valoraciones va ON va.id_reserva = r.id_reserva
    WHERE e.id_operador = p_id_operador;

    RETURN IFNULL(v_promedio, 0.00);
END$$

-- RETO FUNCIÓN C: política de reembolso.
-- Si faltan menos de 48 horas para la actividad: SIN_REEMBOLSO.
-- MySQL no tiene "EXCEPTION WHEN OTHERS"; su equivalente es un
-- DECLARE EXIT HANDLER. Aquí atrapa la reserva inexistente (NOT FOUND)
-- y cualquier otro error (SQLEXCEPTION) y devuelve 'RESERVA_INVALIDA'.
DROP FUNCTION IF EXISTS fn_evaluar_reembolso_cancelacion$$
CREATE FUNCTION fn_evaluar_reembolso_cancelacion(p_id_reserva INT)
RETURNS VARCHAR(20)
READS SQL DATA
BEGIN
    DECLARE v_inicio DATETIME;
    DECLARE v_horas INT;

    DECLARE EXIT HANDLER FOR NOT FOUND, SQLEXCEPTION
        RETURN 'RESERVA_INVALIDA';

    SELECT TIMESTAMP(p.fecha_actividad, p.hora_inicio) INTO v_inicio
    FROM reservas r
    JOIN programacion p ON p.id_programacion = r.id_programacion
    WHERE r.id_reserva = p_id_reserva;

    SET v_horas = TIMESTAMPDIFF(HOUR, NOW(), v_inicio);

    IF v_horas < 48 THEN
        RETURN 'SIN_REEMBOLSO';
    END IF;
    RETURN 'REEMBOLSO_TOTAL';
END$$

DELIMITER ;

-- RETO TRIGGER C (continuación): el trigger usa la función anterior
-- para dejar en el motivo si la cancelación tenía derecho a reembolso.
DELIMITER $$
DROP TRIGGER IF EXISTS trg_auditar_cancelacion_reserva$$
CREATE TRIGGER trg_auditar_cancelacion_reserva
AFTER UPDATE ON reservas
FOR EACH ROW
BEGIN
    IF OLD.estado_reserva <> 'CANCELADA'
       AND NEW.estado_reserva = 'CANCELADA' THEN
        INSERT INTO auditoria_cancelaciones
          (id_reserva, fecha_cancelacion, usuario_bd,
           monto_perdido_cop, motivo)
        VALUES
          (NEW.id_reserva,
           IFNULL(NEW.fecha_cancelacion, NOW()),
           USER(),
           NEW.monto_total_cop,
           CONCAT('Cancelación de reserva. Política aplicada: ',
                  fn_evaluar_reembolso_cancelacion(NEW.id_reserva)));
    END IF;
END$$
DELIMITER ;

-- Pruebas de las funciones.
SELECT fn_consultar_cupos_disponibles(1)      AS cupos_programacion_1,
       fn_consultar_cupos_disponibles(999999) AS cupos_programacion_inexistente;

SELECT o.nombre_comercial,
       fn_promedio_satisfaccion_operador(o.id_operador) AS satisfaccion_promedio
FROM operadores o
ORDER BY satisfaccion_promedio DESC;

SELECT r.id_reserva, p.fecha_actividad,
       fn_evaluar_reembolso_cancelacion(r.id_reserva) AS politica
FROM reservas r
JOIN programacion p ON p.id_programacion = r.id_programacion
WHERE r.id_reserva IN (
  (SELECT MIN(id_reserva) FROM reservas),
  (SELECT MAX(id_reserva) FROM reservas));

SELECT fn_evaluar_reembolso_cancelacion(999999) AS reserva_inexistente;


-- =====================================================================
-- 4.3 PROCEDIMIENTOS ALMACENADOS
-- =====================================================================

DELIMITER $$

-- RETO PROCEDIMIENTO A: registrar una nueva experiencia validando datos.
-- p_municipio recibe el nombre del municipio (ej. 'Colosó').
DROP PROCEDURE IF EXISTS sp_registrar_experiencia$$
CREATE PROCEDURE sp_registrar_experiencia(
    IN p_id_operador   INT,
    IN p_id_categoria  INT,
    IN p_titulo        VARCHAR(150),
    IN p_municipio     VARCHAR(80),
    IN p_duracion      DECIMAL(4,1),
    IN p_precio        DECIMAL(12,2),
    IN p_capacidad_max INT
)
BEGIN
    DECLARE v_id_municipio INT DEFAULT NULL;

    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El precio debe ser mayor que cero';
    END IF;
    IF p_duracion IS NULL OR p_duracion <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La duración debe ser mayor que cero';
    END IF;
    IF p_capacidad_max IS NULL OR p_capacidad_max <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La capacidad máxima debe ser mayor que cero';
    END IF;
    IF p_titulo IS NULL OR TRIM(p_titulo) = '' THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El título es obligatorio';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM operadores
                   WHERE id_operador = p_id_operador AND activo = 1) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El operador no existe o está inactivo';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categorias
                   WHERE id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La categoría no existe';
    END IF;

    SELECT id_municipio INTO v_id_municipio
    FROM municipios WHERE nombre = p_municipio LIMIT 1;

    IF v_id_municipio IS NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El municipio no existe';
    END IF;

    INSERT INTO experiencias
      (id_operador, id_categoria, id_municipio, titulo, descripcion,
       duracion_horas, precio_base_cop, capacidad_max, estado_experiencia)
    VALUES
      (p_id_operador, p_id_categoria, v_id_municipio, p_titulo,
       CONCAT('Experiencia registrada en ', p_municipio, '.'),
       p_duracion, p_precio, p_capacidad_max, 'BORRADOR');

    SELECT LAST_INSERT_ID() AS id_experiencia_creada,
           'Experiencia registrada correctamente (estado BORRADOR)' AS mensaje;
END$$

-- RETO PROCEDIMIENTO B: insertar la reserva y restar los cupos.
DROP PROCEDURE IF EXISTS sp_procesar_reserva$$
CREATE PROCEDURE sp_procesar_reserva(
    IN p_id_visitante      INT,
    IN p_id_programacion   INT,
    IN p_cantidad_personas INT
)
BEGIN
    DECLARE v_cupos  INT DEFAULT NULL;
    DECLARE v_precio DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @cupos_por_procedimiento = 0;
        RESIGNAL;
    END;

    IF p_cantidad_personas IS NULL OR p_cantidad_personas <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La cantidad de personas debe ser mayor que cero';
    END IF;

    START TRANSACTION;

    -- FOR UPDATE bloquea la fila para que dos reservas simultáneas
    -- no tomen los mismos cupos.
    SELECT p.cupos_disponibles, e.precio_base_cop
      INTO v_cupos, v_precio
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE p.id_programacion = p_id_programacion
      AND p.estado_programacion = 'PROGRAMADA'
    FOR UPDATE;

    IF v_cupos IS NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La programación no existe o no está disponible';
    END IF;

    IF p_cantidad_personas > v_cupos THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La cantidad solicitada supera los cupos disponibles';
    END IF;

    SET @cupos_por_procedimiento = 1;

    INSERT INTO reservas
      (id_visitante, id_programacion, cantidad_personas,
       monto_total_cop, estado_reserva)
    VALUES
      (p_id_visitante, p_id_programacion, p_cantidad_personas,
       fn_calcular_total_reserva(v_precio, p_cantidad_personas),
       'CONFIRMADA');

    UPDATE programacion
    SET cupos_disponibles = cupos_disponibles - p_cantidad_personas
    WHERE id_programacion = p_id_programacion;

    SET @cupos_por_procedimiento = 0;
    COMMIT;

    SELECT LAST_INSERT_ID() AS id_reserva,
           fn_consultar_cupos_disponibles(p_id_programacion) AS cupos_restantes,
           'Reserva procesada correctamente' AS mensaje;
END$$

-- RETO PROCEDIMIENTO C: proceso integral con código de respuesta.
-- p_codigo_respuesta: 0 = Éxito, -1 = Cupos insuficientes,
--                    -2 = Error en el pago, -3 = Error inesperado.
-- El EXIT HANDLER cumple el papel de "EXCEPTION WHEN OTHERS".
DROP PROCEDURE IF EXISTS sp_confirmar_reserva_integral$$
CREATE PROCEDURE sp_confirmar_reserva_integral(
    IN  p_id_visitante      INT,
    IN  p_id_programacion   INT,
    IN  p_cantidad_personas INT,
    IN  p_metodo_pago       VARCHAR(20),
    IN  p_referencia        VARCHAR(64),
    OUT p_codigo_respuesta  INT,
    OUT p_id_reserva        INT
)
proceso: BEGIN
    DECLARE v_cupos  INT DEFAULT NULL;
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_monto  DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @cupos_por_procedimiento = 0;
        SET p_codigo_respuesta = -3;
        SET p_id_reserva = NULL;
    END;

    SET p_id_reserva = NULL;
    START TRANSACTION;

    -- 1. Validar que el visitante exista.
    IF NOT EXISTS (SELECT 1 FROM visitantes
                   WHERE id_visitante = p_id_visitante) THEN
        ROLLBACK;
        SET p_codigo_respuesta = -3;
        LEAVE proceso;
    END IF;

    -- 2. Validar disponibilidad de cupos (con bloqueo de la fila).
    SELECT p.cupos_disponibles, e.precio_base_cop
      INTO v_cupos, v_precio
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE p.id_programacion = p_id_programacion
      AND p.estado_programacion = 'PROGRAMADA'
    FOR UPDATE;

    IF v_cupos IS NULL OR p_cantidad_personas IS NULL
       OR p_cantidad_personas <= 0 OR p_cantidad_personas > v_cupos THEN
        ROLLBACK;
        SET p_codigo_respuesta = -1;
        LEAVE proceso;
    END IF;

    -- 3. Validar el pago antes de grabar nada.
    IF p_metodo_pago IS NULL
       OR p_metodo_pago NOT IN ('EFECTIVO','TRANSFERENCIA','TARJETA','OTRO') THEN
        ROLLBACK;
        SET p_codigo_respuesta = -2;
        LEAVE proceso;
    END IF;

    SET v_monto = fn_calcular_total_reserva(v_precio, p_cantidad_personas);
    SET @cupos_por_procedimiento = 1;

    -- 4. Insertar reserva y pago, y actualizar la disponibilidad.
    INSERT INTO reservas
      (id_visitante, id_programacion, cantidad_personas,
       monto_total_cop, estado_reserva)
    VALUES
      (p_id_visitante, p_id_programacion, p_cantidad_personas,
       v_monto, 'CONFIRMADA');

    SET p_id_reserva = LAST_INSERT_ID();

    INSERT INTO pagos
      (id_reserva, monto_cop, metodo_pago, estado_pago,
       referencia_transaccion)
    VALUES
      (p_id_reserva, v_monto, p_metodo_pago, 'APROBADO', p_referencia);

    UPDATE programacion
    SET cupos_disponibles = cupos_disponibles - p_cantidad_personas
    WHERE id_programacion = p_id_programacion;

    SET @cupos_por_procedimiento = 0;
    COMMIT;
    SET p_codigo_respuesta = 0;
END$$

DELIMITER ;

-- Pruebas de los procedimientos.
-- A) Registro válido y registro con precio inválido (el inválido se deja
--    comentado porque detiene la ejecución del archivo con un error).
CALL sp_registrar_experiencia(
  (SELECT id_operador FROM operadores WHERE nit = '900200104-6'),
  (SELECT id_categoria FROM categorias WHERE nombre = 'Naturaleza'),
  'Ascenso al Cerro de Colosó', 'Colosó', 4.5, 85000, 12);
-- CALL sp_registrar_experiencia(1, 1, 'Prueba inválida', 'Sincelejo', 2, 0, 10);
--   Resultado esperado: ERROR 1644 (45000): El precio debe ser mayor que cero

-- B) Reserva de 2 personas en la próxima salida disponible del mote de queso.
SET @vis = (SELECT id_visitante FROM visitantes
            WHERE email = 'ana.turista@correo.test');
SET @prog_mote = (
  SELECT p.id_programacion
  FROM programacion p
  JOIN experiencias e ON e.id_experiencia = p.id_experiencia
  WHERE e.titulo = 'Ruta Gastronómica del Mote de Queso en Sincelejo'
    AND p.estado_programacion = 'PROGRAMADA'
    AND p.fecha_actividad >= CURDATE()
    AND p.cupos_disponibles >= 6
  ORDER BY p.fecha_actividad
  LIMIT 1);
SELECT @prog_mote AS programacion_usada,
       fn_consultar_cupos_disponibles(@prog_mote) AS cupos_antes;
CALL sp_procesar_reserva(@vis, @prog_mote, 2);

-- C) Tres casos del procedimiento integral.
CALL sp_confirmar_reserva_integral(@vis, @prog_mote, 1, 'TARJETA',
                                   'REF-INTEGRAL-001', @codigo, @id_res);
SELECT @codigo AS codigo_exito_esperado_0, @id_res AS id_reserva_creada;

CALL sp_confirmar_reserva_integral(@vis, @prog_mote, 500, 'TARJETA',
                                   'REF-INTEGRAL-002', @codigo, @id_res);
SELECT @codigo AS codigo_cupos_insuficientes_esperado_menos1;

CALL sp_confirmar_reserva_integral(@vis, @prog_mote, 1, 'BITCOIN',
                                   'REF-INTEGRAL-003', @codigo, @id_res);
SELECT @codigo AS codigo_error_pago_esperado_menos2;

CALL sp_confirmar_reserva_integral(999999, @prog_mote, 1, 'TARJETA',
                                   'REF-INTEGRAL-004', @codigo, @id_res);
SELECT @codigo AS codigo_error_inesperado_esperado_menos3;

-- Prueba del trigger B: intentar dejar cupos negativos.
-- Se deja comentado porque el error detiene la ejecución del archivo.
-- UPDATE programacion SET cupos_disponibles = -5 WHERE id_programacion = 1;
--   Resultado esperado: ERROR 1644 (45000): Sobreventa bloqueada: los
--   cupos disponibles no pueden ser negativos

-- Prueba del trigger C: cancelar una reserva y revisar la auditoría.
SET @id_res_cancelar = (
  SELECT MAX(id_reserva) FROM reservas
  WHERE id_visitante = @vis AND estado_reserva = 'CONFIRMADA');
CALL sp_cancelar_reserva(@id_res_cancelar);
SELECT * FROM auditoria_cancelaciones;


-- =====================================================================
-- 4.4 VISTAS
-- =====================================================================

-- RETO VISTA A: experiencias con fechas futuras y cupos libres.
CREATE OR REPLACE VIEW v_experiencias_disponibles_web AS
SELECT
    p.id_programacion   AS id_programacion,
    e.titulo            AS titulo_experiencia,
    m.nombre            AS municipio,
    o.nombre_comercial  AS operador,
    p.fecha_actividad   AS fecha,
    p.hora_inicio       AS hora,
    p.cupos_disponibles AS cupos_libres
FROM programacion p
JOIN experiencias e ON e.id_experiencia = p.id_experiencia
JOIN operadores o   ON o.id_operador = e.id_operador
JOIN municipios m   ON m.id_municipio = e.id_municipio
WHERE p.fecha_actividad >= CURRENT_DATE
  AND p.cupos_disponibles > 0
  AND p.estado_programacion = 'PROGRAMADA'
  AND e.estado_experiencia = 'ACTIVA';

-- RETO VISTA B: logística por operador y fecha programada.
-- Cupos reservados = personas de reservas no canceladas.
CREATE OR REPLACE VIEW v_resumen_operaciones_operador AS
SELECT
    o.nombre_comercial AS nombre_comercial_operador,
    o.telefono         AS telefono,
    e.titulo           AS titulo_experiencia,
    p.fecha_actividad  AS fecha_actividad,
    p.cupos_totales    AS cupos_totales,
    COALESCE(SUM(CASE WHEN r.estado_reserva <> 'CANCELADA'
                      THEN r.cantidad_personas END), 0) AS cupos_reservados,
    ROUND(COALESCE(SUM(CASE WHEN r.estado_reserva <> 'CANCELADA'
                            THEN r.cantidad_personas END), 0)
          * 100 / p.cupos_totales, 2) AS porcentaje_ocupacion
FROM operadores o
JOIN experiencias e   ON e.id_operador = o.id_operador
JOIN programacion p   ON p.id_experiencia = e.id_experiencia
LEFT JOIN reservas r  ON r.id_programacion = p.id_programacion
GROUP BY o.id_operador, o.nombre_comercial, o.telefono,
         p.id_programacion, e.titulo, p.fecha_actividad, p.cupos_totales;

-- RETO VISTA C: KPI de desempeño por experiencia.
-- La ocupación se calcula por cada salida y luego se promedia; el
-- recaudo se calcula aparte para no duplicar pagos al unir tablas.
CREATE OR REPLACE VIEW v_kpi_desempeno_experiencias AS
SELECT
    e.id_experiencia,
    e.titulo,
    ROUND(AVG(oc.ocupacion), 2) AS tasa_ocupacion_promedio,
    COALESCE((
        SELECT SUM(pg.monto_cop)
        FROM programacion p2
        JOIN reservas r2 ON r2.id_programacion = p2.id_programacion
        JOIN pagos pg    ON pg.id_reserva = r2.id_reserva
        WHERE p2.id_experiencia = e.id_experiencia
          AND pg.estado_pago = 'APROBADO'
    ), 0) AS recaudo_total_cop,
    CASE
        WHEN AVG(oc.ocupacion) >= 85 THEN 'EXCELENTE'
        WHEN AVG(oc.ocupacion) >= 50 THEN 'ACEPTABLE'
        ELSE 'BAJO_RENDIMIENTO'
    END AS categoria_desempeno
FROM experiencias e
JOIN (
    SELECT p.id_programacion, p.id_experiencia,
           COALESCE(SUM(CASE WHEN r.estado_reserva <> 'CANCELADA'
                             THEN r.cantidad_personas END), 0)
             * 100 / p.cupos_totales AS ocupacion
    FROM programacion p
    LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
    WHERE p.estado_programacion <> 'CANCELADA'
    GROUP BY p.id_programacion, p.id_experiencia, p.cupos_totales
) oc ON oc.id_experiencia = e.id_experiencia
GROUP BY e.id_experiencia, e.titulo;

SELECT * FROM v_experiencias_disponibles_web ORDER BY fecha LIMIT 10;
SELECT * FROM v_resumen_operaciones_operador
ORDER BY fecha_actividad DESC LIMIT 10;
SELECT * FROM v_kpi_desempeno_experiencias
ORDER BY recaudo_total_cop DESC;


-- =====================================================================
-- 4.5 DML - CONSULTAS CON JOIN
-- =====================================================================

-- RETO JOIN A: visitantes con los tours adquiridos.
-- El monto pagado suma solo los pagos APROBADO de cada reserva.
SELECT
    CONCAT(v.nombre, ' ', v.apellido)  AS `Nombre del Visitante`,
    v.email                            AS `Email`,
    e.titulo                           AS `Título de la Experiencia`,
    m.nombre                           AS `Municipio de Ubicación`,
    p.fecha_actividad                  AS `Fecha de la Actividad`,
    COALESCE(SUM(pg.monto_cop), 0)     AS `Monto Total Pagado`
FROM reservas r
JOIN visitantes v   ON v.id_visitante = r.id_visitante
JOIN programacion p ON p.id_programacion = r.id_programacion
JOIN experiencias e ON e.id_experiencia = p.id_experiencia
JOIN municipios m   ON m.id_municipio = e.id_municipio
LEFT JOIN pagos pg  ON pg.id_reserva = r.id_reserva
                   AND pg.estado_pago = 'APROBADO'
WHERE r.estado_reserva <> 'CANCELADA'   -- solo tours efectivamente adquiridos
GROUP BY r.id_reserva, v.nombre, v.apellido, v.email,
         e.titulo, m.nombre, p.fecha_actividad
ORDER BY p.fecha_actividad DESC, `Nombre del Visitante`;

-- RETO JOIN B: acogida de cada experiencia en el último trimestre
-- (reservas registradas en los últimos 3 meses, sin las canceladas).
SELECT
    o.nombre_comercial              AS `Operador`,
    e.titulo                        AS `Experiencia`,
    COUNT(r.id_reserva)             AS `Total de Reservas Registradas`,
    SUM(r.cantidad_personas)        AS `Personas Totales Acumuladas`,
    SUM(r.monto_total_cop)          AS `Ingreso Bruto Generado`
FROM operadores o
JOIN experiencias e ON e.id_operador = o.id_operador
JOIN programacion p ON p.id_experiencia = e.id_experiencia
JOIN reservas r     ON r.id_programacion = p.id_programacion
WHERE r.fecha_reserva >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
  AND r.estado_reserva <> 'CANCELADA'
GROUP BY o.id_operador, o.nombre_comercial, e.id_experiencia, e.titulo
ORDER BY `Ingreso Bruto Generado` DESC;

-- RETO JOIN C: demanda y calidad por municipio (5 tablas + municipios).
SELECT
    m.nombre                              AS `Municipio de Ubicación`,
    COUNT(DISTINCT r.id_reserva)          AS `Total de Reservas Confirmadas`,
    SUM(r.cantidad_personas)              AS `Suma de Visitantes`,
    ROUND(AVG(va.puntuacion_estrellas), 2) AS `Promedio de Puntuación`
FROM experiencias e
JOIN operadores o    ON o.id_operador = e.id_operador
JOIN municipios m    ON m.id_municipio = e.id_municipio
JOIN programacion p  ON p.id_experiencia = e.id_experiencia
JOIN reservas r      ON r.id_programacion = p.id_programacion
LEFT JOIN valoraciones va ON va.id_reserva = r.id_reserva
WHERE r.estado_reserva IN ('CONFIRMADA', 'COMPLETADA')
GROUP BY m.id_municipio, m.nombre
ORDER BY `Promedio de Puntuación` DESC;


-- =====================================================================
-- 4.6 DML - SUBCONSULTAS
-- =====================================================================

-- RETO SUBCONSULTA A: experiencias sin ninguna reserva activa
-- (activa = no cancelada), para lanzar promociones.
SELECT e.id_experiencia, e.titulo, m.nombre AS municipio,
       e.precio_base_cop
FROM experiencias e
JOIN municipios m ON m.id_municipio = e.id_municipio
WHERE NOT EXISTS (
    SELECT 1
    FROM programacion p
    JOIN reservas r ON r.id_programacion = p.id_programacion
    WHERE p.id_experiencia = e.id_experiencia
      AND r.estado_reserva <> 'CANCELADA'
);

-- RETO SUBCONSULTA B: insignia "Experiencia Destacada".
-- El promedio general (personas por experiencia) se calcula con una
-- subconsulta escalar dentro del HAVING.
SELECT e.titulo,
       SUM(r.cantidad_personas) AS total_visitantes,
       'Experiencia Destacada' AS insignia
FROM experiencias e
JOIN programacion p ON p.id_experiencia = e.id_experiencia
JOIN reservas r     ON r.id_programacion = p.id_programacion
WHERE r.estado_reserva <> 'CANCELADA'
GROUP BY e.id_experiencia, e.titulo
HAVING SUM(r.cantidad_personas) > (
    SELECT AVG(t.total)
    FROM (
        SELECT SUM(r2.cantidad_personas) AS total
        FROM programacion p2
        JOIN reservas r2 ON r2.id_programacion = p2.id_programacion
        WHERE r2.estado_reserva <> 'CANCELADA'
        GROUP BY p2.id_experiencia
    ) t
)
ORDER BY total_visitantes DESC;

-- RETO SUBCONSULTA C: experiencias que superan el promedio de su propia
-- categoría. La subconsulta interna está correlacionada con la externa
-- mediante e2.id_categoria = e.id_categoria (en el HAVING).
SELECT c.nombre AS categoria,
       e.titulo,
       SUM(r.cantidad_personas) AS personas_atendidas
FROM experiencias e
JOIN categorias c   ON c.id_categoria = e.id_categoria
JOIN programacion p ON p.id_experiencia = e.id_experiencia
JOIN reservas r     ON r.id_programacion = p.id_programacion
WHERE r.estado_reserva <> 'CANCELADA'
GROUP BY e.id_experiencia, e.titulo, e.id_categoria, c.nombre
HAVING SUM(r.cantidad_personas) > (
    SELECT SUM(r2.cantidad_personas) / COUNT(DISTINCT e2.id_experiencia)
    FROM experiencias e2
    JOIN programacion p2 ON p2.id_experiencia = e2.id_experiencia
    JOIN reservas r2     ON r2.id_programacion = p2.id_programacion
    WHERE r2.estado_reserva <> 'CANCELADA'
      AND e2.id_categoria = e.id_categoria   -- correlación
)
ORDER BY c.nombre, personas_atendidas DESC;


-- =====================================================================
-- 4.7 TCL - TRANSACCIONES
-- =====================================================================

-- RETO TCL A: reserva y pago como una sola unidad atómica.
SET @prog_tcl = (
  SELECT p.id_programacion
  FROM programacion p
  JOIN experiencias e ON e.id_experiencia = p.id_experiencia
  WHERE e.titulo = 'Ruta Gastronómica del Mote de Queso en Sincelejo'
    AND p.estado_programacion = 'PROGRAMADA'
    AND p.fecha_actividad >= CURDATE()
    AND p.cupos_disponibles >= 2
  ORDER BY p.fecha_actividad
  LIMIT 1);
SET @monto_tcl = (
  SELECT fn_calcular_total_reserva(precio_base_cop, 2)
  FROM experiencias
  WHERE titulo = 'Ruta Gastronómica del Mote de Queso en Sincelejo');

START TRANSACTION;
INSERT INTO reservas
  (id_visitante, id_programacion, cantidad_personas,
   monto_total_cop, estado_reserva)
VALUES (@vis, @prog_tcl, 2, @monto_tcl, 'CONFIRMADA');
SET @id_reserva_tcl = LAST_INSERT_ID();
INSERT INTO pagos
  (id_reserva, monto_cop, metodo_pago, estado_pago, referencia_transaccion)
VALUES (@id_reserva_tcl, @monto_tcl, 'TARJETA', 'APROBADO', 'REF-TCL-A-001');
COMMIT;

-- Persistencia de ambos registros:
SELECT r.id_reserva, r.estado_reserva, r.monto_total_cop,
       pg.id_pago, pg.estado_pago, pg.monto_cop
FROM reservas r
JOIN pagos pg ON pg.id_reserva = r.id_reserva
WHERE r.id_reserva = @id_reserva_tcl;

-- RETO TCL B: ROLLBACK si se piden más cupos de los disponibles.
-- En MySQL las instrucciones IF solo existen dentro de procedimientos,
-- por eso el script transaccional se escribe como procedimiento.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_tcl_reserva_con_validacion$$
CREATE PROCEDURE sp_tcl_reserva_con_validacion(
    IN p_id_visitante INT,
    IN p_id_programacion INT,
    IN p_cantidad_personas INT
)
BEGIN
    DECLARE v_cupos INT DEFAULT 0;
    DECLARE v_precio DECIMAL(12,2);

    START TRANSACTION;

    SELECT p.cupos_disponibles, e.precio_base_cop INTO v_cupos, v_precio
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE p.id_programacion = p_id_programacion
    FOR UPDATE;

    IF p_cantidad_personas > v_cupos THEN
        ROLLBACK;
        SELECT CONCAT('ROLLBACK: se solicitaron ', p_cantidad_personas,
                      ' cupos y solo hay ', v_cupos,
                      ' disponibles. No se creó la reserva.') AS mensaje;
    ELSE
        INSERT INTO reservas
          (id_visitante, id_programacion, cantidad_personas,
           monto_total_cop, estado_reserva)
        VALUES
          (p_id_visitante, p_id_programacion, p_cantidad_personas,
           fn_calcular_total_reserva(v_precio, p_cantidad_personas),
           'CONFIRMADA');
        COMMIT;
        SELECT CONCAT('COMMIT: reserva ', LAST_INSERT_ID(),
                      ' creada correctamente.') AS mensaje;
    END IF;
END$$
DELIMITER ;

SELECT COUNT(*) INTO @reservas_antes FROM reservas;
CALL sp_tcl_reserva_con_validacion(@vis, @prog_tcl, 999);
SELECT @reservas_antes AS reservas_antes,
       (SELECT COUNT(*) FROM reservas) AS reservas_despues;

-- RETO TCL C: paquete masivo con SAVEPOINT.
-- Si el pago falla se vuelve al SAVEPOINT y la reserva queda PENDIENTE.
-- El pago inválido (método 'CHEQUE' no permitido por el CHECK) produce
-- un error; el CONTINUE HANDLER lo captura para que la transacción
-- pueda seguir, lo que en MySQL solo es posible dentro de un procedimiento.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_tcl_paquete_con_savepoint$$
CREATE PROCEDURE sp_tcl_paquete_con_savepoint(
    IN p_id_visitante INT,
    IN p_id_programacion INT,
    IN p_cantidad_personas INT
)
BEGIN
    DECLARE v_error_pago INT DEFAULT 0;
    DECLARE v_id_reserva INT;
    DECLARE v_monto DECIMAL(12,2);

    START TRANSACTION;

    -- 1. Registrar la reserva en estado PENDIENTE.
    SELECT fn_calcular_total_reserva(e.precio_base_cop, p_cantidad_personas)
      INTO v_monto
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE p.id_programacion = p_id_programacion;

    INSERT INTO reservas
      (id_visitante, id_programacion, cantidad_personas,
       monto_total_cop, estado_reserva)
    VALUES
      (p_id_visitante, p_id_programacion, p_cantidad_personas,
       v_monto, 'PENDIENTE');
    SET v_id_reserva = LAST_INSERT_ID();

    -- 2. Punto de restauración.
    SAVEPOINT sp_reserva_creada;

    -- 3. Intento de pago con un método inválido.
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_error_pago = 1;
        INSERT INTO pagos
          (id_reserva, monto_cop, metodo_pago, estado_pago,
           referencia_transaccion)
        VALUES
          (v_id_reserva, v_monto, 'CHEQUE', 'APROBADO', 'REF-TCL-C-001');
    END;

    -- 4. Si el pago falló, volver al punto de restauración.
    IF v_error_pago = 1 THEN
        ROLLBACK TO SAVEPOINT sp_reserva_creada;
    END IF;

    -- 5. Confirmar: la reserva queda guardada como PENDIENTE.
    COMMIT;

    SELECT r.id_reserva, r.estado_reserva,
           (SELECT COUNT(*) FROM pagos WHERE id_reserva = r.id_reserva)
             AS pagos_registrados,
           IF(v_error_pago = 1,
              'Pago fallido: se hizo ROLLBACK TO SAVEPOINT y se conservó la reserva',
              'Pago registrado') AS resultado
    FROM reservas r
    WHERE r.id_reserva = v_id_reserva;
END$$
DELIMITER ;

CALL sp_tcl_paquete_con_savepoint(@vis, @prog_tcl, 3);


-- =====================================================================
-- 4.8 DCL - ROLES, USUARIOS, GRANT Y REVOKE
-- Cambiar las contraseñas de ejemplo en un entorno real.
-- =====================================================================

-- RETO DCL A: rol de solo consulta para pasantes y consultores.
CREATE ROLE IF NOT EXISTS 'rol_promotor_turistico';
GRANT SELECT ON sabores_rutas_sucre.experiencias TO 'rol_promotor_turistico';
GRANT SELECT ON sabores_rutas_sucre.categorias   TO 'rol_promotor_turistico';
GRANT SELECT ON sabores_rutas_sucre.programacion TO 'rol_promotor_turistico';

CREATE USER IF NOT EXISTS 'usr_promotor1'@'localhost'
  IDENTIFIED BY 'Promotor_2026!';
GRANT 'rol_promotor_turistico' TO 'usr_promotor1'@'localhost';
CALL sp_asignar_rol_por_defecto('rol_promotor_turistico', 'usr_promotor1');

-- RETO DCL B: dos perfiles con permisos aislados.
-- Agente de reservas: gestiona clientes, reservas y pagos; no toca
-- operadores. Se le da DELETE sobre reservas para poder retirarlo en el
-- reto DCL C. SELECT es necesario para que los UPDATE con WHERE funcionen.
CREATE ROLE IF NOT EXISTS 'rol_agente_reservas';
GRANT SELECT, INSERT, UPDATE ON sabores_rutas_sucre.visitantes
  TO 'rol_agente_reservas';
GRANT SELECT, INSERT, UPDATE, DELETE ON sabores_rutas_sucre.reservas
  TO 'rol_agente_reservas';
GRANT SELECT, INSERT, UPDATE ON sabores_rutas_sucre.pagos
  TO 'rol_agente_reservas';
GRANT SELECT ON sabores_rutas_sucre.programacion TO 'rol_agente_reservas';

-- Administrador de contenidos: mantiene experiencias, programación y
-- operadores; no tiene ningún permiso sobre pagos.
CREATE ROLE IF NOT EXISTS 'rol_admin_contenido';
GRANT SELECT, INSERT, UPDATE, DELETE ON sabores_rutas_sucre.experiencias
  TO 'rol_admin_contenido';
GRANT SELECT, INSERT, UPDATE, DELETE ON sabores_rutas_sucre.programacion
  TO 'rol_admin_contenido';
GRANT SELECT, INSERT, UPDATE, DELETE ON sabores_rutas_sucre.operadores
  TO 'rol_admin_contenido';
GRANT SELECT ON sabores_rutas_sucre.categorias TO 'rol_admin_contenido';
GRANT SELECT ON sabores_rutas_sucre.municipios TO 'rol_admin_contenido';

CREATE USER IF NOT EXISTS 'usr_agente1'@'localhost'
  IDENTIFIED BY 'Agente_2026!';
CREATE USER IF NOT EXISTS 'usr_contenido1'@'localhost'
  IDENTIFIED BY 'Contenido_2026!';
GRANT 'rol_agente_reservas' TO 'usr_agente1'@'localhost';
GRANT 'rol_admin_contenido' TO 'usr_contenido1'@'localhost';
CALL sp_asignar_rol_por_defecto('rol_agente_reservas', 'usr_agente1');
CALL sp_asignar_rol_por_defecto('rol_admin_contenido', 'usr_contenido1');

SHOW GRANTS FOR 'rol_promotor_turistico';
SHOW GRANTS FOR 'rol_agente_reservas';
SHOW GRANTS FOR 'rol_admin_contenido';

-- RETO DCL C: auditoría, retirar DELETE sobre reservas al rol de ventas.
REVOKE DELETE ON sabores_rutas_sucre.reservas FROM 'rol_agente_reservas';

-- Verificación en el diccionario de datos.
-- mysql.tables_priv guarda los permisos por tabla de usuarios y roles:
SELECT User AS rol, Table_name AS tabla, Table_priv AS permisos
FROM mysql.tables_priv
WHERE Db = 'sabores_rutas_sucre'
  AND User = 'rol_agente_reservas'
ORDER BY Table_name;
-- La misma verificación con el comando de permisos del rol:
SHOW GRANTS FOR 'rol_agente_reservas';   -- reservas ya no tiene DELETE

-- ---------------------------------------------------------------------
-- DEMOSTRACIONES DE PERMISOS (ejecutar conectado como cada usuario).
-- En Workbench: crear una conexión nueva con el usuario y contraseña
-- indicados y ejecutar las líneas. Se dejan comentadas porque las
-- operaciones denegadas generan error y detendrían este archivo.
-- ---------------------------------------------------------------------
-- DCL A - conectado como usr_promotor1 / Promotor_2026!
--   USE sabores_rutas_sucre;
--   SELECT titulo, precio_base_cop FROM experiencias LIMIT 5;  -- funciona
--   DELETE FROM experiencias WHERE id_experiencia = 1;
--   -- ERROR 1142 (42000): DELETE command denied to user
--   --   'usr_promotor1'@'localhost' for table 'experiencias'
--
-- DCL B - conectado como usr_agente1 / Agente_2026!
--   USE sabores_rutas_sucre;
--   SELECT COUNT(*) FROM pagos;                                   -- funciona
--   UPDATE operadores SET telefono = '3000000000' WHERE id_operador = 1;
--   -- ERROR 1142 (42000): UPDATE command denied to user
--   --   'usr_agente1'@'localhost' for table 'operadores'
--
-- DCL B - conectado como usr_contenido1 / Contenido_2026!
--   USE sabores_rutas_sucre;
--   UPDATE experiencias SET precio_base_cop = precio_base_cop
--   WHERE id_experiencia = 1;                                     -- funciona
--   SELECT * FROM pagos;
--   -- ERROR 1142 (42000): SELECT command denied to user
--   --   'usr_contenido1'@'localhost' for table 'pagos'
--
-- DCL C - conectado como usr_agente1 / Agente_2026!
--   SELECT CURRENT_ROLE();             -- rol_agente_reservas
--   SHOW GRANTS FOR 'rol_agente_reservas';   -- ya no aparece DELETE
--   DELETE FROM sabores_rutas_sucre.reservas WHERE id_reserva = 1;
--   -- ERROR 1142 (42000): DELETE command denied to user
--   --   'usr_agente1'@'localhost' for table 'reservas'

-- FIN DE LOS RETOS

-- =====================================================================
-- VERIFICACIÓN FINAL - REGISTROS POR TABLA
-- =====================================================================

SELECT 'roles' AS tabla, COUNT(*) AS registros FROM roles
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
UNION ALL SELECT 'municipios', COUNT(*) FROM municipios
UNION ALL SELECT 'categorias', COUNT(*) FROM categorias
UNION ALL SELECT 'tipos_recurso', COUNT(*) FROM tipos_recurso
UNION ALL SELECT 'operadores', COUNT(*) FROM operadores
UNION ALL SELECT 'recursos', COUNT(*) FROM recursos
UNION ALL SELECT 'experiencias', COUNT(*) FROM experiencias
UNION ALL SELECT 'experiencia_recurso', COUNT(*) FROM experiencia_recurso
UNION ALL SELECT 'programacion', COUNT(*) FROM programacion
UNION ALL SELECT 'visitantes', COUNT(*) FROM visitantes
UNION ALL SELECT 'reservas', COUNT(*) FROM reservas
UNION ALL SELECT 'pagos', COUNT(*) FROM pagos
UNION ALL SELECT 'valoraciones', COUNT(*) FROM valoraciones
UNION ALL SELECT 'auditoria_cancelaciones', COUNT(*) FROM auditoria_cancelaciones;

-- Reservas por estado.
SELECT estado_reserva, COUNT(*) AS cantidad
FROM reservas GROUP BY estado_reserva;

-- Control de cupos: los cupos disponibles deben coincidir con
-- cupos_totales menos las personas de reservas no canceladas.
SELECT COUNT(*) AS programaciones_con_cupos_inconsistentes
FROM programacion p
WHERE p.cupos_disponibles <> p.cupos_totales - (
  SELECT COALESCE(SUM(r.cantidad_personas), 0)
  FROM reservas r
  WHERE r.id_programacion = p.id_programacion
    AND r.estado_reserva <> 'CANCELADA');

SET SQL_SAFE_UPDATES = 1;

-- FIN DEL ARCHIVO 2
