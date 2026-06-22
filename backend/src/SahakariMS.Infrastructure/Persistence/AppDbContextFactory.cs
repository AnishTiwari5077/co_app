using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace SahakariMS.Infrastructure.Persistence;

/// <summary>
/// Used by dotnet-ef at design time (migrations) when no running app is available.
/// Reads connection string from appsettings.json in the API project.
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(Path.Combine(Directory.GetCurrentDirectory(),
                "..", "SahakariMS.Api"))
            .AddJsonFile("appsettings.json", optional: false)
            .AddEnvironmentVariables()
            .Build();

        var connString = config.GetConnectionString("DefaultConnection")!;

        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql(connString,
            npg => npg.MigrationsAssembly("SahakariMS.Infrastructure"));

        return new AppDbContext(optionsBuilder.Options);
    }
}
