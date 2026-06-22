using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Auth;

// ── DTOs ─────────────────────────────────────────────────────────────────────

public record LoginRequest(string Username, string Password, string? DeviceId);
public record LoginResponse(
    string AccessToken, string RefreshToken, string TokenType, int ExpiresIn,
    bool RequiresTwoFactor, UserDto User);
public record UserDto(Guid Id, string Username, string FullName, string Email,
    Guid? BranchId, string? BranchCode, string? BranchName,
    bool IsHeadOffice, List<string> Roles, List<string> Permissions);
public record RefreshTokenRequest(string RefreshToken);
public record RefreshTokenResponse(string AccessToken, string RefreshToken, int ExpiresIn);
public record LogoutRequest(string RefreshToken);

// ── Login Command ─────────────────────────────────────────────────────────────

public record LoginCommand(string Username, string Password, string? DeviceId)
    : IRequest<Result<LoginResponse>>;

public class LoginCommandHandler(
    IAppDbContext db,
    IJwtService jwt,
    IUnitOfWork uow) : IRequestHandler<LoginCommand, Result<LoginResponse>>
{
    public async Task<Result<LoginResponse>> Handle(LoginCommand cmd, CancellationToken ct)
    {
        var user = await db.Users
            .Include(u => u.UserRoles).ThenInclude(ur => ur.Role)
                .ThenInclude(r => r!.RolePermissions).ThenInclude(rp => rp.Permission)
            .Include(u => u.Branch)
            .FirstOrDefaultAsync(u => (u.Username == cmd.Username || u.Email == cmd.Username)
                                      && !u.IsDeleted, ct);

        if (user is null)
            return Result<LoginResponse>.Failure("INVALID_CREDENTIALS", "Invalid username or password.");

        if (user.Status == "Locked")
            return Result<LoginResponse>.Failure("ACCOUNT_LOCKED",
                $"Account is locked until {user.LockedUntil:g}. Contact your administrator.");

        if (!BCrypt.Net.BCrypt.Verify(cmd.Password, user.PasswordHash))
        {
            user.FailedLoginCount++;
            if (user.FailedLoginCount >= 5)
            {
                user.Status = "Locked";
                user.LockedUntil = DateTime.UtcNow.AddMinutes(30);
            }
            await uow.SaveChangesAsync(ct);
            return Result<LoginResponse>.Failure("INVALID_CREDENTIALS", "Invalid username or password.");
        }

        user.FailedLoginCount = 0;
        user.LastLoginAt = DateTime.UtcNow;

        var roles = user.UserRoles.Select(ur => ur.Role!.RoleCode).ToList();
        var permissions = user.UserRoles
            .SelectMany(ur => ur.Role!.RolePermissions)
            .Select(rp => rp.Permission!.PermissionCode)
            .Distinct().ToList();

        var accessToken   = jwt.GenerateAccessToken(user, roles, permissions);
        var refreshToken  = jwt.GenerateRefreshToken();

        await db.RefreshTokens.AddAsync(new Domain.Entities.RefreshToken
        {
            UserId = user.Id, Token = refreshToken,
            DeviceId = cmd.DeviceId, ExpiresAt = DateTime.UtcNow.AddDays(7)
        }, ct);
        await uow.SaveChangesAsync(ct);

        return Result<LoginResponse>.Success(new LoginResponse(
            accessToken, refreshToken, "Bearer", 900, false,
            new UserDto(user.Id, user.Username, user.FullName, user.Email,
                user.BranchId, user.Branch?.BranchCode,
                user.Branch?.BranchName, user.Branch?.IsHeadOffice ?? false,
                roles, permissions)));
    }
}

// ── Refresh Token Command ─────────────────────────────────────────────────────

public record RefreshTokenCommand(string Token) : IRequest<Result<RefreshTokenResponse>>;

public class RefreshTokenCommandHandler(IAppDbContext db, IJwtService jwt, IUnitOfWork uow)
    : IRequestHandler<RefreshTokenCommand, Result<RefreshTokenResponse>>
{
    public async Task<Result<RefreshTokenResponse>> Handle(RefreshTokenCommand cmd, CancellationToken ct)
    {
        var stored = await db.RefreshTokens
            .Include(rt => rt.User)
                .ThenInclude(u => u!.UserRoles).ThenInclude(ur => ur.Role)
                    .ThenInclude(r => r!.RolePermissions).ThenInclude(rp => rp.Permission)
            .FirstOrDefaultAsync(rt => rt.Token == cmd.Token && !rt.IsRevoked, ct);

        if (stored is null || stored.ExpiresAt < DateTime.UtcNow)
            return Result<RefreshTokenResponse>.Failure("INVALID_TOKEN", "Refresh token is invalid or expired.");

        stored.IsRevoked = true;
        stored.RevokedAt = DateTime.UtcNow;

        var user = stored.User!;
        var roles = user.UserRoles.Select(ur => ur.Role!.RoleCode).ToList();
        var permissions = user.UserRoles
            .SelectMany(ur => ur.Role!.RolePermissions)
            .Select(rp => rp.Permission!.PermissionCode).Distinct().ToList();

        var newAccess  = jwt.GenerateAccessToken(user, roles, permissions);
        var newRefresh = jwt.GenerateRefreshToken();

        await db.RefreshTokens.AddAsync(new Domain.Entities.RefreshToken
        {
            UserId = user.Id, Token = newRefresh, ExpiresAt = DateTime.UtcNow.AddDays(7)
        }, ct);
        await uow.SaveChangesAsync(ct);

        return Result<RefreshTokenResponse>.Success(new RefreshTokenResponse(newAccess, newRefresh, 900));
    }
}

// ── Logout Command ────────────────────────────────────────────────────────────

public record LogoutCommand(string Token) : IRequest<Result>;

public class LogoutCommandHandler(IAppDbContext db, IUnitOfWork uow) : IRequestHandler<LogoutCommand, Result>
{
    public async Task<Result> Handle(LogoutCommand cmd, CancellationToken ct)
    {
        var token = await db.RefreshTokens.FirstOrDefaultAsync(rt => rt.Token == cmd.Token, ct);
        if (token is not null) { token.IsRevoked = true; token.RevokedAt = DateTime.UtcNow; }
        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}
