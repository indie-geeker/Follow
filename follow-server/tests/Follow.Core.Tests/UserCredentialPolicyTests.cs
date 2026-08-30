using Follow.Core.Services;

namespace Follow.Core.Tests;

public class UserCredentialPolicyTests
{
    [Fact]
    public void NormalizeAndValidate_CanonicalizesUsernameAndEmail()
    {
        var result = UserCredentialPolicy.NormalizeAndValidate(
            "  Ａdmin.User  ",
            "  Admin@Example.COM ",
            "StrongPassword!2026");

        Assert.Equal("admin.user", result.Username);
        Assert.Equal("admin@example.com", result.Email);
        Assert.Equal("StrongPassword!2026", result.Password);
    }

    [Fact]
    public void NormalizeAndValidate_AcceptsPasswordAtMinimumLength()
    {
        var result = UserCredentialPolicy.NormalizeAndValidate(
            "member",
            "member@example.com",
            "Aa1!bc");

        Assert.Equal("Aa1!bc", result.Password);
    }

    [Theory]
    [InlineData("ab")]
    [InlineData(" user name ")]
    [InlineData("_admin")]
    [InlineData("admin_")]
    [InlineData("admin@name")]
    [InlineData("abcdefghijklmnopqrstuvwxyz1234567")]
    public void NormalizeAndValidate_RejectsInvalidUsername(string username)
    {
        Assert.Throws<ArgumentException>(() => UserCredentialPolicy.NormalizeAndValidate(
            username,
            "member@example.com",
            "StrongPassword!2026"));
    }

    [Theory]
    [InlineData("Aa1!b")]
    [InlineData("lowercaseonly!2026")]
    [InlineData("UPPERCASEONLY!2026")]
    [InlineData("NoDigitsHere!Pass")]
    [InlineData("NoSpecialHere2026")]
    [InlineData("Has WhiteSpace!2026")]
    public void NormalizeAndValidate_RejectsWeakPassword(string password)
    {
        Assert.Throws<ArgumentException>(() => UserCredentialPolicy.NormalizeAndValidate(
            "member",
            "member@example.com",
            password));
    }

    [Theory]
    [InlineData("not-an-email")]
    [InlineData("name@")]
    [InlineData("@example.com")]
    public void NormalizeAndValidate_RejectsInvalidEmail(string email)
    {
        Assert.Throws<ArgumentException>(() => UserCredentialPolicy.NormalizeAndValidate(
            "member",
            email,
            "StrongPassword!2026"));
    }
}
