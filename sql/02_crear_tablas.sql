-- =============================================================================
-- 02_crear_tablas.sql
-- Proyecto H2 — Fase 2, paso 2.3
-- Crea las tablas del modelo estrella en el esquema "model".
-- Orden: dimensiones → fact → bridge → tablas independientes (por las FOREIGN KEY).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_status (8 filas): estados del proyecto y su orden en el pipeline
-- -----------------------------------------------------------------------------
CREATE TABLE model.dim_status (
    status             TEXT     PRIMARY KEY,   -- clave: 'Operational', 'Concept'... (no se repite, no vacía)
    status_label_es    TEXT     NOT NULL,      -- etiqueta en español; toda fila DEBE tenerla
    status_order       INTEGER,                -- posición en el pipeline; SIN NOT NULL porque
                                               -- DEMO, Other/Unknown y Not reported van vacíos
    is_pipeline_stage  BOOLEAN  NOT NULL,      -- true/false (así lo exportó Python)
    sort_order         INTEGER  NOT NULL UNIQUE, -- orden para gráficos 1..8; UNIQUE: dos estados
                                                 -- no pueden ocupar la misma posición

    -- Reglas de negocio (el "patovica"):
    CONSTRAINT chk_status_order_positivo CHECK (status_order >= 1),
    CONSTRAINT chk_sort_order_rango      CHECK (sort_order BETWEEN 1 AND 8)
);

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'dim_status'
ORDER BY ordinal_position;

-- Prueba: debe ser RECHAZADA por chk_sort_order_rango
-- INSERT INTO model.dim_status VALUES ('Prueba', 'Prueba', NULL, false, 99);

-- -----------------------------------------------------------------------------
-- dim_technology (13 filas): tecnologías de producción y su grupo
-- -----------------------------------------------------------------------------
CREATE TABLE model.dim_technology (
    technology           TEXT     PRIMARY KEY,
    technology_label_es  TEXT     NOT NULL,
    tech_specified       BOOLEAN  NOT NULL,
    technology_group     TEXT     NOT NULL,
    technology_group_es  TEXT     NOT NULL,
    -- Reglas de negocio: los grupos no tienen tabla propia → los protege un CHECK
    CONSTRAINT chk_technology_group    CHECK (technology_group IN ('Electrolysis','Fossil fuels with CCUS','Not reported','Other')),
    CONSTRAINT chk_technology_group_es CHECK (technology_group_es IN ('Electrólisis','Combustibles fósiles con CCUS','Sin dato','Otras tecnologías'))
);

-- Control dim_technology: esperado 5 columnas, todas NOT NULL
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'dim_technology'
ORDER BY ordinal_position;

-- Prueba: debe ser RECHAZADA por chk_technology_group
-- INSERT INTO model.dim_technology VALUES ('Prueba', 'Prueba', FALSE, 'nuclear', 'Sin dato');
  -- 
  
  -----------------------------------------------------------------------------
  -- dim_electricity (7 filas): fuente de electricidad del proyecto
  -- Sin CHECK: la tabla ES el catálogo; la protegen la PK y la FK desde fact_projects
  -- -----------------------------------------------------------------------------
CREATE TABLE model.dim_electricity (
    electricity TEXT PRIMARY KEY,
	electricity_label_es TEXT NOT NULL
);
-- Control dim_electricity: esperado 2 columnas, todas NOT NULL
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'dim_electricity'
ORDER BY ordinal_position;
 -----------------------------------------------------------------------------
  -- dim_product (8 filas):Producto final del proyecto
  -- -----------------------------------------------------------------------------
CREATE TABLE model.dim_product (
    product TEXT PRIMARY KEY,
	product_label_es TEXT NOT NULL,
	sort_order INTEGER NOT NULL UNIQUE,
 CONSTRAINT chk_sort_order_rango CHECK (sort_order BETWEEN 1 AND 8)	
);

-- Control dim_product: esperado 3 columnas, todas NOT NULL 
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'dim_product'
ORDER BY ordinal_position;

-- Prueba: debe ser RECHAZADA por chk_sort_order_rango (sort_order fuera de 1..8)
--INSERT INTO model.dim_product VALUES ('Prueba', 'Prueba', 99);

-- dim_country (97 filas): países, región y grupo de foco
CREATE TABLE model.dim_country (
    country_code TEXT PRIMARY KEY,
	country_name_es TEXT NOT NULL,
	region_es TEXT NOT NULL,
	subregion_es TEXT NOT NULL,
	is_latam BOOLEAN NOT NULL,
	focus_group TEXT NOT NULL,

CONSTRAINT chk_region_es CHECK (region_es IN ('Europa','África','Asia','América Latina y el Caribe','Oceanía','América del Norte')),
CONSTRAINT chk_focus_group CHECK (focus_group IN ('Resto del mundo','Argentina','Resto de Latinoamérica'))
);

-- Control dim_country: esperado 6 columnas, todas NOT NULL 
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'dim_country'
ORDER BY ordinal_position;

-- Prueba: debe ser RECHAZADA por chk_region_es (region_es diferente a los valores designados)
--INSERT INTO model.dim_country VALUES ('Prueba', 'Prueba','America','Prueba','Prueba','Prueba');

-----------------------------------------------------------------------------
  -- dim_enduse (14 filas): usos finales del hidrógeno (refinería, amoníaco, movilidad…)
  -- -----------------------------------------------------------------------------
CREATE TABLE model.dim_enduse (
    enduse TEXT PRIMARY KEY,
	enduse_label_es TEXT NOT NULL,
	sort_order INTEGER NOT NULL UNIQUE,
  CONSTRAINT chk_sort_order_rango CHECK (sort_order BETWEEN 1 AND 14)
);
-- Control dim_enduse: esperado 3 columnas, todas NOT NULL 
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'dim_enduse'
ORDER BY ordinal_position;

-- Prueba: debe ser RECHAZADA por chk_sort_order_rango (sort_order fuera de 1..14)
--INSERT INTO model.dim_enduse VALUES ('Prueba','Prueba',99)
-- -----------------------------------------------------------------------------
-- fact_projects (2434 filas): un proyecto de hidrógeno por fila
-- Tabla central del modelo estrella; apunta a 5 dimensiones.
-- (dim_enduse se conecta a través de bridge_enduse: relación muchos a muchos)
-- -----------------------------------------------------------------------------
CREATE TABLE model.fact_projects (

    -- ===== PARTE 1: COLUMNAS (mismo orden que el CSV) =====================

    -- Identificación
    project_id                        INTEGER   PRIMARY KEY,  -- clave sustituta creada en PQ (arranca en 8)
    ref_iea                           INTEGER,                -- ID original de la IEA (puede repetirse: ver ref_duplicated)
    source_row                        INTEGER   NOT NULL,     -- fila del CSV original (trazabilidad)
    project_name                      TEXT,

    -- Claves hacia las dimensiones (se validan en la PARTE 2)
    country_code                      TEXT,                   -- vacío permitido: proyectos sin país informado
    status                            TEXT      NOT NULL,     -- los vacíos ya son 'Not reported' (PQ)
    technology                        TEXT      NOT NULL,
    electricity                       TEXT      NOT NULL,
    product                           TEXT      NOT NULL,

    -- Descriptivas (texto libre)
    countries_all                     TEXT,
    technology_details                TEXT,
    electricity_details               TEXT,
    announced_size                    TEXT,                   -- tamaño anunciado tal cual (ej.: '100 MW')

    -- Fechas (solo el año)
    year_online                       INTEGER,                -- 555 vacíos (77,2 % completo)
    year_decommission                 INTEGER,

    -- Capacidades: NUMERIC = decimales exactos, sin redondeo
    capacity_mwel                     NUMERIC,
    capacity_nm3_h2_h                 NUMERIC,
    capacity_kt_h2_y                  NUMERIC,
    capacity_t_co2_captured_y         NUMERIC,
    iea_zero_carbon_capacity_nm3_h2_h NUMERIC,
    lowe_cf                           NUMERIC,

    -- Ubicación
    latitude                          NUMERIC,                -- 348 vacíos
    longitude                         NUMERIC,

    -- Banderas de calidad creadas en PQ ("marcar en lugar de borrar")
    is_multicountry                   BOOLEAN   NOT NULL,
    has_location                      BOOLEAN   NOT NULL,
    has_capacity                      BOOLEAN   NOT NULL,
    has_enduse                        BOOLEAN   NOT NULL,
    possible_duplicate                BOOLEAN   NOT NULL,
    ref_duplicated                    BOOLEAN   NOT NULL,

    -- ===== PARTE 2: FOREIGN KEY (equivale a tu chk_4a de huérfanos) =======
    CONSTRAINT fk_fact_country     FOREIGN KEY (country_code) REFERENCES model.dim_country (country_code),
    CONSTRAINT fk_fact_status      FOREIGN KEY (status)       REFERENCES model.dim_status (status),
    CONSTRAINT fk_fact_technology  FOREIGN KEY (technology)   REFERENCES model.dim_technology (technology),
    CONSTRAINT fk_fact_electricity FOREIGN KEY (electricity)  REFERENCES model.dim_electricity (electricity),
    CONSTRAINT fk_fact_product     FOREIGN KEY (product)      REFERENCES model.dim_product (product),

    -- ===== PARTE 3: CHECK (reglas de rango; los NULL pasan) ===============
    CONSTRAINT chk_fact_latitude        CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT chk_fact_longitude       CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_fact_year_online     CHECK (year_online       BETWEEN 1900 AND 2100),
    CONSTRAINT chk_fact_year_decom      CHECK (year_decommission BETWEEN 1900 AND 2100),
    CONSTRAINT chk_fact_mwel_positiva   CHECK (capacity_mwel    >= 0),
    CONSTRAINT chk_fact_kt_positiva     CHECK (capacity_kt_h2_y >= 0)
);

-- Control 1 fact_projects: esperado 29 columnas
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'fact_projects'
ORDER BY ordinal_position;

-- Control 2 fact_projects: reglas creadas. Esperado 12 = 1 PK + 5 FK + 6 CHECK
SELECT constraint_type, constraint_name
FROM information_schema.table_constraints
WHERE table_schema = 'model' AND table_name = 'fact_projects'
  AND (constraint_type <> 'CHECK' OR constraint_name LIKE 'chk%')
ORDER BY constraint_type, constraint_name;

-- bridge_enduse (2729 filas): usos finales por proyecto (muchos a muchos)
CREATE TABLE model.bridge_enduse(
    project_id INTEGER NOT NULL,
	enduse TEXT NOT NULL,
CONSTRAINT pk_bridge_enduse PRIMARY KEY (project_id,enduse),
CONSTRAINT fk_bridge_project FOREIGN KEY (project_id) REFERENCES model.fact_projects (project_id),
CONSTRAINT fk_bridge_enduse FOREIGN KEY (enduse) REFERENCES model.dim_enduse (enduse)
);

-- Control 1 bridge_enduse: esperado 2 columnas
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'bridge_enduse'
ORDER BY ordinal_position;

-- Control 2 bridge_enduse: reglas creadas. Esperado 3 = 1 PK + 2 FK 
SELECT constraint_type, constraint_name
FROM information_schema.table_constraints
WHERE table_schema = 'model' AND table_name = 'bridge_enduse'
  AND (constraint_type <> 'CHECK' OR constraint_name LIKE 'chk%')
ORDER BY constraint_type, constraint_name;

-- -----------------------------------------------------------------------------
-- agg_confidential (7 filas): proyectos agregados/confidenciales de la IEA
-- Tabla independiente (sin FK): tiene categorías propias (ej. 'ALK & PEM').
-- Conciliación: 2434 (fact) + 7 (agg) = 2441 filas del CSV original.
-- -----------------------------------------------------------------------------
CREATE TABLE model.agg_confidential(
    project_id INTEGER PRIMARY KEY,
	source_row INTEGER NOT NULL,
	description TEXT NOT NULL,
	status      TEXT NOT NULL,
	technology  TEXT NOT NULL,
	technology_aggregate TEXT NOT NULL,
	announced_size TEXT NOT NULL,
	capacity_mwel NUMERIC,
	capacity_nm3_h2_h NUMERIC,
	capacity_kt_h2_y NUMERIC,

 CONSTRAINT chk_project_id CHECK (project_id BETWEEN 1 AND 7)
 );

-- Control 1 agg_confidential: esperado 10 columnas; solo las 3 capacidades admiten NULL 
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'model' AND table_name = 'agg_confidential'
ORDER BY ordinal_position;

 -- -----------------------------------------------------------------------------
-- dq_dictionary (80 filas): diccionario de datos (qué significa cada columna)
-- Va en el esquema dq: es información SOBRE los datos, no datos del modelo.
-- -----------------------------------------------------------------------------
CREATE TABLE dq.dq_dictionary (
    tabla              TEXT     NOT NULL,   -- nombre de la tabla descrita (ej. 'fact_projects')
    descripcion_tabla  TEXT,                -- se repite en cada fila de la misma tabla
    posicion           INTEGER  NOT NULL,   -- orden de la columna dentro de su tabla
    columna            TEXT     NOT NULL,   -- nombre de la columna descrita
    tipo_dato          TEXT     NOT NULL,   -- tipo de dato documentado
    descripcion        TEXT,                -- qué significa la columna
    origen             TEXT,                -- de dónde viene (CSV original, calculada en PQ…)

    -- PK compuesta: una columna aparece una sola vez por tabla
    CONSTRAINT pk_dq_dictionary PRIMARY KEY (tabla, columna),
    CONSTRAINT chk_dq_posicion  CHECK (posicion >= 1)
);

-- Control 1 dq_dictionary: esperado 7 columnas
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'dq' AND table_name = 'dq_dictionary'
ORDER BY ordinal_position;

-- Control 2 dq_dictionary: reglas creadas. Esperado 2 = 1 PK + 1 CHECK
SELECT constraint_type, constraint_name
FROM information_schema.table_constraints
WHERE table_schema = 'dq' AND table_name = 'dq_dictionary'
  AND (constraint_type <> 'CHECK' OR constraint_name LIKE 'chk%')
ORDER BY constraint_type, constraint_name;

