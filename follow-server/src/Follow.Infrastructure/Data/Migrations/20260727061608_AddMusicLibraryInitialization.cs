using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Follow.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddMusicLibraryInitialization : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "ContentSha256",
                table: "Tracks",
                type: "bytea",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "FileSizeBytes",
                table: "Tracks",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OriginalFileName",
                table: "Tracks",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "MusicImportBatches",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RelativeDirectory = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    AutoStart = table.Column<bool>(type: "boolean", nullable: false),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    DiscoveredFileCount = table.Column<int>(type: "integer", nullable: false),
                    IgnoredFileCount = table.Column<int>(type: "integer", nullable: false),
                    TotalBytes = table.Column<long>(type: "bigint", nullable: false),
                    ScanStartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ScanCompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelRequestedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LeaseOwner = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    LeaseExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastErrorCode = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    LastError = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MusicImportBatches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MusicImportBatches_Users_RequestedByUserId",
                        column: x => x.RequestedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MusicImportItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BatchId = table.Column<Guid>(type: "uuid", nullable: false),
                    RelativePath = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    OriginalFileName = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: false),
                    Extension = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    SourceModifiedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ContentSha256 = table.Column<byte[]>(type: "bytea", maxLength: 32, nullable: true),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Stage = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    Retryable = table.Column<bool>(type: "boolean", nullable: false),
                    NextAttemptAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LeaseOwner = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    LeaseExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ObjectPath = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: true),
                    TrackId = table.Column<Guid>(type: "uuid", nullable: true),
                    ErrorCode = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ErrorMessage = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CompletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MusicImportItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MusicImportItems_MusicImportBatches_BatchId",
                        column: x => x.BatchId,
                        principalTable: "MusicImportBatches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MusicImportItems_Tracks_TrackId",
                        column: x => x.TrackId,
                        principalTable: "Tracks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "UX_Tracks_ContentSha256",
                table: "Tracks",
                column: "ContentSha256",
                unique: true,
                filter: "\"ContentSha256\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportBatches_Status_LeaseExpiresAt",
                table: "MusicImportBatches",
                columns: new[] { "Status", "LeaseExpiresAt" });

            migrationBuilder.CreateIndex(
                name: "UX_MusicImportBatches_RequestedByUser_ClientRequestId",
                table: "MusicImportBatches",
                columns: new[] { "RequestedByUserId", "ClientRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportItems_BatchId_RelativePath",
                table: "MusicImportItems",
                columns: new[] { "BatchId", "RelativePath" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportItems_BatchId_Status",
                table: "MusicImportItems",
                columns: new[] { "BatchId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportItems_Status_NextAttemptAt_LeaseExpiresAt",
                table: "MusicImportItems",
                columns: new[] { "Status", "NextAttemptAt", "LeaseExpiresAt" });

            migrationBuilder.CreateIndex(
                name: "IX_MusicImportItems_TrackId",
                table: "MusicImportItems",
                column: "TrackId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MusicImportItems");

            migrationBuilder.DropTable(
                name: "MusicImportBatches");

            migrationBuilder.DropIndex(
                name: "UX_Tracks_ContentSha256",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "ContentSha256",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "FileSizeBytes",
                table: "Tracks");

            migrationBuilder.DropColumn(
                name: "OriginalFileName",
                table: "Tracks");
        }
    }
}
