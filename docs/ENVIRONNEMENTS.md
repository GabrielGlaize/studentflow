# Environnements : développement et production

Swikko tourne dans deux environnements qui ne partagent ni base ni clés :

|                 | Développement (Mac)                          | Production (NAS)                               |
|-----------------|----------------------------------------------|------------------------------------------------|
| Démarrage       | `make dev`                                   | `make deploy-api` (voir la skill `swikko-deploy`) |
| Fichier Compose | `compose.yaml` (projet `swikko-dev`)         | `compose.nas.yaml` (projet `studyflow`)        |
| API             | http://localhost:5028 · Swagger `/swagger`   | https://studyflow-dev.duckdns.org              |
| Base            | PostgreSQL Docker, port 5433, **seedée**     | PostgreSQL Docker du NAS, vraies données       |
| E-mails         | Mailpit : http://localhost:8025              | Gmail (SMTP), `scripts/nas_configure_email.sh` |
| Clés            | `.env` (aléatoires, créées par `make setup`) | `.env.nas` sur le NAS, root uniquement         |
| App Flutter     | `make app-dev` · `config/dev.json` · bandeau « DEV » | `make app-prod` · `config/prod.json`   |

Un troisième mode, **démo** (`make app-demo`, `config/demo.json`), fait tourner l'app
sans serveur avec des données fictives : pratique pour une présentation hors ligne.

## Première fois sur le Mac

```bash
cd /Users/gab/Documents/studentflow
make setup     # vérifie Docker, .NET, Flutter… crée .env avec des clés aléatoires
make dev       # base + API + Mailpit, la base est seedée au premier démarrage
make app-dev   # installe l'app sur l'appareil branché, reliée au Mac
```

`make` seul liste toutes les commandes.

## Deux façons de lancer l'API en dev

- **`make dev`** : tout dans Docker. Le plus simple, rien d'autre à lancer.
- **`make dev-api`** : la base et Mailpit dans Docker, l'API directement sur le Mac
  avec `dotnet watch` (rechargement à chaud, débogueur). À utiliser quand on modifie
  le backend.

Les deux modes partagent la même base et le même dossier de clés de chiffrement
(`src/backend/StudyFlow.Api/.data-protection-keys`) : on passe de l'un à l'autre sans
rien perdre.

## Les données de développement

Le seed (`src/backend/StudyFlow.Api/Seeding/`) crée une classe de BTS SIO en alternance,
datée par rapport à aujourd'hui :

- 5 semaines de cours au rythme de l'alternance : lundi et mardi à l'école, le mercredi
  une semaine sur deux, le reste en entreprise. Un cours est annulé ;
- des devoirs, dont deux évaluations et deux travaux de groupe ;
- les partiels dans deux semaines, avec une fiche de révision déjà commencée ;
- trois groupes de travail et l'entraide alternance de la classe.

### Les comptes : une situation par compte

Mot de passe commun : `Password1234!`. En dev, l'écran de connexion de l'app liste
tous ces comptes : on touche un compte pour se connecter.

| Compte | Situation à tester |
|--------|--------------------|
| `gabriel@studyflow.dev` | Délégué, en entreprise : gère la classe, organise le projet BDD, 2 messages non lus, invité par Hugo, agenda perso et notes du jour |
| `garance@studyflow.dev` | Élève du groupe de Gabriel |
| `liam@studyflow.dev` | Élève du groupe de Gabriel, disponible le week-end |
| `ines@studyflow.dev` | Cherche son alternance : pas d'entreprise, onglet Alternances |
| `yanis@studyflow.dev` | En retard : ses devoirs passés ne sont pas rendus |
| `chloe@studyflow.dev` | Premier lancement : la présentation s'ouvre après la connexion |
| `hugo@studyflow.dev` | Seul dans son groupe, attend la réponse de Gabriel |
| `sarah@studyflow.dev` | Sans groupe pour les deux travaux de groupe |
| `nina@studyflow.dev` | Demande d'adhésion en attente (Gabriel peut l'accepter) |
| `tom@studyflow.dev` | Sans classe : rejoindre ou créer une classe |

La liste vient de `Seeding/DevelopmentAccounts.cs`, servie à l'app par
`GET /api/v1/dev/accounts`. Cette route n'existe qu'en développement. Pour ajouter une
situation, ajoute un compte à cette liste et ses données dans le seed.

Le seed tourne à chaque démarrage de l'API en dev :

- **les comptes** sont toujours vérifiés : un mot de passe changé pendant les tests revient
  à `Password1234!` ;
- **le contenu** n'est créé que dans une base vide : ce que tu fais dans l'app est conservé.

Pour repartir de zéro : **`make dev-reset`**.

## Tester sur un téléphone

`make app-dev` détecte l'appareil et pointe l'app vers l'IP du Mac
(`http://192.168.1.x:5028`). Il faut que le téléphone soit sur le même Wi-Fi que le Mac.
Le simulateur iOS utilise `localhost`, l'émulateur Android `10.0.2.2`.

## Commandes utiles

| Commande          | Effet                                              |
|-------------------|----------------------------------------------------|
| `make dev-status` | état des conteneurs et de l'API                    |
| `make dev-logs`   | journaux de l'API Docker (récapitulatif du seed)    |
| `make dev-psql`   | console SQL sur la base de dev                     |
| `make dev-down`   | arrête tout, les données restent                   |
| `make app-web`    | l'app dans Chrome, reliée au Mac                   |
| `make test`       | tests backend (Docker requis) et Flutter           |

## Garde-fous

- La production ne lance jamais le seed : il n'existe qu'en environnement `Development`.
- `ResetOnStartup` refuse d'effacer une base qui n'est pas locale.
- Les fichiers `config/*.json` de l'app ne contiennent aucun secret (ils sont dans Git).
  `.env`, `.env.nas` et `firebase_config.json` restent hors de Git.
