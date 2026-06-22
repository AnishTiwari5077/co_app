# SahakariMS — Development Roadmap

## Release Plan

```
MVP (v0.1)          Beta (v0.5)          v1.0               v2.0
Week 1─────────────Week 18──────────────Week 34────────────Week 47+
│                   │                    │                   │
│ Core system       │ Field operations   │ Full system        │ AI features
│ Auth              │ Collector App      │ QR payments        │ OCR KYC
│ Members           │ Mobile Banking     │ Multi-branch       │ Face recognition
│ Shares            │ Notifications      │ Advanced reports   │ Chatbot
│ Savings           │ Full Savings       │ Security v2        │ BI Dashboard
│ Basic Loans       │ Advanced Loans     │ NRB Reports        │ Predictive
│ Core Accounting   │ Full Accounting    │ Performance opt.   │ Analytics
│ Essential Reports │ Audit System       │ Load testing       │
│                   │ COPOMIS            │ Production ready   │
```

---

## Sprint Plan (2-week Sprints)

### Sprint 1 (Weeks 1–2) — Project Setup

**Goal:** Working development environment, CI/CD pipeline, base API

| Task | Owner | Status |
|------|-------|--------|
| GitHub repository with branch protection | DevOps | Planned |
| GitHub Actions CI/CD pipeline | DevOps | Planned |
| Docker Compose dev environment | DevOps | Planned |
| ASP.NET Core 8 Clean Architecture scaffold | Backend | Planned |
| Flutter project setup (Riverpod + GoRouter) | Flutter | Planned |
| PostgreSQL schema with EF Core | Backend | Planned |
| Redis cache configuration | Backend | Planned |
| Serilog structured logging | Backend | Planned |
| Global exception handling | Backend | Planned |
| JWT authentication middleware | Backend | Planned |
| Health check endpoints | Backend | Planned |
| Swagger/OpenAPI setup | Backend | Planned |

**Sprint 1 Deliverable:** `GET /health` returns 200, Swagger UI accessible, Login endpoint working

---

### Sprint 2 (Weeks 3–4) — Auth & User Management

**Goal:** Full authentication system, user and role management

| Task | Owner |
|------|-------|
| Login endpoint with JWT issuance | Backend |
| Refresh token rotation | Backend |
| OTP generation and verification | Backend |
| 2FA with TOTP | Backend |
| Password change and reset | Backend |
| Role and permission CRUD | Backend |
| User management CRUD | Backend |
| Login Flutter screen | Flutter |
| OTP verification Flutter screen | Flutter |
| Secure token storage | Flutter |
| Auth state management (Riverpod) | Flutter |
| Role-based route guards | Flutter |

---

### Sprint 3 (Weeks 5–6) — Member Registration

**Goal:** Complete member registration and KYC workflow

| Task | Owner |
|------|-------|
| Member entity and domain rules | Backend |
| Member registration API | Backend |
| KYC document upload to MinIO | Backend |
| Digital signature upload | Backend |
| Member approval workflow API | Backend |
| Member list and search API | Backend |
| Member registration Flutter form | Flutter |
| KYC document capture (camera) | Flutter |
| Signature capture widget | Flutter |
| Member list and search Flutter page | Flutter |
| Member detail Flutter page | Flutter |

---

### Sprint 4 (Weeks 7–8) — Member Extended + Share Management

**Goal:** Complete member profile, nominees, and share management

| Task | Owner |
|------|-------|
| Nominee management API | Backend |
| Family details API | Backend |
| Fingerprint registration (SDK) | Backend |
| Share purchase API with accounting | Backend |
| Share refund/transfer API | Backend |
| Dividend calculation service | Backend |
| Share certificate PDF generation | Backend |
| Nominee form Flutter widget | Flutter |
| Share management Flutter pages | Flutter |
| Share certificate preview | Flutter |

---

### Sprint 5 (Weeks 9–10) — Savings Accounts

**Goal:** Savings account opening, deposit, withdrawal

| Task | Owner |
|------|-------|
| Savings scheme configuration | Backend |
| Savings account entity and rules | Backend |
| Open account API | Backend |
| Deposit API + accounting entry | Backend |
| Withdrawal API + accounting entry | Backend |
| Account freeze/unfreeze API | Backend |
| Account statement API (PDF + JSON) | Backend |
| Savings Flutter pages | Flutter |
| Deposit/withdrawal forms | Flutter |
| Receipt generation (PDF) | Flutter |
| Statement viewer Flutter | Flutter |

---

### Sprint 6 (Weeks 11–12) — Fixed Deposit & RD

**Goal:** FD and RD management with interest calculation

| Task | Owner |
|------|-------|
| FD entity with interest rules | Backend |
| Create FD API | Backend |
| Premature closure API | Backend |
| FD auto-renewal on maturity | Backend |
| FD maturity background job (Hangfire) | Backend |
| RD installment management | Backend |
| Daily interest accrual job | Backend |
| Monthly interest posting job | Backend |
| FD management Flutter pages | Flutter |
| FD certificate Flutter viewer | Flutter |
| RD tracking Flutter pages | Flutter |

---

### Sprint 7 (Weeks 13–14) — Loan Application & Approval

**Goal:** Complete loan application and approval workflow

| Task | Owner |
|------|-------|
| Loan product configuration | Backend |
| Loan application entity and domain | Backend |
| Loan application API | Backend |
| Guarantor management API | Backend |
| Collateral registration API | Backend |
| Approval workflow API (staged) | Backend |
| Loan rejection with reason | Backend |
| Loan application Flutter form | Flutter |
| Guarantor selection Flutter | Flutter |
| Approval workflow Flutter UI | Flutter |
| Pending approvals dashboard | Flutter |

---

### Sprint 8 (Weeks 15–16) — Loan Disbursement & EMI

**Goal:** Loan disbursement, EMI schedule, and payment

| Task | Owner |
|------|-------|
| EMI schedule generation service | Backend |
| Loan disbursement API | Backend |
| EMI payment API | Backend |
| Penalty calculation service | Backend |
| Partial/advance payment API | Backend |
| Loan schedule view API | Backend |
| Disbursement Flutter page | Flutter |
| EMI schedule Flutter table | Flutter |
| EMI payment Flutter form | Flutter |
| Receipt Flutter widget | Flutter |

---

### Sprint 9 (Weeks 17–18) — Accounting Core

**Goal:** Chart of accounts, voucher entry, ledger

| Task | Owner |
|------|-------|
| Chart of accounts CRUD API | Backend |
| Journal voucher entry API | Backend |
| Payment/receipt/contra vouchers | Backend |
| General ledger query API | Backend |
| Trial balance API | Backend |
| Auto voucher creation for all transactions | Backend |
| Chart of accounts Flutter page | Flutter |
| Voucher entry Flutter form | Flutter |
| Ledger viewer Flutter page | Flutter |
| Trial balance Flutter page | Flutter |

---

### Sprint 10 (Weeks 19–20) — Cash Counter

**Goal:** Cash counter session management

| Task | Owner |
|------|-------|
| Cash session open/close API | Backend |
| Denomination tracking | Backend |
| Cash reconciliation report API | Backend |
| Vault transfer API | Backend |
| Cash counter Flutter page | Flutter |
| Denomination entry Flutter widget | Flutter |
| Cash session summary Flutter | Flutter |

---

### Sprint 11 (Weeks 21–23) — Collector App

**Goal:** Offline-capable Android collector app

| Task | Owner |
|------|-------|
| Collector assignment API | Backend |
| Collection sync API (bulk upload) | Backend |
| Conflict resolution logic | Backend |
| Offline SQLite schema (Flutter) | Flutter |
| Offline collection flow | Flutter |
| GPS location capture | Flutter |
| Bluetooth printer (ESC/POS) | Flutter |
| Collector daily summary Flutter | Flutter |
| Cash handover Flutter flow | Flutter |
| Background sync service | Flutter |

---

### Sprint 12 (Weeks 24–26) — Notifications & SMS

**Goal:** Full notification system across all channels

| Task | Owner |
|------|-------|
| Sparrow SMS integration | Backend |
| Email (SendGrid) integration | Backend |
| Firebase FCM integration | Backend |
| Notification templates | Backend |
| OTP delivery service | Backend |
| EMI reminder job | Backend |
| FD maturity reminder job | Backend |
| Birthday greetings job | Backend |
| Notification centre Flutter page | Flutter |
| Push notification handling | Flutter |

---

### Sprint 13 (Weeks 27–29) — Mobile Banking

**Goal:** Member-facing mobile banking app

| Task | Owner |
|------|-------|
| Member authentication API | Backend |
| Member dashboard API | Backend |
| Fund transfer API | Backend |
| QR payment integration | Backend |
| Utility bill payment API | Backend |
| Loan application from mobile API | Backend |
| Mobile login Flutter screen | Flutter |
| Mobile dashboard Flutter | Flutter |
| Fund transfer Flutter | Flutter |
| QR scanner Flutter widget | Flutter |
| Utility payment Flutter | Flutter |
| Statement download Flutter | Flutter |

---

### Sprint 14 (Weeks 30–32) — Reports Module

**Goal:** All financial and operational reports

| Task | Owner |
|------|-------|
| Trial balance report API | Backend |
| Balance sheet API | Backend |
| P&L statement API | Backend |
| Loan outstanding report | Backend |
| Defaulter list API | Backend |
| FD maturity report API | Backend |
| COPOMIS export API | Backend |
| PDF report generation | Backend |
| Excel export (EPPlus) | Backend |
| Reports Flutter navigation | Flutter |
| Report viewer Flutter | Flutter |
| PDF download Flutter | Flutter |

---

### Sprint 15 (Weeks 33–34) — Audit System

**Goal:** Complete audit and activity logging

| Task | Owner |
|------|-------|
| Audit action filter | Backend |
| Transaction audit DB triggers | DB |
| Login history logging | Backend |
| Audit log query API | Backend |
| Security event alerting | Backend |
| Audit log Flutter pages | Flutter |
| Login history Flutter | Flutter |

---

### Sprint 16 (Weeks 35–37) — Advanced Loans

**Goal:** NPA management, rescheduling, write-offs

| Task | Owner |
|------|-------|
| NPA classification job | Backend |
| Loan rescheduling API | Backend |
| Loan restructuring API | Backend |
| Loan write-off API | Backend |
| NOC generation (PDF) | Backend |
| Recovery from guarantor API | Backend |
| NPA dashboard Flutter | Flutter |
| Rescheduling Flutter form | Flutter |

---

### Sprint 17 (Weeks 38–40) — HR & Assets

**Goal:** Employee management, payroll, asset tracking

| Task | Owner |
|------|-------|
| Employee CRUD API | Backend |
| Attendance management | Backend |
| Leave management | Backend |
| Payroll calculation | Backend |
| Asset registration and depreciation | Backend |
| HR Flutter pages | Flutter |
| Asset management Flutter pages | Flutter |

---

### Sprint 18 (Weeks 41–43) — Security Hardening

**Goal:** Production-grade security

| Task | Owner |
|------|-------|
| API rate limiting per user | Backend |
| Device fingerprint tracking | Backend |
| Anomaly detection alerts | Backend |
| PII field encryption (AES-256) | Backend |
| Security headers middleware | Backend |
| Penetration testing | Security |
| Vulnerability remediation | All |
| Security documentation | All |

---

### Sprint 19 (Weeks 44–45) — Performance & Testing

**Goal:** Performance optimization and full test coverage

| Task | Owner |
|------|-------|
| Database query optimization | Backend |
| Redis caching for hot queries | Backend |
| k6 load testing (500 users) | DevOps |
| Full integration test suite | Backend |
| Flutter widget test completion | Flutter |
| UAT with cooperative staff | PM |
| Bug fixes from UAT | All |

---

### Sprint 20 (Weeks 46–47) — Production Launch

**Goal:** Production deployment and go-live

| Task | Owner |
|------|-------|
| Production server setup | DevOps |
| SSL certificate | DevOps |
| Production Docker deployment | DevOps |
| Database migration (live data) | Backend |
| Monitoring dashboards (Grafana) | DevOps |
| Automated backup validation | DevOps |
| Staff training sessions | PM |
| Go-live smoke tests | All |
| Runbook documentation | DevOps |

---

## Velocity Assumptions

- Backend team: 2 developers × 5 days/week × 8 hours = 80 hrs/sprint
- Flutter team: 2 developers × 5 days/week × 8 hours = 80 hrs/sprint
- Story point = ~4 hours of work
- Each sprint capacity: ~40 story points per team

---

## Dependencies and Critical Path

```
Auth (Sprint 2) ──────────────────────────┐
Member (Sprint 3–4) ──────────────────┐   │
Savings (Sprint 5–6) ──────┐          │   │
                           ├─── Loans ─┼── Dashboard
Accounting (Sprint 9) ─────┘  (7–8)   │
                                       │
                           Collector App (11)
                           Mobile Banking (13)
```

The **critical path** is: Auth → Members → Savings → Loans → Accounting. All other modules can be developed in parallel by a second team.
