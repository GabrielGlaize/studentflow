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
* **Préférences :** Paramétrage des notifications (Activer/Désactiver).

### C. Système de Notifications
* **Notifications de Cours :** Rappel automatique **5 minutes avant** chaque cours (Nom du cours + Salle).
* **Notifications de Devoirs :** Rappel automatique **la veille** d'une échéance.
* **Flexibilité :** Choix de réception global pour les cours, et par devoir pour les tâches.

---

## 4. Architecture Technique (Stack .NET)

* **Logiciel :** .NET 8.0 / ASP.NET Core.
* **ORM :** Entity Framework Core (Approche Code-First).
* **Base de Données :** SQL (relationnelle) pour garantir l'intégrité des liens Classe-Élève.
* **Sécurité :** Hachage des mots de passe en base de données et authentification via JWT (JSON Web Tokens).

---

## 5. Modélisation des Données (EF Core)

Le **Membre 1** est responsable de l'implémentation des entités suivantes :

| Entité | Attributs Clés | Relations |
| :--- | :--- | :--- |
| **Classe** | Id, Nom | Possède plusieurs Élèves et plusieurs Cours. |
| **Utilisateur** | Id, Email, PasswordHash, Role (Admin/Élève) | Appartient à une Classe. |
| **Cours** | Id, Matiere, Salle, HeureDebut, HeureFin, Jour | Lié à une Classe. |
| **Devoir** | Id, Titre, Description, Deadline | Lié à une Classe (et optionnellement à un Cours). |

---

## 6. Planning de Développement

1.  **Phase 1 : Conception & Design**
    * Maquettes Figma (Admin + Mobile).
    * Schéma relationnel de la base de données.
2.  **Phase 2 : Infrastructure & API**
    * Création du projet ASP.NET Core.
    * Configuration d'EF Core et première migration.
    * Développement des endpoints CRUD (Create, Read, Update, Delete).
3.  **Phase 3 : Interfaces & Logique**
    * Développement de l'interface Admin pour saisir les cours.
    * Développement de l'interface Mobile pour afficher le calendrier.
    * Implémentation du service de notifications (Background Worker).
4.  **Phase 4 : Tests & Finalisation**
    * Tests de bout en bout (création d'un cours en admin -> réception notif sur mobile).
    * Rédaction du rapport technique.

---

## 7. Critères de Réussite
* **Isolation des données :** Un élève ne doit voir que les cours de sa propre classe.
* **Réactivité :** Les notifications doivent être envoyées précisément à l'heure prévue.
* **Ergonomie :** L'interface Admin doit permettre de remplir une semaine de cours rapidement.
* **Documentation :** Le code doit être commenté et le fichier `README.md` doit expliquer comment lancer le projet.

---
