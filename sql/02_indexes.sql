-- Prevent a user from having more than one active order.

CREATE UNIQUE INDEX IF NOT EXISTS idx_active_user_order
ON orders(user_id)
WHERE status IN ('PREPARING', 'DELIVERING');


-- Useful for restaurant revenue queries.

CREATE INDEX IF NOT EXISTS idx_orders_delivered_restaurant_date
ON orders(restaurant_id, created_at)
WHERE status = 'DELIVERED';


-- Useful for operational status queries.

CREATE INDEX IF NOT EXISTS idx_orders_status_created
ON orders(status, created_at);


-- Useful for wallet history.

CREATE INDEX IF NOT EXISTS idx_wallet_audit_user_time
ON wallet_audit_logs(user_id, changed_at DESC);