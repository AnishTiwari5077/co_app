# SahakariMS — Roadmap Milestones

## Milestone Overview

| Milestone | Version | Target Date | Status |
|-----------|---------|-------------|--------|
| M1 — Project Foundation | v0.1.0 | Week 4 | Planned |
| M2 — Core Member & Savings | v0.2.0 | Week 10 | Planned |
| M3 — Loan MVP | v0.3.0 | Week 16 | Planned |
| M4 — Accounting Core | v0.4.0 | Week 20 | Planned |
| M5 — Beta Release | v0.5.0 | Week 26 | Planned |
| M6 — Collector App | v0.6.0 | Week 30 | Planned |
| M7 — Mobile Banking | v0.7.0 | Week 34 | Planned |
| M8 — Reports & Regulatory | v0.8.0 | Week 38 | Planned |
| M9 — Security Hardening | v0.9.0 | Week 42 | Planned |
| M10 — Production Launch | v1.0.0 | Week 47 | Planned |

---

## Milestone 1: Project Foundation (v0.1.0)

**Week 4 — Internal team delivery**

### Deliverables

- [x] GitHub repository setup with branch protection rules
- [x] GitHub Actions CI/CD pipeline (build, test, deploy)
- [x] Docker Compose development environment
- [x] ASP.NET Core 8 Clean Architecture scaffold
- [x] Flutter project with Riverpod, GoRouter, folder structure
- [x] PostgreSQL database with EF Core migrations
- [x] Redis cache integration
- [x] Serilog structured logging
- [x] JWT RS256 authentication (login, refresh, logout)
- [x] Role and permission framework
- [x] Swagger/OpenAPI documentation
- [x] Health check endpoint
- [x] Basic admin user creation via seed data

### Acceptance Criteria

- `GET /health` returns 200 with all services healthy
- Login endpoint returns valid JWT
- All unit tests pass on CI
- Code coverage ≥ 60%

---

## Milestone 2: Core Member & Savings (v0.2.0)

**Week 10 — Beta tester delivery**

### Deliverables

- [ ] Member registration with KYC documents
- [ ] Member approval workflow
- [ ] Share account management
- [ ] Savings account opening
- [ ] Deposit and withdrawal operations
- [ ] Account statement generation
- [ ] Basic SMS notifications (transactions)
- [ ] Flutter screens: Member list, registration form, savings
- [ ] MinIO document storage integration

### Acceptance Criteria

- Register a member end-to-end (form → approval → active)
- Open savings account and make 10 deposits/withdrawals
- Download account statement (PDF)
- SMS received within 30 seconds of transaction
- Response time < 500ms for 95% of requests

---

## Milestone 3: Loan MVP (v0.3.0)

**Week 16**

### Deliverables

- [ ] Loan product configuration
- [ ] Loan application with guarantors and collateral
- [ ] Approval workflow (Officer → Manager)
- [ ] Loan disbursement to savings account
- [ ] EMI schedule generation (reducing balance + flat rate)
- [ ] EMI payment recording
- [ ] Overdue penalty calculation
- [ ] Loan statement and NOC generation
- [ ] Flutter loan screens

### Acceptance Criteria

- Full loan lifecycle: Application → Approval → Disbursement → 3 EMI payments → Closure
- EMI schedule matches manual calculation (±NPR 1)
- Penalty calculated correctly for 30-day overdue
- NOC PDF generated after full closure

---

## Milestone 4: Accounting Core (v0.4.0)

**Week 20**

### Deliverables

- [ ] Chart of accounts (standard Nepal cooperative COA)
- [ ] Journal, payment, receipt, contra vouchers
- [ ] Auto-voucher generation for all financial transactions
- [ ] Trial balance
- [ ] General ledger
- [ ] Cash counter open/close session
- [ ] Flutter accounting screens

### Acceptance Criteria

- Trial balance balanced after 100 mixed transactions
- Auto-voucher created for every deposit, withdrawal, EMI payment
- Voucher reversal works correctly
- Cash counter difference calculated accurately

---

## Milestone 5: Beta Release (v0.5.0)

**Week 26 — First external beta**

### Deliverables

- [ ] Complete FD and RD management
- [ ] Interest posting (daily accrual, monthly posting)
- [ ] Dividend calculation and posting
- [ ] Complete notification system (SMS + FCM + Email)
- [ ] Push notifications via Firebase
- [ ] FD maturity reminder job
- [ ] EMI reminder job
- [ ] Balance sheet and P&L reports
- [ ] Advanced member search

### Acceptance Criteria

- Beta cooperative installs and uses system for 2 weeks
- Zero critical bugs during beta period
- Interest posted correctly for 50 accounts (verified manually)
- All financial totals match manual spreadsheet

---

## Milestone 6: Collector App (v0.6.0)

**Week 30**

### Deliverables

- [ ] Android offline-capable collector app
- [ ] Route download and member assignment
- [ ] Offline transaction queue (SQLite)
- [ ] GPS tagging on each collection
- [ ] Bluetooth receipt printing (ESC/POS)
- [ ] Daily collection summary
- [ ] Sync with conflict resolution
- [ ] Cash handover workflow

### Acceptance Criteria

- Collect 50 transactions offline, sync 100% without errors
- GPS location accurate within 50 meters
- Bluetooth receipt prints within 5 seconds
- Sync completes within 30 seconds for 50 transactions

---

## Milestone 7: Mobile Banking (v0.7.0)

**Week 34**

### Deliverables

- [ ] Member mobile app (Android + iOS)
- [ ] mPIN login + biometric
- [ ] Account dashboard with real-time balances
- [ ] Fund transfer between own accounts
- [ ] EMI payment from mobile
- [ ] FonePay/eSewa QR payment
- [ ] Utility bill payment
- [ ] Statement download
- [ ] Loan application from mobile

### Acceptance Criteria

- App works on Android 10+ and iOS 14+
- Login < 2 seconds
- Balance updates in real-time after transaction
- QR payment completes in < 10 seconds end-to-end

---

## Milestone 8: Reports & Regulatory (v0.8.0)

**Week 38**

### Deliverables

- [ ] All financial reports (trial balance, balance sheet, P&L)
- [ ] Loan outstanding report
- [ ] Defaulter list
- [ ] NPA classification report
- [ ] COPOMIS XML export
- [ ] PEARLS ratio dashboard
- [ ] Excel export (EPPlus)
- [ ] PDF reports (iText)
- [ ] Audit log reports

### Acceptance Criteria

- COPOMIS XML validates against DoC schema
- Financial reports match manually prepared statements
- NPA amounts match Excel calculation within NPR 100

---

## Milestone 9: Security Hardening (v0.9.0)

**Week 42**

### Deliverables

- [ ] OWASP ZAP penetration test — remediate all HIGH/CRITICAL issues
- [ ] SonarQube code quality gate (A rating)
- [ ] Device fingerprint tracking
- [ ] Anomaly detection alerts
- [ ] Rate limiting per user and IP
- [ ] SSL Labs A+ rating
- [ ] k6 load test at 500 concurrent users
- [ ] Security documentation complete

### Acceptance Criteria

- SSL Labs: A+
- OWASP ZAP: No HIGH or CRITICAL findings
- SonarQube: ≤ 5 medium issues, 0 high/blocker
- Load test: P95 < 2s at 500 concurrent users

---

## Milestone 10: Production Launch (v1.0.0)

**Week 47**

### Deliverables

- [ ] Production server setup and hardening
- [ ] SSL certificate installed
- [ ] Production data migration (from legacy system)
- [ ] Staff training sessions (4 × 2 hours)
- [ ] User documentation / user manual
- [ ] Monitoring dashboards (Grafana) live
- [ ] Automated backup verified
- [ ] Runbook documentation
- [ ] Go-live smoke tests
- [ ] 30-day hypercare support plan

### Acceptance Criteria

- All staff trained and able to use system independently
- 0 data loss during migration (verified by reconciliation)
- Health check passes
- First real transaction processed successfully

---

## Post-Launch Milestones

| Milestone | Target | Features |
|-----------|--------|---------|
| v1.1.0 | Month 2 | HR module, payroll, attendance |
| v1.2.0 | Month 3 | Asset management, depreciation |
| v1.3.0 | Month 4 | Inventory management |
| v1.4.0 | Month 5 | WhatsApp notifications, eSewa integration |
| v2.0.0 | Month 8 | AI features, OCR KYC, predictive analytics |
