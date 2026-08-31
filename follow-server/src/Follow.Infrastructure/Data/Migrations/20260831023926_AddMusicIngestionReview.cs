using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Follow.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddMusicIngestionReview : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "BitDepth",
                table: "Tracks",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BitRateKbps",
                table: "Tracks",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Channels",
                table: "Tracks",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Codec",
                table: "Tracks",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Container",
                table: "Tracks",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "ExactDurationMilliseconds",
                table: "Tracks",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "FingerprintAlgorithm",
                table: "Tracks",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "FingerprintDurationMilliseconds",
                table: "Tracks",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "FingerprintFrameCount",
                table: "Tracks",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "FingerprintPayload",
                table: "Tracks",
                type: "bytea",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FingerprintVersion",
                table: "Tracks",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsLossless",
                table: "Tracks",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SampleRateHz",
                table: "Tracks",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BitDepth",
                table: "MusicImportItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BitRateKbps",
                table: "MusicImportItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Channels",
                table: "MusicImportItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Codec",
                table: "MusicImportItems",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Container",
                table: "MusicImportItems",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Decision",
                table: "MusicImportItems",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "DecisionTrackId",
                table: "MusicImportItems",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "ExactDurationMilliseconds",
                table: "MusicImportItems",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExtractedAlbum",
                table: "MusicImportItems",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExtractedArtist",
                table: "MusicImportItems",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ExtractedTitle",
                table: "MusicImportItems",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "FingerprintAlgorithm",
                table: "MusicImportItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "FingerprintDurationMilliseconds",
                table: "MusicImportItems",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "FingerprintFrameCount",
                table: "MusicImportItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "FingerprintPayload",
                table: "MusicImportItems",
                type: "bytea",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FingerprintVersion",
                table: "MusicImportItems",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsLossless",
                table: "MusicImportItems",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ReviewGroupId",
                table: "MusicImportItems",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SampleRateHz",
                table: "MusicImportItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SourceETag",
                table: "MusicImportItems",
                type: "character varying(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SourceKind",
                table: "MusicImportItems",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "MountedDirectory");

            migrationBuilder.AddColumn<string>(
                name: "SourceReference",
                table: "MusicImportItems",
                type: "character varying(1024)",
                maxLength: 1024,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StagingObjectPath",
                table: "MusicImportItems",
                type: "character varying(1024)",
                maxLength: 1024,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SourceKind",
                table: "MusicImportBatches",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "MountedDirectory");

            migrationBuilder.CreateTable(
                name: "MusicImportReviewGroups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BatchId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    MatchKind = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ExistingTrackId = table.Column<Guid>(type: "uuid", nullable: true),
                    RecommendedItemId = table.Column<Guid>(type: "uuid", nullable: true),
                    RecommendationExplanation = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    FingerprintVersion = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    FingerprintAlgorithm = table.Column<int>(type: "integer", nullable: true),
                    OverallSimilarity = table.Column<double>(type: "double precision", nullable: true),
                    MinimumSegmentSimilarity = table.Column<double>(type: "double precision", nullable: true),
                    CoverageFraction = table.Column<double>(type: "double precision", nullable: true),
                    AlignmentOffsetFrames = table.Column<int>(type: "integer", nullable: true),
                    ConfirmedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ConfirmedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ApplyErrorCode = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ApplyErrorMessage = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MusicImportReviewGroups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MusicImportReviewGroups_MusicImportBatches_BatchId",
                        column: x => x.BatchId,
                        principalTable: "MusicImportBatches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MusicImportReviewGroups_MusicImportItems_RecommendedItemId",
                        column: x => x.RecommendedItemId,
                        principalTable: "MusicImportItems",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_MusicImportReviewGroups_Tracks_ExistingTrackId",
                        column: x => x.ExistingTrackId,
                        principalTable: "Tracks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_MusicImportReviewGroups_Users_ConfirmedByUserId",
                        column: x => x.ConfirmedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "TrackAudioRevisions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TrackId = table.Column<Guid>(type: "uuid", nullable: false),
                    ReviewGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActingUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PreviousObjectPath = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    ReplacementObjectPath = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    PreviousContentSha256 = table.Column<byte[]>(type: "bytea", maxLength: 32, nullable: true),
                    ReplacementContentSha256 = table.Column<byte[]>(type: "bytea", maxLength: 32, nullable: true),
                    PreviousCodec = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    ReplacementCodec = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    PreviousContainer = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    ReplacementContainer = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    PreviousIsLossless = table.Column<bool>(type: "boolean", nullable: true),
                    ReplacementIsLossless = table.Column<bool>(type: "boolean", nullable: true),
                    PreviousSampleRateHz = table.Column<int>(type: "integer", nullable: true),
                    ReplacementSampleRateHz = table.Column<int>(type: "integer", nullable: true),
                    PreviousBitDepth = table.Column<int>(type: "integer", nullable: true),
                    ReplacementBitDepth = table.Column<int>(type: "integer", nullable: true),
                    PreviousChannels = table.Column<int>(type: "integer", nullable: true),
                    ReplacementChannels = table.Column<int>(type: "integer", nullable: true),
                    PreviousBitRateKbps = table.Column<int>(type: "integer", nullable: true),
                    ReplacementBitRateKbps = table.Column<int>(type: "integer", nullable: true),
                    PreviousFileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    ReplacementFileSizeBytes = table.Column<long>(type: "bigint", nullable: true),
                    PreviousExactDurationMilliseconds = table.Column<long>(type: "bigint", nullable: true),
                    ReplacementExactDurationMilliseconds = table.Column<long>(type: "bigint", nullable: true),
                    PreviousFingerprintVersion = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ReplacementFingerprintVersion = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    PreviousFingerprintAlgorithm = table.Column<int>(type: "integer", nullable: true),
                    ReplacementFingerprintAlgorithm = table.Column<int>(type: "integer", nullable: true),
                    PreviousFingerprintPayload = table.Column<byte[]>(type: "bytea", nullable: true),
                    ReplacementFingerprintPayload = table.Column<byte[]>(type: "bytea", nullable: true),
                    PreviousFingerprintFrameCount = table.Column<int>(type: "integer", nullable: true),
                    ReplacementFingerprintFrameCount = table.Column<int>(type: "integer", nullable: true),
                    PreviousFingerprintDurationMilliseconds = table.Column<long>(type: "bigint", nullable: true),
                    ReplacementFingerprintDurationMilliseconds = table.Column<long>(type: "bigint", nullable: true),
                    StorageDeletionJobId = table.Column<Guid>(type: "uuid", nullable: true),
                    CleanupStatus = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrackAudioRevisions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrackAudioRevisions_MusicImportReviewGroups_ReviewGroupId",
                        column: x => x.ReviewGroupId,
                        principalTable: "MusicImportReviewGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TrackAudioRevisions_StorageDeletionJobs_StorageDeletionJobId",
                        column: x => x.StorageDeletionJobId,
                        principalTable: "StorageDeletionJobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_TrackAudioRevisions_Tracks_TrackId",
                        column: x => x.TrackId,
                        principalTable: "Tracks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TrackAudioRevisions_Users_ActingUserId",
                        column: x => x.ActingUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Tracks_FingerprintVersion_FingerprintAlgorithm",
                table: "Tracks",
                columns: new[] { "FingerprintVersion", "FingerprintAlgorithm" });

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportItems_ReviewGroupId_Decision",
                table: "MusicImportItems",
                columns: new[] { "ReviewGroupId", "Decision" });

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportReviewGroups_BatchId_Status",
                table: "MusicImportReviewGroups",
                columns: new[] { "BatchId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportReviewGroups_ConfirmedByUserId",
                table: "MusicImportReviewGroups",
                column: "ConfirmedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportReviewGroups_ExistingTrackId",
                table: "MusicImportReviewGroups",
                column: "ExistingTrackId");

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportReviewGroups_RecommendedItemId",
                table: "MusicImportReviewGroups",
                column: "RecommendedItemId");

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportReviewGroups_Status_Version",
                table: "MusicImportReviewGroups",
                columns: new[] { "Status", "Version" });

            migrationBuilder.CreateIndex(
                name: "IX_TrackAudioRevisions_ActingUserId",
                table: "TrackAudioRevisions",
                column: "ActingUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TrackAudioRevisions_ReviewGroupId",
                table: "TrackAudioRevisions",
                column: "ReviewGroupId");

            migrationBuilder.CreateIndex(
                name: "IX_TrackAudioRevisions_StorageDeletionJobId",
                table: "TrackAudioRevisions",
                column: "StorageDeletionJobId");

            migrationBuilder.CreateIndex(
                name: "IX_TrackAudioRevisions_TrackId_CreatedAt",
                table: "TrackAudioRevisions",
                columns: new[] { "TrackId", "CreatedAt" });

            migrationBuilder.AddForeignKey(
                name: "FK_MusicImportItems_MusicImportReviewGroups_ReviewGroupId",
                table: "MusicImportItems",
                column: "ReviewGroupId",
                principalTable: "MusicImportReviewGroups",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MusicImportItems_MusicImportReviewGroups_ReviewGroupId",
                table: "MusicImportItems");

            migrationBuilder.DropTable(
                name: "TrackAudioRevisions");

            migrationBuilder.DropTable(
                name: "MusicImportReviewGroups");

            migrationBuilder.DropIndex(
                name: "IX_Tracks_FingerprintVersion_FingerprintAlgorithm",
                table: "Tracks");

            migrationBuilder.DropIndex(
                name: "IX_MusicImportItems_ReviewGroupId_Decision",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "BitDepth",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "BitRateKbps",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "Channels",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "Codec",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "Container",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "ExactDurationMilliseconds",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "FingerprintAlgorithm",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "FingerprintDurationMilliseconds",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "FingerprintFrameCount",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "FingerprintPayload",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "FingerprintVersion",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "IsLossless",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "SampleRateHz",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "BitDepth",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "BitRateKbps",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "Channels",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "Codec",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "Container",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "Decision",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "DecisionTrackId",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "ExactDurationMilliseconds",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "ExtractedAlbum",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "ExtractedArtist",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "ExtractedTitle",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "FingerprintAlgorithm",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "FingerprintDurationMilliseconds",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "FingerprintFrameCount",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "FingerprintPayload",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "FingerprintVersion",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "IsLossless",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "ReviewGroupId",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "SampleRateHz",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "SourceETag",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "SourceKind",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "SourceReference",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "StagingObjectPath",
                table: "MusicImportItems");

            migrationBuilder.DropColumn(
                name: "SourceKind",
                table: "MusicImportBatches");
        }
    }
}
