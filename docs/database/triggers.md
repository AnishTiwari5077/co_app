# SahakariMS — Database: Triggers

## Overview

PostgreSQL triggers are used to:
1. **Auto-populate audit timestamps** (created_at, updated_at)
2. **Record transaction audit trails** (immutable change history)
3. **Enforce referential integrity** beyond FK constraints
4. **Update denormalized balance columns** for performance

---

## Trigger 1: Auto-Update Timestamps

```sql
-- Function to update updated_at on any table
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all core tables
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON saving_accounts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON loans
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_updated_at();

-- (Applied to all 25+ core tables via migration)
```

---

## Trigger 2: Financial Transaction Audit

Immutable audit record for every financial transaction:

```sql
-- Audit table (append-only, no updates)
CREATE TABLE audit.transaction_audit (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name      VARCHAR(100) NOT NULL,
    record_id       UUID NOT NULL,
    operation       VARCHAR(10) NOT NULL,   -- INSERT | UPDATE | DELETE
    old_values      JSONB,
    new_values      JSONB,
    changed_by      UUID,                   -- From session variable
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    session_ip      INET                    -- From session variable
);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION trigger_financial_audit()
RETURNS TRIGGER AS $$
DECLARE
    v_old_values JSONB;
    v_new_values JSONB;
    v_user_id    UUID;
    v_ip         INET;
BEGIN
    -- Read session variables set by application
    BEGIN
        v_user_id := current_setting('app.current_user_id', TRUE)::UUID;
        v_ip := current_setting('app.client_ip', TRUE)::INET;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
        v_ip := NULL;
    END;

    IF TG_OP = 'INSERT' THEN
        v_new_values := to_jsonb(NEW);
        v_old_values := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values := to_jsonb(OLD);
        v_new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_old_values := to_jsonb(OLD);
        v_new_values := NULL;
    END IF;

    INSERT INTO audit.transaction_audit
        (table_name, record_id, operation, old_values, new_values, changed_by, session_ip)
    VALUES
        (TG_TABLE_NAME, COALESCE(NEW.id, OLD.id), TG_OP,
         v_old_values, v_new_values, v_user_id, v_ip);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply to financial tables
CREATE TRIGGER audit_saving_transactions
    AFTER INSERT OR UPDATE ON saving_transactions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_financial_audit();

CREATE TRIGGER audit_loans
    AFTER INSERT OR UPDATE OR DELETE ON loans
    FOR EACH ROW
    EXECUTE FUNCTION trigger_financial_audit();

CREATE TRIGGER audit_loan_payments
    AFTER INSERT OR UPDATE ON loan_payments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_financial_audit();

CREATE TRIGGER audit_voucher_entries
    AFTER INSERT ON accounting.voucher_entries
    FOR EACH ROW
    EXECUTE FUNCTION trigger_financial_audit();
```

---

## Trigger 3: Saving Account Balance Update

After each transaction, update denormalized balance on the account:

```sql
CREATE OR REPLACE FUNCTION trigger_update_saving_balance()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE saving_accounts
    SET
        current_balance = (
            SELECT COALESCE(SUM(
                CASE
                    WHEN txn_type IN ('Deposit', 'InterestCredit', 'DividendCredit') THEN amount
                    ELSE -amount
                END
            ), 0)
            FROM saving_transactions
            WHERE account_id = NEW.account_id
              AND status = 'Completed'
        ),
        total_deposits = (
            SELECT COALESCE(SUM(amount), 0)
            FROM saving_transactions
            WHERE account_id = NEW.account_id
              AND txn_type = 'Deposit'
              AND status = 'Completed'
        ),
        total_withdrawals = (
            SELECT COALESCE(SUM(amount), 0)
            FROM saving_transactions
            WHERE account_id = NEW.account_id
              AND txn_type = 'Withdrawal'
              AND status = 'Completed'
        ),
        updated_at = NOW()
    WHERE id = NEW.account_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_saving_balance_after_txn
    AFTER INSERT OR UPDATE ON saving_transactions
    FOR EACH ROW
    WHEN (NEW.status = 'Completed')
    EXECUTE FUNCTION trigger_update_saving_balance();
```

---

## Trigger 4: Loan Outstanding Balance Update

```sql
CREATE OR REPLACE FUNCTION trigger_update_loan_outstanding()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE loans
    SET
        outstanding_balance = principal_amount - (
            SELECT COALESCE(SUM(principal_paid), 0)
            FROM loan_payments
            WHERE loan_id = NEW.loan_id
        ),
        total_interest_paid = (
            SELECT COALESCE(SUM(interest_paid), 0)
            FROM loan_payments
            WHERE loan_id = NEW.loan_id
        ),
        updated_at = NOW()
    WHERE id = NEW.loan_id;

    -- Auto-close if fully paid
    UPDATE loans
    SET status = 'Closed', closed_at = NOW()
    WHERE id = NEW.loan_id
      AND outstanding_balance <= 0
      AND status = 'Active';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_loan_outstanding_after_payment
    AFTER INSERT ON loan_payments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_loan_outstanding();
```

---

## Trigger 5: Member Status Change Guard

```sql
-- Prevent closing a member with outstanding balances
CREATE OR REPLACE FUNCTION trigger_prevent_invalid_member_close()
RETURNS TRIGGER AS $$
DECLARE
    savings_balance NUMERIC(18,4);
    loan_outstanding NUMERIC(18,4);
BEGIN
    IF NEW.status = 'Closed' AND OLD.status != 'Closed' THEN
        SELECT COALESCE(SUM(current_balance), 0)
        INTO savings_balance
        FROM saving_accounts
        WHERE member_id = NEW.id AND status != 'Closed';

        SELECT COALESCE(SUM(outstanding_balance), 0)
        INTO loan_outstanding
        FROM loans
        WHERE member_id = NEW.id AND status NOT IN ('Closed', 'WrittenOff');

        IF savings_balance > 0 THEN
            RAISE EXCEPTION 'Cannot close member with savings balance: NPR %', savings_balance;
        END IF;

        IF loan_outstanding > 0 THEN
            RAISE EXCEPTION 'Cannot close member with outstanding loan: NPR %', loan_outstanding;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_invalid_member_close
    BEFORE UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION trigger_prevent_invalid_member_close();
```

---

## Setting Session Variables (Application Side)

```csharp
// Infrastructure/Persistence/SahakariMSDbContext.cs
public class SahakariMSDbContext : DbContext
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public override async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        // Set PostgreSQL session variables before saving
        // This allows triggers to record who made the change
        var userId = _httpContextAccessor.HttpContext?
            .User.FindFirstValue(ClaimTypes.NameIdentifier);
        var ip = _httpContextAccessor.HttpContext?
            .Connection.RemoteIpAddress?.ToString();

        if (userId is not null)
            await Database.ExecuteSqlRawAsync(
                $"SET LOCAL app.current_user_id = '{userId}'", ct);

        if (ip is not null)
            await Database.ExecuteSqlRawAsync(
                $"SET LOCAL app.client_ip = '{ip}'", ct);

        return await base.SaveChangesAsync(ct);
    }
}
```
