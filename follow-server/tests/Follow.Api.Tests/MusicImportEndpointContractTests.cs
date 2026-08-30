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
        builder.Services.AddSingleton(new MusicImportRuntimeSettings());
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
            "GET /api/admin/music-imports",
            "GET /api/admin/music-imports/capabilities",
            "GET /api/admin/music-imports/{id:guid}",
            "GET /api/admin/music-imports/{id:guid}/items",
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
        Assert.DoesNotContain("SourceRoot", batchProperties);
        Assert.DoesNotContain("FullPath", itemProperties);
        Assert.DoesNotContain("SourceRoot", capabilityProperties);
    }

    [Fact]
    public void JsonContract_UsesCamelCaseFieldsAndLowerCamelStatusValues()
    {
        var dto = new MusicImportBatchDto(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "request",
            "relative/folder",
            false,
            "completedWithErrors",
            1,
            0,
            10,
            new MusicImportProgressDto(0, 0, 0, 0, 0, 1, 1, 0, 10),
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
        Assert.Contains("\"retryableFailed\":1", json);
        Assert.DoesNotContain("sourceRoot", json, StringComparison.OrdinalIgnoreCase);
    }
}
