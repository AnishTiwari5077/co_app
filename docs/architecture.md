# SahakariMS — System Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │Flutter Admin │  │Flutter Member│  │   Flutter Collector      │  │
│  │(Windows/Web) │  │ Mobile App   │  │   Android App            │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘  │
└─────────┼─────────────────┼──────────────────────┼──────────────────┘
          │ HTTPS/REST       │ HTTPS/REST           │ HTTPS/REST + Offline
┌─────────▼─────────────────▼──────────────────────▼──────────────────┐
│                       API GATEWAY (Nginx)                           │
│              SSL Termination, Rate Limiting, Load Balance           │
└─────────────────────────────────┬────────────────────────────────────┘
                                  │
┌─────────────────────────────────▼────────────────────────────────────┐
│                      ASP.NET CORE 8 WEB API                         │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                   PRESENTATION LAYER                         │   │
│  │  Controllers │ Middleware │ Filters │ FluentValidation        │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │                   APPLICATION LAYER                          │   │
│  │  CQRS Commands │ Queries │ Handlers │ DTOs │ AutoMapper      │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │                     DOMAIN LAYER                             │   │
│  │  Entities │ Value Objects │ Domain Events │ Business Rules   │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │                  INFRASTRUCTURE LAYER                        │   │
│  │  EF Core │ Repositories │ SMS │ Email │ FCM │ MinIO          │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────┬──────────────────┬────────────────────────────────────┘
              │                  │
┌─────────────▼──────┐  ┌───────▼──────────────────────────────────────┐
│   Redis Cache      │  │             PostgreSQL 16                     │
│   Sessions,        │  │  Members, Accounts, Loans, Accounting,        │
│   Hot Data,        │  │  Audit Logs, Documents                        │
│   Rate Limits      │  │                                               │
└────────────────────┘  └───────────────────────────────────────────────┘
              │
┌─────────────▼──────────────────────────────────────────────────────┐
│                        EXTERNAL SERVICES                           │
│  ┌─────────────┐  ┌────────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Sparrow SMS │  │  SendGrid  │  │ Firebase │  │MinIO / AWS S3│  │
│  │  Nepal SMS  │  │   Email    │  │   FCM    │  │   Storage    │  │
│  └─────────────┘  └────────────┘  └──────────┘  └──────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

## Clean Architecture

SahakariMS follows **Clean Architecture** ensuring the business domain is independent of frameworks, UI, databases, and external services.

### Dependency Rule

Dependencies point **inward only**. Inner layers know nothing about outer layers.

```
Presentation → Application → Domain ← Infrastructure
```

### Layer Responsibilities

#### Domain Layer (`SahakariMS.Domain`)
- **Entities**: Member, Loan, SavingAccount, FixedDeposit, Voucher, Share
- **Value Objects**: Money (NPR), MemberCode, AccountNumber, PhoneNumber, NepaliDate
- **Domain Events**: MemberRegistered, LoanDisbursed, EMIPaymentReceived, FDMatured
- **Business Rules**: Enforced inside entity methods (invariants)
- **Repository Interfaces**: `ILoanRepository`, `IMemberRepository`, `IAccountRepository`
- **Domain Services**: `IInterestCalculationService`, `IEMIScheduleService`
- **Zero external dependencies** — pure C# classes

#### Application Layer (`SahakariMS.Application`)
- **CQRS Commands**: `DisburseLoanCommand`, `RegisterMemberCommand`, `PostJournalCommand`
- **CQRS Queries**: `GetMemberLoansQuery`, `GetTrialBalanceQuery`, `GetDashboardQuery`
- **MediatR Handlers**: One handler per command/query
- **DTOs**: Input/output data transfer objects
- **AutoMapper Profiles**: Entity ↔ DTO mapping
- **FluentValidation Validators**: Input validation for every command
- **Application Services**: Cross-cutting use case orchestration
- **Event Handlers**: React to domain events (send SMS, post audit)

#### Infrastructure Layer (`SahakariMS.Infrastructure`)
- **EF Core DbContext**: `SahakariDbContext` with entity configurations
- **Repository Implementations**: EF Core-backed repo classes
- **Unit of Work**: Coordinates multiple repos in one transaction
- **SMS Service**: Sparrow SMS API integration
- **Email Service**: SMTP / SendGrid integration
- **FCM Service**: Firebase push notification
- **MinIO Storage**: Document and photo upload/download
- **Hangfire Jobs**: Background interest posting, reminders
- **External API Clients**: FonePay QR, biometric SDK adapters

#### API Layer (`SahakariMS.API`)
- **Controllers**: Thin — dispatch to MediatR, return HTTP response
- **Middleware**: JWT validation, exception handling, request/response logging
- **Action Filters**: Permission checking, audit trail recording
- **Swagger / OpenAPI**: Auto-generated API documentation
- **DI Registration**: Wire all dependencies together

---

## CQRS Pattern with MediatR

```csharp
// Command — mutates state, returns Result
public record DisburseLoanCommand(
    Guid LoanId,
    decimal Amount,
    string DisbursementMode,
    Guid DisbursedBy
) : IRequest<Result<DisburseLoanResponse>>;

// Command Handler
public class DisburseLoanHandler : IRequestHandler<DisburseLoanCommand, Result<DisburseLoanResponse>>
{
    private readonly ILoanRepository _loans;
    private readonly IAccountingService _accounting;
    private readonly IUnitOfWork _uow;

    public async Task<Result<DisburseLoanResponse>> Handle(
        DisburseLoanCommand cmd, CancellationToken ct)
    {
        var loan = await _loans.GetByIdAsync(cmd.LoanId, ct);
        if (loan is null) return Result.Failure("Loan not found");

        loan.Disburse(cmd.Amount, cmd.DisbursedBy); // raises LoanDisbursedEvent
        await _accounting.PostDisbursementEntryAsync(loan, ct);
        await _uow.SaveChangesAsync(ct);

        return Result.Success(new DisburseLoanResponse(loan.Id, loan.LoanNumber));
    }
}

// Query — reads state, no side effects
public record GetMemberLoansQuery(Guid MemberId, LoanStatus? Status)
    : IRequest<Result<List<LoanSummaryDto>>>;
```

---

## Domain Events

Domain events decouple modules without tight coupling:

```csharp
// Raised inside Loan entity
public class LoanDisbursedEvent : IDomainEvent
{
    public Guid LoanId { get; }
    public Guid MemberId { get; }
    public decimal Amount { get; }
    public DateTime DisbursedAt { get; }
}

// Handler in notification module — sends SMS
public class SendDisbursementSmsHandler : INotificationHandler<LoanDisbursedEvent>
{
    public async Task Handle(LoanDisbursedEvent evt, CancellationToken ct)
    {
        // Send SMS: "Your loan of NPR {Amount} has been disbursed."
    }
}

// Handler in audit module — writes audit log
public class AuditLoanDisbursedHandler : INotificationHandler<LoanDisbursedEvent>
{
    public async Task Handle(LoanDisbursedEvent evt, CancellationToken ct)
    {
        // Insert into audit_logs table
    }
}
```

---

## Flutter Architecture

Feature-based Clean Architecture with Riverpod state management:

```
features/
└── loans/
    ├── data/
    │   ├── datasources/
    │   │   └── loan_remote_datasource.dart    # Dio API calls
    │   ├── models/
    │   │   ├── loan_model.dart                # JSON serializable
    │   │   └── loan_model.g.dart              # json_serializable
    │   └── repositories/
    │       └── loan_repository_impl.dart      # Implements domain repo
    ├── domain/
    │   ├── entities/
    │   │   └── loan.dart                      # Pure Dart entity
    │   ├── repositories/
    │   │   └── loan_repository.dart           # Abstract interface
    │   └── usecases/
    │       ├── get_member_loans_usecase.dart
    │       ├── disburse_loan_usecase.dart
    │       └── make_emi_payment_usecase.dart
    └── presentation/
        ├── pages/
        │   ├── loan_list_page.dart
        │   ├── loan_detail_page.dart
        │   └── loan_application_page.dart
        ├── widgets/
        │   ├── loan_card.dart
        │   ├── emi_schedule_widget.dart
        │   └── loan_status_badge.dart
        └── providers/
            ├── loan_provider.dart             # Riverpod StateNotifier
            └── loan_state.dart
```

---

## Data Flow Examples

### Write Operation (Command)

```
Flutter → Dio POST /api/v1/loans/{id}/disburse
  → Nginx (TLS termination + rate limit check)
  → PermissionMiddleware (check LOAN_DISBURSE permission)
  → LoanController.Disburse()
  → MediatR.Send(DisburseLoanCommand)
  → DisburseLoanHandler.Handle()
    → ILoanRepository.GetByIdAsync()       [PostgreSQL query]
    → loan.Disburse()                      [raises LoanDisbursedEvent]
    → IAccountingService.PostEntry()       [double-entry posting]
    → ILoanRepository.UpdateAsync()
    → MediatR publishes LoanDisbursedEvent
      → NotificationHandler → Sparrow SMS
      → AuditHandler        → audit_logs table
    → IUnitOfWork.SaveChangesAsync()       [atomic commit]
  → AuditMiddleware (log action)
  → 200 OK { loanId, loanNumber, disbursedAt }
```

### Read Operation (Query)

```
Flutter → Dio GET /api/v1/members/{id}/loans?status=Active
  → LoanController.GetMemberLoans()
  → MediatR.Send(GetMemberLoansQuery)
  → GetMemberLoansHandler.Handle()
    → Check Redis cache key "loans:member:{id}:Active"
      → HIT  → return cached List<LoanSummaryDto>
      → MISS → ILoanRepository.GetByMemberIdAsync()
               → Map to List<LoanSummaryDto> via AutoMapper
               → Cache result (TTL: 5 minutes)
  → 200 OK [ ...LoanSummaryDto array ]
```

---

## Database Architecture

### Design Principles

| Principle | Implementation |
|-----------|---------------|
| Primary Keys | `UUID v4` — prevents enumeration attacks |
| Soft Delete | `is_deleted`, `deleted_at`, `deleted_by` on all tables |
| Audit Columns | `created_at`, `updated_at`, `created_by`, `updated_by` |
| Branch Isolation | `branch_id FK` on all multi-branch entities |
| Monetary Precision | `NUMERIC(18,4)` for all financial amounts |
| Dual Calendar | `date_ad` (DATE) + `date_bs` (VARCHAR(10)) where needed |
| Row-Level Security | PostgreSQL RLS policies for branch isolation |
| Indexing | Covering indexes on common query patterns |
| Partitioning | `transaction_logs` partitioned by month |

### Key Schemas

| Schema | Purpose |
|--------|---------|
| `public` | Core cooperative entities |
| `accounting` | Chart of accounts, vouchers, ledger |
| `audit` | All audit log tables |
| `hr` | Employee management |
| `inventory` | Inventory management |

---

## Infrastructure Components

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| API Server | ASP.NET Core | 8.0 | Business logic + REST API |
| Database | PostgreSQL | 16 | Primary persistent data store |
| Cache | Redis | 7.0 | Sessions, hot data, rate limits |
| Object Storage | MinIO | Latest | Documents, photos, report files |
| Reverse Proxy | Nginx | 1.26 | SSL, load balancing, rate limiting |
| Background Jobs | Hangfire | 1.8 | Interest posting, EMI reminders |
| Monitoring | Prometheus + Grafana | Latest | Metrics and alerting |
| Logging | Serilog + ELK | Latest | Structured log aggregation |
| Container | Docker Compose | 2.24 | Service orchestration |
| CI/CD | GitHub Actions | Latest | Automated build/test/deploy |

---

## Scalability Strategy

### Horizontal Scaling
- Stateless API servers (JWT, no server session)
- Redis for distributed session and cache
- Nginx upstream load balancing across API instances

### Database Scaling
- PostgreSQL read replicas for report queries
- Connection pooling via PgBouncer
- Partial indexes for common filtered queries
- Table partitioning for high-volume logs

### Caching Strategy

| Data Type | Cache TTL | Cache Key Pattern |
|-----------|----------|-------------------|
| Member profile | 10 min | `member:{id}` |
| Loan summary | 5 min | `loan:member:{memberId}` |
| Dashboard data | 1 min | `dashboard:branch:{branchId}` |
| Account balance | 30 sec | `balance:account:{accountId}` |
| Trial balance | 5 min | `tb:branch:{branchId}:fiscal:{fiscalId}` |
| Interest rates | 60 min | `rates:branch:{branchId}` |

---

## Multi-Branch Architecture

```
HEAD OFFICE (Branch 0)
├── Full access to all branches
├── Consolidated reporting
└── Global settings management

BRANCH 1
├── Own members, accounts, loans
├── Own cash management
├── Own users and cashiers
└── Branch-level reports

BRANCH 2
├── (same structure)
└── Inter-branch transfers → approval workflow
```

PostgreSQL Row-Level Security enforces branch isolation at the database level, ensuring even a compromised application cannot leak cross-branch data.
