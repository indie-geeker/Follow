using Follow.Core.Services;

namespace Follow.Core.Tests;

public class MusicImportPathPolicyTests
{
    [Fact]
    public void Resolve_EmptyRelativePath_SelectsConfiguredRoot()
    {
        var sourceRoot = CreateTemporaryDirectory();
        try
        {
            var resolved = MusicImportPathPolicy.Resolve(sourceRoot, string.Empty);

            Assert.Equal(Path.GetFullPath(sourceRoot), resolved.FullPath);
            Assert.Equal(string.Empty, resolved.RelativePath);
        }
        finally
        {
            Directory.Delete(sourceRoot, recursive: true);
        }
    }

    [Fact]
    public void Resolve_NormalizesSafeNestedPathForStorage()
    {
        var sourceRoot = CreateTemporaryDirectory();
        try
        {
            var resolved = MusicImportPathPolicy.Resolve(
                sourceRoot,
                "Artist//Album/./song.wav");

            Assert.Equal("Artist/Album/song.wav", resolved.RelativePath);
            Assert.Equal(
                Path.Combine(sourceRoot, "Artist", "Album", "song.wav"),
                resolved.FullPath);
        }
        finally
        {
            Directory.Delete(sourceRoot, recursive: true);
        }
    }

    [Theory]
    [InlineData("/etc/passwd")]
    [InlineData("../library-copy/song.mp3")]
    [InlineData("Artist/../song.mp3")]
    [InlineData("Artist\\song.mp3")]
    [InlineData("Artist/song\u0000.mp3")]
    public void Resolve_RejectsUnsafeRelativePath(string relativePath)
    {
        var sourceRoot = CreateTemporaryDirectory();
        try
        {
            Assert.Throws<ArgumentException>(() =>
                MusicImportPathPolicy.Resolve(sourceRoot, relativePath));
        }
        finally
        {
            Directory.Delete(sourceRoot, recursive: true);
        }
    }

    [Fact]
    public void Resolve_RejectsPathLongerThanConfiguredMaximum()
    {
        var sourceRoot = CreateTemporaryDirectory();
        try
        {
            Assert.Throws<ArgumentException>(() =>
                MusicImportPathPolicy.Resolve(
                    sourceRoot,
                    "123456.wav",
                    maximumRelativePathLength: 8));
        }
        finally
        {
            Directory.Delete(sourceRoot, recursive: true);
        }
    }

    [Fact]
    public void IsReparsePoint_IdentifiesSymbolicLink()
    {
        var sourceRoot = CreateTemporaryDirectory();
        try
        {
            var targetPath = Path.Combine(sourceRoot, "target.wav");
            File.WriteAllBytes(targetPath, [1, 2, 3]);
            var linkPath = Path.Combine(sourceRoot, "link.wav");
            File.CreateSymbolicLink(linkPath, targetPath);

            Assert.True(MusicImportPathPolicy.IsReparsePoint(new FileInfo(linkPath)));
            Assert.False(MusicImportPathPolicy.IsReparsePoint(new FileInfo(targetPath)));
        }
        finally
        {
            Directory.Delete(sourceRoot, recursive: true);
        }
    }

    private static string CreateTemporaryDirectory()
    {
        var path = Path.Combine(
            Path.GetTempPath(),
            $"follow-import-policy-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        return path;
    }
}
