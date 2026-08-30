using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Services;
using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Follow.Infrastructure.Services;

public sealed class AdminAccountOptions
{
    public const string SectionName = "AdminAccount";

    public string Username { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;
}

public sealed class AdminAccountInitializer
{
    private readonly FollowDbContext _context;
    private readonly IPasswordHasher _passwordHasher;
    private readonly AdminAccountOptions _options;

    public AdminAccountInitializer(
        FollowDbContext context,
        IPasswordHasher passwordHasher,
        IOptions<AdminAccountOptions> options)
    {
        _context = context;
        _passwordHasher = passwordHasher;
        _options = options.Value;
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.Username) ||
            string.IsNullOrWhiteSpace(_options.Email) ||
            string.IsNullOrEmpty(_options.Password))
        {
            throw new InvalidOperationException(
                "AdminAccount:Username、AdminAccount:Email 和 AdminAccount:Password 必须全部配置");
        }

        var credentials = UserCredentialPolicy.NormalizeAndValidate(
            _options.Username,
            _options.Email,
            _options.Password);

        var usernameMatch = await _context.Users.FirstOrDefaultAsync(
            user => user.Username.ToLower() == credentials.Username,
            cancellationToken);
        var emailMatch = await _context.Users.FirstOrDefaultAsync(
            user => user.Email.ToLower() == credentials.Email,
            cancellationToken);

        if (usernameMatch is not null && emailMatch is not null && usernameMatch.Id != emailMatch.Id)
        {
            throw new InvalidOperationException("环境管理员用户名和邮箱分别属于两个已有账户");
        }

        var admin = emailMatch ?? usernameMatch;
        if (admin is null)
        {
            admin = new User
            {
                Username = credentials.Username,
                Email = credentials.Email,
                PasswordHash = _passwordHasher.HashPassword(credentials.Password),
                Role = UserRole.Admin
            };
            _context.Users.Add(admin);
            await _context.SaveChangesAsync(cancellationToken);
            return;
        }

        var usernameChanged = !string.Equals(
            admin.Username,
            credentials.Username,
            StringComparison.Ordinal);
        var emailChanged = !string.Equals(
            admin.Email,
            credentials.Email,
            StringComparison.Ordinal);
        var roleChanged = admin.Role != UserRole.Admin;
        var passwordChanged = !_passwordHasher.VerifyPassword(
            credentials.Password,
            admin.PasswordHash);

        if (!usernameChanged && !emailChanged && !roleChanged && !passwordChanged)
            return;

        if (usernameChanged) admin.Username = credentials.Username;
        if (emailChanged) admin.Email = credentials.Email;
        if (roleChanged) admin.Role = UserRole.Admin;
        if (passwordChanged)
        {
            admin.PasswordHash = _passwordHasher.HashPassword(credentials.Password);
        }

        await _context.Entry(admin)
            .Collection(user => user.Sessions)
            .LoadAsync(cancellationToken);
        var now = DateTime.UtcNow;
        foreach (var session in admin.Sessions.Where(session => session.RevokedAt == null))
        {
            session.RevokedAt = now;
            session.RevokedReason = "admin-account-rotated";
            session.Version++;
        }

        await _context.SaveChangesAsync(cancellationToken);
    }
}
