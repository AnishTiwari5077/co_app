# SahakariMS — Workflows

## 1. Member Registration Workflow

```
Staff starts registration
       │
       ▼
Enter personal information
(Name, DOB, Gender, Phone, Address)
       │
       ▼
Upload KYC documents
(Citizenship, PAN, Photo)
       │
       ▼
Capture digital signature
       │
       ▼
Capture fingerprint (optional)
       │
       ▼
Enter family details & nominees
       │
       ▼
Submit for approval
       │
       ▼
Member status = "Pending"
       │
       ▼
Manager reviews KYC documents
       │
    ┌──┴──┐
Reject    Approve
   │         │
   ▼         ▼
Notify    KYC Verified = TRUE
member    Status = "Active"
with         │
reason       ▼
          Share purchase (minimum 10 shares)
             │
             ▼
          Generate member code (auto)
          Send welcome SMS
          Member is fully active
```

---

## 2. Savings Account Opening

```
Cashier selects member
       │
       ▼
Select savings scheme
(Regular, RD, FD, Daily, etc.)
       │
       ▼
Enter opening deposit amount
(Must meet minimum deposit)
       │
       ▼
System generates account number
       │
       ▼
Collect cash (if deposit mode = Cash)
       │
       ▼
Post accounting entry:
  Dr  Cash in Hand
  Cr  Member Savings Account
       │
       ▼
Print deposit slip / passbook page
       │
       ▼
Send SMS: "Account {number} opened.
Balance: NPR {amount}"
```

---

## 3. Deposit Workflow

```
Member arrives at counter
       │
       ▼
Cashier searches member
(by name, code, phone, citizenship)
       │
       ▼
Select savings account
       │
       ▼
Enter deposit amount
       │
       ▼
Verify cash denomination
       │
       ▼
Confirm transaction
       │
       ▼
System posts:
  Dr  Cash in Hand
  Cr  Member Savings Account
       │
       ▼
Generate receipt number
Update account balance
       │
       ▼
Print receipt
       │
       ▼
Send SMS: "Deposited NPR {amount}.
Balance: NPR {newBalance}"
```

---

## 4. Loan Application Workflow

```
Member / Loan Officer submits application
       │
       ▼
Enter loan details
(Type, Amount, Purpose, Tenure)
       │
       ▼
Upload required documents
(Citizenship, Income proof, etc.)
       │
       ▼
Add guarantors
(Select from active members, verify)
       │
       ▼
Register collateral (if required)
       │
       ▼
Submit → Loan status: "Pending"
       │
       ▼
Loan Officer reviews
  ┌────┴────┐
Reject   Recommend
  │          │
  ▼          ▼
Notify    Status: "UnderReview"
member       │
             ▼
          Manager reviews
       ┌─────┴─────┐
    Reject      Approve
      │             │
      ▼             ▼
   Notify      Status: "Approved"
   member      Set approved amount
               Send approval SMS
                    │
                    ▼
               Cashier disburses
               (Loan amount → member savings account)
                    │
                    ▼
               Status: "Active"
               Generate EMI schedule
               Send disbursement SMS
               Post accounting:
                 Dr  Loan Receivable
                 Cr  Member Savings Account
```

---

## 5. EMI Payment Workflow

```
Member arrives (or pays via mobile)
       │
       ▼
Cashier / System looks up loan
       │
       ▼
Show EMI due:
  - Due Date
  - Principal
  - Interest
  - Penalty (if overdue)
  - Total Due
       │
       ▼
Member pays
       │
       ▼
System calculates allocation:
  1. Penalty (if any)
  2. Interest due
  3. Principal due
       │
       ▼
Update loan schedule
Update outstanding balance
       │
       ▼
Post accounting:
  Dr  Cash in Hand
  Cr  Loan Receivable (principal portion)
  Cr  Interest Income (interest portion)
  Cr  Penalty Income (penalty portion)
       │
       ▼
Generate receipt
       │
       ▼
Send SMS: "EMI of NPR {amount} received.
Outstanding: NPR {balance}.
Next EMI: {date}"
       │
       ▼
Check if fully paid
  ┌────┴────┐
  No       Yes
  │         │
Continue  Loan status: "Closed"
          Generate NOC
          Send closure SMS
```

---

## 6. Loan Rescheduling Workflow

```
Member requests rescheduling
(financial hardship, etc.)
       │
       ▼
Loan Officer documents reason
       │
       ▼
Propose new schedule:
  - New tenure
  - New EMI amount
       │
       ▼
Manager reviews
  ┌────┴────┐
Reject   Approve
  │          │
  ▼          ▼
Notify    Update loan:
member      - New tenure
            - Regenerate EMI schedule
            - Status: "Rescheduled"
                 │
                 ▼
              Notify member via SMS
              Log in audit trail
```

---

## 7. NPA Classification Workflow

Background job runs nightly:

```
For each Active / Overdue loan:
       │
       ▼
Calculate overdue days
(from due date of earliest unpaid EMI)
       │
       ▼
0–89 days overdue:
  → Classification: "Standard"
  → Status: "Overdue" (if >0 days)

90–179 days overdue:
  → Classification: "Substandard"
  → Notify branch manager

180–364 days overdue:
  → Classification: "Doubtful"
  → Notify manager + send formal notice

365+ days overdue:
  → Classification: "Loss"
  → Notify board, recommend write-off
```

---

## 8. Cash Counter Open/Close Workflow

### Opening (Morning)

```
Cashier logs in
       │
       ▼
Navigate to Cash Counter → Open Session
       │
       ▼
Enter opening cash:
  - Denomination breakdown
    (1000×5, 500×10, 100×20, etc.)
  - Total verified amount
       │
       ▼
System records opening session
Cash counter is now active
```

### Closing (Evening)

```
Cashier completes all transactions
       │
       ▼
Navigate to Cash Counter → Close Session
       │
       ▼
Count physical cash
Enter closing denomination breakdown
       │
       ▼
System calculates:
  Expected = Opening + Deposits − Withdrawals
  Actual = Entered physical count
  Difference = Actual − Expected
       │
       ▼
If Difference = 0:
  → Close session normally

If Difference ≠ 0:
  → Cashier must enter reason
  → Manager notified
  → Session closed with difference noted
  → Accounting adjustment voucher
```

---

## 9. Collector App Sync Workflow

```
Collector starts the day
       │
       ▼
Login to app (PIN)
       │
       ▼
App syncs member list from server
(if online) or uses cached data
       │
       ▼
Collector visits members' homes
       │
       ▼
For each collection:
  - Select member
  - Enter amount
  - Record GPS location
  - Print Bluetooth receipt
  - Store in local SQLite queue
       │
       ▼
Return to branch
       │
       ▼
Connect to WiFi/internet
App automatically syncs to server:
  - Uploads all pending transactions
  - Server validates and posts
  - Conflicts resolved by server timestamp
       │
       ▼
Cash handover to branch cashier
Print daily collection summary
```

---

## 10. Fixed Deposit Maturity Workflow

Background job runs daily:

```
Fetch all FDs maturing in next 7 days
       │
       ▼
7 days before: Send SMS + push notification
1 day before:  Send SMS reminder
       │
       ▼
On maturity date:
       │
  ┌────┴────────┐
  │             │
Auto-Renew    No Auto-Renew
  │             │
  ▼             ▼
Create new FD  Post maturity amount
(same terms)   to linked savings account
               Post interest
               Update FD status: "Matured"
               Send maturity SMS
```
