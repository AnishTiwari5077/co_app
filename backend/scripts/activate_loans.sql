UPDATE "Loans" 
SET "Status" = 'Active', 
    "OutstandingBalance" = "AppliedAmount",
    "UpdatedAt" = NOW()
WHERE "Status" = 'Approved';

SELECT "LoanNumber", "Status", "OutstandingBalance" FROM "Loans";
