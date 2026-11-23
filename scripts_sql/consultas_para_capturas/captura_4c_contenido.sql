-- =====================================================
-- CAPTURA 4c  (Figura 7 del informe)
-- Ejecutar CONECTADO COMO usr_contenido1  (clave: Contenido_2026!)
-- Dale al rayo. La primera consulta funciona y la segunda
-- debe dar ERROR 1142 en el panel de abajo (Output).
-- Toma captura del panel Output donde sale el error.
-- =====================================================
USE sabores_rutas_sucre;

-- Esto SI puede: ver experiencias
SELECT titulo, estado_experiencia FROM experiencias LIMIT 5;

-- Esto NO puede: ver los pagos  -> ERROR 1142
SELECT * FROM pagos;
