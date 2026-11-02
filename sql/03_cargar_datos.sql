-- =============================================================================
-- 03_cargar_datos.sql
-- Proyecto H2 — Fase 2, paso 2.4
-- Carga los 10 CSV exportados en el 2.1 (copiados a C:/H2/).
-- Orden: dimensiones → fact → bridge → independientes (por las FOREIGN KEY).
-- =============================================================================

-- dim_status (esperado: 8 filas)
COPY model.dim_status
FROM 'C:/H2/dim_status.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);

-- Control dim_status: esperado 8
SELECT COUNT(*) AS filas FROM model.dim_status;

-- dim_technology (esperado: 13 filas)
COPY model.dim_technology
FROM 'C:/H2/dim_technology.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);

-- Control dim_technology: esperado 13
SELECT COUNT(*) AS filas FROM model.dim_technology;

-- dim_electricity (esperado: 7 filas)
COPY model.dim_electricity
FROM 'C:/H2/dim_electricity.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);
-- Control dim_electricity: esperado 7
SELECT COUNT(*) AS filas FROM model.dim_electricity;

-- dim_product (esperado: 8 filas)
COPY model.dim_product
FROM 'C:/H2/dim_product.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);

-- Control dim_product: esperado 8
SELECT COUNT(*) AS filas FROM model.dim_product;

-- dim_country (esperado: 97 filas)
COPY model.dim_country
FROM 'C:/H2/dim_country.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);

-- Control dim_country: esperado 97
SELECT COUNT(*) AS filas FROM model.dim_country;

-- dim_enduse (esperado: 14 filas)
COPY model.dim_enduse
FROM 'C:/H2/dim_enduse.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);
-- Control dim_enduse: esperado 14
SELECT COUNT(*) AS filas FROM model.dim_enduse;

-- fact_projects (esperado: 2434 filas). Va después de las 5 dimensiones (FK)
COPY model.fact_projects
FROM 'C:/H2/fact_projects.csv'
WITH (
    FORMAT csv,         -- archivo CSV (respeta comillas en textos con comas)
    HEADER MATCH,       -- 1ª fila = encabezado, y DEBE coincidir con las columnas de la tabla
    ENCODING 'UTF8'     -- tildes y ñ correctas (así lo exportó Python)
);

-- Control fact_projects: esperado 2434
SELECT COUNT(*) AS filas FROM model.fact_projects;

-- bridge_enduse (esperado: 2729 filas). Va después de fact_projects y dim_enduse (FK)
COPY model.bridge_enduse
FROM 'C:/H2/bridge_enduse.csv'
WITH (
    FORMAT csv,
    HEADER MATCH,
    ENCODING 'UTF8'
);

-- Control bridge_enduse: esperado 2729
SELECT COUNT(*) AS filas FROM model.bridge_enduse;

-- agg_confidential (esperado: 7 filas). Tabla independiente, sin FK
COPY model.agg_confidential
FROM 'C:/H2/agg_confidential.csv'
WITH (
    FORMAT csv,
    HEADER MATCH,
    ENCODING 'UTF8'
);

-- Control agg_confidential: esperado 7
SELECT COUNT(*) AS filas FROM model.agg_confidential;

-- dq_dictionary (esperado: 80 filas). Ojo: esquema dq, no model
COPY dq.dq_dictionary
FROM 'C:/H2/dq_dictionary.csv'
WITH (
    FORMAT csv,
    HEADER MATCH,
    ENCODING 'UTF8'
);

-- Control dq_dictionary: esperado 80
SELECT COUNT(*) AS filas FROM dq.dq_dictionary;

-- =============================================================================
-- CONTROL DE CIERRE 2.4: fact + agg = filas del CSV original. Esperado 2441
-- =============================================================================
SELECT (SELECT COUNT(*) FROM model.fact_projects)
     + (SELECT COUNT(*) FROM model.agg_confidential) AS total_filas;