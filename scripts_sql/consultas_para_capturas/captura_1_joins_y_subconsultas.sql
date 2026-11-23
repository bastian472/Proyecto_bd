-- =====================================================
-- CAPTURA 1  (Figura 6 del informe)
-- Consultas JOIN A, B, C y subconsultas A, B, C
-- Abre este archivo y dale al rayo. Abajo salen 6 pestanas
-- (Result 1 a Result 6): toma captura de cada una.
-- =====================================================
USE sabores_rutas_sucre;

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


