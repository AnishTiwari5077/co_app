namespace SahakariMS.Shared.Common;

/// <summary>
/// Standard API JSON envelope matching docs/api/api-specification.md format.
/// All controllers return this type.
/// </summary>
public class ApiResponse<T>
{
    public bool Success { get; init; }
    public T? Data { get; init; }
    public string? Message { get; init; }
    public DateTime Timestamp { get; init; } = DateTime.UtcNow;
    public ApiError? Error { get; init; }
    public string? CorrelationId { get; init; }
    public PaginationMeta? Pagination { get; init; }

    public static ApiResponse<T> Ok(T data, string? message = null) =>
        new() { Success = true, Data = data, Message = message };

    public static ApiResponse<T> OkPaged(T data, int page, int pageSize, int totalCount, string? message = null) =>
        new()
        {
            Success = true,
            Data = data,
            Message = message,
            Pagination = new PaginationMeta(page, pageSize, totalCount)
        };

    public static ApiResponse<T> Fail(string code, string message, string? correlationId = null) =>
        new()
        {
            Success = false,
            Error = new ApiError(code, message, []),
            CorrelationId = correlationId
        };

    public static ApiResponse<T> ValidationFail(List<ValidationError> errors, string? correlationId = null) =>
        new()
        {
            Success = false,
            Error = new ApiError("VALIDATION_ERROR", "One or more validation errors occurred.",
                errors.Select(e => new ApiErrorDetail(e.Field, e.Message)).ToList()),
            CorrelationId = correlationId
        };
}

public record ApiError(string Code, string Message, List<ApiErrorDetail> Details);
public record ApiErrorDetail(string Field, string Message);
public record PaginationMeta(int Page, int PageSize, int TotalCount)
{
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
}
