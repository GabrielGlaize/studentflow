using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "roles",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    normalized_name = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    concurrency_stamp = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_roles", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "role_claims",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    role_id = table.Column<Guid>(type: "uuid", nullable: false),
                    claim_type = table.Column<string>(type: "text", nullable: true),
                    claim_value = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_role_claims", x => x.id);
                    table.ForeignKey(
                        name: "FK_role_claims_roles_role_id",
                        column: x => x.role_id,
                        principalTable: "roles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "annonces_classe",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    auteur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    contenu = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    est_epingle = table.Column<bool>(type: "boolean", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_annonces_classe", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "appareils_notifications",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    token = table.Column<string>(type: "text", nullable: false),
                    plateforme = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    derniere_activite_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_appareils_notifications", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "classes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    nom = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    annee_scolaire = table.Column<string>(type: "character varying(9)", maxLength: 9, nullable: false),
                    code_acces_hash = table.Column<string>(type: "text", nullable: false),
                    code_acces_chiffre = table.Column<string>(type: "text", nullable: false),
                    code_acces_updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    est_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_classes", x => x.id);
                    table.CheckConstraint("ck_classes_annee_scolaire", "annee_scolaire ~ '^[0-9]{4}-[0-9]{4}$'");
                });

            migrationBuilder.CreateTable(
                name: "utilisateurs",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    prenom = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    nom = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: true),
                    est_actif = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    user_name = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    normalized_user_name = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: true),
                    normalized_email = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    email_confirmed = table.Column<bool>(type: "boolean", nullable: false),
                    password_hash = table.Column<string>(type: "text", nullable: true),
                    security_stamp = table.Column<string>(type: "text", nullable: true),
                    concurrency_stamp = table.Column<string>(type: "text", nullable: true),
                    phone_number = table.Column<string>(type: "text", nullable: true),
                    phone_number_confirmed = table.Column<bool>(type: "boolean", nullable: false),
                    two_factor_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    lockout_end = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    lockout_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    access_failed_count = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_utilisateurs", x => x.id);
                    table.ForeignKey(
                        name: "FK_utilisateurs_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "demandes_adhesion_classe",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    statut = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    requested_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    decided_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    decided_by_id = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_demandes_adhesion_classe", x => x.id);
                    table.ForeignKey(
                        name: "FK_demandes_adhesion_classe_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_demandes_adhesion_classe_utilisateurs_decided_by_id",
                        column: x => x.decided_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_demandes_adhesion_classe_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "evenements_personnels",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    date_jour = table.Column<DateOnly>(type: "date", nullable: false),
                    donnees_chiffrees = table.Column<string>(type: "text", nullable: false),
                    categorie = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    notification_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_evenements_personnels", x => x.id);
                    table.ForeignKey(
                        name: "FK_evenements_personnels_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "matieres",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    nom = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    est_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_matieres", x => x.id);
                    table.ForeignKey(
                        name: "FK_matieres_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_matieres_utilisateurs_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "messages_alternance",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    auteur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    contenu_chiffre = table.Column<string>(type: "text", nullable: false),
                    lien_chiffre = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by_id = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_messages_alternance", x => x.id);
                    table.ForeignKey(
                        name: "FK_messages_alternance_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_messages_alternance_utilisateurs_auteur_id",
                        column: x => x.auteur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_messages_alternance_utilisateurs_deleted_by_id",
                        column: x => x.deleted_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "offres_favorites",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    source = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    offre_externe_id = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    titre = table.Column<string>(type: "character varying(250)", maxLength: 250, nullable: false),
                    entreprise = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    localisation = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    url = table.Column<string>(type: "text", nullable: false),
                    date_publication = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    enregistree_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_offres_favorites", x => x.id);
                    table.ForeignKey(
                        name: "FK_offres_favorites_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "preferences_notifications",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    cours_actifs = table.Column<bool>(type: "boolean", nullable: false),
                    devoirs_actifs = table.Column<bool>(type: "boolean", nullable: false),
                    alternances_actives = table.Column<bool>(type: "boolean", nullable: false),
                    cours_rappel_minutes = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_preferences_notifications", x => x.id);
                    table.CheckConstraint("ck_preferences_notifications_cours_rappel_minutes", "cours_rappel_minutes IN (0, 5, 10, 15, 30, 60)");
                    table.ForeignKey(
                        name: "FK_preferences_notifications_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "professeurs",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    nom_affiche_chiffre = table.Column<string>(type: "text", nullable: false),
                    nom_recherche_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    informations_chiffrees = table.Column<string>(type: "text", nullable: true),
                    est_actif = table.Column<bool>(type: "boolean", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_professeurs", x => x.id);
                    table.ForeignKey(
                        name: "FK_professeurs_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_professeurs_utilisateurs_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "recherches_alternance",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    nom = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    mots_cles = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    localisation = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    latitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                    longitude = table.Column<decimal>(type: "numeric(9,6)", precision: 9, scale: 6, nullable: true),
                    distance_km = table.Column<int>(type: "integer", nullable: true),
                    filtres_json = table.Column<string>(type: "jsonb", nullable: false),
                    alerte_active = table.Column<bool>(type: "boolean", nullable: false),
                    derniere_verification_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_recherches_alternance", x => x.id);
                    table.ForeignKey(
                        name: "FK_recherches_alternance_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "revisions_contributions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    entite_type = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    entite_id = table.Column<Guid>(type: "uuid", nullable: false),
                    action = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    snapshot_chiffre = table.Column<string>(type: "text", nullable: false),
                    auteur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_revisions_contributions", x => x.id);
                    table.ForeignKey(
                        name: "FK_revisions_contributions_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_revisions_contributions_utilisateurs_auteur_id",
                        column: x => x.auteur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "utilisateur_claims",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    claim_type = table.Column<string>(type: "text", nullable: true),
                    claim_value = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_utilisateur_claims", x => x.id);
                    table.ForeignKey(
                        name: "FK_utilisateur_claims_utilisateurs_user_id",
                        column: x => x.user_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "utilisateur_logins",
                columns: table => new
                {
                    login_provider = table.Column<string>(type: "text", nullable: false),
                    provider_key = table.Column<string>(type: "text", nullable: false),
                    provider_display_name = table.Column<string>(type: "text", nullable: true),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_utilisateur_logins", x => new { x.login_provider, x.provider_key });
                    table.ForeignKey(
                        name: "FK_utilisateur_logins_utilisateurs_user_id",
                        column: x => x.user_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "utilisateur_roles",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    role_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_utilisateur_roles", x => new { x.user_id, x.role_id });
                    table.ForeignKey(
                        name: "FK_utilisateur_roles_roles_role_id",
                        column: x => x.role_id,
                        principalTable: "roles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_utilisateur_roles_utilisateurs_user_id",
                        column: x => x.user_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "utilisateur_tokens",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    login_provider = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    value = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_utilisateur_tokens", x => new { x.user_id, x.login_provider, x.name });
                    table.ForeignKey(
                        name: "FK_utilisateur_tokens_utilisateurs_user_id",
                        column: x => x.user_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "cours",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    serie_id = table.Column<Guid>(type: "uuid", nullable: true),
                    matiere_id = table.Column<Guid>(type: "uuid", nullable: false),
                    date_jour = table.Column<DateOnly>(type: "date", nullable: false),
                    donnees_chiffrees = table.Column<string>(type: "text", nullable: false),
                    professeur_id = table.Column<Guid>(type: "uuid", nullable: true),
                    est_annule = table.Column<bool>(type: "boolean", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    updated_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    version = table.Column<long>(type: "bigint", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_cours", x => x.id);
                    table.ForeignKey(
                        name: "FK_cours_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_cours_matieres_matiere_id",
                        column: x => x.matiere_id,
                        principalTable: "matieres",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_cours_professeurs_professeur_id",
                        column: x => x.professeur_id,
                        principalTable: "professeurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_cours_utilisateurs_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_cours_utilisateurs_updated_by_id",
                        column: x => x.updated_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "devoirs_collectifs",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    classe_id = table.Column<Guid>(type: "uuid", nullable: false),
                    cours_id = table.Column<Guid>(type: "uuid", nullable: true),
                    titre = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    deadline = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    updated_by_id = table.Column<Guid>(type: "uuid", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_devoirs_collectifs", x => x.id);
                    table.ForeignKey(
                        name: "FK_devoirs_collectifs_classes_classe_id",
                        column: x => x.classe_id,
                        principalTable: "classes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_devoirs_collectifs_cours_cours_id",
                        column: x => x.cours_id,
                        principalTable: "cours",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_devoirs_collectifs_utilisateurs_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_devoirs_collectifs_utilisateurs_updated_by_id",
                        column: x => x.updated_by_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "taches_personnelles",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    cours_id = table.Column<Guid>(type: "uuid", nullable: true),
                    titre = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    deadline = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    est_terminee = table.Column<bool>(type: "boolean", nullable: false),
                    notification_active = table.Column<bool>(type: "boolean", nullable: false),
                    categorie = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_taches_personnelles", x => x.id);
                    table.ForeignKey(
                        name: "FK_taches_personnelles_cours_cours_id",
                        column: x => x.cours_id,
                        principalTable: "cours",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_taches_personnelles_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "suivis_devoirs",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    devoir_id = table.Column<Guid>(type: "uuid", nullable: false),
                    utilisateur_id = table.Column<Guid>(type: "uuid", nullable: false),
                    est_termine = table.Column<bool>(type: "boolean", nullable: false),
                    notification_active = table.Column<bool>(type: "boolean", nullable: false),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_suivis_devoirs", x => x.id);
                    table.ForeignKey(
                        name: "FK_suivis_devoirs_devoirs_collectifs_devoir_id",
                        column: x => x.devoir_id,
                        principalTable: "devoirs_collectifs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_suivis_devoirs_utilisateurs_utilisateur_id",
                        column: x => x.utilisateur_id,
                        principalTable: "utilisateurs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "roles",
                columns: new[] { "id", "concurrency_stamp", "name", "normalized_name" },
                values: new object[,]
                {
                    { new Guid("3f2a82b4-f75a-4bf7-b5e7-198d85d1ca34"), "studyflow-role-eleve", "Eleve", "ELEVE" },
                    { new Guid("f438558d-7e21-428b-bf4e-85de5ebfc96f"), "studyflow-role-delegue", "Delegue", "DELEGUE" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_annonces_classe_auteur_id",
                table: "annonces_classe",
                column: "auteur_id");

            migrationBuilder.CreateIndex(
                name: "IX_annonces_classe_classe_id_est_epingle",
                table: "annonces_classe",
                columns: new[] { "classe_id", "est_epingle" });

            migrationBuilder.CreateIndex(
                name: "IX_appareils_notifications_token",
                table: "appareils_notifications",
                column: "token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_appareils_notifications_utilisateur_id",
                table: "appareils_notifications",
                column: "utilisateur_id");

            migrationBuilder.CreateIndex(
                name: "IX_classes_created_by_id",
                table: "classes",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_classes_nom",
                table: "classes",
                column: "nom",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_cours_classe_id_date_jour",
                table: "cours",
                columns: new[] { "classe_id", "date_jour" });

            migrationBuilder.CreateIndex(
                name: "IX_cours_created_by_id",
                table: "cours",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_cours_matiere_id",
                table: "cours",
                column: "matiere_id");

            migrationBuilder.CreateIndex(
                name: "IX_cours_professeur_id",
                table: "cours",
                column: "professeur_id");

            migrationBuilder.CreateIndex(
                name: "IX_cours_serie_id",
                table: "cours",
                column: "serie_id");

            migrationBuilder.CreateIndex(
                name: "IX_cours_updated_by_id",
                table: "cours",
                column: "updated_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_demandes_adhesion_classe_classe_id_statut_requested_at",
                table: "demandes_adhesion_classe",
                columns: new[] { "classe_id", "statut", "requested_at" });

            migrationBuilder.CreateIndex(
                name: "IX_demandes_adhesion_classe_decided_by_id",
                table: "demandes_adhesion_classe",
                column: "decided_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_demandes_adhesion_classe_utilisateur_id",
                table: "demandes_adhesion_classe",
                column: "utilisateur_id",
                unique: true,
                filter: "statut = 'Pending'");

            migrationBuilder.CreateIndex(
                name: "IX_demandes_adhesion_classe_utilisateur_id_statut",
                table: "demandes_adhesion_classe",
                columns: new[] { "utilisateur_id", "statut" });

            migrationBuilder.CreateIndex(
                name: "IX_devoirs_collectifs_classe_id_deadline",
                table: "devoirs_collectifs",
                columns: new[] { "classe_id", "deadline" });

            migrationBuilder.CreateIndex(
                name: "IX_devoirs_collectifs_cours_id",
                table: "devoirs_collectifs",
                column: "cours_id");

            migrationBuilder.CreateIndex(
                name: "IX_devoirs_collectifs_created_by_id",
                table: "devoirs_collectifs",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_devoirs_collectifs_updated_by_id",
                table: "devoirs_collectifs",
                column: "updated_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_evenements_personnels_utilisateur_id_date_jour",
                table: "evenements_personnels",
                columns: new[] { "utilisateur_id", "date_jour" });

            migrationBuilder.CreateIndex(
                name: "IX_matieres_classe_id_nom",
                table: "matieres",
                columns: new[] { "classe_id", "nom" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_matieres_created_by_id",
                table: "matieres",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_messages_alternance_auteur_id",
                table: "messages_alternance",
                column: "auteur_id");

            migrationBuilder.CreateIndex(
                name: "IX_messages_alternance_classe_id_created_at",
                table: "messages_alternance",
                columns: new[] { "classe_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_messages_alternance_deleted_by_id",
                table: "messages_alternance",
                column: "deleted_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_offres_favorites_utilisateur_id_source_offre_externe_id",
                table: "offres_favorites",
                columns: new[] { "utilisateur_id", "source", "offre_externe_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_preferences_notifications_utilisateur_id",
                table: "preferences_notifications",
                column: "utilisateur_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_professeurs_classe_id_nom_recherche_hash",
                table: "professeurs",
                columns: new[] { "classe_id", "nom_recherche_hash" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_professeurs_created_by_id",
                table: "professeurs",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "IX_recherches_alternance_utilisateur_id",
                table: "recherches_alternance",
                column: "utilisateur_id");

            migrationBuilder.CreateIndex(
                name: "IX_revisions_contributions_auteur_id",
                table: "revisions_contributions",
                column: "auteur_id");

            migrationBuilder.CreateIndex(
                name: "IX_revisions_contributions_classe_id",
                table: "revisions_contributions",
                column: "classe_id");

            migrationBuilder.CreateIndex(
                name: "IX_revisions_contributions_entite_type_entite_id_created_at",
                table: "revisions_contributions",
                columns: new[] { "entite_type", "entite_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_role_claims_role_id",
                table: "role_claims",
                column: "role_id");

            migrationBuilder.CreateIndex(
                name: "RoleNameIndex",
                table: "roles",
                column: "normalized_name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_suivis_devoirs_devoir_id_utilisateur_id",
                table: "suivis_devoirs",
                columns: new[] { "devoir_id", "utilisateur_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_suivis_devoirs_utilisateur_id",
                table: "suivis_devoirs",
                column: "utilisateur_id");

            migrationBuilder.CreateIndex(
                name: "IX_taches_personnelles_cours_id",
                table: "taches_personnelles",
                column: "cours_id");

            migrationBuilder.CreateIndex(
                name: "IX_taches_personnelles_utilisateur_id_deadline",
                table: "taches_personnelles",
                columns: new[] { "utilisateur_id", "deadline" });

            migrationBuilder.CreateIndex(
                name: "IX_utilisateur_claims_user_id",
                table: "utilisateur_claims",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_utilisateur_logins_user_id",
                table: "utilisateur_logins",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_utilisateur_roles_role_id",
                table: "utilisateur_roles",
                column: "role_id");

            migrationBuilder.CreateIndex(
                name: "EmailIndex",
                table: "utilisateurs",
                column: "normalized_email");

            migrationBuilder.CreateIndex(
                name: "IX_utilisateurs_classe_id",
                table: "utilisateurs",
                column: "classe_id");

            migrationBuilder.CreateIndex(
                name: "UserNameIndex",
                table: "utilisateurs",
                column: "normalized_user_name",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_annonces_classe_classes_classe_id",
                table: "annonces_classe",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_annonces_classe_utilisateurs_auteur_id",
                table: "annonces_classe",
                column: "auteur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_appareils_notifications_utilisateurs_utilisateur_id",
                table: "appareils_notifications",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_classes_utilisateurs_created_by_id",
                table: "classes",
                column: "created_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_utilisateurs_classes_classe_id",
                table: "utilisateurs");

            migrationBuilder.DropTable(
                name: "annonces_classe");

            migrationBuilder.DropTable(
                name: "appareils_notifications");

            migrationBuilder.DropTable(
                name: "demandes_adhesion_classe");

            migrationBuilder.DropTable(
                name: "evenements_personnels");

            migrationBuilder.DropTable(
                name: "messages_alternance");

            migrationBuilder.DropTable(
                name: "offres_favorites");

            migrationBuilder.DropTable(
                name: "preferences_notifications");

            migrationBuilder.DropTable(
                name: "recherches_alternance");

            migrationBuilder.DropTable(
                name: "revisions_contributions");

            migrationBuilder.DropTable(
                name: "role_claims");

            migrationBuilder.DropTable(
                name: "suivis_devoirs");

            migrationBuilder.DropTable(
                name: "taches_personnelles");

            migrationBuilder.DropTable(
                name: "utilisateur_claims");

            migrationBuilder.DropTable(
                name: "utilisateur_logins");

            migrationBuilder.DropTable(
                name: "utilisateur_roles");

            migrationBuilder.DropTable(
                name: "utilisateur_tokens");

            migrationBuilder.DropTable(
                name: "devoirs_collectifs");

            migrationBuilder.DropTable(
                name: "roles");

            migrationBuilder.DropTable(
                name: "cours");

            migrationBuilder.DropTable(
                name: "matieres");

            migrationBuilder.DropTable(
                name: "professeurs");

            migrationBuilder.DropTable(
                name: "classes");

            migrationBuilder.DropTable(
                name: "utilisateurs");
        }
    }
}
