-- =====================================================
-- CAPTURA 2  (Figura 17 del informe)
-- Registros por tabla y control de cupos (debe dar 0)
-- Hazla ANTES de la captura 3.
-- Dale al rayo: salen 3 pestanas (Result 1, 2 y 3).
-- Toma captura de la 1 (registros por tabla) y de la 3 (el 0).
-- =====================================================
USE sabores_rutas_sucre;

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
