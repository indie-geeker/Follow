using Follow.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Follow.Api;

public sealed class DesignTimeFollowDbContextFactory
    : IDesignTimeDbContextFactory<FollowDbContext>
{
    public FollowDbContext CreateDbContext(string[] args)
    {
        // Migration scaffolding only needs a provider; it never opens this connection.
        var options = new DbContextOptionsBuilder<FollowDbContext>()
            .UseNpgsql(
                "Host=127.0.0.1;Database=follow_design;Username=unused;Password=unused")
            .Options;
        return new FollowDbContext(options);
    }
}
