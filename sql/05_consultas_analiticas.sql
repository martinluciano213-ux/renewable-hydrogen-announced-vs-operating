-- =============================================================================
-- 05_consultas_analiticas.sql
-- Proyecto H2 — Fase 2, paso 2.6
-- Consultas que responden las preguntas del dashboard (ver preguntas_dashboard).
-- Control general: cada desglose debe sumar el total (2434 proyectos; 1052955.58 MWel).
-- =============================================================================
-- P1. Panorama: total de proyectos, capacidad total, capacidad operativa y %
-- Control: total_proyectos = 2434 y mwel_total = 1052955.58
SELECT
COUNT (*)  AS total_proyectos,
ROUND(SUM(capacity_mwel), 2) AS mwel_total,
ROUND(SUM(capacity_mwel) FILTER (WHERE status = 'Operational'), 2) AS mwel_operativo,
ROUND(100.0 * SUM(capacity_mwel) FILTER (WHERE status = 'Operational' )
/ SUM(capacity_mwel), 1) AS pct_mwel_operativo
FROM model.fact_projects; 

-- Resultado: 334 operativos, 293 con MWel (41 sin dato, ~12 %). El MWel operativo (1316) es un piso.
SELECT
  COUNT(*) AS proyectos_operativos, 
  COUNT(capacity_mwel) AS con_dato
FROM model.fact_projects 
WHERE status = 'Operational'; 

-- P2. Pipeline por estado: proyectos, capacidad y % del total
-- Control: SUM(proyectos) = 2434 y SUM(mwel) = 1052955.58
WITH por_estado AS (
SELECT d.sort_order,
d.status_label_es AS estado,
COUNT(*) AS proyectos,
ROUND(SUM(f.capacity_mwel), 2) AS mwel
FROM model.fact_projects AS f
JOIN model.dim_status AS d ON f.status = d.status
GROUP BY d.sort_order, d.status_label_es
)
SELECT estado,
proyectos,
ROUND(100.0 * proyectos / SUM(proyectos) OVER (), 1) AS pct_proyectos,
mwel,
ROUND(100.0 * mwel / SUM(mwel) OVER (), 1) AS pct_mwel
FROM por_estado
ORDER BY sort_order;

-- Resultado P2 (proyectos | % | MWel | % MWel):
--   Concepto                 644 | 26.5 | 690866.92 | 65.6
--   Estudio de factibilidad  891 | 36.6 | 338332.01 | 32.1
--   Decisión inv./Construc.  297 | 12.2 |  20519.35 |  1.9
--   Operativo                334 | 13.7 |   1316.26 |  0.1
--   Desmantelado               7 |  0.3 |      null |  -
--   Demostración             245 | 10.1 |    769.78 |  0.1
--   Otro / Desconocido         7 |  0.3 |   1151.25 |  0.1
--   Sin dato                   9 |  0.4 |      null |  -
-- Control: 2434 proyectos OK; MWel 1052955.57 (diferencia de 0.01 por redondeo).
-- Hallazgo: 97.7 % de la capacidad está en concepto o factibilidad; <2 % con inversión.

SELECT status, status_label_es, sort_order FROM model.dim_status ORDER BY sort_order;

-- P3 paso 2: capacidad por año, real vs prometido

SELECT year_online AS año,
SUM(capacity_mwel) FILTER (WHERE status = 'Operational') AS mwel_real,
SUM(capacity_mwel) FILTER (WHERE status IN ('Concept','Feasibility study', 'FID/Construction')) AS mwel_prometido
FROM model.fact_projects
WHERE year_online IS NOT NULL
GROUP BY year_online
ORDER BY year_online;

-- Resultado P3 paso 2 (MWel por año de puesta en marcha):
--   Real (Operational): de 1965 a 2024. Mejor año: 2023 = 587 MW. Suma ≈ 1316.0
--     (vs 1316.26 de la P1: 0.25 MW operativos sin año). Control OK.
--   Prometido (Concept + Feasibility + FID/Construction): de 2024 a 2043.
--     Pico: 2030 = 176797 MW (≈ 177 GW). Suma con año ≈ 686116 MW.
--     Total prometido (P2) ≈ 1049718 MW → ≈ 364 GW (≈ 35 %) sin año.
-- Hallazgo: real y prometido no se superponen (corte de la base ≈ 2024).
--   Solo para 2030 se anuncia >100 veces todo lo construido en la historia.

-- P3 paso 3: real vs prometido, anual y ACUMULADO
WITH por_año AS (
    SELECT year_online                                                                   AS año,
           ROUND(SUM(capacity_mwel) FILTER (WHERE status = 'Operational'), 2)            AS mwel_real,
           ROUND(SUM(capacity_mwel) FILTER (WHERE status IN ('Concept','Feasibility study','FID/Construction')), 2) AS mwel_prometido
    FROM model.fact_projects
    WHERE year_online IS NOT NULL
    GROUP BY year_online
)
SELECT año,
       mwel_real,
       SUM(mwel_real) OVER (ORDER BY año)   AS real_acumulado,
       mwel_prometido,
       SUM(mwel_prometido) OVER (ORDER BY año)   AS prometido_acumulado
FROM por_año
ORDER BY año;


-- Resultado P3 paso 3:
--   real_acumulado final = 1316.00 (OK) | prometido_acumulado final = 686115.66 (OK)
--   84 % de lo real se construyó en 2021–2024 (≈ 1111 de 1316 MW).
--   Prometido acumulado a 2030 ≈ 510 GW (≈ 390 veces lo construido).

-- P4. Proyectos con fecha prevista vencida que todavía no operan
-- Vencido = estado prometido + año previsto anterior a 2024 (corte de la base)
SELECT status,
COUNT(*) AS proyectos_vencidos
FROM model.fact_projects
WHERE status IN ('Concept', 'Feasibility study', 'FID/Construction')
AND year_online <2024
GROUP BY status
ORDER BY proyectos_vencidos DESC;
-- Resultado P4: 1 proyecto (FID/Construction). La IEA actualiza fechas; medir demoras requiere comparar ediciones.}
-- P4 detalle: ¿cuál es el proyecto vencido?
SELECT project_name, country_code, year_online, capacity_mwel
FROM model.fact_projects
WHERE status IN ('Concept', 'Feasibility study', 'FID/Construction')
  AND year_online < 2024;


-- P5 paso 1: ¿qué combinaciones de tecnología y electricidad existen?
SELECT t.technology_group,
       f.electricity,
       COUNT(*) AS proyectos
FROM model.fact_projects AS f
JOIN model.dim_technology AS t ON f.technology = t.technology
GROUP BY t.technology_group, f.electricity
ORDER BY t.technology_group, proyectos DESC;

-- P5 paso 2a: clasificar cada proyecto en una ruta de producción
-- Control: las rutas suman 2434
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
    END            AS ruta,
      COUNT(*)                                                     AS total,
    COUNT(*) FILTER (WHERE f.status = 'Operational')                  AS operativos,
    COUNT(*) FILTER (WHERE f.status IN ('Concept', 'Feasibility study', 'FID/Construction'))       AS prometidos  
FROM model.fact_projects AS f
JOIN model.dim_technology AS t ON f.technology = t.technology
GROUP BY ruta
ORDER BY total DESC;

-- Resultado P5 (cuenta proyectos; la ruta fósil no tiene MWel):
--   Ruta                                 total | operativos | prometidos
--   Electrólisis con renovable dedicada   1292 |   142      |   1100
--   Electrólisis sin fuente informada      565 |    92      |    313
--   Electrólisis con red eléctrica         296 |    66      |    212
--   Fósil con captura de CO2               162 |    20      |    138
--   Otra / sin dato                        101 |    11      |     63
--   Electrólisis con nuclear                18 |     3      |      6
-- Control: total 2434 OK | operativos 334 OK | prometidos 1832 OK
--   (el control detectó el tipeo 'Cocept', que daba 1188 sin mostrar error).
-- Hallazgo: la renovable dedicada pasa del 42 % de lo operativo al 60 % de lo prometido;
--   la red baja del 20 % al 12 % y "sin fuente" del 28 % al 17 %.
--   El pipeline anunciado es más limpio que lo que hoy funciona.

-- Pregunta 6:Qué se produce (H2 o derivados) y para qué se usa
WITH por_producto AS (
SELECT d.sort_order,
d.product_label_es AS producto,
COUNT(*) AS proyectos,
ROUND(SUM(f.capacity_mwel), 2) AS mwel
FROM model.fact_projects AS f
JOIN model.dim_product AS d ON f.product = d.product
GROUP BY d.sort_order, d.product_label_es
)
SELECT producto,
proyectos,
ROUND(100.0 * proyectos / SUM(proyectos) OVER (), 1) AS pct_proyectos,
mwel,
ROUND(100.0 * mwel / SUM(mwel) OVER (), 1) AS pct_mwel
FROM por_producto
ORDER BY sort_order;

-- P6B. Usos finales del H2: cuántos proyectos declaran cada uso
-- Cuenta usos (un proyecto puede tener varios). Control: SUM(proyectos) = 2729
SELECT d.enduse_label_es                                      AS uso_final,
       COUNT(*)                                               AS proyectos,
       ROUND(100.0 * COUNT(*)
             / (SELECT COUNT(DISTINCT project_id) FROM model.bridge_enduse), 1)
                                                              AS pct_de_proyectos_con_uso
FROM model.bridge_enduse AS b
JOIN model.dim_enduse     AS d ON b.enduse = d.enduse
GROUP BY d.sort_order, d.enduse_label_es
ORDER BY proyectos DESC;

-- Resultado P6B: 14 usos, suman 2729 pares proyecto–uso (OK).
--   Movilidad 696 (36.5 %) | Otras industrias 427 (22.4 %) | Amoníaco 422 (22.1 %)
--   Generación eléctrica 257 (13.5 %) | Inyección a red de gas 171 (9.0 %)
--   Metanol 168 (8.8 %) | Refinación 154 (8.1 %) | Comb. sintéticos 132 (6.9 %)
--   Hierro y acero 108 (5.7 %) | resto < 4 % cada uno.
-- Los % son sobre 1908 proyectos con uso y suman > 100 % (un proyecto, varios usos).
-- Cuenta proyectos, no capacidad: no se suma MWel por uso.


-- P7. Ranking de países por capacidad (top 10)
-- Control: el puesto 1 es el país con más MWel; los % del ranking completo suman ≈ 100
WITH por_pais AS (
    SELECT c.country_name_es                                          AS pais,
           COUNT(*)                                                   AS proyectos,
           ROUND(SUM(f.capacity_mwel), 2)                             AS mwel,
           ROUND(100.0 * SUM(f.capacity_mwel)
                 / SUM(SUM(f.capacity_mwel)) OVER (), 1)              AS pct_mundial,
           RANK() OVER (ORDER BY SUM(f.capacity_mwel) DESC NULLS LAST) AS puesto
    FROM model.fact_projects AS f
    JOIN model.dim_country   AS c ON f.country_code = c.country_code
    GROUP BY c.country_name_es
)

-- Resultado P7 (puesto | país | proyectos | MWel | % mundial):
--   1 Australia 152 | 127205.18 | 12.1    6 Egipto          35 | 58174.59 | 5.5
--   2 Mauritania 10 |  94097.13 |  8.9    7 Estados Unidos 190 | 57683.43 | 5.5
--   3 Chile      69 |  70546.46 |  6.7    8 India          100 | 57441.46 | 5.5
--   4 España    169 |  63667.80 |  6.0    9 Brasil          42 | 57385.48 | 5.4
--   5 China     145 |  62457.57 |  5.9   10 Omán            23 | 32700.23 | 3.1
-- El top 10 concentra ≈ 64.6 % de la capacidad. Capacidad ≠ cantidad de proyectos.
SELECT puesto, pais, proyectos, mwel, pct_mundial
FROM por_pais
WHERE puesto<= 10
ORDER BY puesto;

-- P8. Argentina dentro de Latinoamérica y en el mundo
-- Control: 199 proyectos en LatAm; Chile = 1.º LatAm y 3.º mundial (P7); Argentina = 8 proyectos
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
-- Resultado P8 (puesto LatAm | puesto mundial | país | proyectos | MWel):
--    1 |  3 | Chile      69 | 70546.46     8 | 43 | Paraguay        10 | 2005.42
--    2 |  9 | Brasil     42 | 57385.48     9 | 51 | Uruguay          5 | 1178.16
--    3 | 20 | Argentina   8 | 15739.60    10 | 59 | Rep. Dominicana  1 |  350.00
--    4 | 21 | Colombia   35 | 14866.05    11 | 61 | Costa Rica       4 |  321.01
--    5 | 30 | México     14 |  5899.79    12 | 64 | Dominica         1 |  164.50
--    6 | 31 | Perú        7 |  5577.95    13 | 65 | Trinidad y T.    1 |  140.00
--    7 | 36 | Panamá      1 |  4675.23    14 | 79 | Barbados         1 |   15.00
-- Control: 14 países, 199 proyectos OK; Chile y Brasil coinciden con la P7.
-- Argentina: 3.ª LatAm, 20.ª mundo; 8 proyectos > Colombia (35). Solo 1 operativo (Hychico).