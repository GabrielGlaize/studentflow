# Sécurité et confidentialité

Dernière mise à jour : 25 juin 2026.

## Objectif

StudyFlow manipule des données de classe : cours, salles, horaires, professeurs, devoirs, messages internes et informations personnelles.

Le but n’est pas seulement d’empêcher un utilisateur non autorisé d’appeler une route API. Il faut aussi limiter les dégâts si une base PostgreSQL est copiée ou consultée par erreur.

## Règles principales

### 1. Un compte sans classe ne lit aucune donnée scolaire

Un futur élève peut utiliser :

- la recherche d’alternance ;
- les favoris alternance ;
- les recherches sauvegardées ;
- ses tâches et événements personnels.

Mais il ne doit pas voir :

- les cours ;
- les devoirs de classe ;
- les professeurs ;
- les salles ;
- les annonces de classe ;
- les messages d’entraide d’une classe.

Dans le backend, les routes scolaires vérifient donc toujours que l’utilisateur courant possède un `SchoolClassId`.

### 2. Les données de classe sont isolées par `SchoolClassId`

Même si un utilisateur connaît l’identifiant d’un cours ou d’un devoir, l’API ajoute une condition de classe :

```csharp
x.SchoolClassId == user.SchoolClassId
```

Cela évite qu’un élève d’une autre classe récupère une ressource en devinant son identifiant.

### 3. Les suppressions logiques sont filtrées

Certains contenus sont supprimés de façon logique avec `DeletedAt`, pour garder une trace technique.

Les routes de lecture et de modification filtrent maintenant ces éléments :

```csharp
x.DeletedAt == null
```

Cela concerne notamment :

- cours ;
- devoirs de classe ;
- annonces ;
- messages d’entraide alternance ;
- rappels de notifications calculés à partir des cours/devoirs.

Un élément supprimé ne doit donc plus ressortir dans l’app, le tableau de bord ou les rappels.

## Ce qui est chiffré en base

Le projet utilise `ISensitiveDataProtector`, basé sur ASP.NET Core Data Protection.

Les données suivantes sont chiffrées au niveau applicatif avant d’être écrites dans PostgreSQL :

| Donnée | Pourquoi |
| :--- | :--- |
| Code de classe lisible | Évite qu’un code d’accès soit visible directement en base. |
| Nom affiché du professeur | Évite de divulguer les noms des professeurs en cas de fuite. |
| Informations du professeur | Peut contenir des coordonnées ou notes internes. |
| Données précises d’un cours | Contient horaires exacts et salle. |
| Événements personnels | Peut contenir entretiens, lieux, notes de candidature. |
| Messages d’entraide alternance | Peut contenir des liens, contacts ou infos d’entreprise. |
| Snapshots de contribution | Historique technique des modifications. |

Les cours gardent seulement en clair ce qui est nécessaire pour requêter efficacement :

- identifiant de classe ;
- matière ;
- jour ;
- statut annulé ;
- version.

Les horaires précis et la salle sont dans `EncryptedData`.

## Hash de recherche

Pour retrouver une donnée sans la stocker en clair, le backend utilise parfois un hash HMAC.

Règle retenue pour StudyFlow :

- secret à vérifier mais jamais à relire : hash ;
- donnée à réafficher ou réutiliser : chiffrement applicatif ;
- donnée publique ou nécessaire à l’UX collaborative : stockage clair assumé, avec isolation par classe.

Exemple : les professeurs.

On veut empêcher les doublons dans une classe, mais sans stocker le nom normalisé du professeur en clair. Le backend calcule donc :

```text
SearchNameHash = HMAC(Security:LookupKey, "teacher-search-name:NOM")
```

La clé `Security:LookupKey` doit être différente de la clé JWT.

Important : une donnée hachée ne peut pas être relue. StudyFlow hache donc les secrets et les valeurs utilisées uniquement pour chercher ou vérifier : mots de passe via ASP.NET Identity, refresh tokens, codes de classe de recherche, noms de professeurs normalisés, codes de réinitialisation de mot de passe et tokens techniques de notification. Les données qui doivent être affichées ou réutilisées restent chiffrées, pas hachées.

## Code de classe

Le code de classe est protégé de deux façons :

- `AccessCodeHash` : permet de retrouver la classe quand un élève saisit un code ;
- `EncryptedAccessCode` : permet au délégué de revoir le code actuel.

Le code déchiffré est retourné uniquement au délégué de la classe.

## JWT et refresh tokens

L’authentification utilise :

- access token JWT court ;
- refresh token long ;
- refresh token stocké en base sous forme de HMAC avec `Security:LookupKey` ;
- rotation du refresh token lors du renouvellement.

Le JWT reste volontairement minimal : il contient l’identifiant utilisateur, un identifiant unique de jeton, le security stamp et les rôles nécessaires à `[Authorize(Roles = ...)]`. Il ne contient plus les informations personnelles comme le prénom, le nom, l’e-mail ou l’identifiant de classe, car ces données peuvent changer et n’ont pas besoin d’être copiées dans chaque jeton.

À chaque requête authentifiée, le backend vérifie aussi que :

- l’utilisateur existe toujours ;
- son compte est actif ;
- le security stamp du JWT correspond au security stamp actuel en base.

Ainsi, un ancien JWT est invalidé si un changement sensible arrive, par exemple changement de rôle, retrait de classe ou réinitialisation de mot de passe.

Les endpoints sensibles d’authentification sont aussi protégés par un rate limiting applicatif : inscription, création de classe, connexion, refresh token, demande de reset et reset de mot de passe. En local, la limite est de 10 requêtes par minute et par adresse IP, avec réponse HTTP `429 Too Many Requests` en cas d’abus.

## Réinitialisation de mot de passe

Le backend génère un code de réinitialisation aléatoire temporaire. La base ne stocke jamais le code en clair : elle stocke seulement `TokenHash`, calculé avec HMAC-SHA256 et `Security:LookupKey`.

Le code est à usage unique :

- il expire après `Security:PasswordResetTokenMinutes` minutes ;
- il est marqué comme utilisé après changement du mot de passe ;
- les autres codes actifs du même utilisateur sont révoqués.
- les refresh tokens actifs de l’utilisateur sont aussi révoqués après changement du mot de passe.

En développement, le code est renvoyé dans la réponse API pour pouvoir tester sans service mail. En production, il doit être envoyé par e-mail et masqué dans la réponse.

Un refresh token brut n’est donc pas stocké directement en base.

## Notifications

Les préférences de notification appartiennent à l’utilisateur.

Les tokens d’appareil sont protégés de deux façons :

- `TokenHash` : permet de retrouver une installation sans stocker le token brut en clair ;
- `EncryptedToken` : permet au futur service d’envoi push de relire le token si nécessaire.

Ils ne sont jamais renvoyés en clair dans l’API : l’endpoint de liste retourne seulement une prévisualisation masquée.

Les rappels côté backend respectent :

- la classe de l’utilisateur ;
- les préférences globales ;
- les devoirs terminés ;
- les devoirs avec notification désactivée ;
- les cours/devoirs non supprimés.

## Limites actuelles

Certaines données restent en clair parce qu’elles servent directement à l’affichage collaboratif :

- nom de classe ;
- année scolaire ;
- matières ;
- titres et descriptions de devoirs ;
- annonces officielles de classe.

Pour une version production stricte, il faudrait décider si les devoirs et annonces doivent aussi être chiffrés. Pour le MVP étudiant, la priorité de confidentialité demandée était surtout :

- noms des professeurs ;
- horaires précis ;
- salles ;
- événements personnels ;
- messages d’entraide.

## Checklist pour une nouvelle route API

Avant d’ajouter une route scolaire, vérifier :

1. La route est protégée par `[Authorize]`.
2. Elle n’accepte pas de `schoolClassId` fourni par le client élève.
3. Elle récupère la classe depuis l’utilisateur connecté.
4. Elle filtre toujours `SchoolClassId == user.SchoolClassId`.
5. Elle filtre `DeletedAt == null` si l’entité est supprimable logiquement.
6. Elle retourne `NotFound` pour une ressource d’une autre classe.
7. Elle ne log pas de donnée déchiffrée.
8. Les champs sensibles sont chiffrés avant sauvegarde.
