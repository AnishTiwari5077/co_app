using SahakariMS.Domain.Common;

namespace SahakariMS.Domain.Interfaces;

/// <summary>Generic repository contract — infrastructure implements this.</summary>
public interface IRepository<T> where T : BaseEntity
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default);
    Task<T> AddAsync(T entity, CancellationToken ct = default);
    Task UpdateAsync(T entity, CancellationToken ct = default);
    Task DeleteAsync(T entity, CancellationToken ct = default);
}

/// <summary>Unit of Work — wraps all repositories in one transaction.</summary>
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
    Task BeginTransactionAsync(CancellationToken ct = default);
    Task CommitTransactionAsync(CancellationToken ct = default);
    Task RollbackTransactionAsync(CancellationToken ct = default);
}

/// <summary>Cache service contract backed by Redis.</summary>
public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken ct = default);
    Task SetAsync<T>(string key, T value, TimeSpan expiry, CancellationToken ct = default);
    Task RemoveAsync(string key, CancellationToken ct = default);
    Task RemoveByPrefixAsync(string prefix, CancellationToken ct = default);
}

/// <summary>Sequence generator for human-readable codes (member codes, loan numbers etc.).</summary>
public interface ISequenceGenerator
{
    Task<string> NextMemberCodeAsync(string branchCode, int fiscalYear);
    Task<string> NextLoanNumberAsync(string branchCode, int fiscalYear);
    Task<string> NextAccountNumberAsync(string prefix, int fiscalYear);
    Task<string> NextVoucherNumberAsync(string voucherType, Guid branchId, int fiscalYear);
    Task<string> NextReceiptNumberAsync(Guid branchId);
}

/// <summary>SMS gateway contract — Sparrow SMS per technology-stack.md.</summary>
public interface ISmsService
{
    Task<bool> SendOtpAsync(string phoneNumber, string otp, CancellationToken ct = default);
    Task<bool> SendSmsAsync(string phoneNumber, string message, CancellationToken ct = default);
}

/// <summary>Current user context from JWT claims.</summary>
public interface ICurrentUser
{
    Guid? UserId { get; }
    string? Username { get; }
    Guid? BranchId { get; }
    IEnumerable<string> Roles { get; }
    IEnumerable<string> Permissions { get; }
    bool HasPermission(string permission);
}
