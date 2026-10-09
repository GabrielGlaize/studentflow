using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class EvaluationsAndQuietHours : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "muted_until",
                table: "notification_preferences",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "quiet_hours_enabled",
                table: "notification_preferences",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<TimeOnly>(
                name: "quiet_hours_end",
                table: "notification_preferences",
                type: "time without time zone",
                nullable: false,
                defaultValue: new TimeOnly(7, 0, 0));

            migrationBuilder.AddColumn<TimeOnly>(
                name: "quiet_hours_start",
                table: "notification_preferences",
                type: "time without time zone",
                nullable: false,
                defaultValue: new TimeOnly(22, 0, 0));

            migrationBuilder.AddColumn<bool>(
                name: "is_evaluation",
                table: "homework",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "muted_until",
                table: "notification_preferences");

            migrationBuilder.DropColumn(
                name: "quiet_hours_enabled",
                table: "notification_preferences");

            migrationBuilder.DropColumn(
                name: "quiet_hours_end",
                table: "notification_preferences");

            migrationBuilder.DropColumn(
                name: "quiet_hours_start",
                table: "notification_preferences");

            migrationBuilder.DropColumn(
                name: "is_evaluation",
                table: "homework");
        }
    }
}
