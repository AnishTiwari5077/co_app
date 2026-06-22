using System.Net;
using System.Text.Json;
using SahakariMS.Shared.Common;

namespace SahakariMS.Api.Middleware;

/// <summary>Global exception handler — converts unhandled exceptions to ApiResponse error envelopes.</summary>
public class ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await next(ctx);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception on {Method} {Path}", ctx.Request.Method, ctx.Request.Path);
            await WriteErrorAsync(ctx, ex);
        }
    }

    private static async Task WriteErrorAsync(HttpContext ctx, Exception ex)
    {
        ctx.Response.ContentType = "application/json";
        var correlationId = ctx.TraceIdentifier;

        var (statusCode, errorCode, message) = ex switch
        {
            UnauthorizedAccessException => (HttpStatusCode.Forbidden, "FORBIDDEN", "Access denied."),
            _ => (HttpStatusCode.InternalServerError, "INTERNAL_ERROR", "An unexpected error occurred.")
        };

        ctx.Response.StatusCode = (int)statusCode;
        var response = ApiResponse<object>.Fail(errorCode, message, correlationId);
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(response,
            new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }));
    }
}

/// <summary>Adds X-Correlation-ID header to every request/response.</summary>
public class CorrelationIdMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        var correlationId = ctx.Request.Headers["X-Correlation-ID"].FirstOrDefault()
            ?? ctx.TraceIdentifier;
        ctx.Response.Headers["X-Correlation-ID"] = correlationId;
        await next(ctx);
    }
}
