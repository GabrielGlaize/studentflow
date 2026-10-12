# Application Flutter : ce qui est implémenté et pourquoi

Dernière mise à jour : 4 juillet 2026.

## Objectif de l’app

L’application Flutter est la partie mobile de Swikko. Elle doit rester simple à relire par une équipe étudiante, mais assez propre pour pouvoir évoluer sans tout casser.

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
- `announcements` : fil officiel et annonces épinglées ;
- `apprenticeships` : recherche, favoris, recherches sauvegardées et entraide ;
- `company` : espace Entreprise, ressources, contacts et documents ;
- `profile` : réglages, préférences et gestion de classe ;
- `notifications` : calcul des rappels prévus.

Les fichiers sont généralement séparés en trois familles :

- `domain` : modèles simples, proches de ce que l’API renvoie ;
- `data` : repositories démo ou HTTP ;
- `presentation` : écrans et widgets Flutter.

Ce découpage évite d’avoir toute la logique dans les écrans.

## Environnements dev, prod et démo

L’environnement est choisi à la compilation par un fichier de `src/app/config/`
(`--dart-define-from-file`), lu par `AppEnvironment.fromDefines()` :

| Fichier     | Environnement | API                                                 |
|-------------|---------------|-----------------------------------------------------|
| `dev.json`  | Développement | API du Mac (`make dev`), bandeau « DEV »            |
| `prod.json` | Production    | API du NAS                                          |
| `demo.json` | Démonstration | aucune : repositories de démonstration intégrés     |

Les scripts passent le bon fichier :

```bash
make app-dev     # ./scripts/install_app.sh --env=dev  : appareil branché, API du Mac
make app-prod    # ./scripts/install_app.sh --env=prod --release
make app-demo    # ./scripts/install_app.sh --env=demo
make app-web     # ./scripts/run_app.sh --env=dev --device=chrome
```

En dev, le script ajoute l’adresse du Mac vue depuis l’appareil (`--dart-define=STUDYFLOW_API_URL=…`,
qui l’emporte sur le fichier) : l’IP du Mac pour un appareil physique, `10.0.2.2` pour
l’émulateur Android, `localhost` pour le simulateur iOS. Paramètres › Application affiche
l’environnement et l’adresse du serveur utilisés.

`install_app.sh` copie aussi le projet vers `/Users/gab/Developer/studentflow` et nettoie les
attributs macOS qui peuvent casser la signature iOS.

Pourquoi ce choix ?

- le dev ressemble à une vraie app, avec backend et base seedée ;
- la prod n’embarque pas de données locales ;
- les repositories de démonstration servent aux tests et au mode démo, sans backend.

## Authentification réelle

L’app sait maintenant gérer :

- connexion ;
- affichage ou masquage du mot de passe ;
- inscription ;
- inscription avec création de classe ;
- inscription sans classe avec code optionnel ;
- restauration de session ;
- refresh du token quand il arrive bientôt à expiration ;
- demande et saisie d’un code de réinitialisation de mot de passe ;
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
- afficher les actions délégué seulement au bon rôle ;
- lister les membres ;
- retirer un élève ;
- nommer un autre délégué ;
- quitter son propre rôle délégué.

Le rôle délégué reste volontairement léger. Il ne sert pas à approuver les cours ou devoirs, car le concept Swikko repose sur l’autosuffisance des élèves.

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

Cela permet à Swikko de servir à la fois aux élèves déjà en classe et aux futurs élèves qui cherchent une alternance.

## Alternances

L’écran Alternances couvre maintenant :

- recherche d’offres via le repository alternance ;
- interrogation du backend, qui agrège La Bonne Alternance, Adzuna et France Travail lorsque les clés sont configurées ;
- sauvegarde d’une recherche avec mots-clés et ville ;
- relance rapide d’une recherche sauvegardée ;
- suppression d’une recherche sauvegardée ;
- ajout d’une offre en favori ;
- retrait d’une offre des favoris ;
- ouverture de l’offre sur le site source ;
- entraide privée de classe pour partager un message et un lien d’offre.

En mode démo, les favoris et recherches sont gardés en mémoire. En mode API réelle, le repository HTTP appelle les endpoints `/api/v1/apprenticeships/saved-searches` et `/api/v1/apprenticeships/favorite-offers`.

## Travail de groupe

Dossier `lib/features/groups`. Un groupe est un espace privé entre quelques
élèves d'une même classe, rattaché si besoin à un devoir (qui donne la date de
rendu) et à un cours :

- **Discussion** en temps réel (`SignalRGroupRealtime`, hub `/hubs/groups`). Les
  messages partent par l'API REST, qui les enregistre puis les diffuse ; si la
  connexion temps réel tombe, l'onglet relit le fil toutes les 10 secondes ;
- **Tâches** affectées aux membres, qui arrivent dans leur agenda ;
- **Organiser** : créneaux communs calculés par le serveur (planning de la classe,
  jours en entreprise, agendas perso vus seulement comme « occupé »), réunions à
  valider par tous, rappel local 30 minutes avant ;
- **Fichiers** : mêmes règles que les fiches de révision, chiffrés en base.

Un devoir marqué « travail de groupe » affiche qui a déjà un groupe et qui est
encore seul. En démo et dans les tests, `DemoGroupRepository` et
`LocalGroupRealtime` remplacent le serveur.

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
- iOS nécessite une signature Apple valide dans Xcode ;
- le lancement iPhone est simplifié par le script racine :

```bash
./scripts/install_app.sh
```

Dans Xcode, il faut garder une équipe Apple valide dans `Runner > Signing & Capabilities`, puis tester les notifications sur un vrai iPhone.

## Réglages

L’écran Profil gère :

- thème clair, sombre ou système ;
- mode Alternance ou Entreprise ;
- nom d’entreprise ;
- ressources, documents et contacts utiles dans l’espace Entreprise ;
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
- captures finales et micro-ajustements visuels après test sur vrai iPhone ;
- vraie distribution TestFlight/Play Store si le projet sort du cadre local ;
- vrai service mail pour la réinitialisation de mot de passe en production ;
- captures d’écran finales pour le rendu.
