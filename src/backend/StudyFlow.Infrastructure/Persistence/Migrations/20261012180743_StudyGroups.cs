using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class StudyGroups : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "is_group_work",
                table: "homework",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "study_groups",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    school_class_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    encrypted_description = table.Column<string>(type: "text", nullable: true),
                    subject_id = table.Column<Guid>(type: "uuid", nullable: true),
                    homework_id = table.Column<Guid>(type: "uuid", nullable: true),
                    due_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_groups", x => x.id);
                    table.ForeignKey(
                        name: "FK_study_groups_homework_homework_id",
                        column: x => x.homework_id,
                        principalTable: "homework",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_study_groups_school_classes_school_class_id",
                        column: x => x.school_class_id,
                        principalTable: "school_classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_groups_subjects_subject_id",
                        column: x => x.subject_id,
                        principalTable: "subjects",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_study_groups_users_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "user_availabilities",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    company_ends_at = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    available_until = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    weekend_available = table.Column<bool>(type: "boolean", nullable: false),
                    use_personal_agenda = table.Column<bool>(type: "boolean", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_availabilities", x => x.user_id);
                    table.ForeignKey(
                        name: "FK_user_availabilities_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "study_group_meetings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    study_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    starts_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ends_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    mode = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    encrypted_place = table.Column<string>(type: "text", nullable: true),
                    proposed_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    status = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_meetings", x => x.id);
                    table.ForeignKey(
                        name: "FK_study_group_meetings_study_groups_study_group_id",
                        column: x => x.study_group_id,
                        principalTable: "study_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_meetings_users_proposed_by_id",
                        column: x => x.proposed_by_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "study_group_members",
                columns: table => new
                {
                    study_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    role = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    status = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    role_label = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    invited_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    invited_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    joined_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_read_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_members", x => new { x.study_group_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_study_group_members_study_groups_study_group_id",
                        column: x => x.study_group_id,
                        principalTable: "study_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_members_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "study_group_messages",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    study_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    author_id = table.Column<Guid>(type: "uuid", nullable: true),
                    encrypted_text = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_messages", x => x.id);
                    table.ForeignKey(
                        name: "FK_study_group_messages_study_groups_study_group_id",
                        column: x => x.study_group_id,
                        principalTable: "study_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_messages_users_author_id",
                        column: x => x.author_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "study_group_resources",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    study_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    author_id = table.Column<Guid>(type: "uuid", nullable: true),
                    kind = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    encrypted_title = table.Column<string>(type: "text", nullable: false),
                    encrypted_url = table.Column<string>(type: "text", nullable: true),
                    file_name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    file_type = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    content_type = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    size_bytes = table.Column<long>(type: "bigint", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_resources", x => x.id);
                    table.ForeignKey(
                        name: "FK_study_group_resources_study_groups_study_group_id",
                        column: x => x.study_group_id,
                        principalTable: "study_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_resources_users_author_id",
                        column: x => x.author_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "study_group_tasks",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    study_group_id = table.Column<Guid>(type: "uuid", nullable: false),
                    encrypted_title = table.Column<string>(type: "text", nullable: false),
                    encrypted_notes = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    due_on = table.Column<DateOnly>(type: "date", nullable: true),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_tasks", x => x.id);
                    table.ForeignKey(
                        name: "FK_study_group_tasks_study_groups_study_group_id",
                        column: x => x.study_group_id,
                        principalTable: "study_groups",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_tasks_users_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "study_group_meeting_votes",
                columns: table => new
                {
                    study_group_meeting_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    is_available = table.Column<bool>(type: "boolean", nullable: false),
                    answered_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_meeting_votes", x => new { x.study_group_meeting_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_study_group_meeting_votes_study_group_meetings_study_group_~",
                        column: x => x.study_group_meeting_id,
                        principalTable: "study_group_meetings",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_meeting_votes_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "study_group_resource_files",
                columns: table => new
                {
                    study_group_resource_id = table.Column<Guid>(type: "uuid", nullable: false),
                    encrypted_content = table.Column<byte[]>(type: "bytea", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_resource_files", x => x.study_group_resource_id);
                    table.ForeignKey(
                        name: "FK_study_group_resource_files_study_group_resources_study_grou~",
                        column: x => x.study_group_resource_id,
                        principalTable: "study_group_resources",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "study_group_task_assignees",
                columns: table => new
                {
                    study_group_task_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_study_group_task_assignees", x => new { x.study_group_task_id, x.user_id });
                    table.ForeignKey(
                        name: "FK_study_group_task_assignees_study_group_tasks_study_group_ta~",
                        column: x => x.study_group_task_id,
                        principalTable: "study_group_tasks",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_study_group_task_assignees_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_study_group_meeting_votes_user_id",
                table: "study_group_meeting_votes",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_meetings_proposed_by_id",
                table: "study_group_meetings",
                column: "proposed_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_meetings_study_group_id_starts_at",
                table: "study_group_meetings",
                columns: new[] { "study_group_id", "starts_at" });

            migrationBuilder.CreateIndex(
                name: "IX_study_group_members_user_id",
                table: "study_group_members",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_messages_author_id",
                table: "study_group_messages",
                column: "author_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_messages_study_group_id_created_at",
                table: "study_group_messages",
                columns: new[] { "study_group_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_study_group_resources_author_id",
                table: "study_group_resources",
                column: "author_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_resources_study_group_id_created_at",
                table: "study_group_resources",
                columns: new[] { "study_group_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_study_group_task_assignees_user_id",
                table: "study_group_task_assignees",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_tasks_created_by_id",
                table: "study_group_tasks",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_group_tasks_study_group_id_created_at",
                table: "study_group_tasks",
                columns: new[] { "study_group_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_study_groups_created_by_id",
                table: "study_groups",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_groups_homework_id",
                table: "study_groups",
                column: "homework_id");

            migrationBuilder.CreateIndex(
                name: "IX_study_groups_school_class_id_homework_id",
                table: "study_groups",
                columns: new[] { "school_class_id", "homework_id" });

            migrationBuilder.CreateIndex(
                name: "IX_study_groups_subject_id",
                table: "study_groups",
                column: "subject_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "study_group_meeting_votes");

            migrationBuilder.DropTable(
                name: "study_group_members");

            migrationBuilder.DropTable(
                name: "study_group_messages");

            migrationBuilder.DropTable(
                name: "study_group_resource_files");

            migrationBuilder.DropTable(
                name: "study_group_task_assignees");

            migrationBuilder.DropTable(
                name: "user_availabilities");

            migrationBuilder.DropTable(
                name: "study_group_meetings");

            migrationBuilder.DropTable(
                name: "study_group_resources");

            migrationBuilder.DropTable(
                name: "study_group_tasks");

            migrationBuilder.DropTable(
                name: "study_groups");

            migrationBuilder.DropColumn(
                name: "is_group_work",
                table: "homework");
        }
    }
}
