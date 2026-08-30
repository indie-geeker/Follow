using System.Net.Mail;
using System.Text;
using System.Text.RegularExpressions;

namespace Follow.Core.Services;

public static partial class UserCredentialPolicy
{
    public const int MinimumUsernameLength = 3;
    public const int MaximumUsernameLength = 32;
    public const int MinimumPasswordLength = 6;
    public const int MaximumPasswordLength = 128;

    public static NormalizedUserCredentials NormalizeAndValidate(
        string username,
        string email,
        string password)
    {
        var normalizedUsername = NormalizeUsername(username);
        var normalizedEmail = NormalizeEmail(email);
        ValidatePassword(password);

        return new NormalizedUserCredentials(normalizedUsername, normalizedEmail, password);
    }

    public static string NormalizeUsername(string username)
    {
        var normalized = (username ?? string.Empty)
            .Normalize(NormalizationForm.FormKC)
            .Trim()
            .ToLowerInvariant();

        if (!UsernamePattern().IsMatch(normalized))
        {
            throw new ArgumentException(
                $"用户名必须为 {MinimumUsernameLength}-{MaximumUsernameLength} 个字符，只能包含字母、数字、点、下划线或连字符，且必须以字母或数字开头和结尾");
        }

        return normalized;
    }

    public static string NormalizeEmail(string email)
    {
        var normalized = (email ?? string.Empty)
            .Normalize(NormalizationForm.FormKC)
            .Trim()
            .ToLowerInvariant();

        try
        {
            var address = new MailAddress(normalized);
            if (!string.Equals(address.Address, normalized, StringComparison.Ordinal))
            {
                throw new FormatException();
            }
        }
        catch (FormatException)
        {
            throw new ArgumentException("请输入有效的邮箱地址");
        }

        return normalized;
    }

    public static void ValidatePassword(string password)
    {
        if (password is null ||
            password.Length < MinimumPasswordLength ||
            password.Length > MaximumPasswordLength)
        {
            throw new ArgumentException(
                $"密码长度必须为 {MinimumPasswordLength}-{MaximumPasswordLength} 个字符");
        }

        if (password.Any(char.IsWhiteSpace) || password.Any(char.IsControl))
        {
            throw new ArgumentException("密码不能包含空白或控制字符");
        }

        if (!password.Any(char.IsUpper) ||
            !password.Any(char.IsLower) ||
            !password.Any(char.IsDigit) ||
            !password.Any(character => !char.IsLetterOrDigit(character)))
        {
            throw new ArgumentException("密码必须同时包含大写字母、小写字母、数字和特殊字符");
        }
    }

    [GeneratedRegex(@"\A[\p{L}\p{N}][\p{L}\p{N}._-]{1,30}[\p{L}\p{N}]\z", RegexOptions.CultureInvariant)]
    private static partial Regex UsernamePattern();
}

public sealed record NormalizedUserCredentials(string Username, string Email, string Password);
