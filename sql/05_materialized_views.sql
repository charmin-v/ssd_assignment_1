DROP MATERIALIZED VIEW IF EXISTS restaurant_order_summary;


CREATE MATERIALIZED VIEW restaurant_order_summary AS

SELECT
    r.id AS restaurant_id,
    r.name AS restaurant_name,

    COUNT(o.id)::BIGINT
        AS completed_order_count,

    COALESCE(
        SUM(o.total_amount),
        0
    )::DECIMAL(14,2)
        AS completed_revenue

FROM restaurants r

LEFT JOIN orders o
    ON r.id = o.restaurant_id
    AND o.status = 'DELIVERED'

GROUP BY
    r.id,
    r.name;


-- Required for concurrent refresh.

CREATE UNIQUE INDEX IF NOT EXISTS
idx_restaurant_order_summary_id
ON restaurant_order_summary(restaurant_id);


-- Refresh procedure.

CREATE OR REPLACE PROCEDURE
sp_refresh_restaurant_summary()

LANGUAGE SQL

AS $$

    REFRESH MATERIALIZED VIEW CONCURRENTLY
    restaurant_order_summary;

$$;

 
