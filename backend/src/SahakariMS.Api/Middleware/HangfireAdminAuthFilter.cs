using Hangfire.Dashboard;

namespace SahakariMS.Api.Middleware;

/// <summary>
/// Restricts Hangfire dashboard access to authenticated users with the ADMIN role.
/// Used in production only — development uses LocalRequestsOnlyAuthorizationFilter.
/// </summary>
public class HangfireAdminAuthFilter : IDashboardAuthorizationFilter
{
    public bool Authorize(DashboardContext context)
    {
        var httpContext = context.GetHttpContext();

        // Must be authenticated
        if (httpContext.User?.Identity?.IsAuthenticated != true)
            return false;

        // Must have ADMIN role
        return httpContext.User.IsInRole("ADMIN");
    }
}
