using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(StudyFlowDbContext))]
    [Migration("20260629193000_SecureNotificationDeviceTokens")]
    public partial class SecureNotificationDeviceTokens : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Old rows contained push tokens in clear text. We prefer deleting local
            // registrations and letting devices register again with encrypted storage.
            migrationBuilder.Sql("DELETE FROM notification_devices");

            migrationBuilder.DropIndex(
                name: "IX_notification_devices_token",
                table: "notification_devices");

            migrationBuilder.DropColumn(
                name: "token",
                table: "notification_devices");

            migrationBuilder.AddColumn<string>(
                name: "encrypted_token",
                table: "notification_devices",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "token_hash",
                table: "notification_devices",
                type: "character varying(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_notification_devices_token_hash",
                table: "notification_devices",
                column: "token_hash",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM notification_devices");

            migrationBuilder.DropIndex(
                name: "IX_notification_devices_token_hash",
                table: "notification_devices");

            migrationBuilder.DropColumn(
                name: "encrypted_token",
                table: "notification_devices");

            migrationBuilder.DropColumn(
                name: "token_hash",
                table: "notification_devices");

            migrationBuilder.AddColumn<string>(
                name: "token",
                table: "notification_devices",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_notification_devices_token",
                table: "notification_devices",
                column: "token",
                unique: true);
        }
    }
}
