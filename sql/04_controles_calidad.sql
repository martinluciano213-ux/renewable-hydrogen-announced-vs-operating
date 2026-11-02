-- =============================================================================
-- 04_controles_calidad.sql
-- Proyecto H2 — Fase 2, pasos 2.4b y 2.5
-- Controles de calidad sobre los datos ya cargados (equivale a los chk_ y
-- dq_completeness de Power Query, Fase 1).
--   2.4b  Pruebas de restricciones del bridge (INSERT que deben fallar)
--   2.5a  Huérfanos: LEFT JOIN … IS NULL (esperado 0 en las 5 FK)
--   2.5b  Completitud por columna (vacíos y % completo)
-- =============================================================================
--Preparación: un par proyecto–uso real del bridge.
SELECT * FROM model.bridge_enduse LIMIT 1;
-- Prueba 1: proyecto inexistente. Debe fallar por fk_bridge_project
--INSERT INTO model.bridge_enduse VALUES (99999, 'Refining');

-- Prueba 2: enduse inexistente. Debe fallar por fk_bridge_enduse
--INSERT INTO model.bridge_enduse VALUES (8, 'Nuclear');

-- Prueba 3: Duplicado . Debe fallar por pk_bridge_enduse
--INSERT INTO model.bridge_enduse VALUES (8, 'Mobility');
-- Control 2.4b: el bridge sigue intacto. Esperado 2729
SELECT COUNT(*) AS filas FROM model.bridge_enduse;

-- 2.5a Huérfanos de status: proyectos cuyo status NO existe en dim_status. Esperado 0
SELECT COUNT(*) AS huerfanos_status
FROM model.fact_projects AS f                         -- f = alias corto del fact
LEFT JOIN model.dim_status AS d                       -- d = alias corto de la dim
       ON f.status = d.status                         -- la condición de cruce (como el merge)
WHERE d.status IS NULL;                               -- sin pareja en la dim = huérfano

-- 2.5a Huérfanos de tchenology: proyectos cuyo technology NO existe en dim_technology. Esperado 0
SELECT COUNT(*) AS huerfanos_technology
FROM model.fact_projects AS f                         -- f = alias corto del fact
LEFT JOIN model.dim_technology AS d                       -- d = alias corto de la dim
       ON f.technology = d.technology                        -- la condición de cruce (como el merge)
WHERE d.technology IS NULL;   

-- 2.5a Huérfanos de Electricity : proyectos cuyo electricity NO existe en dim_electricity. Esperado 0

SELECT COUNT(*) AS huerfanos_electricity
FROM model.fact_projects AS f                         -- f = alias corto del fact
LEFT JOIN model.dim_electricity AS d                       -- d = alias corto de la dim
       ON f.electricity = d.electricity                        -- la condición de cruce (como el merge)
WHERE d.electricity IS NULL;   

-- 2.5a Huérfanos de Product : proyectos cuyo product NO existe en dim_product. Esperado 0

SELECT COUNT(*) AS huerfanos_product
FROM model.fact_projects AS f
LEFT JOIN model.dim_product AS d
       ON f.product = d.product
WHERE d.product IS NULL;	

-- 2.5a Huérfanos de country : proyectos cuyo country NO existe en dim_country. Esperado 0
SELECT COUNT(*) AS huerfanos_country_code
FROM model.fact_projects AS f
LEFT JOIN model.dim_country AS d
       ON f.country_code = d.country_code
WHERE d.country_code IS NULL	 
AND f.country_code IS NOT NULL;

-- ¿Cuántos proyectos no tienen país? Esperado 0 (por eso no hubo falsos huérfanos)
SELECT COUNT(*) AS sin_pais
FROM model.fact_projects
WHERE country_code IS NULL;

-- =============================================================================
-- 2.5b COMPLETITUD (equivale a dq_completeness de Power Query)
-- =============================================================================

-- Completitud de year_online. Esperado: 2434 total, 1879 con dato, 555 vacíos, 77.2 %
SELECT
    COUNT(*)                                           AS total,
    COUNT(year_online)                                 AS con_dato,     -- COUNT(col) ignora los NULL
    COUNT(*) - COUNT(year_online)                      AS vacios,
    ROUND(100.0 * COUNT(year_online) / COUNT(*), 1)    AS pct_completo
FROM model.fact_projects;

-- Completitud de latitude
SELECT
    COUNT (*)                                         AS total,
	COUNT (latitude)                                  AS con_dato,    
	COUNT (*) - COUNT (latitude)                      AS vacios,
	ROUND (100.0 * COUNT (latitude)/ COUNT (*), 1)    AS pct_completo
FROM model.fact_projects;	

-- Proyectos SIN uso final (anti-join fact ↔ bridge). Esperado 526
SELECT COUNT (*) AS proyectos_sin_enduse
FROM model.fact_projects AS f                        
LEFT JOIN model.bridge_enduse AS d                       
       ON f.project_id = d.project_id                        
WHERE d.project_id IS NULL;

-- Proyectos CON uso final: cuántos proyectos distintos aparecen en el bridge. Esperado 1908
SELECT
    COUNT(*)                    AS filas_bridge,       -- esperado 2729 (una fila por par proyecto–uso)
    COUNT(DISTINCT project_id)  AS proyectos_con_uso   -- esperado 1908 (cada proyecto, una sola vez)
FROM model.bridge_enduse;

-- =============================================================================
-- 2.5c SEMÁFORO DE CALIDAD (equivale a dq_rules de Power Query)
-- Una fila por control: esperado vs real → OK / REVISAR. Esperado: 10 filas, todas OK.
-- =============================================================================
WITH controles AS (

    -- DQ-01: conciliación con el CSV original (control de cierre del 2.4)
    SELECT 'DQ-01'                                        AS id,
           'Filas fact + agg = CSV original'              AS control,
           2441                                           AS esperado,
           (SELECT COUNT(*) FROM model.fact_projects)
         + (SELECT COUNT(*) FROM model.agg_confidential)  AS real

    UNION ALL

    -- DQ-02: huérfanos de status (anti-join del 2.5a)
    SELECT 'DQ-02', 'Huérfanos de status', 0,
           (SELECT COUNT(*)
              FROM model.fact_projects AS f
              LEFT JOIN model.dim_status AS d ON f.status = d.status
             WHERE d.status IS NULL)

    UNION ALL

    -- DQ-03: huérfanos de technology (anti-join del 2.5a)
    SELECT 'DQ-03', 'Huérfanos de technology', 0,
           (SELECT COUNT(*)
              FROM model.fact_projects AS f
              LEFT JOIN model.dim_technology AS d ON f.technology = d.technology
             WHERE d.technology IS NULL)

    UNION ALL

    -- DQ-04: huérfanos de electricity (anti-join del 2.5a)
    SELECT 'DQ-04', 'Huérfanos de electricity', 0,
           (SELECT COUNT(*)
              FROM model.fact_projects AS f
              LEFT JOIN model.dim_electricity AS d ON f.electricity = d.electricity
             WHERE d.electricity IS NULL)

    UNION ALL

    -- DQ-05: huérfanos de product (anti-join del 2.5a)
    SELECT 'DQ-05', 'Huérfanos de product', 0,
           (SELECT COUNT(*)
              FROM model.fact_projects AS f
              LEFT JOIN model.dim_product AS d ON f.product = d.product
             WHERE d.product IS NULL)

    UNION ALL

    -- DQ-06: huérfanos de country_code (versión blindada: vacío ≠ huérfano)
    SELECT 'DQ-06', 'Huérfanos de country_code', 0,
           (SELECT COUNT(*)
              FROM model.fact_projects AS f
              LEFT JOIN model.dim_country AS d ON f.country_code = d.country_code
             WHERE d.country_code IS NULL
               AND f.country_code IS NOT NULL)

    UNION ALL

    -- DQ-07: filas del bridge (conteo del 2.4b)
    SELECT 'DQ-07', 'Filas del bridge', 2729,
           (SELECT COUNT(*) FROM model.bridge_enduse)

    UNION ALL

    -- DQ-08: vacíos de year_online (completitud del 2.5b)
    SELECT 'DQ-08', 'Vacíos de year_online', 555,
           (SELECT COUNT(*) - COUNT(year_online) FROM model.fact_projects)

    UNION ALL

    -- DQ-09: vacíos de latitude (completitud del 2.5b)
    SELECT 'DQ-09', 'Vacíos de latitude', 348,
           (SELECT COUNT(*) - COUNT(latitude) FROM model.fact_projects)

    UNION ALL

    -- DQ-10: proyectos sin uso final (anti-join fact ↔ bridge del 2.5b)
    SELECT 'DQ-10', 'Proyectos sin uso final', 526,
           (SELECT COUNT(*)
              FROM model.fact_projects AS f
              LEFT JOIN model.bridge_enduse AS d ON f.project_id = d.project_id
             WHERE d.project_id IS NULL)

)
SELECT id, control, esperado, real,
       CASE WHEN real = esperado THEN 'OK' ELSE 'REVISAR' END AS estado
FROM controles
ORDER BY id;