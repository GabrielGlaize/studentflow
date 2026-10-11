using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class EmailVerificationCodes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "email_verification_codes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    code_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    used_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    failed_attempts = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_email_verification_codes", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_email_verification_codes_email_expires_at",
                table: "email_verification_codes",
                columns: new[] { "email", "expires_at" });

            // Réglages restés aux valeurs par défaut : créés par une simple lecture du profil, jamais
            // enregistrés par l'élève. Les marquer ainsi évite que l'app écrase ses propres réglages
            // (entreprise choisie sur le téléphone) par ces valeurs par défaut.
            migrationBuilder.Sql("""
                UPDATE user_app_settings
                SET updated_at = '1970-01-01T00:00:00Z'
                WHERE has_company = false AND company_name IS NULL AND theme = 'System';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "email_verification_codes");
        }
    }
}
