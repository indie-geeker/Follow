using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Follow.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddLyricsUrlToTrack : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "LyricsUrl",
                table: "Tracks",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LyricsUrl",
                table: "Tracks");
        }
    }
}
