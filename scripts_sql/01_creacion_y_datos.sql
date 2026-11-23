-- =====================================================================
-- SABORES Y RUTAS DE SUCRE - ARCHIVO 1 DE 2: CREACIÓN Y DATOS
-- Motor: MySQL 8.0.16+ o MariaDB 10.4+ (XAMPP). Probado en ambos.
--
-- Contenido:
--   1. Base de datos, tablas, restricciones e índices (retos DDL A, B y C)
--   2. Funciones y triggers que la carga de datos necesita para que los
--      montos y los cupos queden calculados correctamente
--   3. Inserción de datos: catálogos, operadores, experiencias,
--      programación, visitantes, reservas, pagos y valoraciones
--
-- Ejecutar PRIMERO este archivo y después el archivo 2.
-- ATENCIÓN: borra y vuelve a crear la base sabores_rutas_sucre.
-- =====================================================================

SET NAMES utf8mb4;

-- MySQL Workbench trae activado el "Safe Updates", que bloquea los UPDATE
-- y DELETE cuyo WHERE no usa una clave. Se desactiva solo mientras corre
-- este archivo y se vuelve a activar al final.
SET SQL_SAFE_UPDATES = 0;

-- =====================================================================
-- SCRIPT 1 - CREACIÓN DE LA BASE DE DATOS Y TABLAS
-- Incluye los retos DDL A, B y C.
-- =====================================================================
DROP DATABASE IF EXISTS sabores_rutas_sucre;
CREATE DATABASE IF NOT EXISTS sabores_rutas_sucre
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sabores_rutas_sucre;

-- ---------------------------------------------------------------------
-- Seguridad
-- ---------------------------------------------------------------------
CREATE TABLE roles (
  id_rol      INT          NOT NULL AUTO_INCREMENT,
  nombre_rol  VARCHAR(40)  NOT NULL,
  descripcion VARCHAR(255) NULL,
  CONSTRAINT pk_roles PRIMARY KEY (id_rol),
  CONSTRAINT uq_roles_nombre UNIQUE (nombre_rol)
) ENGINE=InnoDB;

CREATE TABLE usuarios (
  id_usuario     INT          NOT NULL AUTO_INCREMENT,
  id_rol         INT          NOT NULL,
  nombre         VARCHAR(120) NOT NULL,
  email          VARCHAR(150) NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  activo         TINYINT(1)   NOT NULL DEFAULT 1,
  fecha_creacion DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
  CONSTRAINT uq_usuarios_email UNIQUE (email),
  CONSTRAINT fk_usuarios_roles FOREIGN KEY (id_rol) REFERENCES roles (id_rol)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;


-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
CREATE TABLE municipios (
  id_municipio INT         NOT NULL AUTO_INCREMENT,
  nombre       VARCHAR(80) NOT NULL,
  PRIMARY KEY (id_municipio),
  CONSTRAINT uq_municipios_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

CREATE TABLE categorias (
  id_categoria INT          NOT NULL AUTO_INCREMENT,
  nombre       VARCHAR(60)  NOT NULL,
  descripcion  VARCHAR(255) NULL,
  PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

CREATE TABLE tipos_recurso (
  id_tipo_recurso INT         NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(60) NOT NULL,
  PRIMARY KEY (id_tipo_recurso),
  CONSTRAINT uq_tipos_recurso_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Oferta turística
-- ---------------------------------------------------------------------
CREATE TABLE operadores (
  id_operador      INT          NOT NULL AUTO_INCREMENT,
  id_usuario       INT          NULL,
  nombre_comercial VARCHAR(120) NOT NULL,
  nit              VARCHAR(20)  NOT NULL,
  telefono         VARCHAR(20)  NOT NULL,
  email            VARCHAR(150) NOT NULL,
  activo           TINYINT(1)   NOT NULL DEFAULT 1,
  fecha_registro   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_operador),
  CONSTRAINT uq_operadores_nit UNIQUE (nit),
  CONSTRAINT fk_operadores_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE recursos (
  id_recurso      INT          NOT NULL AUTO_INCREMENT,
  id_tipo_recurso INT          NOT NULL,
  id_municipio    INT          NULL,
  nombre          VARCHAR(120) NOT NULL,
  descripcion     VARCHAR(255) NULL,
  telefono        VARCHAR(20)  NULL,
  activo          TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id_recurso),
  CONSTRAINT fk_recursos_tipos FOREIGN KEY (id_tipo_recurso) REFERENCES tipos_recurso (id_tipo_recurso)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_recursos_municipios FOREIGN KEY (id_municipio) REFERENCES municipios (id_municipio)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE experiencias (
  id_experiencia            INT           NOT NULL AUTO_INCREMENT,
  id_operador               INT           NOT NULL,
  id_categoria              INT           NOT NULL,
  id_municipio              INT           NOT NULL,
  titulo                    VARCHAR(150)  NOT NULL,
  descripcion               TEXT          NOT NULL,
  duracion_horas            DECIMAL(4,1)  NOT NULL,
  precio_base_cop           DECIMAL(12,2) NOT NULL,
  capacidad_max             INT           NOT NULL,
  condiciones_participacion TEXT          NULL,
  estado_experiencia        VARCHAR(15)   NOT NULL DEFAULT 'ACTIVA',
  fecha_publicacion         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_experiencia),
  CONSTRAINT fk_experiencias_operadores FOREIGN KEY (id_operador) REFERENCES operadores (id_operador)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_experiencias_categorias FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_experiencias_municipios FOREIGN KEY (id_municipio) REFERENCES municipios (id_municipio)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE experiencia_recurso (
  id_experiencia INT NOT NULL,
  id_recurso     INT NOT NULL,
  PRIMARY KEY (id_experiencia, id_recurso),
  CONSTRAINT fk_exprec_experiencias FOREIGN KEY (id_experiencia) REFERENCES experiencias (id_experiencia)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_exprec_recursos FOREIGN KEY (id_recurso) REFERENCES recursos (id_recurso)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- RETO DDL A: programación de salidas de cada experiencia, con control
-- de fechas y de límite de participantes.
CREATE TABLE programacion (
  id_programacion     INT         NOT NULL AUTO_INCREMENT,
  id_experiencia      INT         NOT NULL,
  fecha_actividad     DATE        NOT NULL,
  hora_inicio         TIME        NOT NULL,
  cupos_totales       INT         NOT NULL,
  cupos_disponibles   INT         NOT NULL,
  estado_programacion VARCHAR(15) NOT NULL DEFAULT 'PROGRAMADA',
  PRIMARY KEY (id_programacion),
  CONSTRAINT fk_programacion_experiencias FOREIGN KEY (id_experiencia) REFERENCES experiencias (id_experiencia)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_programacion_cupos CHECK (cupos_disponibles >= 0 AND cupos_totales > 0)
) ENGINE=InnoDB;

-- RETO DDL A (valor por defecto): MySQL no permite que el DEFAULT de una
-- columna copie el valor de otra columna. Por eso los cupos disponibles
-- se igualan a los cupos totales con un trigger BEFORE INSERT cuando no
-- se envían en el INSERT.
DELIMITER $$
CREATE TRIGGER trg_programacion_cupos_por_defecto
BEFORE INSERT ON programacion
FOR EACH ROW
BEGIN
    IF NEW.cupos_disponibles IS NULL THEN
        SET NEW.cupos_disponibles = NEW.cupos_totales;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- Demanda: visitantes, reservas, pagos y valoraciones
-- ---------------------------------------------------------------------
CREATE TABLE visitantes (
  id_visitante   INT          NOT NULL AUTO_INCREMENT,
  nombre         VARCHAR(80)  NOT NULL,
  apellido       VARCHAR(80)  NOT NULL,
  email          VARCHAR(150) NOT NULL,
  telefono       VARCHAR(20)  NULL,
  fecha_registro DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_visitante),
  CONSTRAINT uq_visitantes_email UNIQUE (email)
) ENGINE=InnoDB;

CREATE TABLE reservas (
  id_reserva         INT           NOT NULL AUTO_INCREMENT,
  id_visitante       INT           NOT NULL,
  id_programacion    INT           NOT NULL,
  cantidad_personas  INT           NOT NULL,
  monto_total_cop    DECIMAL(12,2) NOT NULL,
  fecha_reserva      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_cancelacion  DATETIME      NULL,
  PRIMARY KEY (id_reserva),
  CONSTRAINT fk_reservas_visitantes FOREIGN KEY (id_visitante) REFERENCES visitantes (id_visitante)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  -- RETO DDL C: ON DELETE RESTRICT impide borrar una programación que
  -- tenga reservas, así el historial de los visitantes nunca se pierde
  -- aunque el operador cancele la salida (se marca CANCELADA, no se borra).
  -- ON UPDATE CASCADE propaga un cambio de id a las reservas asociadas.
  CONSTRAINT fk_reservas_programacion FOREIGN KEY (id_programacion) REFERENCES programacion (id_programacion)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_reservas_personas CHECK (cantidad_personas > 0)
) ENGINE=InnoDB;

-- RETO DDL B: se incorpora el estado de la reserva mediante ALTER TABLE,
-- con valor por defecto 'PENDIENTE' y una restricción de dominio (CHECK)
-- que solo admite los cuatro estados del flujo de venta.
ALTER TABLE reservas
  ADD COLUMN estado_reserva VARCHAR(10) NOT NULL DEFAULT 'PENDIENTE'
    AFTER monto_total_cop,
  ADD CONSTRAINT ck_reservas_estado
    CHECK (estado_reserva IN ('PENDIENTE','CONFIRMADA','COMPLETADA','CANCELADA'));

-- RETO DDL C: índice compuesto B-Tree sobre (id_programacion, estado_reserva).
-- Justificación: para validar la sobreventa el sistema consulta siempre
-- "las reservas de ESTA programación que NO están canceladas". Con el
-- índice, MySQL va directo a las filas de esa programación (primera
-- columna) y dentro de ellas filtra por estado (segunda columna) sin
-- recorrer toda la tabla. B-Tree mantiene los valores ordenados, lo que
-- sirve para igualdad (=), IN y rangos. El orden de las columnas importa:
-- id_programacion es la más selectiva y la que siempre se filtra.
ALTER TABLE reservas
  ADD INDEX idx_reservas_prog_estado (id_programacion, estado_reserva) USING BTREE;

CREATE TABLE pagos (
  id_pago                INT           NOT NULL AUTO_INCREMENT,
  id_reserva             INT           NOT NULL,
  monto_cop              DECIMAL(12,2) NOT NULL,
  metodo_pago            VARCHAR(20)   NOT NULL,
  estado_pago            VARCHAR(12)   NOT NULL DEFAULT 'PENDIENTE',
  referencia_transaccion VARCHAR(64)   NULL,
  fecha_pago             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_pago),
  CONSTRAINT fk_pagos_reservas FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_pagos_monto CHECK (monto_cop > 0)
) ENGINE=InnoDB;

CREATE TABLE valoraciones (
  id_valoracion        INT        NOT NULL AUTO_INCREMENT,
  id_reserva           INT        NOT NULL,
  puntuacion_estrellas TINYINT    NOT NULL,
  comentario           TEXT       NULL,
  fecha_valoracion     DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_valoracion),
  CONSTRAINT fk_valoraciones_reservas FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_valoraciones_puntuacion CHECK (puntuacion_estrellas BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- FIN DEL SCRIPT 1

-- FIN DEL SCRIPT 1

-- =====================================================================
-- PARTE 2 - RESTRICCIONES, ÍNDICES, FUNCIONES, TRIGGERS Y DATOS BASE
-- (Etapa 06)
-- =====================================================================

USE sabores_rutas_sucre;

-- =====================================================================
-- 1. DDL - ALTER TABLE, CONSTRAINTS E ÍNDICES
-- =====================================================================

-- Restricciones adicionales para reforzar reglas del negocio.
ALTER TABLE experiencias
  ADD CONSTRAINT ck_experiencias_duracion CHECK (duracion_horas > 0),
  ADD CONSTRAINT ck_experiencias_precio CHECK (precio_base_cop >= 0),
  ADD CONSTRAINT ck_experiencias_capacidad CHECK (capacidad_max > 0),
  ADD CONSTRAINT ck_experiencias_estado
    CHECK (estado_experiencia IN ('ACTIVA','INACTIVA','BORRADOR'));

ALTER TABLE programacion
  ADD CONSTRAINT ck_programacion_estado
    CHECK (estado_programacion IN ('PROGRAMADA','CANCELADA','FINALIZADA')),
  ADD CONSTRAINT ck_programacion_cupos_limite
    CHECK (cupos_disponibles <= cupos_totales);

ALTER TABLE reservas
  ADD CONSTRAINT ck_reservas_monto CHECK (monto_total_cop >= 0);

ALTER TABLE pagos
  ADD CONSTRAINT ck_pagos_estado
    CHECK (estado_pago IN ('PENDIENTE','APROBADO','RECHAZADO','REEMBOLSADO')),
  ADD CONSTRAINT ck_pagos_metodo
    CHECK (metodo_pago IN ('EFECTIVO','TRANSFERENCIA','TARJETA','OTRO'));

-- Índices para acelerar búsquedas frecuentes y reportes.
ALTER TABLE visitantes
  ADD INDEX idx_visitantes_nombre (apellido, nombre);

ALTER TABLE experiencias
  ADD INDEX idx_experiencias_municipio_categoria
    (id_municipio, id_categoria),
  ADD INDEX idx_experiencias_estado (estado_experiencia);

ALTER TABLE programacion
  ADD INDEX idx_programacion_fecha_estado
    (fecha_actividad, estado_programacion);

ALTER TABLE reservas
  ADD INDEX idx_reservas_fecha_estado (fecha_reserva, estado_reserva);

ALTER TABLE pagos
  ADD INDEX idx_pagos_estado_fecha (estado_pago, fecha_pago);

-- Ejemplos de DROP seguros: se dejan comentados para no borrar
-- accidentalmente tablas que contienen información.
-- DROP TABLE IF EXISTS nombre_tabla_prueba;
-- DROP DATABASE IF EXISTS sabores_rutas_sucre;
-- Antes de ejecutar un DROP, verificar respaldos y dependencias.
-- DROP DATABASE elimina TODAS las tablas y datos de la base de datos.

-- =====================================================================
-- 2. DML - DATOS SINTÉTICOS
-- Se insertan catálogos y datos base. El procedimiento de carga ubicado
-- más adelante genera 200 visitantes y 200 reservas de prueba.
-- =====================================================================

INSERT IGNORE INTO roles (nombre_rol, descripcion) VALUES
('ADMINISTRADOR','Control total de la plataforma'),
('OPERADOR','Gestiona experiencias y programación'),
('VISITANTE','Consulta experiencias y realiza reservas');

INSERT IGNORE INTO municipios (nombre) VALUES
('Sincelejo'),('Sampués'),('Tolú'),('Coveñas'),('San Onofre');

INSERT IGNORE INTO categorias (nombre, descripcion) VALUES
('Gastronomía','Experiencias de cocina y sabores tradicionales'),
('Naturaleza','Recorridos y actividades en entornos naturales'),
('Cultura','Tradiciones, artesanías y patrimonio'),
('Aventura','Actividades recreativas y de aventura');

INSERT IGNORE INTO tipos_recurso (nombre) VALUES
('Restaurante'),('Alojamiento'),('Sitio natural'),('Centro cultural');

-- Usuario técnico de demostración. La contraseña es un hash ficticio
-- de ejemplo; en una aplicación real debe generarse con un algoritmo
-- seguro desde el backend, nunca guardarse como texto plano.
INSERT INTO usuarios
(id_rol, nombre, email, password_hash, activo)
SELECT r.id_rol, 'Administrador de prueba',
       'admin.demo@saboresrutas.test', '$2y$12$HASH_DEMO_REEMPLAZAR', 1
FROM roles r
WHERE r.nombre_rol = 'ADMINISTRADOR'
  AND NOT EXISTS (
    SELECT 1 FROM usuarios u
    WHERE u.email = 'admin.demo@saboresrutas.test'
  );

INSERT INTO operadores
(id_usuario, nombre_comercial, nit, telefono, email, activo)
SELECT u.id_usuario, 'Operador Sabores de Sucre',
       '900123456-1', '3001234567',
       'operador@saboresrutas.test', 1
FROM usuarios u
WHERE u.email = 'admin.demo@saboresrutas.test'
  AND NOT EXISTS (
    SELECT 1 FROM operadores o WHERE o.nit = '900123456-1'
  );

INSERT INTO recursos
(id_tipo_recurso, id_municipio, nombre, descripcion, telefono, activo)
SELECT tr.id_tipo_recurso, m.id_municipio,
       'Restaurante Tradición Sucreña',
       'Lugar de muestra para experiencias gastronómicas',
       '3001112233', 1
FROM tipos_recurso tr
JOIN municipios m ON m.nombre = 'Sincelejo'
WHERE tr.nombre = 'Restaurante'
  AND NOT EXISTS (
    SELECT 1 FROM recursos r
    WHERE r.nombre = 'Restaurante Tradición Sucreña'
  );

INSERT INTO experiencias
(id_operador, id_categoria, id_municipio, titulo, descripcion,
 duracion_horas, precio_base_cop, capacidad_max,
 condiciones_participacion, estado_experiencia)
SELECT o.id_operador, c.id_categoria, m.id_municipio,
       'Ruta de sabores tradicionales',
       'Recorrido por fondas de Sincelejo para probar mote de queso, bollo limpio, carimañola y jugo de corozo, con relatos de la cocina sabanera.',
       3.0, 50000.00, 30,
       'Llegar 15 minutos antes de la actividad.',
       'ACTIVA'
FROM operadores o
JOIN categorias c ON c.nombre = 'Gastronomía'
JOIN municipios m ON m.nombre = 'Sincelejo'
WHERE o.nit = '900123456-1'
  AND NOT EXISTS (
    SELECT 1 FROM experiencias e
    WHERE e.titulo = 'Ruta de sabores tradicionales'
  );

INSERT INTO experiencia_recurso (id_experiencia, id_recurso)
SELECT e.id_experiencia, r.id_recurso
FROM experiencias e
JOIN recursos r
  ON r.nombre = 'Restaurante Tradición Sucreña'
WHERE e.titulo = 'Ruta de sabores tradicionales'
  AND NOT EXISTS (
    SELECT 1 FROM experiencia_recurso er
    WHERE er.id_experiencia = e.id_experiencia
      AND er.id_recurso = r.id_recurso
  );

-- Diez fechas de programación, cada una con 30 cupos.
INSERT INTO programacion
(id_experiencia, fecha_actividad, hora_inicio,
 cupos_totales, cupos_disponibles, estado_programacion)
SELECT e.id_experiencia,
       DATE_ADD(CURDATE(), INTERVAL n.dia DAY),
       '09:00:00', 30, 30, 'PROGRAMADA'
FROM experiencias e
JOIN (
  SELECT 1 AS dia UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL
  SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL
  SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
) n
WHERE e.titulo = 'Ruta de sabores tradicionales'
  AND NOT EXISTS (
    SELECT 1 FROM programacion p
    WHERE p.id_experiencia = e.id_experiencia
      AND p.fecha_actividad = DATE_ADD(CURDATE(), INTERVAL n.dia DAY)
      AND p.hora_inicio = '09:00:00'
  );

-- =====================================================================
-- 3. FUNCIONES DEFINIDAS POR EL USUARIO
-- =====================================================================

DELIMITER $$

DROP FUNCTION IF EXISTS fn_calcular_total_reserva$$
CREATE FUNCTION fn_calcular_total_reserva(
    p_precio DECIMAL(12,2),
    p_personas INT
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN IFNULL(p_precio, 0) * IFNULL(p_personas, 0);
END$$

DROP FUNCTION IF EXISTS fn_calcular_impuesto$$
CREATE FUNCTION fn_calcular_impuesto(
    p_valor DECIMAL(12,2),
    p_porcentaje DECIMAL(5,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(IFNULL(p_valor, 0) * IFNULL(p_porcentaje, 0) / 100, 2);
END$$

DELIMITER ;

-- Prueba de las funciones:
SELECT fn_calcular_total_reserva(50000, 3) AS total_tres_personas;
SELECT fn_calcular_impuesto(150000, 19) AS impuesto_19_por_ciento;

-- =====================================================================
-- 4. TRIGGERS - REGLAS AUTOMÁTICAS DEL NEGOCIO
-- =====================================================================

DELIMITER $$

DROP TRIGGER IF EXISTS trg_reservas_validar_cupos$$
CREATE TRIGGER trg_reservas_validar_cupos
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_disponibles INT;
    DECLARE v_estado VARCHAR(15);

    IF NEW.estado_reserva <> 'CANCELADA' THEN
        SELECT cupos_disponibles, estado_programacion
          INTO v_disponibles, v_estado
        FROM programacion
        WHERE id_programacion = NEW.id_programacion
        FOR UPDATE;

        IF v_estado <> 'PROGRAMADA' THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'La programación no está disponible';
        END IF;

        IF v_disponibles < NEW.cantidad_personas THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'No hay suficientes cupos disponibles';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_reservas_descontar_cupos$$
CREATE TRIGGER trg_reservas_descontar_cupos
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estado_reserva <> 'CANCELADA' THEN
        UPDATE programacion
        SET cupos_disponibles = cupos_disponibles - NEW.cantidad_personas
        WHERE id_programacion = NEW.id_programacion;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_reservas_devolver_cupos$$
CREATE TRIGGER trg_reservas_devolver_cupos
AFTER UPDATE ON reservas
FOR EACH ROW
BEGIN
    -- Reserva activa que pasa a cancelada: devuelve los cupos.
    IF OLD.estado_reserva <> 'CANCELADA'
       AND NEW.estado_reserva = 'CANCELADA' THEN
        UPDATE programacion
        SET cupos_disponibles =
            LEAST(cupos_totales, cupos_disponibles + OLD.cantidad_personas)
        WHERE id_programacion = OLD.id_programacion;
    END IF;

    -- Reserva cancelada que vuelve a estar activa: valida y descuenta.
    IF OLD.estado_reserva = 'CANCELADA'
       AND NEW.estado_reserva <> 'CANCELADA' THEN
        UPDATE programacion
        SET cupos_disponibles = cupos_disponibles - NEW.cantidad_personas
        WHERE id_programacion = NEW.id_programacion
          AND estado_programacion = 'PROGRAMADA'
          AND cupos_disponibles >= NEW.cantidad_personas;

        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'No hay cupos para reactivar la reserva';
        END IF;
    END IF;
END$$

DELIMITER ;

-- REGLA DE NEGOCIO 7 ("Impedir valoraciones inválidas"): una valoración
-- solo se acepta si la reserva está COMPLETADA (la experiencia ya se
-- realizó) y cada reserva admite una sola valoración.
ALTER TABLE valoraciones
  ADD CONSTRAINT uq_valoraciones_reserva UNIQUE (id_reserva);

DELIMITER $$
DROP TRIGGER IF EXISTS trg_validar_valoracion$$
CREATE TRIGGER trg_validar_valoracion
BEFORE INSERT ON valoraciones
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(10);

    SELECT estado_reserva INTO v_estado
    FROM reservas
    WHERE id_reserva = NEW.id_reserva;

    IF v_estado IS NULL OR v_estado <> 'COMPLETADA' THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Solo se puede valorar una experiencia ya realizada (reserva COMPLETADA)';
    END IF;
END$$
DELIMITER ;

-- Prueba (comentada porque el error detiene el archivo): valorar una
-- reserva CONFIRMADA que aún no se ha realizado.
-- INSERT INTO valoraciones (id_reserva, puntuacion_estrellas)
-- SELECT MIN(id_reserva), 5 FROM reservas WHERE estado_reserva = 'CONFIRMADA';
--   Resultado esperado: ERROR 1644 (45000): Solo se puede valorar una
--   experiencia ya realizada (reserva COMPLETADA)


-- =====================================================================
-- CARGA DE 200 VISITANTES Y 200 RESERVAS DE DEMOSTRACIÓN
-- =====================================================================

DELIMITER $$

-- Carga de 200 visitantes y 200 reservas sintéticas.
-- Se incluye como procedimiento auxiliar para demostrar volumen de datos.
DROP PROCEDURE IF EXISTS sp_cargar_dataset_demo$$
CREATE PROCEDURE sp_cargar_dataset_demo()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE v_id_programacion INT;
    DECLARE v_id_visitante INT;
    DECLARE v_programaciones INT DEFAULT 0;
    DECLARE v_offset INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_programaciones
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE e.titulo = 'Ruta de sabores tradicionales'
      AND p.estado_programacion = 'PROGRAMADA';

    IF v_programaciones < 10 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Se requieren diez programaciones de demostración';
    END IF;

    START TRANSACTION;

    WHILE i <= 200 DO
        INSERT IGNORE INTO visitantes
          (nombre, apellido, email, telefono)
        VALUES
          (CONCAT('Visitante', i),
           CONCAT('Prueba', i),
           CONCAT('visitante', i, '@demo.sabores.test'),
           CONCAT('300', LPAD(i, 7, '0')));

        SET i = i + 1;
    END WHILE;

    COMMIT;

    -- Crear 200 reservas: 20 reservas por cada una de 10 programaciones.
    SET i = 1;
    START TRANSACTION;

    WHILE i <= 200 DO
        SELECT id_visitante INTO v_id_visitante
        FROM visitantes
        WHERE email = CONCAT('visitante', i, '@demo.sabores.test');

        SET v_offset = FLOOR((i - 1) / 20);

        SELECT p.id_programacion INTO v_id_programacion
        FROM programacion p
        JOIN experiencias e ON e.id_experiencia = p.id_experiencia
        WHERE e.titulo = 'Ruta de sabores tradicionales'
          AND p.estado_programacion = 'PROGRAMADA'
        ORDER BY p.fecha_actividad, p.id_programacion
        LIMIT 1 OFFSET v_offset;

        IF NOT EXISTS (
            SELECT 1 FROM reservas
            WHERE id_visitante = v_id_visitante
              AND id_programacion = v_id_programacion
        ) THEN
            INSERT INTO reservas
              (id_visitante, id_programacion, cantidad_personas,
               monto_total_cop, estado_reserva)
            VALUES
              (v_id_visitante, v_id_programacion, 1,
               50000.00, 'CONFIRMADA');
        END IF;

        SET i = i + 1;
    END WHILE;

    COMMIT;

    SELECT
      (SELECT COUNT(*) FROM visitantes
       WHERE email LIKE '%@demo.sabores.test') AS visitantes_demo,
      (SELECT COUNT(*) FROM reservas r
       JOIN visitantes v ON v.id_visitante = r.id_visitante
       WHERE v.email LIKE '%@demo.sabores.test') AS reservas_demo;
END$$

DELIMITER ;

-- Ejecutar una sola vez para generar los datos de demostración.
CALL sp_cargar_dataset_demo();


-- Se reserva el id de visitante que en la versión de un solo archivo
-- usa la demostración de DELETE (archivo 2). Así los identificadores, y
-- por tanto los resultados, coinciden con el informe y con los datos
-- migrados a PostgreSQL y MongoDB.
ALTER TABLE visitantes AUTO_INCREMENT = 202;

-- =====================================================================
-- SCRIPT 3 - CARGA DE DATOS ADICIONALES
-- Completa los catálogos y tablas que quedaban con muy pocos registros.
-- Se ejecuta DESPUÉS del Script 2 para que los triggers descuenten y
-- devuelvan los cupos automáticamente.
-- Tabla principal: reservas (mínimo 100 registros; aquí quedan más de 300).
-- =====================================================================

USE sabores_rutas_sucre;

-- 3.1 Catálogos adicionales
INSERT IGNORE INTO municipios (nombre) VALUES
('Corozal'),
('Morroa'),
('Colosó'),
('Los Palmitos'),
('San Marcos'),
('Sincé'),
('Ovejas'),
('Majagual'),
('Galeras');

INSERT IGNORE INTO categorias (nombre, descripcion) VALUES
('Artesanía','Talleres con artesanos y oficios tradicionales'),
('Ecoturismo','Avistamiento de fauna y recorridos sostenibles');

INSERT IGNORE INTO tipos_recurso (nombre) VALUES
('Transporte'),('Taller artesanal'),('Guía local');

-- 3.2 Usuarios con rol OPERADOR y sus operadores turísticos
-- La contraseña es un hash ficticio de ejemplo, igual que en el Script 2.
INSERT INTO usuarios (id_rol, nombre, email, password_hash, activo)
SELECT r.id_rol, t.nombre, t.email, '$2y$12$HASH_DEMO_REEMPLAZAR', 1
FROM roles r
JOIN (
  SELECT 'Sabores del Golfo' AS nombre, 'operador01@saboresrutas.test' AS email
  UNION ALL SELECT 'Ruta Zenú Tours' AS nombre, 'operador02@saboresrutas.test' AS email
  UNION ALL SELECT 'Coveñas Mar y Sol' AS nombre, 'operador03@saboresrutas.test' AS email
  UNION ALL SELECT 'Montes de María Aventura' AS nombre, 'operador04@saboresrutas.test' AS email
  UNION ALL SELECT 'Cocina de la Abuela Sabanera' AS nombre, 'operador05@saboresrutas.test' AS email
  UNION ALL SELECT 'Ecorutas La Mojana' AS nombre, 'operador06@saboresrutas.test' AS email
  UNION ALL SELECT 'Corozal Cultural' AS nombre, 'operador07@saboresrutas.test' AS email
  UNION ALL SELECT 'Manglares de San Onofre' AS nombre, 'operador08@saboresrutas.test' AS email
  UNION ALL SELECT 'Artesanías Morroa' AS nombre, 'operador09@saboresrutas.test' AS email
  UNION ALL SELECT 'Sabana Viva Experiencias' AS nombre, 'operador10@saboresrutas.test' AS email
) t
WHERE r.nombre_rol = 'OPERADOR'
  AND NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.email = t.email);

INSERT INTO usuarios (id_rol, nombre, email, password_hash, activo)
SELECT r.id_rol, 'Coordinador de plataforma', 'coordinador@saboresrutas.test',
       '$2y$12$HASH_DEMO_REEMPLAZAR', 1
FROM roles r
WHERE r.nombre_rol = 'ADMINISTRADOR'
  AND NOT EXISTS (SELECT 1 FROM usuarios u
                  WHERE u.email = 'coordinador@saboresrutas.test');

INSERT INTO operadores (id_usuario, nombre_comercial, nit, telefono, email, activo)
SELECT u.id_usuario, u.nombre, t.nit, t.telefono, u.email, 1
FROM usuarios u
JOIN (
  SELECT 'operador01@saboresrutas.test' AS email, '900200101-3' AS nit, '3017994000' AS telefono
  UNION ALL SELECT 'operador02@saboresrutas.test' AS email, '900200102-1' AS nit, '3031440241' AS telefono
  UNION ALL SELECT 'operador03@saboresrutas.test' AS email, '900200103-8' AS nit, '3043723261' AS telefono
  UNION ALL SELECT 'operador04@saboresrutas.test' AS email, '900200104-6' AS nit, '3044347840' AS telefono
  UNION ALL SELECT 'operador05@saboresrutas.test' AS email, '900200105-4' AS nit, '3053432734' AS telefono
  UNION ALL SELECT 'operador06@saboresrutas.test' AS email, '900200106-2' AS nit, '3016887842' AS telefono
  UNION ALL SELECT 'operador07@saboresrutas.test' AS email, '900200107-0' AS nit, '3024984372' AS telefono
  UNION ALL SELECT 'operador08@saboresrutas.test' AS email, '900200108-9' AS nit, '3050334484' AS telefono
  UNION ALL SELECT 'operador09@saboresrutas.test' AS email, '900200109-7' AS nit, '3051707092' AS telefono
  UNION ALL SELECT 'operador10@saboresrutas.test' AS email, '900200110-5' AS nit, '3047350043' AS telefono
) t ON t.email = u.email
WHERE NOT EXISTS (SELECT 1 FROM operadores o WHERE o.nit = t.nit);

-- 3.3 Recursos turísticos (restaurantes, alojamientos, sitios, etc.)
INSERT INTO recursos (id_tipo_recurso, id_municipio, nombre, descripcion, telefono, activo)
SELECT tr.id_tipo_recurso, m.id_municipio, t.nombre, t.descripcion, t.telefono, 1
FROM (
  SELECT 'Restaurante' AS tipo, 'Sincelejo' AS municipio, 'Fonda El Corralito' AS nombre, 'Cocina típica sabanera' AS descripcion, '3038226991' AS telefono
  UNION ALL SELECT 'Restaurante' AS tipo, 'Tolú' AS municipio, 'Kiosco La Bahía' AS nombre, 'Pescados y mariscos frescos' AS descripcion, '3048424442' AS telefono
  UNION ALL SELECT 'Restaurante' AS tipo, 'Coveñas' AS municipio, 'Restaurante Punta Bolívar' AS nombre, 'Comida de mar frente a la playa' AS descripcion, '3046763004' AS telefono
  UNION ALL SELECT 'Restaurante' AS tipo, 'Sampués' AS municipio, 'Comedor Zenú' AS nombre, 'Platos a base de maíz y yuca' AS descripcion, '3059025641' AS telefono
  UNION ALL SELECT 'Restaurante' AS tipo, 'Corozal' AS municipio, 'Asadero La Sabana' AS nombre, 'Carnes y bollos tradicionales' AS descripcion, '3042944036' AS telefono
  UNION ALL SELECT 'Alojamiento' AS tipo, 'Tolú' AS municipio, 'Hostal Brisas del Golfo' AS nombre, 'Hospedaje familiar cerca al malecón' AS descripcion, '3049360747' AS telefono
  UNION ALL SELECT 'Alojamiento' AS tipo, 'Coveñas' AS municipio, 'Cabañas Primera Ensenada' AS nombre, 'Cabañas frente al mar' AS descripcion, '3039601384' AS telefono
  UNION ALL SELECT 'Alojamiento' AS tipo, 'San Onofre' AS municipio, 'Ecohotel Rincón del Mar' AS nombre, 'Alojamiento ecológico' AS descripcion, '3026101703' AS telefono
  UNION ALL SELECT 'Alojamiento' AS tipo, 'Sincelejo' AS municipio, 'Hotel Majagual Plaza' AS nombre, 'Hotel urbano en el centro' AS descripcion, '3010170110' AS telefono
  UNION ALL SELECT 'Sitio natural' AS tipo, 'Tolú' AS municipio, 'Manglares de la Ciénaga de la Caimanera' AS nombre, 'Recorrido en canoa por el manglar' AS descripcion, '3051218551' AS telefono
  UNION ALL SELECT 'Sitio natural' AS tipo, 'San Onofre' AS municipio, 'Playa Rincón del Mar' AS nombre, 'Playa de arena blanca' AS descripcion, '3015417273' AS telefono
  UNION ALL SELECT 'Sitio natural' AS tipo, 'Coveñas' AS municipio, 'Playa La Martina' AS nombre, 'Playa para deportes náuticos' AS descripcion, '3017431403' AS telefono
  UNION ALL SELECT 'Sitio natural' AS tipo, 'Ovejas' AS municipio, 'Reserva Montes de María' AS nombre, 'Bosque seco tropical' AS descripcion, '3029276364' AS telefono
  UNION ALL SELECT 'Sitio natural' AS tipo, 'Majagual' AS municipio, 'Humedales de La Mojana' AS nombre, 'Avistamiento de aves' AS descripcion, '3016580132' AS telefono
  UNION ALL SELECT 'Centro cultural' AS tipo, 'Sincelejo' AS municipio, 'Casa de la Cultura de Sincelejo' AS nombre, 'Muestras de música y danza' AS descripcion, '3040175825' AS telefono
  UNION ALL SELECT 'Centro cultural' AS tipo, 'Corozal' AS municipio, 'Museo del Fandango' AS nombre, 'Historia del fandango sabanero' AS descripcion, '3010771002' AS telefono
  UNION ALL SELECT 'Centro cultural' AS tipo, 'Sampués' AS municipio, 'Centro Artesanal del Sombrero Vueltiao' AS nombre, 'Exhibición de caña flecha' AS descripcion, '3055981521' AS telefono
  UNION ALL SELECT 'Taller artesanal' AS tipo, 'Morroa' AS municipio, 'Taller de Hamacas Morroa' AS nombre, 'Tejido tradicional de hamacas' AS descripcion, '3042902585' AS telefono
  UNION ALL SELECT 'Taller artesanal' AS tipo, 'Sampués' AS municipio, 'Taller Caña Flecha Zenú' AS nombre, 'Trenzado del sombrero vueltiao' AS descripcion, '3055593020' AS telefono
  UNION ALL SELECT 'Transporte' AS tipo, 'Tolú' AS municipio, 'Lanchas Golfo de Morrosquillo' AS nombre, 'Transporte marítimo a las islas' AS descripcion, '3031087828' AS telefono
  UNION ALL SELECT 'Transporte' AS tipo, 'Sincelejo' AS municipio, 'Transportes Sabana Express' AS nombre, 'Traslados terrestres' AS descripcion, '3024107938' AS telefono
  UNION ALL SELECT 'Guía local' AS tipo, 'Los Palmitos' AS municipio, 'Guías Sabana Viva' AS nombre, 'Guianza en recorridos rurales' AS descripcion, '3036656808' AS telefono
) t
JOIN tipos_recurso tr ON tr.nombre = t.tipo
JOIN municipios m ON m.nombre = t.municipio
WHERE NOT EXISTS (SELECT 1 FROM recursos r WHERE r.nombre = t.nombre);

-- 3.4 Experiencias turísticas
INSERT INTO experiencias (id_operador, id_categoria, id_municipio, titulo, descripcion,
  duracion_horas, precio_base_cop, capacidad_max, condiciones_participacion, estado_experiencia)
SELECT o.id_operador, c.id_categoria, m.id_municipio, t.titulo, t.descripcion,
       t.horas, t.precio, t.capacidad, t.condiciones, t.estado
FROM (
  SELECT 'Taller de cocina sabanera' AS titulo, '900200105-4' AS nit, 'Gastronomía' AS categoria, 'Sincelejo' AS municipio, 'Taller práctico en el que se cocinan platos típicos de la sabana sucreña con una cocinera tradicional y se comparte la mesa al final.' AS descripcion, 3.0 AS horas, 70000 AS precio, 15 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, '900200105-4' AS nit, 'Gastronomía' AS categoria, 'Sincelejo' AS municipio, 'Ruta gastronómica dedicada al mote de queso: mercado, preparación con ñame y queso costeño, y degustación en una casa sincelejana.' AS descripcion, 2.5 AS horas, 55000 AS precio, 12 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, '900200101-3' AS nit, 'Gastronomía' AS categoria, 'Tolú' AS municipio, 'Pasadía en Tolú para comprar pescado fresco a los pescadores del golfo y almorzarlo frente al mar con patacón y arroz con coco.' AS descripcion, 4.0 AS horas, 85000 AS precio, 20 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, '900200103-8' AS nit, 'Gastronomía' AS categoria, 'Coveñas' AS municipio, 'Almuerzo de mariscos en la playa de Coveñas: cazuela, ceviche de camarón y pescado del día, con vista al Golfo de Morrosquillo.' AS descripcion, 3.0 AS horas, 95000 AS precio, 16 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, '900200102-1' AS nit, 'Gastronomía' AS categoria, 'Sampués' AS municipio, 'Cocina del pueblo Zenú en Sampués: preparaciones con maíz, yuca y ñame, contadas por una familia de artesanos.' AS descripcion, 3.0 AS horas, 60000 AS precio, 15 AS capacidad, 'Llegar 15 minutos antes.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, '900200107-0' AS nit, 'Gastronomía' AS categoria, 'Corozal' AS municipio, 'Asado sabanero en una finca de Corozal con carne de res a la brasa, bollo y ensalada, acompañado de música de acordeón.' AS descripcion, 3.5 AS horas, 75000 AS precio, 20 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, '900200103-8' AS nit, 'Naturaleza' AS categoria, 'Coveñas' AS municipio, 'Pasadía ecológico en la Ciénaga de la Caimanera: recorrido en canoa por el manglar, descanso en la playa y almuerzo de pescado fresco.' AS descripcion, 6.0 AS horas, 95000 AS precio, 20 AS capacidad, 'Llegar 15 minutos antes.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, '900200108-9' AS nit, 'Naturaleza' AS categoria, 'San Onofre' AS municipio, 'Tarde tranquila en Rincón del Mar, San Onofre: caminata por la playa, baño en el mar y atardecer con coctel de frutas.' AS descripcion, 4.0 AS horas, 80000 AS precio, 20 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, '900200104-6' AS nit, 'Naturaleza' AS categoria, 'Colosó' AS municipio, 'Caminata guiada por el bosque seco tropical de los Montes de María en Colosó, con miradores, quebradas y avistamiento de monos aulladores.' AS descripcion, 5.0 AS horas, 90000 AS precio, 15 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, '900200106-2' AS nit, 'Ecoturismo' AS categoria, 'Majagual' AS municipio, 'Avistamiento de aves en los humedales de La Mojana al amanecer, en canoa y con guía local experto en especies acuáticas.' AS descripcion, 6.0 AS horas, 110000 AS precio, 10 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, '900200106-2' AS nit, 'Ecoturismo' AS categoria, 'Majagual' AS municipio, 'Jornada con pescadores de la ciénaga en Majagual: técnicas de atarraya, recorrido en chalupa y fritura del pescado capturado.' AS descripcion, 4.0 AS horas, 70000 AS precio, 8 AS capacidad, 'Usar ropa cómoda y protector solar.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, '900200108-9' AS nit, 'Gastronomía' AS categoria, 'San Onofre' AS municipio, 'Cata de mariscos en San Onofre con menú de tres tiempos y maridaje con bebidas tradicionales del Caribe.' AS descripcion, 3.0 AS horas, 130000 AS precio, 12 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Manglar y conservación' AS titulo, '900200108-9' AS nit, 'Ecoturismo' AS categoria, 'San Onofre' AS municipio, 'Experiencia de conservación en San Onofre: siembra de mangle, charla sobre el ecosistema y recorrido en kayak.' AS descripcion, 3.0 AS horas, 60000 AS precio, 12 AS capacidad, 'Llegar 15 minutos antes.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, '900200107-0' AS nit, 'Cultura' AS categoria, 'Corozal' AS municipio, 'Noche de fandango en Corozal: rueda de baile alrededor de la banda de viento, con velas encendidas como en las fiestas patronales.' AS descripcion, 3.0 AS horas, 45000 AS precio, 30 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, '900200105-4' AS nit, 'Cultura' AS categoria, 'Sincelejo' AS municipio, 'Recorrido a pie por el centro histórico de Sincelejo: catedral, plaza Majagual y la historia de las corralejas.' AS descripcion, 2.0 AS horas, 35000 AS precio, 25 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, '900200102-1' AS nit, 'Cultura' AS categoria, 'Sampués' AS municipio, 'Visita al centro artesanal de Sampués para conocer cómo se fabrica el sombrero vueltiao, desde la caña flecha hasta el trenzado final.' AS descripcion, 2.5 AS horas, 50000 AS precio, 15 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, '900200104-6' AS nit, 'Cultura' AS categoria, 'Ovejas' AS municipio, 'Encuentro con músicos de gaita y tambor en Ovejas, cuna del Festival Nacional de Gaitas, con taller corto de percusión.' AS descripcion, 2.5 AS horas, 40000 AS precio, 30 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, '900200109-7' AS nit, 'Cultura' AS categoria, 'Morroa' AS municipio, 'Ruta por Morroa entre la música de gaita y los telares donde se tejen las hamacas que hicieron famoso al pueblo.' AS descripcion, 4.0 AS horas, 85000 AS precio, 10 AS capacidad, 'Llegar 15 minutos antes.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, '900200102-1' AS nit, 'Artesanía' AS categoria, 'Sampués' AS municipio, 'Taller de trenzado de caña flecha con artesanos zenúes: cada participante elabora una pulsera o llavero con trenza de 15 pares.' AS descripcion, 3.0 AS horas, 65000 AS precio, 10 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, '900200109-7' AS nit, 'Artesanía' AS categoria, 'Morroa' AS municipio, 'Taller de mochilas y tejidos sabaneros en Morroa con técnicas de crochet y telar vertical.' AS descripcion, 3.0 AS horas, 60000 AS precio, 12 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, '900200103-8' AS nit, 'Aventura' AS categoria, 'Coveñas' AS municipio, 'Recorrido en kayak por la costa del Golfo de Morrosquillo en Coveñas, con parada para nadar en aguas tranquilas.' AS descripcion, 2.0 AS horas, 75000 AS precio, 12 AS capacidad, 'Llegar 15 minutos antes.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, '900200101-3' AS nit, 'Aventura' AS categoria, 'Tolú' AS municipio, 'Paseo en lancha desde Tolú hasta Isla Múcura en el archipiélago de San Bernardo, con tiempo de playa y almuerzo.' AS descripcion, 8.0 AS horas, 150000 AS precio, 25 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, '900200110-5' AS nit, 'Aventura' AS categoria, 'Los Palmitos' AS municipio, 'Cabalgata por potreros y caminos reales de Los Palmitos, al ritmo de la vida ganadera de la sabana.' AS descripcion, 3.0 AS horas, 80000 AS precio, 10 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'ACTIVA' AS estado
  UNION ALL SELECT 'Snorkel en Coveñas' AS titulo, '900200103-8' AS nit, 'Aventura' AS categoria, 'Coveñas' AS municipio, 'Snorkel en los arrecifes cercanos a Coveñas para observar peces de colores y estrellas de mar (temporalmente inactiva).' AS descripcion, 3.0 AS horas, 120000 AS precio, 10 AS capacidad, 'Llevar hidratación y gorra.' AS condiciones, 'INACTIVA' AS estado
  UNION ALL SELECT 'Festival gastronómico de Sincé' AS titulo, '900200107-0' AS nit, 'Gastronomía' AS categoria, 'Sincé' AS municipio, 'Festival gastronómico de Sincé con muestras de cocina sabanera, concurso de bollos y música en vivo (en preparación).' AS descripcion, 5.0 AS horas, 50000 AS precio, 40 AS capacidad, 'Menores de edad con acompañante.' AS condiciones, 'BORRADOR' AS estado
) t
JOIN operadores o ON o.nit = t.nit
JOIN categorias c ON c.nombre = t.categoria
JOIN municipios m ON m.nombre = t.municipio
WHERE NOT EXISTS (SELECT 1 FROM experiencias e WHERE e.titulo = t.titulo);

-- 3.5 Relación experiencia - recurso
INSERT INTO experiencia_recurso (id_experiencia, id_recurso)
SELECT e.id_experiencia, r.id_recurso
FROM (
  SELECT 'Taller de cocina sabanera' AS titulo, 'Fonda El Corralito' AS recurso
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, 'Fonda El Corralito' AS recurso
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, 'Casa de la Cultura de Sincelejo' AS recurso
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, 'Kiosco La Bahía' AS recurso
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, 'Restaurante Punta Bolívar' AS recurso
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, 'Comedor Zenú' AS recurso
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, 'Asadero La Sabana' AS recurso
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, 'Manglares de la Ciénaga de la Caimanera' AS recurso
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, 'Lanchas Golfo de Morrosquillo' AS recurso
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, 'Playa Rincón del Mar' AS recurso
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, 'Ecohotel Rincón del Mar' AS recurso
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, 'Reserva Montes de María' AS recurso
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, 'Guías Sabana Viva' AS recurso
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, 'Humedales de La Mojana' AS recurso
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, 'Humedales de La Mojana' AS recurso
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, 'Ecohotel Rincón del Mar' AS recurso
  UNION ALL SELECT 'Manglar y conservación' AS titulo, 'Ecohotel Rincón del Mar' AS recurso
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, 'Museo del Fandango' AS recurso
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, 'Casa de la Cultura de Sincelejo' AS recurso
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, 'Centro Artesanal del Sombrero Vueltiao' AS recurso
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, 'Guías Sabana Viva' AS recurso
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, 'Taller de Hamacas Morroa' AS recurso
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, 'Taller Caña Flecha Zenú' AS recurso
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, 'Taller de Hamacas Morroa' AS recurso
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, 'Playa La Martina' AS recurso
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, 'Lanchas Golfo de Morrosquillo' AS recurso
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, 'Hostal Brisas del Golfo' AS recurso
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, 'Guías Sabana Viva' AS recurso
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, 'Transportes Sabana Express' AS recurso
  UNION ALL SELECT 'Snorkel en Coveñas' AS titulo, 'Playa La Martina' AS recurso
  UNION ALL SELECT 'Snorkel en Coveñas' AS titulo, 'Cabañas Primera Ensenada' AS recurso
  UNION ALL SELECT 'Festival gastronómico de Sincé' AS titulo, 'Transportes Sabana Express' AS recurso
) t
JOIN experiencias e ON e.titulo = t.titulo
JOIN recursos r ON r.nombre = t.recurso
WHERE NOT EXISTS (SELECT 1 FROM experiencia_recurso er
                  WHERE er.id_experiencia = e.id_experiencia AND er.id_recurso = r.id_recurso);

-- 3.6 Programación: fechas pasadas (se finalizan más abajo) y futuras.
-- Las fechas son relativas a la fecha de ejecución (CURDATE()).
INSERT INTO programacion (id_experiencia, fecha_actividad, hora_inicio,
  cupos_totales, cupos_disponibles, estado_programacion)
SELECT e.id_experiencia, DATE_ADD(CURDATE(), INTERVAL t.dias DAY), t.hora,
       t.cupos, t.cupos, 'PROGRAMADA'
FROM (
  SELECT 'Taller de cocina sabanera' AS titulo, -34 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Taller de cocina sabanera' AS titulo, -6 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Taller de cocina sabanera' AS titulo, 35 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Taller de cocina sabanera' AS titulo, 37 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Taller de cocina sabanera' AS titulo, 41 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, -46 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, -24 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, 8 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, 13 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Ruta Gastronómica del Mote de Queso en Sincelejo' AS titulo, 38 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, -21 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, -15 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, 14 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, 32 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Ruta del pescado en Tolú' AS titulo, 35 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, -46 AS dias, '14:00:00' AS hora, 16 AS cupos
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, -4 AS dias, '14:00:00' AS hora, 16 AS cupos
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, 12 AS dias, '14:00:00' AS hora, 16 AS cupos
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, 34 AS dias, '14:00:00' AS hora, 16 AS cupos
  UNION ALL SELECT 'Mariscos frente al mar' AS titulo, 35 AS dias, '14:00:00' AS hora, 16 AS cupos
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, -35 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, -25 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, 24 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, 37 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Sabores Zenú de Sampués' AS titulo, 40 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, -9 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, -4 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, 17 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, 30 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Asado sabanero en Corozal' AS titulo, 32 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, -43 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, -7 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, 5 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, 7 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Pasadía en la Ciénaga de la Caimanera en Coveñas' AS titulo, 14 AS dias, '16:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, -27 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, -9 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, 17 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, 28 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Atardecer en Rincón del Mar' AS titulo, 36 AS dias, '14:00:00' AS hora, 20 AS cupos
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, -29 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, -16 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, 34 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, 36 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Senderismo en los Montes de María - Colosó' AS titulo, 37 AS dias, '16:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, -25 AS dias, '16:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, -18 AS dias, '16:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, 7 AS dias, '16:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, 23 AS dias, '16:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Aves de La Mojana' AS titulo, 25 AS dias, '16:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, -54 AS dias, '16:00:00' AS hora, 8 AS cupos
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, -9 AS dias, '16:00:00' AS hora, 8 AS cupos
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, 21 AS dias, '16:00:00' AS hora, 8 AS cupos
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, 33 AS dias, '16:00:00' AS hora, 8 AS cupos
  UNION ALL SELECT 'Pesca artesanal en la ciénaga' AS titulo, 37 AS dias, '16:00:00' AS hora, 8 AS cupos
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, -49 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, -33 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, 9 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, 22 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Cata de mariscos y maridaje en San Onofre' AS titulo, 35 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Manglar y conservación' AS titulo, -54 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Manglar y conservación' AS titulo, -37 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Manglar y conservación' AS titulo, 14 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Manglar y conservación' AS titulo, 17 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Manglar y conservación' AS titulo, 31 AS dias, '16:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, -60 AS dias, '08:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, -55 AS dias, '08:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, 5 AS dias, '08:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, 33 AS dias, '08:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Noche de fandango sabanero' AS titulo, 42 AS dias, '08:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, -21 AS dias, '08:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, -10 AS dias, '08:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, 12 AS dias, '08:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, 17 AS dias, '08:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Historia de Sincelejo a pie' AS titulo, 20 AS dias, '08:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, -26 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, -12 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, 14 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, 22 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'El sombrero vueltiao por dentro' AS titulo, 27 AS dias, '08:00:00' AS hora, 15 AS cupos
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, -40 AS dias, '09:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, -18 AS dias, '09:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, 36 AS dias, '09:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, 41 AS dias, '09:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Música de gaitas y tambores' AS titulo, 42 AS dias, '09:00:00' AS hora, 30 AS cupos
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, -46 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, -26 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, 13 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, 35 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Ruta de la Gaita y la Hamaca en Morroa' AS titulo, 42 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, -55 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, -34 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, 13 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, 15 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Trenzado de caña flecha' AS titulo, 42 AS dias, '14:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, -34 AS dias, '09:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, -28 AS dias, '09:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, 14 AS dias, '09:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, 29 AS dias, '09:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Mochilas y tejidos sabaneros' AS titulo, 38 AS dias, '09:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, -60 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, -36 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, 9 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, 11 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Kayak en el Golfo de Morrosquillo' AS titulo, 29 AS dias, '08:00:00' AS hora, 12 AS cupos
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, -38 AS dias, '16:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, -7 AS dias, '16:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, 6 AS dias, '16:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, 27 AS dias, '16:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Paseo en lancha a Isla Múcura' AS titulo, 37 AS dias, '16:00:00' AS hora, 25 AS cupos
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, -40 AS dias, '08:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, -17 AS dias, '08:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, 24 AS dias, '08:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, 25 AS dias, '08:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Cabalgata por la sabana' AS titulo, 33 AS dias, '08:00:00' AS hora, 10 AS cupos
  UNION ALL SELECT 'Snorkel en Coveñas' AS titulo, -29 AS dias, '16:00:00' AS hora, 10 AS cupos
) t
JOIN experiencias e ON e.titulo = t.titulo
WHERE NOT EXISTS (SELECT 1 FROM programacion p
                  WHERE p.id_experiencia = e.id_experiencia
                    AND p.fecha_actividad = DATE_ADD(CURDATE(), INTERVAL t.dias DAY)
                    AND p.hora_inicio = t.hora);

-- 3.7 Visitantes con nombres realistas (se suman a los 200 de prueba)
INSERT IGNORE INTO visitantes (nombre, apellido, email, telefono) VALUES
('Diego', 'Navarro', 'diego.navarro@correo.test', '3043581855'),
('Diego', 'Romero', 'diego.romero@correo.test', '3108274727'),
('Sofía', 'Arrieta', 'sofia.arrieta@correo.test', '3224914569'),
('Yuliana', 'Tovar', 'yuliana.tovar@correo.test', '3017696744'),
('Camila', 'Mercado', 'camila.mercado@correo.test', '3041758944'),
('Kevin', 'Atencia', 'kevin.atencia@correo.test', '3008580296'),
('Diana', 'Julio', 'diana.julio@correo.test', '3109117501'),
('Fabián', 'Sierra', 'fabian.sierra@correo.test', '3003166605'),
('Kevin', 'Romero', 'kevin.romero@correo.test', '3109671348'),
('Alejandro', 'Hernández', 'alejandro.hernandez@correo.test', '3044120649'),
('Miguel', 'Montes', 'miguel.montes@correo.test', '3209942439'),
('Natalia', 'Castro', 'natalia.castro@correo.test', '3017428783'),
('Laura', 'Díaz', 'laura.diaz@correo.test', '3153930894'),
('José', 'Ruiz', 'jose.ruiz@correo.test', '3227974916'),
('Laura', 'Ruiz', 'laura.ruiz@correo.test', '3046465836'),
('Sebastián', 'Padilla', 'sebastian.padilla@correo.test', '3223015037'),
('Sebastián', 'Ortega', 'sebastian.ortega@correo.test', '3235594149'),
('Rafael', 'Rodríguez', 'rafael.rodriguez@correo.test', '3104881154'),
('Andrés', 'Gómez', 'andres.gomez@correo.test', '3226543899'),
('Natalia', 'Atencia', 'natalia.atencia@correo.test', '3041456084'),
('Paola', 'Castro', 'paola.castro@correo.test', '3046900575'),
('Mariana', 'Sierra', 'mariana.sierra@correo.test', '3234632979'),
('Valentina', 'Navarro', 'valentina.navarro@correo.test', '3124597623'),
('Diego', 'Vergara', 'diego.vergara@correo.test', '3123224963'),
('Valentina', 'Ortega', 'valentina.ortega@correo.test', '3122617839'),
('Natalia', 'Díaz', 'natalia.diaz@correo.test', '3012013781'),
('Óscar', 'Barrios', 'oscar.barrios@correo.test', '3042783754'),
('Sebastián', 'Arrieta', 'sebastian.arrieta@correo.test', '3122072316'),
('Laura', 'Paternina', 'laura.paternina@correo.test', '3153707689'),
('José', 'Montes', 'jose.montes@correo.test', '3011232708'),
('Natalia', 'Castro', 'natalia.castro2@correo.test', '3127954630'),
('Andrés', 'Martínez', 'andres.martinez@correo.test', '3014946427'),
('Andrés', 'Vergara', 'andres.vergara@correo.test', '3012574879'),
('Yuliana', 'Atencia', 'yuliana.atencia@correo.test', '3156284394'),
('Óscar', 'Ruiz', 'oscar.ruiz@correo.test', '3007781192'),
('Jorge', 'Navarro', 'jorge.navarro@correo.test', '3108762311'),
('Natalia', 'Sierra', 'natalia.sierra@correo.test', '3017277142'),
('Diana', 'Romero', 'diana.romero@correo.test', '3127527130'),
('Laura', 'Acosta', 'laura.acosta@correo.test', '3151966882'),
('Ana', 'Tovar', 'ana.tovar@correo.test', '3201397004'),
('Laura', 'Tovar', 'laura.tovar@correo.test', '3155857938'),
('Ana', 'Julio', 'ana.julio@correo.test', '3015981860'),
('Óscar', 'Benítez', 'oscar.benitez@correo.test', '3151340075'),
('Mariana', 'Arrieta', 'mariana.arrieta@correo.test', '3101941959'),
('Ana', 'Rodríguez', 'ana.rodriguez@correo.test', '3043058316'),
('Valentina', 'Martínez', 'valentina.martinez@correo.test', '3049767502'),
('Paola', 'Navarro', 'paola.navarro@correo.test', '3121483086'),
('Natalia', 'Cárdenas', 'natalia.cardenas@correo.test', '3046972209'),
('Natalia', 'Contreras', 'natalia.contreras@correo.test', '3205014888'),
('Óscar', 'Benítez', 'oscar.benitez2@correo.test', '3103100642'),
('Daniela', 'Atencia', 'daniela.atencia@correo.test', '3007658179'),
('Alejandro', 'Montes', 'alejandro.montes@correo.test', '3044829496'),
('Andrés', 'Pérez', 'andres.perez@correo.test', '3129033657'),
('Natalia', 'Montes', 'natalia.montes@correo.test', '3153326285'),
('Kevin', 'Cárdenas', 'kevin.cardenas@correo.test', '3014008192'),
('Mariana', 'Martínez', 'mariana.martinez@correo.test', '3235449700'),
('Jorge', 'Olivera', 'jorge.olivera@correo.test', '3236326731'),
('Camila', 'Sierra', 'camila.sierra@correo.test', '3005073617'),
('Isabella', 'Martínez', 'isabella.martinez@correo.test', '3109533231'),
('Diana', 'Hernández', 'diana.hernandez@correo.test', '3207038642'),
('Lina', 'Salgado', 'lina.salgado@correo.test', '3235626517'),
('Jorge', 'Castro', 'jorge.castro@correo.test', '3107286867'),
('Paola', 'Ruiz', 'paola.ruiz@correo.test', '3228953451'),
('Alejandro', 'Ortega', 'alejandro.ortega@correo.test', '3124152477'),
('Daniela', 'Olivera', 'daniela.olivera@correo.test', '3203579994'),
('Isabella', 'Rivera', 'isabella.rivera@correo.test', '3006946386'),
('Rafael', 'Acosta', 'rafael.acosta@correo.test', '3237850588'),
('Lina', 'Martínez', 'lina.martinez@correo.test', '3042412764'),
('Laura', 'Barrios', 'laura.barrios@correo.test', '3235446211'),
('Carlos', 'Tovar', 'carlos.tovar@correo.test', '3011307902'),
('Mariana', 'Mercado', 'mariana.mercado@correo.test', '3121748986'),
('Miguel', 'Contreras', 'miguel.contreras@correo.test', '3239667041'),
('Lina', 'Olivera', 'lina.olivera@correo.test', '3049535601'),
('Valentina', 'Gómez', 'valentina.gomez@correo.test', '3047529890'),
('Jorge', 'Atencia', 'jorge.atencia@correo.test', '3126207979'),
('Camila', 'Meza', 'camila.meza@correo.test', '3103721443'),
('Alejandro', 'Vergara', 'alejandro.vergara@correo.test', '3125791217'),
('Paola', 'Hernández', 'paola.hernandez@correo.test', '3204165812'),
('Ana', 'Olivera', 'ana.olivera@correo.test', '3009053266'),
('Natalia', 'Barrios', 'natalia.barrios@correo.test', '3233866978'),
('Ana', 'Romero', 'ana.romero@correo.test', '3004013575'),
('Jorge', 'Atencia', 'jorge.atencia2@correo.test', '3043750423'),
('Andrés', 'Rivera', 'andres.rivera@correo.test', '3019640135'),
('Yuliana', 'Rivera', 'yuliana.rivera@correo.test', '3007284030'),
('Juan', 'Barrios', 'juan.barrios@correo.test', '3124627088'),
('Mariana', 'Hernández', 'mariana.hernandez@correo.test', '3103122728'),
('Valentina', 'Arrieta', 'valentina.arrieta@correo.test', '3222801764'),
('Diana', 'Acosta', 'diana.acosta@correo.test', '3017395450'),
('José', 'Navarro', 'jose.navarro@correo.test', '3122972144'),
('Paola', 'Padilla', 'paola.padilla@correo.test', '3223029013'),
('Mariana', 'Romero', 'mariana.romero@correo.test', '3107017607'),
('Yuliana', 'Acosta', 'yuliana.acosta@correo.test', '3226790134'),
('Juan', 'Gómez', 'juan.gomez@correo.test', '3019301581'),
('Óscar', 'Vergara', 'oscar.vergara@correo.test', '3124792454'),
('Daniela', 'Arrieta', 'daniela.arrieta@correo.test', '3209493836'),
('Mariana', 'Arrieta', 'mariana.arrieta2@correo.test', '3159274426'),
('Miguel', 'Arrieta', 'miguel.arrieta@correo.test', '3044296482'),
('Lina', 'Ruiz', 'lina.ruiz@correo.test', '3106847641'),
('Óscar', 'Ortega', 'oscar.ortega@correo.test', '3157873623'),
('Rafael', 'Ortega', 'rafael.ortega@correo.test', '3204571458'),
('Carlos', 'Ruiz', 'carlos.ruiz@correo.test', '3048235939'),
('José', 'Arrieta', 'jose.arrieta@correo.test', '3016369288'),
('José', 'Acosta', 'jose.acosta@correo.test', '3225422858'),
('Carlos', 'Atencia', 'carlos.atencia@correo.test', '3124930782'),
('Jorge', 'Hernández', 'jorge.hernandez@correo.test', '3233067560'),
('José', 'Vergara', 'jose.vergara@correo.test', '3227731771'),
('Miguel', 'Pérez', 'miguel.perez@correo.test', '3236522554'),
('Yuliana', 'Benítez', 'yuliana.benitez@correo.test', '3152593937'),
('Yuliana', 'Julio', 'yuliana.julio@correo.test', '3229668625'),
('Luis', 'Benítez', 'luis.benitez@correo.test', '3156543955'),
('Camila', 'Paternina', 'camila.paternina@correo.test', '3203901946'),
('Andrés', 'Montes', 'andres.montes@correo.test', '3235230777'),
('Carlos', 'Arrieta', 'carlos.arrieta@correo.test', '3208984994'),
('Diana', 'Rivera', 'diana.rivera@correo.test', '3226683223'),
('Andrés', 'Martínez', 'andres.martinez2@correo.test', '3103027361'),
('Yuliana', 'Castro', 'yuliana.castro@correo.test', '3126479668'),
('Andrés', 'Julio', 'andres.julio@correo.test', '3108669479'),
('Sebastián', 'Montes', 'sebastian.montes@correo.test', '3152325198'),
('Mariana', 'Tovar', 'mariana.tovar@correo.test', '3101191145'),
('Valentina', 'Hernández', 'valentina.hernandez@correo.test', '3154680993'),
('Santiago', 'Mercado', 'santiago.mercado@correo.test', '3046191677'),
('Juan', 'Cárdenas', 'juan.cardenas@correo.test', '3209754364'),
('Yuliana', 'Cárdenas', 'yuliana.cardenas@correo.test', '3233235607'),
('Valentina', 'Pérez', 'valentina.perez@correo.test', '3128038640'),
('Camila', 'Díaz', 'camila.diaz@correo.test', '3239613863'),
('María', 'Paternina', 'maria.paternina@correo.test', '3226725494'),
('Jorge', 'Barrios', 'jorge.barrios@correo.test', '3159047903'),
('José', 'Padilla', 'jose.padilla@correo.test', '3155196018'),
('Camila', 'Olivera', 'camila.olivera@correo.test', '3223235300'),
('Andrés', 'Padilla', 'andres.padilla@correo.test', '3155258943'),
('Rafael', 'Julio', 'rafael.julio@correo.test', '3224334204'),
('Paola', 'Montes', 'paola.montes@correo.test', '3237709644'),
('Laura', 'Mercado', 'laura.mercado@correo.test', '3007893064'),
('Diana', 'Gómez', 'diana.gomez@correo.test', '3239930040'),
('Óscar', 'Castro', 'oscar.castro@correo.test', '3129096637'),
('Sofía', 'Gómez', 'sofia.gomez@correo.test', '3239765137'),
('Sofía', 'Arrieta', 'sofia.arrieta2@correo.test', '3226334072'),
('Yuliana', 'Arrieta', 'yuliana.arrieta@correo.test', '3154039374'),
('Juan', 'Atencia', 'juan.atencia@correo.test', '3045319967'),
('Diana', 'Romero', 'diana.romero2@correo.test', '3237422797'),
('Kevin', 'Rodríguez', 'kevin.rodriguez@correo.test', '3101484455'),
('Santiago', 'Salgado', 'santiago.salgado@correo.test', '3108197225'),
('Sebastián', 'Castro', 'sebastian.castro@correo.test', '3233122075'),
('Sebastián', 'Mercado', 'sebastian.mercado@correo.test', '3129197072'),
('Carlos', 'Atencia', 'carlos.atencia2@correo.test', '3157102640'),
('Kevin', 'Contreras', 'kevin.contreras@correo.test', '3234171791'),
('Carlos', 'Navarro', 'carlos.navarro@correo.test', '3233568720'),
('Ana', 'Hernández', 'ana.hernandez@correo.test', '3042024716'),
('Lina', 'Sierra', 'lina.sierra@correo.test', '3005703780'),
('Lina', 'Vergara', 'lina.vergara@correo.test', '3043335198'),
('José', 'Atencia', 'jose.atencia@correo.test', '3153147305'),
('Santiago', 'Díaz', 'santiago.diaz@correo.test', '3041899976'),
('Óscar', 'Díaz', 'oscar.diaz@correo.test', '3047944378'),
('Kevin', 'Navarro', 'kevin.navarro@correo.test', '3221486701'),
('Laura', 'Salgado', 'laura.salgado@correo.test', '3237109537'),
('Alejandro', 'Atencia', 'alejandro.atencia@correo.test', '3018812140'),
('Yuliana', 'Meza', 'yuliana.meza@correo.test', '3203600769'),
('Alejandro', 'Arrieta', 'alejandro.arrieta@correo.test', '3049526818'),
('Camila', 'Padilla', 'camila.padilla@correo.test', '3001975917'),
('Valentina', 'Barrios', 'valentina.barrios@correo.test', '3126515873'),
('Óscar', 'Pérez', 'oscar.perez@correo.test', '3049443358'),
('Luis', 'Castro', 'luis.castro@correo.test', '3018094080'),
('Yuliana', 'Benítez', 'yuliana.benitez2@correo.test', '3103863352'),
('María', 'Salgado', 'maria.salgado@correo.test', '3224568743'),
('Paola', 'Díaz', 'paola.diaz@correo.test', '3238079532'),
('Ana', 'Benítez', 'ana.benitez@correo.test', '3227093336'),
('Fabián', 'Mercado', 'fabian.mercado@correo.test', '3128389971'),
('Karen', 'Atencia', 'karen.atencia@correo.test', '3222539537'),
('Alejandro', 'Rivera', 'alejandro.rivera@correo.test', '3104279047'),
('Valentina', 'Julio', 'valentina.julio@correo.test', '3016938050'),
('Fabián', 'Sierra', 'fabian.sierra2@correo.test', '3042931846'),
('Daniela', 'Mercado', 'daniela.mercado@correo.test', '3204175914'),
('Alejandro', 'Benítez', 'alejandro.benitez@correo.test', '3003430713'),
('Kevin', 'Rivera', 'kevin.rivera@correo.test', '3125817017'),
('Ana', 'Barrios', 'ana.barrios@correo.test', '3201159745'),
('Isabella', 'Romero', 'isabella.romero@correo.test', '3225581623'),
('Rafael', 'Barrios', 'rafael.barrios@correo.test', '3223314374'),
('Valentina', 'Ortega', 'valentina.ortega2@correo.test', '3044734464'),
('Paola', 'Ruiz', 'paola.ruiz2@correo.test', '3201809251'),
('Karen', 'Tovar', 'karen.tovar@correo.test', '3236473593'),
('Óscar', 'Montes', 'oscar.montes@correo.test', '3018734098'),
('Santiago', 'Barrios', 'santiago.barrios@correo.test', '3239814702'),
('Rafael', 'Romero', 'rafael.romero@correo.test', '3015632460'),
('Laura', 'Martínez', 'laura.martinez@correo.test', '3011702516'),
('Juan', 'Romero', 'juan.romero@correo.test', '3222825314'),
('Miguel', 'Ortega', 'miguel.ortega@correo.test', '3229030089'),
('Mariana', 'Pérez', 'mariana.perez@correo.test', '3046342084'),
('Carlos', 'Pérez', 'carlos.perez@correo.test', '3017573946'),
('Juan', 'Díaz', 'juan.diaz@correo.test', '3235277321'),
('Andrés', 'Martínez', 'andres.martinez3@correo.test', '3019737793'),
('Valentina', 'Meza', 'valentina.meza@correo.test', '3153570821'),
('Laura', 'Padilla', 'laura.padilla@correo.test', '3106406523'),
('Fabián', 'Rivera', 'fabian.rivera@correo.test', '3225068994'),
('Miguel', 'Salgado', 'miguel.salgado@correo.test', '3236244852'),
('Natalia', 'Martínez', 'natalia.martinez@correo.test', '3225181240'),
('Sofía', 'Díaz', 'sofia.diaz@correo.test', '3224164236'),
('Óscar', 'Rodríguez', 'oscar.rodriguez@correo.test', '3227402502'),
('Isabella', 'Romero', 'isabella.romero2@correo.test', '3009371075'),
('Luis', 'Contreras', 'luis.contreras@correo.test', '3009884161'),
('Santiago', 'Ortega', 'santiago.ortega@correo.test', '3045943781'),
('María', 'Castro', 'maria.castro@correo.test', '3236265969'),
('José', 'Julio', 'jose.julio@correo.test', '3201441202'),
('Paola', 'Navarro', 'paola.navarro2@correo.test', '3233791061'),
('Sebastián', 'Rodríguez', 'sebastian.rodriguez@correo.test', '3154637333'),
('Diego', 'Gómez', 'diego.gomez@correo.test', '3233853179'),
('Santiago', 'Contreras', 'santiago.contreras@correo.test', '3012772651'),
('Lina', 'Benítez', 'lina.benitez@correo.test', '3201096826'),
('María', 'Mercado', 'maria.mercado@correo.test', '3005407009'),
('Óscar', 'Ortega', 'oscar.ortega2@correo.test', '3049803364'),
('José', 'Paternina', 'jose.paternina@correo.test', '3152418549'),
('José', 'Díaz', 'jose.diaz@correo.test', '3004666699'),
('Fabián', 'Acosta', 'fabian.acosta@correo.test', '3232940945'),
('Alejandro', 'Ruiz', 'alejandro.ruiz@correo.test', '3231596825'),
('Paola', 'Rivera', 'paola.rivera@correo.test', '3229648467'),
('Kevin', 'Paternina', 'kevin.paternina@correo.test', '3004187727'),
('Kevin', 'Olivera', 'kevin.olivera@correo.test', '3221788770'),
('Laura', 'Gómez', 'laura.gomez@correo.test', '3042099053'),
('José', 'Mercado', 'jose.mercado@correo.test', '3005813396'),
('Sofía', 'Olivera', 'sofia.olivera@correo.test', '3008908490'),
('Karen', 'Montes', 'karen.montes@correo.test', '3013811798');

-- 3.8 Reservas (tabla principal). Se crean como CONFIRMADA; los triggers
-- validan y descuentan los cupos. El monto usa fn_calcular_total_reserva.
CREATE TEMPORARY TABLE tmp_reservas (
  email VARCHAR(150), titulo VARCHAR(150), dias INT, personas INT,
  id_visitante INT NULL, id_programacion INT NULL,
  monto DECIMAL(12,2) NULL, fecha_reserva DATETIME NULL
);
INSERT INTO tmp_reservas (email, titulo, dias, personas) VALUES
('sebastian.mercado@correo.test', 'Taller de cocina sabanera', -34, 1),
('miguel.salgado@correo.test', 'Taller de cocina sabanera', -34, 1),
('miguel.contreras@correo.test', 'Taller de cocina sabanera', -34, 2),
('karen.atencia@correo.test', 'Taller de cocina sabanera', -6, 5),
('jose.navarro@correo.test', 'Taller de cocina sabanera', 35, 1),
('fabian.rivera@correo.test', 'Taller de cocina sabanera', 35, 1),
('kevin.contreras@correo.test', 'Taller de cocina sabanera', 35, 1),
('santiago.ortega@correo.test', 'Taller de cocina sabanera', 35, 4),
('valentina.ortega2@correo.test', 'Taller de cocina sabanera', 37, 4),
('ana.rodriguez@correo.test', 'Taller de cocina sabanera', 41, 3),
('jose.montes@correo.test', 'Taller de cocina sabanera', 41, 2),
('oscar.ortega2@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', -46, 1),
('paola.ruiz2@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', -46, 2),
('yuliana.benitez@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', -46, 2),
('valentina.arrieta@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', -24, 3),
('yuliana.acosta@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', -24, 2),
('kevin.atencia@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', 8, 3),
('miguel.arrieta@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', 13, 1),
('paola.hernandez@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', 13, 4),
('kevin.contreras@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', 38, 2),
('laura.padilla@correo.test', 'Ruta Gastronómica del Mote de Queso en Sincelejo', 38, 1),
('fabian.sierra@correo.test', 'Ruta del pescado en Tolú', -21, 2),
('juan.diaz@correo.test', 'Ruta del pescado en Tolú', -21, 2),
('sebastian.montes@correo.test', 'Ruta del pescado en Tolú', -15, 1),
('paola.ruiz@correo.test', 'Ruta del pescado en Tolú', -15, 2),
('fabian.rivera@correo.test', 'Ruta del pescado en Tolú', -15, 3),
('camila.olivera@correo.test', 'Ruta del pescado en Tolú', 14, 2),
('yuliana.cardenas@correo.test', 'Ruta del pescado en Tolú', 14, 5),
('yuliana.meza@correo.test', 'Ruta del pescado en Tolú', 32, 1),
('diana.romero@correo.test', 'Ruta del pescado en Tolú', 32, 2),
('diana.rivera@correo.test', 'Ruta del pescado en Tolú', 35, 1),
('laura.acosta@correo.test', 'Ruta del pescado en Tolú', 35, 2),
('oscar.perez@correo.test', 'Ruta del pescado en Tolú', 35, 2),
('jose.atencia@correo.test', 'Mariscos frente al mar', -46, 1),
('isabella.martinez@correo.test', 'Mariscos frente al mar', -46, 1),
('diana.rivera@correo.test', 'Mariscos frente al mar', -46, 4),
('laura.gomez@correo.test', 'Mariscos frente al mar', -4, 4),
('mariana.mercado@correo.test', 'Mariscos frente al mar', -4, 2),
('alejandro.ruiz@correo.test', 'Mariscos frente al mar', 12, 2),
('andres.martinez2@correo.test', 'Mariscos frente al mar', 12, 1),
('jose.vergara@correo.test', 'Mariscos frente al mar', 12, 3),
('jose.paternina@correo.test', 'Mariscos frente al mar', 34, 4),
('fabian.sierra@correo.test', 'Mariscos frente al mar', 35, 2),
('paola.ruiz2@correo.test', 'Mariscos frente al mar', 35, 1),
('natalia.martinez@correo.test', 'Mariscos frente al mar', 35, 1),
('camila.sierra@correo.test', 'Sabores Zenú de Sampués', -35, 5),
('fabian.sierra2@correo.test', 'Sabores Zenú de Sampués', -35, 4),
('diego.gomez@correo.test', 'Sabores Zenú de Sampués', -35, 2),
('oscar.ortega@correo.test', 'Sabores Zenú de Sampués', -25, 1),
('mariana.hernandez@correo.test', 'Sabores Zenú de Sampués', -25, 1),
('jose.arrieta@correo.test', 'Sabores Zenú de Sampués', -25, 2),
('kevin.rodriguez@correo.test', 'Sabores Zenú de Sampués', -25, 1),
('juan.atencia@correo.test', 'Sabores Zenú de Sampués', -25, 2),
('miguel.arrieta@correo.test', 'Sabores Zenú de Sampués', -25, 2),
('jose.navarro@correo.test', 'Sabores Zenú de Sampués', -25, 3),
('ana.rodriguez@correo.test', 'Sabores Zenú de Sampués', 24, 2),
('alejandro.hernandez@correo.test', 'Sabores Zenú de Sampués', 24, 2),
('fabian.acosta@correo.test', 'Sabores Zenú de Sampués', 24, 3),
('mariana.arrieta@correo.test', 'Sabores Zenú de Sampués', 24, 1),
('daniela.mercado@correo.test', 'Sabores Zenú de Sampués', 24, 4),
('miguel.arrieta@correo.test', 'Sabores Zenú de Sampués', 37, 2),
('ana.barrios@correo.test', 'Sabores Zenú de Sampués', 37, 2),
('ana.olivera@correo.test', 'Sabores Zenú de Sampués', 37, 1),
('diego.gomez@correo.test', 'Sabores Zenú de Sampués', 37, 3),
('valentina.arrieta@correo.test', 'Sabores Zenú de Sampués', 37, 2),
('camila.sierra@correo.test', 'Sabores Zenú de Sampués', 40, 4),
('luis.castro@correo.test', 'Sabores Zenú de Sampués', 40, 5),
('alejandro.ruiz@correo.test', 'Sabores Zenú de Sampués', 40, 4),
('rafael.julio@correo.test', 'Asado sabanero en Corozal', -9, 5),
('fabian.sierra2@correo.test', 'Asado sabanero en Corozal', -9, 1),
('alejandro.arrieta@correo.test', 'Asado sabanero en Corozal', -9, 4),
('alejandro.ruiz@correo.test', 'Asado sabanero en Corozal', -4, 2),
('fabian.rivera@correo.test', 'Asado sabanero en Corozal', -4, 5),
('jorge.olivera@correo.test', 'Asado sabanero en Corozal', -4, 2),
('rafael.ortega@correo.test', 'Asado sabanero en Corozal', 17, 2),
('oscar.vergara@correo.test', 'Asado sabanero en Corozal', 17, 2),
('diego.gomez@correo.test', 'Asado sabanero en Corozal', 17, 4),
('yuliana.acosta@correo.test', 'Asado sabanero en Corozal', 30, 2),
('fabian.sierra@correo.test', 'Asado sabanero en Corozal', 30, 4),
('mariana.martinez@correo.test', 'Asado sabanero en Corozal', 30, 1),
('juan.cardenas@correo.test', 'Asado sabanero en Corozal', 32, 2),
('laura.tovar@correo.test', 'Asado sabanero en Corozal', 32, 5),
('natalia.contreras@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 2),
('diana.romero2@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 2),
('natalia.diaz@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 1),
('jose.arrieta@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 1),
('kevin.navarro@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 1),
('laura.mercado@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 2),
('oscar.perez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 5),
('lina.salgado@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 1),
('diego.navarro@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 2),
('sebastian.ortega@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 1),
('alejandro.rivera@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -43, 2),
('oscar.perez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 1),
('paola.diaz@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 2),
('jose.paternina@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 1),
('diego.gomez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 1),
('camila.diaz@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 2),
('paola.navarro@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 2),
('jose.navarro@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 1),
('diana.rivera@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 1),
('sofia.olivera@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 2),
('kevin.rodriguez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 4),
('yuliana.julio@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', -7, 3),
('kevin.atencia@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 1),
('yuliana.julio@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 3),
('sebastian.ortega@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 4),
('sebastian.padilla@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 2),
('paola.padilla@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 2),
('laura.diaz@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 3),
('luis.benitez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 2),
('isabella.rivera@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 5, 2),
('yuliana.julio@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 2),
('mariana.arrieta@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 1),
('natalia.sierra@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 1),
('paola.navarro2@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 2),
('luis.contreras@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 2),
('jose.julio@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 4),
('camila.sierra@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 1),
('fabian.rivera@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 2),
('yuliana.benitez2@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 1),
('oscar.rodriguez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 1),
('jorge.atencia2@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 7, 2),
('lina.sierra@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 2),
('andres.martinez3@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 2),
('oscar.castro@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 4),
('yuliana.benitez@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 1),
('sebastian.castro@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 1),
('jose.vergara@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 2),
('rafael.acosta@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 3),
('isabella.romero2@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 1),
('diana.rivera@correo.test', 'Pasadía en la Ciénaga de la Caimanera en Coveñas', 14, 3),
('oscar.ortega2@correo.test', 'Atardecer en Rincón del Mar', -27, 1),
('lina.martinez@correo.test', 'Atardecer en Rincón del Mar', -27, 2),
('alejandro.atencia@correo.test', 'Atardecer en Rincón del Mar', -27, 2),
('daniela.atencia@correo.test', 'Atardecer en Rincón del Mar', -27, 1),
('valentina.arrieta@correo.test', 'Atardecer en Rincón del Mar', -9, 2),
('mariana.perez@correo.test', 'Atardecer en Rincón del Mar', -9, 3),
('maria.salgado@correo.test', 'Atardecer en Rincón del Mar', -9, 5),
('ana.benitez@correo.test', 'Atardecer en Rincón del Mar', 17, 2),
('mariana.tovar@correo.test', 'Atardecer en Rincón del Mar', 17, 2),
('alejandro.benitez@correo.test', 'Atardecer en Rincón del Mar', 17, 2),
('jose.diaz@correo.test', 'Atardecer en Rincón del Mar', 28, 2),
('miguel.salgado@correo.test', 'Atardecer en Rincón del Mar', 28, 5),
('kevin.contreras@correo.test', 'Atardecer en Rincón del Mar', 36, 2),
('yuliana.tovar@correo.test', 'Atardecer en Rincón del Mar', 36, 2),
('oscar.ortega@correo.test', 'Atardecer en Rincón del Mar', 36, 3),
('paola.navarro2@correo.test', 'Senderismo en los Montes de María - Colosó', -29, 3),
('yuliana.cardenas@correo.test', 'Senderismo en los Montes de María - Colosó', -29, 1),
('jose.vergara@correo.test', 'Senderismo en los Montes de María - Colosó', -29, 1),
('laura.salgado@correo.test', 'Senderismo en los Montes de María - Colosó', -29, 2),
('santiago.barrios@correo.test', 'Senderismo en los Montes de María - Colosó', -29, 1),
('diana.romero2@correo.test', 'Senderismo en los Montes de María - Colosó', -29, 1),
('jose.montes@correo.test', 'Senderismo en los Montes de María - Colosó', -16, 3),
('camila.paternina@correo.test', 'Senderismo en los Montes de María - Colosó', -16, 3),
('alejandro.vergara@correo.test', 'Senderismo en los Montes de María - Colosó', -16, 1),
('santiago.barrios@correo.test', 'Senderismo en los Montes de María - Colosó', -16, 4),
('laura.ruiz@correo.test', 'Senderismo en los Montes de María - Colosó', 34, 1),
('valentina.martinez@correo.test', 'Senderismo en los Montes de María - Colosó', 34, 1),
('oscar.vergara@correo.test', 'Senderismo en los Montes de María - Colosó', 34, 1),
('camila.padilla@correo.test', 'Senderismo en los Montes de María - Colosó', 34, 5),
('yuliana.meza@correo.test', 'Senderismo en los Montes de María - Colosó', 36, 1),
('yuliana.benitez2@correo.test', 'Senderismo en los Montes de María - Colosó', 36, 2),
('jorge.atencia@correo.test', 'Senderismo en los Montes de María - Colosó', 36, 2),
('yuliana.benitez@correo.test', 'Senderismo en los Montes de María - Colosó', 36, 1),
('valentina.ortega2@correo.test', 'Senderismo en los Montes de María - Colosó', 36, 1),
('oscar.barrios@correo.test', 'Senderismo en los Montes de María - Colosó', 36, 5),
('jose.atencia@correo.test', 'Senderismo en los Montes de María - Colosó', 37, 1),
('juan.romero@correo.test', 'Senderismo en los Montes de María - Colosó', 37, 4),
('jorge.navarro@correo.test', 'Senderismo en los Montes de María - Colosó', 37, 2),
('paola.rivera@correo.test', 'Senderismo en los Montes de María - Colosó', 37, 2),
('diana.julio@correo.test', 'Aves de La Mojana', -25, 2),
('valentina.gomez@correo.test', 'Aves de La Mojana', -25, 3),
('daniela.arrieta@correo.test', 'Aves de La Mojana', -25, 2),
('paola.rivera@correo.test', 'Aves de La Mojana', -25, 2),
('natalia.contreras@correo.test', 'Aves de La Mojana', -18, 3),
('miguel.perez@correo.test', 'Aves de La Mojana', -18, 5),
('yuliana.arrieta@correo.test', 'Aves de La Mojana', 7, 1),
('jose.arrieta@correo.test', 'Aves de La Mojana', 7, 1),
('rafael.rodriguez@correo.test', 'Aves de La Mojana', 7, 3),
('carlos.navarro@correo.test', 'Aves de La Mojana', 7, 2),
('yuliana.benitez2@correo.test', 'Aves de La Mojana', 23, 2),
('maria.castro@correo.test', 'Aves de La Mojana', 23, 2),
('santiago.ortega@correo.test', 'Aves de La Mojana', 23, 1),
('sebastian.rodriguez@correo.test', 'Aves de La Mojana', 23, 3),
('andres.martinez3@correo.test', 'Aves de La Mojana', 25, 1),
('valentina.barrios@correo.test', 'Aves de La Mojana', 25, 2),
('andres.rivera@correo.test', 'Aves de La Mojana', 25, 1),
('santiago.contreras@correo.test', 'Aves de La Mojana', 25, 1),
('fabian.sierra@correo.test', 'Aves de La Mojana', 25, 3),
('oscar.benitez2@correo.test', 'Pesca artesanal en la ciénaga', -54, 4),
('natalia.atencia@correo.test', 'Pesca artesanal en la ciénaga', -9, 2),
('karen.montes@correo.test', 'Pesca artesanal en la ciénaga', 21, 5),
('daniela.mercado@correo.test', 'Pesca artesanal en la ciénaga', 33, 2),
('oscar.benitez2@correo.test', 'Pesca artesanal en la ciénaga', 37, 2),
('diego.vergara@correo.test', 'Cata de mariscos y maridaje en San Onofre', -49, 2),
('sebastian.mercado@correo.test', 'Cata de mariscos y maridaje en San Onofre', -49, 2),
('diana.romero2@correo.test', 'Cata de mariscos y maridaje en San Onofre', -49, 1),
('camila.sierra@correo.test', 'Cata de mariscos y maridaje en San Onofre', -49, 1),
('paola.padilla@correo.test', 'Cata de mariscos y maridaje en San Onofre', -49, 2),
('jorge.navarro@correo.test', 'Cata de mariscos y maridaje en San Onofre', -33, 3),
('oscar.benitez2@correo.test', 'Cata de mariscos y maridaje en San Onofre', -33, 1),
('ana.barrios@correo.test', 'Cata de mariscos y maridaje en San Onofre', -33, 2),
('daniela.olivera@correo.test', 'Cata de mariscos y maridaje en San Onofre', -33, 1),
('natalia.contreras@correo.test', 'Cata de mariscos y maridaje en San Onofre', 9, 2),
('valentina.martinez@correo.test', 'Cata de mariscos y maridaje en San Onofre', 9, 1),
('juan.cardenas@correo.test', 'Cata de mariscos y maridaje en San Onofre', 9, 5),
('oscar.ruiz@correo.test', 'Cata de mariscos y maridaje en San Onofre', 22, 2),
('valentina.gomez@correo.test', 'Cata de mariscos y maridaje en San Onofre', 22, 2),
('diego.gomez@correo.test', 'Cata de mariscos y maridaje en San Onofre', 22, 3),
('jose.navarro@correo.test', 'Cata de mariscos y maridaje en San Onofre', 35, 5),
('camila.sierra@correo.test', 'Cata de mariscos y maridaje en San Onofre', 35, 4),
('juan.cardenas@correo.test', 'Manglar y conservación', -54, 3),
('kevin.romero@correo.test', 'Manglar y conservación', -54, 2),
('laura.acosta@correo.test', 'Manglar y conservación', -37, 4),
('carlos.ruiz@correo.test', 'Manglar y conservación', -37, 1),
('rafael.romero@correo.test', 'Manglar y conservación', 14, 5),
('rafael.acosta@correo.test', 'Manglar y conservación', 17, 2),
('jose.diaz@correo.test', 'Manglar y conservación', 17, 5),
('lina.olivera@correo.test', 'Manglar y conservación', 31, 2),
('karen.tovar@correo.test', 'Manglar y conservación', 31, 1),
('laura.diaz@correo.test', 'Manglar y conservación', 31, 4),
('jorge.atencia@correo.test', 'Noche de fandango sabanero', -60, 5),
('diego.vergara@correo.test', 'Noche de fandango sabanero', -60, 3),
('karen.atencia@correo.test', 'Noche de fandango sabanero', -60, 4),
('juan.atencia@correo.test', 'Noche de fandango sabanero', -60, 1),
('ana.romero@correo.test', 'Noche de fandango sabanero', -60, 1),
('oscar.perez@correo.test', 'Noche de fandango sabanero', -60, 1),
('valentina.ortega@correo.test', 'Noche de fandango sabanero', -60, 4),
('diana.gomez@correo.test', 'Noche de fandango sabanero', -60, 1),
('ana.barrios@correo.test', 'Noche de fandango sabanero', -60, 4),
('valentina.meza@correo.test', 'Noche de fandango sabanero', -60, 2),
('miguel.montes@correo.test', 'Noche de fandango sabanero', -60, 2),
('kevin.rivera@correo.test', 'Noche de fandango sabanero', -55, 2),
('jorge.barrios@correo.test', 'Noche de fandango sabanero', -55, 2),
('maria.paternina@correo.test', 'Noche de fandango sabanero', -55, 5),
('sebastian.padilla@correo.test', 'Noche de fandango sabanero', -55, 3),
('diana.acosta@correo.test', 'Noche de fandango sabanero', -55, 2),
('alejandro.montes@correo.test', 'Noche de fandango sabanero', -55, 4),
('isabella.rivera@correo.test', 'Noche de fandango sabanero', -55, 2),
('oscar.castro@correo.test', 'Noche de fandango sabanero', -55, 2),
('carlos.atencia@correo.test', 'Noche de fandango sabanero', -55, 2),
('sofia.diaz@correo.test', 'Noche de fandango sabanero', -55, 2),
('ana.benitez@correo.test', 'Noche de fandango sabanero', -55, 1),
('camila.paternina@correo.test', 'Noche de fandango sabanero', 5, 3),
('ana.barrios@correo.test', 'Noche de fandango sabanero', 5, 2),
('kevin.navarro@correo.test', 'Noche de fandango sabanero', 5, 1),
('diana.romero@correo.test', 'Noche de fandango sabanero', 5, 1),
('juan.cardenas@correo.test', 'Noche de fandango sabanero', 5, 4),
('rafael.romero@correo.test', 'Noche de fandango sabanero', 5, 2),
('yuliana.acosta@correo.test', 'Noche de fandango sabanero', 5, 4),
('lina.martinez@correo.test', 'Noche de fandango sabanero', 5, 5),
('yuliana.julio@correo.test', 'Noche de fandango sabanero', 5, 1),
('natalia.montes@correo.test', 'Noche de fandango sabanero', 5, 1),
('kevin.cardenas@correo.test', 'Noche de fandango sabanero', 5, 1),
('isabella.romero@correo.test', 'Noche de fandango sabanero', 5, 2),
('sofia.gomez@correo.test', 'Noche de fandango sabanero', 33, 1),
('ana.rodriguez@correo.test', 'Noche de fandango sabanero', 33, 2),
('santiago.contreras@correo.test', 'Noche de fandango sabanero', 33, 2),
('yuliana.atencia@correo.test', 'Noche de fandango sabanero', 33, 5),
('karen.tovar@correo.test', 'Noche de fandango sabanero', 33, 4),
('valentina.martinez@correo.test', 'Noche de fandango sabanero', 33, 2),
('camila.paternina@correo.test', 'Noche de fandango sabanero', 33, 2),
('jose.diaz@correo.test', 'Noche de fandango sabanero', 33, 1),
('jose.arrieta@correo.test', 'Noche de fandango sabanero', 33, 1),
('daniela.arrieta@correo.test', 'Noche de fandango sabanero', 33, 2),
('andres.martinez3@correo.test', 'Noche de fandango sabanero', 42, 2),
('oscar.rodriguez@correo.test', 'Noche de fandango sabanero', 42, 2),
('maria.paternina@correo.test', 'Noche de fandango sabanero', 42, 3),
('jorge.atencia2@correo.test', 'Noche de fandango sabanero', 42, 1),
('jorge.castro@correo.test', 'Noche de fandango sabanero', 42, 5),
('lina.benitez@correo.test', 'Noche de fandango sabanero', 42, 3),
('maria.castro@correo.test', 'Noche de fandango sabanero', 42, 3),
('valentina.navarro@correo.test', 'Noche de fandango sabanero', 42, 2),
('paola.castro@correo.test', 'Noche de fandango sabanero', 42, 1),
('jorge.olivera@correo.test', 'Noche de fandango sabanero', 42, 2),
('camila.sierra@correo.test', 'Noche de fandango sabanero', 42, 3),
('valentina.barrios@correo.test', 'Historia de Sincelejo a pie', -21, 5),
('kevin.olivera@correo.test', 'Historia de Sincelejo a pie', -21, 2),
('mariana.mercado@correo.test', 'Historia de Sincelejo a pie', -21, 2),
('juan.romero@correo.test', 'Historia de Sincelejo a pie', -21, 4),
('jorge.atencia@correo.test', 'Historia de Sincelejo a pie', -21, 4),
('luis.castro@correo.test', 'Historia de Sincelejo a pie', -21, 3),
('paola.rivera@correo.test', 'Historia de Sincelejo a pie', -10, 1),
('mariana.tovar@correo.test', 'Historia de Sincelejo a pie', -10, 4),
('maria.mercado@correo.test', 'Historia de Sincelejo a pie', -10, 2),
('rafael.ortega@correo.test', 'Historia de Sincelejo a pie', -10, 1),
('rafael.julio@correo.test', 'Historia de Sincelejo a pie', -10, 4),
('ana.romero@correo.test', 'Historia de Sincelejo a pie', -10, 2),
('natalia.castro2@correo.test', 'Historia de Sincelejo a pie', -10, 2),
('miguel.contreras@correo.test', 'Historia de Sincelejo a pie', -10, 3),
('yuliana.atencia@correo.test', 'Historia de Sincelejo a pie', 12, 1),
('yuliana.rivera@correo.test', 'Historia de Sincelejo a pie', 12, 1),
('jorge.atencia2@correo.test', 'Historia de Sincelejo a pie', 12, 4),
('lina.martinez@correo.test', 'Historia de Sincelejo a pie', 12, 5),
('carlos.tovar@correo.test', 'Historia de Sincelejo a pie', 12, 2),
('lina.olivera@correo.test', 'Historia de Sincelejo a pie', 12, 1),
('carlos.atencia2@correo.test', 'Historia de Sincelejo a pie', 12, 4),
('miguel.contreras@correo.test', 'Historia de Sincelejo a pie', 17, 3),
('laura.mercado@correo.test', 'Historia de Sincelejo a pie', 17, 2),
('andres.martinez3@correo.test', 'Historia de Sincelejo a pie', 17, 3),
('kevin.rodriguez@correo.test', 'Historia de Sincelejo a pie', 17, 1),
('santiago.contreras@correo.test', 'Historia de Sincelejo a pie', 17, 1),
('sofia.arrieta@correo.test', 'Historia de Sincelejo a pie', 17, 1),
('diego.vergara@correo.test', 'Historia de Sincelejo a pie', 17, 1),
('carlos.atencia@correo.test', 'Historia de Sincelejo a pie', 17, 2),
('rafael.barrios@correo.test', 'Historia de Sincelejo a pie', 17, 3),
('sebastian.mercado@correo.test', 'Historia de Sincelejo a pie', 17, 1),
('camila.mercado@correo.test', 'Historia de Sincelejo a pie', 20, 1),
('miguel.montes@correo.test', 'Historia de Sincelejo a pie', 20, 5),
('yuliana.benitez2@correo.test', 'Historia de Sincelejo a pie', 20, 2),
('kevin.atencia@correo.test', 'Historia de Sincelejo a pie', 20, 1),
('oscar.rodriguez@correo.test', 'Historia de Sincelejo a pie', 20, 2),
('sebastian.arrieta@correo.test', 'Historia de Sincelejo a pie', 20, 1),
('jose.ruiz@correo.test', 'Historia de Sincelejo a pie', 20, 2),
('santiago.contreras@correo.test', 'Historia de Sincelejo a pie', 20, 1),
('jorge.barrios@correo.test', 'El sombrero vueltiao por dentro', -26, 2),
('jorge.olivera@correo.test', 'El sombrero vueltiao por dentro', -26, 1),
('yuliana.castro@correo.test', 'El sombrero vueltiao por dentro', -26, 1),
('alejandro.hernandez@correo.test', 'El sombrero vueltiao por dentro', -26, 1),
('camila.olivera@correo.test', 'El sombrero vueltiao por dentro', -26, 2),
('valentina.ortega2@correo.test', 'El sombrero vueltiao por dentro', -26, 2),
('oscar.rodriguez@correo.test', 'El sombrero vueltiao por dentro', -26, 2),
('yuliana.benitez@correo.test', 'El sombrero vueltiao por dentro', -26, 1),
('jose.acosta@correo.test', 'El sombrero vueltiao por dentro', -26, 3),
('oscar.barrios@correo.test', 'El sombrero vueltiao por dentro', -12, 4),
('jorge.castro@correo.test', 'El sombrero vueltiao por dentro', -12, 2),
('paola.castro@correo.test', 'El sombrero vueltiao por dentro', -12, 2),
('fabian.sierra@correo.test', 'El sombrero vueltiao por dentro', -12, 1),
('laura.diaz@correo.test', 'El sombrero vueltiao por dentro', -12, 5),
('andres.perez@correo.test', 'El sombrero vueltiao por dentro', 14, 1),
('diego.romero@correo.test', 'El sombrero vueltiao por dentro', 14, 1),
('rafael.ortega@correo.test', 'El sombrero vueltiao por dentro', 14, 2),
('diana.rivera@correo.test', 'El sombrero vueltiao por dentro', 14, 1),
('camila.paternina@correo.test', 'El sombrero vueltiao por dentro', 14, 5),
('valentina.arrieta@correo.test', 'El sombrero vueltiao por dentro', 14, 2),
('valentina.martinez@correo.test', 'El sombrero vueltiao por dentro', 14, 3),
('natalia.castro@correo.test', 'El sombrero vueltiao por dentro', 22, 1),
('jorge.navarro@correo.test', 'El sombrero vueltiao por dentro', 22, 1),
('miguel.montes@correo.test', 'El sombrero vueltiao por dentro', 22, 2),
('diego.vergara@correo.test', 'El sombrero vueltiao por dentro', 22, 2),
('luis.contreras@correo.test', 'El sombrero vueltiao por dentro', 22, 3),
('maria.mercado@correo.test', 'El sombrero vueltiao por dentro', 22, 2),
('kevin.atencia@correo.test', 'El sombrero vueltiao por dentro', 22, 2),
('jose.julio@correo.test', 'El sombrero vueltiao por dentro', 22, 2),
('lina.vergara@correo.test', 'El sombrero vueltiao por dentro', 27, 3),
('mariana.arrieta@correo.test', 'El sombrero vueltiao por dentro', 27, 3),
('jose.mercado@correo.test', 'El sombrero vueltiao por dentro', 27, 1),
('juan.diaz@correo.test', 'El sombrero vueltiao por dentro', 27, 2),
('natalia.contreras@correo.test', 'El sombrero vueltiao por dentro', 27, 4),
('sebastian.padilla@correo.test', 'Música de gaitas y tambores', -40, 1),
('camila.diaz@correo.test', 'Música de gaitas y tambores', -40, 4),
('natalia.diaz@correo.test', 'Música de gaitas y tambores', -40, 3),
('andres.martinez@correo.test', 'Música de gaitas y tambores', -40, 2),
('natalia.castro2@correo.test', 'Música de gaitas y tambores', -40, 2),
('lina.vergara@correo.test', 'Música de gaitas y tambores', -40, 1),
('oscar.diaz@correo.test', 'Música de gaitas y tambores', -40, 4),
('jorge.atencia@correo.test', 'Música de gaitas y tambores', -40, 2),
('kevin.atencia@correo.test', 'Música de gaitas y tambores', -40, 5),
('santiago.mercado@correo.test', 'Música de gaitas y tambores', -40, 3),
('ana.romero@correo.test', 'Música de gaitas y tambores', -40, 3),
('ana.romero@correo.test', 'Música de gaitas y tambores', -18, 1),
('jose.arrieta@correo.test', 'Música de gaitas y tambores', -18, 1),
('isabella.martinez@correo.test', 'Música de gaitas y tambores', -18, 5),
('valentina.ortega@correo.test', 'Música de gaitas y tambores', -18, 4),
('miguel.perez@correo.test', 'Música de gaitas y tambores', -18, 2),
('laura.mercado@correo.test', 'Música de gaitas y tambores', -18, 3),
('oscar.ortega2@correo.test', 'Música de gaitas y tambores', -18, 1),
('mariana.tovar@correo.test', 'Música de gaitas y tambores', -18, 2),
('kevin.rodriguez@correo.test', 'Música de gaitas y tambores', -18, 1),
('jorge.navarro@correo.test', 'Música de gaitas y tambores', -18, 3),
('andres.julio@correo.test', 'Música de gaitas y tambores', -18, 1),
('isabella.romero@correo.test', 'Música de gaitas y tambores', -18, 4),
('miguel.arrieta@correo.test', 'Música de gaitas y tambores', 36, 3),
('oscar.ortega2@correo.test', 'Música de gaitas y tambores', 36, 1),
('jorge.hernandez@correo.test', 'Música de gaitas y tambores', 36, 5),
('laura.acosta@correo.test', 'Música de gaitas y tambores', 36, 2),
('mariana.arrieta@correo.test', 'Música de gaitas y tambores', 36, 2),
('alejandro.rivera@correo.test', 'Música de gaitas y tambores', 36, 2),
('paola.navarro2@correo.test', 'Música de gaitas y tambores', 36, 4),
('yuliana.tovar@correo.test', 'Música de gaitas y tambores', 36, 5),
('laura.martinez@correo.test', 'Música de gaitas y tambores', 36, 2),
('oscar.montes@correo.test', 'Música de gaitas y tambores', 36, 4),
('ana.tovar@correo.test', 'Música de gaitas y tambores', 41, 1),
('camila.meza@correo.test', 'Música de gaitas y tambores', 41, 1),
('ana.julio@correo.test', 'Música de gaitas y tambores', 41, 1),
('valentina.hernandez@correo.test', 'Música de gaitas y tambores', 41, 2),
('diana.julio@correo.test', 'Música de gaitas y tambores', 41, 3),
('ana.barrios@correo.test', 'Música de gaitas y tambores', 41, 3),
('yuliana.benitez2@correo.test', 'Música de gaitas y tambores', 41, 3),
('natalia.castro@correo.test', 'Música de gaitas y tambores', 41, 3),
('ana.benitez@correo.test', 'Música de gaitas y tambores', 41, 2),
('diana.gomez@correo.test', 'Música de gaitas y tambores', 41, 1),
('sebastian.castro@correo.test', 'Música de gaitas y tambores', 41, 2),
('alejandro.vergara@correo.test', 'Música de gaitas y tambores', 41, 2),
('natalia.castro2@correo.test', 'Música de gaitas y tambores', 41, 1),
('yuliana.arrieta@correo.test', 'Música de gaitas y tambores', 41, 2),
('diana.hernandez@correo.test', 'Música de gaitas y tambores', 42, 1),
('natalia.sierra@correo.test', 'Música de gaitas y tambores', 42, 3),
('valentina.martinez@correo.test', 'Música de gaitas y tambores', 42, 2),
('oscar.vergara@correo.test', 'Música de gaitas y tambores', 42, 2),
('andres.montes@correo.test', 'Música de gaitas y tambores', 42, 4),
('oscar.benitez2@correo.test', 'Música de gaitas y tambores', 42, 3),
('santiago.mercado@correo.test', 'Música de gaitas y tambores', 42, 5),
('fabian.acosta@correo.test', 'Música de gaitas y tambores', 42, 2),
('valentina.hernandez@correo.test', 'Música de gaitas y tambores', 42, 4),
('kevin.romero@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -46, 2),
('oscar.ruiz@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -46, 2),
('sofia.olivera@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -46, 1),
('oscar.perez@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -46, 2),
('valentina.ortega@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -26, 1),
('jose.navarro@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -26, 1),
('andres.julio@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -26, 2),
('oscar.benitez@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -26, 1),
('diana.romero2@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', -26, 1),
('lina.sierra@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 13, 3),
('mariana.hernandez@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 13, 2),
('maria.paternina@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 35, 1),
('jose.arrieta@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 35, 1),
('andres.rivera@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 35, 4),
('laura.padilla@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 42, 1),
('jose.ruiz@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 42, 2),
('santiago.contreras@correo.test', 'Ruta de la Gaita y la Hamaca en Morroa', 42, 3),
('oscar.benitez2@correo.test', 'Trenzado de caña flecha', -55, 1),
('juan.romero@correo.test', 'Trenzado de caña flecha', -55, 4),
('andres.gomez@correo.test', 'Trenzado de caña flecha', -55, 2),
('sofia.diaz@correo.test', 'Trenzado de caña flecha', -34, 3),
('ana.benitez@correo.test', 'Trenzado de caña flecha', -34, 2),
('carlos.tovar@correo.test', 'Trenzado de caña flecha', -34, 4),
('andres.gomez@correo.test', 'Trenzado de caña flecha', 13, 2),
('santiago.salgado@correo.test', 'Trenzado de caña flecha', 13, 2),
('oscar.diaz@correo.test', 'Trenzado de caña flecha', 13, 2),
('diana.romero2@correo.test', 'Trenzado de caña flecha', 15, 3),
('oscar.barrios@correo.test', 'Trenzado de caña flecha', 15, 1),
('mariana.martinez@correo.test', 'Trenzado de caña flecha', 15, 2),
('oscar.benitez2@correo.test', 'Trenzado de caña flecha', 42, 1),
('diana.julio@correo.test', 'Trenzado de caña flecha', 42, 4),
('paola.padilla@correo.test', 'Mochilas y tejidos sabaneros', -34, 1),
('sebastian.arrieta@correo.test', 'Mochilas y tejidos sabaneros', -34, 1),
('laura.tovar@correo.test', 'Mochilas y tejidos sabaneros', -34, 2),
('laura.martinez@correo.test', 'Mochilas y tejidos sabaneros', -28, 1),
('carlos.tovar@correo.test', 'Mochilas y tejidos sabaneros', -28, 1),
('jorge.navarro@correo.test', 'Mochilas y tejidos sabaneros', -28, 2),
('jose.montes@correo.test', 'Mochilas y tejidos sabaneros', 14, 1),
('kevin.cardenas@correo.test', 'Mochilas y tejidos sabaneros', 14, 4),
('sofia.gomez@correo.test', 'Mochilas y tejidos sabaneros', 29, 2),
('kevin.cardenas@correo.test', 'Mochilas y tejidos sabaneros', 29, 1),
('yuliana.benitez2@correo.test', 'Mochilas y tejidos sabaneros', 38, 2),
('isabella.martinez@correo.test', 'Mochilas y tejidos sabaneros', 38, 1),
('yuliana.atencia@correo.test', 'Mochilas y tejidos sabaneros', 38, 2),
('juan.romero@correo.test', 'Kayak en el Golfo de Morrosquillo', -60, 3),
('ana.rodriguez@correo.test', 'Kayak en el Golfo de Morrosquillo', -60, 1),
('karen.tovar@correo.test', 'Kayak en el Golfo de Morrosquillo', -60, 5),
('diana.gomez@correo.test', 'Kayak en el Golfo de Morrosquillo', -60, 3),
('valentina.ortega2@correo.test', 'Kayak en el Golfo de Morrosquillo', -36, 4),
('maria.paternina@correo.test', 'Kayak en el Golfo de Morrosquillo', -36, 2),
('paola.navarro2@correo.test', 'Kayak en el Golfo de Morrosquillo', -36, 3),
('camila.diaz@correo.test', 'Kayak en el Golfo de Morrosquillo', -36, 2),
('yuliana.tovar@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 1),
('mariana.arrieta@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 2),
('rafael.ortega@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 1),
('yuliana.rivera@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 2),
('laura.acosta@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 1),
('miguel.salgado@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 1),
('laura.barrios@correo.test', 'Kayak en el Golfo de Morrosquillo', 9, 2),
('oscar.montes@correo.test', 'Kayak en el Golfo de Morrosquillo', 11, 1),
('maria.mercado@correo.test', 'Kayak en el Golfo de Morrosquillo', 11, 1),
('oscar.perez@correo.test', 'Kayak en el Golfo de Morrosquillo', 11, 4),
('natalia.barrios@correo.test', 'Kayak en el Golfo de Morrosquillo', 11, 4),
('carlos.atencia@correo.test', 'Kayak en el Golfo de Morrosquillo', 29, 2),
('mariana.mercado@correo.test', 'Kayak en el Golfo de Morrosquillo', 29, 2),
('laura.padilla@correo.test', 'Kayak en el Golfo de Morrosquillo', 29, 4),
('camila.sierra@correo.test', 'Kayak en el Golfo de Morrosquillo', 29, 2),
('carlos.ruiz@correo.test', 'Paseo en lancha a Isla Múcura', -38, 2),
('valentina.julio@correo.test', 'Paseo en lancha a Isla Múcura', -38, 3),
('kevin.atencia@correo.test', 'Paseo en lancha a Isla Múcura', -38, 2),
('andres.julio@correo.test', 'Paseo en lancha a Isla Múcura', -38, 2),
('jose.vergara@correo.test', 'Paseo en lancha a Isla Múcura', -38, 1),
('luis.benitez@correo.test', 'Paseo en lancha a Isla Múcura', -7, 1),
('jorge.olivera@correo.test', 'Paseo en lancha a Isla Múcura', -7, 1),
('rafael.julio@correo.test', 'Paseo en lancha a Isla Múcura', -7, 1),
('jose.julio@correo.test', 'Paseo en lancha a Isla Múcura', -7, 2),
('laura.salgado@correo.test', 'Paseo en lancha a Isla Múcura', -7, 4),
('diana.romero2@correo.test', 'Paseo en lancha a Isla Múcura', -7, 1),
('sofia.arrieta@correo.test', 'Paseo en lancha a Isla Múcura', 6, 2),
('kevin.navarro@correo.test', 'Paseo en lancha a Isla Múcura', 6, 2),
('isabella.rivera@correo.test', 'Paseo en lancha a Isla Múcura', 6, 2),
('alejandro.ruiz@correo.test', 'Paseo en lancha a Isla Múcura', 6, 1),
('lina.benitez@correo.test', 'Paseo en lancha a Isla Múcura', 6, 2),
('paola.ruiz@correo.test', 'Paseo en lancha a Isla Múcura', 6, 4),
('miguel.perez@correo.test', 'Paseo en lancha a Isla Múcura', 27, 1),
('jose.paternina@correo.test', 'Paseo en lancha a Isla Múcura', 27, 2),
('andres.vergara@correo.test', 'Paseo en lancha a Isla Múcura', 27, 4),
('rafael.ortega@correo.test', 'Paseo en lancha a Isla Múcura', 27, 4),
('yuliana.cardenas@correo.test', 'Paseo en lancha a Isla Múcura', 37, 4),
('camila.olivera@correo.test', 'Paseo en lancha a Isla Múcura', 37, 2),
('lina.ruiz@correo.test', 'Paseo en lancha a Isla Múcura', 37, 2),
('jorge.hernandez@correo.test', 'Paseo en lancha a Isla Múcura', 37, 2),
('diana.romero2@correo.test', 'Cabalgata por la sabana', -40, 3),
('sebastian.mercado@correo.test', 'Cabalgata por la sabana', -17, 1),
('natalia.castro@correo.test', 'Cabalgata por la sabana', -17, 2),
('carlos.navarro@correo.test', 'Cabalgata por la sabana', 24, 4),
('kevin.romero@correo.test', 'Cabalgata por la sabana', 25, 4),
('diana.rivera@correo.test', 'Cabalgata por la sabana', 33, 2),
('mariana.hernandez@correo.test', 'Snorkel en Coveñas', -29, 2),
('laura.martinez@correo.test', 'Snorkel en Coveñas', -29, 1),
('valentina.navarro@correo.test', 'Snorkel en Coveñas', -29, 2),
('diana.julio@correo.test', 'Snorkel en Coveñas', -29, 1),
('laura.mercado@correo.test', 'Snorkel en Coveñas', -29, 3);

-- Se resuelven los id antes de insertar: MySQL no permite que el
-- INSERT lea programacion mientras el trigger la actualiza.
UPDATE tmp_reservas t
JOIN visitantes v ON v.email = t.email
JOIN experiencias e ON e.titulo = t.titulo
JOIN programacion p ON p.id_experiencia = e.id_experiencia
                   AND p.fecha_actividad = DATE_ADD(CURDATE(), INTERVAL t.dias DAY)
SET t.id_visitante = v.id_visitante,
    t.id_programacion = p.id_programacion,
    t.monto = fn_calcular_total_reserva(e.precio_base_cop, t.personas),
    -- la reserva se hace entre 3 y 20 días antes de la actividad
    t.fecha_reserva = DATE_SUB(TIMESTAMP(p.fecha_actividad, '10:00:00'),
                               INTERVAL (3 + MOD(v.id_visitante, 18)) DAY);

INSERT INTO reservas (id_visitante, id_programacion, cantidad_personas,
                      monto_total_cop, estado_reserva, fecha_reserva)
SELECT t.id_visitante, t.id_programacion, t.personas,
       t.monto, 'CONFIRMADA', t.fecha_reserva
FROM tmp_reservas t
WHERE t.id_programacion IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM reservas r
                  WHERE r.id_visitante = t.id_visitante
                    AND r.id_programacion = t.id_programacion)
ORDER BY t.fecha_reserva, t.id_visitante;

DROP TEMPORARY TABLE tmp_reservas;

-- 3.9 Estados de las reservas para tener datos variados.
-- Primero se guardan los id en una tabla temporal: MySQL no permite que
-- un UPDATE haga JOIN con programacion si el trigger también la modifica.
CREATE TEMPORARY TABLE tmp_ids (id_reserva INT PRIMARY KEY, nuevo_estado VARCHAR(10));

-- a) Actividades pasadas: reservas COMPLETADA (excepto la ruta demo).
INSERT INTO tmp_ids
SELECT r.id_reserva, 'COMPLETADA'
FROM reservas r
JOIN programacion p ON p.id_programacion = r.id_programacion
JOIN experiencias e ON e.id_experiencia = p.id_experiencia
WHERE p.fecha_actividad < CURDATE()
  AND r.estado_reserva = 'CONFIRMADA'
  AND e.titulo <> 'Ruta de sabores tradicionales';

-- b) Algunas reservas futuras quedan PENDIENTE (sin pago aún).
INSERT INTO tmp_ids
SELECT r.id_reserva, 'PENDIENTE'
FROM reservas r
JOIN programacion p ON p.id_programacion = r.id_programacion
JOIN visitantes v ON v.id_visitante = r.id_visitante
WHERE p.fecha_actividad >= CURDATE()
  AND r.estado_reserva = 'CONFIRMADA'
  AND v.email LIKE '%@correo.test'
  AND MOD(r.id_reserva, 5) = 0;

-- c) Algunas reservas futuras se cancelan.
INSERT IGNORE INTO tmp_ids
SELECT r.id_reserva, 'CANCELADA'
FROM reservas r
JOIN programacion p ON p.id_programacion = r.id_programacion
JOIN visitantes v ON v.id_visitante = r.id_visitante
WHERE p.fecha_actividad >= CURDATE()
  AND r.estado_reserva = 'CONFIRMADA'
  AND v.email LIKE '%@correo.test'
  AND MOD(r.id_reserva, 7) = 0;

-- Aplicar los estados. Al cancelar, el trigger trg_reservas_devolver_cupos
-- devuelve los cupos a la programación automáticamente.
UPDATE reservas r
JOIN tmp_ids t ON t.id_reserva = r.id_reserva
SET r.estado_reserva = t.nuevo_estado,
    r.fecha_cancelacion = IF(t.nuevo_estado = 'CANCELADA',
                             DATE_ADD(r.fecha_reserva, INTERVAL 1 DAY), NULL);

DROP TEMPORARY TABLE tmp_ids;

-- Las programaciones con fecha pasada quedan FINALIZADA.
UPDATE programacion
SET estado_programacion = 'FINALIZADA'
WHERE fecha_actividad < CURDATE()
  AND estado_programacion = 'PROGRAMADA';

-- Una programación futura cancelada por el operador (la más lejana
-- del kayak, cancelando antes sus reservas activas para devolver cupos).
CREATE TEMPORARY TABLE tmp_prog_cancelar AS
SELECT p.id_programacion
FROM programacion p
JOIN experiencias e ON e.id_experiencia = p.id_experiencia
WHERE e.titulo = 'Kayak en el Golfo de Morrosquillo'
  AND p.fecha_actividad >= CURDATE()
ORDER BY p.fecha_actividad DESC
LIMIT 1;

UPDATE reservas
SET estado_reserva = 'CANCELADA',
    fecha_cancelacion = DATE_ADD(fecha_reserva, INTERVAL 1 DAY)
WHERE id_programacion IN (SELECT id_programacion FROM tmp_prog_cancelar)
  AND estado_reserva <> 'CANCELADA';

UPDATE programacion
SET estado_programacion = 'CANCELADA'
WHERE id_programacion IN (SELECT id_programacion FROM tmp_prog_cancelar);

DROP TEMPORARY TABLE tmp_prog_cancelar;

-- 3.10 Pagos
-- Reservas confirmadas o completadas: pago aprobado por el total.
INSERT INTO pagos (id_reserva, monto_cop, metodo_pago, estado_pago,
                   referencia_transaccion, fecha_pago)
SELECT r.id_reserva, r.monto_total_cop,
       ELT(MOD(r.id_reserva, 4) + 1,
           'EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO'),
       'APROBADO',
       CONCAT('REF-', LPAD(r.id_reserva, 6, '0')),
       DATE_ADD(r.fecha_reserva, INTERVAL 2 HOUR)
FROM reservas r
WHERE r.estado_reserva IN ('CONFIRMADA', 'COMPLETADA')
  AND NOT EXISTS (SELECT 1 FROM pagos pg WHERE pg.id_reserva = r.id_reserva);

-- Reservas pendientes: pago en proceso.
INSERT INTO pagos (id_reserva, monto_cop, metodo_pago, estado_pago,
                   referencia_transaccion, fecha_pago)
SELECT r.id_reserva, r.monto_total_cop, 'TRANSFERENCIA', 'PENDIENTE',
       CONCAT('REF-', LPAD(r.id_reserva, 6, '0')),
       DATE_ADD(r.fecha_reserva, INTERVAL 1 HOUR)
FROM reservas r
WHERE r.estado_reserva = 'PENDIENTE'
  AND NOT EXISTS (SELECT 1 FROM pagos pg WHERE pg.id_reserva = r.id_reserva);

-- Reservas canceladas: el pago se reembolsó.
INSERT INTO pagos (id_reserva, monto_cop, metodo_pago, estado_pago,
                   referencia_transaccion, fecha_pago)
SELECT r.id_reserva, r.monto_total_cop, 'TARJETA', 'REEMBOLSADO',
       CONCAT('REF-', LPAD(r.id_reserva, 6, '0')),
       DATE_ADD(r.fecha_reserva, INTERVAL 2 HOUR)
FROM reservas r
WHERE r.estado_reserva = 'CANCELADA'
  AND NOT EXISTS (SELECT 1 FROM pagos pg WHERE pg.id_reserva = r.id_reserva);

-- Algunos intentos rechazados antes del pago aprobado.
INSERT INTO pagos (id_reserva, monto_cop, metodo_pago, estado_pago,
                   referencia_transaccion, fecha_pago)
SELECT r.id_reserva, r.monto_total_cop, 'TARJETA', 'RECHAZADO',
       CONCAT('REF-', LPAD(r.id_reserva, 6, '0'), '-R'),
       DATE_ADD(r.fecha_reserva, INTERVAL 1 HOUR)
FROM reservas r
JOIN visitantes v ON v.id_visitante = r.id_visitante
WHERE r.estado_reserva IN ('CONFIRMADA', 'COMPLETADA')
  AND v.email LIKE '%@correo.test'
  AND MOD(r.id_reserva, 9) = 0
  AND NOT EXISTS (SELECT 1 FROM pagos pg
                  WHERE pg.id_reserva = r.id_reserva
                    AND pg.estado_pago = 'RECHAZADO');

-- 3.11 Valoraciones de las experiencias ya realizadas (reservas COMPLETADA).
INSERT INTO valoraciones (id_reserva, puntuacion_estrellas, comentario,
                          fecha_valoracion)
SELECT r.id_reserva,
       ELT(MOD(r.id_reserva, 10) + 1, 5, 4, 5, 3, 5, 4, 5, 2, 4, 5),
       ELT(MOD(r.id_reserva, 8) + 1,
           'Excelente experiencia, muy recomendada.',
           'El guía fue muy amable y conocía la historia.',
           'La comida estuvo deliciosa.',
           'Buena actividad, pero empezó un poco tarde.',
           'Volvería con mi familia.',
           'Paisajes hermosos y buena organización.',
           'Precio justo por lo que se ofrece.',
           'Faltó información sobre el punto de encuentro.'),
       DATE_ADD(TIMESTAMP(p.fecha_actividad, '20:00:00'),
                INTERVAL MOD(r.id_reserva, 3) DAY)
FROM reservas r
JOIN programacion p ON p.id_programacion = r.id_programacion
WHERE r.estado_reserva = 'COMPLETADA'
  AND MOD(r.id_reserva, 4) <> 0
  AND NOT EXISTS (SELECT 1 FROM valoraciones va
                  WHERE va.id_reserva = r.id_reserva);

-- FIN DE LA CARGA DE DATOS

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
UNION ALL SELECT 'valoraciones', COUNT(*) FROM valoraciones;


SET SQL_SAFE_UPDATES = 1;

-- FIN DEL ARCHIVO 1
