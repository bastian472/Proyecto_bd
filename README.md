# Sabores y Rutas de Sucre — Bases de Datos

Plataforma de turismo cultural, gastronómico y de naturaleza del departamento de Sucre (Colombia). Este repositorio contiene la solución de datos del **Modelo de Negocio 3** del curso de Bases de Datos (Parcial Corte II): base relacional, base NoSQL documental, base vectorial y migración a otro gestor.

| Componente | Tecnología | Carpeta |
|---|---|---|
| Base relacional | MySQL 8 o MariaDB 10.4+ (dos scripts) | [`scripts_sql/`](scripts_sql/) |
| Base NoSQL documental | MongoDB Atlas | [`nosql/`](nosql/) |
| Base vectorial | MongoDB Atlas Vector Search + spaCy | [`vectorial/`](vectorial/) |
| Migración | MySQL/MariaDB → PostgreSQL 18 | [`migracion/`](migracion/) |
| Diagrama del modelo | MySQL Workbench (EER) | [`documentacion/`](documentacion/) |

## Estructura

```
sabores-rutas-sucre-bd/
├── README.md
├── scripts_sql/
│   ├── 01_creacion_y_datos.sql            # tablas, índices y carga de datos
│   ├── 02_consultas_y_retos.sql           # consultas, vistas, SP, TCL, DCL y retos
│   └── evidencias/                        # capturas de MySQL Workbench
├── nosql/
│   ├── sabores_rutas_sucre_mongodb.js     # colecciones, datos y consultas
│   └── evidencias/                        # salida de mongosh (Q1–Q14, reto C) y Atlas
├── vectorial/
│   ├── sabores_rutas_sucre_vectorial.js   # embeddings, índice y búsquedas
│   ├── buscar_semantico.py                # búsqueda en vivo con cualquier frase
│   ├── requirements.txt
│   └── evidencias/                        # clúster, índice y búsquedas V1–V5
├── migracion/
│   ├── 01_esquema_postgresql.sql
│   ├── 02_datos_postgresql.sql
│   ├── 03_objetos_programables.sql
│   ├── 04_seguridad_postgresql.sql
│   ├── 05_validacion_postgresql.sql
│   ├── migracion_completa_postgresql.sql  # 01 a 05 en un solo archivo
│   ├── exportar_datos.py                  # genera 02 desde MySQL/MariaDB
│   └── evidencias/                        # pgAdmin: 39 de 39 pruebas OK
└── documentacion/
    └── diagramas/
        └── modelo_relacional_bd.jpg        # modelo relacional generado en MySQL Workbench
```

## Despliegue

### 1. Base relacional (MySQL o MariaDB)

1. Abrir MySQL Workbench (o phpMyAdmin) conectado como `root`.
2. Abrir `scripts_sql/01_creacion_y_datos.sql` y ejecutarlo completo (rayo ⚡ o `Ctrl + Shift + Enter`).
3. Abrir `scripts_sql/02_consultas_y_retos.sql` y ejecutarlo completo.

Los mismos archivos funcionan en **MySQL 8.0.16+** y en **MariaDB 10.4+** (XAMPP). La única instrucción que cambia entre ambos, la asignación del rol por defecto, la resuelve el procedimiento `sp_asignar_rol_por_defecto`, que detecta el servidor con `VERSION()`. Probado en MySQL 8.0.46 y MariaDB 10.11.

El archivo 1 **borra y vuelve a crear** la base `sabores_rutas_sucre`. Para repetir todo, ejecute de nuevo el archivo 1 y después el 2. Al final del archivo 2 se muestran los registros por tabla y una consulta de control de cupos que debe dar `0`.

Resultado esperado: 27 experiencias, 126 programaciones, 421 visitantes, 713 reservas, 757 pagos y 162 valoraciones.

### 2. Base NoSQL (MongoDB Atlas)

1. Crear un clúster gratuito (M0) en [MongoDB Atlas](https://www.mongodb.com/atlas).
2. En **Database Access**, crear un usuario; en **Network Access**, permitir la IP del equipo.
3. Instalar [mongosh](https://www.mongodb.com/try/download/shell) y ejecutar, desde la carpeta `nosql`:

```bash
mongosh "mongodb+srv://CLUSTER.mongodb.net/" --apiVersion 1 --username USUARIO --password CLAVE --file sabores_rutas_sucre_mongodb.js
```

Crea la base `sabores_rutas_sucre` con las colecciones `experiencias` (27), `visitantes` (221) y `reservas` (513), y ejecuta 14 consultas más las pruebas del reto C. Debe terminar con `FIN DEL SCRIPT`.

### 3. Base vectorial (Atlas Vector Search)

Requiere haber ejecutado antes el paso 2. Desde la carpeta `vectorial`:

```bash
mongosh "mongodb+srv://CLUSTER.mongodb.net/" --apiVersion 1 --username USUARIO --password CLAVE --file sabores_rutas_sucre_vectorial.js
```

El script guarda un embedding de 300 dimensiones en cada experiencia, crea el índice `idx_vector_experiencias`, espera a que esté listo y ejecuta 5 búsquedas semánticas (V1 a V5).

Búsqueda en vivo con cualquier frase (opcional):

```bash
pip install -r requirements.txt
python -m spacy download es_core_news_md
set MONGODB_URI=mongodb+srv://USUARIO:CLAVE@CLUSTER.mongodb.net/
python buscar_semantico.py "quiero comer pescado fresco frente al mar"
```

En PowerShell: `$env:MONGODB_URI="mongodb+srv://..."`.

### 4. Migración a PostgreSQL

1. Instalar PostgreSQL 14 o superior con pgAdmin (probado en PostgreSQL 18; también sirve un servicio en la nube como Neon o Supabase).
2. Crear la base: `CREATE DATABASE sabores_rutas_sucre ENCODING 'UTF8';`
3. Abrir el **Query Tool** sobre esa base y ejecutar `migracion/migracion_completa_postgresql.sql` (F5).
4. La última consulta muestra las pruebas de validación: deben salir **39 pruebas, 39 correctas, 0 fallidas**.

Con `psql`:

```bash
psql -d sabores_rutas_sucre -f migracion/migracion_completa_postgresql.sql
```

Para volver a generar los datos desde la base MySQL/MariaDB:

```bash
pip install pymysql
python migracion/exportar_datos.py --user root --password "" > migracion/02_datos_postgresql.sql
```

## Credenciales de prueba

Usuarios creados por los scripts para demostrar el control de acceso (DCL). Son solo para pruebas: cambiar las contraseñas en un entorno real.

| Usuario | Contraseña | Rol | Puede | No puede |
|---|---|---|---|---|
| `usr_promotor1` | `Promotor_2026!` | `rol_promotor_turistico` | Consultar experiencias, categorías y programación | Modificar o borrar nada |
| `usr_agente1` | `Agente_2026!` | `rol_agente_reservas` | Gestionar visitantes, reservas y pagos | Tocar operadores; borrar reservas |
| `usr_contenido1` | `Contenido_2026!` | `rol_admin_contenido` | Gestionar experiencias, programación y operadores | Ver pagos |

En MySQL/MariaDB se conectan como `usuario@localhost`; en PostgreSQL con `psql -h localhost -U usuario -d sabores_rutas_sucre`.

**MongoDB Atlas (acceso de lectura para revisión):**

| Dato | Valor |
|---|---|
| Cadena de conexión | `mongodb+srv://cluster1s.1idunwj.mongodb.net/` (base `sabores_rutas_sucre`) |
| Usuario de solo lectura | `profesor_lectura` |
| Contraseña | `maria_db` |

> Para el revisor, crear en Atlas un usuario aparte con el rol **Only read any database**. No publicar aquí la contraseña del usuario administrador.

## Validación rápida

| Prueba | Dónde | Resultado esperado |
|---|---|---|
| Cupos consistentes con reservas | Final del script SQL | `programaciones_con_cupos_inconsistentes = 0` |
| Procedimiento integral | Script SQL, sección 4.3 | Códigos `0`, `-1`, `-2`, `-3` |
| Valoración sobre reserva no realizada | Script SQL / PostgreSQL | Rechazada por `trg_validar_valoracion` |
| Consulta NoSQL | `nosql/` | `FIN DEL SCRIPT` |
| Búsqueda semántica V1 | `vectorial/` | 1.º *Ruta del pescado en Tolú* |
| Migración | `05_validacion_postgresql.sql` | 39 de 39 pruebas OK |

## Integrantes

- Kendry Johana Peñafiel Tamara
- [Nombre completo] — [rol en el equipo]
- [Nombre completo] — [rol en el equipo]

Proyecto alineado con el **ODS 9 — Industria, innovación e infraestructura** (meta 9.c, acceso a las TIC).
