-- =====================================================
-- CAPTURA 4a  (Figura 7 del informe)
-- Ejecutar CONECTADO COMO usr_promotor1  (clave: Promotor_2026!)
-- Dale al rayo. La primera consulta funciona y la segunda
-- debe dar ERROR 1142 en el panel de abajo (Output).
-- Toma captura del panel Output donde sale el error.
-- =====================================================
USE sabores_rutas_sucre;

-- Esto SI puede: consultar
SELECT titulo, precio_base_cop FROM experiencias LIMIT 5;

-- Esto NO puede: borrar  -> ERROR 1142
DELETE FROM experiencias WHERE id_experiencia = 1;
