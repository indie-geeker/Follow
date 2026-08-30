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
    public DbSet<Tag> Tags => Set<Tag>();
    public DbSet<TrackTag> TrackTags => Set<TrackTag>();
    public DbSet<UserSession> UserSessions => Set<UserSession>();
    public DbSet<StorageDeletionJob> StorageDeletionJobs => Set<StorageDeletionJob>();
    public DbSet<MusicImportBatch> MusicImportBatches => Set<MusicImportBatch>();
    public DbSet<MusicImportItem> MusicImportItems => Set<MusicImportItem>();

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

        modelBuilder.Entity<UserSession>(entity =>
        {
            entity.HasOne(e => e.User)
                .WithMany(u => u.Sessions)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.Property(e => e.RefreshTokenHash).HasMaxLength(32);
            entity.Property(e => e.PreviousRefreshTokenHash).HasMaxLength(32);
            entity.Property(e => e.DeviceName).HasMaxLength(64);
            entity.Property(e => e.ClientType).HasMaxLength(16);
            entity.Property(e => e.UserAgent).HasMaxLength(256);
            entity.Property(e => e.Version).IsConcurrencyToken();
            entity.HasIndex(e => e.RefreshTokenHash).IsUnique();
            entity.HasIndex(e => new { e.UserId, e.RevokedAt });
            entity.HasIndex(e => e.ExpiresAt);
        });

        modelBuilder.Entity<StorageDeletionJob>(entity =>
        {
            entity.Property(e => e.ObjectPath).HasMaxLength(1024);
            entity.Property(e => e.LastError).HasMaxLength(2048);
            entity.HasIndex(e => new { e.CompletedAt, e.NextAttemptAt });
        });

        modelBuilder.Entity<MusicImportBatch>(entity =>
        {
            entity.HasOne(e => e.RequestedByUser)
                .WithMany()
                .HasForeignKey(e => e.RequestedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.Property(e => e.ClientRequestId).HasMaxLength(64);
            entity.Property(e => e.RelativeDirectory).HasMaxLength(1024);
            entity.Property(e => e.Status).HasConversion<string>().HasMaxLength(32);
            entity.Property(e => e.LeaseOwner).HasMaxLength(128);
            entity.Property(e => e.LastErrorCode).HasMaxLength(64);
            entity.Property(e => e.LastError).HasMaxLength(2048);
            entity.Property(e => e.Version).IsConcurrencyToken();
            entity.HasIndex(e => new { e.RequestedByUserId, e.ClientRequestId })
                .IsUnique()
                .HasDatabaseName("UX_MusicImportBatches_RequestedByUser_ClientRequestId");
            entity.HasIndex(e => new { e.Status, e.LeaseExpiresAt });
        });

        modelBuilder.Entity<MusicImportItem>(entity =>
        {
            entity.HasOne(e => e.Batch)
                .WithMany(e => e.Items)
                .HasForeignKey(e => e.BatchId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Track)
                .WithMany()
                .HasForeignKey(e => e.TrackId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.Property(e => e.RelativePath).HasMaxLength(1024);
            entity.Property(e => e.OriginalFileName).HasMaxLength(512);
            entity.Property(e => e.Extension).HasMaxLength(16);
            entity.Property(e => e.ContentSha256).HasMaxLength(32);
            entity.Property(e => e.Status).HasConversion<string>().HasMaxLength(32);
            entity.Property(e => e.Stage).HasConversion<string>().HasMaxLength(32);
            entity.Property(e => e.LeaseOwner).HasMaxLength(128);
            entity.Property(e => e.ObjectPath).HasMaxLength(1024);
            entity.Property(e => e.ErrorCode).HasMaxLength(64);
            entity.Property(e => e.ErrorMessage).HasMaxLength(2048);
            entity.Property(e => e.Version).IsConcurrencyToken();
            entity.HasIndex(e => new { e.BatchId, e.RelativePath }).IsUnique();
            entity.HasIndex(e => new { e.BatchId, e.Status });
            entity.HasIndex(e => new { e.Status, e.NextAttemptAt, e.LeaseExpiresAt });
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

            entity.Property(e => e.ContentSha256).HasMaxLength(32);
            entity.Property(e => e.OriginalFileName).HasMaxLength(512);
            entity.HasIndex(e => e.ContentSha256)
                .IsUnique()
                .HasDatabaseName("UX_Tracks_ContentSha256")
                .HasFilter("\"ContentSha256\" IS NOT NULL");
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

    public override int SaveChanges()
    {
        UpdateAuditFields();
        return base.SaveChanges();
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        UpdateAuditFields();
        return base.SaveChangesAsync(cancellationToken);
    }

    internal async Task<bool> TryRenewMusicImportItemLeaseAsync(
        Guid itemId,
        string leaseOwner,
        DateTime now,
        DateTime leaseExpiresAt,
        CancellationToken cancellationToken)
    {
        if (Database.IsRelational())
        {
            return await MusicImportItems
                .Where(item => item.Id == itemId &&
                    item.Status == MusicImportItemStatus.Processing &&
                    item.LeaseOwner == leaseOwner &&
                    item.LeaseExpiresAt > now)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(item => item.LeaseExpiresAt, leaseExpiresAt)
                    .SetProperty(item => item.UpdatedAt, now),
                    cancellationToken) == 1;
        }

        var item = await MusicImportItems.SingleOrDefaultAsync(
            candidate => candidate.Id == itemId,
            cancellationToken);
        if (item == null ||
            item.Status != MusicImportItemStatus.Processing ||
            !string.Equals(item.LeaseOwner, leaseOwner, StringComparison.Ordinal) ||
            item.LeaseExpiresAt is not DateTime currentExpiry ||
            currentExpiry <= now)
        {
            return false;
        }

        item.LeaseExpiresAt = leaseExpiresAt;
        item.UpdatedAt = now;
        // Heartbeats intentionally do not advance Version. The status/owner/expiry
        // predicate fences recovery, while a stable Version avoids making the
        // processor's primary tracked context stale on every heartbeat.
        await base.SaveChangesAsync(cancellationToken);
        return true;
    }

    private void UpdateAuditFields()
    {
        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = DateTime.UtcNow;

                switch (entry.Entity)
                {
                    case MusicImportBatch batch:
                        batch.Version++;
                        break;
                    case MusicImportItem item:
                        item.Version++;
                        break;
                }
            }
        }
    }
}
