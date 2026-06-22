# SahakariMS — Technology Stack

## Overview

Every technology choice in SahakariMS is made with the following priorities:
1. **Reliability** — Financial software cannot lose data
2. **Security** — Member and financial data is highly sensitive
3. **Performance** — Sub-2-second response for all common operations
4. **Maintainability** — Long-term maintainability by a small team
5. **Ecosystem** — Strong community, long-term support, Nepal deployment-friendly

---

## Frontend: Flutter

| Attribute | Detail |
|-----------|--------|
| Version | Flutter 3.22 / Dart 3.4 |
| Platforms | Android, iOS, Windows (Desktop), Web |
| UI Framework | Material Design 3 |

### Why Flutter?

- **Single codebase** for Android (collector app, member app), iOS (member app), Windows (admin desktop), and Web (admin portal)
- Strong **offline-first** support via local SQLite
- Native performance for complex UIs (passbook, EMI schedule)
- Built-in support for **Bluetooth printing** (ESC/POS packages)
- **Riverpod** provides reactive, testable state management
- Nepal developer community familiarity

### Key Flutter Packages

| Package | Purpose |
|---------|---------|
| `riverpod` / `hooks_riverpod` | State management |
| `go_router` | Declarative routing + deep links |
| `dio` | HTTP client with interceptors |
| `flutter_secure_storage` | Secure token storage |
| `sqflite` | Local SQLite (collector offline) |
| `json_serializable` | JSON serialization |
| `freezed` | Immutable data classes + union types |
| `intl` | Nepali date formatting, currency |
| `nepali_date_converter` | BS/AD calendar conversion |
| `pdf` | Generate passbook and reports |
| `printing` | Print PDF to network/Bluetooth |
| `flutter_blue_plus` | Bluetooth printer connection |
| `camera` | Photo capture for KYC |
| `firebase_messaging` | Push notifications |
| `fl_chart` | Dashboard charts |
| `local_auth` | Biometric (fingerprint) login |

---

## Backend: ASP.NET Core 8

| Attribute | Detail |
|-----------|--------|
| Version | .NET 8 (LTS until Nov 2026) |
| Architecture | Clean Architecture + CQRS |
| API Style | RESTful Web API |

### Why ASP.NET Core?

- **Enterprise-grade** performance — among the fastest web frameworks
- Strong **type safety** reduces runtime errors in financial calculations
- **Entity Framework Core** with LINQ provides safe, typed queries
- **MediatR** enables clean CQRS implementation
- **FluentValidation** for robust input validation
- Built-in **dependency injection** and middleware pipeline
- .NET 8 is **LTS** — supported until November 2026
- Excellent **Docker** support

### Key NuGet Packages

| Package | Purpose |
|---------|---------|
| `MediatR` | CQRS / command-query bus |
| `FluentValidation` | Input validation |
| `AutoMapper` | Entity ↔ DTO mapping |
| `Microsoft.EntityFrameworkCore` | ORM |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | PostgreSQL provider |
| `StackExchange.Redis` | Redis client |
| `Serilog` | Structured logging |
| `Hangfire` | Background job scheduling |
| `Swashbuckle.AspNetCore` | Swagger/OpenAPI |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | JWT authentication |
| `Ardalis.GuardClauses` | Guard clauses for domain validation |
| `Minio` | MinIO / S3 object storage |
| `FirebaseAdmin` | Firebase FCM push notifications |

---

## Database: PostgreSQL 16

| Attribute | Detail |
|-----------|--------|
| Version | PostgreSQL 16 |
| ORM | Entity Framework Core 8 |
| Migration | EF Core Migrations |

### Why PostgreSQL?

- **ACID compliance** — critical for financial transactions
- **NUMERIC type** — exact decimal precision for monetary calculations
- **Row-Level Security (RLS)** — enforce branch data isolation at DB level
- **Stored Procedures** — complex financial calculations in the DB
- **Triggers** — automatic audit trail on financial tables
- **Table Partitioning** — partition high-volume audit/transaction tables by month
- **Excellent indexing** — partial indexes, composite indexes, covering indexes
- **JSON columns** — flexible storage for metadata without schema changes
- Open source with strong community support in Nepal

### Database Features Used

| Feature | Usage |
|---------|-------|
| UUID primary keys | Prevent ID enumeration attacks |
| NUMERIC(18,4) | All monetary amounts |
| TIMESTAMPTZ | All timestamps (timezone-aware) |
| Row-Level Security | Branch data isolation |
| Triggers | Audit log generation |
| Stored Procedures | Interest calculation, EMI schedule |
| Partial Indexes | Optimise active-record queries |
| Table Partitioning | `audit_logs`, `transaction_logs` by month |
| Full-Text Search | Member name and document search |

---

## Cache: Redis 7

| Attribute | Detail |
|-----------|--------|
| Version | Redis 7.0 |
| Client | StackExchange.Redis |
| Usage | Distributed cache + session storage |

### Cached Data

| Data | TTL | Key Pattern |
|------|-----|-------------|
| User sessions | 24 hours | `session:{userId}` |
| Member profile | 10 min | `member:{id}` |
| Account balance | 30 sec | `balance:{accountId}` |
| Dashboard stats | 1 min | `dashboard:branch:{branchId}` |
| Trial balance | 5 min | `tb:{branchId}:{fiscalId}` |
| Interest rates | 60 min | `rates:{branchId}` |
| Role permissions | 30 min | `perms:{roleId}` |
| OTP codes | 5 min | `otp:{mobile}` |

---

## Object Storage: MinIO

| Attribute | Detail |
|-----------|--------|
| Software | MinIO (S3-compatible) |
| Deployment | Self-hosted on same server |
| SDK | Official Minio .NET SDK |

### Storage Buckets

| Bucket | Contents |
|--------|---------|
| `member-photos` | Member profile photos |
| `kyc-documents` | Citizenship, PAN, passport scans |
| `loan-documents` | Loan agreements, guarantor docs |
| `property-documents` | Collateral property documents |
| `signatures` | Digital signature images |
| `reports` | Generated PDF and Excel reports |
| `backups` | Database backup archives |

Files are stored with UUID filenames and served via pre-signed URLs (valid 1 hour).

---

## Authentication: JWT + Refresh Tokens

| Attribute | Detail |
|-----------|--------|
| Algorithm | RS256 (asymmetric key signing) |
| Access Token TTL | 15 minutes |
| Refresh Token TTL | 7 days |
| Storage (Flutter) | flutter_secure_storage (encrypted keychain) |

### Token Flow

```
Login → Access Token (15 min) + Refresh Token (7 days, httpOnly cookie)
  → Access token expires → client sends refresh token
  → Server validates + rotates refresh token
  → New access token + new refresh token issued
  → Old refresh token invalidated (rotation prevents reuse)
```

---

## Push Notifications: Firebase FCM

| Attribute | Detail |
|-----------|--------|
| Service | Firebase Cloud Messaging |
| SDK | FirebaseAdmin .NET SDK (server), firebase_messaging (Flutter) |
| Platforms | Android + iOS + Web |

---

## SMS Gateway: Sparrow SMS

| Attribute | Detail |
|-----------|--------|
| Primary | Sparrow SMS (Nepal) |
| Fallback | Aakash SMS |
| Integration | REST API |

Sparrow SMS is the most widely used SMS gateway in Nepal with reliable delivery and competitive pricing. The system supports automatic fallback to Aakash SMS if Sparrow SMS is unavailable.

---

## Containerization: Docker

| Attribute | Detail |
|-----------|--------|
| Runtime | Docker Engine 24+ |
| Orchestration | Docker Compose (single server) |
| Production | Docker Compose with resource limits |
| Image Registry | GitHub Container Registry (ghcr.io) |

### Docker Services

```yaml
services:
  api:        # ASP.NET Core API
  db:         # PostgreSQL 16
  redis:      # Redis 7
  minio:      # MinIO object storage
  nginx:      # Reverse proxy + SSL
  hangfire:   # Background job server
  prometheus: # Metrics collection
  grafana:    # Metrics dashboard
```

---

## CI/CD: GitHub Actions

### Workflows

| Workflow | Trigger | Actions |
|---------|---------|---------|
| `build-test.yml` | Every PR | Build, lint, run tests |
| `security-scan.yml` | Every PR | OWASP Dependency Check |
| `deploy-staging.yml` | Push to `develop` | Deploy to staging server |
| `deploy-prod.yml` | Push to `main` | Deploy to production server |

---

## Monitoring: Prometheus + Grafana

| Component | Tool |
|-----------|------|
| Metrics collection | Prometheus |
| Dashboards | Grafana |
| Structured logging | Serilog → Elasticsearch |
| Log visualisation | Kibana |
| Uptime monitoring | UptimeRobot |

### Key Metrics Tracked

- API request count, error rate, response time (p50, p95, p99)
- Database connection pool usage
- Redis cache hit/miss ratio
- Background job success/failure count
- Active user sessions
- SMS delivery success rate

---

## Technology Decisions Log

| Decision | Chosen | Alternatives Considered | Reason |
|----------|--------|------------------------|--------|
| Frontend | Flutter | React Native, Xamarin | Single codebase for all platforms, offline support |
| Backend | ASP.NET Core | Node.js NestJS, Spring Boot | Type safety for financial calculations, .NET ecosystem |
| Database | PostgreSQL | MySQL, SQL Server | RLS, NUMERIC precision, open source, Nepal hosting |
| Cache | Redis | In-memory, Memcached | Distributed cache, pub/sub, persistence |
| Architecture | Clean + CQRS | MVC, N-tier | Testability, separation, scalability |
| Auth | JWT RS256 | Session-based, OAuth | Stateless, scalable, mobile-compatible |
| SMS | Sparrow SMS | Ncell BULK, Message Hive | Nepal coverage, reliable API, local support |
| Storage | MinIO | AWS S3, Azure Blob | Self-hosted, S3-compatible, no cloud dependency |
| Background Jobs | Hangfire | Quartz.NET, hosted services | Dashboard, retry, persistence, easy setup |
