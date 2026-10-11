# Swikko App

Application Flutter mobile et web de Swikko.

## Tester sur iPhone

Pour lancer l’app sur ton iPhone :

1. Installe et ouvre Xcode au moins une fois.
2. Branche l’iPhone en USB.
3. Sur l’iPhone, accepte “Faire confiance à cet ordinateur”.
4. Si iOS le demande, active le mode développeur dans `Réglages > Confidentialité et sécurité > Mode développeur`.
5. Lance :

```bash
flutter doctor
flutter devices
flutter run -d ton_iphone
```

Si tu as une erreur de signature Apple :

```bash
open ios/Runner.xcworkspace
```

Dans Xcode, sélectionne `Runner`, puis `Signing & Capabilities`, et choisis ton Apple ID dans `Team`.

Par défaut, l’app utilise maintenant le backend réel. Depuis un iPhone physique, remplace `localhost` par l’adresse IP locale du Mac :

```bash
flutter run -d ton_iphone \
  --dart-define=STUDYFLOW_API_URL=http://192.168.1.42:5028
```

`localhost` sur l’iPhone veut dire “l’iPhone lui-même”, pas ton Mac.

## État actuel

L’application contient maintenant :

- une navigation principale responsive ;
- un écran de connexion réel par défaut ;
- un contrôleur de session ;
- un tableau de bord connecté à un repository ;
- un écran Planning connecté à un repository ;
- création, modification et suppression de cours depuis le Planning ;
- un écran agenda connecté aux devoirs et tâches personnelles ;
- un formulaire de création de tâche personnelle depuis l’agenda ;
- des actions de tâche personnelle : marquer terminée/restaurer et supprimer ;
- un filtre pour afficher ou masquer les tâches terminées ;
- un écran alternances connecté à la recherche d’offres ;
- un écran profil avec réglages de thème, notifications et statut entreprise ;
- une section délégué dans le profil avec code de classe et approbation des élèves ;
- une navigation avec un onglet commun `Carrière` ;
- un écran Carrière dédié lorsque l’élève indique avoir une entreprise ;
- une sauvegarde locale des réglages avec `flutter_secure_storage` ;
- une brique `Documents importants` avec titre, type, lien et note ;
- une première brique fonctionnelle dans l’espace Carrière : contacts sauvegardés localement ;
- un raccourci `Tâches carrière` qui ouvre l’Agenda directement sur la catégorie professionnelle ;
- des modèles Dart alignés avec `GET /api/v1/dashboard` ;
- un profil minimal avec déconnexion ;
- des repositories de démonstration, utiles pour tester sans backend lancé ;
- un `HttpAuthRepository` prêt à appeler `POST /api/v1/auth/login`.
- un `HttpDashboardRepository` prêt à appeler `GET /api/v1/dashboard`.
- un `HttpCourseRepository` prêt à appeler `GET /api/v1/courses`.
- un `HttpAgendaRepository` prêt à appeler `GET /api/v1/homework`, `GET /api/v1/personal-agenda/tasks`, `POST /api/v1/personal-agenda/tasks`, `PUT /api/v1/personal-agenda/tasks/{id}` et `DELETE /api/v1/personal-agenda/tasks/{id}`.
- un `HttpApprenticeshipRepository` prêt à appeler `GET /api/v1/apprenticeships/opportunities`.
- un stockage de session avec `flutter_secure_storage` pour le mode backend réel.
- une déconnexion backend réelle via `POST /api/v1/auth/logout`.
- un refresh automatique de session via `POST /api/v1/auth/refresh`.

## Architecture

```text
lib/
├── core/
│   ├── app_scope.dart
│   ├── config/
│   └── theme/
└── features/
    ├── agenda/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── apprenticeships/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── auth/
    │   ├── application/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── dashboard/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── profile/
    │   └── presentation/
    ├── schedule/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── shell/
        └── presentation/
```

Le principe est simple :

- `domain` contient les modèles métier Flutter ;
- `data` contient les repositories qui récupèrent les données ;
- `presentation` contient les écrans et widgets ;
- `core` contient les éléments communs à toute l’app.

## Lancer l’application

Avec le backend lancé, sur émulateur Android :

```bash
flutter pub get
flutter run
```

L’app utilise automatiquement `http://10.0.2.2:5028` sur Android, ce qui permet à l’émulateur de joindre le backend lancé sur le Mac.

En dev, `lib/main.dart` est l’entrypoint normal. Il utilise le backend local par défaut et peut s’appuyer sur les données seedées par l’API en environnement `Development`.

En prod, utilise l’entrypoint `lib/main_prod.dart` :

```bash
flutter run -t lib/main_prod.dart \
  --dart-define=STUDYFLOW_API_URL=https://ton-api-prod.example.com
```

```bash
flutter pub get
flutter run -d chrome
```

Pour forcer une autre URL d’API :

```bash
flutter run -d chrome --dart-define=STUDYFLOW_API_URL=http://localhost:5028
```

## Vérifications

```bash
flutter analyze
flutter test
```

## Utiliser exceptionnellement les repositories de démonstration

Le backend réel est utilisé par défaut. Pour lancer l’app sans backend, force les repositories de démonstration :

```bash
flutter run -d chrome \
  --dart-define=STUDYFLOW_USE_DEMO_AUTH=true \
  --dart-define=STUDYFLOW_USE_DEMO_AGENDA=true \
  --dart-define=STUDYFLOW_USE_DEMO_APPRENTICESHIPS=true \
  --dart-define=STUDYFLOW_USE_DEMO_DASHBOARD=true \
  --dart-define=STUDYFLOW_USE_DEMO_COURSES=true
```

Dans ce mode, l’API ASP.NET Core n’a pas besoin de tourner.

Quand le backend réel est utilisé, la session est conservée dans un stockage sécurisé local. Au prochain lancement, l’app tente de restaurer la session avant d’afficher l’écran de connexion.

En mode démo, le stockage reste en mémoire uniquement pour éviter de sauvegarder de faux tokens sur la machine de développement.

Avant un appel API authentifié, l’app vérifie l’expiration de l’access token. S’il expire dans moins d’une minute, elle utilise le refresh token pour obtenir une nouvelle paire de tokens puis sauvegarde la session mise à jour.

## Agenda : fonctionnement actuel

L’écran Agenda affiche deux types d’informations :

- les devoirs de classe, partagés avec les autres élèves ;
- les tâches personnelles de l’élève, séparées entre `school`, `apprenticeship` et `company`.

Le bouton `Nouvelle tâche` ouvre un formulaire simple. En mode démo, la tâche est gardée en mémoire pendant la session. En mode backend réel, elle est envoyée à l’API via :

```http
POST /api/v1/personal-agenda/tasks
```

avec le titre, la description optionnelle, la catégorie active et la préférence de rappel.

Chaque tâche personnelle possède aussi des actions directes. Toucher la tâche ou sa case permet de la marquer comme terminée ou de la restaurer si elle est affichée dans une vue incluant les tâches terminées. L’icône corbeille permet de la supprimer. En mode backend réel, ces actions utilisent les endpoints `PUT` et `DELETE` de l’agenda personnel.

Le filtre `Afficher terminées` recharge l’agenda avec `includeDone=true`. Il sert notamment à retrouver une tâche terminée trop vite et à la restaurer.

## Profil et réglages

L’écran Profil contient les réglages utilisateur de base :

- activation/désactivation des notifications de cours ;
- activation/désactivation des notifications de devoirs ;
- choix `J’ai une entreprise`, qui adapte l’onglet `Carrière` ;
- choix du thème : système, clair ou sombre.

Ces préférences sont sauvegardées localement avec `flutter_secure_storage`. Elles restent donc disponibles après fermeture et réouverture de l’app sur le même appareil.

## Cours collaboratifs et classe

L’écran Planning permet maintenant d’ajouter, modifier et supprimer un cours. En mode backend réel, l’app s’appuie sur :

- `GET /api/v1/courses`
- `POST /api/v1/courses`
- `PUT /api/v1/courses/{id}`
- `DELETE /api/v1/courses/{id}`
- `GET/POST /api/v1/class-resources/subjects`
- `GET/POST /api/v1/class-resources/teachers`

Le profil affiche aussi une première section de gestion de classe pour le délégué : code de classe et demandes d’élèves à approuver. En mode backend réel, elle utilise `GET /api/v1/classes/current` et `GET/POST /api/v1/delegate/membership-requests`.

## Espace Entreprise

Quand le réglage `J’ai une entreprise` est activé, l’onglet `Carrière` affiche les outils utiles à l’entreprise. Cet écran sert de base pour organiser la vie professionnelle :

- ressources importantes, avec ajout et suppression locale ;
- tâches carrière, reliées à l’Agenda et ouvertes directement dans la catégorie professionnelle ;
- contacts utiles, avec ajout et suppression locale ;

Les ressources et contacts sont déjà fonctionnels et sauvegardés avec `flutter_secure_storage`.

## Prochaine étape

Brancher les prochains modules réels : documents entreprise, contacts, ou formulaires de création/modification des cours et devoirs.
