CREATE OR REPLACE FUNCTION fn_wallet_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    difference DECIMAL(10,2);
    audit_action VARCHAR(10);
BEGIN

    difference := NEW.wallet_balance - OLD.wallet_balance;

    -- No wallet change = no audit record.
    IF difference = 0 THEN
        RETURN NEW;
    END IF;

    IF difference < 0 THEN
        audit_action := 'DEBIT';
    ELSE
        audit_action := 'CREDIT';
    END IF;

    INSERT INTO wallet_audit_logs (
        id,
        user_id,
        amount_changed,
        action_type,
        balance_after,
        changed_at
    )
    VALUES (
        gen_random_uuid(),
        NEW.id,
        ABS(difference),
        audit_action,
        NEW.wallet_balance,
        NOW()
    );

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_wallet_audit
ON users;


CREATE TRIGGER trg_wallet_audit
AFTER UPDATE OF wallet_balance
ON users
FOR EACH ROW
WHEN (
    OLD.wallet_balance IS DISTINCT FROM NEW.wallet_balance
)
EXECUTE FUNCTION fn_wallet_audit();


-- -------------------------------------------------------
-- Make wallet audit logs immutable.
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_prevent_audit_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'wallet_audit_logs records are immutable';
END;
$$;


CREATE OR REPLACE FUNCTION fn_prevent_audit_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'wallet_audit_logs records are immutable';
END;
$$;


DROP TRIGGER IF EXISTS trg_audit_no_update
ON wallet_audit_logs;


DROP TRIGGER IF EXISTS trg_audit_no_delete
ON wallet_audit_logs;


CREATE TRIGGER trg_audit_no_update
BEFORE UPDATE
ON wallet_audit_logs
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_audit_update();


CREATE TRIGGER trg_audit_no_delete
BEFORE DELETE
ON wallet_audit_logs
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_audit_delete();  
