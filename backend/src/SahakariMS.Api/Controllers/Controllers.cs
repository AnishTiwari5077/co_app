using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SahakariMS.Application.Auth;
using SahakariMS.Shared.Common;

namespace SahakariMS.Api.Controllers;

// ── Auth Controller ───────────────────────────────────────────────────────────
[ApiController]
[Route("api/v1/auth")]
public class AuthController(IMediator mediator) : ControllerBase
{
    /// <summary>POST /auth/login — open to all (no token required).</summary>
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new LoginCommand(request.Username, request.Password, request.DeviceId), ct);
        if (!result.IsSuccess)
            return result.ErrorCode == "ACCOUNT_LOCKED"
                ? StatusCode(423, ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!))
                : Unauthorized(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<LoginResponse>.Ok(result.Value!));
    }

    /// <summary>POST /auth/refresh-token — open to all (uses refresh token, not JWT).</summary>
    [HttpPost("refresh-token")]
    [AllowAnonymous]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new RefreshTokenCommand(request.RefreshToken), ct);
        if (!result.IsSuccess) return Unauthorized(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<RefreshTokenResponse>.Ok(result.Value!));
    }

    /// <summary>POST /auth/logout — any authenticated user can log out.</summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest request, CancellationToken ct)
    {
        await mediator.Send(new LogoutCommand(request.RefreshToken), ct);
        return NoContent();
    }
}

// ── Members Controller ────────────────────────────────────────────────────────
[ApiController]
[Route("api/v1/members")]
[Authorize] // base: any authenticated user
public class MembersController(IMediator mediator) : ControllerBase
{
    /// <summary>GET /members — all staff can view members.</summary>
    [HttpGet]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,LOAN_OFFICER")]
    public async Task<IActionResult> GetMembers(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null, [FromQuery] string? status = null,
        [FromQuery] Guid? branchId = null, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Members.GetMembersQuery(page, pageSize, search, status, branchId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<IReadOnlyList<Application.Members.MemberListDto>>.OkPaged(
            result.Value!.Data, result.Value.Page, result.Value.PageSize, result.Value.TotalCount));
    }

    /// <summary>GET /members/{id} — all staff can view a member's details.</summary>
    [HttpGet("{id:guid}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER,LOAN_OFFICER")]
    public async Task<IActionResult> GetMember(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Members.GetMemberByIdQuery(id), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Members.MemberDetailDto>.Ok(result.Value!));
    }

    /// <summary>POST /members — only Admin, Manager, Cashier can register members.</summary>
    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> RegisterMember([FromBody] Application.Members.RegisterMemberRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Members.RegisterMemberCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return CreatedAtAction(nameof(GetMember), new { id = result.Value }, new { id = result.Value, status = "Pending" });
    }

    /// <summary>POST /members/{id}/approve — only Admin and Manager can approve members.</summary>
    [HttpPost("{id:guid}/approve")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> ApproveMember(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Members.ApproveMemberCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { message = "Member approved." }));
    }



    /// <summary>GET /accounting/chart-of-accounts/manage - all accounts for management (includes inactive).</summary>
    [HttpGet("chart-of-accounts/manage")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> GetAllAccounts(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetChartOfAccountsQuery(PostableOnly: false), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.ChartOfAccountDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/chart-of-accounts - create a new account.</summary>
    [HttpPost("chart-of-accounts")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateAccount([FromBody] Application.Accounting.CreateChartOfAccountRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateChartOfAccountCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/chart-of-accounts/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/chart-of-accounts/{id}/toggle - activate or deactivate.</summary>
    [HttpPut("chart-of-accounts/{id:guid}/toggle")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ToggleAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.ToggleChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { isActive = result.Value }));
    }

    /// <summary>DELETE /accounting/chart-of-accounts/{id} - soft delete account.</summary>
    [HttpDelete("chart-of-accounts/{id:guid}")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> DeleteAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.DeleteChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    /// <summary>GET /accounting/fiscal-years - list all fiscal years.</summary>
    [HttpGet("fiscal-years")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetFiscalYears(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetFiscalYearsQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.FiscalYearDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/fiscal-years - create a new fiscal year.</summary>
    [HttpPost("fiscal-years")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateFiscalYear([FromBody] Application.Accounting.CreateFiscalYearRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateFiscalYearCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/fiscal-years/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/set-current - mark as active.</summary>
    [HttpPut("fiscal-years/{id:guid}/set-current")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> SetCurrentFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.SetCurrentFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/close - close (lock) a fiscal year.</summary>
    [HttpPut("fiscal-years/{id:guid}/close")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CloseFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CloseFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

// ── Savings Controller ────────────────────────────────────────────────────────
[ApiController]
[Route("api/v1/savings/accounts")]
[Authorize]
public class SavingsController(IMediator mediator) : ControllerBase
{
    /// <summary>GET /savings/accounts — list all savings accounts.</summary>
    [HttpGet]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetSavingAccounts(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null, [FromQuery] string? accountType = null,
        [FromQuery] Guid? branchId = null, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Savings.GetSavingAccountsQuery(page, pageSize, search, accountType, branchId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<IReadOnlyList<Application.Savings.SavingAccountListDto>>.OkPaged(
            result.Value!.Data, result.Value.Page, result.Value.PageSize, result.Value.TotalCount));
    }

    /// <summary>GET /savings/accounts/by-number/{accountNumber} — resolve account number like SAV-2083-00001 to full detail.</summary>
    [HttpGet("by-number/{accountNumber}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetSavingAccountByNumber(string accountNumber, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Savings.GetSavingAccountByNumberQuery(accountNumber), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Savings.SavingAccountDetailDto>.Ok(result.Value!));
    }

    /// <summary>GET /savings/accounts/{id} — get full account detail.</summary>
    [HttpGet("{id:guid}")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetSavingAccountDetail(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Savings.GetSavingAccountDetailQuery(id), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Savings.SavingAccountDetailDto>.Ok(result.Value!));
    }

    /// <summary>GET /savings/accounts/{id}/transactions — paginated transaction history.</summary>
    [HttpGet("{id:guid}/transactions")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetTransactions(
        Guid id, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Savings.GetSavingTransactionsQuery(id, page, pageSize), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<IReadOnlyList<Application.Savings.SavingTransactionDto>>.OkPaged(
            result.Value!.Data, result.Value.Page, result.Value.PageSize, result.Value.TotalCount));
    }

    /// <summary>
    /// POST /savings/accounts/{id}/deposit
    /// Only Admin, Manager, and Cashier can process deposits.
    /// Loan Officers and Accountants will receive 403 Forbidden.
    /// </summary>
    [HttpPost("{id:guid}/deposit")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> Deposit(Guid id, [FromBody] Application.Savings.DepositRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Savings.DepositCommand(id, request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Savings.TransactionResponse>.Ok(result.Value!));
    }

    /// <summary>
    /// POST /savings/accounts/{id}/withdraw
    /// Only Admin, Manager, and Cashier can process withdrawals.
    /// </summary>
    [HttpPost("{id:guid}/withdraw")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> Withdraw(Guid id, [FromBody] Application.Savings.WithdrawRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Savings.WithdrawCommand(id, request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Savings.TransactionResponse>.Ok(result.Value!));
    }

    /// <summary>POST /savings/accounts — open a new savings account for a member.</summary>
    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> OpenAccount([FromBody] Application.Savings.OpenSavingAccountRequest request, CancellationToken ct)
    {
        var branchId = Guid.TryParse(User.FindFirst("branchId")?.Value, out var b) ? b : Guid.Empty;
        var result = await mediator.Send(new Application.Savings.OpenSavingAccountCommand(request, branchId, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/savings/accounts/{result.Value!.AccountId}",
            ApiResponse<Application.Savings.OpenSavingAccountResponse>.Ok(result.Value!));
    }



    /// <summary>GET /accounting/chart-of-accounts/manage - all accounts for management (includes inactive).</summary>
    [HttpGet("chart-of-accounts/manage")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> GetAllAccounts(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetChartOfAccountsQuery(PostableOnly: false), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.ChartOfAccountDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/chart-of-accounts - create a new account.</summary>
    [HttpPost("chart-of-accounts")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateAccount([FromBody] Application.Accounting.CreateChartOfAccountRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateChartOfAccountCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/chart-of-accounts/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/chart-of-accounts/{id}/toggle - activate or deactivate.</summary>
    [HttpPut("chart-of-accounts/{id:guid}/toggle")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ToggleAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.ToggleChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { isActive = result.Value }));
    }

    /// <summary>DELETE /accounting/chart-of-accounts/{id} - soft delete account.</summary>
    [HttpDelete("chart-of-accounts/{id:guid}")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> DeleteAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.DeleteChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    /// <summary>GET /accounting/fiscal-years - list all fiscal years.</summary>
    [HttpGet("fiscal-years")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetFiscalYears(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetFiscalYearsQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.FiscalYearDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/fiscal-years - create a new fiscal year.</summary>
    [HttpPost("fiscal-years")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateFiscalYear([FromBody] Application.Accounting.CreateFiscalYearRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateFiscalYearCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/fiscal-years/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/set-current - mark as active.</summary>
    [HttpPut("fiscal-years/{id:guid}/set-current")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> SetCurrentFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.SetCurrentFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/close - close (lock) a fiscal year.</summary>
    [HttpPut("fiscal-years/{id:guid}/close")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CloseFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CloseFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

// ── Savings Schemes Controller ───────────────────────────────────────────────────
[ApiController]
[Route("api/v1/savings/schemes")]
[Authorize]
public class SavingSchemesController(IMediator mediator) : ControllerBase
{
    /// <summary>GET /savings/schemes — list all active savings schemes for UI pickers.</summary>
    [HttpGet]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> GetSchemes(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Savings.GetSavingSchemesQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Savings.SavingSchemeDto>>.Ok(result.Value!));
    }
}

// ── Loans Controller ──────────────────────────────────────────────────────────
[ApiController]
[Route("api/v1/loans")]
[Authorize]
public class LoansController(IMediator mediator) : ControllerBase
{
    /// <summary>GET /loans — list all loans.</summary>
    [HttpGet]
    [Authorize(Roles = "ADMIN,MANAGER,LOAN_OFFICER,CASHIER")]
    public async Task<IActionResult> GetLoans(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
        [FromQuery] string? search = null, [FromQuery] string? status = null,
        [FromQuery] Guid? branchId = null, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Loans.GetLoansQuery(page, pageSize, search, status, branchId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<IReadOnlyList<Application.Loans.LoanListDto>>.OkPaged(
            result.Value!.Data, result.Value.Page, result.Value.PageSize, result.Value.TotalCount));
    }

    /// <summary>GET /loans/products — list active loan products for the application form.</summary>
    [HttpGet("products")]
    [Authorize(Roles = "ADMIN,MANAGER,LOAN_OFFICER,CASHIER")]
    public async Task<IActionResult> GetLoanProducts(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.GetLoanProductsQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Loans.LoanProductDto>>.Ok(result.Value!));
    }

    /// <summary>POST /loans — Admin, Manager, and Loan Officer can apply for loans.</summary>
    [HttpPost]
    [Authorize(Roles = "ADMIN,MANAGER,LOAN_OFFICER")]
    public async Task<IActionResult> ApplyLoan([FromBody] Application.Loans.ApplyLoanRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.ApplyLoanCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/loans/{result.Value}", new { id = result.Value });
    }

    /// <summary>POST /loans/{id}/approve — only Admin and Manager can approve loans.</summary>
    [HttpPost("{id:guid}/approve")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> ApproveLoan(Guid id, [FromBody] ApproveLoanBody body, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.ApproveLoanCommand(id, body.ApprovedAmount, body.Remarks, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { message = "Loan approved." }));
    }

    /// <summary>POST /loans/{id}/disburse — only Admin and Manager can disburse loans.</summary>
    [HttpPost("{id:guid}/disburse")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> DisburseLoan(Guid id, [FromBody] DisburseLoanBody body, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.DisburseLoanCommand(id, body.DisbursedAmount, body.Mode, body.Date, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { message = "Loan disbursed." }));
    }

    /// <summary>POST /loans/{id}/payment — Admin, Manager, and Cashier collect EMI payments.</summary>
    [HttpPost("{id:guid}/payment")]
    [Authorize(Roles = "ADMIN,MANAGER,CASHIER")]
    public async Task<IActionResult> MakePayment(Guid id, [FromBody] Application.Loans.LoanPaymentRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.MakePaymentCommand(id, request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Loans.LoanPaymentResponse>.Ok(result.Value!));
    }

    /// <summary>GET /loans/{id}/schedule — all loan-related roles can view EMI schedule.</summary>
    [HttpGet("{id:guid}/schedule")]
    [Authorize(Roles = "ADMIN,MANAGER,LOAN_OFFICER,CASHIER")]
    public async Task<IActionResult> GetSchedule(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.GetEmiScheduleQuery(id), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Loans.EmiScheduleDto>>.Ok(result.Value!));
    }

    /// <summary>GET /loans/{id} — full loan detail with guarantors, collaterals, stats.</summary>
    [HttpGet("{id:guid}")]
    [Authorize(Roles = "ADMIN,MANAGER,LOAN_OFFICER,CASHIER")]
    public async Task<IActionResult> GetLoanDetail(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.GetLoanDetailQuery(id), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Loans.LoanDetailDto>.Ok(result.Value!));
    }

    /// <summary>GET /loans/{id}/payments — paginated payment history for a loan.</summary>
    [HttpGet("{id:guid}/payments")]
    [Authorize(Roles = "ADMIN,MANAGER,LOAN_OFFICER,CASHIER")]
    public async Task<IActionResult> GetLoanPayments(
        Guid id, [FromQuery] int page = 1, [FromQuery] int pageSize = 30, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Loans.GetLoanPaymentsQuery(id, page, pageSize), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<IReadOnlyList<Application.Loans.LoanPaymentDto>>.OkPaged(
            result.Value!.Data, result.Value.Page, result.Value.PageSize, result.Value.TotalCount));
    }



    /// <summary>GET /accounting/chart-of-accounts/manage - all accounts for management (includes inactive).</summary>
    [HttpGet("chart-of-accounts/manage")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> GetAllAccounts(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetChartOfAccountsQuery(PostableOnly: false), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.ChartOfAccountDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/chart-of-accounts - create a new account.</summary>
    [HttpPost("chart-of-accounts")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateAccount([FromBody] Application.Accounting.CreateChartOfAccountRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateChartOfAccountCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/chart-of-accounts/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/chart-of-accounts/{id}/toggle - activate or deactivate.</summary>
    [HttpPut("chart-of-accounts/{id:guid}/toggle")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ToggleAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.ToggleChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { isActive = result.Value }));
    }

    /// <summary>DELETE /accounting/chart-of-accounts/{id} - soft delete account.</summary>
    [HttpDelete("chart-of-accounts/{id:guid}")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> DeleteAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.DeleteChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    /// <summary>GET /accounting/fiscal-years - list all fiscal years.</summary>
    [HttpGet("fiscal-years")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetFiscalYears(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetFiscalYearsQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.FiscalYearDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/fiscal-years - create a new fiscal year.</summary>
    [HttpPost("fiscal-years")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateFiscalYear([FromBody] Application.Accounting.CreateFiscalYearRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateFiscalYearCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/fiscal-years/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/set-current - mark as active.</summary>
    [HttpPut("fiscal-years/{id:guid}/set-current")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> SetCurrentFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.SetCurrentFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/close - close (lock) a fiscal year.</summary>
    [HttpPut("fiscal-years/{id:guid}/close")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CloseFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CloseFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

public record ApproveLoanBody(decimal ApprovedAmount, string? Remarks);
public record DisburseLoanBody(decimal DisbursedAmount, string Mode, DateOnly Date);

// ── Accounting Controller ─────────────────────────────────────────────────────
[ApiController]
[Route("api/v1/accounting")]
[Authorize(Roles = "ADMIN,MANAGER,ACCOUNTANT")] // entire controller restricted
public class AccountingController(IMediator mediator) : ControllerBase
{
    /// <summary>GET /accounting/chart-of-accounts — load postable accounts for journal entry dropdowns.</summary>
    [HttpGet("chart-of-accounts")]
    public async Task<IActionResult> GetChartOfAccounts(
        [FromQuery] string? search = null, [FromQuery] string? accountType = null,
        [FromQuery] bool postableOnly = true, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Accounting.GetChartOfAccountsQuery(search, accountType, postableOnly), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.ChartOfAccountDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/vouchers — Admin, Manager, Accountant can create journal entries.</summary>
    [HttpPost("vouchers")]
    public async Task<IActionResult> CreateVoucher([FromBody] Application.Accounting.CreateVoucherRequest request, CancellationToken ct)
    {
        var branchId = Guid.TryParse(User.FindFirst("branchId")?.Value, out var b) ? b : Guid.Empty;
        var result = await mediator.Send(new Application.Accounting.CreateVoucherCommand(request, branchId, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/vouchers/{result.Value}", new { id = result.Value });
    }

    /// <summary>GET /accounting/trial-balance — Admin, Manager, Accountant can view trial balance.</summary>
    [HttpGet("trial-balance")]
    public async Task<IActionResult> GetTrialBalance([FromQuery] Guid? branchId, [FromQuery] DateOnly? asOfDate, CancellationToken ct)
    {
        var bid = branchId ?? (Guid.TryParse(User.FindFirst("branchId")?.Value, out var b) ? b : Guid.Empty);
        var result = await mediator.Send(new Application.Accounting.GetTrialBalanceQuery(bid, asOfDate ?? DateOnly.FromDateTime(DateTime.UtcNow)), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Accounting.TrialBalanceDto>.Ok(result.Value!));
    }

    /// <summary>GET /accounting/vouchers — paginated voucher list with entries.</summary>
    [HttpGet("vouchers")]
    public async Task<IActionResult> GetVouchers(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 30,
        [FromQuery] string? voucherType = null, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Accounting.GetVouchersQuery(page, pageSize, voucherType), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<IReadOnlyList<Application.Accounting.VoucherListDto>>.OkPaged(
            result.Value!.Data, result.Value.Page, result.Value.PageSize, result.Value.TotalCount));
    }

    /// <summary>GET /accounting/ledger/{accountId} — full ledger for a chart-of-account with running balance.</summary>
    [HttpGet("ledger/{accountId:guid}")]
    public async Task<IActionResult> GetLedger(
        Guid accountId, [FromQuery] DateOnly? fromDate, [FromQuery] DateOnly? toDate, CancellationToken ct = default)
    {
        var result = await mediator.Send(new Application.Accounting.GetLedgerQuery(accountId, fromDate, toDate), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Accounting.LedgerDto>.Ok(result.Value!));
    }



    /// <summary>GET /accounting/chart-of-accounts/manage - all accounts for management (includes inactive).</summary>
    [HttpGet("chart-of-accounts/manage")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> GetAllAccounts(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetChartOfAccountsQuery(PostableOnly: false), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.ChartOfAccountDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/chart-of-accounts - create a new account.</summary>
    [HttpPost("chart-of-accounts")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateAccount([FromBody] Application.Accounting.CreateChartOfAccountRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateChartOfAccountCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/chart-of-accounts/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/chart-of-accounts/{id}/toggle - activate or deactivate.</summary>
    [HttpPut("chart-of-accounts/{id:guid}/toggle")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ToggleAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.ToggleChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { isActive = result.Value }));
    }

    /// <summary>DELETE /accounting/chart-of-accounts/{id} - soft delete account.</summary>
    [HttpDelete("chart-of-accounts/{id:guid}")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> DeleteAccount(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.DeleteChartOfAccountCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    /// <summary>GET /accounting/fiscal-years - list all fiscal years.</summary>
    [HttpGet("fiscal-years")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetFiscalYears(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetFiscalYearsQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Accounting.FiscalYearDto>>.Ok(result.Value!));
    }

    /// <summary>POST /accounting/fiscal-years - create a new fiscal year.</summary>
    [HttpPost("fiscal-years")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CreateFiscalYear([FromBody] Application.Accounting.CreateFiscalYearRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CreateFiscalYearCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/fiscal-years/{result.Value}", new { id = result.Value });
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/set-current - mark as active.</summary>
    [HttpPut("fiscal-years/{id:guid}/set-current")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> SetCurrentFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.SetCurrentFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }

    /// <summary>PUT /accounting/fiscal-years/{id}/close - close (lock) a fiscal year.</summary>
    [HttpPut("fiscal-years/{id:guid}/close")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> CloseFiscalYear(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.CloseFiscalYearCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { }));
    }
    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}


// ── Dashboard Controller ──────────────────────────────────────────────────────
[ApiController]
[Route("api/v1/dashboard")]
[Authorize] // all roles can see dashboard
public class DashboardController(IMediator mediator) : ControllerBase
{
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(CancellationToken ct)
    {
        var branchId = Guid.TryParse(User.FindFirst("branchId")?.Value, out var b) ? b : Guid.Empty;
        var result = await mediator.Send(new Application.Accounting.GetDashboardSummaryQuery(branchId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Accounting.DashboardSummaryDto>.Ok(result.Value!));
    }

    /// <summary>GET /dashboard/activity — recent transactions, savings distribution, pending approvals.</summary>
    [HttpGet("activity")]
    public async Task<IActionResult> GetActivity(CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Accounting.GetDashboardActivityQuery(), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Accounting.DashboardActivityDto>.Ok(result.Value!));
    }
}
