using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace StudyFlow.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RenameBackendModelToEnglish : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_annonces_classe_classes_classe_id",
                table: "annonces_classe");

            migrationBuilder.DropForeignKey(
                name: "FK_annonces_classe_utilisateurs_auteur_id",
                table: "annonces_classe");

            migrationBuilder.DropForeignKey(
                name: "FK_appareils_notifications_utilisateurs_utilisateur_id",
                table: "appareils_notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_classes_utilisateurs_created_by_id",
                table: "classes");

            migrationBuilder.DropForeignKey(
                name: "FK_cours_classes_classe_id",
                table: "cours");

            migrationBuilder.DropForeignKey(
                name: "FK_cours_matieres_matiere_id",
                table: "cours");

            migrationBuilder.DropForeignKey(
                name: "FK_cours_professeurs_professeur_id",
                table: "cours");

            migrationBuilder.DropForeignKey(
                name: "FK_cours_utilisateurs_created_by_id",
                table: "cours");

            migrationBuilder.DropForeignKey(
                name: "FK_cours_utilisateurs_updated_by_id",
                table: "cours");

            migrationBuilder.DropForeignKey(
                name: "FK_demandes_adhesion_classe_classes_classe_id",
                table: "demandes_adhesion_classe");

            migrationBuilder.DropForeignKey(
                name: "FK_demandes_adhesion_classe_utilisateurs_decided_by_id",
                table: "demandes_adhesion_classe");

            migrationBuilder.DropForeignKey(
                name: "FK_demandes_adhesion_classe_utilisateurs_utilisateur_id",
                table: "demandes_adhesion_classe");

            migrationBuilder.DropForeignKey(
                name: "FK_devoirs_collectifs_classes_classe_id",
                table: "devoirs_collectifs");

            migrationBuilder.DropForeignKey(
                name: "FK_devoirs_collectifs_cours_cours_id",
                table: "devoirs_collectifs");

            migrationBuilder.DropForeignKey(
                name: "FK_devoirs_collectifs_utilisateurs_created_by_id",
                table: "devoirs_collectifs");

            migrationBuilder.DropForeignKey(
                name: "FK_devoirs_collectifs_utilisateurs_updated_by_id",
                table: "devoirs_collectifs");

            migrationBuilder.DropForeignKey(
                name: "FK_evenements_personnels_utilisateurs_utilisateur_id",
                table: "evenements_personnels");

            migrationBuilder.DropForeignKey(
                name: "FK_matieres_classes_classe_id",
                table: "matieres");

            migrationBuilder.DropForeignKey(
                name: "FK_matieres_utilisateurs_created_by_id",
                table: "matieres");

            migrationBuilder.DropForeignKey(
                name: "FK_messages_alternance_classes_classe_id",
                table: "messages_alternance");

            migrationBuilder.DropForeignKey(
                name: "FK_messages_alternance_utilisateurs_auteur_id",
                table: "messages_alternance");

            migrationBuilder.DropForeignKey(
                name: "FK_messages_alternance_utilisateurs_deleted_by_id",
                table: "messages_alternance");

            migrationBuilder.DropForeignKey(
                name: "FK_offres_favorites_utilisateurs_utilisateur_id",
                table: "offres_favorites");

            migrationBuilder.DropForeignKey(
                name: "FK_preferences_notifications_utilisateurs_utilisateur_id",
                table: "preferences_notifications");

            migrationBuilder.DropForeignKey(
                name: "FK_professeurs_classes_classe_id",
                table: "professeurs");

            migrationBuilder.DropForeignKey(
                name: "FK_professeurs_utilisateurs_created_by_id",
                table: "professeurs");

            migrationBuilder.DropForeignKey(
                name: "FK_recherches_alternance_utilisateurs_utilisateur_id",
                table: "recherches_alternance");

            migrationBuilder.DropForeignKey(
                name: "FK_refresh_tokens_utilisateurs_utilisateur_id",
                table: "refresh_tokens");

            migrationBuilder.DropForeignKey(
                name: "FK_revisions_contributions_classes_classe_id",
                table: "revisions_contributions");

            migrationBuilder.DropForeignKey(
                name: "FK_revisions_contributions_utilisateurs_auteur_id",
                table: "revisions_contributions");

            migrationBuilder.DropForeignKey(
                name: "FK_suivis_devoirs_devoirs_collectifs_devoir_id",
                table: "suivis_devoirs");

            migrationBuilder.DropForeignKey(
                name: "FK_suivis_devoirs_utilisateurs_utilisateur_id",
                table: "suivis_devoirs");

            migrationBuilder.DropForeignKey(
                name: "FK_taches_personnelles_cours_cours_id",
                table: "taches_personnelles");

            migrationBuilder.DropForeignKey(
                name: "FK_taches_personnelles_utilisateurs_utilisateur_id",
                table: "taches_personnelles");

            migrationBuilder.DropForeignKey(
                name: "FK_utilisateur_claims_utilisateurs_user_id",
                table: "utilisateur_claims");

            migrationBuilder.DropForeignKey(
                name: "FK_utilisateur_logins_utilisateurs_user_id",
                table: "utilisateur_logins");

            migrationBuilder.DropForeignKey(
                name: "FK_utilisateur_roles_roles_role_id",
                table: "utilisateur_roles");

            migrationBuilder.DropForeignKey(
                name: "FK_utilisateur_roles_utilisateurs_user_id",
                table: "utilisateur_roles");

            migrationBuilder.DropForeignKey(
                name: "FK_utilisateur_tokens_utilisateurs_user_id",
                table: "utilisateur_tokens");

            migrationBuilder.DropForeignKey(
                name: "FK_utilisateurs_classes_classe_id",
                table: "utilisateurs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_utilisateurs",
                table: "utilisateurs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_utilisateur_tokens",
                table: "utilisateur_tokens");

            migrationBuilder.DropPrimaryKey(
                name: "PK_utilisateur_roles",
                table: "utilisateur_roles");

            migrationBuilder.DropPrimaryKey(
                name: "PK_utilisateur_logins",
                table: "utilisateur_logins");

            migrationBuilder.DropPrimaryKey(
                name: "PK_utilisateur_claims",
                table: "utilisateur_claims");

            migrationBuilder.DropPrimaryKey(
                name: "PK_taches_personnelles",
                table: "taches_personnelles");

            migrationBuilder.DropPrimaryKey(
                name: "PK_suivis_devoirs",
                table: "suivis_devoirs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_revisions_contributions",
                table: "revisions_contributions");

            migrationBuilder.DropPrimaryKey(
                name: "PK_recherches_alternance",
                table: "recherches_alternance");

            migrationBuilder.DropPrimaryKey(
                name: "PK_professeurs",
                table: "professeurs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_preferences_notifications",
                table: "preferences_notifications");

            migrationBuilder.DropCheckConstraint(
                name: "ck_preferences_notifications_cours_rappel_minutes",
                table: "preferences_notifications");

            migrationBuilder.DropPrimaryKey(
                name: "PK_offres_favorites",
                table: "offres_favorites");

            migrationBuilder.DropPrimaryKey(
                name: "PK_messages_alternance",
                table: "messages_alternance");

            migrationBuilder.DropPrimaryKey(
                name: "PK_matieres",
                table: "matieres");

            migrationBuilder.DropPrimaryKey(
                name: "PK_evenements_personnels",
                table: "evenements_personnels");

            migrationBuilder.DropPrimaryKey(
                name: "PK_devoirs_collectifs",
                table: "devoirs_collectifs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_demandes_adhesion_classe",
                table: "demandes_adhesion_classe");

            migrationBuilder.DropIndex(
                name: "IX_demandes_adhesion_classe_utilisateur_id",
                table: "demandes_adhesion_classe");

            migrationBuilder.DropPrimaryKey(
                name: "PK_cours",
                table: "cours");

            migrationBuilder.DropPrimaryKey(
                name: "PK_classes",
                table: "classes");

            migrationBuilder.DropCheckConstraint(
                name: "ck_classes_annee_scolaire",
                table: "classes");

            migrationBuilder.DropPrimaryKey(
                name: "PK_appareils_notifications",
                table: "appareils_notifications");

            migrationBuilder.DropPrimaryKey(
                name: "PK_annonces_classe",
                table: "annonces_classe");

            migrationBuilder.RenameTable(
                name: "utilisateurs",
                newName: "users");

            migrationBuilder.RenameTable(
                name: "utilisateur_tokens",
                newName: "user_tokens");

            migrationBuilder.RenameTable(
                name: "utilisateur_roles",
                newName: "user_roles");

            migrationBuilder.RenameTable(
                name: "utilisateur_logins",
                newName: "user_logins");

            migrationBuilder.RenameTable(
                name: "utilisateur_claims",
                newName: "user_claims");

            migrationBuilder.RenameTable(
                name: "taches_personnelles",
                newName: "personal_tasks");

            migrationBuilder.RenameTable(
                name: "suivis_devoirs",
                newName: "homework_progress");

            migrationBuilder.RenameTable(
                name: "revisions_contributions",
                newName: "contribution_revisions");

            migrationBuilder.RenameTable(
                name: "recherches_alternance",
                newName: "apprenticeship_searches");

            migrationBuilder.RenameTable(
                name: "professeurs",
                newName: "teachers");

            migrationBuilder.RenameTable(
                name: "preferences_notifications",
                newName: "notification_preferences");

            migrationBuilder.RenameTable(
                name: "offres_favorites",
                newName: "favorite_offers");

            migrationBuilder.RenameTable(
                name: "messages_alternance",
                newName: "apprenticeship_messages");

            migrationBuilder.RenameTable(
                name: "matieres",
                newName: "subjects");

            migrationBuilder.RenameTable(
                name: "evenements_personnels",
                newName: "personal_events");

            migrationBuilder.RenameTable(
                name: "devoirs_collectifs",
                newName: "homework");

            migrationBuilder.RenameTable(
                name: "demandes_adhesion_classe",
                newName: "class_membership_requests");

            migrationBuilder.RenameTable(
                name: "cours",
                newName: "courses");

            migrationBuilder.RenameTable(
                name: "classes",
                newName: "school_classes");

            migrationBuilder.RenameTable(
                name: "appareils_notifications",
                newName: "notification_devices");

            migrationBuilder.RenameTable(
                name: "annonces_classe",
                newName: "class_announcements");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "refresh_tokens",
                newName: "user_id");

            migrationBuilder.RenameIndex(
                name: "IX_refresh_tokens_utilisateur_id_expires_at",
                table: "refresh_tokens",
                newName: "IX_refresh_tokens_user_id_expires_at");

            migrationBuilder.RenameColumn(
                name: "prenom",
                table: "users",
                newName: "first_name");

            migrationBuilder.RenameColumn(
                name: "est_actif",
                table: "users",
                newName: "is_active");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "users",
                newName: "school_class_id");

            migrationBuilder.RenameColumn(
                name: "nom",
                table: "users",
                newName: "last_name");

            migrationBuilder.RenameIndex(
                name: "IX_utilisateurs_classe_id",
                table: "users",
                newName: "IX_users_school_class_id");

            migrationBuilder.RenameIndex(
                name: "IX_utilisateur_roles_role_id",
                table: "user_roles",
                newName: "IX_user_roles_role_id");

            migrationBuilder.RenameIndex(
                name: "IX_utilisateur_logins_user_id",
                table: "user_logins",
                newName: "IX_user_logins_user_id");

            migrationBuilder.RenameIndex(
                name: "IX_utilisateur_claims_user_id",
                table: "user_claims",
                newName: "IX_user_claims_user_id");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "personal_tasks",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "notification_active",
                table: "personal_tasks",
                newName: "notifications_enabled");

            migrationBuilder.RenameColumn(
                name: "est_terminee",
                table: "personal_tasks",
                newName: "is_done");

            migrationBuilder.RenameColumn(
                name: "cours_id",
                table: "personal_tasks",
                newName: "course_id");

            migrationBuilder.RenameColumn(
                name: "titre",
                table: "personal_tasks",
                newName: "title");

            migrationBuilder.RenameColumn(
                name: "categorie",
                table: "personal_tasks",
                newName: "category");

            migrationBuilder.RenameIndex(
                name: "IX_taches_personnelles_utilisateur_id_deadline",
                table: "personal_tasks",
                newName: "IX_personal_tasks_user_id_deadline");

            migrationBuilder.RenameIndex(
                name: "IX_taches_personnelles_cours_id",
                table: "personal_tasks",
                newName: "IX_personal_tasks_course_id");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "homework_progress",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "notification_active",
                table: "homework_progress",
                newName: "notifications_enabled");

            migrationBuilder.RenameColumn(
                name: "devoir_id",
                table: "homework_progress",
                newName: "homework_id");

            migrationBuilder.RenameColumn(
                name: "est_termine",
                table: "homework_progress",
                newName: "is_done");

            migrationBuilder.RenameIndex(
                name: "IX_suivis_devoirs_utilisateur_id",
                table: "homework_progress",
                newName: "IX_homework_progress_user_id");

            migrationBuilder.RenameIndex(
                name: "IX_suivis_devoirs_devoir_id_utilisateur_id",
                table: "homework_progress",
                newName: "IX_homework_progress_homework_id_user_id");

            migrationBuilder.RenameColumn(
                name: "snapshot_chiffre",
                table: "contribution_revisions",
                newName: "encrypted_snapshot");

            migrationBuilder.RenameColumn(
                name: "entite_type",
                table: "contribution_revisions",
                newName: "entity_type");

            migrationBuilder.RenameColumn(
                name: "entite_id",
                table: "contribution_revisions",
                newName: "entity_id");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "contribution_revisions",
                newName: "school_class_id");

            migrationBuilder.RenameColumn(
                name: "auteur_id",
                table: "contribution_revisions",
                newName: "author_id");

            migrationBuilder.RenameIndex(
                name: "IX_revisions_contributions_entite_type_entite_id_created_at",
                table: "contribution_revisions",
                newName: "IX_contribution_revisions_entity_type_entity_id_created_at");

            migrationBuilder.RenameIndex(
                name: "IX_revisions_contributions_classe_id",
                table: "contribution_revisions",
                newName: "IX_contribution_revisions_school_class_id");

            migrationBuilder.RenameIndex(
                name: "IX_revisions_contributions_auteur_id",
                table: "contribution_revisions",
                newName: "IX_contribution_revisions_author_id");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "apprenticeship_searches",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "nom",
                table: "apprenticeship_searches",
                newName: "name");

            migrationBuilder.RenameColumn(
                name: "mots_cles",
                table: "apprenticeship_searches",
                newName: "keywords");

            migrationBuilder.RenameColumn(
                name: "localisation",
                table: "apprenticeship_searches",
                newName: "location");

            migrationBuilder.RenameColumn(
                name: "filtres_json",
                table: "apprenticeship_searches",
                newName: "filters_json");

            migrationBuilder.RenameColumn(
                name: "derniere_verification_at",
                table: "apprenticeship_searches",
                newName: "last_checked_at");

            migrationBuilder.RenameColumn(
                name: "alerte_active",
                table: "apprenticeship_searches",
                newName: "alert_enabled");

            migrationBuilder.RenameIndex(
                name: "IX_recherches_alternance_utilisateur_id",
                table: "apprenticeship_searches",
                newName: "IX_apprenticeship_searches_user_id");

            migrationBuilder.RenameColumn(
                name: "nom_recherche_hash",
                table: "teachers",
                newName: "search_name_hash");

            migrationBuilder.RenameColumn(
                name: "nom_affiche_chiffre",
                table: "teachers",
                newName: "encrypted_display_name");

            migrationBuilder.RenameColumn(
                name: "informations_chiffrees",
                table: "teachers",
                newName: "encrypted_information");

            migrationBuilder.RenameColumn(
                name: "est_actif",
                table: "teachers",
                newName: "is_active");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "teachers",
                newName: "school_class_id");

            migrationBuilder.RenameIndex(
                name: "IX_professeurs_created_by_id",
                table: "teachers",
                newName: "IX_teachers_created_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_professeurs_classe_id_nom_recherche_hash",
                table: "teachers",
                newName: "IX_teachers_school_class_id_search_name_hash");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "notification_preferences",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "devoirs_actifs",
                table: "notification_preferences",
                newName: "homework_enabled");

            migrationBuilder.RenameColumn(
                name: "cours_rappel_minutes",
                table: "notification_preferences",
                newName: "course_reminder_minutes");

            migrationBuilder.RenameColumn(
                name: "cours_actifs",
                table: "notification_preferences",
                newName: "courses_enabled");

            migrationBuilder.RenameColumn(
                name: "alternances_actives",
                table: "notification_preferences",
                newName: "apprenticeships_enabled");

            migrationBuilder.RenameIndex(
                name: "IX_preferences_notifications_utilisateur_id",
                table: "notification_preferences",
                newName: "IX_notification_preferences_user_id");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "favorite_offers",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "entreprise",
                table: "favorite_offers",
                newName: "company");

            migrationBuilder.RenameColumn(
                name: "titre",
                table: "favorite_offers",
                newName: "title");

            migrationBuilder.RenameColumn(
                name: "offre_externe_id",
                table: "favorite_offers",
                newName: "external_offer_id");

            migrationBuilder.RenameColumn(
                name: "localisation",
                table: "favorite_offers",
                newName: "location");

            migrationBuilder.RenameColumn(
                name: "enregistree_at",
                table: "favorite_offers",
                newName: "saved_at");

            migrationBuilder.RenameColumn(
                name: "date_publication",
                table: "favorite_offers",
                newName: "published_at");

            migrationBuilder.RenameIndex(
                name: "IX_offres_favorites_utilisateur_id_source_offre_externe_id",
                table: "favorite_offers",
                newName: "IX_favorite_offers_user_id_source_external_offer_id");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "apprenticeship_messages",
                newName: "school_class_id");

            migrationBuilder.RenameColumn(
                name: "auteur_id",
                table: "apprenticeship_messages",
                newName: "author_id");

            migrationBuilder.RenameColumn(
                name: "lien_chiffre",
                table: "apprenticeship_messages",
                newName: "encrypted_link");

            migrationBuilder.RenameColumn(
                name: "contenu_chiffre",
                table: "apprenticeship_messages",
                newName: "encrypted_content");

            migrationBuilder.RenameIndex(
                name: "IX_messages_alternance_deleted_by_id",
                table: "apprenticeship_messages",
                newName: "IX_apprenticeship_messages_deleted_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_messages_alternance_classe_id_created_at",
                table: "apprenticeship_messages",
                newName: "IX_apprenticeship_messages_school_class_id_created_at");

            migrationBuilder.RenameIndex(
                name: "IX_messages_alternance_auteur_id",
                table: "apprenticeship_messages",
                newName: "IX_apprenticeship_messages_author_id");

            migrationBuilder.RenameColumn(
                name: "nom",
                table: "subjects",
                newName: "name");

            migrationBuilder.RenameColumn(
                name: "est_active",
                table: "subjects",
                newName: "is_active");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "subjects",
                newName: "school_class_id");

            migrationBuilder.RenameIndex(
                name: "IX_matieres_created_by_id",
                table: "subjects",
                newName: "IX_subjects_created_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_matieres_classe_id_nom",
                table: "subjects",
                newName: "IX_subjects_school_class_id_name");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "personal_events",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "notification_active",
                table: "personal_events",
                newName: "notifications_enabled");

            migrationBuilder.RenameColumn(
                name: "donnees_chiffrees",
                table: "personal_events",
                newName: "encrypted_data");

            migrationBuilder.RenameColumn(
                name: "date_jour",
                table: "personal_events",
                newName: "day");

            migrationBuilder.RenameColumn(
                name: "categorie",
                table: "personal_events",
                newName: "category");

            migrationBuilder.RenameIndex(
                name: "IX_evenements_personnels_utilisateur_id_date_jour",
                table: "personal_events",
                newName: "IX_personal_events_user_id_day");

            migrationBuilder.RenameColumn(
                name: "cours_id",
                table: "homework",
                newName: "course_id");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "homework",
                newName: "school_class_id");

            migrationBuilder.RenameColumn(
                name: "titre",
                table: "homework",
                newName: "title");

            migrationBuilder.RenameIndex(
                name: "IX_devoirs_collectifs_updated_by_id",
                table: "homework",
                newName: "IX_homework_updated_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_devoirs_collectifs_created_by_id",
                table: "homework",
                newName: "IX_homework_created_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_devoirs_collectifs_cours_id",
                table: "homework",
                newName: "IX_homework_course_id");

            migrationBuilder.RenameIndex(
                name: "IX_devoirs_collectifs_classe_id_deadline",
                table: "homework",
                newName: "IX_homework_school_class_id_deadline");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "class_membership_requests",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "statut",
                table: "class_membership_requests",
                newName: "status");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "class_membership_requests",
                newName: "school_class_id");

            migrationBuilder.RenameIndex(
                name: "IX_demandes_adhesion_classe_utilisateur_id_statut",
                table: "class_membership_requests",
                newName: "IX_class_membership_requests_user_id_status");

            migrationBuilder.RenameIndex(
                name: "IX_demandes_adhesion_classe_decided_by_id",
                table: "class_membership_requests",
                newName: "IX_class_membership_requests_decided_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_demandes_adhesion_classe_classe_id_statut_requested_at",
                table: "class_membership_requests",
                newName: "IX_class_membership_requests_school_class_id_status_requested_~");

            migrationBuilder.RenameColumn(
                name: "professeur_id",
                table: "courses",
                newName: "teacher_id");

            migrationBuilder.RenameColumn(
                name: "matiere_id",
                table: "courses",
                newName: "subject_id");

            migrationBuilder.RenameColumn(
                name: "est_annule",
                table: "courses",
                newName: "is_cancelled");

            migrationBuilder.RenameColumn(
                name: "donnees_chiffrees",
                table: "courses",
                newName: "encrypted_data");

            migrationBuilder.RenameColumn(
                name: "date_jour",
                table: "courses",
                newName: "day");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "courses",
                newName: "school_class_id");

            migrationBuilder.RenameColumn(
                name: "serie_id",
                table: "courses",
                newName: "series_id");

            migrationBuilder.RenameIndex(
                name: "IX_cours_updated_by_id",
                table: "courses",
                newName: "IX_courses_updated_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_cours_serie_id",
                table: "courses",
                newName: "IX_courses_series_id");

            migrationBuilder.RenameIndex(
                name: "IX_cours_professeur_id",
                table: "courses",
                newName: "IX_courses_teacher_id");

            migrationBuilder.RenameIndex(
                name: "IX_cours_matiere_id",
                table: "courses",
                newName: "IX_courses_subject_id");

            migrationBuilder.RenameIndex(
                name: "IX_cours_created_by_id",
                table: "courses",
                newName: "IX_courses_created_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_cours_classe_id_date_jour",
                table: "courses",
                newName: "IX_courses_school_class_id_day");

            migrationBuilder.RenameColumn(
                name: "nom",
                table: "school_classes",
                newName: "name");

            migrationBuilder.RenameColumn(
                name: "est_active",
                table: "school_classes",
                newName: "is_active");

            migrationBuilder.RenameColumn(
                name: "code_acces_updated_at",
                table: "school_classes",
                newName: "access_code_updated_at");

            migrationBuilder.RenameColumn(
                name: "code_acces_hash",
                table: "school_classes",
                newName: "access_code_hash");

            migrationBuilder.RenameColumn(
                name: "code_acces_chiffre",
                table: "school_classes",
                newName: "encrypted_access_code");

            migrationBuilder.RenameColumn(
                name: "annee_scolaire",
                table: "school_classes",
                newName: "school_year");

            migrationBuilder.RenameIndex(
                name: "IX_classes_nom",
                table: "school_classes",
                newName: "IX_school_classes_name");

            migrationBuilder.RenameIndex(
                name: "IX_classes_created_by_id",
                table: "school_classes",
                newName: "IX_school_classes_created_by_id");

            migrationBuilder.RenameColumn(
                name: "utilisateur_id",
                table: "notification_devices",
                newName: "user_id");

            migrationBuilder.RenameColumn(
                name: "plateforme",
                table: "notification_devices",
                newName: "platform");

            migrationBuilder.RenameColumn(
                name: "derniere_activite_at",
                table: "notification_devices",
                newName: "last_seen_at");

            migrationBuilder.RenameIndex(
                name: "IX_appareils_notifications_utilisateur_id",
                table: "notification_devices",
                newName: "IX_notification_devices_user_id");

            migrationBuilder.RenameIndex(
                name: "IX_appareils_notifications_token",
                table: "notification_devices",
                newName: "IX_notification_devices_token");

            migrationBuilder.RenameColumn(
                name: "classe_id",
                table: "class_announcements",
                newName: "school_class_id");

            migrationBuilder.RenameColumn(
                name: "auteur_id",
                table: "class_announcements",
                newName: "author_id");

            migrationBuilder.RenameColumn(
                name: "est_epingle",
                table: "class_announcements",
                newName: "is_pinned");

            migrationBuilder.RenameColumn(
                name: "contenu",
                table: "class_announcements",
                newName: "content");

            migrationBuilder.RenameIndex(
                name: "IX_annonces_classe_classe_id_est_epingle",
                table: "class_announcements",
                newName: "IX_class_announcements_school_class_id_is_pinned");

            migrationBuilder.RenameIndex(
                name: "IX_annonces_classe_auteur_id",
                table: "class_announcements",
                newName: "IX_class_announcements_author_id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_users",
                table: "users",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_user_tokens",
                table: "user_tokens",
                columns: new[] { "user_id", "login_provider", "name" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_user_roles",
                table: "user_roles",
                columns: new[] { "user_id", "role_id" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_user_logins",
                table: "user_logins",
                columns: new[] { "login_provider", "provider_key" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_user_claims",
                table: "user_claims",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_personal_tasks",
                table: "personal_tasks",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_homework_progress",
                table: "homework_progress",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_contribution_revisions",
                table: "contribution_revisions",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_apprenticeship_searches",
                table: "apprenticeship_searches",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_teachers",
                table: "teachers",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_notification_preferences",
                table: "notification_preferences",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_favorite_offers",
                table: "favorite_offers",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_apprenticeship_messages",
                table: "apprenticeship_messages",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_subjects",
                table: "subjects",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_personal_events",
                table: "personal_events",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_homework",
                table: "homework",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_class_membership_requests",
                table: "class_membership_requests",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_courses",
                table: "courses",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_school_classes",
                table: "school_classes",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_notification_devices",
                table: "notification_devices",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_class_announcements",
                table: "class_announcements",
                column: "id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_notification_preferences_course_reminder_minutes",
                table: "notification_preferences",
                sql: "course_reminder_minutes IN (0, 5, 10, 15, 30, 60)");

            migrationBuilder.CreateIndex(
                name: "IX_class_membership_requests_user_id",
                table: "class_membership_requests",
                column: "user_id",
                unique: true,
                filter: "status = 'Pending'");

            migrationBuilder.AddCheckConstraint(
                name: "ck_school_classes_school_year",
                table: "school_classes",
                sql: "school_year ~ '^[0-9]{4}-[0-9]{4}$'");

            migrationBuilder.AddForeignKey(
                name: "FK_apprenticeship_messages_school_classes_school_class_id",
                table: "apprenticeship_messages",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_apprenticeship_messages_users_author_id",
                table: "apprenticeship_messages",
                column: "author_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_apprenticeship_messages_users_deleted_by_id",
                table: "apprenticeship_messages",
                column: "deleted_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_apprenticeship_searches_users_user_id",
                table: "apprenticeship_searches",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_class_announcements_school_classes_school_class_id",
                table: "class_announcements",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_class_announcements_users_author_id",
                table: "class_announcements",
                column: "author_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_class_membership_requests_school_classes_school_class_id",
                table: "class_membership_requests",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_class_membership_requests_users_decided_by_id",
                table: "class_membership_requests",
                column: "decided_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_class_membership_requests_users_user_id",
                table: "class_membership_requests",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_contribution_revisions_school_classes_school_class_id",
                table: "contribution_revisions",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_contribution_revisions_users_author_id",
                table: "contribution_revisions",
                column: "author_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_courses_school_classes_school_class_id",
                table: "courses",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_courses_subjects_subject_id",
                table: "courses",
                column: "subject_id",
                principalTable: "subjects",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_courses_teachers_teacher_id",
                table: "courses",
                column: "teacher_id",
                principalTable: "teachers",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_courses_users_created_by_id",
                table: "courses",
                column: "created_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_courses_users_updated_by_id",
                table: "courses",
                column: "updated_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_favorite_offers_users_user_id",
                table: "favorite_offers",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_homework_courses_course_id",
                table: "homework",
                column: "course_id",
                principalTable: "courses",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_homework_school_classes_school_class_id",
                table: "homework",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_homework_users_created_by_id",
                table: "homework",
                column: "created_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_homework_users_updated_by_id",
                table: "homework",
                column: "updated_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_homework_progress_homework_homework_id",
                table: "homework_progress",
                column: "homework_id",
                principalTable: "homework",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_homework_progress_users_user_id",
                table: "homework_progress",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_notification_devices_users_user_id",
                table: "notification_devices",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_notification_preferences_users_user_id",
                table: "notification_preferences",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_personal_events_users_user_id",
                table: "personal_events",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_personal_tasks_courses_course_id",
                table: "personal_tasks",
                column: "course_id",
                principalTable: "courses",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_personal_tasks_users_user_id",
                table: "personal_tasks",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_refresh_tokens_users_user_id",
                table: "refresh_tokens",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_school_classes_users_created_by_id",
                table: "school_classes",
                column: "created_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_subjects_school_classes_school_class_id",
                table: "subjects",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_subjects_users_created_by_id",
                table: "subjects",
                column: "created_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_teachers_school_classes_school_class_id",
                table: "teachers",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_teachers_users_created_by_id",
                table: "teachers",
                column: "created_by_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_user_claims_users_user_id",
                table: "user_claims",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_user_logins_users_user_id",
                table: "user_logins",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_user_roles_roles_role_id",
                table: "user_roles",
                column: "role_id",
                principalTable: "roles",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_user_roles_users_user_id",
                table: "user_roles",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_user_tokens_users_user_id",
                table: "user_tokens",
                column: "user_id",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_users_school_classes_school_class_id",
                table: "users",
                column: "school_class_id",
                principalTable: "school_classes",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_apprenticeship_messages_school_classes_school_class_id",
                table: "apprenticeship_messages");

            migrationBuilder.DropForeignKey(
                name: "FK_apprenticeship_messages_users_author_id",
                table: "apprenticeship_messages");

            migrationBuilder.DropForeignKey(
                name: "FK_apprenticeship_messages_users_deleted_by_id",
                table: "apprenticeship_messages");

            migrationBuilder.DropForeignKey(
                name: "FK_apprenticeship_searches_users_user_id",
                table: "apprenticeship_searches");

            migrationBuilder.DropForeignKey(
                name: "FK_class_announcements_school_classes_school_class_id",
                table: "class_announcements");

            migrationBuilder.DropForeignKey(
                name: "FK_class_announcements_users_author_id",
                table: "class_announcements");

            migrationBuilder.DropForeignKey(
                name: "FK_class_membership_requests_school_classes_school_class_id",
                table: "class_membership_requests");

            migrationBuilder.DropForeignKey(
                name: "FK_class_membership_requests_users_decided_by_id",
                table: "class_membership_requests");

            migrationBuilder.DropForeignKey(
                name: "FK_class_membership_requests_users_user_id",
                table: "class_membership_requests");

            migrationBuilder.DropForeignKey(
                name: "FK_contribution_revisions_school_classes_school_class_id",
                table: "contribution_revisions");

            migrationBuilder.DropForeignKey(
                name: "FK_contribution_revisions_users_author_id",
                table: "contribution_revisions");

            migrationBuilder.DropForeignKey(
                name: "FK_courses_school_classes_school_class_id",
                table: "courses");

            migrationBuilder.DropForeignKey(
                name: "FK_courses_subjects_subject_id",
                table: "courses");

            migrationBuilder.DropForeignKey(
                name: "FK_courses_teachers_teacher_id",
                table: "courses");

            migrationBuilder.DropForeignKey(
                name: "FK_courses_users_created_by_id",
                table: "courses");

            migrationBuilder.DropForeignKey(
                name: "FK_courses_users_updated_by_id",
                table: "courses");

            migrationBuilder.DropForeignKey(
                name: "FK_favorite_offers_users_user_id",
                table: "favorite_offers");

            migrationBuilder.DropForeignKey(
                name: "FK_homework_courses_course_id",
                table: "homework");

            migrationBuilder.DropForeignKey(
                name: "FK_homework_school_classes_school_class_id",
                table: "homework");

            migrationBuilder.DropForeignKey(
                name: "FK_homework_users_created_by_id",
                table: "homework");

            migrationBuilder.DropForeignKey(
                name: "FK_homework_users_updated_by_id",
                table: "homework");

            migrationBuilder.DropForeignKey(
                name: "FK_homework_progress_homework_homework_id",
                table: "homework_progress");

            migrationBuilder.DropForeignKey(
                name: "FK_homework_progress_users_user_id",
                table: "homework_progress");

            migrationBuilder.DropForeignKey(
                name: "FK_notification_devices_users_user_id",
                table: "notification_devices");

            migrationBuilder.DropForeignKey(
                name: "FK_notification_preferences_users_user_id",
                table: "notification_preferences");

            migrationBuilder.DropForeignKey(
                name: "FK_personal_events_users_user_id",
                table: "personal_events");

            migrationBuilder.DropForeignKey(
                name: "FK_personal_tasks_courses_course_id",
                table: "personal_tasks");

            migrationBuilder.DropForeignKey(
                name: "FK_personal_tasks_users_user_id",
                table: "personal_tasks");

            migrationBuilder.DropForeignKey(
                name: "FK_refresh_tokens_users_user_id",
                table: "refresh_tokens");

            migrationBuilder.DropForeignKey(
                name: "FK_school_classes_users_created_by_id",
                table: "school_classes");

            migrationBuilder.DropForeignKey(
                name: "FK_subjects_school_classes_school_class_id",
                table: "subjects");

            migrationBuilder.DropForeignKey(
                name: "FK_subjects_users_created_by_id",
                table: "subjects");

            migrationBuilder.DropForeignKey(
                name: "FK_teachers_school_classes_school_class_id",
                table: "teachers");

            migrationBuilder.DropForeignKey(
                name: "FK_teachers_users_created_by_id",
                table: "teachers");

            migrationBuilder.DropForeignKey(
                name: "FK_user_claims_users_user_id",
                table: "user_claims");

            migrationBuilder.DropForeignKey(
                name: "FK_user_logins_users_user_id",
                table: "user_logins");

            migrationBuilder.DropForeignKey(
                name: "FK_user_roles_roles_role_id",
                table: "user_roles");

            migrationBuilder.DropForeignKey(
                name: "FK_user_roles_users_user_id",
                table: "user_roles");

            migrationBuilder.DropForeignKey(
                name: "FK_user_tokens_users_user_id",
                table: "user_tokens");

            migrationBuilder.DropForeignKey(
                name: "FK_users_school_classes_school_class_id",
                table: "users");

            migrationBuilder.DropPrimaryKey(
                name: "PK_users",
                table: "users");

            migrationBuilder.DropPrimaryKey(
                name: "PK_user_tokens",
                table: "user_tokens");

            migrationBuilder.DropPrimaryKey(
                name: "PK_user_roles",
                table: "user_roles");

            migrationBuilder.DropPrimaryKey(
                name: "PK_user_logins",
                table: "user_logins");

            migrationBuilder.DropPrimaryKey(
                name: "PK_user_claims",
                table: "user_claims");

            migrationBuilder.DropPrimaryKey(
                name: "PK_teachers",
                table: "teachers");

            migrationBuilder.DropPrimaryKey(
                name: "PK_subjects",
                table: "subjects");

            migrationBuilder.DropPrimaryKey(
                name: "PK_school_classes",
                table: "school_classes");

            migrationBuilder.DropCheckConstraint(
                name: "ck_school_classes_school_year",
                table: "school_classes");

            migrationBuilder.DropPrimaryKey(
                name: "PK_personal_tasks",
                table: "personal_tasks");

            migrationBuilder.DropPrimaryKey(
                name: "PK_personal_events",
                table: "personal_events");

            migrationBuilder.DropPrimaryKey(
                name: "PK_notification_preferences",
                table: "notification_preferences");

            migrationBuilder.DropCheckConstraint(
                name: "ck_notification_preferences_course_reminder_minutes",
                table: "notification_preferences");

            migrationBuilder.DropPrimaryKey(
                name: "PK_notification_devices",
                table: "notification_devices");

            migrationBuilder.DropPrimaryKey(
                name: "PK_homework_progress",
                table: "homework_progress");

            migrationBuilder.DropPrimaryKey(
                name: "PK_homework",
                table: "homework");

            migrationBuilder.DropPrimaryKey(
                name: "PK_favorite_offers",
                table: "favorite_offers");

            migrationBuilder.DropPrimaryKey(
                name: "PK_courses",
                table: "courses");

            migrationBuilder.DropPrimaryKey(
                name: "PK_contribution_revisions",
                table: "contribution_revisions");

            migrationBuilder.DropPrimaryKey(
                name: "PK_class_membership_requests",
                table: "class_membership_requests");

            migrationBuilder.DropIndex(
                name: "IX_class_membership_requests_user_id",
                table: "class_membership_requests");

            migrationBuilder.DropPrimaryKey(
                name: "PK_class_announcements",
                table: "class_announcements");

            migrationBuilder.DropPrimaryKey(
                name: "PK_apprenticeship_searches",
                table: "apprenticeship_searches");

            migrationBuilder.DropPrimaryKey(
                name: "PK_apprenticeship_messages",
                table: "apprenticeship_messages");

            migrationBuilder.RenameTable(
                name: "users",
                newName: "utilisateurs");

            migrationBuilder.RenameTable(
                name: "user_tokens",
                newName: "utilisateur_tokens");

            migrationBuilder.RenameTable(
                name: "user_roles",
                newName: "utilisateur_roles");

            migrationBuilder.RenameTable(
                name: "user_logins",
                newName: "utilisateur_logins");

            migrationBuilder.RenameTable(
                name: "user_claims",
                newName: "utilisateur_claims");

            migrationBuilder.RenameTable(
                name: "teachers",
                newName: "professeurs");

            migrationBuilder.RenameTable(
                name: "subjects",
                newName: "matieres");

            migrationBuilder.RenameTable(
                name: "school_classes",
                newName: "classes");

            migrationBuilder.RenameTable(
                name: "personal_tasks",
                newName: "taches_personnelles");

            migrationBuilder.RenameTable(
                name: "personal_events",
                newName: "evenements_personnels");

            migrationBuilder.RenameTable(
                name: "notification_preferences",
                newName: "preferences_notifications");

            migrationBuilder.RenameTable(
                name: "notification_devices",
                newName: "appareils_notifications");

            migrationBuilder.RenameTable(
                name: "homework_progress",
                newName: "suivis_devoirs");

            migrationBuilder.RenameTable(
                name: "homework",
                newName: "devoirs_collectifs");

            migrationBuilder.RenameTable(
                name: "favorite_offers",
                newName: "offres_favorites");

            migrationBuilder.RenameTable(
                name: "courses",
                newName: "cours");

            migrationBuilder.RenameTable(
                name: "contribution_revisions",
                newName: "revisions_contributions");

            migrationBuilder.RenameTable(
                name: "class_membership_requests",
                newName: "demandes_adhesion_classe");

            migrationBuilder.RenameTable(
                name: "class_announcements",
                newName: "annonces_classe");

            migrationBuilder.RenameTable(
                name: "apprenticeship_searches",
                newName: "recherches_alternance");

            migrationBuilder.RenameTable(
                name: "apprenticeship_messages",
                newName: "messages_alternance");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "refresh_tokens",
                newName: "utilisateur_id");

            migrationBuilder.RenameIndex(
                name: "IX_refresh_tokens_user_id_expires_at",
                table: "refresh_tokens",
                newName: "IX_refresh_tokens_utilisateur_id_expires_at");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "utilisateurs",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "is_active",
                table: "utilisateurs",
                newName: "est_actif");

            migrationBuilder.RenameColumn(
                name: "first_name",
                table: "utilisateurs",
                newName: "prenom");

            migrationBuilder.RenameColumn(
                name: "last_name",
                table: "utilisateurs",
                newName: "nom");

            migrationBuilder.RenameIndex(
                name: "IX_users_school_class_id",
                table: "utilisateurs",
                newName: "IX_utilisateurs_classe_id");

            migrationBuilder.RenameIndex(
                name: "IX_user_roles_role_id",
                table: "utilisateur_roles",
                newName: "IX_utilisateur_roles_role_id");

            migrationBuilder.RenameIndex(
                name: "IX_user_logins_user_id",
                table: "utilisateur_logins",
                newName: "IX_utilisateur_logins_user_id");

            migrationBuilder.RenameIndex(
                name: "IX_user_claims_user_id",
                table: "utilisateur_claims",
                newName: "IX_utilisateur_claims_user_id");

            migrationBuilder.RenameColumn(
                name: "search_name_hash",
                table: "professeurs",
                newName: "nom_recherche_hash");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "professeurs",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "is_active",
                table: "professeurs",
                newName: "est_actif");

            migrationBuilder.RenameColumn(
                name: "encrypted_information",
                table: "professeurs",
                newName: "informations_chiffrees");

            migrationBuilder.RenameColumn(
                name: "encrypted_display_name",
                table: "professeurs",
                newName: "nom_affiche_chiffre");

            migrationBuilder.RenameIndex(
                name: "IX_teachers_school_class_id_search_name_hash",
                table: "professeurs",
                newName: "IX_professeurs_classe_id_nom_recherche_hash");

            migrationBuilder.RenameIndex(
                name: "IX_teachers_created_by_id",
                table: "professeurs",
                newName: "IX_professeurs_created_by_id");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "matieres",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "name",
                table: "matieres",
                newName: "nom");

            migrationBuilder.RenameColumn(
                name: "is_active",
                table: "matieres",
                newName: "est_active");

            migrationBuilder.RenameIndex(
                name: "IX_subjects_school_class_id_name",
                table: "matieres",
                newName: "IX_matieres_classe_id_nom");

            migrationBuilder.RenameIndex(
                name: "IX_subjects_created_by_id",
                table: "matieres",
                newName: "IX_matieres_created_by_id");

            migrationBuilder.RenameColumn(
                name: "school_year",
                table: "classes",
                newName: "annee_scolaire");

            migrationBuilder.RenameColumn(
                name: "name",
                table: "classes",
                newName: "nom");

            migrationBuilder.RenameColumn(
                name: "is_active",
                table: "classes",
                newName: "est_active");

            migrationBuilder.RenameColumn(
                name: "encrypted_access_code",
                table: "classes",
                newName: "code_acces_chiffre");

            migrationBuilder.RenameColumn(
                name: "access_code_updated_at",
                table: "classes",
                newName: "code_acces_updated_at");

            migrationBuilder.RenameColumn(
                name: "access_code_hash",
                table: "classes",
                newName: "code_acces_hash");

            migrationBuilder.RenameIndex(
                name: "IX_school_classes_name",
                table: "classes",
                newName: "IX_classes_nom");

            migrationBuilder.RenameIndex(
                name: "IX_school_classes_created_by_id",
                table: "classes",
                newName: "IX_classes_created_by_id");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "taches_personnelles",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "notifications_enabled",
                table: "taches_personnelles",
                newName: "notification_active");

            migrationBuilder.RenameColumn(
                name: "is_done",
                table: "taches_personnelles",
                newName: "est_terminee");

            migrationBuilder.RenameColumn(
                name: "course_id",
                table: "taches_personnelles",
                newName: "cours_id");

            migrationBuilder.RenameColumn(
                name: "title",
                table: "taches_personnelles",
                newName: "titre");

            migrationBuilder.RenameColumn(
                name: "category",
                table: "taches_personnelles",
                newName: "categorie");

            migrationBuilder.RenameIndex(
                name: "IX_personal_tasks_user_id_deadline",
                table: "taches_personnelles",
                newName: "IX_taches_personnelles_utilisateur_id_deadline");

            migrationBuilder.RenameIndex(
                name: "IX_personal_tasks_course_id",
                table: "taches_personnelles",
                newName: "IX_taches_personnelles_cours_id");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "evenements_personnels",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "notifications_enabled",
                table: "evenements_personnels",
                newName: "notification_active");

            migrationBuilder.RenameColumn(
                name: "encrypted_data",
                table: "evenements_personnels",
                newName: "donnees_chiffrees");

            migrationBuilder.RenameColumn(
                name: "day",
                table: "evenements_personnels",
                newName: "date_jour");

            migrationBuilder.RenameColumn(
                name: "category",
                table: "evenements_personnels",
                newName: "categorie");

            migrationBuilder.RenameIndex(
                name: "IX_personal_events_user_id_day",
                table: "evenements_personnels",
                newName: "IX_evenements_personnels_utilisateur_id_date_jour");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "preferences_notifications",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "homework_enabled",
                table: "preferences_notifications",
                newName: "devoirs_actifs");

            migrationBuilder.RenameColumn(
                name: "courses_enabled",
                table: "preferences_notifications",
                newName: "cours_actifs");

            migrationBuilder.RenameColumn(
                name: "course_reminder_minutes",
                table: "preferences_notifications",
                newName: "cours_rappel_minutes");

            migrationBuilder.RenameColumn(
                name: "apprenticeships_enabled",
                table: "preferences_notifications",
                newName: "alternances_actives");

            migrationBuilder.RenameIndex(
                name: "IX_notification_preferences_user_id",
                table: "preferences_notifications",
                newName: "IX_preferences_notifications_utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "appareils_notifications",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "platform",
                table: "appareils_notifications",
                newName: "plateforme");

            migrationBuilder.RenameColumn(
                name: "last_seen_at",
                table: "appareils_notifications",
                newName: "derniere_activite_at");

            migrationBuilder.RenameIndex(
                name: "IX_notification_devices_user_id",
                table: "appareils_notifications",
                newName: "IX_appareils_notifications_utilisateur_id");

            migrationBuilder.RenameIndex(
                name: "IX_notification_devices_token",
                table: "appareils_notifications",
                newName: "IX_appareils_notifications_token");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "suivis_devoirs",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "notifications_enabled",
                table: "suivis_devoirs",
                newName: "notification_active");

            migrationBuilder.RenameColumn(
                name: "homework_id",
                table: "suivis_devoirs",
                newName: "devoir_id");

            migrationBuilder.RenameColumn(
                name: "is_done",
                table: "suivis_devoirs",
                newName: "est_termine");

            migrationBuilder.RenameIndex(
                name: "IX_homework_progress_user_id",
                table: "suivis_devoirs",
                newName: "IX_suivis_devoirs_utilisateur_id");

            migrationBuilder.RenameIndex(
                name: "IX_homework_progress_homework_id_user_id",
                table: "suivis_devoirs",
                newName: "IX_suivis_devoirs_devoir_id_utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "devoirs_collectifs",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "course_id",
                table: "devoirs_collectifs",
                newName: "cours_id");

            migrationBuilder.RenameColumn(
                name: "title",
                table: "devoirs_collectifs",
                newName: "titre");

            migrationBuilder.RenameIndex(
                name: "IX_homework_updated_by_id",
                table: "devoirs_collectifs",
                newName: "IX_devoirs_collectifs_updated_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_homework_school_class_id_deadline",
                table: "devoirs_collectifs",
                newName: "IX_devoirs_collectifs_classe_id_deadline");

            migrationBuilder.RenameIndex(
                name: "IX_homework_created_by_id",
                table: "devoirs_collectifs",
                newName: "IX_devoirs_collectifs_created_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_homework_course_id",
                table: "devoirs_collectifs",
                newName: "IX_devoirs_collectifs_cours_id");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "offres_favorites",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "company",
                table: "offres_favorites",
                newName: "entreprise");

            migrationBuilder.RenameColumn(
                name: "title",
                table: "offres_favorites",
                newName: "titre");

            migrationBuilder.RenameColumn(
                name: "saved_at",
                table: "offres_favorites",
                newName: "enregistree_at");

            migrationBuilder.RenameColumn(
                name: "published_at",
                table: "offres_favorites",
                newName: "date_publication");

            migrationBuilder.RenameColumn(
                name: "location",
                table: "offres_favorites",
                newName: "localisation");

            migrationBuilder.RenameColumn(
                name: "external_offer_id",
                table: "offres_favorites",
                newName: "offre_externe_id");

            migrationBuilder.RenameIndex(
                name: "IX_favorite_offers_user_id_source_external_offer_id",
                table: "offres_favorites",
                newName: "IX_offres_favorites_utilisateur_id_source_offre_externe_id");

            migrationBuilder.RenameColumn(
                name: "teacher_id",
                table: "cours",
                newName: "professeur_id");

            migrationBuilder.RenameColumn(
                name: "subject_id",
                table: "cours",
                newName: "matiere_id");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "cours",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "is_cancelled",
                table: "cours",
                newName: "est_annule");

            migrationBuilder.RenameColumn(
                name: "encrypted_data",
                table: "cours",
                newName: "donnees_chiffrees");

            migrationBuilder.RenameColumn(
                name: "day",
                table: "cours",
                newName: "date_jour");

            migrationBuilder.RenameColumn(
                name: "series_id",
                table: "cours",
                newName: "serie_id");

            migrationBuilder.RenameIndex(
                name: "IX_courses_updated_by_id",
                table: "cours",
                newName: "IX_cours_updated_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_courses_teacher_id",
                table: "cours",
                newName: "IX_cours_professeur_id");

            migrationBuilder.RenameIndex(
                name: "IX_courses_subject_id",
                table: "cours",
                newName: "IX_cours_matiere_id");

            migrationBuilder.RenameIndex(
                name: "IX_courses_series_id",
                table: "cours",
                newName: "IX_cours_serie_id");

            migrationBuilder.RenameIndex(
                name: "IX_courses_school_class_id_day",
                table: "cours",
                newName: "IX_cours_classe_id_date_jour");

            migrationBuilder.RenameIndex(
                name: "IX_courses_created_by_id",
                table: "cours",
                newName: "IX_cours_created_by_id");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "revisions_contributions",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "entity_type",
                table: "revisions_contributions",
                newName: "entite_type");

            migrationBuilder.RenameColumn(
                name: "entity_id",
                table: "revisions_contributions",
                newName: "entite_id");

            migrationBuilder.RenameColumn(
                name: "encrypted_snapshot",
                table: "revisions_contributions",
                newName: "snapshot_chiffre");

            migrationBuilder.RenameColumn(
                name: "author_id",
                table: "revisions_contributions",
                newName: "auteur_id");

            migrationBuilder.RenameIndex(
                name: "IX_contribution_revisions_school_class_id",
                table: "revisions_contributions",
                newName: "IX_revisions_contributions_classe_id");

            migrationBuilder.RenameIndex(
                name: "IX_contribution_revisions_entity_type_entity_id_created_at",
                table: "revisions_contributions",
                newName: "IX_revisions_contributions_entite_type_entite_id_created_at");

            migrationBuilder.RenameIndex(
                name: "IX_contribution_revisions_author_id",
                table: "revisions_contributions",
                newName: "IX_revisions_contributions_auteur_id");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "demandes_adhesion_classe",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "status",
                table: "demandes_adhesion_classe",
                newName: "statut");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "demandes_adhesion_classe",
                newName: "classe_id");

            migrationBuilder.RenameIndex(
                name: "IX_class_membership_requests_user_id_status",
                table: "demandes_adhesion_classe",
                newName: "IX_demandes_adhesion_classe_utilisateur_id_statut");

            migrationBuilder.RenameIndex(
                name: "IX_class_membership_requests_school_class_id_status_requested_~",
                table: "demandes_adhesion_classe",
                newName: "IX_demandes_adhesion_classe_classe_id_statut_requested_at");

            migrationBuilder.RenameIndex(
                name: "IX_class_membership_requests_decided_by_id",
                table: "demandes_adhesion_classe",
                newName: "IX_demandes_adhesion_classe_decided_by_id");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "annonces_classe",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "author_id",
                table: "annonces_classe",
                newName: "auteur_id");

            migrationBuilder.RenameColumn(
                name: "is_pinned",
                table: "annonces_classe",
                newName: "est_epingle");

            migrationBuilder.RenameColumn(
                name: "content",
                table: "annonces_classe",
                newName: "contenu");

            migrationBuilder.RenameIndex(
                name: "IX_class_announcements_school_class_id_is_pinned",
                table: "annonces_classe",
                newName: "IX_annonces_classe_classe_id_est_epingle");

            migrationBuilder.RenameIndex(
                name: "IX_class_announcements_author_id",
                table: "annonces_classe",
                newName: "IX_annonces_classe_auteur_id");

            migrationBuilder.RenameColumn(
                name: "user_id",
                table: "recherches_alternance",
                newName: "utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "name",
                table: "recherches_alternance",
                newName: "nom");

            migrationBuilder.RenameColumn(
                name: "location",
                table: "recherches_alternance",
                newName: "localisation");

            migrationBuilder.RenameColumn(
                name: "last_checked_at",
                table: "recherches_alternance",
                newName: "derniere_verification_at");

            migrationBuilder.RenameColumn(
                name: "keywords",
                table: "recherches_alternance",
                newName: "mots_cles");

            migrationBuilder.RenameColumn(
                name: "filters_json",
                table: "recherches_alternance",
                newName: "filtres_json");

            migrationBuilder.RenameColumn(
                name: "alert_enabled",
                table: "recherches_alternance",
                newName: "alerte_active");

            migrationBuilder.RenameIndex(
                name: "IX_apprenticeship_searches_user_id",
                table: "recherches_alternance",
                newName: "IX_recherches_alternance_utilisateur_id");

            migrationBuilder.RenameColumn(
                name: "school_class_id",
                table: "messages_alternance",
                newName: "classe_id");

            migrationBuilder.RenameColumn(
                name: "author_id",
                table: "messages_alternance",
                newName: "auteur_id");

            migrationBuilder.RenameColumn(
                name: "encrypted_link",
                table: "messages_alternance",
                newName: "lien_chiffre");

            migrationBuilder.RenameColumn(
                name: "encrypted_content",
                table: "messages_alternance",
                newName: "contenu_chiffre");

            migrationBuilder.RenameIndex(
                name: "IX_apprenticeship_messages_school_class_id_created_at",
                table: "messages_alternance",
                newName: "IX_messages_alternance_classe_id_created_at");

            migrationBuilder.RenameIndex(
                name: "IX_apprenticeship_messages_deleted_by_id",
                table: "messages_alternance",
                newName: "IX_messages_alternance_deleted_by_id");

            migrationBuilder.RenameIndex(
                name: "IX_apprenticeship_messages_author_id",
                table: "messages_alternance",
                newName: "IX_messages_alternance_auteur_id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_utilisateurs",
                table: "utilisateurs",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_utilisateur_tokens",
                table: "utilisateur_tokens",
                columns: new[] { "user_id", "login_provider", "name" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_utilisateur_roles",
                table: "utilisateur_roles",
                columns: new[] { "user_id", "role_id" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_utilisateur_logins",
                table: "utilisateur_logins",
                columns: new[] { "login_provider", "provider_key" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_utilisateur_claims",
                table: "utilisateur_claims",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_professeurs",
                table: "professeurs",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_matieres",
                table: "matieres",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_classes",
                table: "classes",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_taches_personnelles",
                table: "taches_personnelles",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_evenements_personnels",
                table: "evenements_personnels",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_preferences_notifications",
                table: "preferences_notifications",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_appareils_notifications",
                table: "appareils_notifications",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_suivis_devoirs",
                table: "suivis_devoirs",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_devoirs_collectifs",
                table: "devoirs_collectifs",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_offres_favorites",
                table: "offres_favorites",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_cours",
                table: "cours",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_revisions_contributions",
                table: "revisions_contributions",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_demandes_adhesion_classe",
                table: "demandes_adhesion_classe",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_annonces_classe",
                table: "annonces_classe",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_recherches_alternance",
                table: "recherches_alternance",
                column: "id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_messages_alternance",
                table: "messages_alternance",
                column: "id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_classes_annee_scolaire",
                table: "classes",
                sql: "annee_scolaire ~ '^[0-9]{4}-[0-9]{4}$'");

            migrationBuilder.AddCheckConstraint(
                name: "ck_preferences_notifications_cours_rappel_minutes",
                table: "preferences_notifications",
                sql: "cours_rappel_minutes IN (0, 5, 10, 15, 30, 60)");

            migrationBuilder.CreateIndex(
                name: "IX_demandes_adhesion_classe_utilisateur_id",
                table: "demandes_adhesion_classe",
                column: "utilisateur_id",
                unique: true,
                filter: "statut = 'Pending'");

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

            migrationBuilder.AddForeignKey(
                name: "FK_cours_classes_classe_id",
                table: "cours",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_cours_matieres_matiere_id",
                table: "cours",
                column: "matiere_id",
                principalTable: "matieres",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_cours_professeurs_professeur_id",
                table: "cours",
                column: "professeur_id",
                principalTable: "professeurs",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_cours_utilisateurs_created_by_id",
                table: "cours",
                column: "created_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_cours_utilisateurs_updated_by_id",
                table: "cours",
                column: "updated_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_demandes_adhesion_classe_classes_classe_id",
                table: "demandes_adhesion_classe",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_demandes_adhesion_classe_utilisateurs_decided_by_id",
                table: "demandes_adhesion_classe",
                column: "decided_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_demandes_adhesion_classe_utilisateurs_utilisateur_id",
                table: "demandes_adhesion_classe",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_devoirs_collectifs_classes_classe_id",
                table: "devoirs_collectifs",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_devoirs_collectifs_cours_cours_id",
                table: "devoirs_collectifs",
                column: "cours_id",
                principalTable: "cours",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_devoirs_collectifs_utilisateurs_created_by_id",
                table: "devoirs_collectifs",
                column: "created_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_devoirs_collectifs_utilisateurs_updated_by_id",
                table: "devoirs_collectifs",
                column: "updated_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_evenements_personnels_utilisateurs_utilisateur_id",
                table: "evenements_personnels",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_matieres_classes_classe_id",
                table: "matieres",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_matieres_utilisateurs_created_by_id",
                table: "matieres",
                column: "created_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_messages_alternance_classes_classe_id",
                table: "messages_alternance",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_messages_alternance_utilisateurs_auteur_id",
                table: "messages_alternance",
                column: "auteur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_messages_alternance_utilisateurs_deleted_by_id",
                table: "messages_alternance",
                column: "deleted_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_offres_favorites_utilisateurs_utilisateur_id",
                table: "offres_favorites",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_preferences_notifications_utilisateurs_utilisateur_id",
                table: "preferences_notifications",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_professeurs_classes_classe_id",
                table: "professeurs",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_professeurs_utilisateurs_created_by_id",
                table: "professeurs",
                column: "created_by_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_recherches_alternance_utilisateurs_utilisateur_id",
                table: "recherches_alternance",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_refresh_tokens_utilisateurs_utilisateur_id",
                table: "refresh_tokens",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_revisions_contributions_classes_classe_id",
                table: "revisions_contributions",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_revisions_contributions_utilisateurs_auteur_id",
                table: "revisions_contributions",
                column: "auteur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_suivis_devoirs_devoirs_collectifs_devoir_id",
                table: "suivis_devoirs",
                column: "devoir_id",
                principalTable: "devoirs_collectifs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_suivis_devoirs_utilisateurs_utilisateur_id",
                table: "suivis_devoirs",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_taches_personnelles_cours_cours_id",
                table: "taches_personnelles",
                column: "cours_id",
                principalTable: "cours",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_taches_personnelles_utilisateurs_utilisateur_id",
                table: "taches_personnelles",
                column: "utilisateur_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_utilisateur_claims_utilisateurs_user_id",
                table: "utilisateur_claims",
                column: "user_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_utilisateur_logins_utilisateurs_user_id",
                table: "utilisateur_logins",
                column: "user_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_utilisateur_roles_roles_role_id",
                table: "utilisateur_roles",
                column: "role_id",
                principalTable: "roles",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_utilisateur_roles_utilisateurs_user_id",
                table: "utilisateur_roles",
                column: "user_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_utilisateur_tokens_utilisateurs_user_id",
                table: "utilisateur_tokens",
                column: "user_id",
                principalTable: "utilisateurs",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_utilisateurs_classes_classe_id",
                table: "utilisateurs",
                column: "classe_id",
                principalTable: "classes",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}
