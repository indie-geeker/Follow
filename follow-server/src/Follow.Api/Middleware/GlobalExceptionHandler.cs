using System.Net;
using Follow.Shared.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace Follow.Api.Middleware;

public class GlobalExceptionHandler : IMiddleware
{
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
    {
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unhandled exception occurred.");
            await HandleExceptionAsync(context, ex);
        }
    }

    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, errorCode, message) = exception switch
        {
            UnauthorizedAccessException => (StatusCodes.Status200OK, 1, exception.Message), // Keeping 200 OK for consistency with login endpoint, but returning error code 1
            InvalidOperationException => (StatusCodes.Status200OK, 1, exception.Message),
            ArgumentException => (StatusCodes.Status200OK, 1, exception.Message),
            _ => (StatusCodes.Status500InternalServerError, 500, "An unexpected error occurred.")
        };

        // If it's a 500 error, we might want to hide the details in production
        // For now, using a generic message for 500s.

        context.Response.StatusCode = statusCode;

        var response = ApiResponse.Error(errorCode, message);
        
        await context.Response.WriteAsJsonAsync(response);
    }
}
