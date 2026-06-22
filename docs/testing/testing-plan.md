# SahakariMS — Testing Plan

## Testing Strategy Overview

SahakariMS employs a comprehensive, multi-layered testing strategy to ensure correctness, security, and performance of all financial operations.

```
                    Manual Testing
                   ───────────────
                 End-to-End (E2E) Tests
                ─────────────────────────
            Integration Tests (API + Database)
           ─────────────────────────────────────
        Unit Tests (Domain Logic + Application Layer)
       ─────────────────────────────────────────────────
              Static Analysis + Linting
```

---

## Testing Frameworks

| Layer | Framework | Language |
|-------|----------|---------|
| Domain unit tests | xUnit + FluentAssertions | C# |
| Integration tests | xUnit + TestContainers | C# |
| API tests | xUnit + WebApplicationFactory | C# |
| Flutter unit tests | flutter_test | Dart |
| Flutter widget tests | flutter_test | Dart |
| Performance tests | k6 | JavaScript |
| Security scanning | OWASP ZAP | Automated |

---

## 1. Unit Tests

### Coverage Target: 90% for Domain Layer, 80% for Application Layer

### Domain Entity Tests

```csharp
// Tests/Unit/Domain/LoanTests.cs
public class LoanTests
{
    [Fact]
    public void Disburse_WhenLoanIsApproved_ShouldSetActiveStatus()
    {
        // Arrange
        var loan = Loan.Create(memberId, LoanType.Personal, 500000, 60, 14.0m);
        loan.Approve(500000, approverId);

        // Act
        loan.Disburse(500000, disburserId);

        // Assert
        loan.Status.Should().Be(LoanStatus.Active);
        loan.DisbursedAmount.Should().Be(500000);
        loan.OutstandingBalance.Should().Be(500000);
    }

    [Fact]
    public void Disburse_WhenLoanIsPending_ShouldThrowDomainException()
    {
        // Arrange
        var loan = Loan.Create(memberId, LoanType.Personal, 500000, 60, 14.0m);

        // Act & Assert
        var act = () => loan.Disburse(500000, disburserId);
        act.Should().Throw<DomainException>()
           .WithMessage("Only approved loans can be disbursed.");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1000)]
    public void Create_WithNonPositiveAmount_ShouldThrowArgumentException(decimal amount)
    {
        var act = () => Loan.Create(memberId, LoanType.Personal, amount, 60, 14.0m);
        act.Should().Throw<ArgumentException>();
    }
}
```

### Interest Calculation Tests

```csharp
public class InterestCalculationServiceTests
{
    private readonly InterestCalculationService _sut = new();

    [Theory]
    [InlineData(100000, 7.5, false, 20.55)]   // non-leap year
    [InlineData(100000, 7.5, true,  20.49)]   // leap year
    [InlineData(0, 7.5, false, 0)]             // zero balance
    [InlineData(100000, 0, false, 0)]          // zero rate
    public void CalculateDailyInterest_ShouldReturnCorrectAmount(
        decimal balance, decimal rate, bool isLeapYear, decimal expected)
    {
        var result = _sut.CalculateDailyInterest(balance, rate, isLeapYear);
        result.Should().BeApproximately(expected, 0.01m);
    }

    [Fact]
    public void GenerateEMISchedule_ShouldBalanceToZeroAtEnd()
    {
        var schedule = _sut.GenerateReducingBalanceSchedule(500000, 14.0m, 60, DateTime.Today);

        schedule.Last().ClosingBalance.Should().BeApproximately(0, 0.50m);
        schedule.Count.Should().Be(60);
        schedule.All(s => s.PrincipalAmount > 0).Should().BeTrue();
    }
}
```

### Member Domain Tests

```csharp
public class MemberTests
{
    [Fact]
    public void Create_WhenAgeUnder18_ShouldThrowDomainException()
    {
        var dateOfBirth = DateOnly.FromDateTime(DateTime.Today.AddYears(-17));
        var act = () => Member.Create("Ram", "Shrestha", dateOfBirth, branchId, createdBy);
        act.Should().Throw<DomainException>().WithMessage("*18*");
    }

    [Fact]
    public void Close_WhenOutstandingLoanExists_ShouldThrowDomainException()
    {
        var member = CreateActiveMember();
        member.SetLoanOutstanding(50000);

        var act = () => member.Close("Test reason", closedBy);
        act.Should().Throw<DomainException>()
           .WithMessage("*outstanding loan*");
    }
}
```

---

## 2. Integration Tests

### Setup with TestContainers

```csharp
public class IntegrationTestBase : IAsyncLifetime
{
    protected readonly PostgreSqlContainer _postgres;
    protected readonly RedisContainer _redis;
    protected SahakariDbContext _db;

    public IntegrationTestBase()
    {
        _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:16")
            .WithDatabase("sahakarims_test")
            .Build();

        _redis = new RedisBuilder()
            .WithImage("redis:7")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
        await _redis.StartAsync();

        var options = new DbContextOptionsBuilder<SahakariDbContext>()
            .UseNpgsql(_postgres.GetConnectionString())
            .Options;

        _db = new SahakariDbContext(options);
        await _db.Database.MigrateAsync();
        await SeedTestDataAsync();
    }
}
```

### API Integration Tests

```csharp
public class MembersControllerTests : IntegrationTestBase
{
    [Fact]
    public async Task Post_WithValidData_ShouldReturn201WithMemberCode()
    {
        // Arrange
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", await GetCashierToken());

        var request = new RegisterMemberRequest
        {
            FirstName = "Sita",
            LastName = "Tamang",
            DateOfBirthAd = new DateOnly(1985, 6, 15),
            CitizenshipNumber = "23-01-75-99999",
            PhoneNumber = "9845678901",
            AddressDistrict = "Lalitpur",
            AddressMunicipality = "Lalitpur Metropolitan City",
            BranchId = _testBranchId
        };

        // Act
        var response = await client.PostAsJsonAsync("/api/v1/members", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);
        var result = await response.Content.ReadFromJsonAsync<RegisterMemberResponse>();
        result.Should().NotBeNull();
        result!.MemberCode.Should().StartWith("KTM-");
    }

    [Fact]
    public async Task Post_WithDuplicateCitizenship_ShouldReturn409()
    {
        // Test duplicate citizenship number
        var request = BuildValidRequest(citizenshipNumber: _existingCitizenshipNumber);
        var response = await _client.PostAsJsonAsync("/api/v1/members", request);
        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }
}
```

### Loan Payment Integration Test

```csharp
[Fact]
public async Task MakeEMIPayment_ShouldUpdateLoanBalanceAndCreateVoucher()
{
    // Arrange — create active loan with known balance
    var loan = await CreateActiveLoan(500000, 60, 14.0m);
    var expectedPrincipal = loan.Schedule[0].PrincipalAmount;

    // Act
    var response = await _client.PostAsJsonAsync(
        $"/api/v1/loans/{loan.Id}/payment",
        new { Amount = loan.Schedule[0].EmiAmount, PaymentMode = "Cash" });

    // Assert
    response.StatusCode.Should().Be(HttpStatusCode.OK);

    var updatedLoan = await _db.Loans.FindAsync(loan.Id);
    updatedLoan!.OutstandingBalance.Should()
        .BeApproximately(500000 - expectedPrincipal, 0.01m);

    // Verify accounting voucher was created
    var voucher = await _db.Vouchers
        .FirstOrDefaultAsync(v => v.ReferenceId == loan.Id);
    voucher.Should().NotBeNull();
    voucher!.IsPosted.Should().BeTrue();
}
```

---

## 3. Flutter Widget Tests

```dart
// test/widget/members/member_card_test.dart
void main() {
  testWidgets('MemberCard shows member name and status', (tester) async {
    final member = MemberSummary(
      id: 'test-id',
      memberCode: 'KTM-2081-001',
      fullName: 'Sita Tamang',
      status: MemberStatus.active,
      totalSavings: 45000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberCard(member: member),
        ),
      ),
    );

    expect(find.text('Sita Tamang'), findsOneWidget);
    expect(find.text('KTM-2081-001'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
  });

  testWidgets('MemberCard calls onTap when tapped', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberCard(
            member: testMember,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MemberCard));
    expect(tapped, isTrue);
  });
}
```

---

## 4. Performance Tests (k6)

```javascript
// tests/performance/login_load_test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // Ramp up to 50 users
    { duration: '2m',  target: 200 },  // Hold at 200 users
    { duration: '30s', target: 500 },  // Spike to 500 users
    { duration: '1m',  target: 200 },  // Scale back
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95% of requests < 2s
    http_req_failed:   ['rate<0.01'],   // Error rate < 1%
    errors:            ['rate<0.01'],
  },
};

export default function () {
  // Test login endpoint
  const loginRes = http.post(
    `${__ENV.BASE_URL}/api/v1/auth/login`,
    JSON.stringify({ username: 'cashier01', password: 'Test@123' }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  check(loginRes, {
    'login status is 200': (r) => r.status === 200,
    'has access token': (r) => JSON.parse(r.body).accessToken !== undefined,
  });

  errorRate.add(loginRes.status !== 200);

  // Test member search
  const token = JSON.parse(loginRes.body).accessToken;
  const searchRes = http.get(
    `${__ENV.BASE_URL}/api/v1/members?search=Ram&page=1&pageSize=10`,
    { headers: { Authorization: `Bearer ${token}` } }
  );

  check(searchRes, {
    'search status is 200': (r) => r.status === 200,
    'search returns results': (r) => JSON.parse(r.body).data.length >= 0,
  });

  sleep(1);
}
```

---

## 5. Security Testing

### OWASP ZAP Automated Scan

```bash
# Run OWASP ZAP API scan
docker run -t owasp/zap2docker-stable zap-api-scan.py \
  -t https://staging-api.sahakarims.np/swagger/v1/swagger.json \
  -f openapi \
  -r zap-report.html \
  -l PASS
```

### Manual Security Test Scenarios

| Test | Method | Expected |
|------|--------|---------|
| SQL Injection in member search | `'; DROP TABLE members; --` | 400 Bad Request |
| XSS in narration field | `<script>alert(1)</script>` | Input sanitized |
| JWT without signature | Tampered token | 401 Unauthorized |
| Expired JWT | Old token | 401 Unauthorized |
| Access other branch data | Branch B cashier → Branch A data | 403 Forbidden |
| Brute force login | 10 rapid failed logins | Account locked |
| Large payload attack | 100MB request body | 413 Request Too Large |
| IDOR attack | Modify loan ID in URL | 403 or 404 |

---

## 6. User Acceptance Testing (UAT)

### UAT Participants

- Branch Manager: Tests approval workflows and reports
- Cashier: Tests deposit/withdrawal, cash counter opening/closing
- Loan Officer: Tests loan application, approval, disbursement
- Collector: Tests mobile app, offline collection, sync
- Member: Tests mobile banking app

### UAT Scenarios

| Scenario | Module | Acceptance Criteria |
|----------|--------|-------------------|
| Register a new member end-to-end | Members | Member code generated, SMS received |
| Open savings account and deposit | Savings | Balance updated, receipt printed |
| Process a loan application | Loans | Approval workflow completes correctly |
| Make EMI payment | Loans | Balance reduced, receipt issued |
| Run trial balance | Accounting | Balances match manual calculation |
| Export COPOMIS report | Reports | File matches municipality format |
| Offline collection on Android | Collector App | Data syncs correctly on reconnect |
| View balance on mobile app | Mobile Banking | Shows real-time balance |

---

## 7. Test Data

### Seed Data for Testing

```sql
-- Test branch
INSERT INTO branches (branch_code, branch_name, is_head_office)
VALUES ('TEST', 'Test Branch', TRUE);

-- Test users for each role
INSERT INTO users (username, email, password_hash, full_name, branch_id) VALUES
('test_admin',    'admin@test.np',    '$2b$12$...', 'Test Admin',    (SELECT id FROM branches WHERE branch_code='TEST')),
('test_cashier',  'cashier@test.np',  '$2b$12$...', 'Test Cashier',  (SELECT id FROM branches WHERE branch_code='TEST')),
('test_manager',  'manager@test.np',  '$2b$12$...', 'Test Manager',  (SELECT id FROM branches WHERE branch_code='TEST'));

-- Test members
INSERT INTO members (member_code, first_name, last_name, citizenship_number, phone_primary, branch_id, status, kyc_verified, created_by)
VALUES
('TEST-001', 'Ram', 'Shrestha', '01-01-75-00001', '9841000001', (SELECT id FROM branches WHERE branch_code='TEST'), 'Active', TRUE, (SELECT id FROM users WHERE username='test_admin')),
('TEST-002', 'Sita', 'Tamang',  '01-01-75-00002', '9841000002', (SELECT id FROM branches WHERE branch_code='TEST'), 'Active', TRUE, (SELECT id FROM users WHERE username='test_admin'));
```

---

## 8. CI Test Execution

```yaml
# .github/workflows/test.yml
name: Run Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: sahakarims_test
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
      redis:
        image: redis:7
        ports: ['6379:6379']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '8.0' }
      - run: dotnet restore src/backend
      - run: dotnet test src/backend --collect:"XPlat Code Coverage"
      - uses: codecov/codecov-action@v4

  flutter-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.22.0' }
      - run: flutter pub get
        working-directory: src/flutter
      - run: flutter test --coverage
        working-directory: src/flutter
```
