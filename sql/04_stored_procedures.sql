CREATE OR REPLACE PROCEDURE sp_execute_checkout(
    p_order_id UUID,
    p_user_id UUID,
    p_restaurant_id UUID,
    p_amount DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    current_balance DECIMAL(10,2);
BEGIN

    -- Validate amount.

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION
            'Checkout amount must be greater than zero';
    END IF;


    -- Lock the user's wallet row.

    SELECT wallet_balance
    INTO current_balance
    FROM users
    WHERE id = p_user_id
    FOR UPDATE;


    IF NOT FOUND THEN
        RAISE EXCEPTION
            'User does not exist: %',
            p_user_id;
    END IF;


    -- Check restaurant.

    IF NOT EXISTS (
        SELECT 1
        FROM restaurants
        WHERE id = p_restaurant_id
    ) THEN

        RAISE EXCEPTION
            'Restaurant does not exist: %',
            p_restaurant_id;

    END IF;


    -- Check wallet balance.

    IF current_balance < p_amount THEN

        RAISE EXCEPTION
            'Insufficient balance. Available: %, Required: %',
            current_balance,
            p_amount;

    END IF;


    -- Prevent duplicate order ID.

    IF EXISTS (
        SELECT 1
        FROM orders
        WHERE id = p_order_id
    ) THEN

        RAISE EXCEPTION
            'Order already exists: %',
            p_order_id;

    END IF;


    -- Deduct wallet.

    UPDATE users
    SET wallet_balance =
        wallet_balance - p_amount
    WHERE id = p_user_id;


    -- Wallet trigger automatically creates
    -- the DEBIT audit record.


    -- Create order.

    INSERT INTO orders (
        id,
        user_id,
        restaurant_id,
        total_amount,
        status,
        created_at
    )
    VALUES (
        p_order_id,
        p_user_id,
        p_restaurant_id,
        p_amount,
        'PREPARING',
        NOW()
    );

END;
$$;


-- Example transaction:
--
-- BEGIN;
-- SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
--
-- CALL sp_execute_checkout(
--     'ORDER_UUID',
--     'USER_UUID',
--     'RESTAURANT_UUID',
--     500.00
-- );
--
-- COMMIT;
