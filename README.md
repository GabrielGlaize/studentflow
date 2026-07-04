# StudyFlow Pro

StudyFlow aide une classe à partager son emploi du temps, ses devoirs et ses informations importantes. L’outil public de recherche d’alternances reste accessible sans compte depuis un navigateur.

Un compte sans classe peut organiser ses candidatures dans un planning personnel. Les rattachements scolaires sont approuvés par un délégué, tandis que les cours restent modifiables librement par tous les élèves approuvés. Les identités des professeurs, salles et horaires précis sont destinés à être chiffrés avant stockage.

## Tester l’application Flutter sur iPhone

Pour lancer StudyFlow sur un iPhone physique :

1. Installe et ouvre Xcode au moins une fois.
2. Branche l’iPhone en USB.
3. Sur l’iPhone, accepte “Faire confiance à cet ordinateur”.
4. Si iOS le demande, active le mode développeur dans `Réglages > Confidentialité et sécurité > Mode développeur`.
5. Depuis l’application Flutter, lance :

```bash
cd src/app
flutter doctor
flutter devices
flutter run -d ton_iphone
```

Si Xcode bloque la signature Apple :

```bash
open ios/Runner.xcworkspace
```

Dans Xcode, sélectionne `Runner`, puis `Signing & Capabilities`, et choisis ton Apple ID dans `Team`.

Par défaut, l’app utilise le backend réel. Depuis l’iPhone, il faut utiliser l’adresse IP du Mac sur le même Wi-Fi, pas `localhost` :

```bash
flutter run -d ton_iphone \
  --dart-define=STUDYFLOW_API_URL=http://192.168.1.42:5028
```

Remplace `192.168.1.42` par l’adresse IP locale de ton Mac.

## Stack

- API ASP.NET Core 8 ;
- architecture Domain / Application / Infrastructure / API ;
- application Flutter pour Android, Web et iOS à générer ;
- PostgreSQL 16, Entity Framework Core et ASP.NET Core Identity.

## Prérequis

- SDK .NET 8, ou SDK .NET 9 si `global.json` autorise le roll-forward majeur ;
- Flutter stable avec les plateformes Android, Web et iOS activées selon la machine.
- Docker Desktop ou une instance PostgreSQL locale.

## Base de données

Une instance PostgreSQL de développement est fournie :

```bash
docker compose up -d postgres
dotnet tool restore
dotnet ef database update \
  --project src/backend/StudyFlow.Infrastructure \
  --startup-project src/backend/StudyFlow.Infrastructure
```

La chaîne locale par défaut utilise la base, l’utilisateur et le mot de passe `studyflow`. En dehors du développement, utilise la variable `ConnectionStrings__PostgreSql` ou `STUDYFLOW_POSTGRES` pour la génération des migrations.

Le conteneur expose PostgreSQL sur le port hôte `5433` afin de ne pas entrer en conflit avec une installation PostgreSQL locale sur le port standard `5432`.

## Backend

```bash
dotnet restore StudyFlow.sln
dotnet run --project src/backend/StudyFlow.Api
```

En environnement `Development`, le backend applique les migrations et seed une classe locale si `DevelopmentSeed:Enabled=true`.

Par défaut, `DevelopmentSeed:ResetOnStartup=true` dans `appsettings.Development.json` : à chaque relance du backend, la base locale est supprimée puis recréée avec les données seedées. C’est pratique pour une démo propre. Pour conserver tes modifications locales entre deux lancements, passe cette valeur à `false`.

- compte délégué : `gabriel@studyflow.dev`
- élèves seedés : `garance@studyflow.dev`, `liam@studyflow.dev`
- demande d’approbation seedée : `nina@studyflow.dev`
- mot de passe : `Password1234!`
- classe : `BTS SIO 1`, année `2026-2027`
- cours principaux : C, Architecture web, HTML/CSS/JS, Administration Windows, Flutter, API ASP.NET Core, Base de données et Anglais.

Ces identifiants sont aussi affichés dans le terminal au lancement de `dotnet run`.

La recherche d’alternance agrège plusieurs sources côté backend : La Bonne Alternance, Adzuna et France Travail. Les vraies clés ne doivent pas être mises dans Git. En local, le backend charge automatiquement le fichier `.env` placé à la racine du projet :

```env
Adzuna__AppId=ton-app-id
Adzuna__AppKey=ton-app-key
FranceTravail__ClientId=ton-client-id
FranceTravail__ClientSecret=ton-client-secret
```

Sans clés configurées, l’API garde des résultats de démonstration pour les sources prévues à cet effet afin que l’app reste testable. France Travail nécessite un compte développeur et un couple client id/secret.

La réinitialisation de mot de passe utilise des codes temporaires stockés uniquement sous forme de hash en base. En environnement `Development`, l’API renvoie aussi le code dans la réponse pour tester sans serveur e-mail. En production, il faudra envoyer ce code par e-mail et ne jamais l’afficher dans la réponse.

Après ajout ou modification d’une entité backend, génère puis applique la migration :

```bash
dotnet ef migrations add AddPasswordResetTokens \
  --project src/backend/StudyFlow.Infrastructure \
  --startup-project src/backend/StudyFlow.Api

dotnet ef database update \
  --project src/backend/StudyFlow.Infrastructure \
  --startup-project src/backend/StudyFlow.Api
```

Points de contrôle disponibles :

- `GET /health`
- `GET /api/status`

Si ton poste ne détecte que le SDK .NET 9, le fichier `global.json` autorise maintenant le roll-forward majeur. Le projet reste ciblé sur .NET 8, mais le SDK 9 peut compiler la solution si les packs nécessaires sont présents.

## Flutter

```bash
cd src/app
flutter pub get
flutter run
```

Sur émulateur Android, `flutter run` utilise automatiquement `http://10.0.2.2:5028` pour joindre le backend du Mac.

Pour lancer le mode prod Flutter :

```bash
cd src/app
flutter run -t lib/main_prod.dart \
  --dart-define=STUDYFLOW_API_URL=https://ton-api-prod.example.com
```

Pour lancer les tests :

```bash
dotnet build StudyFlow.sln
cd src/app && flutter test
```

## État actuel du MVP Flutter

- authentification réelle branchable sur l’API : connexion, inscription, création de classe, refresh token, logout et restauration de session ;
- inscription sans classe avec code de classe optionnel pour envoyer immédiatement une demande d’adhésion ;
- création d’une classe avec attribution automatique du rôle délégué ;
- gestion délégué : code de classe, régénération du code, modification du nom/année, approbation et refus des demandes ;
- gestion délégué avancée : liste des membres, retrait d’un élève, nomination d’un autre délégué et retrait de son propre rôle délégué ;
- emploi du temps collaboratif : création, modification et suppression de cours par les élèves approuvés ;
- sécurité collaborative : conflit horaire détecté, historique de cours et restauration du dernier état ;
- agenda collaboratif : création, modification et suppression de devoirs de classe ;
- tâches et événements personnels séparés en espaces École et Carrière ;
- préférences synchronisables : thème, mode entreprise et préférences de notifications ;
- calcul, prévisualisation et programmation native des prochains rappels de cours/devoirs côté Flutter ;
- alternances : recherche d’offres, recherches sauvegardées, favoris et entraide de classe ;
- interface Web publique alternance branchée sur `/api/v1/public/alternances` avec fallback de démonstration ;
- sécurité : isolation par classe, chiffrement des données sensibles et filtrage des contenus supprimés ;
- espace Carrière avec ressources, contacts et raccourci vers les tâches carrière ;
- fil officiel de classe et entraide alternance de classe ;
- design mobile homogène inspiré du prototype HTML, avec états chargement/vide/erreur cohérents.

## Points encore à traiter

- générer le dossier iOS avec `flutter create --platforms=ios .` puis vérifier la signature Xcode ;
- amélioration avancée de la recherche alternance : filtres plus fins, alertes et tri ;
- fiche détail Web dynamique pour les offres publiques ;
- revue sécurité production : rotation des clés, chiffrement éventuel des devoirs/annonces, rate limiting ;
- captures d’écran finales et guide de démonstration.

## Organisation

```text
src/
├── app/                         Application Flutter Android/Web
└── backend/
    ├── StudyFlow.Api/           Entrées HTTP et configuration
    ├── StudyFlow.Application/   Cas d’usage
    ├── StudyFlow.Domain/        Modèle métier
    └── StudyFlow.Infrastructure/ Persistance et services externes
```

Les décisions fonctionnelles se trouvent dans [`CAHIER_DES_CHARGES.md`](./CAHIER_DES_CHARGES.md) et les documents détaillés dans [`docs`](./docs/), notamment [`docs/FRONTEND_FLUTTER.md`](./docs/FRONTEND_FLUTTER.md) pour comprendre l’application mobile et [`docs/SECURITE_CONFIDENTIALITE.md`](./docs/SECURITE_CONFIDENTIALITE.md) pour les choix de sécurité.
