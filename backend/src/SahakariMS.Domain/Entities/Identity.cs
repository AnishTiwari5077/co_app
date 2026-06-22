using SahakariMS.Domain.Common;

namespace SahakariMS.Domain.Entities;

/// <summary>Cooperative branch office — per public.branches table spec.</summary>
public class Branch : BaseEntity
{
    public string BranchCode { get; set; } = string.Empty;
    public string BranchName { get; set; } = string.Empty;
    public string? BranchNameNp { get; set; }
    public string? Address { get; set; }
    public string? District { get; set; }
    public string? Municipality { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public Guid? ManagerId { get; set; }
    public bool IsHeadOffice { get; set; } = false;
    public string Status { get; set; } = "Active";
    public DateOnly? EstablishedDate { get; set; }

    // Navigation
    public ICollection<User> Users { get; set; } = [];
    public ICollection<Member> Members { get; set; } = [];
}

/// <summary>System user (employee) — per public.users table spec.</summary>
public class User : BaseEntity
{
    public Guid? BranchId { get; set; }
    public string? EmployeeCode { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? PhotoUrl { get; set; }
    public string Status { get; set; } = "Active";   // Active|Inactive|Locked
    public bool IsTwoFactorEnabled { get; set; } = false;
    public string? TwoFactorSecret { get; set; }
    public int FailedLoginCount { get; set; } = 0;
    public DateTime? LockedUntil { get; set; }
    public DateTime? LastLoginAt { get; set; }
    public DateTime? PasswordChangedAt { get; set; }
    public bool MustChangePassword { get; set; } = true;

    // Navigation
    public Branch? Branch { get; set; }
    public ICollection<UserRole> UserRoles { get; set; } = [];
    public ICollection<RefreshToken> RefreshTokens { get; set; } = [];
}

/// <summary>Role definition — per public.roles table spec.</summary>
public class Role : BaseEntity
{
    public string RoleCode { get; set; } = string.Empty;
    public string RoleName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSystemRole { get; set; } = false;
    public bool IsActive { get; set; } = true;

    public ICollection<UserRole> UserRoles { get; set; } = [];
    public ICollection<RolePermission> RolePermissions { get; set; } = [];
}

public class Permission : BaseEntity
{
    public string PermissionCode { get; set; } = string.Empty;
    public string Module { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public ICollection<RolePermission> RolePermissions { get; set; } = [];
}

public class UserRole
{
    public Guid UserId { get; set; }
    public Guid RoleId { get; set; }
    public Guid? BranchId { get; set; }
    public User? User { get; set; }
    public Role? Role { get; set; }
}

public class RolePermission
{
    public Guid RoleId { get; set; }
    public Guid PermissionId { get; set; }
    public Role? Role { get; set; }
    public Permission? Permission { get; set; }
}

/// <summary>JWT refresh token store — per public.refresh_tokens.</summary>
public class RefreshToken : BaseEntity
{
    public Guid UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public string? DeviceId { get; set; }
    public string? IpAddress { get; set; }
    public DateTime ExpiresAt { get; set; }
    public bool IsRevoked { get; set; } = false;
    public DateTime? RevokedAt { get; set; }
    public User? User { get; set; }
}
