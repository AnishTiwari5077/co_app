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

    // ── Ensure PostgreSQL extensions exist ────────────────────────────────────
    await db.Database.ExecuteSqlRawAsync("CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";");
    await db.Database.ExecuteSqlRawAsync("CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";");

    // ── Ensure custom schemas exist ───────────────────────────────────────────
    await db.Database.ExecuteSqlRawAsync("CREATE SCHEMA IF NOT EXISTS accounting;");
    await db.Database.ExecuteSqlRawAsync("CREATE SCHEMA IF NOT EXISTS audit;");
    await db.Database.ExecuteSqlRawAsync("CREATE SCHEMA IF NOT EXISTS hr;");

    // ── Ensure sequences exist (for member codes, loan numbers, etc.) ─────────
    await db.Database.ExecuteSqlRawAsync("CREATE SEQUENCE IF NOT EXISTS member_code_seq    START 1 INCREMENT 1;");
    await db.Database.ExecuteSqlRawAsync("CREATE SEQUENCE IF NOT EXISTS loan_number_seq    START 1 INCREMENT 1;");
    await db.Database.ExecuteSqlRawAsync("CREATE SEQUENCE IF NOT EXISTS account_number_seq START 1 INCREMENT 1;");
    await db.Database.ExecuteSqlRawAsync("CREATE SEQUENCE IF NOT EXISTS voucher_number_seq START 1 INCREMENT 1;");
    await db.Database.ExecuteSqlRawAsync("CREATE SEQUENCE IF NOT EXISTS receipt_number_seq START 1 INCREMENT 1;");

    // ── Ensure admin has Head Office BranchId assigned ────────────────────────
    var headOfficeBranchId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    var adminUser = db.Users.FirstOrDefault(u => u.Username == "admin");
    if (adminUser != null && adminUser.BranchId == null)
    {
        adminUser.BranchId = headOfficeBranchId;
        adminUser.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
    }

    // ── Seed Saving Schemes if none exist ─────────────────────────────────────
    if (!db.SavingSchemes.Any())
    {
        db.SavingSchemes.AddRange(
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "REG-001", SchemeName = "साधारण बचत (Regular Savings)",           SchemeType = "Regular",          InterestRate = 6.00m,  InterestCalculation = "Daily", InterestPosting = "Quarterly", MinimumBalance = 500,  MinimumDeposit = 100,   WithdrawalAllowed = true,  WithdrawalNoticeDays = 0,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "JNR-001", SchemeName = "बाल बचत (Junior Savings)",               SchemeType = "Regular",          InterestRate = 7.00m,  InterestCalculation = "Daily", InterestPosting = "Quarterly", MinimumBalance = 200,  MinimumDeposit = 50,    WithdrawalAllowed = true,  WithdrawalNoticeDays = 0,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "FD-006",  SchemeName = "६ महिने मुद्दती (FD 6 Months)",         SchemeType = "FixedDeposit",     InterestRate = 9.50m,  InterestCalculation = "Daily", InterestPosting = "Monthly",   MinimumBalance = 0,    MinimumDeposit = 5000,  WithdrawalAllowed = false, WithdrawalNoticeDays = 7,  MinTenureMonths = 6,  MaxTenureMonths = 6,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "FD-012",  SchemeName = "१ वर्षे मुद्दती (FD 1 Year)",           SchemeType = "FixedDeposit",     InterestRate = 11.00m, InterestCalculation = "Daily", InterestPosting = "Monthly",   MinimumBalance = 0,    MinimumDeposit = 5000,  WithdrawalAllowed = false, WithdrawalNoticeDays = 15, MinTenureMonths = 12, MaxTenureMonths = 12, IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "FD-024",  SchemeName = "२ वर्षे मुद्दती (FD 2 Years)",          SchemeType = "FixedDeposit",     InterestRate = 12.00m, InterestCalculation = "Daily", InterestPosting = "Monthly",   MinimumBalance = 0,    MinimumDeposit = 10000, WithdrawalAllowed = false, WithdrawalNoticeDays = 30, MinTenureMonths = 24, MaxTenureMonths = 24, IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "RD-001",  SchemeName = "मासिक आवर्ती बचत (Monthly Recurring)", SchemeType = "RecurringDeposit", InterestRate = 8.50m,  InterestCalculation = "Daily", InterestPosting = "Yearly",    MinimumBalance = 0,    MinimumDeposit = 500,   WithdrawalAllowed = false, WithdrawalNoticeDays = 30, MinTenureMonths = 12, MaxTenureMonths = 60, IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.SavingScheme { SchemeCode = "SR-001",  SchemeName = "जेष्ठ नागरिक बचत (Senior Citizen)",     SchemeType = "Regular",          InterestRate = 8.00m,  InterestCalculation = "Daily", InterestPosting = "Quarterly", MinimumBalance = 500,  MinimumDeposit = 500,   WithdrawalAllowed = true,  WithdrawalNoticeDays = 0,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
        );
        await db.SaveChangesAsync();
    }

    // ── Seed Loan Products if none exist ──────────────────────────────────────
    if (!db.LoanProducts.Any())
    {
        db.LoanProducts.AddRange(
            new SahakariMS.Domain.Entities.LoanProduct { ProductCode = "PL-001", ProductName = "Personal Loan",     LoanType = "Personal",    InterestRate = 14.0m, InterestType = "Diminishing", PenaltyRate = 2, MinAmount = 10000,   MaxAmount = 500000,   MinTenureMonths = 3,  MaxTenureMonths = 60,  ProcessingFeePercent = 1.5m, CollateralRequired = false, GuarantorRequired = true,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.LoanProduct { ProductCode = "BL-001", ProductName = "Business Loan",     LoanType = "Business",    InterestRate = 13.0m, InterestType = "Diminishing", PenaltyRate = 2, MinAmount = 50000,   MaxAmount = 5000000,  MinTenureMonths = 6,  MaxTenureMonths = 84,  ProcessingFeePercent = 1.0m, CollateralRequired = true,  GuarantorRequired = true,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.LoanProduct { ProductCode = "AG-001", ProductName = "Agriculture Loan",  LoanType = "Agriculture", InterestRate = 11.0m, InterestType = "Diminishing", PenaltyRate = 2, MinAmount = 10000,   MaxAmount = 1000000,  MinTenureMonths = 3,  MaxTenureMonths = 60,  ProcessingFeePercent = 1.0m, CollateralRequired = true,  GuarantorRequired = false, IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.LoanProduct { ProductCode = "HL-001", ProductName = "Home Loan",         LoanType = "Housing",     InterestRate = 12.0m, InterestType = "Diminishing", PenaltyRate = 2, MinAmount = 100000,  MaxAmount = 10000000, MinTenureMonths = 12, MaxTenureMonths = 240, ProcessingFeePercent = 0.5m, CollateralRequired = true,  GuarantorRequired = true,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new SahakariMS.Domain.Entities.LoanProduct { ProductCode = "MF-001", ProductName = "Microfinance Loan", LoanType = "Personal",    InterestRate = 15.0m, InterestType = "Flat",        PenaltyRate = 3, MinAmount = 5000,    MaxAmount = 200000,   MinTenureMonths = 3,  MaxTenureMonths = 24,  ProcessingFeePercent = 2.0m, CollateralRequired = false, GuarantorRequired = true,  IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
        );
        await db.SaveChangesAsync();
    }

    // Seed default admin user if no users exist
    if (!db.Users.Any())
    {
        var adminId = Guid.NewGuid();
        var adminRoleId = Guid.Parse("11111111-1111-1111-1111-111111111111");

        db.Users.Add(new SahakariMS.Domain.Entities.User
        {
            Id = adminId,
            BranchId = headOfficeBranchId,   // Always assign Head Office branch
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
