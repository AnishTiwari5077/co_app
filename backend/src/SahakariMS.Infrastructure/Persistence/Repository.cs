using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using SahakariMS.Domain.Common;
using SahakariMS.Domain.Interfaces;

namespace SahakariMS.Infrastructure.Persistence;

/// <summary>Generic EF Core repository.</summary>
public class Repository<T>(AppDbContext db) : IRepository<T> where T : BaseEntity
{
    protected readonly AppDbContext _db = db;
    protected readonly DbSet<T> _set = db.Set<T>();

    public async Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default) =>
        await _set.FirstOrDefaultAsync(e => e.Id == id, ct);

    public async Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default) =>
        await _set.ToListAsync(ct);

    public async Task<T> AddAsync(T entity, CancellationToken ct = default)
    {
        await _set.AddAsync(entity, ct);
        return entity;
    }

    public Task UpdateAsync(T entity, CancellationToken ct = default)
    {
        entity.UpdatedAt = DateTime.UtcNow;
        _db.Entry(entity).State = EntityState.Modified;
        return Task.CompletedTask;
    }

    public Task DeleteAsync(T entity, CancellationToken ct = default)
    {
        entity.IsDeleted = true;
        entity.DeletedAt = DateTime.UtcNow;
        _db.Entry(entity).State = EntityState.Modified;
        return Task.CompletedTask;
    }
}

/// <summary>Unit of Work wrapping a PostgreSQL transaction.</summary>
public class UnitOfWork(AppDbContext db) : IUnitOfWork
{
    private IDbContextTransaction? _tx;

    public async Task<int> SaveChangesAsync(CancellationToken ct = default) =>
        await db.SaveChangesAsync(ct);

    public async Task BeginTransactionAsync(CancellationToken ct = default) =>
        _tx = await db.Database.BeginTransactionAsync(ct);

    public async Task CommitTransactionAsync(CancellationToken ct = default)
    {
        if (_tx is not null) { await _tx.CommitAsync(ct); await _tx.DisposeAsync(); _tx = null; }
    }

    public async Task RollbackTransactionAsync(CancellationToken ct = default)
    {
        if (_tx is not null) { await _tx.RollbackAsync(ct); await _tx.DisposeAsync(); _tx = null; }
    }
}
