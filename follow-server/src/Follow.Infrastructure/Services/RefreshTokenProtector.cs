using System.Security.Cryptography;

namespace Follow.Infrastructure.Services;

public sealed class RefreshTokenProtector
{
    private const int SecretSize = 32;

    public IssuedRefreshToken Issue(Guid sessionId)
    {
        var secret = RandomNumberGenerator.GetBytes(SecretSize);
        var encodedSecret = Convert.ToBase64String(secret)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

        return new IssuedRefreshToken(
            $"{sessionId:N}.{encodedSecret}",
            SHA256.HashData(secret));
    }

    public bool TryRead(string? token, out Guid sessionId, out byte[] hash)
    {
        sessionId = Guid.Empty;
        hash = [];
        if (string.IsNullOrWhiteSpace(token)) return false;

        var parts = token.Split('.', 2, StringSplitOptions.None);
        if (parts.Length != 2 || !Guid.TryParseExact(parts[0], "N", out sessionId))
        {
            return false;
        }

        try
        {
            var encoded = parts[1].Replace('-', '+').Replace('_', '/');
            encoded = encoded.PadRight(encoded.Length + ((4 - encoded.Length % 4) % 4), '=');
            var secret = Convert.FromBase64String(encoded);
            if (secret.Length != SecretSize) return false;
            hash = SHA256.HashData(secret);
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    public static bool Matches(byte[] expected, byte[] actual) =>
        expected.Length == actual.Length &&
        CryptographicOperations.FixedTimeEquals(expected, actual);
}

public sealed record IssuedRefreshToken(string Token, byte[] Hash);
