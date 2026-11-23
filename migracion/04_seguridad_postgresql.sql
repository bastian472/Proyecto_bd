-- =====================================================================
-- 04. CONTROL DE ACCESO (DCL) EN POSTGRESQL
-- En PostgreSQL usuarios y roles son el mismo objeto (ROLE): un usuario
-- es un rol con LOGIN. Los roles se heredan automáticamente (INHERIT),
-- por eso no hace falta SET DEFAULT ROLE como en MySQL/MariaDB.
-- CREATE ROLE no admite IF NOT EXISTS: se usa un bloque DO.
-- Cambiar las contraseñas de ejemplo en un entorno real.
-- =====================================================================

DO $$
DECLARE
  r TEXT;
BEGIN
  FOREACH r IN ARRAY ARRAY['rol_promotor_turistico','rol_agente_reservas','rol_admin_contenido'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_promotor1') THEN
    CREATE ROLE usr_promotor1 LOGIN PASSWORD 'Promotor_2026!';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_agente1') THEN
    CREATE ROLE usr_agente1 LOGIN PASSWORD 'Agente_2026!';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_contenido1') THEN
    CREATE ROLE usr_contenido1 LOGIN PASSWORD 'Contenido_2026!';
  END IF;
END $$;

-- En PostgreSQL también hay que permitir el uso del esquema.
GRANT USAGE ON SCHEMA public TO rol_promotor_turistico, rol_agente_reservas, rol_admin_contenido;

-- RETO DCL A: solo consulta del catálogo.
GRANT SELECT ON experiencias, categorias, programacion TO rol_promotor_turistico;

-- RETO DCL B: agente de reservas (clientes, reservas y pagos).
GRANT SELECT, INSERT, UPDATE ON visitantes, pagos TO rol_agente_reservas;
GRANT SELECT, INSERT, UPDATE, DELETE ON reservas TO rol_agente_reservas;
GRANT SELECT ON programacion TO rol_agente_reservas;
-- Con columnas IDENTITY no se necesitan permisos sobre secuencias para
-- insertar, a diferencia de las columnas SERIAL.

-- RETO DCL B: administrador de contenidos (sin acceso a pagos).
GRANT SELECT, INSERT, UPDATE, DELETE ON experiencias, programacion, operadores TO rol_admin_contenido;
GRANT SELECT ON categorias, municipios TO rol_admin_contenido;

GRANT rol_promotor_turistico TO usr_promotor1;
GRANT rol_agente_reservas    TO usr_agente1;
GRANT rol_admin_contenido    TO usr_contenido1;

-- RETO DCL C: retirar DELETE sobre reservas al rol de ventas.
REVOKE DELETE ON reservas FROM rol_agente_reservas;

-- Verificación en el diccionario de datos (PostgreSQL sí tiene
-- information_schema.role_table_grants).
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_promotor_turistico','rol_agente_reservas','rol_admin_contenido')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- FIN 04
