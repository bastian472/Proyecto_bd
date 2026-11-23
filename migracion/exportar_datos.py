"""Exporta los datos de MySQL/MariaDB a INSERT compatibles con PostgreSQL.

Uso:
    pip install pymysql
    python exportar_datos.py --host localhost --user root --password ""  > 02_datos_postgresql.sql

Convierte: TINYINT(1) -> TRUE/FALSE, fechas a formato ISO, comillas
escapadas al estilo SQL estándar, y al final ajusta las secuencias de
identidad con setval para que los próximos INSERT no repitan ids.
"""
import argparse
import datetime as dt
import decimal

import pymysql

# Orden de carga: primero las tablas padre, luego las hijas (llaves foráneas).
TABLAS = ["roles", "usuarios", "municipios", "categorias", "tipos_recurso",
          "operadores", "recursos", "experiencias", "experiencia_recurso",
          "programacion", "visitantes", "reservas", "pagos", "valoraciones",
          "auditoria_cancelaciones"]
BOOLEANAS = {("usuarios", "activo"), ("operadores", "activo"), ("recursos", "activo")}
SIN_IDENTIDAD = {"experiencia_recurso"}


def literal(valor, booleana=False):
    if valor is None:
        return "NULL"
    if booleana:
        return "TRUE" if int(valor) else "FALSE"
    if isinstance(valor, (int, float, decimal.Decimal)):
        return str(valor)
    if isinstance(valor, dt.timedelta):           # columnas TIME
        s = int(valor.total_seconds())
        return f"'{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}'"
    if isinstance(valor, (dt.datetime, dt.date)):
        return "'" + valor.isoformat(sep=" ") + "'" if isinstance(valor, dt.datetime) else f"'{valor.isoformat()}'"
    return "'" + str(valor).replace("'", "''") + "'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=3306)
    ap.add_argument("--user", default="root")
    ap.add_argument("--password", default="")
    ap.add_argument("--database", default="sabores_rutas_sucre")
    a = ap.parse_args()
    cn = pymysql.connect(host=a.host, port=a.port, user=a.user, password=a.password,
                         database=a.database, charset="utf8mb4")
    cur = cn.cursor()
    print("-- =====================================================================")
    print("-- 02. DATOS migrados desde MySQL/MariaDB (generado por exportar_datos.py)")
    print(f"-- Fecha de exportación: {dt.datetime.now():%Y-%m-%d %H:%M}")
    print("-- Se cargan ANTES de crear los triggers para que no vuelvan a")
    print("-- descontar cupos que ya vienen calculados desde el origen.")
    print("-- =====================================================================\n")
    print("BEGIN;\n")
    for t in TABLAS:
        cur.execute(f"SELECT * FROM {t}")
        cols = [d[0] for d in cur.description]
        filas = cur.fetchall()
        print(f"-- {t}: {len(filas)} registros")
        if not filas:
            print()
            continue
        for i in range(0, len(filas), 200):
            bloque = filas[i:i + 200]
            valores = ",\n".join(
                "(" + ", ".join(literal(v, (t, c) in BOOLEANAS) for c, v in zip(cols, f)) + ")"
                for f in bloque)
            print(f"INSERT INTO {t} ({', '.join(cols)}) VALUES\n{valores};")
        print()
    print("-- Ajustar las secuencias de identidad al último id cargado.")
    for t in TABLAS:
        if t in SIN_IDENTIDAD:
            continue
        cur.execute("SELECT COLUMN_NAME FROM information_schema.COLUMNS "
                    "WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s AND COLUMN_KEY='PRI'", (a.database, t))
        pk = cur.fetchone()[0]
        print(f"SELECT setval(pg_get_serial_sequence('{t}', '{pk}'), "
              f"COALESCE((SELECT MAX({pk}) FROM {t}), 1));")
    print("\nCOMMIT;\n-- FIN 02")


if __name__ == "__main__":
    main()
