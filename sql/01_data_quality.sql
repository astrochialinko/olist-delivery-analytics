-- ============================================================
-- 01_data_quality.sql
-- 
-- Purpose:
--   Inspect row counts, key uniqueness, join coverage,
--   date ranges, status distributions, and one-to-many relations.
-- ============================================================
-- 1. Reusable data quality summary
CREATE OR REPLACE VIEW dq_summary AS

-- Row counts
SELECT
    'orders.row_count' AS check_name,
    CAST(COUNT(*) AS VARCHAR) AS observed_value,
    '> 0' AS expected_condition
FROM orders

UNION ALL

SELECT
    'customers.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM customers

UNION ALL

SELECT
    'order_items.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM order_items

UNION ALL

SELECT
    'payments.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM order_payments

UNION ALL

SELECT
    'reviews.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM order_reviews

UNION ALL

SELECT
    'products.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM products

UNION ALL

SELECT
    'sellers.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM sellers

UNION ALL

SELECT
    'geolocation.row_count',
    CAST(COUNT(*) AS VARCHAR),
    '> 0'
FROM geolocation


-- Primary / composite key checks
UNION ALL

SELECT
    'orders.duplicate_order_ids',
    CAST(
        COUNT(*) - COUNT(DISTINCT order_id)
        AS VARCHAR
    ),
    '= 0'
FROM orders

UNION ALL

SELECT
    'customers.duplicate_customer_ids',
    CAST(
        COUNT(*) - COUNT(DISTINCT customer_id)
        AS VARCHAR
    ),
    '= 0'
FROM customers

UNION ALL

SELECT
    'products.duplicate_product_ids',
    CAST(
        COUNT(*) - COUNT(DISTINCT product_id)
        AS VARCHAR
    ),
    '= 0'
FROM products

UNION ALL

SELECT
    'sellers.duplicate_seller_ids',
    CAST(
        COUNT(*) - COUNT(DISTINCT seller_id)
        AS VARCHAR
    ),
    '= 0'
FROM sellers

UNION ALL

SELECT
    'order_items.duplicate_key_groups',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM (
    SELECT
        order_id,
        order_item_id
    FROM order_items
    GROUP BY
        order_id,
        order_item_id
    HAVING COUNT(*) > 1
) duplicate_item_keys

UNION ALL

SELECT
    'payments.duplicate_key_groups',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM (
    SELECT
        order_id,
        payment_sequential
    FROM order_payments
    GROUP BY
        order_id,
        payment_sequential
    HAVING COUNT(*) > 1
) duplicate_payment_keys

-- Orphan relationship checks
UNION ALL

SELECT
    'orders.missing_customer',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT
    'order_items.missing_order',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'order_items.missing_product',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'order_items.missing_seller',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL

SELECT
    'payments.missing_order',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM order_payments p
LEFT JOIN orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'reviews.missing_order',
    CAST(COUNT(*) AS VARCHAR),
    '= 0'
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL

-- Important missing fields
UNION ALL

SELECT
    'orders.missing_purchase_timestamp',
    CAST(
        COUNT(*) FILTER (
            WHERE TRY_CAST(order_purchase_timestamp AS TIMESTAMP) IS NULL
        )
        AS VARCHAR
    ),
    '= 0'
FROM orders

UNION ALL

SELECT
    'delivered_orders.missing_delivery_date',
    CAST(
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND TRY_CAST(order_delivered_customer_date AS TIMESTAMP) IS NULL
        )
        AS VARCHAR
    ),
    'Investigate'
FROM orders

UNION ALL

SELECT
    'delivered_orders.missing_estimated_date',
    CAST(
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND TRY_CAST(order_estimated_delivery_date AS TIMESTAMP) IS NULL
        )
        AS VARCHAR
    ),
    '= 0'
FROM orders

-- Expected one-to-many relationships
UNION ALL

SELECT
    'orders.with_multiple_items',
    CAST(COUNT(*) AS VARCHAR),
    'Expected; aggregate before joining'
FROM (
    SELECT order_id
    FROM order_items
    GROUP BY order_id
    HAVING COUNT(*) > 1
) multiple_items

UNION ALL

SELECT
    'orders.with_multiple_payments',
    CAST(COUNT(*) AS VARCHAR),
    'Expected; aggregate before joining'
FROM (
    SELECT order_id
    FROM order_payments
    GROUP BY order_id
    HAVING COUNT(*) > 1
) multiple_payments

UNION ALL

SELECT
    'orders.with_multiple_reviews',
    CAST(COUNT(*) AS VARCHAR),
    'Expected; resolve before joining'
FROM (
    SELECT order_id
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) multiple_reviews

UNION ALL

SELECT
    'geolocation.zip_prefixes_with_multiple_rows',
    CAST(COUNT(*) AS VARCHAR),
    'Expected; aggregate before joining'
FROM (
    SELECT geolocation_zip_code_prefix
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
    HAVING COUNT(*) > 1
) duplicate_zip_prefixes
;


-- 2. Main validation results
SELECT *
FROM dq_summary
ORDER BY check_name;


-- 3. Customer identifier structure
-- customer_id:
--   Order-level customer identifier.
-- customer_unique_id:
--   Persistent customer identifier used to identify repeat buyers.
SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(DISTINCT customer_id)
        - COUNT(DISTINCT customer_unique_id)
        AS additional_customer_ids
FROM customers;

-- Customers associated with multiple customer_id values
SELECT
    customer_unique_id,
    COUNT(DISTINCT customer_id) AS customer_id_count
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY customer_id_count DESC
LIMIT 20;

-- Distribution of customer_id count per unique customer
SELECT
    customer_id_count,
    COUNT(*) AS unique_customer_count
FROM (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT customer_id) AS customer_id_count
    FROM customers
    GROUP BY customer_unique_id
)
GROUP BY customer_id_count
ORDER BY customer_id_count;


-- 4. Order status distribution
SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 5. Dataset date coverage
SELECT
    MIN(
        TRY_CAST(order_purchase_timestamp AS TIMESTAMP)
    ) AS first_purchase,

    MAX(
        TRY_CAST(order_purchase_timestamp AS TIMESTAMP)
    ) AS last_purchase,

    COUNT(*) AS order_count
FROM orders;


-- 6. Order item cardinality
SELECT
    COUNT(*) AS item_rows,
    COUNT(DISTINCT order_id) AS orders_with_items,
    ROUND(
        COUNT(*) * 1.0 / COUNT(DISTINCT order_id),
        2
    ) AS avg_items_per_order
FROM order_items;

SELECT
    item_count,
    COUNT(*) AS order_count
FROM (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
)
GROUP BY item_count
ORDER BY item_count;


-- 7. Payment cardinality
SELECT
    COUNT(*) AS payment_rows,
    COUNT(DISTINCT order_id) AS orders_with_payments,
    ROUND(
        COUNT(*) * 1.0 / COUNT(DISTINCT order_id),
        2
    ) AS avg_payment_rows_per_order
FROM order_payments;

SELECT
    payment_count,
    COUNT(*) AS order_count
FROM (
    SELECT
        order_id,
        COUNT(*) AS payment_count
    FROM order_payments
    GROUP BY order_id
)
GROUP BY payment_count
ORDER BY payment_count;

-- Example orders with multiple payment rows
SELECT
    order_id,
    COUNT(*) AS payment_count,
    SUM(payment_value) AS total_payment_value
FROM order_payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_count DESC, order_id
LIMIT 20;


-- 8. Review cardinality
SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT order_id) AS orders_with_reviews,
    ROUND(
        COUNT(*) * 1.0 / COUNT(DISTINCT order_id),
        2
    ) AS avg_review_rows_per_order
FROM order_reviews;

SELECT
    review_count,
    COUNT(*) AS order_count
FROM (
    SELECT
        order_id,
        COUNT(*) AS review_count
    FROM order_reviews
    GROUP BY order_id
)
GROUP BY review_count
ORDER BY review_count;

-- Example orders with multiple review rows
SELECT
    order_id,
    COUNT(*) AS review_count
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC, order_id
LIMIT 20;


-- 9. Geolocation ZIP-prefix cardinality
-- Do not join geolocation directly to customers/sellers by ZIP
-- prefix because a ZIP prefix may contain many coordinate rows.
-- Aggregate geolocation to one row per ZIP before joining.
SELECT
    COUNT(*) AS geolocation_rows,
    COUNT(
        DISTINCT geolocation_zip_code_prefix
    ) AS unique_zip_prefixes,

    ROUND(
        COUNT(*) * 1.0 /
        COUNT(DISTINCT geolocation_zip_code_prefix),
        2
    ) AS avg_rows_per_zip_prefix

FROM geolocation;

-- ZIP prefixes with the most coordinate rows
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS coordinate_rows,
    COUNT(DISTINCT geolocation_lat) AS unique_latitudes,
    COUNT(DISTINCT geolocation_lng) AS unique_longitudes
FROM geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1
ORDER BY coordinate_rows DESC
LIMIT 20;