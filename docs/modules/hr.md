# SahakariMS — Module: HR & Payroll

## Overview

The HR module manages cooperative staff — employee records, attendance, leave, and payroll. It integrates with the accounting module to post salary expenses automatically.

---

## Employee Lifecycle

```
Hire → Probation (3 months) → Permanent → Promotion/Transfer → Exit
```

---

## Employee Data Model

```sql
CREATE TABLE employees (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID NOT NULL REFERENCES branches(id),
    employee_code       VARCHAR(20) NOT NULL UNIQUE,  -- EMP-KTM-001
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    first_name_np       VARCHAR(200),                 -- Nepali name
    gender              VARCHAR(10) NOT NULL,
    date_of_birth_ad    DATE NOT NULL,
    citizenship_number  VARCHAR(50),
    pan_number          VARCHAR(20),                   -- Encrypted
    phone               VARCHAR(15) NOT NULL,
    email               VARCHAR(200),
    address             JSONB,
    join_date_ad        DATE NOT NULL,
    join_date_bs        VARCHAR(10) NOT NULL,
    designation         VARCHAR(100) NOT NULL,         -- Branch Manager, Cashier, etc.
    department          VARCHAR(100),
    employment_type     VARCHAR(20) NOT NULL,          -- Permanent | Contract | Probation
    basic_salary        NUMERIC(12,2) NOT NULL,
    bank_account        VARCHAR(50),                   -- For salary transfer
    bank_name           VARCHAR(100),
    is_user             BOOLEAN DEFAULT FALSE,         -- Is this employee a system user?
    user_id             UUID REFERENCES users(id),
    status              VARCHAR(20) NOT NULL DEFAULT 'Active',
    exit_date_ad        DATE,
    exit_reason         TEXT,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Attendance Management

```sql
CREATE TABLE attendance (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id     UUID NOT NULL REFERENCES employees(id),
    branch_id       UUID NOT NULL REFERENCES branches(id),
    date_ad         DATE NOT NULL,
    date_bs         VARCHAR(10) NOT NULL,
    check_in_at     TIMESTAMPTZ,
    check_out_at    TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL,  -- Present | Absent | Leave | Holiday | HalfDay
    work_hours      NUMERIC(4,2),          -- Calculated on checkout
    overtime_hours  NUMERIC(4,2) DEFAULT 0,
    notes           TEXT,
    marked_by       UUID REFERENCES users(id),  -- Manual override audit
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Leave Management

```sql
CREATE TABLE leave_types (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(50) NOT NULL,   -- Annual, Sick, Maternity, Paternity
    annual_days     INT NOT NULL,
    is_paid         BOOLEAN NOT NULL DEFAULT TRUE,
    can_carry_forward BOOLEAN NOT NULL DEFAULT FALSE,
    max_carry_days  INT DEFAULT 0
);

CREATE TABLE leave_requests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id     UUID NOT NULL REFERENCES employees(id),
    leave_type_id   UUID NOT NULL REFERENCES leave_types(id),
    from_date_ad    DATE NOT NULL,
    to_date_ad      DATE NOT NULL,
    days            INT NOT NULL,
    reason          TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'Pending',  -- Pending | Approved | Rejected
    approved_by     UUID REFERENCES users(id),
    approved_at     TIMESTAMPTZ,
    rejection_note  TEXT
);
```

---

## Payroll

### Salary Components

```
GROSS SALARY = Basic + Allowances (HRA, TA, DA, Medical)

DEDUCTIONS:
  - Employee PF (10% of basic — mandatory, Nepal SSF)
  - Employee Tax (as per Nepal income tax slab)
  - Loan from cooperative (if any)
  - Salary advance recovery

NET SALARY = Gross - Total Deductions

EMPLOYER CONTRIBUTIONS:
  - Employer PF (10% of basic — Social Security Fund)
  - Gratuity provision (8.33% of basic per year)
```

### Nepal Income Tax (FY 2081/82) — Individual

| Income Slab (Annual) | Tax Rate |
|---------------------|---------|
| Up to NPR 5,00,000 | 1% |
| 5,00,001 – 7,00,000 | 10% |
| 7,00,001 – 10,00,000 | 20% |
| 10,00,001 – 20,00,000 | 30% |
| Above 20,00,000 | 36% |

---

### Payroll Generation

```csharp
// Application/HR/Payroll/GeneratePayrollCommandHandler.cs
public class GeneratePayrollCommandHandler
    : IRequestHandler<GeneratePayrollCommand, PayrollSummary>
{
    public async Task<PayrollSummary> Handle(
        GeneratePayrollCommand command, CancellationToken ct)
    {
        var employees = await _repo.GetActiveEmployeesAsync(command.BranchId, ct);
        var attendance = await _attendanceRepo.GetMonthlyAttendanceAsync(
            command.BranchId, command.Year, command.Month, ct);
        var taxSlabs = await _taxRepo.GetCurrentSlabsAsync(ct);

        var payslips = new List<Payslip>();

        foreach (var emp in employees)
        {
            var workDays = attendance.Where(a => a.EmployeeId == emp.Id &&
                           a.Status == AttendanceStatus.Present).Count();
            var totalDays = DaysInMonth(command.Year, command.Month);

            // Pro-rated salary for employees who joined mid-month
            var grossSalary = emp.BasicSalary + emp.TotalAllowances;
            grossSalary = grossSalary * workDays / totalDays;

            // Calculate deductions
            var pfDeduction = emp.BasicSalary * 0.10m;
            var taxDeduction = TaxCalculator.CalculateMonthlyTax(
                grossSalary * 12, taxSlabs);

            var netSalary = grossSalary - pfDeduction - taxDeduction;

            var payslip = new Payslip
            {
                EmployeeId = emp.Id,
                Month = command.Month,
                Year = command.Year,
                GrossSalary = grossSalary,
                PfDeduction = pfDeduction,
                TaxDeduction = taxDeduction,
                NetSalary = netSalary,
                WorkingDays = workDays,
                TotalDays = totalDays
            };

            payslips.Add(payslip);

            // Auto-post accounting entry
            await _accountingService.PostSalaryExpenseAsync(payslip, ct);
        }

        return new PayrollSummary { Payslips = payslips };
    }
}
```

---

### Payroll Accounting Entry

```
Month-end salary posting:

Dr  Staff Salaries Expense     {total_gross}
Dr  Employer PF Contribution   {employer_pf}
Cr  Staff Salary Payable       {total_net}
Cr  Tax Payable (IRD)          {total_tax}
Cr  PF Payable (SSF)           {total_pf}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/hr/employees` | HR_VIEW | List employees |
| POST | `/hr/employees` | HR_MANAGE | Add employee |
| GET | `/hr/employees/{id}` | HR_VIEW | Employee profile |
| PUT | `/hr/employees/{id}` | HR_MANAGE | Update employee |
| POST | `/hr/attendance/mark` | HR_MANAGE | Mark attendance |
| GET | `/hr/attendance/{employeeId}` | HR_VIEW | View attendance |
| POST | `/hr/leave/request` | Any | Submit leave request |
| POST | `/hr/leave/{id}/approve` | HR_MANAGE | Approve leave |
| GET | `/hr/payroll` | HR_PAYROLL | List payroll records |
| POST | `/hr/payroll/generate` | HR_PAYROLL | Generate monthly payroll |
| GET | `/hr/payroll/{id}/payslip` | HR_VIEW | Download payslip PDF |
