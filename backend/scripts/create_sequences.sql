-- Create all required sequences for SahakariMS on Railway
-- These are needed for generating human-readable codes for members, loans, accounts, vouchers

CREATE SEQUENCE IF NOT EXISTS member_code_seq   START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS loan_number_seq   START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS account_number_seq START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS voucher_number_seq START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS receipt_number_seq START 1 INCREMENT 1;

-- Verify
SELECT sequencename, start_value, last_value, increment_by
FROM pg_sequences
WHERE sequencename IN (
  'member_code_seq',
  'loan_number_seq',
  'account_number_seq',
  'voucher_number_seq',
  'receipt_number_seq'
);
