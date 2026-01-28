using Follow.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace Follow.Infrastructure.Data;

public class FollowDbContext : DbContext
{
    public FollowDbContext(DbContextOptions<FollowDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Track> Tracks => Set<Track>();
    public DbSet<Artist> Artists => Set<Artist>();
    public DbSet<Album> Albums => Set<Album>();
    public DbSet<Playlist> Playlists => Set<Playlist>();
    public DbSet<PlaylistTrack> PlaylistTracks => Set<PlaylistTrack>();
    public DbSet<PlayHistory> PlayHistories => Set<PlayHistory>();
    public DbSet<Favorite> Favorites => Set<Favorite>();
    public DbSet<RssSubscription> RssSubscriptions => Set<RssSubscription>();
    public DbSet<RssEpisode> RssEpisodes => Set<RssEpisode>();
    public DbSet<Tag> Tags => Set<Tag>();
    public DbSet<TrackTag> TrackTags => Set<TrackTag>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(e => e.Username).IsUnique();
            entity.HasIndex(e => e.Email).IsUnique();
            entity.Property(e => e.Role).HasConversion<string>();
        });

        // Track
        modelBuilder.Entity<Track>(entity =>
        {
            entity.HasOne(e => e.Artist)
                .WithMany(a => a.Tracks)
                .HasForeignKey(e => e.ArtistId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(e => e.Album)
                .WithMany(a => a.Tracks)
                .HasForeignKey(e => e.AlbumId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Album
        modelBuilder.Entity<Album>(entity =>
        {
            entity.HasOne(e => e.Artist)
                .WithMany(a => a.Albums)
                .HasForeignKey(e => e.ArtistId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Playlist
        modelBuilder.Entity<Playlist>(entity =>
        {
            entity.HasOne(e => e.User)
                .WithMany(u => u.Playlists)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // PlaylistTrack
        modelBuilder.Entity<PlaylistTrack>(entity =>
        {
            entity.HasOne(e => e.Playlist)
                .WithMany(p => p.PlaylistTracks)
                .HasForeignKey(e => e.PlaylistId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Track)
                .WithMany(t => t.PlaylistTracks)
                .HasForeignKey(e => e.TrackId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.PlaylistId, e.TrackId }).IsUnique();
        });

        // PlayHistory
        modelBuilder.Entity<PlayHistory>(entity =>
        {
            entity.HasOne(e => e.User)
                .WithMany(u => u.PlayHistories)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Track)
                .WithMany(t => t.PlayHistories)
                .HasForeignKey(e => e.TrackId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Favorite
        modelBuilder.Entity<Favorite>(entity =>
        {
            entity.HasOne(e => e.User)
                .WithMany(u => u.Favorites)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Track)
                .WithMany(t => t.Favorites)
                .HasForeignKey(e => e.TrackId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.UserId, e.TrackId }).IsUnique();
        });

        // RssSubscription
        modelBuilder.Entity<RssSubscription>(entity =>
        {
            entity.HasOne(e => e.User)
                .WithMany(u => u.RssSubscriptions)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // RssEpisode
        modelBuilder.Entity<RssEpisode>(entity =>
        {
            entity.HasOne(e => e.Subscription)
                .WithMany(s => s.Episodes)
                .HasForeignKey(e => e.SubscriptionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Tag
        modelBuilder.Entity<Tag>(entity =>
        {
            entity.HasIndex(e => e.Name).IsUnique();
        });

        // TrackTag
        modelBuilder.Entity<TrackTag>(entity =>
        {
            entity.HasOne(e => e.Track)
                .WithMany(t => t.TrackTags)
                .HasForeignKey(e => e.TrackId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Tag)
                .WithMany(t => t.TrackTags)
                .HasForeignKey(e => e.TagId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.TrackId, e.TagId }).IsUnique();
        });
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = DateTime.UtcNow;
            }
        }
        return base.SaveChangesAsync(cancellationToken);
    }
}
