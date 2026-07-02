# Contrat initial de l’API

Ce document définit les échanges nécessaires au MVP. L’implémentation ASP.NET Core devra produire une documentation OpenAPI cohérente avec ce contrat.

## 1. Conventions

- Préfixe : `/api/v1`
- Format : JSON UTF-8
- Dates et heures : ISO 8601 en UTC
- Authentification : `Authorization: Bearer <access_token>`
- Identifiants : UUID sous forme de chaîne
- Pagination publique : `page` et `pageSize`
- Taille maximale par défaut : 20 éléments
- Taille maximale autorisée : 50 éléments

Les noms JSON utilisent le `camelCase`.

## 2. Format des erreurs

Les erreurs suivent le format Problem Details.

```json
{
  "type": "https://studyflow.example/errors/validation",
  "title": "Données invalides",
  "status": 400,
  "detail": "Un ou plusieurs champs sont invalides.",
  "traceId": "00-abc-123",
  "errors": {
    "dateFin": ["La date de fin doit être postérieure à la date de début."]
  }
}
```

Codes principaux :

- `400` : paramètres ou contenu invalides ;
- `401` : authentification absente ou invalide ;
- `403` : rôle ou classe non autorisé ;
- `404` : ressource inexistante ou non visible ;
- `409` : conflit fonctionnel, par exemple un horaire incompatible ;
- `429` : trop de requêtes sur une route publique ;
- `502` ou `503` : source externe temporairement indisponible.

Une ressource scolaire appartenant à une autre classe est traitée comme inexistante afin de ne pas révéler sa présence.

## 3. Authentification

### `POST /api/v1/auth/login`

Public. Connecte un utilisateur.

```json
{
  "email": "eleve@example.fr",
  "password": "mot-de-passe"
}
```

### `POST /api/v1/auth/register`

Public. Crée un compte personnel sans exiger de code de classe. Le rattachement scolaire est une étape distincte.

### `POST /api/v1/auth/register-and-create-class`

Public. Crée atomiquement le compte du visiteur, sa classe, son rattachement approuvé et les rôles `Eleve` et `Delegue`. La réponse contient la session et le code initial de la classe. Une limitation de débit et une vérification d’adresse e-mail protègent ce parcours contre la création automatisée de classes.

Réponse `200` :

```json
{
  "accessToken": "jwt",
  "expiresAt": "2026-06-22T15:00:00Z",
  "refreshToken": "opaque-token",
  "user": {
    "id": "uuid",
    "email": "eleve@example.fr",
    "prenom": "Camille",
    "nom": "Martin",
    "roles": ["Eleve"],
    "classe": {
      "id": "uuid",
      "nom": "L2-A"
    }
  }
}
```

### `POST /api/v1/auth/refresh`

Public avec un jeton de renouvellement valide. Renouvelle la session et effectue une rotation du refresh token.

### `POST /api/v1/auth/logout`

Authentifié. Révoque le refresh token fourni.

### `POST /api/v1/auth/forgot-password`

Public. Reçoit un e-mail et prépare un code de réinitialisation temporaire. La réponse reste générique pour éviter de révéler si le compte existe. En développement seulement, la réponse peut contenir `developmentToken` pour tester sans serveur mail.

### `POST /api/v1/auth/reset-password`

Public. Reçoit `email`, `token` et `newPassword`. Le backend compare le hash du token reçu avec le hash stocké en base, puis réinitialise le mot de passe si le code est valide, non expiré et non utilisé.

### `GET /api/v1/me`

Authentifié. Retourne l’utilisateur courant, ses rôles, sa classe éventuelle et ses préférences utiles à l’interface. `classe` vaut `null` pour un futur élève qui utilise uniquement les alternances.

### `POST /api/v1/classes/rejoindre`

Authentifié sans classe. Reçoit un code valide et crée une demande d’adhésion `EnAttente`. La réponse ne contient ni nom de professeur, ni cours, ni annonce, ni autre donnée de la classe.

### `GET /api/v1/classes/demande-courante`

Retourne uniquement le statut de la demande courante : `EnAttente`, `Approuvee`, `Refusee` ou `Annulee`.

## 4. Tableau de bord

### `GET /api/v1/dashboard`

Authentifié. Retourne une vue agrégée contenant :

- le prochain cours et sa salle ;
- les devoirs ou projets à échéance proche ;
- les tâches personnelles à faire ;
- les annonces épinglées ;
- les prochaines échéances Entreprise si ce mode est activé.

Sans classe approuvée, cette route retourne le prochain événement personnel et les tâches `Alternance`, sans aucun contenu scolaire.

## 5. Alternances publiques

### `GET /api/v1/public/alternances`

Public. Paramètres :

| Paramètre | Obligatoire | Description |
| :--- | :---: | :--- |
| `q` | Oui | Texte utilisateur servant à proposer un métier |
| `romeCodes` | Oui pour la recherche finale | Codes ROME issus du métier sélectionné |
| `location` | Non | Ville, code postal ou zone |
| `distanceKm` | Non | Rayon lorsque la source le permet |
| `educationLevel` | Non | Niveau d’études normalisé |
| `page` | Non | Page, valeur initiale `1` |
| `pageSize` | Non | De `1` à `50` |

Le client commence par résoudre `q` en suggestions de métiers. Le backend n’envoie à la source externe que les codes et filtres qu’elle prend réellement en charge.

### `GET /api/v1/public/alternances/metiers`

Public. Reçoit `q` et retourne une courte liste de métiers avec leur libellé et leurs codes ROME. La première version peut utiliser un référentiel limité aux domaines de la classe ; la version publique devra utiliser un référentiel officiel complet.

Réponse `200` :

```json
{
  "items": [
    {
      "source": "provider",
      "externalId": "12345",
      "title": "Développeur en alternance",
      "company": "Entreprise Exemple",
      "location": "Paris",
      "publishedAt": "2026-06-20T08:00:00Z",
      "contractType": "Apprentissage",
      "summary": "Description courte normalisée",
      "applicationUrl": "https://source.example/offres/12345"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "total": 142,
  "hasNextPage": true
}
```

Si le fournisseur ne communique pas le total, `total` vaut `null` et `hasNextPage` reste utilisable.

### `GET /api/v1/public/alternances/{source}/{externalId}`

Public. Retourne le détail normalisé et l’URL d’origine. Aucun contenu provenant d’une source externe ne doit être conservé ou redistribué au-delà de ses conditions d’utilisation.

## 6. Données personnelles liées aux alternances

Toutes ces routes nécessitent une authentification.

### Recherches sauvegardées

- `GET /api/v1/alternances/recherches`
- `POST /api/v1/alternances/recherches`
- `PUT /api/v1/alternances/recherches/{id}`
- `DELETE /api/v1/alternances/recherches/{id}`

Création :

```json
{
  "nom": "Développement autour de Paris",
  "motsCles": "développeur web",
  "localisation": "Paris",
  "distanceKm": 30,
  "filtres": {
    "educationLevel": "BacPlus2"
  },
  "alerteActive": false
}
```

### Favoris

- `GET /api/v1/alternances/favoris`
- `POST /api/v1/alternances/favoris`
- `DELETE /api/v1/alternances/favoris/{id}`

Le `POST` reçoit les informations normalisées de l’offre affichée. L’API vérifie l’URL, la source, les longueurs et l’unicité avant l’enregistrement.

## 7. Calendrier collaboratif

### `GET /api/v1/courses`

Authentifié. Paramètres obligatoires : `from` et `to`. L’API utilise toujours la classe de l’utilisateur connecté, sans accepter un `classeId` fourni par un élève.

Les champs chiffrés sont déchiffrés uniquement après vérification de l’appartenance approuvée. Les réponses et journaux techniques ne mettent jamais en cache un nom de professeur ou un horaire précis hors du périmètre autorisé.

### `GET /api/v1/courses/{id}`

Authentifié. Retourne un cours visible par l’utilisateur.

### `POST /api/v1/courses`

Authentifié. Tout élève peut créer un cours dans sa propre classe. La classe est déduite de l’utilisateur connecté.

```json
{
  "subjectId": "uuid",
  "teacherId": "uuid",
  "day": "2026-09-07",
  "startsAt": "08:00",
  "endsAt": "10:00",
  "room": "B204",
  "isCancelled": false
}
```

L’API renvoie `409` si un conflit horaire est détecté avec un autre cours actif de la même classe sur la même date.

### Modification collaborative

- `PUT /api/v1/courses/{id}` : corrige une occurrence de sa classe ;
- `DELETE /api/v1/courses/{id}` : supprime logiquement une occurrence de la classe.

Chaque opération conserve l’auteur et la date. N’importe quel élève de la classe peut modifier, supprimer ou restaurer une contribution.

Aucune route d’approbation par un délégué n’existe pour les cours. Un jeton de version est envoyé lors d’une modification afin de détecter un écrasement concurrent.

- `GET /api/v1/courses/{id}/revisions` : historique minimal ;
- `POST /api/v1/courses/{id}/restore-latest` : restaure le dernier état disponible.

## 8. Devoirs et projets collectifs

- `GET /api/v1/devoirs?from=&to=&completed=`
- `GET /api/v1/devoirs/{id}`
- `POST /api/v1/devoirs`
- `PUT /api/v1/devoirs/{id}`
- `DELETE /api/v1/devoirs/{id}`
- `PUT /api/v1/devoirs/{id}/suivi`

Mise à jour du suivi individuel :

```json
{
  "estTermine": true,
  "notificationActive": false
}
```

Tout élève peut créer un devoir ou projet pour sa propre classe. La classe du devoir et celle du cours associé doivent être identiques. L’état d’avancement reste individuel.

## 9. Tâches personnelles

Authentifié. Chaque route utilise l’utilisateur courant comme propriétaire.

- `GET /api/v1/taches?from=&to=&completed=`
- `GET /api/v1/taches/{id}`
- `POST /api/v1/taches`
- `PUT /api/v1/taches/{id}`
- `DELETE /api/v1/taches/{id}`

L’API n’accepte jamais de champ `utilisateurId` dans les commandes de création ou de modification. Le champ `categorie` accepte `Ecole`, `Alternance` ou `Entreprise`.

### Événements personnels

- `GET /api/v1/personal-agenda/events?from=&to=&category=`
- `POST /api/v1/personal-agenda/events`
- `PUT /api/v1/personal-agenda/events/{id}`
- `DELETE /api/v1/personal-agenda/events/{id}`

Ces routes sont disponibles à tout utilisateur connecté, même sans classe. Le titre, le lieu, les notes et l’horaire précis sont chiffrés avant stockage.

## 10. Classe et fonctions délégué

Toutes les routes `/api/v1/delegue/*` nécessitent le rôle `Delegue` et ciblent uniquement sa classe.

### Classe et code d’accès

- `GET /api/v1/classe` : informations de la classe courante ;
- `PUT /api/v1/delegue/classe` : modifie les informations communes autorisées ;
- `GET /api/v1/delegue/classe/code` : retourne le code actif au délégué autorisé depuis sa valeur chiffrée ;
- `POST /api/v1/delegue/classe/code/renouveler` : invalide l’ancien code et retourne le nouveau une seule fois.

### Matières

- `GET /api/v1/matieres`
- `POST /api/v1/delegue/matieres`
- `PUT /api/v1/delegue/matieres/{id}`
- `DELETE /api/v1/delegue/matieres/{id}` : archive si la matière est déjà utilisée.

### Professeurs

- `GET /api/v1/professeurs`
- `POST /api/v1/delegue/professeurs`
- `PUT /api/v1/delegue/professeurs/{id}`
- `DELETE /api/v1/delegue/professeurs/{id}` : archive si le professeur est déjà utilisé.

### Membres et délégués

- `GET /api/v1/classes/current/members`
- `GET /api/v1/delegate/membership-requests`
- `POST /api/v1/delegate/membership-requests/{id}/approve`
- `POST /api/v1/delegate/membership-requests/{id}/reject`
- `DELETE /api/v1/classes/current/members/{id}` : retire l’élève de la classe sans supprimer son compte ;
- `POST /api/v1/classes/current/members/{id}/make-delegate`
- `POST /api/v1/classes/current/delegate-role/leave`

L’API refuse qu’un délégué se retire lui-même si cela laisse la classe sans délégué actif. Elle ne propose pas de route pour retirer le rôle délégué d’un autre élève.

L’approbation est transactionnelle : elle vérifie que le demandeur est toujours sans classe, rattache son compte, attribue le rôle `Eleve` et clôt la demande. Une demande en attente n’autorise aucune lecture scolaire.

Le code actif ne doit jamais apparaître dans les journaux applicatifs, traces ou messages d’erreur.

## 11. Fil d’informations

- `GET /api/v1/annonces?before=&limit=`
- `POST /api/v1/delegue/annonces`
- `PUT /api/v1/delegue/annonces/{id}`
- `DELETE /api/v1/delegue/annonces/{id}`
- `POST /api/v1/delegue/annonces/{id}/epingler`
- `DELETE /api/v1/delegue/annonces/{id}/epingler`

Les annonces sont isolées par classe et publiées uniquement par les délégués. Aucun WebSocket ou chat temps réel n’est requis pour le MVP.

## 12. Entraide alternance de la classe

- `GET /api/v1/alternances/entraide?before=&limit=`
- `POST /api/v1/alternances/entraide`
- `DELETE /api/v1/alternances/entraide/{id}` : auteur du message ;
- `DELETE /api/v1/delegue/alternances/entraide/{id}` : modération.

Ce canal accepte un texte court et un lien d’offre facultatif. Il est réservé aux membres approuvés de la même classe, chiffré en base et distinct du fil d’annonces officielles. Une première version peut utiliser du rafraîchissement périodique ; le temps réel n’est pas obligatoire.

## 13. Profil, réglages et notifications

- `GET /api/v1/profil`
- `PUT /api/v1/profil`
- `GET /api/v1/reglages`
- `PUT /api/v1/reglages`

- `GET /api/v1/notifications/preferences`
- `PUT /api/v1/notifications/preferences`
- `GET /api/v1/notifications/devices`
- `POST /api/v1/notifications/devices`
- `DELETE /api/v1/notifications/devices/{id}`
- `GET /api/v1/notifications/due-preview?lookBehindMinutes=5&lookAheadMinutes=60` : délégué uniquement.

L’enregistrement d’un appareil associe un jeton de notification à l’utilisateur courant. Le jeton est remplacé ou désactivé lorsqu’il devient invalide.

`PUT /api/v1/notifications/preferences` accepte `coursRappelMinutes` avec les valeurs `0`, `5`, `10`, `15`, `30` ou `60`.

Le service de fond `NotificationDispatchWorker` peut être activé avec `NotificationWorker__Enabled=true`. Il s’appuie sur la table `notification_deliveries` pour ne pas renvoyer plusieurs fois le même rappel.

Les réglages comprennent notamment le thème, le mode Entreprise, les préférences de notification et les options d’accessibilité retenues. Le thème peut rester local au client, tandis que les préférences devant suivre l’utilisateur sont synchronisées.

## 14. Protections des routes publiques

Les recherches publiques doivent utiliser :

- une limitation par adresse IP et fenêtre temporelle ;
- une limite globale pour protéger le quota du fournisseur ;
- un cache court basé sur les critères normalisés ;
- une longueur maximale pour chaque paramètre ;
- un délai d’expiration lors des appels externes ;
- aucune clé de fournisseur dans le client Flutter ;
- des journaux sans contenu personnel sensible.

## 15. Confidentialité des données scolaires

- L’API refuse les données scolaires à un compte sans rattachement approuvé.
- Les noms et informations de professeurs, salles et horaires précis sont chiffrés avant écriture dans PostgreSQL.
- La clé de chiffrement est fournie par la configuration sécurisée et reste distincte de la base.
- Les requêtes de calendrier utilisent la classe et le jour indexables, puis déchiffrent les détails en mémoire.
- Les valeurs déchiffrées sont exclues des logs, traces, réponses d’erreur et caches partagés.
- Les entités supprimées logiquement sont filtrées avec `DeletedAt == null` dans les réponses API, le tableau de bord et les rappels.

## 16. Points à confirmer avant implémentation

- fournisseur d’offres et filtres réellement disponibles ;
- durée du cache public ;
- fréquence et règles des alertes d’alternance ;
- modification d’une occurrence ou d’une série récurrente ;
- méthode de suppression d’un devoir déjà suivi par des élèves.
- gestionnaire de clés retenu pour la production ;
- durée de conservation du canal d’entraide.
