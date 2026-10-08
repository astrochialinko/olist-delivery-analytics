-- ============================================================
-- 04_tableau_exports.sql
-- Export curated datasets for Tableau
-- ============================================================

COPY (
    SELECT *
    FROM mart_order_analytics
    ORDER BY purchase_timestamp, order_id
)
TO 'data/processed/tableau_order_analytics.csv'
(
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ','
);

COPY (
    SELECT *
    FROM mart_item_sales
    ORDER BY purchase_timestamp, order_id, order_item_id
)
TO 'data/processed/tableau_item_sales.csv'
(
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ','
);

COPY (
    SELECT *
    FROM mart_order_category
    ORDER BY purchase_date, order_id, product_category
)
TO 'data/processed/tableau_order_category.csv'
(
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ','
);

-- Export validation summaries for documentation
COPY (
    SELECT *
    FROM dq_summary
    ORDER BY check_name
)
TO 'data/processed/data_quality_summary.csv'
(
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ','
);