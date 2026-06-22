# SahakariMS — Coding Standards

## General Principles

All code in this project follows **SOLID**, **DRY**, **KISS**, and **Clean Code** principles. Every developer must read and adhere to these standards before contributing.

| Principle | Meaning | Application |
|-----------|---------|------------|
| **S**ingle Responsibility | One class = one reason to change | Each handler, service, and widget has a single purpose |
| **O**pen/Closed | Open for extension, closed for modification | Use interfaces and dependency injection |
| **L**iskov Substitution | Subtypes replace base types | All implementations honour their contracts |
| **I**nterface Segregation | Many specific interfaces > one general | Keep interfaces small and focused |
| **D**ependency Inversion | Depend on abstractions, not concretions | All dependencies injected via constructor |
| **DRY** | Don't Repeat Yourself | No duplicated business logic; shared via services |
| **KISS** | Keep It Simple | Simple, readable solutions preferred over clever ones |

---

## C# Coding Standards (ASP.NET Core)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Class | PascalCase | `LoanRepository`, `RegisterMemberHandler` |
| Interface | IPascalCase | `ILoanRepository`, `IMemberService` |
| Method | PascalCase | `GetByIdAsync`, `CalculateEMI` |
| Property | PascalCase | `MemberCode`, `OutstandingBalance` |
| Local Variable | camelCase | `loanAmount`, `memberId` |
| Parameter | camelCase | `memberId`, `cancellationToken` |
| Private Field | _camelCase | `_repository`, `_logger` |
| Constant | UPPER_SNAKE | `MAX_LOAN_AMOUNT`, `DEFAULT_INTEREST_RATE` |
| Enum | PascalCase | `LoanStatus.Active`, `MemberStatus.Pending` |
| Async Method | Suffix `Async` | `GetMemberAsync`, `DisburseLoanAsync` |

### File Structure per Class

```csharp
// 1. File-scoped namespace
namespace SahakariMS.Domain.Entities.Loans;

// 2. XML documentation on public classes
/// <summary>
/// Represents a cooperative loan issued to a member.
/// </summary>
public class Loan : AuditableEntity
{
    // 3. Private fields
    private readonly List<LoanSchedule> _schedule = [];
    private readonly List<LoanPayment> _payments = [];

    // 4. Constructor (private setters enforce invariants)
    private Loan() { }

    public static Loan Create(
        Guid memberId,
        LoanType type,
        decimal requestedAmount,
        int tenureMonths,
        decimal interestRate)
    {
        // Validate invariants
        Guard.Against.NegativeOrZero(requestedAmount, nameof(requestedAmount));
        Guard.Against.OutOfRange(interestRate, nameof(interestRate), 0, 50);

        var loan = new Loan
        {
            Id = Guid.NewGuid(),
            MemberId = memberId,
            Type = type,
            RequestedAmount = requestedAmount,
            TenureMonths = tenureMonths,
            InterestRate = interestRate,
            Status = LoanStatus.Pending,
            LoanNumber = GenerateLoanNumber()
        };

        // 5. Raise domain event
        loan.AddDomainEvent(new LoanApplicationSubmittedEvent(loan.Id, memberId));

        return loan;
    }

    // 6. Properties
    public Guid MemberId { get; private set; }
    public string LoanNumber { get; private set; } = default!;
    public LoanType Type { get; private set; }
    public decimal RequestedAmount { get; private set; }
    public decimal DisbursedAmount { get; private set; }
    public decimal OutstandingBalance { get; private set; }
    public int TenureMonths { get; private set; }
    public decimal InterestRate { get; private set; }
    public LoanStatus Status { get; private set; }

    // 7. Read-only collections
    public IReadOnlyList<LoanSchedule> Schedule => _schedule.AsReadOnly();
    public IReadOnlyList<LoanPayment> Payments => _payments.AsReadOnly();

    // 8. Domain methods
    public void Disburse(decimal amount, Guid disbursedBy)
    {
        if (Status != LoanStatus.Approved)
            throw new DomainException("Only approved loans can be disbursed.");

        DisbursedAmount = amount;
        OutstandingBalance = amount;
        Status = LoanStatus.Active;

        AddDomainEvent(new LoanDisbursedEvent(Id, MemberId, amount, disbursedBy));
    }
}
```

### Commands and Queries

```csharp
// Commands use record types
public record RegisterMemberCommand(
    string FirstName,
    string LastName,
    string CitizenshipNumber,
    string PhoneNumber,
    Guid BranchId
) : IRequest<Result<RegisterMemberResponse>>;

// Validators with FluentValidation
public class RegisterMemberCommandValidator : AbstractValidator<RegisterMemberCommand>
{
    public RegisterMemberCommandValidator()
    {
        RuleFor(x => x.FirstName)
            .NotEmpty().WithMessage("First name is required.")
            .MaximumLength(100).WithMessage("First name must not exceed 100 characters.");

        RuleFor(x => x.CitizenshipNumber)
            .NotEmpty()
            .Matches(@"^\d{2}-\d{2}-\d{2}-\d{5}$")
            .WithMessage("Invalid citizenship number format.");

        RuleFor(x => x.PhoneNumber)
            .NotEmpty()
            .Matches(@"^9[78]\d{8}$")
            .WithMessage("Invalid Nepal phone number.");
    }
}
```

### Controller Style

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
public class MembersController : ControllerBase
{
    private readonly ISender _mediator;
    private readonly ILogger<MembersController> _logger;

    public MembersController(ISender mediator, ILogger<MembersController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    /// <summary>Registers a new cooperative member.</summary>
    /// <response code="201">Member registered successfully</response>
    /// <response code="400">Validation error</response>
    /// <response code="409">Citizenship number already registered</response>
    [HttpPost]
    [RequirePermission(Permissions.Members.Create)]
    [ProducesResponseType(typeof(RegisterMemberResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Register(
        [FromBody] RegisterMemberRequest request,
        CancellationToken ct)
    {
        var command = new RegisterMemberCommand(
            request.FirstName, request.LastName,
            request.CitizenshipNumber, request.PhoneNumber,
            request.BranchId);

        var result = await _mediator.Send(command, ct);

        return result.IsSuccess
            ? CreatedAtAction(nameof(GetById), new { id = result.Value.Id }, result.Value)
            : BadRequest(result.ToProblemDetails());
    }
}
```

### Error Handling

```csharp
// Use Result<T> pattern — never throw for expected failures
public record Result<T>
{
    public bool IsSuccess { get; init; }
    public T? Value { get; init; }
    public string? Error { get; init; }
    public ErrorCode? ErrorCode { get; init; }

    public static Result<T> Success(T value) => new() { IsSuccess = true, Value = value };
    public static Result<T> Failure(string error, ErrorCode code = ErrorCode.General)
        => new() { IsSuccess = false, Error = error, ErrorCode = code };
}
```

---

## Dart / Flutter Coding Standards

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Class | UpperCamelCase | `MemberCard`, `LoanDetailPage` |
| Variable | lowerCamelCase | `memberList`, `loanAmount` |
| Constant | lowerCamelCase | `defaultTimeout`, `maxRetries` |
| File | snake_case | `member_card.dart`, `loan_detail_page.dart` |
| Directory | snake_case | `features/loans/`, `shared/widgets/` |
| Private | _prefixedCamelCase | `_controller`, `_isLoading` |

### Widget Structure

```dart
/// Displays a member summary card with avatar and key details.
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    this.onTap,
  });

  final MemberSummary member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: MemberAvatar(memberId: member.id, photoUrl: member.photoUrl),
        title: Text(member.fullName, style: AppTextStyles.bodyLarge),
        subtitle: Text(member.memberCode, style: AppTextStyles.caption),
        trailing: StatusBadge(status: member.status),
        onTap: onTap,
      ),
    );
  }
}
```

### Riverpod Providers

```dart
// State class
@freezed
class MemberState with _$MemberState {
  const factory MemberState.initial() = _Initial;
  const factory MemberState.loading() = _Loading;
  const factory MemberState.loaded(List<MemberSummary> members) = _Loaded;
  const factory MemberState.error(String message) = _Error;
}

// Notifier
@riverpod
class MemberNotifier extends _$MemberNotifier {
  @override
  MemberState build() => const MemberState.initial();

  Future<void> loadMembers({String? query}) async {
    state = const MemberState.loading();
    final result = await ref.read(memberRepositoryProvider).getMembers(query: query);
    state = result.fold(
      (error) => MemberState.error(error),
      (members) => MemberState.loaded(members),
    );
  }
}

// Usage in widget
class MemberListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberNotifierProvider);

    return state.when(
      initial: () => const SizedBox.shrink(),
      loading: () => const LoadingOverlay(),
      loaded: (members) => MemberListView(members: members),
      error: (msg) => ErrorView(message: msg, onRetry: () =>
          ref.read(memberNotifierProvider.notifier).loadMembers()),
    );
  }
}
```

---

## Database Conventions (PostgreSQL)

```sql
-- Table names: snake_case, plural
CREATE TABLE members (
    -- UUID primary key (always)
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Business key
    member_code     VARCHAR(20) NOT NULL UNIQUE,

    -- Foreign keys include table name prefix
    branch_id       UUID NOT NULL REFERENCES branches(id),

    -- Name columns: explicit first/last
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,

    -- Monetary values: NUMERIC(18,4)
    share_balance   NUMERIC(18,4) NOT NULL DEFAULT 0,

    -- Enums stored as VARCHAR with CHECK
    status          VARCHAR(20) NOT NULL DEFAULT 'Pending'
                    CHECK (status IN ('Pending','Active','Inactive','Closed')),

    -- Dual calendar dates
    date_of_birth_ad DATE,
    date_of_birth_bs VARCHAR(10),

    -- Standard audit columns (all tables)
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    deleted_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID NOT NULL REFERENCES users(id),
    updated_by      UUID NOT NULL REFERENCES users(id)
);

-- Indexes: idx_{table}_{columns}
CREATE INDEX idx_members_branch_id ON members(branch_id);
CREATE INDEX idx_members_member_code ON members(member_code);
CREATE INDEX idx_members_citizenship ON members(citizenship_number);
-- Partial index for active records
CREATE INDEX idx_members_active ON members(branch_id, status)
    WHERE is_deleted = FALSE AND status = 'Active';
```

---

## API Standards

- All endpoints under `/api/v1/`
- Plural nouns for resources: `/members`, `/loans`, `/accounts`
- Use HTTP verbs correctly: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`
- Always return `Result<T>` wrapper in successful responses
- Validation errors → `400 Bad Request` with `ProblemDetails`
- Auth errors → `401 Unauthorized`
- Permission errors → `403 Forbidden`
- Not found → `404 Not Found`
- Conflict → `409 Conflict`
- Server error → `500 Internal Server Error` (with correlation ID)
- All responses include `X-Correlation-ID` header
- Paginated responses include `X-Total-Count`, `X-Page`, `X-Page-Size` headers

---

## Git Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change, no new feature or bug fix |
| `test` | Adding or updating tests |
| `chore` | Build process or tooling changes |
| `perf` | Performance improvement |
| `style` | Formatting, whitespace (no logic change) |

**Examples:**
```
feat(loans): add loan rescheduling workflow
fix(interest): correct daily product calculation for leap year
docs(api): update loan disbursement endpoint docs
test(members): add KYC approval unit tests
chore(docker): upgrade PostgreSQL to 16.3
```

---

## Code Review Checklist

Before submitting a Pull Request:

- [ ] Code compiles without warnings
- [ ] All tests pass (`dotnet test` / `flutter test`)
- [ ] New functionality has unit tests
- [ ] No hardcoded secrets or connection strings
- [ ] No commented-out code blocks
- [ ] All public APIs have XML documentation (C#) or dartdoc (Dart)
- [ ] Database migrations are reversible
- [ ] No `N+1` query patterns
- [ ] Sensitive fields not logged in plain text
- [ ] Permission attribute on every controller action
- [ ] Audit logging on every financial operation
- [ ] Error messages are user-friendly (no stack traces to client)
