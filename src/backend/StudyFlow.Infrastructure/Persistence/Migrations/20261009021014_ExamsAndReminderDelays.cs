using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ExamsAndReminderDelays : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Lignes existantes : la veille pour les devoirs et tâches, 1 h avant pour les événements.
            migrationBuilder.AddColumn<int>(
                name: "reminder_minutes_before",
                table: "personal_tasks",
                type: "integer",
                nullable: false,
                defaultValue: 1440);

            migrationBuilder.AddColumn<int>(
                name: "reminder_minutes_before",
                table: "personal_events",
                type: "integer",
                nullable: false,
                defaultValue: 60);

            migrationBuilder.AddColumn<int>(
                name: "reminder_minutes_before",
                table: "homework_progress",
                type: "integer",
                nullable: false,
                defaultValue: 1440);

            migrationBuilder.CreateTable(
                name: "exam_sessions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    school_class_id = table.Column<Guid>(type: "uuid", nullable: false),
                    title = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    starts_on = table.Column<DateOnly>(type: "date", nullable: false),
                    ends_on = table.Column<DateOnly>(type: "date", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_exam_sessions", x => x.id);
                    table.ForeignKey(
                        name: "FK_exam_sessions_school_classes_school_class_id",
                        column: x => x.school_class_id,
                        principalTable: "school_classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_exam_sessions_users_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "exam_subjects",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    exam_session_id = table.Column<Guid>(type: "uuid", nullable: false),
                    subject_id = table.Column<Guid>(type: "uuid", nullable: false),
                    exam_day = table.Column<DateOnly>(type: "date", nullable: true),
                    starts_at = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    details = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    position = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_exam_subjects", x => x.id);
                    table.ForeignKey(
                        name: "FK_exam_subjects_exam_sessions_exam_session_id",
                        column: x => x.exam_session_id,
                        principalTable: "exam_sessions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_exam_subjects_subjects_subject_id",
                        column: x => x.subject_id,
                        principalTable: "subjects",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "revision_items",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    exam_subject_id = table.Column<Guid>(type: "uuid", nullable: false),
                    author_id = table.Column<Guid>(type: "uuid", nullable: false),
                    text = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_revision_items", x => x.id);
                    table.ForeignKey(
                        name: "FK_revision_items_exam_subjects_exam_subject_id",
                        column: x => x.exam_subject_id,
                        principalTable: "exam_subjects",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_revision_items_users_author_id",
                        column: x => x.author_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "revision_resources",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    exam_subject_id = table.Column<Guid>(type: "uuid", nullable: false),
                    author_id = table.Column<Guid>(type: "uuid", nullable: false),
                    title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    kind = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    url = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    file_name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    file_type = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    content_type = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    size_bytes = table.Column<long>(type: "bigint", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_revision_resources", x => x.id);
                    table.ForeignKey(
                        name: "FK_revision_resources_exam_subjects_exam_subject_id",
                        column: x => x.exam_subject_id,
                        principalTable: "exam_subjects",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_revision_resources_users_author_id",
                        column: x => x.author_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "revision_item_checks",
                columns: table => new
                {
                    revision_item_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    checked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_revision_item_checks", x => new { x.revision_item_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_revision_item_checks_revision_items_revision_item_id",
                        column: x => x.revision_item_id,
                        principalTable: "revision_items",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_revision_item_checks_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "revision_resource_files",
                columns: table => new
                {
                    revision_resource_id = table.Column<Guid>(type: "uuid", nullable: false),
                    content = table.Column<byte[]>(type: "bytea", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_revision_resource_files", x => x.revision_resource_id);
                    table.ForeignKey(
                        name: "FK_revision_resource_files_revision_resources_revision_resourc~",
                        column: x => x.revision_resource_id,
                        principalTable: "revision_resources",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_exam_sessions_created_by_id",
                table: "exam_sessions",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_exam_sessions_school_class_id_starts_on",
                table: "exam_sessions",
                columns: new[] { "school_class_id", "starts_on" });

            migrationBuilder.CreateIndex(
                name: "IX_exam_subjects_exam_session_id_subject_id",
                table: "exam_subjects",
                columns: new[] { "exam_session_id", "subject_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_exam_subjects_subject_id",
                table: "exam_subjects",
                column: "subject_id");

            migrationBuilder.CreateIndex(
                name: "IX_revision_item_checks_user_id",
                table: "revision_item_checks",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_revision_items_author_id",
                table: "revision_items",
                column: "author_id");

            migrationBuilder.CreateIndex(
                name: "IX_revision_items_exam_subject_id_created_at",
                table: "revision_items",
                columns: new[] { "exam_subject_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_revision_resources_author_id",
                table: "revision_resources",
                column: "author_id");

            migrationBuilder.CreateIndex(
                name: "IX_revision_resources_exam_subject_id_created_at",
                table: "revision_resources",
                columns: new[] { "exam_subject_id", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "revision_item_checks");

            migrationBuilder.DropTable(
                name: "revision_resource_files");

            migrationBuilder.DropTable(
                name: "revision_items");

            migrationBuilder.DropTable(
                name: "revision_resources");

            migrationBuilder.DropTable(
                name: "exam_subjects");

            migrationBuilder.DropTable(
                name: "exam_sessions");

            migrationBuilder.DropColumn(
                name: "reminder_minutes_before",
                table: "personal_tasks");

            migrationBuilder.DropColumn(
                name: "reminder_minutes_before",
                table: "personal_events");

            migrationBuilder.DropColumn(
                name: "reminder_minutes_before",
                table: "homework_progress");
        }
    }
}
