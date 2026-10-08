using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class LinkSubjectsAndTeachers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_teachers_school_class_id_search_name_hash",
                table: "teachers");

            migrationBuilder.DropIndex(
                name: "IX_subjects_school_class_id_name",
                table: "subjects");

            migrationBuilder.CreateTable(
                name: "subject_teachers",
                columns: table => new
                {
                    subject_id = table.Column<Guid>(type: "uuid", nullable: false),
                    teacher_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_subject_teachers", x => new { x.subject_id, x.teacher_id });
                    table.ForeignKey(
                        name: "FK_subject_teachers_subjects_subject_id",
                        column: x => x.subject_id,
                        principalTable: "subjects",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_subject_teachers_teachers_teacher_id",
                        column: x => x.teacher_id,
                        principalTable: "teachers",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_teachers_school_class_id_search_name_hash",
                table: "teachers",
                columns: new[] { "school_class_id", "search_name_hash" },
                unique: true,
                filter: "is_active");

            migrationBuilder.CreateIndex(
                name: "IX_subjects_school_class_id_name",
                table: "subjects",
                columns: new[] { "school_class_id", "name" },
                unique: true,
                filter: "is_active");

            migrationBuilder.CreateIndex(
                name: "IX_subject_teachers_teacher_id",
                table: "subject_teachers",
                column: "teacher_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "subject_teachers");

            migrationBuilder.DropIndex(
                name: "IX_teachers_school_class_id_search_name_hash",
                table: "teachers");

            migrationBuilder.DropIndex(
                name: "IX_subjects_school_class_id_name",
                table: "subjects");

            migrationBuilder.CreateIndex(
                name: "IX_teachers_school_class_id_search_name_hash",
                table: "teachers",
                columns: new[] { "school_class_id", "search_name_hash" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_subjects_school_class_id_name",
                table: "subjects",
                columns: new[] { "school_class_id", "name" },
                unique: true);
        }
    }
}
