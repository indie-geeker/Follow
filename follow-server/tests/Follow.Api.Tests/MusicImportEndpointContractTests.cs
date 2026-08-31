using System.Text.Json;
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

public class MusicImportEndpointContractTests
{
    [Fact]
    public void Routes_AreCompleteAndProtectedByAdminOnly()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddAuthorization();
        builder.Services.AddSingleton<IMusicImportService>(_ => null!);
        builder.Services.AddSingleton<IMusicImportPreviewService>(_ => null!);
        builder.Services.AddSingleton<IMusicImportReviewService>(_ => null!);
        builder.Services.AddSingleton(new MusicImportRuntimeSettings());
        builder.Services.AddSingleton(new AudioFingerprintCapabilityState());
        var app = builder.Build();

        app.MapMusicImportEndpoints();

        var endpoints = ((IEndpointRouteBuilder)app).DataSources
            .SelectMany(source => source.Endpoints)
            .OfType<RouteEndpoint>()
            .ToArray();
        var contracts = endpoints
            .SelectMany(endpoint => endpoint.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods
                .Select(method => $"{method} {endpoint.RoutePattern.RawText}"))
            .ToHashSet(StringComparer.Ordinal);
        var expected = new[]
        {
            "POST /api/admin/music-imports",
            "POST /api/admin/music-imports/uploads",
            "GET /api/admin/music-imports",
            "GET /api/admin/music-imports/capabilities",
            "GET /api/admin/music-imports/{id:guid}",
            "GET /api/admin/music-imports/{id:guid}/items",
            "GET /api/admin/music-imports/items/{itemId:guid}/preview",
            "HEAD /api/admin/music-imports/items/{itemId:guid}/preview",
            "GET /api/admin/music-imports/{id:guid}/review-groups",
            "GET /api/admin/music-imports/review-groups/{groupId:guid}",
            "PUT /api/admin/music-imports/review-groups/{groupId:guid}/decision",
            "POST /api/admin/music-imports/{id:guid}/apply",
            "POST /api/admin/music-imports/{id:guid}/start",
            "POST /api/admin/music-imports/{id:guid}/pause",
            "POST /api/admin/music-imports/{id:guid}/resume",
            "POST /api/admin/music-imports/{id:guid}/cancel",
            "POST /api/admin/music-imports/{id:guid}/retry-failures"
        };

        Assert.Equal(expected.Order(), contracts.Order());
        Assert.All(endpoints, endpoint => Assert.Contains(
            endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>(),
            authorization => authorization.Policy == Policies.AdminOnly));
    }

    [Fact]
    public void ResponseContracts_ExposeRelativeAuditDataAndRetryableCountOnly()
    {
        var batchProperties = typeof(MusicImportBatchDto).GetProperties()
            .Select(property => property.Name)
            .ToArray();
        var itemProperties = typeof(MusicImportItemDto).GetProperties()
            .Select(property => property.Name)
            .ToArray();
        var capabilityProperties = typeof(MusicImportCapabilitiesDto).GetProperties()
            .Select(property => property.Name)
            .ToArray();

        Assert.Contains(nameof(MusicImportBatchDto.RelativeDirectory), batchProperties);
        Assert.Contains(nameof(MusicImportItemDto.RelativePath), itemProperties);
        Assert.Contains(nameof(MusicImportProgressDto.RetryableFailed),
            typeof(MusicImportProgressDto).GetProperties().Select(property => property.Name));
        Assert.Contains(nameof(MusicImportProgressDto.Phases),
            typeof(MusicImportProgressDto).GetProperties().Select(property => property.Name));
        Assert.Contains(nameof(MusicImportCapabilitiesDto.CanIngest), capabilityProperties);
        Assert.Contains(nameof(MusicImportCapabilitiesDto.FingerprintAvailable), capabilityProperties);
        Assert.Contains(nameof(MusicImportCapabilitiesDto.FingerprintVersion), capabilityProperties);
        Assert.Contains(nameof(MusicImportCapabilitiesDto.FingerprintErrorCode), capabilityProperties);
        Assert.DoesNotContain("SourceRoot", batchProperties);
        Assert.DoesNotContain("FullPath", itemProperties);
        Assert.DoesNotContain("SourceRoot", capabilityProperties);
        Assert.DoesNotContain("StorageEndpoint", capabilityProperties);
        Assert.DoesNotContain("AccessKey", capabilityProperties);
        Assert.DoesNotContain("SecretKey", capabilityProperties);
    }

    [Fact]
    public void ReviewContracts_ExposeManualReviewFactsWithoutRecommendationAcceptanceFlag()
    {
        var pageProperties = typeof(MusicImportReviewBatchDto).GetProperties()
            .Select(property => property.Name)
            .ToArray();
        var groupProperties = typeof(MusicImportReviewGroupDto).GetProperties()
            .Select(property => property.Name)
            .ToArray();
        var candidateProperties = typeof(MusicImportReviewCandidateDto).GetProperties()
            .Select(property => property.Name)
            .ToArray();

        Assert.Contains(nameof(MusicImportReviewBatchDto.TotalCount), pageProperties);
        Assert.Contains(nameof(MusicImportReviewBatchDto.Page), pageProperties);
        Assert.Contains(nameof(MusicImportReviewBatchDto.PageSize), pageProperties);
        Assert.Contains(nameof(MusicImportReviewBatchDto.TotalPages), pageProperties);
        Assert.Contains(nameof(MusicImportReviewBatchDto.Summary), pageProperties);
        Assert.Contains(nameof(MusicImportReviewGroupDto.MatchExplanation), groupProperties);
        Assert.Contains(nameof(MusicImportReviewGroupDto.DecisionKind), groupProperties);
        Assert.Contains(nameof(MusicImportReviewGroupDto.SelectedItemIds), groupProperties);
        Assert.Contains(nameof(MusicImportReviewGroupDto.ApplyErrorCode), groupProperties);
        Assert.Contains(nameof(MusicImportReviewGroupDto.CleanupStatus), groupProperties);
        Assert.Contains(nameof(MusicImportReviewGroupDto.CleanupErrorCode), groupProperties);
        Assert.Contains(nameof(MusicImportReviewCandidateDto.SourceLabel), candidateProperties);
        Assert.Contains(nameof(MusicImportReviewCandidateDto.PreviewAvailable), candidateProperties);
        Assert.Contains(nameof(MusicImportReviewCandidateDto.Version), candidateProperties);

        var recommendationBooleans = new[]
        {
            typeof(MusicImportReviewBatchDto),
            typeof(MusicImportReviewGroupDto),
            typeof(MusicImportReviewCandidateDto)
        }
            .SelectMany(type => type.GetProperties())
            .Where(property => property.PropertyType == typeof(bool))
            .Where(property => property.Name.Contains("Recommendation", StringComparison.OrdinalIgnoreCase) ||
                property.Name.Contains("Accepted", StringComparison.OrdinalIgnoreCase) ||
                property.Name.Contains("Approved", StringComparison.OrdinalIgnoreCase) ||
                property.Name.Contains("Selected", StringComparison.OrdinalIgnoreCase))
            .ToArray();

        Assert.Empty(recommendationBooleans);
        Assert.DoesNotContain("SourceReference", candidateProperties);
        Assert.DoesNotContain("StagingObjectPath", candidateProperties);
        Assert.DoesNotContain("FullPath", candidateProperties);
    }

    [Fact]
    public void JsonContract_UsesCamelCaseFieldsAndLowerCamelStatusValues()
    {
        var dto = new MusicImportBatchDto(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "request",
            "relative/folder",
            "mountedDirectory",
            false,
            "completedWithErrors",
            1,
            0,
            10,
            new MusicImportProgressDto(
                0,
                0,
                0,
                0,
                0,
                1,
                1,
                0,
                10,
                new MusicImportPhaseProgressDto(0, 0, 0, 0, 0, 0, 0, 0, 0)),
            "FAILED_ITEMS",
            "Some items failed.",
            DateTime.UtcNow,
            DateTime.UtcNow,
            DateTime.UtcNow,
            DateTime.UtcNow,
            DateTime.UtcNow,
            DateTime.UtcNow);

        var json = JsonSerializer.Serialize(dto, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.Contains("\"status\":\"completedWithErrors\"", json);
        Assert.Contains("\"sourceKind\":\"mountedDirectory\"", json);
        Assert.Contains("\"retryableFailed\":1", json);
        Assert.DoesNotContain("sourceRoot", json, StringComparison.OrdinalIgnoreCase);
    }
}
