namespace SahakariMS.Shared.Common;

/// <summary>Functional result type — either a success value or an error.</summary>
public class Result<T>
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public string? ErrorCode { get; }
    public string? ErrorMessage { get; }
    public List<ValidationError>? ValidationErrors { get; }

    private Result(T value) { IsSuccess = true; Value = value; }
    private Result(string errorCode, string errorMessage, List<ValidationError>? errors = null)
    {
        IsSuccess = false; ErrorCode = errorCode; ErrorMessage = errorMessage; ValidationErrors = errors;
    }

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(string code, string message) => new(code, message);
    public static Result<T> ValidationFailure(List<ValidationError> errors) =>
        new("VALIDATION_ERROR", "One or more validation errors occurred.", errors);
}

public class Result
{
    public bool IsSuccess { get; }
    public string? ErrorCode { get; }
    public string? ErrorMessage { get; }
    private Result() { IsSuccess = true; }
    private Result(string errorCode, string errorMessage) { IsSuccess = false; ErrorCode = errorCode; ErrorMessage = errorMessage; }
    public static Result Success() => new();
    public static Result Failure(string code, string message) => new(code, message);
}

public record ValidationError(string Field, string Message);
