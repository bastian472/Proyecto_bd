-- =====================================================
-- CAPTURA 4b  (Figura 7 del informe)
-- Ejecutar CONECTADO COMO usr_agente1  (clave: Agente_2026!)
-- Dale al rayo. La primera consulta funciona y la segunda
-- debe dar ERROR 1142 en el panel de abajo (Output).
-- Toma captura del panel Output donde sale el error.
-- =====================================================
USE sabores_rutas_sucre;

-- Esto SI puede: ver pagos
SELECT COUNT(*) AS total_pagos FROM pagos;

-- Esto NO puede: borrar reservas (se le quito el DELETE)  -> ERROR 1142
DELETE FROM reservas WHERE id_reserva = 1;
