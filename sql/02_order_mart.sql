-- ============================================================
-- 02_order_mart.sql
-- Grain: one row per order
-- ============================================================

CREATE OR REPLACE TABLE mart_order_analytics AS

WITH typed_orders AS (
    SELECT
        order_id,
        customer_id,
        order_status,
        TRY_CAST(order_purchase_timestamp AS TIMESTAMP)
            AS purchase_timestamp,
        TRY_CAST(order_approved_at AS TIMESTAMP)
            AS approved_timestamp,
        TRY_CAST(order_delivered_carrier_date AS TIMESTAMP)
            AS carrier_timestamp,
        TRY_CAST(order_delivered_customer_date AS TIMESTAMP)
            AS delivered_timestamp,
        TRY_CAST(order_estimated_delivery_date AS TIMESTAMP)
            AS estimated_delivery_timestamp
    FROM orders
),

item_agg AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT product_id) AS product_count,
        COUNT(DISTINCT seller_id) AS seller_count,
        SUM(price) AS product_revenue,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
),

payment_agg AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        COUNT(DISTINCT payment_type) AS payment_type_count,
        STRING_AGG(DISTINCT payment_type, ', ') AS payment_types,
        MAX(payment_installments) AS max_payment_installments,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id
),

review_ranked AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        TRY_CAST(review_creation_date AS TIMESTAMP)
            AS review_creation_timestamp,
        TRY_CAST(review_answer_timestamp AS TIMESTAMP)
            AS review_answer_timestamp,

        COUNT(*) OVER (
            PARTITION BY order_id
        ) AS review_record_count,

        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                TRY_CAST(review_answer_timestamp AS TIMESTAMP)
                    DESC NULLS LAST,
                TRY_CAST(review_creation_date AS TIMESTAMP)
                    DESC NULLS LAST,
                review_id DESC
        ) AS review_rank
    FROM order_reviews
),

review_latest AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_timestamp,
        review_answer_timestamp,
        review_record_count
    FROM review_ranked
    WHERE review_rank = 1
)

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,

    o.order_status,

    o.purchase_timestamp,
    CAST(o.purchase_timestamp AS DATE) AS purchase_date,
    CAST(
        DATE_TRUNC('month', o.purchase_timestamp)
        AS DATE
    ) AS purchase_month,
    DAYNAME(o.purchase_timestamp) AS purchase_weekday,
    CAST(EXTRACT(hour FROM o.purchase_timestamp) AS INTEGER)
        AS purchase_hour,

    o.approved_timestamp,
    o.carrier_timestamp,
    o.delivered_timestamp,
    o.estimated_delivery_timestamp,

    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,

    ia.item_count,
    ia.product_count,
    ia.seller_count,
    ia.product_revenue,
    ia.freight_value,

    pa.payment_record_count,
    pa.payment_type_count,
    pa.payment_types,
    pa.max_payment_installments,
    pa.payment_value,

    rl.review_id,
    rl.review_score,
    rl.review_record_count,
    rl.review_comment_title,
    rl.review_comment_message,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.purchase_timestamp IS NOT NULL
         AND o.delivered_timestamp IS NOT NULL
        THEN DATE_DIFF(
            'day',
            CAST(o.purchase_timestamp AS DATE),
            CAST(o.delivered_timestamp AS DATE)
        )
    END AS delivery_days,

    CASE
        WHEN o.purchase_timestamp IS NOT NULL
         AND o.estimated_delivery_timestamp IS NOT NULL
        THEN DATE_DIFF(
            'day',
            CAST(o.purchase_timestamp AS DATE),
            CAST(o.estimated_delivery_timestamp AS DATE)
        )
    END AS promised_delivery_days,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.delivered_timestamp IS NOT NULL
         AND o.estimated_delivery_timestamp IS NOT NULL
        THEN DATE_DIFF(
            'day',
            CAST(o.estimated_delivery_timestamp AS DATE),
            CAST(o.delivered_timestamp AS DATE)
        )
    END AS signed_delay_days,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.delivered_timestamp IS NOT NULL
         AND o.estimated_delivery_timestamp IS NOT NULL
        THEN GREATEST(
            DATE_DIFF(
                'day',
                CAST(o.estimated_delivery_timestamp AS DATE),
                CAST(o.delivered_timestamp AS DATE)
            ),
            0
        )
    END AS days_late,

    CASE
        WHEN o.order_status <> 'delivered'
            THEN NULL
        WHEN o.delivered_timestamp IS NULL
          OR o.estimated_delivery_timestamp IS NULL
            THEN NULL
        ELSE o.delivered_timestamp
             > o.estimated_delivery_timestamp
    END AS is_late,

    CASE
        WHEN o.order_status <> 'delivered'
            THEN 'Not delivered'
        WHEN o.delivered_timestamp IS NULL
          OR o.estimated_delivery_timestamp IS NULL
            THEN 'Missing delivery date'
        WHEN o.delivered_timestamp
             > o.estimated_delivery_timestamp
            THEN 'Late'
        ELSE 'On time or early'
    END AS delivery_status,

    CASE
        WHEN rl.review_score IS NULL THEN NULL
        WHEN rl.review_score <= 2 THEN TRUE
        ELSE FALSE
    END AS negative_review,

    CASE
        WHEN o.order_status <> 'delivered'
            THEN 'Not delivered'
        WHEN o.delivered_timestamp IS NULL
          OR o.estimated_delivery_timestamp IS NULL
            THEN 'Missing delivery date'
        WHEN o.delivered_timestamp
             <= o.estimated_delivery_timestamp
            THEN 'On time or early'
        WHEN DATE_DIFF(
            'day',
            CAST(o.estimated_delivery_timestamp AS DATE),
            CAST(o.delivered_timestamp AS DATE)
        ) BETWEEN 1 AND 3
            THEN '1-3 days late'
        WHEN DATE_DIFF(
            'day',
            CAST(o.estimated_delivery_timestamp AS DATE),
            CAST(o.delivered_timestamp AS DATE)
        ) BETWEEN 4 AND 7
            THEN '4-7 days late'
        WHEN DATE_DIFF(
            'day',
            CAST(o.estimated_delivery_timestamp AS DATE),
            CAST(o.delivered_timestamp AS DATE)
        ) BETWEEN 8 AND 14
            THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_bucket,

    ia.order_id IS NOT NULL AS has_item_record,
    pa.order_id IS NOT NULL AS has_payment_record,
    rl.order_id IS NOT NULL AS has_review_record

FROM typed_orders o

LEFT JOIN customers c
    ON o.customer_id = c.customer_id

LEFT JOIN item_agg ia
    ON o.order_id = ia.order_id

LEFT JOIN payment_agg pa
    ON o.order_id = pa.order_id

LEFT JOIN review_latest rl
    ON o.order_id = rl.order_id
;

-- One-row-per-order validation
SELECT
    COUNT(*) AS mart_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_rows
FROM mart_order_analytics;

-- Revenue reconciliation
SELECT
    (SELECT SUM(price) FROM order_items)
        AS raw_item_revenue,

    (SELECT SUM(product_revenue)
     FROM mart_order_analytics)
        AS mart_item_revenue,

    (SELECT SUM(freight_value) FROM order_items)
        AS raw_freight_value,

    (SELECT SUM(freight_value)
     FROM mart_order_analytics)
        AS mart_freight_value;