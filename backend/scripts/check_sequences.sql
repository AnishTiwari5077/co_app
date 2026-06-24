-- Check if all required sequences exist in Railway DB
SELECT sequencename, start_value, last_value, increment_by
FROM pg_sequences
WHERE sequencename IN (
  'member_code_seq',
  'loan_number_seq',
  'account_number_seq',
  'voucher_number_seq',
  'receipt_number_seq'
);
