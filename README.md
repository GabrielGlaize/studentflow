# StudyFlow Pro

StudyFlow Pro est un projet annuel autour de l'organisation scolaire et de la
recherche d'alternance. L'application aide une classe à centraliser son emploi
du temps, ses devoirs, ses annonces importantes, ses ressources et son suivi
carrière.

Le dépôt public présente le produit, l'application Flutter et une version
backend démontrable. Les éléments de déploiement privé, les secrets et les
paramètres d'infrastructure réelle ne sont pas publiés ici.

## Fonctionnalités

- application Flutter Android, iOS, Web et desktop ;
- authentification, inscription et création de classe ;
- demandes d'adhésion validées par un délégué ;
- planning, devoirs, annonces et ressources de classe ;
- espace personnel pour tâches, événements et recherche d'alternance ;
- recherche publique d'alternance avec données de démonstration si les sources
  externes ne sont pas configurées ;
- préférences utilisateur et thème clair/sombre.

## Architecture

```text
src/
├── app/                         Application Flutter
└── backend/
    ├── StudyFlow.Api/           Entrées HTTP et configuration
    ├── StudyFlow.Application/   Cas d'usage
    ├── StudyFlow.Domain/        Modèle métier
    └── StudyFlow.Infrastructure/ Persistance et services techniques
```

## Backend public

Le backend public est fourni pour démonstration et revue de code. Il contient :

- le modèle applicatif ;
- les contrôleurs API ;
- le seeder de démonstration ;
- une configuration de production sans secret.

Aucune clé, aucun jeton, aucun mot de passe de production et aucune instruction
de déploiement privé ne doivent être ajoutés au dépôt public. En production, les
valeurs sensibles doivent venir d'un gestionnaire de secrets ou de variables
d'environnement côté hébergeur.

Variables attendues côté environnement privé :

```text
ConnectionStrings__PostgreSql
Jwt__SigningKey
Security__LookupKey
Security__DataProtectionKeysPath
Email__Host
Email__UserName
Email__Password
```

Les fournisseurs externes d'alternance sont optionnels pour la démonstration.
Si aucune clé n'est fournie, les parcours restent testables avec les données de
démonstration prévues par le projet.

## Lancement local de démonstration

Prérequis :

- SDK .NET 8 ;
- Flutter stable ;
- une base PostgreSQL locale ou distante configurée hors dépôt.

Backend :

```bash
dotnet run --project src/backend/StudyFlow.Api
```

Avant de lancer l'API, renseigner les variables d'environnement listées plus
haut avec des valeurs propres à l'environnement local.

Application Flutter :

```bash
cd src/app
flutter pub get
flutter run
```

Tests :

```bash
dotnet build StudyFlow.sln
cd src/app
flutter test
```

## Configuration de production

Le fichier [`src/backend/StudyFlow.Api/appsettings.Production.json`](./src/backend/StudyFlow.Api/appsettings.Production.json)
ne contient pas de secret. Il sert uniquement de profil de base. Les valeurs
réelles doivent être injectées par l'environnement d'exécution.

Le seeder de développement est désactivé hors environnement `Development`.

## Documentation produit

- [`CAHIER_DES_CHARGES.md`](./CAHIER_DES_CHARGES.md)
- [`docs/PARCOURS_UTILISATEURS.md`](./docs/PARCOURS_UTILISATEURS.md)
- [`docs/ARBORESCENCE_ECRANS.md`](./docs/ARBORESCENCE_ECRANS.md)
- [`docs/DESIGN_SYSTEM.md`](./docs/DESIGN_SYSTEM.md)
- [`docs/INTERFACE_WEB_ALTERNANCES.md`](./docs/INTERFACE_WEB_ALTERNANCES.md)

## Dépôt privé

La configuration d'infrastructure réelle doit rester dans un dépôt privé séparé.
