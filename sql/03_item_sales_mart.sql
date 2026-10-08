-- ============================================================
-- 03_item_sales_mart.sql
-- mart_item_sales grain: one row per order item
-- mart_order_category grain: one row per order and category
-- ============================================================

CREATE OR REPLACE TABLE mart_item_sales AS

SELECT
    oi.order_id,
    oi.order_item_id,

    oa.customer_unique_id,
    oa.customer_state,
    oa.customer_city,

    oa.order_status,
    oa.purchase_timestamp,
    oa.purchase_date,
    oa.purchase_month,

    oi.product_id,

    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'unknown'
    ) AS product_category,

    p.product_category_name AS product_category_portuguese,
    p.product_name_lenght AS product_name_length,
    p.product_description_lenght AS product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    CASE
        WHEN p.product_length_cm IS NOT NULL
         AND p.product_height_cm IS NOT NULL
         AND p.product_width_cm IS NOT NULL
        THEN
            p.product_length_cm
            * p.product_height_cm
            * p.product_width_cm
    END AS product_volume_cm3,

    oi.seller_id,
    s.seller_city,
    s.seller_state,

    TRY_CAST(oi.shipping_limit_date AS TIMESTAMP)
        AS shipping_limit_timestamp,

    oi.price AS item_revenue,
    oi.freight_value AS item_freight_value,
    oi.price + oi.freight_value AS item_total_value,

    oa.delivery_days,
    oa.promised_delivery_days,
    oa.signed_delay_days,
    oa.days_late,
    oa.is_late,
    oa.delivery_status,
    oa.delay_bucket,

    oa.review_score,
    oa.negative_review

FROM order_items oi

INNER JOIN mart_order_analytics oa
    ON oi.order_id = oa.order_id

LEFT JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation pct
    ON p.product_category_name = pct.product_category_name

LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
;

-- One row per order item validation
SELECT
    COUNT(*) AS mart_rows,
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
        AS duplicate_item_rows
FROM mart_item_sales;

-- Revenue reconciliation
SELECT
    (SELECT SUM(price) FROM order_items)
        AS raw_item_revenue,

    (SELECT SUM(item_revenue) FROM mart_item_sales)
        AS mart_item_revenue,

    (SELECT SUM(freight_value) FROM order_items)
        AS raw_freight_value,

    (SELECT SUM(item_freight_value) FROM mart_item_sales)
        AS mart_freight_value;


-- ------------------------------------------------------------
-- Order-category mart
-- Prevents multiple items in the same category from overweighting
-- delivery and review metrics.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE mart_order_category AS

SELECT
    order_id,
    customer_unique_id,
    customer_state,
    customer_city,

    order_status,
    purchase_date,
    purchase_month,

    product_category,

    is_late,
    delivery_status,
    delay_bucket,
    delivery_days,
    promised_delivery_days,
    signed_delay_days,
    days_late,

    review_score,
    negative_review,

    COUNT(*) AS category_item_count,
    COUNT(DISTINCT product_id) AS category_product_count,
    COUNT(DISTINCT seller_id) AS category_seller_count,

    SUM(item_revenue) AS category_revenue,
    SUM(item_freight_value) AS category_freight_value,
    SUM(item_total_value) AS category_total_value

FROM mart_item_sales

GROUP BY
    order_id,
    customer_unique_id,
    customer_state,
    customer_city,
    order_status,
    purchase_date,
    purchase_month,
    product_category,
    is_late,
    delivery_status,
    delay_bucket,
    delivery_days,
    promised_delivery_days,
    signed_delay_days,
    days_late,
    review_score,
    negative_review
;

-- One row per order-category validation
SELECT
    COUNT(*) AS mart_rows,
    COUNT(*) - COUNT(DISTINCT (order_id, product_category))
        AS duplicate_order_category_rows
FROM mart_order_category;