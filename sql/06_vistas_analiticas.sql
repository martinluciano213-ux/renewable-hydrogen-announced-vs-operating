-- =============================================================================
-- 06_vistas_analiticas.sql
-- Proyecto H2 — Fase 2, paso 2.7
-- Una vista por pregunta del dashboard (P1–P8) + calidad, en el esquema analytics.
-- Power BI se conecta a estas vistas. Las consultas vienen de 04 y 05.
-- =============================================================================
-- Vista P1: panorama (una fila con los KPI de la portada)
CREATE OR REPLACE VIEW analytics.v_p1_panorama AS
SELECT
    COUNT(*)                                                             AS total_proyectos,
    ROUND(SUM(capacity_mwel), 2)                                         AS mwel_total,
    ROUND(SUM(capacity_mwel) FILTER (WHERE status = 'Operational'), 2)   AS mwel_operativo,
    ROUND(100.0 * SUM(capacity_mwel) FILTER (WHERE status = 'Operational')
                / SUM(capacity_mwel), 1)                                 AS pct_mwel_operativo
FROM model.fact_projects;

-- Control: la vista devuelve lo mismo que la consulta original (2434 | 1052955.58 | 1316.26 | 0.1)
SELECT * FROM analytics.v_p1_panorama;

-- Vista P2: pipeline por estado (proyectos, capacidad y % del total)
CREATE OR REPLACE VIEW analytics.v_p2_pipeline AS
WITH por_estado AS (
    SELECT d.sort_order,
           d.status_label_es              AS estado,
           COUNT(*)                       AS proyectos,
           ROUND(SUM(f.capacity_mwel), 2) AS mwel
    FROM model.fact_projects AS f
    JOIN model.dim_status    AS d ON f.status = d.status
    GROUP BY d.sort_order, d.status_label_es
)
SELECT sort_order,                 -- nuevo: Power BI ordena por esta columna
       estado,
       proyectos,
       ROUND(100.0 * proyectos / SUM(proyectos) OVER (), 1) AS pct_proyectos,
       mwel,
       ROUND(100.0 * mwel / SUM(mwel) OVER (), 1)           AS pct_mwel
FROM por_estado
ORDER BY sort_order;

-- Control: 8 filas, idénticas a la P2 de 05 (más la columna sort_order)
SELECT * FROM analytics.v_p2_pipeline;

-- Vista P3: crecimiento por año, real (operativo) vs prometido, anual y acumulado
-- Excluye proyectos sin año (555). No necesita sort_order: Power BI ordena bien por año (número).
CREATE OR REPLACE VIEW analytics.v_p3_crecimiento AS
WITH por_año AS (
    SELECT year_online                                                                   AS año,
           ROUND(SUM(capacity_mwel) FILTER (WHERE status = 'Operational'), 2)            AS mwel_real,
           ROUND(SUM(capacity_mwel) FILTER (WHERE status IN ('Concept', 'Feasibility study', 'FID/Construction')), 2) AS mwel_prometido
    FROM model.fact_projects
    WHERE year_online IS NOT NULL
    GROUP BY year_online
)
SELECT año,
       mwel_real,
       SUM(mwel_real)      OVER (ORDER BY año) AS real_acumulado,
       mwel_prometido,
       SUM(mwel_prometido) OVER (ORDER BY año) AS prometido_acumulado
FROM por_año
ORDER BY año;

-- Control: 45 filas (1965 a 2043); último real_acumulado = 1316.00; último prometido_acumulado = 686115.66
SELECT * FROM analytics.v_p3_crecimiento;

-- Vista P4: proyectos prometidos con fecha prevista vencida (año < 2024, corte de la base)
-- Trae el detalle; Power BI puede contarlos. Le sumamos el nombre del país con un JOIN.
CREATE OR REPLACE VIEW analytics.v_p4_vencidos AS
SELECT f.project_name      AS proyecto,
       c.country_name_es   AS pais,
       f.status,
       f.year_online       AS año_previsto,
       f.capacity_mwel     AS mwel
FROM model.fact_projects AS f
JOIN model.dim_country   AS c ON f.country_code = c.country_code
WHERE f.status IN ('Concept', 'Feasibility study', 'FID/Construction')
  AND f.year_online < 2024;

-- Control: 1 fila (Inner Mongolia green hydrogen | China | FID/Construction | 2023 | null)
SELECT * FROM analytics.v_p4_vencidos;

-- Vista P5: rutas de producción (cuenta proyectos), total vs operativos vs prometidos
-- No necesita sort_order: en Power BI se ordena por "total" (de mayor a menor).
CREATE OR REPLACE VIEW analytics.v_p5_rutas AS
SELECT
    CASE
        WHEN t.technology_group = 'Electrolysis' AND f.electricity = 'Dedicated renewable'
             THEN 'Electrólisis con renovable dedicada'
        WHEN t.technology_group = 'Electrolysis' AND f.electricity = 'Nuclear'
             THEN 'Electrólisis con nuclear'
        WHEN t.technology_group = 'Electrolysis' AND f.electricity IN ('Grid', 'Grid+Renewables')
             THEN 'Electrólisis con red eléctrica'
        WHEN t.technology_group = 'Electrolysis'
             THEN 'Electrólisis sin fuente informada'
        WHEN t.technology_group = 'Fossil fuels with CCUS'
             THEN 'Fósil con captura de CO2'
        ELSE 'Otra / sin dato'
    END                                                                              AS ruta,
    COUNT(*)                                                                         AS total,
    COUNT(*) FILTER (WHERE f.status = 'Operational')                                 AS operativos,
    COUNT(*) FILTER (WHERE f.status IN ('Concept', 'Feasibility study', 'FID/Construction')) AS prometidos
FROM model.fact_projects  AS f
JOIN model.dim_technology AS t ON f.technology = t.technology
GROUP BY ruta
ORDER BY total DESC;

-- Control: 6 filas; total 2434 | operativos 334 | prometidos 1832
SELECT * FROM analytics.v_p5_rutas;

-- Vista P6A: qué se produce (proyectos, capacidad y % del total)
CREATE OR REPLACE VIEW analytics.v_p6a_productos AS
WITH por_producto AS (
    SELECT d.sort_order,
           d.product_label_es             AS producto,
           COUNT(*)                       AS proyectos,
           ROUND(SUM(f.capacity_mwel), 2) AS mwel
    FROM model.fact_projects AS f
    JOIN model.dim_product   AS d ON f.product = d.product
    GROUP BY d.sort_order, d.product_label_es
)
SELECT sort_order,                 -- para ordenar en Power BI
       producto,
       proyectos,
       ROUND(100.0 * proyectos / SUM(proyectos) OVER (), 1) AS pct_proyectos,
       mwel,
       ROUND(100.0 * mwel / SUM(mwel) OVER (), 1)           AS pct_mwel
FROM por_producto
ORDER BY sort_order;

-- Control: 8 filas; proyectos suman 2434
SELECT * FROM analytics.v_p6a_productos;

-- Vista P6B: para qué se usa (cuenta usos; un proyecto puede tener varios)
-- % sobre los 1908 proyectos con uso: suman más de 100 %
CREATE OR REPLACE VIEW analytics.v_p6b_usos AS
SELECT d.sort_order,               -- para ordenar en Power BI
       d.enduse_label_es                                      AS uso_final,
       COUNT(*)                                               AS proyectos,
       ROUND(100.0 * COUNT(*)
             / (SELECT COUNT(DISTINCT project_id) FROM model.bridge_enduse), 1)
                                                              AS pct_de_proyectos_con_uso
FROM model.bridge_enduse AS b
JOIN model.dim_enduse     AS d ON b.enduse = d.enduse
GROUP BY d.sort_order, d.enduse_label_es
ORDER BY proyectos DESC;

-- Control: 14 filas; proyectos suman 2729
SELECT * FROM analytics.v_p6b_usos;

-- Vista P7: ranking mundial de países por capacidad (todos los países)
-- El top 10 se filtra en Power BI (filtro "N superior" por puesto).
CREATE OR REPLACE VIEW analytics.v_p7_ranking_paises AS
SELECT c.country_name_es                                               AS pais,
       COUNT(*)                                                        AS proyectos,
       ROUND(SUM(f.capacity_mwel), 2)                                  AS mwel,
       ROUND(100.0 * SUM(f.capacity_mwel)
             / SUM(SUM(f.capacity_mwel)) OVER (), 1)                   AS pct_mundial,
       RANK() OVER (ORDER BY SUM(f.capacity_mwel) DESC NULLS LAST)     AS puesto
FROM model.fact_projects AS f
JOIN model.dim_country   AS c ON f.country_code = c.country_code
GROUP BY c.country_name_es
ORDER BY puesto;

-- Control: 97 filas (todos los países); puesto 1 Australia (127205.18); Chile 3; Brasil 9
SELECT * FROM analytics.v_p7_ranking_paises;

-- Vista P8: países de Latinoamérica, con su puesto en la región y en el mundo
-- La CTE hace falta: los rankings se calculan con TODOS los países y recién después se filtra LatAm.
CREATE OR REPLACE VIEW analytics.v_p8_latam AS
WITH por_pais AS (
    SELECT c.country_name_es                                                   AS pais,
           c.is_latam,
           COUNT(*)                                                            AS proyectos,
           ROUND(SUM(f.capacity_mwel), 2)                                      AS mwel,
           RANK() OVER (ORDER BY SUM(f.capacity_mwel) DESC NULLS LAST)         AS puesto_mundial,
           RANK() OVER (PARTITION BY c.is_latam
                        ORDER BY SUM(f.capacity_mwel) DESC NULLS LAST)         AS puesto_latam
    FROM model.fact_projects AS f
    JOIN model.dim_country   AS c ON f.country_code = c.country_code
    GROUP BY c.country_name_es, c.is_latam
)
SELECT puesto_latam, puesto_mundial, pais, proyectos, mwel
FROM por_pais
WHERE is_latam = true
ORDER BY puesto_latam;

-- Control: 14 filas, 199 proyectos; Chile 1|3, Brasil 2|9, Argentina 3|20 (8 proyectos)
SELECT * FROM analytics.v_p8_latam;

-- Vista calidad: semáforo de 10 controles (página 4 del dashboard)
-- Esperado vs real → OK / REVISAR. Viene de 04_controles_calidad.sql (2.5c).
CREATE OR REPLACE VIEW analytics.v_calidad_semaforo AS
WITH controles AS (
    SELECT 'DQ-01' AS id, 'Filas fact + agg = CSV original' AS control, 2441 AS esperado,
           (SELECT COUNT(*) FROM model.fact_projects)
         + (SELECT COUNT(*) FROM model.agg_confidential) AS real
    UNION ALL
    SELECT 'DQ-02', 'Huérfanos de status', 0,
           (SELECT COUNT(*) FROM model.fact_projects AS f
              LEFT JOIN model.dim_status AS d ON f.status = d.status
             WHERE d.status IS NULL)
    UNION ALL
    SELECT 'DQ-03', 'Huérfanos de technology', 0,
           (SELECT COUNT(*) FROM model.fact_projects AS f
              LEFT JOIN model.dim_technology AS d ON f.technology = d.technology
             WHERE d.technology IS NULL)
    UNION ALL
    SELECT 'DQ-04', 'Huérfanos de electricity', 0,
           (SELECT COUNT(*) FROM model.fact_projects AS f
              LEFT JOIN model.dim_electricity AS d ON f.electricity = d.electricity
             WHERE d.electricity IS NULL)
    UNION ALL
    SELECT 'DQ-05', 'Huérfanos de product', 0,
           (SELECT COUNT(*) FROM model.fact_projects AS f
              LEFT JOIN model.dim_product AS d ON f.product = d.product
             WHERE d.product IS NULL)
    UNION ALL
    SELECT 'DQ-06', 'Huérfanos de country_code', 0,
           (SELECT COUNT(*) FROM model.fact_projects AS f
              LEFT JOIN model.dim_country AS d ON f.country_code = d.country_code
             WHERE d.country_code IS NULL AND f.country_code IS NOT NULL)
    UNION ALL
    SELECT 'DQ-07', 'Filas del bridge', 2729,
           (SELECT COUNT(*) FROM model.bridge_enduse)
    UNION ALL
    SELECT 'DQ-08', 'Vacíos de year_online', 555,
           (SELECT COUNT(*) - COUNT(year_online) FROM model.fact_projects)
    UNION ALL
    SELECT 'DQ-09', 'Vacíos de latitude', 348,
           (SELECT COUNT(*) - COUNT(latitude) FROM model.fact_projects)
    UNION ALL
    SELECT 'DQ-10', 'Proyectos sin uso final', 526,
           (SELECT COUNT(*) FROM model.fact_projects AS f
              LEFT JOIN model.bridge_enduse AS d ON f.project_id = d.project_id
             WHERE d.project_id IS NULL)
)
SELECT id, control, esperado, real,
       CASE WHEN real = esperado THEN 'OK' ELSE 'REVISAR' END AS estado
FROM controles
ORDER BY id;

-- Control: 10 filas, todas en OK
SELECT * FROM analytics.v_calidad_semaforo;

-- Control final 2.7: vistas creadas en analytics. Esperado: 10 (sin v2_pipeline)
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'analytics'
ORDER BY table_name;

  