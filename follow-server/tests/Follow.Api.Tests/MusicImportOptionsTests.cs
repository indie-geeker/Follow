using Follow.Api.Configuration;

namespace Follow.Api.Tests;

public class MusicImportOptionsTests
{
    [Fact]
    public void DisabledDefaults_DoNotRequireAHostSourcePath()
    {
        var settings = new MusicImportOptions().ToRuntimeSettings();

        Assert.False(settings.Enabled);
        Assert.Equal(string.Empty, settings.SourceRoot);
    }

    [Theory]
    [InlineData("bad/alias")]
    [InlineData("bad\\alias")]
    [InlineData("bad\nalias")]
    public void SourceAlias_RejectsPathSeparatorsAndControlCharacters(string alias)
    {
        var options = new MusicImportOptions { SourceAlias = alias };

        Assert.Throws<InvalidOperationException>(() => options.ToRuntimeSettings());
    }

    [Fact]
    public void SourceAlias_IsBoundedTo128Characters()
    {
        var options = new MusicImportOptions { SourceAlias = new string('a', 129) };

        Assert.Throws<InvalidOperationException>(() => options.ToRuntimeSettings());
    }

    [Fact]
    public void EnabledSourceRoot_CannotBeTheFilesystemRoot()
    {
        var options = new MusicImportOptions
        {
            Enabled = true,
            SourceRoot = Path.GetPathRoot(Path.GetFullPath("/"))!
        };

        Assert.Throws<InvalidOperationException>(() => options.ToRuntimeSettings());
    }

    [Fact]
    public void EnabledOverlayPath_IsValidatedWithoutRequiringHostFilesystemAccess()
    {
        var options = new MusicImportOptions
        {
            Enabled = true,
            SourceRoot = "/imports/library",
            SourceAlias = "只读音乐库"
        };

        var settings = options.ToRuntimeSettings();

        Assert.True(settings.Enabled);
        Assert.Equal("/imports/library", settings.SourceRoot);
        Assert.Equal("只读音乐库", settings.SourceAlias);
    }
}
