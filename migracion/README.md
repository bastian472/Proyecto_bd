# Migración MySQL/MariaDB → PostgreSQL 18

Migración de la base relacional de MySQL/MariaDB a PostgreSQL 18, con validación automática de 39 pruebas.

## Archivos y orden de ejecución

| Orden | Archivo | Qué hace |
|---|---|---|
| 1 | `01_esquema_postgresql.sql` | 15 tablas, restricciones e índices |
| 2 | `02_datos_postgresql.sql` | Todos los datos (dentro de una transacción) y ajuste de secuencias |
| 3 | `03_objetos_programables.sql` | 5 funciones, 7 triggers, 5 procedimientos y 3 vistas en PL/pgSQL |
| 4 | `04_seguridad_postgresql.sql` | 3 roles, 3 usuarios, GRANT y REVOKE |
| 5 | `05_validacion_postgresql.sql` | 39 pruebas comparadas contra el origen |
| — | `migracion_completa_postgresql.sql` | Los pasos 1 a 5 en un solo archivo |
| — | `exportar_datos.py` | Regenera el archivo 02 leyendo la base MySQL/MariaDB |

Los datos se cargan **antes** de crear los triggers para que no vuelvan a descontar cupos que ya vienen calculados del origen.

## Cómo ejecutarla (pgAdmin 4)

1. Clic derecho en **Databases > Create > Database…** y crear `sabores_rutas_sucre`.
2. Seleccionar la base y abrir **Tools > Query Tool**.
3. **Open File** → `migracion_completa_postgresql.sql`.
4. Ejecutar con el botón **Execute/Refresh** (triángulo).
5. La última pestaña de resultados muestra la validación: **39 pruebas, 39 OK**.

Para regenerar los datos desde el origen:

```bash
pip install pymysql
python exportar_datos.py --host localhost --user root --password "" > 02_datos_postgresql.sql
```

## Evidencias

La carpeta `evidencias/` tiene las capturas de pgAdmin: script cargado, resultado 39/39, detalle de pruebas y tablas migradas.
