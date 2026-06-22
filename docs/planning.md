# SahakariMS — Project Planning

## Project Overview

A production-ready **Cooperative Management System (CMS)** for Saving and Credit Cooperative Societies (SACCOS) in Nepal. The system manages the complete lifecycle of cooperative operations including member management, deposits, loans, accounting, financial reporting, mobile banking, audit logging, and regulatory reporting (COPOMIS).

---

## Project Goals

| Goal | Description |
|------|-------------|
| Fully Digital Operations | Replace paper-based processes with a digital system |
| Multi-Branch Support | Manage multiple branches from a single system |
| High Security | Enterprise-grade security with full audit trails |
| Real-Time Transactions | Immediate processing and posting of financial transactions |
| Regulatory Compliance | COPOMIS, PEARLS, NRB reporting requirements |
| Mobile Banking | Digital access for cooperative members |
| Offline Capability | Field collectors can work without internet |
| Automated Accounting | Double-entry bookkeeping with automatic posting |
| Scalable Architecture | Supports growth from 100 to 100,000+ members |

---

## Technology Stack Summary

| Component | Technology | Reason |
|-----------|-----------|--------|
| Frontend | Flutter 3.22 | Single codebase for Android, iOS, Windows, Web |
| State Management | Riverpod | Reactive, testable state management |
| Navigation | GoRouter | Declarative routing with deep linking |
| Backend | ASP.NET Core 8 | Enterprise-grade, high performance, strongly typed |
| Architecture | Clean Architecture + CQRS | Separation of concerns, testability |
| ORM | Entity Framework Core 8 | Code-first migrations, LINQ queries |
| Database | PostgreSQL 16 | ACID compliance, stored procedures, partitioning |
| Cache | Redis 7 | Session storage, distributed cache |
| Storage | MinIO / AWS S3 | Document and media storage |
| Authentication | JWT + Refresh Tokens | Stateless, scalable authentication |
| Push Notifications | Firebase Cloud Messaging | Cross-platform push delivery |
| SMS | Sparrow SMS (Nepal) | Local SMS gateway for Nepal |
| Container | Docker + Docker Compose | Consistent deployments |
| CI/CD | GitHub Actions | Automated testing and deployment |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                     │
│      Flutter App (Android/iOS/Windows/Web)               │
│      ASP.NET Core Controllers + Middleware               │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP / REST API
┌─────────────────────▼───────────────────────────────────┐
│                   Application Layer                      │
│      CQRS (Commands / Queries)                           │
│      Use Cases, DTOs, Validators                         │
│      MediatR Pipeline Behaviors                          │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                    Domain Layer                          │
│      Entities, Aggregates, Value Objects                 │
│      Domain Events, Business Rules                       │
│      Repository Interfaces                               │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                Infrastructure Layer                      │
│      EF Core Repositories, Unit of Work                  │
│      SMS Gateway, Email, FCM                             │
│      MinIO / S3 Storage                                  │
│      Redis Cache                                         │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                 Data Layer                               │
│      PostgreSQL 16 (Primary Database)                    │
│      Redis 7 (Cache + Sessions)                          │
│      MinIO (File Storage)                                │
└─────────────────────────────────────────────────────────┘
```

---

## Design Principles

- **Clean Architecture** — Dependency inversion, domain is framework-agnostic
- **SOLID** — Every class has a single responsibility
- **DRY** — No duplicate business logic
- **KISS** — Simple, readable, maintainable code
- **Repository Pattern** — Data access abstraction
- **Unit of Work** — Atomic database transactions
- **CQRS** — Separate read and write paths
- **Domain Events** — Loose coupling between modules
- **Dependency Injection** — Testable, configurable services

---

## Git Branching Strategy

```
main          ← Production-only, tagged releases
  └── develop ← Integration branch, all features merged here
        ├── feature/member-management
        ├── feature/loan-module
        ├── feature/mobile-banking
        ├── release/v1.0.0
        └── hotfix/emi-calculation-fix
```

**Commit Convention:** Conventional Commits
```
feat(loans): add EMI rescheduling workflow
fix(accounting): correct interest double-posting bug
docs(api): update loan endpoint documentation
test(members): add KYC verification unit tests
chore(docker): update PostgreSQL to 16.3
```

---

## Project Phases

### Phase 1 — Project Setup *(2 Weeks)*

**Deliverables:**
- GitHub repository with branch protection rules
- GitHub Actions CI/CD pipeline (build, test, deploy)
- Docker Compose for local development environment
- ASP.NET Core 8 Clean Architecture scaffolding
- Flutter project setup (Riverpod + GoRouter + Material 3)
- PostgreSQL schema migration framework (EF Core)
- Redis cache configuration
- Serilog structured logging
- Global exception handling middleware
- Health check endpoints
- JWT authentication middleware
- Role-based authorization policies
- Swagger / OpenAPI documentation

---

### Phase 2 — Member Management *(3 Weeks)*

**Deliverables:**
- Member registration with auto-generated member code
- KYC workflow: Citizenship, PAN, Photo capture
- Digital signature capture and PNG storage
- Fingerprint registration (DigitalPersona / Mantra SDK)
- Family information form (spouse, parents, children)
- Nominee registration (primary + alternate)
- Membership approval workflow (Pending → Verified → Active)
- Membership closure with final settlement
- Member reactivation workflow
- Photo and document upload to MinIO
- COPOMIS XML/Excel export

---

### Phase 3 — Share Management *(2 Weeks)*

**Deliverables:**
- Share purchase with payment and receipt
- Share refund / buyback with accounting entry
- Share transfer between members
- Share ledger per member with history
- Dividend calculation (configurable per period)
- Dividend posting to savings or cheque issuance
- Share certificate PDF generation (with QR code)
- Share summary and holder reports

---

### Phase 4 — Savings & Deposit Module *(4 Weeks)*

**Deliverables:**
- Account types: Regular, Child, Women's, Daily, Monthly, RD, FD, Special
- Open, close, freeze, and reactivate accounts
- Deposit and withdrawal transactions with slip printing
- Automatic interest calculation (daily product basis)
- Interest posting engine (daily / monthly / yearly)
- Passbook printing (formatted layout)
- Digital statement generation (PDF, Excel, CSV)
- Account-level SMS notifications
- Bulk interest posting job

---

### Phase 5 — Loan Module *(6 Weeks)*

**Deliverables:**
- Loan types: Personal, Business, Agriculture, Gold, Vehicle, Education, Micro
- Multi-step loan application form
- Document checklist with upload
- Guarantor management (add, verify, link)
- Collateral management (land, gold, vehicle)
- Approval workflow with role-based stages
- Disbursement to member savings account
- EMI schedule generation (flat / reducing balance)
- EMI collection at counter and via mobile
- Penalty calculation for overdue EMIs
- Partial / advance payment with schedule update
- Loan rescheduling with board approval
- Loan restructuring for distressed members
- NPA classification (substandard, doubtful, loss)
- Loan write-off with accounting entries
- NOC generation on loan closure
- Loan recovery from guarantor

---

### Phase 6 — Accounting Module *(5 Weeks)*

**Deliverables:**
- Chart of accounts (Nepal cooperative standard)
- Manual journal entry with debit/credit validation
- Payment, receipt, and contra vouchers
- General Ledger with balance tracking
- Cash Book and Bank Book
- Trial Balance (adjusted and unadjusted)
- Profit & Loss Statement
- Balance Sheet
- Cash Flow Statement (direct method)
- Fiscal year management (BS calendar support)
- Year-end closing entries
- Opening balance entry

---

### Phase 7 — Cash Counter *(2 Weeks)*

**Deliverables:**
- Cash deposit at counter
- Cash withdrawal at counter
- Opening cash balance entry by cashier
- Closing cash reconciliation with difference report
- Vault transfer (teller ↔ vault)
- Cash adjustment with reason
- Cash verification report
- Denomination-wise cash count

---

### Phase 8 — Collector System *(3 Weeks)*

**Deliverables:**
- Android collector app (Flutter)
- Offline collection with local SQLite queue
- GPS location capture per transaction
- Bluetooth thermal receipt printing
- Daily collection summary per collector
- Cash handover to branch with acknowledgment
- Automatic server sync on internet restore
- Collection performance report

---

### Phase 9 — Mobile Banking *(5 Weeks)*

**Deliverables:**
- Member login with OTP verification
- Dashboard: balance, loans, EMI due dates
- Account balance (all accounts)
- Mini statement (last 10 transactions)
- Full statement with date filter (PDF download)
- Fund transfer to cooperative savings accounts
- QR code payment (scan & pay)
- Utility bill payment integration
- Loan status and EMI schedule view
- FD application from mobile
- Loan application from mobile
- Notification centre
- Profile and contact update

---

### Phase 10 — Notification System *(1 Week)*

**Deliverables:**
- SMS integration (Sparrow SMS API, Nepal)
- Email integration (SMTP / SendGrid)
- Push notifications (Firebase FCM)
- OTP SMS for login and sensitive operations
- Automated EMI reminder (3 days before due)
- Deposit and withdrawal SMS alerts
- Birthday greetings
- FD maturity alerts (7 days, 3 days, on day)
- Loan approval / rejection notifications
- Template management for SMS and email

---

### Phase 11 — Reports Module *(4 Weeks)*

**Deliverables:**
- Daily transaction report
- Monthly summary report
- Annual financial summary
- Trial Balance (PDF, Excel)
- Balance Sheet (PDF, Excel)
- Profit & Loss Statement
- Cash Flow Statement
- Member reports: new, inactive, total by branch
- Loan outstanding report
- Defaulter list with aging
- EMI due report (weekly, monthly)
- FD maturity schedule
- RD status report
- Daily and monthly collection reports
- Interest income report
- Dividend report
- Export: PDF, Excel (XLSX), CSV

---

### Phase 12 — Audit System *(2 Weeks)*

**Deliverables:**
- Activity log (user, action, timestamp, IP, module)
- Transaction audit trail (before/after values)
- Login and logout history with device info
- Deleted record recovery log
- Configuration change tracking
- Financial audit summary
- Security event log

---

### Phase 13 — Security Hardening *(2 Weeks)*

**Deliverables:**
- JWT access token (15 min) + Refresh token rotation (7 days)
- RBAC with fine-grained module/action permissions
- TOTP-based 2FA (Google Authenticator compatible)
- Device registration and anomaly detection
- Password policy (complexity, expiry, history)
- Account lockout after 5 failed attempts
- AES-256 encryption for PII fields
- API rate limiting per IP and user
- SQL injection prevention (parameterized queries only)
- XSS protection headers
- CORS policy configuration
- Secure cookie settings

---

### Phase 14 — Government Reports *(2 Weeks)*

**Deliverables:**
- COPOMIS export (XML + Excel, municipality format)
- PEARLS monitoring report
- NRB required reports (capital adequacy, liquidity)
- Annual general meeting report
- Income tax reports
- VAT reports (if applicable)

---

### Phase 15 — Testing *(3 Weeks)*

**Deliverables:**
- Unit tests for all domain logic (xUnit)
- Integration tests for API endpoints (TestContainers)
- Flutter widget tests for all screens
- End-to-end test scenarios
- Performance testing (k6): 500 concurrent users
- Security scan (OWASP ZAP)
- User Acceptance Testing (UAT) with cooperative staff
- Test coverage report (target: 80%+)

---

### Phase 16 — Production Deployment *(1 Week)*

**Deliverables:**
- Production server setup (Ubuntu 24.04 LTS)
- Nginx reverse proxy with SSL (Let's Encrypt / paid cert)
- Docker production deployment
- Automated nightly backup to remote storage
- Monitoring: Prometheus + Grafana dashboards
- Alerting: PagerDuty / email on errors
- DNS configuration
- Production smoke tests
- Runbook documentation

---

## Timeline Summary

| Phase | Module | Duration | Cumulative |
|-------|--------|---------|-----------|
| Phase 1 | Project Setup | 2 Weeks | 2 |
| Phase 2 | Member Management | 3 Weeks | 5 |
| Phase 3 | Share Management | 2 Weeks | 7 |
| Phase 4 | Savings Module | 4 Weeks | 11 |
| Phase 5 | Loan Module | 6 Weeks | 17 |
| Phase 6 | Accounting | 5 Weeks | 22 |
| Phase 7 | Cash Counter | 2 Weeks | 24 |
| Phase 8 | Collector System | 3 Weeks | 27 |
| Phase 9 | Mobile Banking | 5 Weeks | 32 |
| Phase 10 | Notifications | 1 Week | 33 |
| Phase 11 | Reports | 4 Weeks | 37 |
| Phase 12 | Audit System | 2 Weeks | 39 |
| Phase 13 | Security | 2 Weeks | 41 |
| Phase 14 | Govt. Reports | 2 Weeks | 43 |
| Phase 15 | Testing | 3 Weeks | 46 |
| Phase 16 | Deployment | 1 Week | **47 Weeks** |

---

## Milestones

### 🎯 Milestone 1 — MVP (Weeks 1–17)
- Authentication and role management
- Member management with KYC
- Share management
- Core savings module
- Basic loan management
- Core accounting
- Essential reports

### 🎯 Milestone 2 — Beta (Weeks 18–33)
- Collector Android app
- Member mobile banking
- SMS and push notifications
- All savings types (RD, FD, special)
- Advanced loan features (NPA, rescheduling)
- Complete accounting (fiscal year, closing)
- Audit system
- COPOMIS reports

### 🎯 Milestone 3 — Version 1.0 (Weeks 34–47)
- Complete banking system
- Multi-branch management
- QR payment integration
- Security hardening and 2FA
- Performance optimization
- Automated backups
- Production monitoring
- Full test coverage (80%+)

---

## Success Criteria

| Criterion | Target |
|-----------|--------|
| System Uptime | 99.9% (less than 9 hours downtime/year) |
| Transaction Accuracy | Zero financial inconsistency |
| Audit Coverage | 100% of all financial operations logged |
| Regulatory Compliance | Full COPOMIS and PEARLS compliance |
| Response Time | < 2 seconds for 95th percentile of requests |
| Concurrent Users | Support 500 simultaneous users |
| Security | Zero critical vulnerabilities (OWASP Top 10) |
| Test Coverage | ≥ 80% unit and integration coverage |
| Scalability | Support 100,000+ members per instance |
| Maintainability | < 1 day to onboard new developer |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Biometric device SDK compatibility | Medium | High | Early POC, multiple vendor evaluation |
| Nepal BS calendar integration | Low | Medium | Use existing NepaliDateConverter library |
| SMS gateway downtime | Medium | Medium | Multi-gateway fallback (Sparrow → Aakash) |
| PostgreSQL performance at scale | Low | High | Query optimization, indexing, read replicas |
| Regulatory changes | Medium | High | Modular report design, easy configuration |
| Offline sync conflicts | Medium | High | Conflict resolution strategy with timestamps |
| Data migration from legacy system | High | High | Migration scripts, parallel run, validation |

---

## Team Structure (Recommended)

| Role | Count | Responsibility |
|------|-------|---------------|
| Project Manager | 1 | Timeline, coordination, client communication |
| Backend Developer | 2 | ASP.NET Core API, database design |
| Flutter Developer | 2 | Cross-platform app, mobile banking, collector app |
| Database Administrator | 1 | PostgreSQL optimization, migrations |
| QA Engineer | 1 | Testing, UAT coordination |
| DevOps Engineer | 1 | Docker, CI/CD, production deployment |
| UI/UX Designer | 1 | Flutter UI design, Figma prototypes |
