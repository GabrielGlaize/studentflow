# StudyFlow Pro — Documentation backend

Ce document explique ce qui a été fait sur le backend, pourquoi ces choix ont été faits, et comment relire le code sans se perdre.

L’objectif n’est pas seulement de lister des fichiers. Le but est que l’équipe comprenne la logique du projet, puisse l’expliquer à l’oral, et puisse continuer le développement proprement.

---

## 1. Objectif actuel du backend

Le backend sert de base à l’application StudyFlow Pro.

Il doit permettre :

- à un élève de créer un compte ;
- à un futur élève de créer une classe et devenir automatiquement délégué ;
- à un élève de rejoindre une classe avec un code ;
- au délégué d’approuver ou refuser les demandes d’entrée ;
- aux élèves d’une classe de gérer eux-mêmes les cours et devoirs ;
- à chaque utilisateur d’avoir son agenda personnel ;
- de préparer la partie alternance et entreprise ;
- de protéger les données sensibles comme les professeurs, salles et horaires.

Le backend est donc déjà pensé autour de l’idée principale du projet : une classe autosuffisante, où les élèves peuvent contribuer sans dépendre constamment d’un admin.

---

## 2. Architecture générale

Le backend est organisé en plusieurs projets .NET :

```text
src/backend/
├── StudyFlow.Api
├── StudyFlow.Application
├── StudyFlow.Domain
└── StudyFlow.Infrastructure
```

### StudyFlow.Api

C’est la couche exposée au monde extérieur.

Elle contient :

- les contrôleurs API ;
- les routes HTTP ;
- les contrats de requêtes/réponses.

Exemple :

```text
POST /api/v1/auth/login
GET  /api/v1/courses
POST /api/v1/personal-agenda/tasks
```

On y trouve notamment :

- `AuthController`
- `CoursesController`
- `HomeworkController`
- `PersonalAgendaController`
- `DashboardController`
- `ProfileController`
- `ClassAnnouncementsController`
- `ApprenticeshipMessagesController`
- `ClassResourcesController`
- `SchoolClassesController`
- `DelegateMembershipController`

### StudyFlow.Domain

C’est le cœur métier.

Il contient les entités principales :

- `SchoolClass`
- `ApplicationUser`
- `Course`
- `Homework`
- `Subject`
- `Teacher`
- `PersonalTask`
- `PersonalEvent`
- `ApprenticeshipSearch`
- etc.

Cette couche ne devrait pas dépendre d’ASP.NET ou de la base de données directement. Elle décrit surtout les objets importants du projet.

### StudyFlow.Infrastructure

C’est la couche technique.

Elle contient :

- Entity Framework Core ;
- la configuration PostgreSQL ;
- Identity ;
- JWT ;
- le chiffrement ;
- les migrations ;
- les services techniques.

Exemples :

- `StudyFlowDbContext`
- `AuthTokenService`
- `ClassCodeService`
- `SensitiveDataProtector`

### StudyFlow.Application

Cette couche contient les interfaces utilisées par le reste du projet.

Exemples :

- `IAuthTokenService`
- `IClassCodeService`
- `ISensitiveDataProtector`

Pourquoi mettre ces interfaces ici ? Pour que l’API puisse utiliser des services sans connaître tous les détails techniques de leur implémentation.

---

## 3. Pourquoi on a renommé le code en anglais

Au début, plusieurs noms étaient en français :

- `Classe`
- `Cours`
- `Matiere`
- `Professeur`
- `DevoirCollectif`
- etc.

On les a renommés en anglais :

| Ancien nom | Nouveau nom |
|---|---|
| `Classe` | `SchoolClass` |
| `Cours` | `Course` |
| `Matiere` | `Subject` |
| `Professeur` | `Teacher` |
| `DevoirCollectif` | `Homework` |
| `TachePersonnelle` | `PersonalTask` |
| `EvenementPersonnel` | `PersonalEvent` |
| `DemandeAdhesionClasse` | `ClassMembershipRequest` |
| `AnnonceClasse` | `ClassAnnouncement` |
| `RechercheAlternance` | `ApprenticeshipSearch` |
| `OffreFavorite` | `FavoriteOffer` |

Pourquoi ?

- Le C# professionnel utilise souvent l’anglais.
- Les librairies .NET sont en anglais.
- Les routes API sont plus cohérentes.
- Flutter utilisera sûrement des modèles en anglais aussi.
- Cela évite un mélange difficile à maintenir.

On a fait ce renommage maintenant, parce que le projet est encore jeune. Plus on attend, plus ce genre de changement devient risqué.

---

## 4. Base de données et EF Core

Le projet utilise Entity Framework Core avec PostgreSQL.

La classe centrale est :

```text
src/backend/StudyFlow.Infrastructure/Persistence/StudyFlowDbContext.cs
```

Elle déclare les tables via des `DbSet`.

Exemple :

```csharp
public DbSet<SchoolClass> SchoolClasses => Set<SchoolClass>();
public DbSet<Course> Courses => Set<Course>();
public DbSet<Homework> HomeworkItems => Set<Homework>();
```

### Pourquoi utiliser EF Core ?

EF Core permet de manipuler la base avec des objets C#.

Au lieu d’écrire directement :

```sql
SELECT * FROM courses WHERE school_class_id = ...
```

on peut écrire :

```csharp
dbContext.Courses.Where(x => x.SchoolClassId == user.SchoolClassId)
```

Cela rend le code plus lisible pour nous, tout en gardant une vraie base relationnelle derrière.

### Migrations

Les migrations servent à transformer le modèle C# en structure PostgreSQL.

Migrations actuelles importantes :

- `InitialCreate`
- `AddAuthenticationSecurity`
- `RenameBackendModelToEnglish`

La dernière migration a été créée pour aligner la base avec les noms anglais.

Commande utilisée :

```bash
./.dotnet-sdk/dotnet ef migrations add RenameBackendModelToEnglish \
  --project src/backend/StudyFlow.Infrastructure \
  --startup-project src/backend/StudyFlow.Infrastructure \
  --no-build
```

Puis application à la base :

```bash
./.dotnet-sdk/dotnet ef database update \
  --project src/backend/StudyFlow.Infrastructure \
  --startup-project src/backend/StudyFlow.Infrastructure \
  --no-build
```

Pourquoi `--no-build` ?

Parce que l’outil EF lançait parfois le `dotnet` global installé sur la machine, au lieu du SDK local du projet. Comme on avait déjà vérifié que la build passait, `--no-build` évite ce problème.

---

## 5. Authentification et comptes

L’authentification utilise :

- ASP.NET Core Identity ;
- JWT ;
- refresh tokens.

### Entité utilisateur

Le compte utilisateur est représenté par :

```text
src/backend/StudyFlow.Infrastructure/Identity/ApplicationUser.cs
```

Champs importants :

- `FirstName`
- `LastName`
- `Email`
- `PasswordHash`, géré par Identity
- `SchoolClassId`
- `IsActive`

### Pourquoi Identity ?

Identity évite de recoder nous-mêmes :

- le hash des mots de passe ;
- la validation des mots de passe ;
- les rôles ;
- la gestion utilisateur de base.

### JWT

Quand l’utilisateur se connecte, l’API renvoie :

- un access token ;
- un refresh token.

L’access token sert à appeler les routes protégées.

Le refresh token sert à renouveler la session sans redemander le mot de passe.

### Routes auth

```text
POST /api/v1/auth/register
POST /api/v1/auth/register-and-create-class
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

### Cas spécial : créer une classe

La route :

```text
POST /api/v1/auth/register-and-create-class
```

crée :

- un utilisateur ;
- une classe ;
- un code d’accès ;
- les rôles `Eleve` et `Delegue` pour cet utilisateur.

Pourquoi ?

Parce qu’un élève non connecté doit pouvoir créer sa classe et devenir automatiquement délégué. C’est exactement le fonctionnement voulu dans le cahier des charges.

---

## 6. Rôles

Le projet utilise deux rôles principaux :

```csharp
public enum UserRole
{
    Eleve = 0,
    Delegue = 1
}
```

### Élève

Un élève peut :

- consulter sa classe ;
- créer/modifier/supprimer des cours ;
- créer/modifier/supprimer des devoirs ;
- gérer ses tâches personnelles ;
- gérer ses événements personnels.

### Délégué

Un délégué est un élève avec quelques droits supplémentaires.

Il peut :

- voir les demandes d’entrée dans la classe ;
- approuver un élève ;
- refuser un élève.

Important : le délégué ne valide pas les cours ni les devoirs. Les élèves peuvent les gérer directement.

C’est volontaire, parce que le projet repose sur l’autosuffisance de la classe.

---

## 7. Gestion des classes

Entité principale :

```text
SchoolClass
```

Champs importants :

- `Name`
- `SchoolYear`
- `AccessCodeHash`
- `EncryptedAccessCode`
- `CreatedById`
- `IsActive`

### Code de classe

Le code de classe est protégé de deux façons :

- une version hashée pour retrouver la classe ;
- une version chiffrée si on doit pouvoir le réafficher au délégué plus tard.

Pourquoi ne pas stocker seulement le code en clair ?

Parce qu’un code de classe donne accès à une classe. Même si ce n’est pas aussi sensible qu’un mot de passe, il faut éviter de le laisser lisible inutilement dans la base.

### Routes

```text
POST /api/v1/classes/join
GET  /api/v1/classes/current-request
```

### Demande d’adhésion

Quand un élève entre un code de classe, il n’est pas ajouté directement.

On crée une `ClassMembershipRequest`.

Statuts possibles :

- `Pending`
- `Approved`
- `Rejected`
- `Cancelled`

Pourquoi ?

Parce que tu voulais que le délégué puisse approuver les élèves. Cela évite qu’une personne externe rejoigne une classe juste avec un code récupéré ailleurs.

---

## 8. Gestion par le délégué

Contrôleur :

```text
DelegateMembershipController
```

Routes :

```text
GET  /api/v1/delegate/membership-requests
POST /api/v1/delegate/membership-requests/{id}/approve
POST /api/v1/delegate/membership-requests/{id}/reject
```

Ces routes sont protégées par :

```csharp
[Authorize(Roles = nameof(UserRole.Delegue))]
```

Cela veut dire que seul un utilisateur avec le rôle `Delegue` peut appeler ces endpoints.

---

## 9. Ressources de classe : matières et professeurs

Contrôleur :

```text
ClassResourcesController
```

Routes :

```text
GET  /api/v1/class-resources/subjects
POST /api/v1/class-resources/subjects
GET  /api/v1/class-resources/teachers
POST /api/v1/class-resources/teachers
```

### Subjects

Les matières sont stockées avec :

- `Name`
- `SchoolClassId`
- `CreatedById`
- `IsActive`

On empêche deux matières identiques dans la même classe grâce à un index unique :

```csharp
entity.HasIndex(x => new { x.SchoolClassId, x.Name }).IsUnique();
```

### Teachers

Les professeurs sont plus sensibles.

On stocke :

- `EncryptedDisplayName`
- `SearchNameHash`
- `EncryptedInformation`

Pourquoi chiffrer le nom du professeur ?

Parce que tu as demandé à éviter qu’en cas de fuite de base, les noms des professeurs et leurs horaires soient directement divulgués.

Pourquoi avoir aussi un hash de recherche ?

Parce qu’il faut quand même pouvoir détecter les doublons.

Exemple :

- nom affiché : chiffré ;
- hash de recherche : permet de savoir si ce prof existe déjà, sans lire le nom.

---

## 10. Gestion des cours

Entité :

```text
Course
```

Champs importants :

- `SchoolClassId`
- `SubjectId`
- `TeacherId`
- `Day`
- `EncryptedData`
- `IsCancelled`
- `Version`
- `DeletedAt`

Routes :

```text
GET    /api/v1/courses
GET    /api/v1/courses/{id}
POST   /api/v1/courses
PUT    /api/v1/courses/{id}
DELETE /api/v1/courses/{id}
```

### Pourquoi les cours sont modifiables par les élèves ?

C’est un choix métier important.

Le projet part du principe que la classe peut s’auto-gérer. Si un cours est mal rempli, un élève doit pouvoir le corriger sans attendre un délégué.

### Protection des données sensibles

Les détails précis du cours sont stockés dans `EncryptedData`.

Dedans, on met :

- heure de début ;
- heure de fin ;
- salle.

Pourquoi ?

Parce que l’emploi du temps peut être sensible. Si la base fuit, on ne veut pas exposer directement :

- les salles ;
- les horaires exacts ;
- les enchaînements de cours.

### Version

Chaque cours a une propriété :

```csharp
public long Version { get; set; } = 1;
```

Pourquoi ?

Pour éviter qu’un élève écrase sans le savoir la modification d’un autre.

Exemple :

1. Élève A ouvre le cours en version 1.
2. Élève B modifie le cours, il passe en version 2.
3. Élève A essaie d’envoyer une modification basée sur la version 1.
4. L’API refuse avec un conflit.

C’est une protection simple contre les modifications concurrentes.

### Suppression logique

Les cours utilisent `DeletedAt`.

Cela veut dire qu’on ne supprime pas forcément la ligne immédiatement en base. On marque le cours comme supprimé.

Pourquoi ?

Parce qu’on peut garder un historique et éviter des pertes brutales.

---

## 11. Gestion des devoirs

Entité :

```text
Homework
```

Routes :

```text
GET    /api/v1/homework
GET    /api/v1/homework/{id}
POST   /api/v1/homework
PUT    /api/v1/homework/{id}
PUT    /api/v1/homework/{id}/progress
DELETE /api/v1/homework/{id}
```

Un devoir peut être lié à un cours avec :

```csharp
public Guid? CourseId { get; set; }
```

Le `?` veut dire que ce lien est optionnel.

Pourquoi optionnel ?

Parce qu’un devoir peut parfois être global, ou ne pas correspondre à un cours précis.

Comme les cours, les devoirs sont gérés par les élèves de la classe. Ils ne passent pas par une validation du délégué.

### Progression personnelle d’un devoir

Un devoir est partagé par toute la classe, mais son avancement est personnel.

Exemple :

- tout le monde voit le devoir “Rendre le dossier d’anglais” ;
- Gabriel peut le marquer comme fait ;
- un autre élève peut encore l’avoir comme non terminé.

Pour ça, on utilise l’entité :

```text
HomeworkProgress
```

Elle contient :

- `HomeworkId` : le devoir concerné ;
- `UserId` : l’élève concerné ;
- `IsDone` : indique si cet élève a terminé le devoir ;
- `NotificationsEnabled` : indique si cet élève veut recevoir les rappels pour ce devoir ;
- `CompletedAt` : date de validation du devoir.

La route utilisée par Flutter sera :

```text
PUT /api/v1/homework/{id}/progress
```

Exemple de corps JSON :

```json
{
  "isDone": true,
  "notificationsEnabled": false
}
```

Pourquoi ce choix ?

Parce qu’on garde le modèle autosuffisant de la classe : les élèves créent et corrigent les devoirs ensemble, mais chaque élève garde son propre état d’avancement et ses propres préférences de notification.

Par défaut, `GET /api/v1/homework` ne renvoie pas les devoirs déjà terminés par l’élève connecté. Si l’application veut tout afficher, elle peut appeler :

```text
GET /api/v1/homework?includeDone=true
```

---

## 12. Historique des contributions

Entité :

```text
ContributionRevision
```

Elle sert à journaliser les modifications importantes.

On enregistre :

- la classe ;
- le type d’entité modifiée ;
- l’identifiant de l’entité ;
- l’action ;
- l’auteur ;
- un snapshot chiffré.

Actions possibles :

- `Created`
- `Updated`
- `Deleted`
- `Restored`

Pourquoi ?

Parce qu’on veut laisser les élèves contribuer librement, mais sans rendre les changements invisibles.

Ce n’est pas une validation. C’est un historique.

En soutenance, c’est un bon point à expliquer : le système est ouvert, mais traçable.

---

## 13. Agenda personnel

Contrôleur :

```text
PersonalAgendaController
```

Routes tâches :

```text
GET    /api/v1/personal-agenda/tasks
POST   /api/v1/personal-agenda/tasks
GET    /api/v1/personal-agenda/tasks/{id}
PUT    /api/v1/personal-agenda/tasks/{id}
DELETE /api/v1/personal-agenda/tasks/{id}
```

Routes événements :

```text
GET    /api/v1/personal-agenda/events
POST   /api/v1/personal-agenda/events
GET    /api/v1/personal-agenda/events/{id}
PUT    /api/v1/personal-agenda/events/{id}
DELETE /api/v1/personal-agenda/events/{id}
```

### Pourquoi c’est important ?

Parce que tu as ajouté une idée importante : un futur élève doit pouvoir utiliser l’agenda et les tâches pour organiser sa recherche d’alternance, même s’il n’a pas encore de classe.

Donc :

- les tâches personnelles ne nécessitent pas forcément une classe ;
- les événements personnels non plus ;
- par contre, lier une tâche à un cours nécessite d’être dans une classe.

### Catégories de tâches

```csharp
School
Apprenticeship
Company
```

Cela permet de faire le switch dans l’application entre :

- tâches école ;
- tâches alternance ;
- tâches entreprise.

### Événements personnels

Les événements personnels stockent leurs détails dans `EncryptedData`.

Pourquoi ?

Parce qu’un agenda personnel peut contenir des informations privées :

- rendez-vous ;
- entretiens ;
- adresses ;
- notes personnelles.

---

## 14. Alternance et entreprise

Le domaine contient déjà :

```text
ApprenticeshipSearch
FavoriteOffer
ApprenticeshipMessage
```

### ApprenticeshipSearch

Sert à enregistrer une recherche d’alternance.

Champs importants :

- `Keywords`
- `Location`
- `DistanceKm`
- `FiltersJson`
- `AlertEnabled`

L’idée est compatible avec l’API La Bonne Alternance.

### FavoriteOffer

Sert à enregistrer une offre mise en favori.

Champs importants :

- `Source`
- `ExternalOfferId`
- `Title`
- `Company`
- `Location`
- `Url`

### ApprenticeshipMessage

Sert à préparer le fil communautaire d’offres d’alternance partagées entre élèves.

Il est lié à une classe.

Son contenu est chiffré avec :

- `EncryptedContent`
- `EncryptedLink`

Pourquoi ?

Même si ce ne sont pas des données aussi sensibles que des mots de passe, les messages communautaires peuvent contenir des contacts, liens, noms d’entreprises ou informations privées.

---

## 15. Notifications

Entités :

```text
NotificationPreference
NotificationDevice
```

### NotificationPreference

Contient les préférences utilisateur :

- notifications de cours activées ;
- notifications de devoirs activées ;
- notifications alternance activées ;
- délai de rappel avant un cours.

Le rappel de cours est limité par la base :

```text
0, 5, 10, 15, 30, 60 minutes
```

Pourquoi limiter ?

Pour éviter des valeurs absurdes comme `-999` ou `999999`.

### NotificationDevice

Représente un appareil capable de recevoir des notifications.

Plateformes :

- Android ;
- iOS ;
- Web.

Routes ajoutées :

```text
GET    /api/v1/notifications/preferences
PUT    /api/v1/notifications/preferences
GET    /api/v1/notifications/devices
POST   /api/v1/notifications/devices
DELETE /api/v1/notifications/devices/{id}
GET    /api/v1/notifications/due-preview
```

`POST /api/v1/notifications/devices` enregistre le token de notification du smartphone ou du navigateur.

Exemple :

```json
{
  "token": "firebase-or-web-push-token",
  "platform": "android"
}
```

Le backend ne renvoie jamais le token complet dans la réponse. Il renvoie seulement un aperçu, par exemple `...a1b2c3`, pour éviter d’afficher une donnée sensible inutilement.

Important : cette étape prépare les notifications, mais elle n’envoie pas encore les notifications. L’envoi réel viendra dans un service de fond dédié.

### Prévisualisation des rappels à envoyer

Le backend contient maintenant un planner de notifications.

Son rôle est de répondre à la question :

> “Entre maintenant et dans X minutes, quels rappels devraient être envoyés ?”

Route de test :

```text
GET /api/v1/notifications/due-preview?lookBehindMinutes=5&lookAheadMinutes=60
```

Cette route est réservée au rôle `Delegue`, car elle peut afficher les rappels prévus pour les élèves de la classe.

Pour l’instant, le planner gère :

- les rappels de cours, selon `CourseReminderMinutes` ;
- les rappels de devoirs, la veille de la deadline.

Il respecte aussi :

- les préférences globales de notifications ;
- les devoirs déjà marqués comme faits ;
- les notifications désactivées pour un devoir précis ;
- le nombre d’appareils enregistrés par élève.

Ce n’est pas encore l’envoi réel. C’est la couche de décision. Plus tard, un service de fond pourra l’appeler toutes les minutes puis envoyer les messages via Firebase ou Web Push.

### Service de fond des notifications

Le backend contient maintenant un vrai service de fond :

```text
NotificationDispatchWorker
```

Son rôle :

1. se réveiller régulièrement ;
2. regarder toutes les classes ;
3. demander au planner quels rappels sont dus ;
4. envoyer chaque rappel une seule fois ;
5. enregistrer le résultat dans la table `notification_deliveries`.

Pour l’instant, l’expéditeur utilisé est :

```text
LoggingNotificationSender
```

Il n’envoie pas encore de vraie notification push. Il écrit simplement dans les logs. C’est volontaire : cela permet de tester toute la logique sans dépendre de Firebase ou d’un service externe.

La nouvelle table :

```text
notification_deliveries
```

sert à éviter les doublons.

Exemple : si un rappel de cours devait partir à 08:25 pour l’élève A, le backend garde une trace. Si le worker repasse quelques secondes après, il voit que ce rappel a déjà été traité et ne le renvoie pas.

Configuration actuelle :

```json
{
  "NotificationWorker": {
    "Enabled": false,
    "IntervalSeconds": 60,
    "LookBehindMinutes": 2
  }
}
```

Le worker est désactivé par défaut pour éviter les comportements inattendus pendant le développement. Pour l’activer :

```bash
NotificationWorker__Enabled=true
```

Une migration EF a été ajoutée :

```text
AddNotificationDeliveryLog
```

Elle crée uniquement la table d’historique des envois.

---

## 16. Sécurité des données

Le backend protège les données de plusieurs façons.

### Mots de passe

Ils sont gérés par ASP.NET Identity.

On ne stocke jamais le mot de passe en clair.

### JWT

Les routes protégées nécessitent un token.

Le token contient notamment :

- l’identifiant utilisateur ;
- l’email ;
- les rôles ;
- l’identifiant de classe si l’utilisateur en a une.

### Chiffrement applicatif

Service :

```text
SensitiveDataProtector
```

Il sert à chiffrer certaines données avant stockage.

Exemples :

- nom affiché du professeur ;
- informations professeur ;
- données précises du cours ;
- données d’événements personnels ;
- snapshots d’historique ;
- messages alternance.

### Hash de recherche

Pour certaines données, on veut détecter les doublons sans stocker le texte en clair.

Exemple :

```text
Teacher.SearchNameHash
```

Cela permet de vérifier si un professeur existe déjà dans une classe.

---

## 17. Isolation des données

Un point très important : l’élève ne doit voir que les données de sa classe.

Dans les contrôleurs, on retrouve souvent une condition comme :

```csharp
x.SchoolClassId == user.SchoolClassId
```

Pourquoi ?

Parce qu’un utilisateur ne doit pas pouvoir accéder aux cours d’une autre classe juste en devinant un identifiant.

Même si quelqu’un connaît un `courseId`, l’API vérifie que ce cours appartient bien à la classe de l’utilisateur connecté.

Depuis la revue sécurité du 25 juin 2026, les lectures et modifications filtrent aussi les entités supprimées logiquement :

```csharp
x.DeletedAt == null
```

Cela évite qu’un cours, devoir, message ou annonce supprimé réapparaisse dans l’application, le tableau de bord ou les rappels de notifications.

La synthèse complète est dans `docs/SECURITE_CONFIDENTIALITE.md`.

---

## 18. Routes API disponibles

### Auth

```text
POST /api/v1/auth/register
POST /api/v1/auth/register-and-create-class
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

### Classes

```text
GET  /api/v1/classes/current
PUT  /api/v1/classes/current
POST /api/v1/classes/join
GET  /api/v1/classes/current-request
GET  /api/v1/classes/current/access-code
POST /api/v1/classes/current/access-code/regenerate
```

### Délégué

```text
GET  /api/v1/delegate/membership-requests
POST /api/v1/delegate/membership-requests/{id}/approve
POST /api/v1/delegate/membership-requests/{id}/reject
```

### Ressources de classe

```text
GET  /api/v1/class-resources/subjects
POST /api/v1/class-resources/subjects
GET  /api/v1/class-resources/teachers
POST /api/v1/class-resources/teachers
```

### Cours

```text
GET    /api/v1/courses
GET    /api/v1/courses/{id}
POST   /api/v1/courses
PUT    /api/v1/courses/{id}
DELETE /api/v1/courses/{id}
```

### Devoirs

```text
GET    /api/v1/homework
GET    /api/v1/homework/{id}
POST   /api/v1/homework
PUT    /api/v1/homework/{id}
PUT    /api/v1/homework/{id}/progress
DELETE /api/v1/homework/{id}
```

### Agenda personnel

```text
GET    /api/v1/personal-agenda/tasks
POST   /api/v1/personal-agenda/tasks
GET    /api/v1/personal-agenda/tasks/{id}
PUT    /api/v1/personal-agenda/tasks/{id}
DELETE /api/v1/personal-agenda/tasks/{id}

GET    /api/v1/personal-agenda/events
POST   /api/v1/personal-agenda/events
GET    /api/v1/personal-agenda/events/{id}
PUT    /api/v1/personal-agenda/events/{id}
DELETE /api/v1/personal-agenda/events/{id}
```

### Dashboard

```text
GET /api/v1/dashboard
```

### Profil et réglages

```text
GET /api/v1/profile
PUT /api/v1/profile
PUT /api/v1/profile/app-settings
PUT /api/v1/profile/notification-settings
GET /api/v1/notifications/preferences
PUT /api/v1/notifications/preferences
GET /api/v1/notifications/devices
POST /api/v1/notifications/devices
DELETE /api/v1/notifications/devices/{id}
```

### Annonces importantes

```text
GET    /api/v1/class-announcements
POST   /api/v1/class-announcements
PUT    /api/v1/class-announcements/{id}
DELETE /api/v1/class-announcements/{id}
```

### Fil communautaire alternance

```text
GET    /api/v1/apprenticeship-messages
POST   /api/v1/apprenticeship-messages
DELETE /api/v1/apprenticeship-messages/{id}
```

### Recherches et favoris alternance

```text
GET    /api/v1/apprenticeships/opportunities
GET    /api/v1/apprenticeships/saved-searches
POST   /api/v1/apprenticeships/saved-searches
PUT    /api/v1/apprenticeships/saved-searches/{id}
DELETE /api/v1/apprenticeships/saved-searches/{id}

GET    /api/v1/apprenticeships/favorite-offers
POST   /api/v1/apprenticeships/favorite-offers
DELETE /api/v1/apprenticeships/favorite-offers/{id}
```

---

## 19. Pourquoi certains messages sont en français alors que le code est en anglais

Le code est en anglais pour respecter les conventions professionnelles.

Mais les messages d’erreur envoyés à l’utilisateur restent en français.

Exemple :

```csharp
return BadRequestProblem("Le nom du professeur est obligatoire.");
```

Pourquoi ?

Parce que l’utilisateur final est francophone, et parce que le projet est présenté en français.

Donc on sépare :

- code interne : anglais ;
- expérience utilisateur : français.

---

## 20. Commandes utiles

### Démarrer PostgreSQL

```bash
docker compose up -d
```

### Compiler le backend

```bash
./.dotnet-sdk/dotnet build src/backend/StudyFlow.Api/StudyFlow.Api.csproj \
  --no-restore \
  --disable-build-servers \
  -m:1 \
  -v:minimal
```

### Appliquer les migrations

```bash
./.dotnet-sdk/dotnet ef database update \
  --project src/backend/StudyFlow.Infrastructure \
  --startup-project src/backend/StudyFlow.Infrastructure \
  --no-build
```

### Lancer l’API

```bash
./.dotnet-sdk/dotnet run \
  --project src/backend/StudyFlow.Api \
  --urls http://127.0.0.1:5050
```

On utilise `127.0.0.1` plutôt que `localhost`, car Kestrel peut poser problème avec certains bindings dynamiques.

---

## 21. Ce qui est déjà vérifié

Le backend compile correctement :

```text
0 erreur
0 warning
```

La migration `RenameBackendModelToEnglish` a été :

- générée ;
- appliquée sur PostgreSQL local.

Le contrôle `git diff --check` passe aussi, donc pas de problème d’espaces ou de fins de lignes détecté.

---

## 22. Ce qu’il reste à faire ensuite

Depuis le raccordement Flutter, plusieurs éléments initialement prévus sont maintenant couverts côté application :

- authentification réelle branchable : login, inscription, refresh, logout, restauration ;
- création de compte sans classe et création de classe avec rôle `Delegue` ;
- demande d’adhésion avec code, approbation et refus par le délégué ;
- modification des informations de classe et régénération du code ;
- CRUD des cours et devoirs collectifs côté Flutter ;
- préférences d’application et de notifications synchronisables ;
- calcul et affichage côté Flutter des rappels à venir pour les cours et devoirs ;
- recherches sauvegardées et favoris alternance branchés côté Flutter ;
- filtrage des contenus supprimés logiquement dans les routes sensibles ;
- fil officiel de classe, entraide alternance et espace Entreprise.

Les prochaines étapes logiques sont donc :

1. Tester les parcours complets avec l’API réelle et PostgreSQL, pas seulement en mode démo.
2. Brancher les notifications push/locales réelles côté Flutter.
3. Améliorer les filtres et alertes de recherche alternance.
4. Finaliser l’interface Web publique des alternances.
5. Faire une revue sécurité production : rotation des clés, rate limiting, durcissement logs et politique de sauvegardes.
6. Préparer les captures, le guide de démonstration et le support oral.

### Dashboard mobile attendu

Le dashboard pourra regrouper :

- le prochain cours ;
- les devoirs à venir ;
- les tâches personnelles ;
- les événements du jour ;
- éventuellement les annonces importantes.

Le premier endpoint existe maintenant avec `GET /api/v1/dashboard`. Il évite à Flutter de faire trop d’appels API séparés pour afficher l’écran d’accueil.

---

## 23. Résumé simple pour l’oral

On peut expliquer le backend comme ça :

> StudyFlow Pro est organisé avec une API ASP.NET Core, une base PostgreSQL et Entity Framework Core. Les utilisateurs se connectent avec JWT. Un élève peut créer une classe, devenir délégué, puis partager un code de classe. Les autres élèves demandent à rejoindre la classe et le délégué les approuve. Une fois dans la classe, les élèves peuvent gérer eux-mêmes les cours et devoirs, sans validation, car le projet repose sur l’autosuffisance. Pour garder une trace, chaque contribution importante est journalisée. Les données sensibles comme les noms de professeurs, salles, horaires précis et événements personnels sont chiffrées en base. Le backend prévoit aussi l’agenda personnel et les futures fonctionnalités d’alternance.

---

## 24. À retenir

Le projet n’est pas seulement une application de calendrier.

Il défend une idée :

> Une classe peut s’organiser elle-même avec des outils simples, partagés, sécurisés et adaptés aux étudiants.

Les choix techniques servent cette idée :

- rôles simples ;
- délégué limité ;
- élèves contributeurs ;
- historique des modifications ;
- chiffrement des données sensibles ;
- agenda utilisable même sans classe ;
- préparation de l’espace alternance.
