namespace Follow.Api.Tests;

public class RssRemovalContractTests
{
    [Fact]
    public void CurrentServerSurface_DoesNotExposeRss()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));

        AssertSourceDoesNotContain(serverRoot, "src/Follow.Api/Program.cs", "Rss");
        AssertSourceDoesNotContain(serverRoot, "src/Follow.Infrastructure/Data/FollowDbContext.cs", "Rss");
        AssertSourceDoesNotContain(serverRoot, "src/Follow.Core/Entities/User.cs", "Rss");

        Assert.False(File.Exists(Path.Combine(serverRoot, "src/Follow.Api/Endpoints/RssEndpoints.cs")));
        Assert.False(File.Exists(Path.Combine(serverRoot, "src/Follow.Core/Interfaces/IRssService.cs")));
        Assert.False(File.Exists(Path.Combine(serverRoot, "src/Follow.Infrastructure/Services/RssService.cs")));
        Assert.False(File.Exists(Path.Combine(serverRoot, "src/Follow.Core/Entities/RssSubscription.cs")));
        Assert.False(File.Exists(Path.Combine(serverRoot, "src/Follow.Core/Entities/RssEpisode.cs")));
    }

    private static void AssertSourceDoesNotContain(
        string serverRoot,
        string relativePath,
        string text)
    {
        var source = File.ReadAllText(Path.Combine(serverRoot, relativePath));
        Assert.DoesNotContain(text, source, StringComparison.OrdinalIgnoreCase);
    }
}
