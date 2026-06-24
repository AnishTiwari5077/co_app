using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using MediatR;
using StackExchange.Redis;
using SahakariMS.Infrastructure.Persistence;
using SahakariMS.Infrastructure.Services;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Application.Interfaces;
using SahakariMS.Api.Middleware;
using Hangfire;
using Hangfire.PostgreSql;
using SahakariMS.Application.Loans;

var builder = WebApplication.CreateBuilder(args);

// ── Configuration ─────────────────────────────────────────────────────────────
var jwtSettings = builder.Configuration.GetSection("JwtSettings").Get<JwtSettings>()!;
var connString  = builder.Configuration.GetConnectionString("DefaultConnection")!;
var redisConn   = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";

// ── Database ──────────────────────────────────────────────────────────────────
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseNpgsql(connString, npg => npg.MigrationsAssembly("SahakariMS.Infrastructure")));
builder.Services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());

// ── Redis ─────────────────────────────────────────────────────────────────────
builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect(redisConn));
builder.Services.AddScoped<ICacheService, RedisCacheService>();

// ── MediatR ───────────────────────────────────────────────────────────────────
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(typeof(SahakariMS.Application.Auth.LoginCommand).Assembly);
});

// ── JWT Auth ──────────────────────────────────────────────────────────────────
builder.Services.Configure<JwtSettings>(builder.Configuration.GetSection("JwtSettings"));
builder.Services.AddSingleton<JwtService>();
builder.Services.AddSingleton<IJwtService>(sp => sp.GetRequiredService<JwtService>());
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = jwtSettings.Issuer,
            ValidAudience            = jwtSettings.Audience,
            IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.SecretKey))
        };
    });
builder.Services.AddAuthorization();

// ── Repositories & UoW ────────────────────────────────────────────────────────
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));

// ── Infrastructure Services ───────────────────────────────────────────────────
builder.Services.AddScoped<ISequenceGenerator, SequenceGenerator>();

// ── Hangfire ──────────────────────────────────────────────────────────────────
builder.Services.AddHangfire(cfg => cfg
    .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
    .UseSimpleAssemblyNameTypeSerializer()
    .UseRecommendedSerializerSettings()
    .UsePostgreSqlStorage(c => c.UseNpgsqlConnection(connString)));
builder.Services.AddHangfireServer();
builder.Services.AddScoped<LoanNpaJob>();

// ── API ───────────────────────────────────────────────────────────────────────
builder.Services.AddControllers().AddJsonOptions(opts =>
    opts.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "SahakariMS API", Version = "v1",
        Description = "Nepal Cooperative Management System API" });
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization", Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer", BearerFormat = "JWT", In = Microsoft.OpenApi.Models.ParameterLocation.Header
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        [new Microsoft.OpenApi.Models.OpenApiSecurityScheme
        {
            Reference = new Microsoft.OpenApi.Models.OpenApiReference
                { Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "Bearer" }
        }] = []
    });
});

var allowedOrigins = builder.Configuration
    .GetSection("AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:3000", "http://localhost:5173", "http://localhost:5111"];

builder.Services.AddCors(opts =>
    opts.AddDefaultPolicy(p => p
        .AllowAnyOrigin()
        .AllowAnyHeader()
        .AllowAnyMethod()));

// ── Build ─────────────────────────────────────────────────────────────────────
var app = builder.Build();

// Auto-migrate on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();

    // Seed default admin user if no users exist
    if (!db.Users.Any())
    {
        var adminId = Guid.NewGuid();
        var adminRoleId = Guid.Parse("11111111-1111-1111-1111-111111111111");

        db.Users.Add(new SahakariMS.Domain.Entities.User
        {
            Id = adminId,
            EmployeeCode = "EMP-001",
            FullName = "System Administrator",
            Email = "admin@sahakarims.np",
            Username = "admin",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin@1234", workFactor: 11),
            Phone = "9800000000",
            Status = "Active",
            IsTwoFactorEnabled = false,
            FailedLoginCount = 0,
            MustChangePassword = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            IsDeleted = false,
        });

        db.Set<SahakariMS.Domain.Entities.UserRole>().Add(new SahakariMS.Domain.Entities.UserRole
        {
            UserId = adminId,
            RoleId = adminRoleId,
        });

        await db.SaveChangesAsync();
    }
}

// Ensure uploads directory exists
var uploadsPath = Path.Combine(app.Environment.ContentRootPath, "wwwroot", "uploads", "members");
Directory.CreateDirectory(uploadsPath);
app.UseStaticFiles();

app.UseMiddleware<CorrelationIdMiddleware>();
app.UseMiddleware<ExceptionMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "SahakariMS v1"));
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
    app.UseHsts();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
// Hangfire dashboard — protected in production
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    // In production only allow authenticated ADMIN users
    Authorization = app.Environment.IsDevelopment()
        ? [new Hangfire.Dashboard.LocalRequestsOnlyAuthorizationFilter()]
        : [new HangfireAdminAuthFilter()]
});

// ── Recurring Jobs ────────────────────────────────────────────────────────────
// Runs every day at midnight UTC: marks overdue EMIs and updates NPA classification
RecurringJob.AddOrUpdate<LoanNpaJob>(
    "loan-npa-daily",
    job => job.ExecuteAsync(),
    Cron.Daily(0, 0), // midnight UTC
    new RecurringJobOptions { TimeZone = TimeZoneInfo.Utc });
app.MapControllers();

app.Run();
