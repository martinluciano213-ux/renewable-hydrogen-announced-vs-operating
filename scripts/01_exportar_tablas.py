# =============================================================================
# 01_exportar_tablas.py
# Proyecto H2 — Fase 2, paso 2.1
#
# Exporta las tablas finales del libro de Power Query a CSV "neutros" para PostgreSQL:
#   - UTF-8, separador coma, PUNTO decimal (independiente de la configuración regional)
#   - enteros sin ".0" (ej.: 2009 y no 2009.0)
#   - VERDADERO/FALSO como true/false
#   - vacíos como campo vacío (PostgreSQL los lee como NULL)
# Al final verifica filas, columnas y algunos valores conocidos.
# =============================================================================

from pathlib import Path
import pandas as pd

# -----------------------------------------------------------------------------
# 1. PARÁMETROS (equivalente a pRutaCSV en Power Query): solo se edita esta parte.
# -----------------------------------------------------------------------------
CARPETA_PROYECTO = Path(r"C:\Users\marti\OneDrive\Desktop\Portfolio - Martín Luciano - Analista de Datos\H2_Proyecto_Dashboard")
LIBRO = CARPETA_PROYECTO / "H2_Fase1_PowerQuery.xlsx"
SALIDA = CARPETA_PROYECTO / "datos" / "export_postgres"

# Tablas a exportar: {nombre de la hoja: (filas esperadas, columnas esperadas)}
TABLAS = {
    "dim_status":       (8, 5),
    "dim_technology":   (13, 5),
    "dim_electricity":  (7, 2),
    "dim_product":      (8, 3),
    "dim_country":      (97, 6),
    "dim_enduse":       (14, 3),
    "fact_projects":    (2434, 29),
    "agg_confidential": (7, 10),
    "bridge_enduse":    (2729, 2),
    "dq_dictionary":    (80, 7),
}


# -----------------------------------------------------------------------------
# 2. FUNCIÓN AUXILIAR: preparar los tipos de dato para PostgreSQL
# -----------------------------------------------------------------------------
def normalizar_tipos(df: pd.DataFrame) -> pd.DataFrame:
    for col in df.columns:
        serie = df[col]
        # Columnas decimales cuyos valores son todos enteros (años, ids, órdenes)
        # → entero que admite vacíos. Evita "2009.0" en columnas INTEGER.
        if pd.api.types.is_float_dtype(serie):
            valores = serie.dropna()
            if len(valores) > 0 and (valores % 1 == 0).all():
                df[col] = serie.astype("Int64")
        # Columnas lógicas (VERDADERO/FALSO) → true/false.
        elif pd.api.types.is_bool_dtype(serie):
            df[col] = serie.map({True: "true", False: "false"})
    return df


# -----------------------------------------------------------------------------
# 3. EXPORTAR
# -----------------------------------------------------------------------------
SALIDA.mkdir(parents=True, exist_ok=True)

print(f"Leyendo: {LIBRO.name}\n")
hojas = pd.read_excel(LIBRO, sheet_name=list(TABLAS.keys()))

resumen = []
for nombre, (filas_esp, cols_esp) in TABLAS.items():
    df = normalizar_tipos(hojas[nombre])
    df.to_csv(SALIDA / f"{nombre}.csv", index=False, encoding="utf-8")
    ok = (len(df) == filas_esp) and (df.shape[1] == cols_esp)
    resumen.append((nombre, len(df), df.shape[1], filas_esp, cols_esp, "OK" if ok else "REVISAR"))

# -----------------------------------------------------------------------------
# 4. CONTROLES (como los chk_ de Power Query)
# -----------------------------------------------------------------------------
print(f"{'tabla':<18}{'filas':>7}{'cols':>6}   {'esperado':>12}   estado")
print("-" * 60)
for nombre, f, c, fe, ce, estado in resumen:
    print(f"{nombre:<18}{f:>7}{c:>6}   {f'{fe} x {ce}':>12}   {estado}")

fact = hojas["fact_projects"]
lat_hychico = fact.loc[fact["ref_iea"] == 303, "latitude"].iloc[0]
suma_mwel = round(fact["capacity_mwel"].sum(), 2)

print("\nControles de valores:")
print(f"  Latitud de Hychico (ref_iea 303): {lat_hychico}   (esperado: -45.866278)")
print(f"  Suma de capacity_mwel:            {suma_mwel}   (esperado: 1052955.58)")
print(f"\nArchivos guardados en: {SALIDA}")
