-- =====================================================================
-- 03. OBJETOS PROGRAMABLES EN PL/pgSQL
-- Funciones, triggers, procedimientos y vistas traducidos desde MySQL.
-- Se ejecuta DESPUÉS de cargar los datos (02).
--
-- Diferencias clave frente a MySQL:
--   * No existe DELIMITER: el cuerpo va entre $$ ... $$ con LANGUAGE plpgsql.
--   * Un trigger son dos objetos: una FUNCIÓN que RETURNS trigger y el
--     CREATE TRIGGER ... EXECUTE FUNCTION que la llama.
--   * SIGNAL SQLSTATE '45000' -> RAISE EXCEPTION ... USING ERRCODE.
--   * DECLARE EXIT HANDLER -> bloque BEGIN ... EXCEPTION WHEN ... END.
--   * Variables de sesión @var -> set_config / current_setting.
--   * Un procedimiento se ejecuta dentro de la transacción del CALL: si
--     falla, PostgreSQL deshace todo automáticamente.
-- =====================================================================

-- ---------------------------------------------------------------------
-- FUNCIONES
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_total_reserva(p_precio NUMERIC, p_personas INTEGER)
RETURNS NUMERIC(12,2)
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_precio, 0) * COALESCE(p_personas, 0);
$$;

CREATE OR REPLACE FUNCTION fn_calcular_impuesto(p_valor NUMERIC, p_porcentaje NUMERIC)
RETURNS NUMERIC(12,2)
LANGUAGE sql IMMUTABLE AS $$
  SELECT ROUND(COALESCE(p_valor, 0) * COALESCE(p_porcentaje, 0) / 100, 2);
$$;

-- RETO FUNCIÓN A
CREATE OR REPLACE FUNCTION fn_consultar_cupos_disponibles(p_id_programacion INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_cupos INTEGER;
BEGIN
  SELECT cupos_disponibles INTO v_cupos
  FROM programacion
  WHERE id_programacion = p_id_programacion
    AND estado_programacion = 'PROGRAMADA';
  RETURN COALESCE(v_cupos, 0);
END;
$$;

-- RETO FUNCIÓN B
CREATE OR REPLACE FUNCTION fn_promedio_satisfaccion_operador(p_id_operador INTEGER)
RETURNS NUMERIC(3,2)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_promedio NUMERIC(3,2);
BEGIN
  SELECT ROUND(AVG(va.puntuacion_estrellas), 2) INTO v_promedio
  FROM experiencias e
  JOIN programacion p  ON p.id_experiencia = e.id_experiencia
  JOIN reservas r      ON r.id_programacion = p.id_programacion
  JOIN valoraciones va ON va.id_reserva = r.id_reserva
  WHERE e.id_operador = p_id_operador;
  RETURN COALESCE(v_promedio, 0.00);
END;
$$;

-- RETO FUNCIÓN C: aquí sí existe EXCEPTION WHEN OTHERS, como pide el
-- enunciado. SELECT ... INTO STRICT lanza NO_DATA_FOUND si no hay fila.
CREATE OR REPLACE FUNCTION fn_evaluar_reembolso_cancelacion(p_id_reserva INTEGER)
RETURNS VARCHAR(20)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_inicio TIMESTAMP;
  v_horas  NUMERIC;
BEGIN
  SELECT p.fecha_actividad + p.hora_inicio INTO STRICT v_inicio
  FROM reservas r
  JOIN programacion p ON p.id_programacion = r.id_programacion
  WHERE r.id_reserva = p_id_reserva;

  v_horas := EXTRACT(EPOCH FROM (v_inicio - LOCALTIMESTAMP)) / 3600;
  IF v_horas < 48 THEN
    RETURN 'SIN_REEMBOLSO';
  END IF;
  RETURN 'REEMBOLSO_TOTAL';
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'RESERVA_INVALIDA';
END;
$$;

-- ---------------------------------------------------------------------
-- TRIGGERS
-- ---------------------------------------------------------------------

-- RETO DDL A: cupos_disponibles = cupos_totales si no se envía.
CREATE OR REPLACE FUNCTION tf_programacion_cupos_por_defecto() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.cupos_disponibles IS NULL THEN
    NEW.cupos_disponibles := NEW.cupos_totales;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_programacion_cupos_por_defecto
BEFORE INSERT ON programacion
FOR EACH ROW EXECUTE FUNCTION tf_programacion_cupos_por_defecto();

-- Validar disponibilidad antes de insertar una reserva.
CREATE OR REPLACE FUNCTION tf_reservas_validar_cupos() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_disponibles INTEGER;
  v_estado      VARCHAR(15);
BEGIN
  IF NEW.estado_reserva <> 'CANCELADA' THEN
    SELECT cupos_disponibles, estado_programacion
      INTO v_disponibles, v_estado
    FROM programacion
    WHERE id_programacion = NEW.id_programacion
    FOR UPDATE;

    IF v_estado IS DISTINCT FROM 'PROGRAMADA' THEN
      RAISE EXCEPTION 'La programación no está disponible' USING ERRCODE = 'P0001';
    END IF;
    IF v_disponibles < NEW.cantidad_personas THEN
      RAISE EXCEPTION 'No hay suficientes cupos disponibles' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_reservas_validar_cupos
BEFORE INSERT ON reservas
FOR EACH ROW EXECUTE FUNCTION tf_reservas_validar_cupos();

-- RETO TRIGGER A. La "variable de sesión" de MySQL (@cupos_por_procedimiento)
-- se reemplaza por un parámetro de configuración local a la transacción.
CREATE OR REPLACE FUNCTION tf_actualizar_cupos_despues_reserva() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.estado_reserva <> 'CANCELADA'
     AND COALESCE(current_setting('app.cupos_por_procedimiento', true), '0') <> '1' THEN
    UPDATE programacion
    SET cupos_disponibles = cupos_disponibles - NEW.cantidad_personas
    WHERE id_programacion = NEW.id_programacion;
  END IF;
  RETURN NULL;   -- en un trigger AFTER el valor de retorno se ignora
END;
$$;
CREATE TRIGGER trg_actualizar_cupos_despues_reserva
AFTER INSERT ON reservas
FOR EACH ROW EXECUTE FUNCTION tf_actualizar_cupos_despues_reserva();

-- Devolver cupos al cancelar y validarlos al reactivar.
CREATE OR REPLACE FUNCTION tf_reservas_devolver_cupos() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_filas INTEGER;
BEGIN
  IF OLD.estado_reserva <> 'CANCELADA' AND NEW.estado_reserva = 'CANCELADA' THEN
    UPDATE programacion
    SET cupos_disponibles = LEAST(cupos_totales, cupos_disponibles + OLD.cantidad_personas)
    WHERE id_programacion = OLD.id_programacion;
  END IF;

  IF OLD.estado_reserva = 'CANCELADA' AND NEW.estado_reserva <> 'CANCELADA' THEN
    UPDATE programacion
    SET cupos_disponibles = cupos_disponibles - NEW.cantidad_personas
    WHERE id_programacion = NEW.id_programacion
      AND estado_programacion = 'PROGRAMADA'
      AND cupos_disponibles >= NEW.cantidad_personas;
    GET DIAGNOSTICS v_filas = ROW_COUNT;     -- equivale a ROW_COUNT() de MySQL
    IF v_filas = 0 THEN
      RAISE EXCEPTION 'No hay cupos para reactivar la reserva' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_reservas_devolver_cupos
AFTER UPDATE OF estado_reserva ON reservas
FOR EACH ROW EXECUTE FUNCTION tf_reservas_devolver_cupos();

-- RETO TRIGGER B
CREATE OR REPLACE FUNCTION tf_prevenir_sobreventa_cupos() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.cupos_disponibles < 0 THEN
    RAISE EXCEPTION 'Sobreventa bloqueada: los cupos disponibles no pueden ser negativos'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_prevenir_sobreventa_cupos
BEFORE UPDATE ON programacion
FOR EACH ROW EXECUTE FUNCTION tf_prevenir_sobreventa_cupos();

-- RETO TRIGGER C. En PostgreSQL la condición se escribe en la cláusula
-- WHEN del trigger, así la función solo se ejecuta cuando hace falta.
CREATE OR REPLACE FUNCTION tf_auditar_cancelacion_reserva() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auditoria_cancelaciones
    (id_reserva, fecha_cancelacion, usuario_bd, monto_perdido_cop, motivo)
  VALUES
    (NEW.id_reserva, COALESCE(NEW.fecha_cancelacion, LOCALTIMESTAMP), session_user,
     NEW.monto_total_cop,
     'Cancelación de reserva. Política aplicada: ' || fn_evaluar_reembolso_cancelacion(NEW.id_reserva));
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_auditar_cancelacion_reserva
AFTER UPDATE OF estado_reserva ON reservas
FOR EACH ROW
WHEN (OLD.estado_reserva <> 'CANCELADA' AND NEW.estado_reserva = 'CANCELADA')
EXECUTE FUNCTION tf_auditar_cancelacion_reserva();

-- REGLA DE NEGOCIO 7: solo se valoran experiencias realizadas.
CREATE OR REPLACE FUNCTION tf_validar_valoracion() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_estado VARCHAR(10);
BEGIN
  SELECT estado_reserva INTO v_estado FROM reservas WHERE id_reserva = NEW.id_reserva;
  IF v_estado IS DISTINCT FROM 'COMPLETADA' THEN
    RAISE EXCEPTION 'Solo se puede valorar una experiencia ya realizada (reserva COMPLETADA)'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_validar_valoracion
BEFORE INSERT ON valoraciones
FOR EACH ROW EXECUTE FUNCTION tf_validar_valoracion();

-- ---------------------------------------------------------------------
-- PROCEDIMIENTOS
-- ---------------------------------------------------------------------

-- RETO PROCEDIMIENTO A
CREATE OR REPLACE PROCEDURE sp_registrar_experiencia(
  p_id_operador INTEGER, p_id_categoria INTEGER, p_titulo VARCHAR,
  p_municipio VARCHAR, p_duracion NUMERIC, p_precio NUMERIC, p_capacidad_max INTEGER,
  INOUT p_id_experiencia INTEGER DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
  v_id_municipio INTEGER;
BEGIN
  IF p_precio IS NULL OR p_precio <= 0 THEN
    RAISE EXCEPTION 'El precio debe ser mayor que cero' USING ERRCODE = 'P0001';
  END IF;
  IF p_duracion IS NULL OR p_duracion <= 0 THEN
    RAISE EXCEPTION 'La duración debe ser mayor que cero' USING ERRCODE = 'P0001';
  END IF;
  IF p_capacidad_max IS NULL OR p_capacidad_max <= 0 THEN
    RAISE EXCEPTION 'La capacidad máxima debe ser mayor que cero' USING ERRCODE = 'P0001';
  END IF;
  IF p_titulo IS NULL OR TRIM(p_titulo) = '' THEN
    RAISE EXCEPTION 'El título es obligatorio' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM operadores WHERE id_operador = p_id_operador AND activo) THEN
    RAISE EXCEPTION 'El operador no existe o está inactivo' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_id_categoria) THEN
    RAISE EXCEPTION 'La categoría no existe' USING ERRCODE = 'P0001';
  END IF;
  SELECT id_municipio INTO v_id_municipio FROM municipios WHERE nombre = p_municipio;
  IF v_id_municipio IS NULL THEN
    RAISE EXCEPTION 'El municipio no existe' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO experiencias (id_operador, id_categoria, id_municipio, titulo, descripcion,
                            duracion_horas, precio_base_cop, capacidad_max, estado_experiencia)
  VALUES (p_id_operador, p_id_categoria, v_id_municipio, p_titulo,
          'Experiencia registrada en ' || p_municipio || '.',
          p_duracion, p_precio, p_capacidad_max, 'BORRADOR')
  RETURNING id_experiencia INTO p_id_experiencia;   -- reemplaza a LAST_INSERT_ID()
END;
$$;

-- RETO PROCEDIMIENTO B
CREATE OR REPLACE PROCEDURE sp_procesar_reserva(
  p_id_visitante INTEGER, p_id_programacion INTEGER, p_cantidad_personas INTEGER,
  INOUT p_id_reserva INTEGER DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
  v_cupos  INTEGER;
  v_precio NUMERIC(12,2);
BEGIN
  IF p_cantidad_personas IS NULL OR p_cantidad_personas <= 0 THEN
    RAISE EXCEPTION 'La cantidad de personas debe ser mayor que cero' USING ERRCODE = 'P0001';
  END IF;

  SELECT p.cupos_disponibles, e.precio_base_cop INTO v_cupos, v_precio
  FROM programacion p
  JOIN experiencias e ON e.id_experiencia = p.id_experiencia
  WHERE p.id_programacion = p_id_programacion
    AND p.estado_programacion = 'PROGRAMADA'
  FOR UPDATE OF p;

  IF v_cupos IS NULL THEN
    RAISE EXCEPTION 'La programación no existe o no está disponible' USING ERRCODE = 'P0001';
  END IF;
  IF p_cantidad_personas > v_cupos THEN
    RAISE EXCEPTION 'La cantidad solicitada supera los cupos disponibles' USING ERRCODE = 'P0001';
  END IF;

  PERFORM set_config('app.cupos_por_procedimiento', '1', true);  -- solo esta transacción
  INSERT INTO reservas (id_visitante, id_programacion, cantidad_personas, monto_total_cop, estado_reserva)
  VALUES (p_id_visitante, p_id_programacion, p_cantidad_personas,
          fn_calcular_total_reserva(v_precio, p_cantidad_personas), 'CONFIRMADA')
  RETURNING id_reserva INTO p_id_reserva;

  UPDATE programacion
  SET cupos_disponibles = cupos_disponibles - p_cantidad_personas
  WHERE id_programacion = p_id_programacion;
  PERFORM set_config('app.cupos_por_procedimiento', '0', true);
END;
$$;

-- RETO PROCEDIMIENTO C: 0 = éxito, -1 = cupos insuficientes,
-- -2 = error en el pago, -3 = error inesperado (EXCEPTION WHEN OTHERS).
CREATE OR REPLACE PROCEDURE sp_confirmar_reserva_integral(
  p_id_visitante INTEGER, p_id_programacion INTEGER, p_cantidad_personas INTEGER,
  p_metodo_pago VARCHAR, p_referencia VARCHAR,
  INOUT p_codigo_respuesta INTEGER DEFAULT NULL,
  INOUT p_id_reserva INTEGER DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
  v_cupos  INTEGER;
  v_precio NUMERIC(12,2);
  v_monto  NUMERIC(12,2);
BEGIN
  p_id_reserva := NULL;
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM visitantes WHERE id_visitante = p_id_visitante) THEN
      p_codigo_respuesta := -3;
      RETURN;
    END IF;

    SELECT p.cupos_disponibles, e.precio_base_cop INTO v_cupos, v_precio
    FROM programacion p
    JOIN experiencias e ON e.id_experiencia = p.id_experiencia
    WHERE p.id_programacion = p_id_programacion
      AND p.estado_programacion = 'PROGRAMADA'
    FOR UPDATE OF p;

    IF v_cupos IS NULL OR p_cantidad_personas IS NULL
       OR p_cantidad_personas <= 0 OR p_cantidad_personas > v_cupos THEN
      p_codigo_respuesta := -1;
      RETURN;
    END IF;

    IF p_metodo_pago IS NULL
       OR p_metodo_pago NOT IN ('EFECTIVO','TRANSFERENCIA','TARJETA','OTRO') THEN
      p_codigo_respuesta := -2;
      RETURN;
    END IF;

    v_monto := fn_calcular_total_reserva(v_precio, p_cantidad_personas);
    PERFORM set_config('app.cupos_por_procedimiento', '1', true);

    INSERT INTO reservas (id_visitante, id_programacion, cantidad_personas, monto_total_cop, estado_reserva)
    VALUES (p_id_visitante, p_id_programacion, p_cantidad_personas, v_monto, 'CONFIRMADA')
    RETURNING id_reserva INTO p_id_reserva;

    INSERT INTO pagos (id_reserva, monto_cop, metodo_pago, estado_pago, referencia_transaccion)
    VALUES (p_id_reserva, v_monto, p_metodo_pago, 'APROBADO', p_referencia);

    UPDATE programacion
    SET cupos_disponibles = cupos_disponibles - p_cantidad_personas
    WHERE id_programacion = p_id_programacion;

    PERFORM set_config('app.cupos_por_procedimiento', '0', true);
    p_codigo_respuesta := 0;
  EXCEPTION
    WHEN OTHERS THEN
      -- El bloque se deshace solo (subtransacción): equivale al ROLLBACK.
      p_codigo_respuesta := -3;
      p_id_reserva := NULL;
  END;
END;
$$;

-- Cancelar una reserva (los triggers devuelven cupos y auditan).
CREATE OR REPLACE PROCEDURE sp_cancelar_reserva(p_id_reserva INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
  v_estado VARCHAR(10);
BEGIN
  SELECT estado_reserva INTO v_estado FROM reservas WHERE id_reserva = p_id_reserva FOR UPDATE;
  IF v_estado IS NULL THEN
    RAISE EXCEPTION 'La reserva no existe' USING ERRCODE = 'P0001';
  END IF;
  IF v_estado = 'CANCELADA' THEN
    RAISE EXCEPTION 'La reserva ya se encuentra cancelada' USING ERRCODE = 'P0001';
  END IF;
  UPDATE reservas
  SET estado_reserva = 'CANCELADA', fecha_cancelacion = LOCALTIMESTAMP
  WHERE id_reserva = p_id_reserva;
END;
$$;

-- Registrar un pago sobre una reserva existente.
CREATE OR REPLACE PROCEDURE sp_registrar_pago(
  p_id_reserva INTEGER, p_monto NUMERIC, p_metodo VARCHAR, p_referencia VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE
  v_total  NUMERIC(12,2);
  v_estado VARCHAR(10);
BEGIN
  SELECT monto_total_cop, estado_reserva INTO v_total, v_estado
  FROM reservas WHERE id_reserva = p_id_reserva FOR UPDATE;
  IF v_estado = 'CANCELADA' THEN
    RAISE EXCEPTION 'No se puede pagar una reserva cancelada' USING ERRCODE = 'P0001';
  END IF;
  IF p_monto <= 0 OR p_monto > v_total THEN
    RAISE EXCEPTION 'El monto del pago no es válido' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO pagos (id_reserva, monto_cop, metodo_pago, estado_pago, referencia_transaccion)
  VALUES (p_id_reserva, p_monto, p_metodo, 'APROBADO', p_referencia);
END;
$$;

-- ---------------------------------------------------------------------
-- VISTAS
-- Nota: en PostgreSQL entero / entero da un entero (30 / 40 = 0), por eso
-- los porcentajes convierten a NUMERIC antes de dividir.
-- ---------------------------------------------------------------------

-- RETO VISTA A
CREATE OR REPLACE VIEW v_experiencias_disponibles_web AS
SELECT p.id_programacion,
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

-- RETO VISTA B
CREATE OR REPLACE VIEW v_resumen_operaciones_operador AS
SELECT o.nombre_comercial AS nombre_comercial_operador,
       o.telefono,
       e.titulo           AS titulo_experiencia,
       p.fecha_actividad,
       p.cupos_totales,
       COALESCE(SUM(r.cantidad_personas) FILTER (WHERE r.estado_reserva <> 'CANCELADA'), 0) AS cupos_reservados,
       ROUND(COALESCE(SUM(r.cantidad_personas) FILTER (WHERE r.estado_reserva <> 'CANCELADA'), 0)
             * 100.0 / p.cupos_totales, 2) AS porcentaje_ocupacion
FROM operadores o
JOIN experiencias e  ON e.id_operador = o.id_operador
JOIN programacion p  ON p.id_experiencia = e.id_experiencia
LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
GROUP BY o.id_operador, p.id_programacion, e.titulo;

-- RETO VISTA C
CREATE OR REPLACE VIEW v_kpi_desempeno_experiencias AS
WITH ocupacion AS (
  SELECT p.id_programacion, p.id_experiencia,
         COALESCE(SUM(r.cantidad_personas) FILTER (WHERE r.estado_reserva <> 'CANCELADA'), 0)
           * 100.0 / p.cupos_totales AS ocupacion
  FROM programacion p
  LEFT JOIN reservas r ON r.id_programacion = p.id_programacion
  WHERE p.estado_programacion <> 'CANCELADA'
  GROUP BY p.id_programacion
), recaudo AS (
  SELECT p.id_experiencia, SUM(pg.monto_cop) AS recaudo
  FROM programacion p
  JOIN reservas r ON r.id_programacion = p.id_programacion
  JOIN pagos pg   ON pg.id_reserva = r.id_reserva
  WHERE pg.estado_pago = 'APROBADO'
  GROUP BY p.id_experiencia
)
SELECT e.id_experiencia,
       e.titulo,
       ROUND(AVG(oc.ocupacion), 2) AS tasa_ocupacion_promedio,
       COALESCE(MAX(rc.recaudo), 0) AS recaudo_total_cop,
       CASE WHEN AVG(oc.ocupacion) >= 85 THEN 'EXCELENTE'
            WHEN AVG(oc.ocupacion) >= 50 THEN 'ACEPTABLE'
            ELSE 'BAJO_RENDIMIENTO' END AS categoria_desempeno
FROM experiencias e
JOIN ocupacion oc     ON oc.id_experiencia = e.id_experiencia
LEFT JOIN recaudo rc  ON rc.id_experiencia = e.id_experiencia
GROUP BY e.id_experiencia;

-- FIN 03
