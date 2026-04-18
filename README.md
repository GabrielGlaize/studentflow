# Cahier des Charges : Projet StudyFlow Pro
> **Système de Gestion de Scolarité : Application Mobile & Administration Web**

---

## 1. Présentation du Projet
**StudyFlow Pro** est une application de productivité pour étudiants et établissements. Elle centralise l'emploi du temps, la gestion des devoirs et l'organisation par classes. 

L'écosystème repose sur une architecture moderne :
* **Backend :** API ASP.NET Core.
* **Accès Données :** Entity Framework Core (EF Core).
* **Base de Données :** SQL Server / PostgreSQL.
* **Interface Admin :** Application Web (Blazor ou React).
* **Interface Élève :** Application Mobile (.NET MAUI ou React Native).

---

## 2. Organisation de l'Équipe (3 Membres)

| Rôle | Responsable | Missions Principales |
| :--- | :--- | :--- |
| **Membre 1 : Architecte Data** | [Nom] | Modélisation SQL, Entités C#, DbContext, Migrations EF Core. |
| **Membre 2 : Backend & Mobile** | [Nom] | API ASP.NET Core, Logique des Notifications, Développement Mobile. |
| **Membre 3 : Product & Admin** | [Nom] | Design UI/UX (Figma), Interface Admin Web, Documentation & Planning. |

---

## 3. Spécifications Fonctionnelles

### A. Interface Administration (Web)
* **Gestion des Classes :** Création, modification et suppression des classes (ex: L1-A, L2-B).
* **Gestion des Utilisateurs :** Ajout d'élèves et affectation à une classe.
* **Gestion du Calendrier :** Remplissage de l'emploi du temps (Matière, Salle, Horaire, Professeur) par classe.
* **Devoirs Globaux :** Publication de devoirs assignés à toute une classe.

### B. Interface Élève (Mobile)
* **Calendrier Dynamique :** Consultation de l'emploi du temps du jour et de la semaine.
* **Détails des Cours :** Affichage immédiat de la salle et des informations du professeur.
* **Gestion des Devoirs :** Liste des tâches personnelles ou de classe, avec option de liaison à un cours.
* **Préférences :** Paramétrage des notifications (Activer/Dés
