# SahakariMS — Feature Specification

## Project Objective

SahakariMS is an enterprise-grade Cooperative Management System for Nepal's Saving and Credit Cooperative Societies (SACCOS). It digitizes cooperative operations, improves financial accuracy, ensures regulatory compliance, and provides secure, scalable, auditable services for members, employees, and management.

---

## Feature Index

1. [Authentication](#1-authentication)
2. [User Management](#2-user-management)
3. [Role & Permission Management](#3-role--permission-management)
4. [Branch Management](#4-branch-management)
5. [Member Management](#5-member-management)
6. [Share Management](#6-share-management)
7. [Savings & Deposit Management](#7-savings--deposit-management)
8. [Fixed Deposit Management](#8-fixed-deposit-management)
9. [Loan Management](#9-loan-management)
10. [EMI Management](#10-emi-management)
11. [Cash Counter](#11-cash-counter)
12. [Accounting](#12-accounting)
13. [Financial Reports](#13-financial-reports)
14. [Audit System](#14-audit-system)
15. [Notification System](#15-notification-system)
16. [Collector Application](#16-collector-application)
17. [Member Mobile Banking](#17-member-mobile-banking)
18. [Human Resources](#18-human-resources)
19. [Asset Management](#19-asset-management)
20. [Inventory](#20-inventory)
21. [Document Management](#21-document-management)
22. [Government Reporting](#22-government-reporting)
23. [Dashboard](#23-dashboard)
24. [Search System](#24-search-system)
25. [Backup & Restore](#25-backup--restore)
26. [API Integrations](#26-api-integrations)
27. [Security Features](#27-security-features)
28. [Multi-Branch Features](#28-multi-branch-features)
29. [Offline Support](#29-offline-support)
30. [Future Features](#30-future-features)

---

## 1. Authentication

| Feature | Description |
|---------|-------------|
| Secure Login | Username + password login with bcrypt hashing |
| Session Management | JWT access token (15 min) + refresh token (7 days) |
| Two-Factor Authentication | TOTP (Google Authenticator) + SMS OTP fallback |
| OTP Verification | Time-limited OTP for sensitive transactions |
| Forgot Password | Password reset via registered email / SMS OTP |
| Device Registration | Register trusted devices, flag unknown logins |
| Login History | IP address, device, browser, timestamp per login |
| Concurrent Session Control | Max active sessions configurable per role |
| Account Lockout | Configurable lockout after N failed attempts |
| Password Expiry | Force password change after N days |
| Remember Me | Persistent login for trusted devices (configurable) |

---

## 2. User Management

| Feature | Description |
|---------|-------------|
| Create User | Register new system user (employee) with profile |
| Edit User | Modify user details, contact, and assigned branch |
| Deactivate User | Prevent login without deleting the record |
| Soft Delete | Remove user with audit trail and data preservation |
| Assign Branch | Link user to one or multiple branches |
| Assign Roles | Assign one or more roles to a user |
| Granular Permissions | Override default role permissions per user |
| Lock / Unlock | Temporary lockout by admin |
| Password Reset | Admin-initiated password reset with forced change |
| Profile Photo | Upload and manage user profile photos |

---

## 3. Role & Permission Management

| Feature | Description |
|---------|-------------|
| Create / Edit / Delete Roles | Full CRUD for custom roles |
| Module Permissions | Grant or deny access to each system module |
| Screen Permissions | Control which screens a role can access |
| Action Permissions | Control specific actions (approve, delete, post) |
| Data-Level Permissions | Restrict data to user's assigned branch |
| Role Hierarchy | Super roles inherit permissions from child roles |
| Permission Matrix | Export full role-permission matrix to Excel |
| Predefined Roles | Administrator, Manager, Accountant, Cashier, Loan Officer, Collector, Auditor, Member |

---

## 4. Branch Management

| Feature | Description |
|---------|-------------|
| Create Branch | Add new branch with code, address, and contact |
| Edit Branch | Modify branch information and settings |
| Close Branch | Mark branch inactive with final settlement |
| Branch Users | Assign and manage users per branch |
| Branch Cash | Independent cash management per branch |
| Branch Reports | All reports filterable by branch |
| Inter-Branch Transfer | Transfer funds between branches with approval |
| Consolidated Reports | Merge all branch data in head-office reports |
| Branch Settings | Per-branch interest rates, loan limits, schemes |

---

## 5. Member Management

| Feature | Description |
|---------|-------------|
| Member Registration | Capture personal info, contact, address |
| Auto Member Code | System-generated unique member code |
| KYC Verification | Citizenship number, PAN, photo upload |
| Digital Signature | Capture and store member's digital signature |
| Fingerprint Registration | Biometric enrollment (DigitalPersona / Mantra SDK) |
| Family Information | Spouse, parents, children details |
| Nominee Management | Primary and alternate nominee with relationship |
| Shareholder Link | Connect member to share account |
| Membership Approval | Pending → Verified → Active workflow |
| Membership Closure | Final settlement, share refund, account closure |
| Member Reactivation | Restore closed membership |
| Photo Management | Profile photo upload and update |
| Document Upload | Citizenship, PAN, passport to MinIO |
| COPOMIS Export | Generate XML/Excel for municipal submission |
| Member Search | Search by name, code, citizenship, phone |

---

## 6. Share Management

| Feature | Description |
|---------|-------------|
| Share Purchase | Buy shares with payment and receipt |
| Share Refund | Refund shares on exit or request |
| Share Transfer | Transfer shares between two members |
| Share Ledger | Full transaction history per member |
| Dividend Calculation | Calculate dividend based on shareholding period |
| Dividend Posting | Post dividend to savings or issue cheque |
| Share Certificate | Generate PDF certificate with QR code |
| Share Reports | Holder list, transaction history, dividend summary |

---

## 7. Savings & Deposit Management

### Account Types

| Type | Description |
|------|-------------|
| Regular Saving | Standard savings with daily access |
| Child Saving | Savings account for minors |
| Women's Saving | Special scheme for women members |
| Daily Saving | Door-to-door daily collection |
| Monthly Saving | Fixed monthly deposit scheme |
| Recurring Deposit | Fixed amount deposited monthly for a tenure |
| Fixed Deposit | Lump sum deposit for fixed tenure |
| Special Savings | Cooperative-defined special schemes |

### Features

| Feature | Description |
|---------|-------------|
| Open Account | Create account with scheme, initial deposit |
| Close Account | Final interest calculation and settlement |
| Cash Deposit | Counter deposit with slip |
| Cash Withdrawal | Counter withdrawal with slip |
| Cheque Deposit | Record cheque deposits with clearing |
| Interest Calculation | Daily product basis calculation |
| Auto Interest Posting | Automated posting on configured schedule |
| Passbook Printing | Formatted passbook output (A5/A6 format) |
| Digital Statement | PDF and Excel statement with date filter |
| Account Freeze | Freeze account with reason (legal, request) |
| Account Reactivation | Unfreeze frozen account |
| SMS Notification | Automatic SMS on every transaction |
| Bulk Interest Posting | Post interest for all accounts in one job |

---

## 8. Fixed Deposit Management

| Feature | Description |
|---------|-------------|
| Create FD | FD with custom amount, tenure, interest rate |
| Premature Closure | Close FD before maturity with penalty |
| Auto Renewal | Automatically renew FD on maturity |
| Maturity Processing | Post matured FD amount to savings |
| Interest Payment | Monthly or on maturity to savings account |
| Re-invest Interest | Add interest back to FD principal |
| FD Certificate | PDF certificate with terms and interest schedule |
| FD Maturity Schedule | List of all FDs with upcoming maturity dates |
| Maturity Alerts | SMS and push notification before maturity |

---

## 9. Loan Management

### Loan Types

| Type | Description |
|------|-------------|
| Personal Loan | General purpose, unsecured or salary-backed |
| Agriculture Loan | For farming, livestock, equipment |
| Business Loan | For trade and commerce |
| Gold Loan | Secured against gold jewellery |
| Vehicle Loan | For purchase of vehicles |
| Education Loan | For students' education expenses |
| Micro Loan | Small-ticket loans for low-income members |

### Workflow

```
Application → Document Verification → Guarantor Verification →
Collateral Assessment → Loan Officer Review →
Manager Approval → Committee Approval (for large loans) →
Disbursement → EMI Collection → Closure / NPA
```

### Features

| Feature | Description |
|---------|-------------|
| Loan Application | Multi-step form with document upload |
| Document Checklist | List required documents per loan type |
| Guarantor Management | Add multiple guarantors, verify, link |
| Collateral Management | Register land, gold, vehicle as collateral |
| Loan Verification | Loan Officer review and recommendation |
| Approval Workflow | Staged approval based on loan amount |
| Loan Rejection | Reject with detailed reason and notification |
| Loan Disbursement | Transfer to member's savings account |
| EMI Schedule | Auto-generated payment schedule |
| EMI Payment | Counter or mobile EMI collection |
| Penalty Calculation | Auto penalty on overdue EMIs |
| Partial Payment | Pay more than EMI, reduce principal |
| Advance Payment | Lump sum advance payment |
| Loan Rescheduling | Extend tenure with approval |
| Loan Restructuring | Restructure distressed loans |
| NPA Classification | Substandard, Doubtful, Loss categories |
| Loan Write-Off | Write off irrecoverable loans |
| Loan Recovery | Recover from guarantor savings or legal |
| Loan Closure | Final settlement and NOC |

---

## 10. EMI Management

| Feature | Description |
|---------|-------------|
| EMI Generation | Auto-generate schedule from disbursement date |
| EMI Payment | Record payment at counter or mobile |
| Penalty Calculation | Days-overdue × penalty rate |
| Interest Calculation | Reducing balance or flat rate |
| Receipt Generation | Print or digital receipt on payment |
| EMI Adjustment | Adjust EMI amount on rescheduling |
| EMI History | Full payment history per loan |
| Advance EMI | Record advance payments |
| Foreclosure | Early settlement with rebate |

---

## 11. Cash Counter

| Feature | Description |
|---------|-------------|
| Cash Deposit | Accept deposit and issue receipt |
| Cash Withdrawal | Process withdrawal with ID verification |
| Cash Transfer | Internal transfer between accounts |
| Opening Cash | Enter opening denomination-wise balance |
| Closing Cash | Closing with reconciliation |
| Cash Verification | Spot check verification report |
| Cash Adjustment | Correct petty differences with reason |
| Vault Transfer | Move cash from teller to vault |
| Denomination Count | Track notes and coins separately |

---

## 12. Accounting

| Feature | Description |
|---------|-------------|
| Chart of Accounts | Nepal cooperative standard account structure |
| Journal Entry | Manual double-entry journal |
| Payment Voucher | Record outgoing payments |
| Receipt Voucher | Record incoming receipts |
| Contra Voucher | Cash/bank internal transfers |
| General Ledger | Complete ledger per account |
| Cash Book | Daily cash inflow/outflow |
| Bank Book | Bank transaction register |
| Trial Balance | Unadjusted and adjusted |
| Profit & Loss | Income vs expense statement |
| Balance Sheet | Assets, liabilities, equity |
| Cash Flow | Direct method cash flow statement |
| Fiscal Year | BS calendar, year-end closing entries |
| Opening Balance | Enter historical opening balances |

---

## 13. Financial Reports

### Report Categories

| Category | Reports |
|----------|---------|
| Daily | Transaction summary, cash position, collection |
| Monthly | Income, expense, deposits, withdrawals |
| Annual | P&L, Balance Sheet, Cash Flow |
| Member | New members, inactive, churned, total |
| Loan | Outstanding, disbursed, defaulter, aging |
| Savings | Account-wise, scheme-wise, interest |
| FD | Maturity schedule, premature, interest |
| RD | Active, matured, defaulter |
| Collection | By collector, branch, daily |
| Interest | Income, expense, accrued |
| Government | COPOMIS, PEARLS |

### Export Formats
- PDF (with cooperative letterhead)
- Excel (XLSX with formulas)
- CSV (for data import)

---

## 14. Audit System

| Feature | Description |
|---------|-------------|
| Activity Log | User, action, module, timestamp, IP |
| Transaction Audit | Before/after values for financial transactions |
| Login History | Login, logout, failed attempts with device info |
| Deletion Log | Soft-deleted records with deletion reason |
| Config Change Log | Setting changes with old/new values |
| Financial Audit | Daily financial audit summary |
| Security Events | Password change, 2FA, role change events |
| Report Access Log | Who accessed which report when |
| API Request Log | All API requests with response codes |

---

## 15. Notification System

| Channel | Triggers |
|---------|---------|
| **SMS** | Deposit, Withdrawal, Loan Approved, EMI Due, EMI Paid, FD Maturity, OTP, Birthday |
| **Email** | Account Statement, Loan NOC, Welcome, Password Reset, FD Certificate |
| **Push (FCM)** | Transaction alerts, EMI reminders, FD maturity, Offers |

### Additional Features
- Template management (customize SMS and email content)
- Bulk notifications (broadcast to all members)
- Notification scheduling
- Delivery status tracking
- Opt-out management per member
- Multi-language support (Nepali and English)

---

## 16. Collector Application

*Dedicated Android app for field savings collection*

| Feature | Description |
|---------|-------------|
| Offline Collection | Collect savings without internet using local SQLite |
| GPS Tracking | Record GPS coordinates per transaction |
| Bluetooth Receipt | Print receipts on thermal Bluetooth printer |
| Daily Summary | Show total collected amount per day |
| Cash Handover | Hand over collected cash to branch |
| Server Sync | Auto-sync collected data on internet restore |
| Conflict Handling | Resolve sync conflicts with server timestamps |
| Collection Report | Daily and monthly collection per collector |
| Member List | View assigned members for the day |

---

## 17. Member Mobile Banking

*Flutter app for cooperative members*

| Feature | Description |
|---------|-------------|
| Secure Login | Mobile number + OTP login |
| Dashboard | Balance summary, pending EMIs, alerts |
| Account Balance | All accounts with current balance |
| Mini Statement | Last 10 transactions |
| Full Statement | Date-filtered statement (PDF download) |
| Fund Transfer | Transfer to cooperative savings account |
| QR Payment | Scan-and-pay at cooperative POS |
| Utility Payment | NEA, Ncell, NT, water bills |
| Loan Status | Current loans, outstanding, next EMI |
| EMI Schedule | Full payment schedule |
| FD Application | Apply for Fixed Deposit from mobile |
| Loan Application | Submit loan request from mobile |
| Notifications | Transaction alerts, announcements |
| Profile Update | Change contact, photo, nominee |

---

## 18. Human Resources

| Feature | Description |
|---------|-------------|
| Employee Registration | Personal info, position, department, branch |
| Attendance | Daily attendance tracking (biometric or manual) |
| Leave Management | Apply, approve, track leave |
| Payroll | Monthly salary calculation |
| Salary | Base, allowances, deductions, net |
| Bonus | Festival bonus, performance bonus |
| Promotion | Grade and position updates |
| Transfer | Move employee to another branch |
| Termination | Clearance and final settlement |
| Provident Fund | PF calculation and records |
| Income Tax | CIT deduction per slab |

---

## 19. Asset Management

| Feature | Description |
|---------|-------------|
| Asset Registration | Register with purchase date, cost, location |
| Asset Transfer | Move asset between branches |
| Depreciation | Auto-calculate depreciation per method |
| Asset Disposal | Sell or scrap with accounting entry |
| Maintenance Schedule | Record maintenance history |
| Asset Report | Complete asset register with book value |

---

## 20. Inventory

*For cooperatives that sell goods / agricultural supplies*

| Feature | Description |
|---------|-------------|
| Product Registration | Name, category, unit, price |
| Purchase | Receive stock from supplier |
| Sales | Sell to members or public |
| Stock Management | Real-time stock levels |
| Barcode Support | Generate and scan barcodes |
| Stock Adjustment | Corrections and wastage |
| Supplier Management | Supplier records and payment |

---

## 21. Document Management

| Feature | Description |
|---------|-------------|
| Upload Documents | Citizenship, PAN, Loan Agreement, Property |
| Download Documents | Download stored documents |
| Version History | Track document revisions |
| Document Approval | Approve uploaded documents |
| Secure Storage | Encrypted storage on MinIO |
| Expiry Alerts | Notify before document expiry |
| Category Tags | Categorize by type and module |

---

## 22. Government Reporting

| Report | Description |
|--------|-------------|
| COPOMIS | Municipality cooperative reporting (XML + Excel) |
| PEARLS | Financial health monitoring framework |
| NRB Reports | Capital adequacy, liquidity (where applicable) |
| Annual Report | Yearly cooperative performance summary |
| Income Tax Report | Tax deduction at source summary |
| VAT Report | VAT-registered cooperative tax reports |

---

## 23. Dashboard

### Executive Dashboard (Manager / Chairperson)
- Total active members
- Total savings balance
- Total outstanding loans
- Loan recovery rate (%)
- Non-performing loans (NPA %)
- Today's deposits and withdrawals
- Cash position (branch-wise)
- Monthly income vs expense chart
- New members this month
- Defaulter count

### Cashier Dashboard
- Today's cash receipts
- Today's cash payments
- Current cash balance
- Pending transactions
- Cash position vs limit

### Loan Officer Dashboard
- Pending loan applications
- Loans pending approval
- EMIs due today
- Overdue loans
- NPA loans

---

## 24. Search System

**Global search across:**
- Member Name, Member Code
- Citizenship Number
- Mobile Number
- Account Number
- Loan Number
- Receipt Number
- Voucher Number
- Transaction Reference

---

## 25. Backup & Restore

| Feature | Description |
|---------|-------------|
| Automatic Backup | Nightly backup at configurable time |
| Manual Backup | On-demand backup by administrator |
| Cloud Backup | Backup to S3-compatible storage |
| Restore Backup | Restore from specific backup point |
| Backup Encryption | AES-256 encrypted backup files |
| Backup Verification | Test restore to verify backup integrity |
| Retention Policy | Keep last N backups, archive older ones |

---

## 26. API Integrations

| Integration | Purpose |
|-------------|---------|
| Sparrow SMS | Primary SMS gateway for Nepal |
| Aakash SMS | Fallback SMS gateway |
| SendGrid / SMTP | Transactional email |
| Firebase FCM | Push notifications |
| QR Payment | eSewa / Khalti QR payment gateway |
| Payment Gateway | Card payments |
| Biometric SDK | DigitalPersona / Mantra fingerprint |
| Thermal Printer | Bluetooth receipt printing |
| Barcode Scanner | Inventory management |

---

## 27. Security Features

| Feature | Description |
|---------|-------------|
| RBAC | Role-based access with fine-grained permissions |
| JWT Authentication | Stateless token-based auth |
| 2FA | TOTP + SMS OTP |
| HTTPS Only | All communication over TLS 1.3 |
| Password Hashing | bcrypt with salt |
| AES-256 Encryption | PII and sensitive data fields |
| SQL Injection | Parameterized queries via EF Core |
| XSS Protection | Content Security Policy headers |
| CSRF Protection | Anti-forgery tokens |
| Rate Limiting | Per IP and per user |
| Session Timeout | Configurable inactivity timeout |
| Device Tracking | Flag and alert on new device login |
| Audit Logging | Every action logged with user and timestamp |

---

## 28. Multi-Branch Features

| Feature | Description |
|---------|-------------|
| Branch Isolation | Each branch manages own members and cash |
| Cross-Branch View | Head office sees all branches |
| Branch Reports | All reports filterable by branch |
| Consolidated Reports | Merged multi-branch financial reports |
| Inter-Branch Transfer | Transfer funds with dual approval |
| Branch Permissions | Branch-specific data access control |
| Branch Dashboard | Per-branch KPI dashboard |

---

## 29. Offline Support

**Modules supporting offline operation:**

| Module | Offline Capability |
|--------|-------------------|
| Collector App | Full offline collection with SQLite queue |
| Member Verification | Cache member list for offline lookup |
| Receipt Printing | Bluetooth print without internet |
| Daily Collection | Store locally, sync when connected |

*Automatic conflict resolution on sync using server timestamps.*

---

## 30. Future Features

| Feature | Description |
|---------|-------------|
| AI Loan Risk Assessment | ML-based loan eligibility and risk scoring |
| OCR Citizenship Scan | Auto-extract data from citizenship photo |
| Face Recognition Login | Biometric face-based authentication |
| Voice Banking | Voice command transactions (Nepali) |
| Chatbot Support | Automated member query resolution |
| Business Intelligence | Advanced BI dashboards with drill-down |
| Fraud Detection | ML-based anomaly detection |
| Online Loan Portal | Public-facing loan application portal |
| QR Merchant Payments | Pay cooperative merchants via QR |
| WhatsApp Notifications | WhatsApp business API alerts |
| Digital KYC | eKYC via government ID APIs |
| Predictive Analytics | Forecasting deposits, withdrawals, loans |

---

## Non-Functional Requirements

### Performance
- API response time < 2 seconds at 95th percentile
- Support 500 concurrent users in production
- Database queries optimized with proper indexing
- Paginated results for large datasets

### Security
- Zero critical OWASP Top 10 vulnerabilities
- End-to-end encryption for sensitive data
- Complete audit trail for all operations
- Regular automated vulnerability scans

### Reliability
- 99.9% uptime target (< 9 hours downtime/year)
- Automated failover for critical services
- Regular backup with tested restore procedures

### Scalability
- Horizontal scaling via Docker container orchestration
- Database connection pooling
- Redis caching for frequent queries
- Read replicas for report queries

### Maintainability
- Clean Architecture, SOLID, DRY, KISS
- 80%+ unit and integration test coverage
- Comprehensive inline documentation
- API versioning for backward compatibility

### Compliance
- Nepal Department of Cooperatives Act 2074
- COPOMIS reporting format compliance
- PEARLS monitoring framework
- Data privacy regulations
