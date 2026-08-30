using Follow.Shared.DTOs;

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
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            _logger.LogDebug("Request was cancelled by the client.");
        }
        catch (Exception ex)
        {
            if (context.Response.HasStarted)
            {
                _logger.LogError(
                    ex,
                    "An unhandled exception occurred after the response started.");
                throw;
            }

            if (ex is ArgumentException or UnauthorizedAccessException or InvalidOperationException)
                _logger.LogWarning("Request rejected: {Message}", ex.Message);
            else
                _logger.LogError(ex, "An unhandled exception occurred.");
            context.Response.Clear();
            await HandleExceptionAsync(context, ex);
        }
    }

    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, errorCode, message) = exception switch
        {
            UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, 401, exception.Message),
            InvalidOperationException => (StatusCodes.Status409Conflict, 409, exception.Message),
            ArgumentException => (StatusCodes.Status400BadRequest, 400, exception.Message),
            _ => (StatusCodes.Status500InternalServerError, 500, "An unexpected error occurred.")
        };

        context.Response.StatusCode = statusCode;

        var response = ApiResponse.Error(errorCode, message);
        
        await context.Response.WriteAsJsonAsync(response);
    }
}
