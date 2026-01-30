namespace Follow.Shared.DTOs;

/// <summary>
/// Standard API response wrapper for consistent response format
/// </summary>
/// <typeparam name="T">The type of data being returned</typeparam>
public record ApiResponse<T>
{
    /// <summary>
    /// Response code: 0 for success, non-zero for errors
    /// </summary>
    public int Code { get; init; }
    
    /// <summary>
    /// Human-readable message
    /// </summary>
    public string Message { get; init; } = string.Empty;
    
    /// <summary>
    /// Response data (null for errors)
    /// </summary>
    public T? Data { get; init; }
    
    /// <summary>
    /// Creates a success response
    /// </summary>
    public static ApiResponse<T> Success(T data, string message = "Success")
        => new() { Code = 0, Message = message, Data = data };
    
    /// <summary>
    /// Creates an error response
    /// </summary>
    public static ApiResponse<T> Error(int code, string message)
        => new() { Code = code, Message = message, Data = default };
}

/// <summary>
/// Non-generic API response for operations without data
/// </summary>
public record ApiResponse
{
    public int Code { get; init; }
    public string Message { get; init; } = string.Empty;
    public object? Data { get; init; }
    
    public static ApiResponse Success(string message = "Success")
        => new() { Code = 0, Message = message, Data = null };
    
    public static ApiResponse Error(int code, string message)
        => new() { Code = code, Message = message, Data = null };
}
