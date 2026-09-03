CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    wallet_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    CONSTRAINT chk_users_wallet_balance
        CHECK (wallet_balance >= 0)
);

CREATE TABLE IF NOT EXISTS restaurants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(160) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,

    CONSTRAINT chk_restaurant_latitude
        CHECK (latitude BETWEEN -90 AND 90),

    CONSTRAINT chk_restaurant_longitude
        CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    restaurant_id UUID NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PREPARING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_order_user
        FOREIGN KEY (user_id) REFERENCES users(id),

    CONSTRAINT fk_order_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(id),

    CONSTRAINT chk_order_amount
        CHECK (total_amount >= 0),

    CONSTRAINT chk_order_status
        CHECK (
            status IN (
                'PREPARING',
                'DELIVERING',
                'DELIVERED'
            )
        )
);

CREATE TABLE IF NOT EXISTS wallet_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    amount_changed DECIMAL(10,2) NOT NULL,
    action_type VARCHAR(10) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_wallet_audit_user
        FOREIGN KEY (user_id) REFERENCES users(id),

    CONSTRAINT chk_audit_amount
        CHECK (amount_changed >= 0),

    CONSTRAINT chk_audit_action
        CHECK (
            action_type IN ('DEBIT', 'CREDIT')
        ),

    CONSTRAINT chk_audit_balance
        CHECK (balance_after >= 0)
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id
ON orders(user_id);

CREATE INDEX IF NOT EXISTS idx_orders_restaurant_id
ON orders(restaurant_id);

CREATE INDEX IF NOT EXISTS idx_wallet_audit_user_id
ON wallet_audit_logs(user_id);