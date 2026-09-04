BEGIN;


CREATE TABLE IF NOT EXISTS dim_product (
    product_key          BIGSERIAL PRIMARY KEY,
    product_code          TEXT NOT NULL UNIQUE,     
    product_name           TEXT NOT NULL,             
    generic                 TEXT NOT NULL,
    strength                 TEXT NOT NULL,        
    form                      TEXT NOT NULL,
    category                  TEXT NOT NULL,
    pack_size                  INTEGER NOT NULL CHECK (pack_size > 0),
    unit_price                  NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    reorder_level_packs          INTEGER NOT NULL CHECK (reorder_level_packs >= 0),  -- CONFIRMED: stated in packs, not loose units
    CONSTRAINT uq_product_generic_strength_form UNIQUE (generic, strength, form)
);

COMMENT ON COLUMN dim_product.reorder_level_packs IS 'Reorder threshold in PACKS as stored in erp_products.csv. Multiply by pack_size before comparing against loose-unit stock figures.';

COMMENT ON TABLE dim_product IS 'Conformed product dimension. Canonical row per medicine/strength/form combination.';

-- ----------------------------------------------------------------------------
-- Conformed dimension: branch
-- One row per physical branch. branch_id is the ERP branch id; every free-text
-- branch string in stock_counts resolves here (Kum Mary's branch resolver).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_branch (
    branch_key      BIGSERIAL PRIMARY KEY,
    branch_id       TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    town            TEXT NOT NULL,
    region          TEXT NOT NULL,
    opened_year     SMALLINT NOT NULL CHECK (opened_year BETWEEN 1990 AND 2100),
    staff_count     SMALLINT NOT NULL CHECK (staff_count >= 0)
);

COMMENT ON TABLE dim_branch IS 'Conformed branch dimension. 16 branches across 6 regions.';


CREATE TABLE IF NOT EXISTS fact_sales (
    sale_key            BIGSERIAL PRIMARY KEY,
    branch_key          BIGINT NOT NULL REFERENCES dim_branch(branch_key),
    product_key         BIGINT NOT NULL REFERENCES dim_product(product_key),
    sold_on             DATE NOT NULL,
    quantity_units      INTEGER NOT NULL CHECK (quantity_units >= 0),
    unit_price          NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    payment_method      TEXT NOT NULL,
    source_ref          TEXT NOT NULL,     -- original product_ref as it appeared on the till, for traceability
    source_ref_type     TEXT NOT NULL,     -- 'erp_code' | 'legacy_code' | 'typed_name'
    resolution_method   TEXT NOT NULL      -- which resolver rule fired
);

CREATE INDEX IF NOT EXISTS ix_fact_sales_branch_date ON fact_sales (branch_key, sold_on);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product_date ON fact_sales (product_key, sold_on);

COMMENT ON TABLE fact_sales IS 'Grain: one row per till transaction line. ~150,400 rows expected.';


CREATE TABLE IF NOT EXISTS fact_stock_count (
    count_key               BIGSERIAL PRIMARY KEY,
    branch_key               BIGINT NOT NULL REFERENCES dim_branch(branch_key),
    product_key               BIGINT REFERENCES dim_product(product_key),
    counted_on               DATE NOT NULL,
    quantity_units            INTEGER NOT NULL CHECK (quantity_units >= 0),  -- normalised to loose units at load time
    quantity_units_raw         NUMERIC(10,2) NOT NULL,                       -- as typed, before pack/unit normalisation
    quantity_unit_raw         TEXT NOT NULL,                                 -- 'pack' | 'unit' as typed
    counted_by                TEXT NOT NULL,
    typed_branch_raw          TEXT NOT NULL,   -- original free-text branch string
    typed_description_raw     TEXT NOT NULL,   -- original free-text item description
    resolution_method         TEXT NOT NULL,   -- 'exact' | 'fuzzy' | 'escalated'
    resolution_confidence     TEXT NOT NULL CHECK (resolution_confidence IN ('auto','fallback','escalated'))
);

CREATE INDEX IF NOT EXISTS ix_fact_stock_count_branch_date ON fact_stock_count (branch_key, counted_on);

COMMENT ON TABLE fact_stock_count IS 'Grain: one row per manual stock-count line. ~5,348 rows expected. NULL product_key = escalated, see reports/escalations.csv.';


CREATE TABLE IF NOT EXISTS fact_delivery (
    delivery_key         BIGSERIAL PRIMARY KEY,
    branch_key             BIGINT NOT NULL REFERENCES dim_branch(branch_key),  -- CONFIRMED present in source, corrected from earlier chain-level assumption
    product_key           BIGINT NOT NULL REFERENCES dim_product(product_key),
    delivered_on          DATE NOT NULL,             -- CONFIRMED present in source
    supplier                TEXT NOT NULL,             -- source column: supplier (e.g. "Pharmapro", "CENAME")
    supplier_item_code    TEXT NOT NULL,             -- source column: supplier_id (e.g. "U31674") — the supplier's own item code
    supplier_item_name     TEXT NOT NULL,             -- source column: supplier_item — free-text description, used as resolver fallback
    cartons                INTEGER NOT NULL CHECK (cartons > 0),
    units_per_carton       INTEGER NOT NULL CHECK (units_per_carton > 0),
    quantity_units          INTEGER NOT NULL CHECK (quantity_units >= 0),  -- = cartons * units_per_carton, normalised at load
    invoice_value            NUMERIC(12,2) NOT NULL CHECK (invoice_value >= 0),
    batch                    TEXT NOT NULL,
    expiry                    DATE NOT NULL,
    resolution_method        TEXT NOT NULL   -- 'code_map' | 'unmapped_escalated'
);

CREATE INDEX IF NOT EXISTS ix_fact_delivery_branch_date ON fact_delivery (branch_key, delivered_on);
CREATE INDEX IF NOT EXISTS ix_fact_delivery_product_date ON fact_delivery (product_key, delivered_on);

COMMENT ON TABLE fact_delivery IS 'Grain: one row per delivery-note line. ~1,887 rows expected.';


CREATE TABLE IF NOT EXISTS fact_wastage (
    wastage_key       BIGSERIAL PRIMARY KEY,
    product_key         BIGINT NOT NULL REFERENCES dim_product(product_key),
    branch_key           BIGINT NOT NULL REFERENCES dim_branch(branch_key),  -- CONFIRMED present in source
    recorded_on           DATE NOT NULL,                                     -- CONFIRMED present in source; matches source column name
    quantity_units          INTEGER NOT NULL CHECK (quantity_units >= 0),
    reason                  TEXT NOT NULL,
    batch                    TEXT NOT NULL,
    approved_by              TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_fact_wastage_branch_date ON fact_wastage (branch_key, recorded_on);

COMMENT ON TABLE fact_wastage IS 'Grain: one row per wastage record. ~500 rows expected.';

 

COMMIT;