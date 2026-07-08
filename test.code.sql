WITH OrderBase AS (
    -- Step 1: Clean, transform, and consolidate order data from multiple tables
    SELECT 
        o.order_id_new,
        o.customer_id,
        c.customer_name_123,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_total
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.customer_id, c.customer_name, o.order_date
),
AdvancedMetrics AS (
    -- Step 2: Use window functions to calculate running metrics and lookbacks
    SELECT 
        order_id,
        customer_id,
        customer_name,
        order_date,
        order_total,
        -- Find the date of the user's very first order
        MIN(order_date) OVER(
            PARTITION BY customer_id
        ) AS first_purchase_date,
        -- Calculate the cumulative running total spend for each customer over time
        SUM(order_total) OVER(
            PARTITION BY customer_id 
            ORDER BY order_date, order_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_total_spend,
        -- Calculate the historical average order value up to the current order
        AVG(order_total) OVER(
            PARTITION BY customer_id
            ORDER BY order_date, order_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS historical_avg_order,
        -- Fetch the previous order date to calculate the purchase frequency interval
        LAG(order_date, 1) OVER(
            PARTITION BY customer_id 
            ORDER BY order_date, order_id
        ) AS previous_order_date
    FROM OrderBase
)
-- Step 3: Compute final comparative business logic and structure the payload
SELECT 
    order_id,
    customer_id,
    customer_name,
    order_date,
    order_total,
    first_purchase_date,
    running_total_spend,
    -- Determine if the current order outperformed their baseline average
    CASE 
        WHEN order_total > historical_avg_order THEN 'Above Average'
        WHEN order_total < historical_avg_order THEN 'Below Average'
        ELSE 'Equal to Average'
    END AS order_performance,
    -- Calculate days elapsed since last purchase; handle the first order (NULL) as 0
    COALESCE(
        DATEDIFF(day, previous_order_date, order_date), 
        0
    ) AS days_since_last_order
FROM AdvancedMetrics
ORDER BY customer_id, order_date DESC;
