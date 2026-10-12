# Environnements de l'app

Un fichier par environnement, passé à Flutter avec `--dart-define-from-file` :

| Fichier     | Environnement | Serveur                                         |
|-------------|---------------|-------------------------------------------------|
| `dev.json`  | Développement | API du Mac (`make dev`), bandeau « DEV » visible |
| `prod.json` | Production    | API du NAS                                      |
| `demo.json` | Démonstration | Aucun : données fictives intégrées à l'app      |

Les scripts s'en chargent (`make app-dev`, `make app-prod`, `make app-demo`). En
dev sur un téléphone, ils ajoutent `--dart-define=STUDYFLOW_API_URL=http://IP_DU_MAC:5028`,
qui l'emporte sur le fichier.

Pas de secret ici : ces fichiers sont dans Git. Les identifiants Firebase restent dans
`../firebase_config.json` (ignoré par Git).
