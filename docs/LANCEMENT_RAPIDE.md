# Swikko — lancement rapide

Pour développer ou faire une démonstration sur le Mac. Le détail des environnements
(développement / production) est dans [`ENVIRONNEMENTS.md`](./ENVIRONNEMENTS.md).

## 1. Une seule fois

Docker Desktop, le SDK .NET 8 et Flutter doivent être installés.

```bash
cd /Users/gab/Documents/studentflow
make setup
```

`make setup` vérifie les outils, crée `.env` avec des clés locales aléatoires (jamais dans
Git) et récupère les dépendances.

## 2. Lancer le backend

```bash
make dev
```

Docker démarre PostgreSQL, l’API et Mailpit. Au premier démarrage, la base est remplie
avec une classe complète. Le terminal affiche ensuite :

- l’API : http://localhost:5028 (Swagger : http://localhost:5028/swagger) ;
- l’adresse à utiliser depuis un téléphone : `http://IP_DU_MAC:5028` ;
- la boîte mail locale : http://localhost:8025 (codes d’inscription, réinitialisation…) ;
- les comptes de test, chacun avec sa situation (délégué, en retard, sans classe…),
  mot de passe `Password1234!`.

Tu modifies le backend ? Lance plutôt `make dev-api` : l’API tourne sur le Mac avec
rechargement à chaud, sur la même base.

## 3. Lancer l’app

Sur un iPhone, un iPad ou un téléphone Android branché au Mac (même Wi-Fi) :

```bash
make app-dev
```

Le script demande sur quel appareil installer, puis relie l’app à l’API du Mac. Un
bandeau « DEV » rappelle qu’on n’est pas sur les vraies données, et l’écran de
connexion liste les comptes de test : on en touche un pour se connecter.

Autres cibles :

```bash
make app-web                                   # Chrome
./scripts/run_app.sh --device=macos --env=dev  # app macOS
./scripts/run_app.sh --list                    # tous les appareils
```

## 4. Au quotidien

| Commande          | Effet                                       |
|-------------------|---------------------------------------------|
| `make dev-status` | l’API tourne-t-elle ?                       |
| `make dev-logs`   | journaux de l’API                           |
| `make dev-reset`  | base remise à zéro, puis reseedée           |
| `make dev-down`   | tout arrêter (les données restent)          |
| `make test`       | tous les tests                              |

## 5. Si l’app dit « impossible de joindre le serveur »

1. `make dev-status` : l’API est-elle en ligne ?
2. Le téléphone et le Mac sont-ils sur le même Wi-Fi ?
3. L’IP du Mac a-t-elle changé ? Relance `make app-dev` : le script la relit à chaque fois.
4. En Wi-Fi d’école ou public, les appareils ne se voient souvent pas entre eux :
   installe plutôt l’app de production (`make app-prod`) ou de démo (`make app-demo`).

`localhost` désigne toujours l’appareil lui-même : sur un téléphone, il faut l’IP du Mac.
Les scripts s’en chargent.

## 6. Production

L’API de production tourne sur le NAS. Le déploiement suit la skill `swikko-deploy`
(écran « Quoi de neuf », tests, puis `make deploy-api`). Le guide du NAS est dans
[`NAS_DEPLOIEMENT.md`](./NAS_DEPLOIEMENT.md).
