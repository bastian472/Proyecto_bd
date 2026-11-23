-- =====================================================
-- CAPTURA 3  (Figura 8 del informe)
-- Codigos del procedimiento integral (0, -1, -2, -3),
-- las 3 vistas y la tabla de auditoria de cancelaciones.
-- Hazla DESPUES de la captura 2 (esta prueba crea una
-- reserva nueva y cancela otra).
-- Dale al rayo. Salen varias pestanas; toma captura de:
--   - la que muestra los 4 codigos (0, -1, -2, -3)
--   - las 3 vistas
--   - la ultima: auditoria_cancelaciones
-- =====================================================
USE sabores_rutas_sucre;

-- Datos para la prueba: la visitante de prueba y la proxima
-- salida con cupos de la Ruta del Mote de Queso.
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

-- Los 4 casos del procedimiento integral
CALL sp_confirmar_reserva_integral(@vis, @prog_mote, 1, 'TARJETA',
                                   'REF-CAPTURA-001', @c0, @id_res);
CALL sp_confirmar_reserva_integral(@vis, @prog_mote, 500, 'TARJETA',
                                   'REF-CAPTURA-002', @c1, @id_res2);
CALL sp_confirmar_reserva_integral(@vis, @prog_mote, 1, 'BITCOIN',
                                   'REF-CAPTURA-003', @c2, @id_res3);
CALL sp_confirmar_reserva_integral(999999, @prog_mote, 1, 'TARJETA',
                                   'REF-CAPTURA-004', @c3, @id_res4);

-- PESTANA DE LOS CODIGOS (los 4 en una sola fila)
SELECT @c0 AS `exito (0)`,
       @c1 AS `sin cupos (-1)`,
       @c2 AS `error de pago (-2)`,
       @c3 AS `error inesperado (-3)`;

-- LAS 3 VISTAS
SELECT * FROM v_experiencias_disponibles_web ORDER BY fecha LIMIT 10;
SELECT * FROM v_resumen_operaciones_operador ORDER BY fecha_actividad DESC LIMIT 10;
SELECT * FROM v_kpi_desempeno_experiencias ORDER BY recaudo_total_cop DESC;

-- AUDITORIA: se cancela la reserva recien creada y se ve el registro
CALL sp_cancelar_reserva(@id_res);
SELECT * FROM auditoria_cancelaciones;
