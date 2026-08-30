namespace Follow.Core.Services;

public static class PaginationPolicy
{
    public const int MaximumPageSize = 100;

    public static void Validate(int page, int pageSize)
    {
        if (page < 1)
            throw new ArgumentException("page 必须大于或等于 1", nameof(page));
        ValidateLimit(pageSize, nameof(pageSize));
    }

    public static int GetOffset(int page, int pageSize)
    {
        Validate(page, pageSize);
        var offset = ((long)page - 1) * pageSize;
        if (offset > int.MaxValue)
            throw new ArgumentException("page 超出可查询范围", nameof(page));
        return (int)offset;
    }

    public static void ValidateLimit(int limit, string parameterName = "limit")
    {
        if (limit < 1 || limit > MaximumPageSize)
        {
            throw new ArgumentException(
                $"{parameterName} 必须在 1 到 {MaximumPageSize} 之间",
                parameterName);
        }
    }
}
