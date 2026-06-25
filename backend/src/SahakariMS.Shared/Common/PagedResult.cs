namespace SahakariMS.Shared.Common;

/// <summary>Standard paginated response matching API spec.</summary>
public class PagedResult<T>
{
    public IReadOnlyList<T> Data { get; init; } = [];
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalCount { get; init; }
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);

    public static PagedResult<T> Create(IReadOnlyList<T> data, int page, int pageSize, int totalCount) =>
        new() { Data = data, Page = page, PageSize = pageSize, TotalCount = totalCount };
}

/// <summary>Standard query parameters for paginated list endpoints.</summary>
public record PagedQuery
{
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 20;
    public string? Search { get; init; }

    public int Skip => (Page - 1) * PageSize;
    public int Take => Math.Min(PageSize, 100);
}
