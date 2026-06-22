# SahakariMS — Testing: Integration Testing

## Overview

Integration tests verify that multiple components work together correctly: API endpoints, database operations, Redis caching, and external service integrations. Uses **xUnit** + **TestContainers** for a real database per test run.

---

## Test Infrastructure

```csharp
// SahakariMS.Integration.Tests/SahakariMSApiFactory.cs
public class SahakariMSApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private PostgreSqlContainer _postgres = null!;
    private RedisContainer _redis = null!;

    public async Task InitializeAsync()
    {
        // Start real PostgreSQL container
        _postgres = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("sahakarims_test")
            .WithUsername("sahakarims")
            .WithPassword("testpass")
            .Build();

        // Start real Redis container
        _redis = new RedisBuilder()
            .WithImage("redis:7-alpine")
            .Build();

        await Task.WhenAll(_postgres.StartAsync(), _redis.StartAsync());
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Replace DB connection with test container
            services.RemoveAll<DbContextOptions<SahakariMSDbContext>>();
            services.AddDbContext<SahakariMSDbContext>(options =>
                options.UseNpgsql(_postgres.GetConnectionString()));

            // Replace Redis
            services.RemoveAll<IConnectionMultiplexer>();
            services.AddSingleton<IConnectionMultiplexer>(
                ConnectionMultiplexer.Connect(_redis.GetConnectionString()));

            // Replace SMS gateway with mock (don't send real SMS in tests)
            services.RemoveAll<ISmsGateway>();
            services.AddSingleton<ISmsGateway, MockSmsGateway>();
        });
    }

    public async Task DisposeAsync()
    {
        await _postgres.StopAsync();
        await _redis.StopAsync();
    }
}
```

---

## Authentication Integration Tests

```csharp
public class AuthEndpointTests : IClassFixture<SahakariMSApiFactory>
{
    private readonly HttpClient _client;
    private readonly SahakariMSApiFactory _factory;

    public AuthEndpointTests(SahakariMSApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Login_WithValidCredentials_ReturnsJwtTokens()
    {
        // Arrange — seed a test user
        await _factory.SeedUserAsync("cashier01@test.np", "Test@1234", "Cashier");

        var request = new { username = "cashier01@test.np", password = "Test@1234" };

        // Act
        var response = await _client.PostAsJsonAsync("/api/v1/auth/login", request);
        var body = await response.Content.ReadFromJsonAsync<LoginResponse>();

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotEmpty(body!.AccessToken);
        Assert.NotEmpty(body.RefreshToken);
        Assert.Equal(900, body.ExpiresIn);
    }

    [Fact]
    public async Task Login_WithWrongPassword_Returns401AndLocksAfter5Attempts()
    {
        await _factory.SeedUserAsync("locktest@test.np", "Correct@1234", "Cashier");

        // 5 failed attempts
        for (int i = 0; i < 5; i++)
        {
            var r = await _client.PostAsJsonAsync("/api/v1/auth/login",
                new { username = "locktest@test.np", password = "Wrong@1234" });
            Assert.Equal(HttpStatusCode.Unauthorized, r.StatusCode);
        }

        // 6th attempt — should be locked
        var lockedResponse = await _client.PostAsJsonAsync("/api/v1/auth/login",
            new { username = "locktest@test.np", password = "Correct@1234" });

        var body = await lockedResponse.Content.ReadFromJsonAsync<ProblemDetails>();
        Assert.Contains("locked", body!.Detail, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task RefreshToken_AfterUse_OldTokenIsInvalid()
    {
        var tokens = await GetValidTokensAsync();
        var newTokens = await RefreshTokenAsync(tokens.RefreshToken);

        // Old refresh token should now fail
        var reuseResponse = await _client.PostAsJsonAsync("/api/v1/auth/refresh-token",
            new { refreshToken = tokens.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, reuseResponse.StatusCode);
    }
}
```

---

## Savings Workflow Integration Tests

```csharp
public class SavingsWorkflowTests : IClassFixture<SahakariMSApiFactory>
{
    [Fact]
    public async Task DepositAndWithdraw_FullFlow_BalanceIsCorrect()
    {
        // Arrange
        _client.SetBearerToken(await GetCashierTokenAsync());
        var accountId = await CreateSavingsAccountAsync();

        // Act — Deposit NPR 10,000
        var depositResponse = await _client.PostAsJsonAsync(
            $"/api/v1/savings/accounts/{accountId}/deposit",
            new { amount = 10_000m, depositMode = "Cash", narration = "Test" });

        Assert.Equal(HttpStatusCode.Created, depositResponse.StatusCode);
        var depositResult = await depositResponse.Content.ReadFromJsonAsync<TransactionResponse>();
        Assert.Equal(10_000m, depositResult!.BalanceAfter);

        // Act — Withdraw NPR 3,000
        var withdrawResponse = await _client.PostAsJsonAsync(
            $"/api/v1/savings/accounts/{accountId}/withdraw",
            new { amount = 3_000m, withdrawalMode = "Cash" });

        Assert.Equal(HttpStatusCode.Created, withdrawResponse.StatusCode);
        var withdrawResult = await withdrawResponse.Content.ReadFromJsonAsync<TransactionResponse>();
        Assert.Equal(7_000m, withdrawResult!.BalanceAfter);

        // Verify balance in DB
        var account = await _client.GetFromJsonAsync<SavingAccountDto>(
            $"/api/v1/savings/accounts/{accountId}");
        Assert.Equal(7_000m, account!.CurrentBalance);

        // Verify accounting entries created
        var vouchers = await _client.GetFromJsonAsync<List<VoucherDto>>(
            $"/api/v1/accounting/vouchers?referenceId={accountId}&today=true");
        Assert.Equal(2, vouchers!.Count);  // One deposit voucher, one withdrawal voucher
    }

    [Fact]
    public async Task Withdrawal_ExceedingBalance_Returns400()
    {
        _client.SetBearerToken(await GetCashierTokenAsync());
        var accountId = await CreateSavingsAccountWithBalanceAsync(balance: 5_000m);

        var response = await _client.PostAsJsonAsync(
            $"/api/v1/savings/accounts/{accountId}/withdraw",
            new { amount = 10_000m, withdrawalMode = "Cash" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<ProblemDetails>();
        Assert.Contains("balance", body!.Detail, StringComparison.OrdinalIgnoreCase);
    }
}
```

---

## Loan Workflow Integration Tests

```csharp
public class LoanWorkflowTests : IClassFixture<SahakariMSApiFactory>
{
    [Fact]
    public async Task LoanLifecycle_FullFlow_CompletesSuccessfully()
    {
        // 1. Apply for loan
        var memberId = await CreateActiveMemberAsync();
        var loanId = await ApplyForLoanAsync(memberId, amount: 100_000m, tenure: 12);

        // 2. Approve loan (as Manager)
        _client.SetBearerToken(await GetManagerTokenAsync());
        var approveResponse = await _client.PostAsJsonAsync(
            $"/api/v1/loans/{loanId}/approve",
            new { remarks = "Good credit history" });
        Assert.Equal(HttpStatusCode.OK, approveResponse.StatusCode);

        // 3. Disburse loan (as Cashier)
        _client.SetBearerToken(await GetCashierTokenAsync());
        var disburseResponse = await _client.PostAsJsonAsync(
            $"/api/v1/loans/{loanId}/disburse",
            new { disbursementMode = "AccountCredit", narration = "Business loan disbursement" });
        Assert.Equal(HttpStatusCode.OK, disburseResponse.StatusCode);

        // 4. Verify loan status = Active
        var loan = await _client.GetFromJsonAsync<LoanDto>($"/api/v1/loans/{loanId}");
        Assert.Equal("Active", loan!.Status);
        Assert.Equal(12, loan.Schedule.Count);

        // 5. Pay first EMI
        var firstEmi = loan.Schedule.MinBy(s => s.DueDate)!;
        var paymentResponse = await _client.PostAsJsonAsync(
            $"/api/v1/loans/{loanId}/payment",
            new { amount = firstEmi.EmiAmount, paymentMode = "Cash" });
        Assert.Equal(HttpStatusCode.Created, paymentResponse.StatusCode);

        // 6. Verify EMI is marked as paid
        loan = await _client.GetFromJsonAsync<LoanDto>($"/api/v1/loans/{loanId}");
        Assert.Equal("Paid", loan!.Schedule[0].Status);
        Assert.True(loan.OutstandingBalance < 100_000m);
    }
}
```

---

## Running Integration Tests

```bash
# Requires Docker running for TestContainers

dotnet test \
  src/backend/SahakariMS.Tests/SahakariMS.Integration.Tests/ \
  -v normal \
  --logger "trx;LogFileName=integration-results.trx"

# Run specific test class
dotnet test --filter "FullyQualifiedName~LoanWorkflowTests"

# Run with HTML report
dotnet test --logger "html;LogFileName=results.html"
```

---

## Test Data Factories

```csharp
// SahakariMS.Integration.Tests/Fixtures/TestDataFactory.cs
public class TestDataFactory
{
    private readonly SahakariMSDbContext _db;

    public async Task<Guid> CreateActiveMemberAsync(
        string? firstName = null,
        string? branchId = null)
    {
        var member = Member.Create(
            firstName: firstName ?? Faker.Name.First(),
            lastName: Faker.Name.Last(),
            gender: Gender.Male,
            dateOfBirthAd: new DateOnly(1990, 5, 15),
            citizenshipNumber: $"01-01-{Faker.Random.Int(70, 85)}-{Faker.Random.Int(10000, 99999)}",
            phonePrimary: $"98{Faker.Random.Int(10000000, 99999999)}",
            branchId: branchId ?? _defaultBranchId,
            createdBy: _defaultUserId);

        member.Approve(_defaultManagerId, "Test approval");

        _db.Members.Add(member);
        await _db.SaveChangesAsync();
        return member.Id;
    }
}
```
