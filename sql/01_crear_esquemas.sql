-- =============================================================================
-- 01_crear_esquemas.sql
-- Proyecto H2 — Fase 2, paso 2.2b
-- Crea las 3 capas de la base h2_iea (equivalen a los grupos de Power Query).
-- IF NOT EXISTS: si lo corrés dos veces, no da error (el script es re-ejecutable).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS model;      -- modelo estrella (equivale a 04_Modelo)
CREATE SCHEMA IF NOT EXISTS dq;         -- calidad de datos (equivale a 05_Calidad + 06_controles)
CREATE SCHEMA IF NOT EXISTS analytics;  -- vistas para el dashboard (Power BI / Looker)

-- Documentamos cada esquema dentro de la propia base
COMMENT ON SCHEMA model     IS 'Modelo estrella: fact_projects, dimensiones, bridge_enduse y agg_confidential. Cargado desde Power Query (Fase 1).';
COMMENT ON SCHEMA dq        IS 'Calidad de datos: diccionario y controles (conteos, conciliación, huérfanos, completitud).';
COMMENT ON SCHEMA analytics IS 'Vistas analíticas que consume el dashboard.';
-- Control 2.2b: ¿existen los 3 esquemas?
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('model', 'dq', 'analytics')
ORDER BY schema_name;