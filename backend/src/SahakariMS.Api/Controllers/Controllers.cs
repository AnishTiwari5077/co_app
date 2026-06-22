using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SahakariMS.Application.Auth;
using SahakariMS.Shared.Common;

namespace SahakariMS.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController(IMediator mediator) : ControllerBase
{
    /// <summary>POST /auth/login — authenticate user and issue JWT.</summary>
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

    /// <summary>POST /auth/refresh-token — rotate refresh token.</summary>
    [HttpPost("refresh-token")]
    [AllowAnonymous]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new RefreshTokenCommand(request.RefreshToken), ct);
        if (!result.IsSuccess) return Unauthorized(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<RefreshTokenResponse>.Ok(result.Value!));
    }

    /// <summary>POST /auth/logout — revoke refresh token.</summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest request, CancellationToken ct)
    {
        await mediator.Send(new LogoutCommand(request.RefreshToken), ct);
        return NoContent();
    }
}

[ApiController]
[Route("api/v1/members")]
[Authorize]
public class MembersController(IMediator mediator) : ControllerBase
{
    [HttpGet]
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

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetMember(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Members.GetMemberByIdQuery(id), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Members.MemberDetailDto>.Ok(result.Value!));
    }

    [HttpPost]
    public async Task<IActionResult> RegisterMember([FromBody] Application.Members.RegisterMemberRequest request, CancellationToken ct)
    {
        var actorId = GetCurrentUserId();
        var result = await mediator.Send(new Application.Members.RegisterMemberCommand(request, actorId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return CreatedAtAction(nameof(GetMember), new { id = result.Value }, new { id = result.Value, status = "Pending" });
    }

    [HttpPost("{id:guid}/approve")]
    public async Task<IActionResult> ApproveMember(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Members.ApproveMemberCommand(id, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { message = "Member approved." }));
    }

    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

[ApiController]
[Route("api/v1/savings/accounts")]
[Authorize]
public class SavingsController(IMediator mediator) : ControllerBase
{
    [HttpPost("{id:guid}/deposit")]
    public async Task<IActionResult> Deposit(Guid id, [FromBody] Application.Savings.DepositRequest request, CancellationToken ct)
    {
        var actorId = GetCurrentUserId();
        var result = await mediator.Send(new Application.Savings.DepositCommand(id, request, actorId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Savings.TransactionResponse>.Ok(result.Value!));
    }

    [HttpPost("{id:guid}/withdraw")]
    public async Task<IActionResult> Withdraw(Guid id, [FromBody] Application.Savings.WithdrawRequest request, CancellationToken ct)
    {
        var actorId = GetCurrentUserId();
        var result = await mediator.Send(new Application.Savings.WithdrawCommand(id, request, actorId), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Savings.TransactionResponse>.Ok(result.Value!));
    }

    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

[ApiController]
[Route("api/v1/loans")]
[Authorize]
public class LoansController(IMediator mediator) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> ApplyLoan([FromBody] Application.Loans.ApplyLoanRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.ApplyLoanCommand(request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/loans/{result.Value}", new { id = result.Value });
    }

    [HttpPost("{id:guid}/approve")]
    public async Task<IActionResult> ApproveLoan(Guid id, [FromBody] ApproveLoanBody body, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.ApproveLoanCommand(id, body.ApprovedAmount, body.Remarks, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { message = "Loan approved." }));
    }

    [HttpPost("{id:guid}/disburse")]
    public async Task<IActionResult> DisburseLoan(Guid id, [FromBody] DisburseLoanBody body, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.DisburseLoanCommand(id, body.DisbursedAmount, body.Mode, body.Date, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<object>.Ok(new { message = "Loan disbursed." }));
    }

    [HttpPost("{id:guid}/payment")]
    public async Task<IActionResult> MakePayment(Guid id, [FromBody] Application.Loans.LoanPaymentRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.MakePaymentCommand(id, request, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Loans.LoanPaymentResponse>.Ok(result.Value!));
    }

    [HttpGet("{id:guid}/schedule")]
    public async Task<IActionResult> GetSchedule(Guid id, CancellationToken ct)
    {
        var result = await mediator.Send(new Application.Loans.GetEmiScheduleQuery(id), ct);
        if (!result.IsSuccess) return NotFound(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<List<Application.Loans.EmiScheduleDto>>.Ok(result.Value!));
    }

    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

public record ApproveLoanBody(decimal ApprovedAmount, string? Remarks);
public record DisburseLoanBody(decimal DisbursedAmount, string Mode, DateOnly Date);

[ApiController]
[Route("api/v1/accounting")]
[Authorize]
public class AccountingController(IMediator mediator) : ControllerBase
{
    [HttpPost("vouchers")]
    public async Task<IActionResult> CreateVoucher([FromBody] Application.Accounting.CreateVoucherRequest request, CancellationToken ct)
    {
        var branchId = Guid.TryParse(User.FindFirst("branchId")?.Value, out var b) ? b : Guid.Empty;
        var result = await mediator.Send(new Application.Accounting.CreateVoucherCommand(request, branchId, GetCurrentUserId()), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Created($"/api/v1/accounting/vouchers/{result.Value}", new { id = result.Value });
    }

    [HttpGet("trial-balance")]
    public async Task<IActionResult> GetTrialBalance([FromQuery] Guid? branchId, [FromQuery] DateOnly? asOfDate, CancellationToken ct)
    {
        var bid = branchId ?? (Guid.TryParse(User.FindFirst("branchId")?.Value, out var b) ? b : Guid.Empty);
        var result = await mediator.Send(new Application.Accounting.GetTrialBalanceQuery(bid, asOfDate ?? DateOnly.FromDateTime(DateTime.UtcNow)), ct);
        if (!result.IsSuccess) return BadRequest(ApiResponse<object>.Fail(result.ErrorCode!, result.ErrorMessage!));
        return Ok(ApiResponse<Application.Accounting.TrialBalanceDto>.Ok(result.Value!));
    }

    private Guid GetCurrentUserId() =>
        Guid.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var id)
            ? id : Guid.Empty;
}

[ApiController]
[Route("api/v1/dashboard")]
[Authorize]
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
}
