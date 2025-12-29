namespace Follow.Core.Interfaces;

/// <summary>
/// Interface for password hashing
/// </summary>
public interface IPasswordHasher
{
    string HashPassword(string password);
    bool VerifyPassword(string password, string hashedPassword);
}
