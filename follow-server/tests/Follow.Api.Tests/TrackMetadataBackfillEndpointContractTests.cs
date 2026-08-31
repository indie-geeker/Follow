using Follow.Api.Endpoints;
using Follow.Core.Interfaces;
using Follow.Infrastructure.Services;
using Follow.Shared.Constants;
using Follow.Shared.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Follow.Api.Tests;

public sealed class TrackMetadataBackfillEndpointContractTests
{
    [Fact]
    public void Route_IsPostOnlyAndProtectedByAdminPolicy()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddAuthorization();
        builder.Services.AddSingleton<IAdminService>(_ => null!);
        builder.Services.AddSingleton<TrackMetadataBackfillService>(_ => null!);
        var app = builder.Build();

        app.MapAdminEndpoints();

        var endpoint = ((IEndpointRouteBuilder)app).DataSources
            .SelectMany(source => source.Endpoints)
            .OfType<RouteEndpoint>()
            .Single(candidate => candidate.RoutePattern.RawText ==
                "/api/admin/tracks/metadata-backfill");
        Assert.Equal(
            [HttpMethods.Post],
            endpoint.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods);
        Assert.Contains(
            endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>(),
            authorization => authorization.Policy == Policies.AdminOnly);
    }

    [Fact]
    public void DtosExposeBoundsAndAuditCountsWithoutEmbeddedContent()
    {
        var request = new TrackMetadataBackfillRequest(true);
        Assert.True(request.DryRun);
        Assert.Null(request.AfterId);
        Assert.Equal(50, request.Limit);

        var responseProperties = typeof(TrackMetadataBackfillResponse)
            .GetProperties()
            .Select(property => property.Name)
            .ToArray();
        var entryProperties = typeof(TrackMetadataBackfillEntryDto)
            .GetProperties()
            .Select(property => property.Name)
            .ToArray();
        Assert.Contains(nameof(TrackMetadataBackfillResponse.CandidateCount), responseProperties);
        Assert.Contains(nameof(TrackMetadataBackfillResponse.FailedCount), responseProperties);
        Assert.Contains(nameof(TrackMetadataBackfillResponse.NextAfterId), responseProperties);
        Assert.DoesNotContain("CoverData", entryProperties);
        Assert.DoesNotContain("TimedLyrics", entryProperties);
    }

    [Fact]
    public void EndpointDelegatesToTheBoundedServiceWithoutStartupInvocation()
    {
        var serverRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "../../../../../"));
        var endpointSource = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/Endpoints/AdminEndpoints.cs"));
        var programSource = File.ReadAllText(Path.Combine(
            serverRoot,
            "src/Follow.Api/Program.cs"));

        Assert.Contains("backfillService.RunAsync", endpointSource);
        Assert.DoesNotContain("RunMetadataBackfill", programSource);
    }
}
