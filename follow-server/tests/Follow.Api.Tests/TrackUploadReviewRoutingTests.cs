using System.Security.Claims;
using System.Security.Cryptography;
using Follow.Api.Endpoints;
using Follow.Core.Entities;
using Follow.Core.Interfaces;
using Follow.Core.Models;
using Follow.Infrastructure.Data;
using Follow.Infrastructure.Services;
using Follow.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Follow.Api.Tests;

public class TrackUploadReviewRoutingTests
{
    [Fact]
    public async Task OrdinaryAdminUpload_Returns202StagingReviewWithoutCreatingTrack()
    {
        using var source = new MemoryStream([1, 2, 3, 4]);
        var file = new FormFile(source, 0, source.Length, "file", "song.mp3")
        {
            Headers = new HeaderDictionary(),
            ContentType = "audio/mpeg"
        };
        await using var context = CreateContext();
        var settings = MusicImportScannerTests.EnabledSettings(Path.GetTempPath());
        var storage = new RoutingStorage();
        var service = new MusicImportService(context, settings, storage);
        var capability = AvailableCapability();
        var principal = AdminPrincipal(Guid.NewGuid());

        var result = await TrackEndpoints.UploadTrack(
            file,
            "ordinary-upload",
            principal,
            service,
            settings,
            capability,
            CancellationToken.None);
        var http = ResultContext();
        await result.ExecuteAsync(http);

        Assert.Equal(StatusCodes.Status202Accepted, http.Response.StatusCode);
        Assert.Single(await context.MusicImportBatches.ToListAsync());
        var item = await context.MusicImportItems.SingleAsync();
        Assert.StartsWith("tracks/staging/", item.SourceReference);
        Assert.Empty(await context.Tracks.ToListAsync());
        Assert.Single(storage.Objects);
        Assert.All(storage.Objects.Keys, key => Assert.StartsWith("tracks/staging/", key));
    }

    [Fact]
    public async Task OrdinaryUpload_FailsClosedWhenFingerprintRuntimeUnavailable()
    {
        using var source = new MemoryStream([1, 2, 3, 4]);
        var file = new FormFile(source, 0, source.Length, "file", "song.mp3");
        await using var context = CreateContext();
        var settings = MusicImportScannerTests.EnabledSettings(Path.GetTempPath());
        var storage = new RoutingStorage();
        var service = new MusicImportService(context, settings, storage);
        var capability = new AudioFingerprintCapabilityState();

        var result = await TrackEndpoints.UploadTrack(
            file,
            "unavailable",
            AdminPrincipal(Guid.NewGuid()),
            service,
            settings,
            capability,
            CancellationToken.None);
        var http = ResultContext();
        await result.ExecuteAsync(http);

        Assert.Equal(StatusCodes.Status503ServiceUnavailable, http.Response.StatusCode);
        Assert.Empty(await context.MusicImportBatches.ToListAsync());
        Assert.Empty(storage.Objects);
    }

    [Fact]
    public void OrdinaryUploadRoute_RemainsAdminOnlyAndHasNoTrackCreationServiceParameter()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddAuthorization();
        builder.Services.AddSingleton<ITrackService>(_ => null!);
        builder.Services.AddSingleton<IMusicImportService>(_ => null!);
        builder.Services.AddSingleton<IStorageService>(_ => null!);
        builder.Services.AddSingleton(new MusicImportRuntimeSettings());
        builder.Services.AddSingleton(new AudioFingerprintCapabilityState());
        var app = builder.Build();
        app.MapTrackEndpoints();

        var endpoint = ((IEndpointRouteBuilder)app).DataSources
            .SelectMany(source => source.Endpoints)
            .OfType<RouteEndpoint>()
            .Single(candidate => candidate.RoutePattern.RawText == "/api/tracks/upload");

        Assert.Contains(
            endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>(),
            authorization => authorization.Policy == Policies.AdminOnly);
        var serverRoot = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../"));
        var endpointSource = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/Endpoints/TrackEndpoints.cs"));
        Assert.DoesNotContain("UploadTrackAsync", endpointSource);
    }

    private static AudioFingerprintCapabilityState AvailableCapability()
    {
        var state = new AudioFingerprintCapabilityState();
        state.Update(new AudioFingerprintCapability(true, "1.6.1", 2, null, null));
        return state;
    }

    private static DefaultHttpContext ResultContext()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.ConfigureHttpJsonOptions(_ => { });
        var context = new DefaultHttpContext
        {
            RequestServices = services.BuildServiceProvider()
        };
        context.Response.Body = new MemoryStream();
        return context;
    }

    private static ClaimsPrincipal AdminPrincipal(Guid userId) => new(
        new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Role, UserRole.Admin.ToString())
        ], "test"));

    private static FollowDbContext CreateContext() => new(
        new DbContextOptionsBuilder<FollowDbContext>()
            .UseInMemoryDatabase($"track-routing-{Guid.NewGuid():N}")
            .Options);

    private sealed class RoutingStorage : IStorageService
    {
        public Dictionary<string, byte[]> Objects { get; } = new(StringComparer.Ordinal);

        public async Task WriteObjectAsync(string objectPath, Stream source, long length, string contentType, CancellationToken cancellationToken = default)
        {
            using var buffer = new MemoryStream();
            await source.CopyToAsync(buffer, cancellationToken);
            Objects[objectPath] = buffer.ToArray();
        }

        public Task<StorageObjectMetadata?> GetObjectMetadataAsync(string filePath, CancellationToken cancellationToken = default) =>
            Task.FromResult(Objects.TryGetValue(filePath, out var bytes)
                ? new StorageObjectMetadata(
                    bytes.LongLength,
                    "audio/mpeg",
                    Convert.ToHexString(SHA256.HashData(bytes)))
                : null);

        public Task CopyRangeToAsync(string filePath, long offset, long length, Stream destination, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<bool> DeleteFileAsync(string filePath) => Task.FromResult(Objects.Remove(filePath));
        public Task<string> UploadFileAsync(Stream fileStream, string fileName, string contentType, string? folder = null) => throw new InvalidOperationException("Immediate Track upload is forbidden.");
    }
}
