-- =====================================================================
-- 05. PRUEBAS DE VALIDACIÓN DESPUÉS DE LA MIGRACIÓN
-- Compara PostgreSQL contra los valores tomados del origen (MariaDB)
-- el día de la exportación. Cada prueba deja una fila en la tabla
-- temporal "validacion" con el valor esperado, el obtenido y si coincide.
-- Ejecutar inmediatamente después de 01-04.
-- =====================================================================

DROP TABLE IF EXISTS validacion;
CREATE TEMP TABLE validacion (
  n         SERIAL,
  grupo     TEXT,
  prueba    TEXT,
  esperado  TEXT,
  obtenido  TEXT,
  resultado TEXT GENERATED ALWAYS AS (CASE WHEN esperado = obtenido THEN 'OK' ELSE 'FALLA' END) STORED
);

-- ---------------------------------------------------------------------
-- 1. CONTEO DE REGISTROS (origen MariaDB -> destino PostgreSQL)
-- ---------------------------------------------------------------------
INSERT INTO validacion (grupo, prueba, esperado, obtenido)
SELECT '1. Conteo', t.tabla, t.origen::TEXT, t.destino::TEXT
FROM (VALUES
  ('roles', 3, (SELECT COUNT(*) FROM roles)),
  ('usuarios', 12, (SELECT COUNT(*) FROM usuarios)),
  ('municipios', 14, (SELECT COUNT(*) FROM municipios)),
  ('categorias', 6, (SELECT COUNT(*) FROM categorias)),
  ('tipos_recurso', 7, (SELECT COUNT(*) FROM tipos_recurso)),
  ('operadores', 11, (SELECT COUNT(*) FROM operadores)),
  ('recursos', 23, (SELECT COUNT(*) FROM recursos)),
  ('experiencias', 27, (SELECT COUNT(*) FROM experiencias)),
  ('experiencia_recurso', 33, (SELECT COUNT(*) FROM experiencia_recurso)),
  ('programacion', 126, (SELECT COUNT(*) FROM programacion)),
  ('visitantes', 421, (SELECT COUNT(*) FROM visitantes)),
  ('reservas', 713, (SELECT COUNT(*) FROM reservas)),
  ('pagos', 757, (SELECT COUNT(*) FROM pagos)),
  ('valoraciones', 162, (SELECT COUNT(*) FROM valoraciones)),
  ('auditoria_cancelaciones', 1, (SELECT COUNT(*) FROM auditoria_cancelaciones))
) AS t(tabla, origen, destino);

-- ---------------------------------------------------------------------
-- 2. INTEGRIDAD REFERENCIAL
-- ---------------------------------------------------------------------
INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES
('2. Integridad', 'Reservas sin visitante', '0',
 (SELECT COUNT(*) FROM reservas r WHERE NOT EXISTS (SELECT 1 FROM visitantes v WHERE v.id_visitante = r.id_visitante))::TEXT),
('2. Integridad', 'Reservas sin programación', '0',
 (SELECT COUNT(*) FROM reservas r WHERE NOT EXISTS (SELECT 1 FROM programacion p WHERE p.id_programacion = r.id_programacion))::TEXT),
('2. Integridad', 'Pagos sin reserva', '0',
 (SELECT COUNT(*) FROM pagos pg WHERE NOT EXISTS (SELECT 1 FROM reservas r WHERE r.id_reserva = pg.id_reserva))::TEXT),
('2. Integridad', 'Valoraciones sobre reservas no completadas', '0',
 (SELECT COUNT(*) FROM valoraciones va JOIN reservas r ON r.id_reserva = va.id_reserva WHERE r.estado_reserva <> 'COMPLETADA')::TEXT),
('2. Integridad', 'Llaves foráneas declaradas', '15',
 (SELECT COUNT(*) FROM information_schema.table_constraints
  WHERE constraint_type = 'FOREIGN KEY' AND table_schema = 'public')::TEXT),
('2. Integridad', 'Cupos inconsistentes con las reservas', '0',
 (SELECT COUNT(*) FROM programacion p
  WHERE p.cupos_disponibles <> p.cupos_totales - (
    SELECT COALESCE(SUM(r.cantidad_personas), 0) FROM reservas r
    WHERE r.id_programacion = p.id_programacion AND r.estado_reserva <> 'CANCELADA'))::TEXT);

-- La base rechaza una reserva con un visitante que no existe.
DO $$
BEGIN
  INSERT INTO reservas (id_visitante, id_programacion, cantidad_personas, monto_total_cop, estado_reserva)
  VALUES (999999, 1, 1, 50000, 'CANCELADA');
  INSERT INTO validacion (grupo, prueba, esperado, obtenido)
  VALUES ('2. Integridad', 'FK rechaza visitante inexistente', 'foreign_key_violation', 'se insertó');
EXCEPTION WHEN foreign_key_violation THEN
  INSERT INTO validacion (grupo, prueba, esperado, obtenido)
  VALUES ('2. Integridad', 'FK rechaza visitante inexistente', 'foreign_key_violation', 'foreign_key_violation');
END $$;

-- ---------------------------------------------------------------------
-- 3. CONSULTAS CRÍTICAS DEL NEGOCIO
-- ---------------------------------------------------------------------
INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES
('3. Consultas', 'Recaudo total (pagos APROBADO)', '75225000.00',
 (SELECT SUM(monto_cop) FROM pagos WHERE estado_pago = 'APROBADO')::TEXT),
('3. Consultas', 'Valor total reservado', '91935000.00',
 (SELECT SUM(monto_total_cop) FROM reservas)::TEXT),
('3. Consultas', 'KPI: experiencias EXCELENTE / ACEPTABLE / BAJO', '5 / 9 / 11',
 (SELECT COUNT(*) FILTER (WHERE categoria_desempeno = 'EXCELENTE') || ' / ' ||
         COUNT(*) FILTER (WHERE categoria_desempeno = 'ACEPTABLE') || ' / ' ||
         COUNT(*) FILTER (WHERE categoria_desempeno = 'BAJO_RENDIMIENTO')
  FROM v_kpi_desempeno_experiencias)),
('3. Consultas', 'JOIN C: municipio mejor valorado', 'Morroa | 27 reservas | 4.67',
 (SELECT m.nombre || ' | ' || COUNT(DISTINCT r.id_reserva) || ' reservas | ' || ROUND(AVG(va.puntuacion_estrellas), 2)
  FROM experiencias e
  JOIN municipios m   ON m.id_municipio = e.id_municipio
  JOIN programacion p ON p.id_experiencia = e.id_experiencia
  JOIN reservas r     ON r.id_programacion = p.id_programacion
  LEFT JOIN valoraciones va ON va.id_reserva = r.id_reserva
  WHERE r.estado_reserva IN ('CONFIRMADA', 'COMPLETADA')
  GROUP BY m.id_municipio, m.nombre
  ORDER BY ROUND(AVG(va.puntuacion_estrellas), 2) DESC NULLS LAST
  LIMIT 1));

-- ---------------------------------------------------------------------
-- 4. OBJETOS PROGRAMABLES
-- ---------------------------------------------------------------------
INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES
('4. Programables', 'fn_consultar_cupos_disponibles(1)', '10', fn_consultar_cupos_disponibles(1)::TEXT),
('4. Programables', 'fn_consultar_cupos_disponibles(999999)', '0', fn_consultar_cupos_disponibles(999999)::TEXT),
('4. Programables', 'fn_promedio_satisfaccion_operador(2)', '3.75', fn_promedio_satisfaccion_operador(2)::TEXT),
('4. Programables', 'fn_evaluar_reembolso_cancelacion(999999)', 'RESERVA_INVALIDA', fn_evaluar_reembolso_cancelacion(999999));

DO $$
DECLARE
  v_cod INTEGER; v_res INTEGER; v_prog INTEGER; v_vis INTEGER;
  v_antes INTEGER; v_despues INTEGER; v_aud INTEGER;
BEGIN
  SELECT id_programacion INTO v_prog FROM programacion
  WHERE estado_programacion = 'PROGRAMADA' AND cupos_disponibles >= 2
  ORDER BY id_programacion LIMIT 1;
  SELECT id_visitante INTO v_vis FROM visitantes WHERE email = 'ana.turista@correo.test';

  CALL sp_confirmar_reserva_integral(v_vis, v_prog, 500, 'TARJETA', 'VAL-1', v_cod, v_res);
  INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'sp_confirmar_reserva_integral: cupos insuficientes', '-1', v_cod::TEXT);
  CALL sp_confirmar_reserva_integral(v_vis, v_prog, 1, 'BITCOIN', 'VAL-2', v_cod, v_res);
  INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'sp_confirmar_reserva_integral: pago inválido', '-2', v_cod::TEXT);
  CALL sp_confirmar_reserva_integral(999999, v_prog, 1, 'TARJETA', 'VAL-3', v_cod, v_res);
  INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'sp_confirmar_reserva_integral: visitante inexistente', '-3', v_cod::TEXT);

  v_antes := fn_consultar_cupos_disponibles(v_prog);
  CALL sp_confirmar_reserva_integral(v_vis, v_prog, 2, 'TARJETA', 'VAL-4', v_cod, v_res);
  v_despues := fn_consultar_cupos_disponibles(v_prog);
  INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES
    ('4. Programables', 'sp_confirmar_reserva_integral: éxito', '0', v_cod::TEXT),
    ('4. Programables', 'Cupos descontados una sola vez (2)', '2', (v_antes - v_despues)::TEXT);

  SELECT COUNT(*) INTO v_aud FROM auditoria_cancelaciones;
  CALL sp_cancelar_reserva(v_res);
  INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES
    ('4. Programables', 'Trigger devuelve cupos al cancelar', v_antes::TEXT, fn_consultar_cupos_disponibles(v_prog)::TEXT),
    ('4. Programables', 'Trigger de auditoría registra la cancelación', (v_aud + 1)::TEXT,
     (SELECT COUNT(*) FROM auditoria_cancelaciones)::TEXT);

  BEGIN
    UPDATE programacion SET cupos_disponibles = -5 WHERE id_programacion = v_prog;
    INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'Trigger impide cupos negativos', 'bloqueado', 'se permitió');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'Trigger impide cupos negativos', 'bloqueado', 'bloqueado');
  END;

  BEGIN
    INSERT INTO valoraciones (id_reserva, puntuacion_estrellas)
    SELECT MIN(id_reserva), 5 FROM reservas WHERE estado_reserva = 'CONFIRMADA';
    INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'Trigger impide valorar reserva no realizada', 'bloqueado', 'se permitió');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO validacion (grupo, prueba, esperado, obtenido) VALUES ('4. Programables', 'Trigger impide valorar reserva no realizada', 'bloqueado', 'bloqueado');
  END;
END $$;

-- ---------------------------------------------------------------------
-- RESULTADO
-- ---------------------------------------------------------------------
SELECT grupo, prueba, esperado, obtenido, resultado FROM validacion ORDER BY n;
SELECT COUNT(*) AS pruebas,
       COUNT(*) FILTER (WHERE resultado = 'OK') AS correctas,
       COUNT(*) FILTER (WHERE resultado = 'FALLA') AS fallidas
FROM validacion;

-- FIN 05
