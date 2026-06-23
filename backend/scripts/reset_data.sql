-- Clean reset — business data only (no hangfire in this transaction)
BEGIN;

-- Loans (children first)
TRUNCATE TABLE "LoanPayments"      CASCADE;
TRUNCATE TABLE "LoanEmiSchedules"  CASCADE;
TRUNCATE TABLE "LoanCollaterals"   CASCADE;
TRUNCATE TABLE "LoanGuarantors"    CASCADE;
TRUNCATE TABLE "Loans"             CASCADE;

-- Savings
TRUNCATE TABLE "SavingTransactions" CASCADE;
TRUNCATE TABLE "SavingAccounts"     CASCADE;
TRUNCATE TABLE "ShareAccounts"      CASCADE;

-- Members
TRUNCATE TABLE "MemberNominees"    CASCADE;
TRUNCATE TABLE "Members"           CASCADE;

-- Auth tokens (forces fresh login)
TRUNCATE TABLE "RefreshTokens"     CASCADE;

COMMIT;

SELECT 'DONE' AS status;
