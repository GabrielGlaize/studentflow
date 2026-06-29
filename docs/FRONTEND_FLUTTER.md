# Application Flutter : ce qui est implémenté et pourquoi

Dernière mise à jour : 25 juin 2026.

## Objectif de l’app

L’application Flutter est la partie mobile de StudyFlow. Elle doit rester simple à relire par une équipe étudiante, mais assez propre pour pouvoir évoluer sans tout casser.

Le principe produit est le suivant :

- les élèves approuvés d’une classe peuvent corriger eux-mêmes les cours et devoirs ;
- le délégué ne valide pas les contenus scolaires, il gère seulement l’accès à la classe et les informations communes ;
- un futur élève sans classe peut quand même utiliser l’app pour organiser sa recherche d’alternance ;
- les réglages importants doivent pouvoir être gardés localement et synchronisés avec l’API quand elle est activée.

## Organisation du code

Le code Flutter est rangé par fonctionnalité dans `src/app/lib/features`.

Exemples :

- `auth` : connexion, inscription, restauration de session ;
- `classes` : code de classe, demandes d’adhésion, rôle délégué ;
- `schedule` : emploi du temps et CRUD des cours ;
- `agenda` : devoirs de classe et tâches personnelles ;
- `profile` : réglages, préférences et gestion de classe ;
- `notifications` : calcul des rappels prévus.

Les fichiers sont généralement séparés en trois familles :

- `domain` : modèles simples, proches de ce que l’API renvoie ;
- `data` : repositories démo ou HTTP ;
- `presentation` : écrans et widgets Flutter.

Ce découpage évite d’avoir toute la logique dans les écrans.

## Environnements dev, prod et repositories de démonstration

Par défaut, l’app démarre maintenant en mode dev réel : elle appelle le backend local.

Sur Android Emulator, l’URL locale est automatiquement `http://10.0.2.2:5028`. Sur les autres cibles locales, l’app utilise `http://localhost:5028`, sauf si `STUDYFLOW_API_URL` est fourni.

Commandes principales :

```bash
flutter run

flutter run -t lib/main_prod.dart \
  --dart-define=STUDYFLOW_API_URL=https://ton-api-prod.example.com
```

Pourquoi ce choix ?

- le dev ressemble à une vraie app, avec backend et base seedée ;
- la prod n’embarque pas de données locales ;
- les repositories de démonstration restent disponibles uniquement pour les tests ou une présentation sans backend.

## Authentification réelle

L’app sait maintenant gérer :

- connexion ;
- inscription ;
- inscription avec création de classe ;
- inscription sans classe avec code optionnel ;
- restauration de session ;
- refresh du token quand il arrive bientôt à expiration ;
- messages d’erreur plus lisibles en cas de validation API, mauvais mot de passe ou réseau indisponible.

Le contrôleur principal est `SessionController`. Il centralise l’état de session pour éviter que chaque écran gère son propre token.

## Classes et rôle délégué

Le parcours classe couvre maintenant :

- créer une classe ;
- devenir automatiquement délégué quand on crée la classe ;
- afficher et partager le code de classe ;
- rejoindre une classe avec un code ;
- approuver ou refuser une demande d’adhésion ;
- régénérer le code de classe ;
- modifier les informations principales de la classe ;
- afficher les actions délégué seulement au bon rôle.

Le rôle délégué reste volontairement léger. Il ne sert pas à approuver les cours ou devoirs, car le concept StudyFlow repose sur l’autosuffisance des élèves.

## Cours et devoirs collaboratifs

Les élèves approuvés peuvent :

- créer un cours ;
- modifier un cours ;
- supprimer un cours ;
- créer un devoir de classe ;
- modifier un devoir de classe ;
- supprimer un devoir de classe.

C’est le cœur du concept : si un cours ou un devoir est mal rempli, un autre élève peut corriger directement.

## Agenda personnel

L’agenda sépare :

- les devoirs de classe ;
- les tâches personnelles école ;
- les tâches de recherche d’alternance ;
- les tâches entreprise quand l’élève active le mode Entreprise ;
- les événements personnels : entretiens, relances, rendez-vous alternance ou points entreprise.

Cela permet à StudyFlow de servir à la fois aux élèves déjà en classe et aux futurs élèves qui cherchent une alternance.

## Alternances

L’écran Alternances couvre maintenant :

- recherche d’offres via le repository alternance ;
- sauvegarde d’une recherche avec mots-clés et ville ;
- relance rapide d’une recherche sauvegardée ;
- suppression d’une recherche sauvegardée ;
- ajout d’une offre en favori ;
- retrait d’une offre des favoris ;
- ouverture de l’offre sur le site source ;
- entraide privée de classe pour partager un message et un lien d’offre.

En mode démo, les favoris et recherches sont gardés en mémoire. En mode API réelle, le repository HTTP appelle les endpoints `/api/v1/apprenticeships/saved-searches` et `/api/v1/apprenticeships/favorite-offers`.

## Notifications

La V1 Flutter calcule maintenant les rappels prévus :

- rappel avant un cours selon le délai choisi : 0, 5, 10, 15, 30 ou 60 minutes ;
- rappel de devoir la veille de la deadline ;
- respect des préférences globales de notifications ;
- exclusion des cours annulés ;
- exclusion des devoirs déjà terminés ou avec notification désactivée.

Les rappels sont visibles dans `Profil et réglages > Rappels prévus`.

L’app utilise maintenant `flutter_local_notifications` via `NativeLocalNotificationScheduler`. Elle conserve la liste en mémoire pour l’affichage et les tests, puis programme les notifications locales sur l’appareil quand la plateforme le permet.

Notes importantes :

- la logique métier est testable sans configuration iOS/Android complexe ;
- les règles de rappel sont déjà visibles dans l’app ;
- Android demande la permission `POST_NOTIFICATIONS` ;
- le dossier iOS n’est pas encore présent dans le workspace actuel, donc la configuration iPhone devra être générée avec la plateforme iOS Flutter :

```bash
cd src/app
flutter create --platforms=ios .
open ios/Runner.xcworkspace
```

Dans Xcode, il faudra ensuite choisir une équipe Apple dans `Runner > Signing & Capabilities`, puis tester les notifications sur un vrai iPhone.

## Réglages

L’écran Profil gère :

- thème clair, sombre ou système ;
- mode Alternance ou Entreprise ;
- nom d’entreprise ;
- notifications de cours ;
- délai de rappel avant cours ;
- notifications de devoirs ;
- notifications alternance.

Les préférences sont sauvegardées localement et synchronisables avec l’API.

## Finition UI

La passe de finition UI a ajouté des états visuels communs :

- chargement pleine page ;
- erreur récupérable avec bouton `Réessayer` ;
- état vide explicatif ;
- cartes cohérentes avec la direction artistique du prototype HTML.

Les écrans concernés sont notamment :

- tableau de bord ;
- emploi du temps ;
- agenda ;
- alternances ;
- profil ;
- espace entreprise.

Les lignes de réglages sont maintenant entièrement cliquables, pas seulement le petit switch à droite. C’est plus confortable sur smartphone.

## Qualité et tests

Les tests couvrent notamment :

- parsing des modèles API ;
- repositories démo ;
- session et refresh token ;
- erreurs réseau/API ;
- logique de rappels ;
- parcours widget principal.

Commandes utiles :

```bash
cd src/app
flutter analyze
flutter test
```

Le backend peut être vérifié séparément :

```bash
dotnet build src/backend/StudyFlow.Api/StudyFlow.Api.csproj
```

## Ce qui reste côté Flutter

Les gros blocs restants sont :

- filtres avancés et alertes automatiques pour les alternances ;
- génération et vérification du dossier iOS ;
- captures finales et micro-ajustements visuels après test sur vrai iPhone ;
- revue sécurité/confidentialité finale ;
- captures d’écran finales pour le rendu.
