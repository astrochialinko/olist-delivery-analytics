-- ============================================================
-- 00_source_views.sql
--
-- Purpose:
--   Create DuckDB views over the raw Olist CSV files.
--   Raw data is not modified; cleaning and aggregation are
--   handled in downstream SQL scripts.
--
-- Pipeline:
--   Raw CSV -> Source Views -> Data Quality -> Analytics
-- ============================================================
CREATE OR REPLACE VIEW customers AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_customers_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW orders AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_orders_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW order_items AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_order_items_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW order_payments AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_order_payments_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW order_reviews AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_order_reviews_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW products AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_products_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW sellers AS
SELECT * FROM read_csv_auto(
    'data/raw/olist_sellers_dataset.csv',
    header = true
);

CREATE OR REPLACE VIEW category_translation AS
SELECT * FROM read_csv_auto(
    'data/raw/product_category_name_translation.csv',
    header = true
);

CREATE OR REPLACE VIEW geolocation AS
SELECT *
FROM read_csv_auto(
    'data/raw/olist_geolocation_dataset.csv',
    header = true
);