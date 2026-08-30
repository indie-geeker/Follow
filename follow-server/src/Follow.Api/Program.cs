using System.Text;
using System.Security.Claims;
using Follow.Api.Auth;
using Follow.Api.Configuration;
using Follow.Api.Endpoints;
using Follow.Api.Middleware;
using Follow.Api.RateLimiting;
using Follow.Api.Security;
using Follow.Api.Uploads;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.Constants;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureFollowUploadLimits();
builder.Services.AddFollowUploadLimits();

// Add services to the container

// Database
var defaultConnection = GetRequiredConnectionString(builder.Configuration);
builder.Services.AddDbContext<FollowDbContext>(options =>
    options.UseNpgsql(defaultConnection));

// Services
builder.Services.AddTransient<GlobalExceptionHandler>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddSingleton<RefreshTokenProtector>();
builder.Services.AddSingleton<AuthCookieManager>();
builder.Services.AddFollowRateLimiting(builder.Configuration);
builder.Services.AddScoped<StorageDeletionQueue>();
builder.Services.AddHostedService<StorageDeletionWorker>();
builder.Services.Configure<MusicImportOptions>(
    builder.Configuration.GetSection(MusicImportOptions.SectionName));
var musicImportOptions = builder.Configuration
    .GetSection(MusicImportOptions.SectionName)
    .Get<MusicImportOptions>() ?? new MusicImportOptions();
var musicImportSettings = musicImportOptions.ToRuntimeSettings();
builder.Services.AddSingleton(musicImportSettings);
builder.Services.AddScoped<MusicImportScanner>();
builder.Services.AddScoped<MusicImportProcessor>();
builder.Services.AddScoped<IMusicImportService, MusicImportService>();
builder.Services.AddSingleton<IAudioMetadataExtractor, TagLibAudioMetadataExtractor>();
builder.Services.AddHostedService<MusicImportWorker>();
builder.Services.AddSingleton<IStorageService, MinioStorageService>();
builder.Services.AddScoped<IArtistService, ArtistService>();
builder.Services.AddScoped<IAlbumService, AlbumService>();
builder.Services.AddScoped<ITrackService, TrackService>();
builder.Services.AddScoped<IPlaylistService, PlaylistService>();
builder.Services.AddScoped<IUserMusicService, UserMusicService>();
builder.Services.AddScoped<IAdminService, AdminService>();
builder.Services.Configure<AdminAccountOptions>(
    builder.Configuration.GetSection(AdminAccountOptions.SectionName));
builder.Services.AddScoped<AdminAccountInitializer>();
builder.Services.AddScoped<ITagService, TagService>();

// JWT Authentication
var jwtSettings = builder.Configuration.GetSection("JwtSettings");
var secretKey = GetRequiredJwtSecret(builder.Configuration);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey))
    };

    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            if (string.IsNullOrWhiteSpace(context.Token) &&
                !context.Request.Headers.ContainsKey("Authorization"))
            {
                context.Token = context.Request.Cookies[AuthCookieManager.AccessCookieName];
            }

            return Task.CompletedTask;
        },
        OnTokenValidated = async context =>
        {
            var principal = context.Principal;
            if (!Guid.TryParse(
                    principal?.FindFirstValue(ClaimTypes.NameIdentifier),
                    out var userId) ||
                !Guid.TryParse(principal?.FindFirstValue("sid"), out var sessionId))
            {
                context.Fail("Invalid session claims");
                return;
            }

            var authService = context.HttpContext.RequestServices
                .GetRequiredService<IAuthService>();
            if (!await authService.IsSessionActiveAsync(userId, sessionId))
                context.Fail("Session revoked or expired");
        },
        OnChallenge = context =>
        {
            context.HandleResponse();
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.ContentType = "application/json";
            
            var response = Follow.Shared.DTOs.ApiResponse.Error(StatusCodes.Status401Unauthorized, "Unauthorized");
            return context.Response.WriteAsJsonAsync(response);
        },
        OnForbidden = context =>
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            context.Response.ContentType = "application/json";
            
            var response = Follow.Shared.DTOs.ApiResponse.Error(StatusCodes.Status403Forbidden, "Forbidden");
            return context.Response.WriteAsJsonAsync(response);
        }
    };
});

// Authorization policies
builder.Services.AddAuthorizationBuilder()
    .AddPolicy(Policies.AdminOnly, policy => policy.RequireRole(Roles.Admin))
    .AddPolicy(Policies.UserOnly, policy => policy.RequireRole(Roles.Admin, Roles.Member));

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseFollowForwardedHeaders(builder.Configuration);
app.UseMiddleware<GlobalExceptionHandler>();
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

// Map API endpoints
app.MapAuthEndpoints();
app.MapTrackEndpoints();
app.MapArtistEndpoints();
app.MapAlbumEndpoints();
app.MapPlaylistEndpoints();
app.MapUserMusicEndpoints();
app.MapAdminEndpoints();
app.MapTagEndpoints();
app.MapMusicImportEndpoints();

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
    .WithTags("Health");

// API info endpoint
app.MapGet("/", () => Results.Ok(new 
{ 
    name = "Follow Music API", 
    version = "1.0.0",
    docs = "/swagger"
}));

// Auto-apply database migrations on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<FollowDbContext>();
    db.Database.Migrate();
    // Force MinIO bucket initialization before the API can report itself ready.
    _ = scope.ServiceProvider.GetRequiredService<IStorageService>();
    var adminInitializer = scope.ServiceProvider.GetRequiredService<AdminAccountInitializer>();
    await adminInitializer.InitializeAsync();
}

app.Run();

static string GetRequiredConnectionString(IConfiguration configuration)
{
    var connectionString = configuration.GetConnectionString("DefaultConnection");
    return string.IsNullOrWhiteSpace(connectionString)
        ? throw new InvalidOperationException(
            "ConnectionStrings:DefaultConnection 必须通过安全配置提供")
        : connectionString;
}

static string GetRequiredJwtSecret(IConfiguration configuration)
{
    var secret = configuration["JwtSettings:SecretKey"];
    if (string.IsNullOrWhiteSpace(secret) || Encoding.UTF8.GetByteCount(secret) < 32)
    {
        throw new InvalidOperationException(
            "JwtSettings:SecretKey 必须通过安全配置提供且至少为 32 字节");
    }

    return secret;
}

public partial class Program;
