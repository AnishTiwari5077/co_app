# SahakariMS — Testing: Unit Testing

## Overview

Unit tests validate individual components in isolation — primarily domain logic, business rules, and utility functions. We use **xUnit** for the backend and **flutter_test** for the frontend.

---

## Backend Unit Testing (xUnit)

### Test Project Structure

```
SahakariMS.Tests/
  SahakariMS.Domain.Tests/
    Entities/
      MemberTests.cs
      LoanTests.cs
      SavingAccountTests.cs
      ShareAccountTests.cs
    ValueObjects/
      MoneyTests.cs
      NepaliDateTests.cs
    Services/
      InterestCalculationServiceTests.cs
      EmiScheduleServiceTests.cs
      NpaClassificationServiceTests.cs
  SahakariMS.Application.Tests/
    Members/
      RegisterMemberCommandHandlerTests.cs
      ApproveMemberCommandHandlerTests.cs
    Loans/
      CreateLoanCommandHandlerTests.cs
      DisburseLoantCommandHandlerTests.cs
      RecordEmiPaymentCommandHandlerTests.cs
    Savings/
      DepositCommandHandlerTests.cs
      WithdrawCommandHandlerTests.cs
```

---

### Domain Entity Tests

```csharp
// SahakariMS.Domain.Tests/Entities/LoanTests.cs
public class LoanTests
{
    [Fact]
    public void Loan_WithValidData_CanBeCreated()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var branchId = Guid.NewGuid();

        // Act
        var loan = Loan.Create(
            memberId: memberId,
            branchId: branchId,
            productCode: "BL-001",
            amount: 500_000m,
            tenureMonths: 60,
            interestRate: 14m,
            interestMethod: InterestMethod.ReducingBalance,
            purpose: "Business expansion",
            requestedBy: Guid.NewGuid());

        // Assert
        Assert.NotNull(loan);
        Assert.Equal(LoanStatus.Pending, loan.Status);
        Assert.Equal(500_000m, loan.PrincipalAmount);
        Assert.Equal(14m, loan.InterestRate);
    }

    [Theory]
    [InlineData(0)]        // Zero amount
    [InlineData(-1000)]    // Negative amount
    [InlineData(100)]      // Below minimum (1,000)
    public void Loan_WithInvalidAmount_ThrowsDomainException(decimal amount)
    {
        Assert.Throws<DomainException>(() =>
            Loan.Create(
                memberId: Guid.NewGuid(),
                branchId: Guid.NewGuid(),
                productCode: "BL-001",
                amount: amount,
                tenureMonths: 12,
                interestRate: 14m,
                interestMethod: InterestMethod.ReducingBalance,
                purpose: "Test",
                requestedBy: Guid.NewGuid()));
    }

    [Fact]
    public void Loan_WhenApproved_StatusChangesToApproved()
    {
        // Arrange
        var loan = CreateValidPendingLoan();
        var approverId = Guid.NewGuid();

        // Act
        loan.Approve(approverId, remarks: "Good credit history");

        // Assert
        Assert.Equal(LoanStatus.Approved, loan.Status);
        Assert.Equal(approverId, loan.ApprovedBy);
        Assert.NotNull(loan.ApprovedAt);
    }

    [Fact]
    public void Loan_WhenAlreadyApproved_CannotBeApprovedAgain()
    {
        var loan = CreateValidPendingLoan();
        loan.Approve(Guid.NewGuid(), "First approval");

        Assert.Throws<DomainException>(() =>
            loan.Approve(Guid.NewGuid(), "Second approval"));
    }
}
```

---

### Interest Calculation Tests

```csharp
// SahakariMS.Domain.Tests/Services/InterestCalculationServiceTests.cs
public class InterestCalculationServiceTests
{
    private readonly InterestCalculationService _sut = new();

    [Theory]
    [InlineData(500_000, 14.0, 60, 11_634.0)]  // Business loan
    [InlineData(100_000, 16.0, 24,  4_948.0)]  // Personal loan
    [InlineData(200_000, 10.0, 36,  6_453.0)]  // Agriculture loan
    public void CalculateReducingBalanceEmi_ReturnsCorrectEmi(
        decimal principal, decimal ratePercent, int tenureMonths, decimal expectedEmi)
    {
        var emi = _sut.CalculateReducingBalanceEmi(principal, ratePercent, tenureMonths);
        Assert.Equal(expectedEmi, Math.Round(emi, 0));
    }

    [Fact]
    public void GenerateEmiSchedule_TotalInterest_MatchesExpected()
    {
        // NPR 500,000 at 14% for 60 months
        var schedule = _sut.GenerateEmiSchedule(
            principal: 500_000m,
            ratePercent: 14m,
            tenureMonths: 60,
            startDate: new DateOnly(2081, 4, 15));

        var totalPrincipal = schedule.Sum(s => s.PrincipalAmount);
        var totalInterest = schedule.Sum(s => s.InterestAmount);

        Assert.Equal(60, schedule.Count);
        Assert.Equal(500_000m, Math.Round(totalPrincipal, 0));
        Assert.True(totalInterest > 0);
        // Verify interest is frontloaded (reducing balance)
        Assert.True(schedule[0].InterestAmount > schedule[59].InterestAmount);
    }

    [Fact]
    public void CalculateDailyInterest_ForSavingsAccount_IsCorrect()
    {
        // NPR 50,000 at 7.5% p.a. for 30 days
        decimal balance = 50_000m;
        decimal ratePercent = 7.5m;

        decimal monthlyInterest = _sut.CalculateDailyProductInterest(
            balance, ratePercent, days: 30);

        // Expected: 50000 * 7.5 / 100 / 365 * 30 = 308.22
        Assert.Equal(308.22m, Math.Round(monthlyInterest, 2));
    }

    [Fact]
    public void CalculatePenalty_OverdueLoan_IsCorrect()
    {
        decimal overduePrincipal = 10_000m;
        decimal penaltyRate = 2m;
        int overdueDays = 30;

        decimal penalty = _sut.CalculatePenalty(overduePrincipal, penaltyRate, overdueDays);

        // Expected: 10000 * 2% / 365 * 30 = 16.44
        Assert.Equal(16.44m, Math.Round(penalty, 2));
    }
}
```

---

### Nepali Date Tests

```csharp
public class NepaliDateTests
{
    [Theory]
    [InlineData("2081-04-15", "2024-07-30")]  // BS → AD
    [InlineData("2080-01-01", "2023-04-14")]
    [InlineData("2079-12-30", "2023-04-12")]
    public void ConvertBsToAd_ReturnsCorrectDate(string bsDate, string expectedAdDate)
    {
        var bs = NepaliDate.Parse(bsDate);
        var ad = bs.ToGregorianDate();
        Assert.Equal(DateOnly.Parse(expectedAdDate), ad);
    }

    [Theory]
    [InlineData("2024-07-30", "2081-04-15")]  // AD → BS
    [InlineData("2023-04-14", "2080-01-01")]
    public void ConvertAdToBs_ReturnsCorrectDate(string adDate, string expectedBsDate)
    {
        var ad = DateOnly.Parse(adDate);
        var bs = NepaliDate.FromGregorianDate(ad);
        Assert.Equal(expectedBsDate, bs.ToString());
    }

    [Fact]
    public void NepaliDate_EndOfYear_IsLastDayOfChaitra()
    {
        var yearEnd = NepaliDate.GetYearEndDate(2081);
        Assert.Equal(2081, yearEnd.Year);
        Assert.Equal(12, yearEnd.Month);  // Chaitra = month 12
        Assert.Equal(30, yearEnd.Day);    // Chaitra 30 = year end
    }
}
```

---

## Flutter Unit Testing

```dart
// test/domain/interest_calculation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sahakarims/core/utils/interest_calculator.dart';

void main() {
  group('InterestCalculator', () {
    test('calculates reducing balance EMI correctly', () {
      final emi = InterestCalculator.reducingBalanceEmi(
        principal: 500000,
        annualRate: 14.0,
        tenureMonths: 60,
      );

      expect(emi, closeTo(11634.0, 1.0));  // Allow NPR 1 rounding
    });

    test('generates EMI schedule with correct count', () {
      final schedule = InterestCalculator.generateSchedule(
        principal: 500000,
        annualRate: 14.0,
        tenureMonths: 60,
        startDate: DateTime(2024, 7, 30),
      );

      expect(schedule.length, equals(60));
    });

    test('total principal in schedule equals disbursed amount', () {
      final schedule = InterestCalculator.generateSchedule(
        principal: 500000,
        annualRate: 14.0,
        tenureMonths: 60,
        startDate: DateTime(2024, 7, 30),
      );

      final total = schedule.fold(0.0, (sum, s) => sum + s.principalAmount);
      expect(total, closeTo(500000.0, 1.0));
    });

    test('formats NPR amount correctly', () {
      expect(formatNPR(1250000), equals('NPR 12,50,000.00'));
      expect(formatNPR(500), equals('NPR 500.00'));
    });
  });
}
```

---

## Running Tests

```bash
# Backend — run all unit tests
dotnet test src/backend/SahakariMS.Tests/SahakariMS.Domain.Tests/ -v normal

# Backend — with coverage
dotnet test src/backend/SahakariMS.Tests/SahakariMS.Domain.Tests/ \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage

# Generate HTML coverage report
reportgenerator \
  -reports:"./coverage/**/coverage.cobertura.xml" \
  -targetdir:./coverage/html \
  -reporttypes:Html

# Flutter — run all tests
flutter test test/

# Flutter — specific test file
flutter test test/domain/interest_calculation_test.dart

# Flutter — with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Coverage Targets

| Component | Target Coverage |
|-----------|---------------|
| Domain entities | ≥ 90% |
| Interest calculation | ≥ 95% |
| Date conversion | ≥ 95% |
| Command handlers | ≥ 80% |
| Flutter widgets | ≥ 70% |
| Overall backend | ≥ 80% |
| Overall Flutter | ≥ 70% |
