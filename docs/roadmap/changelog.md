# SahakariMS — Changelog

All notable changes to SahakariMS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Initial project scaffold and documentation

---

## [0.1.0] — 2081-04-15 (Initial Foundation)

### Added
- ASP.NET Core 8 Clean Architecture scaffold
- Flutter project setup with Riverpod and GoRouter
- PostgreSQL 16 database with EF Core migrations
- Redis 7 cache integration
- JWT RS256 authentication (login, refresh, logout)
- Role-based access control (RBAC) with granular permissions
- Docker Compose development environment
- GitHub Actions CI/CD pipeline
- Serilog structured logging
- Swagger/OpenAPI documentation at `/swagger`
- Health check endpoint at `/health`
- Global exception handling middleware
- Audit action filter for activity logging
- Seed data: roles, permissions, system accounts, default admin user
- Flutter login screen with form validation
- Flutter auth state management (Riverpod)
- Secure token storage (flutter_secure_storage)
- Auto token refresh via Dio interceptor

### Technical
- `SahakariMS.Domain` — pure C# domain entities
- `SahakariMS.Application` — CQRS handlers with MediatR
- `SahakariMS.Infrastructure` — EF Core, Redis, MinIO, SMS
- `SahakariMS.API` — ASP.NET Core web API host

---

## How to Read This Changelog

### Categories

- **Added** — New features
- **Changed** — Changes to existing features
- **Deprecated** — Features to be removed in future
- **Removed** — Removed features
- **Fixed** — Bug fixes
- **Security** — Security patches and hardening

### Versioning

- **Major (X.0.0)** — Breaking changes, major rewrites
- **Minor (0.X.0)** — New features, backward compatible
- **Patch (0.0.X)** — Bug fixes, security patches

---

## Planned Releases

```
v0.2.0  — Members, Shares, Savings                     Week 10
v0.3.0  — Loans (application through closure)          Week 16
v0.4.0  — Accounting (vouchers, trial balance)         Week 20
v0.5.0  — Beta (FD, RD, notifications, reports)        Week 26
v0.6.0  — Collector App (Android, offline)             Week 30
v0.7.0  — Mobile Banking App                           Week 34
v0.8.0  — Reports & COPOMIS                            Week 38
v0.9.0  — Security hardening, load tested              Week 42
v1.0.0  — Production launch                            Week 47
```

---

## Deprecation Policy

- Features are announced as deprecated at least **2 minor versions** before removal
- Deprecated features still work but emit deprecation warnings in logs
- Breaking changes only occur in major version bumps

---

## Security Advisories

Security vulnerabilities are reported at: security@sahakarims.np

- Response time: < 24 hours
- Fix deployment: < 72 hours for critical, < 2 weeks for high
- Public disclosure: After patch is deployed to all installations
