# Swikko — guide NAS

Ce guide explique comment faire tourner l'API Swikko sur un NAS avec Docker,
pour que l'app iPhone puisse fonctionner même quand le Mac est éteint.

Un retour d’expérience complet du déploiement réellement effectué est disponible
dans [`RETEX_DEPLOIEMENT_NAS.md`](./RETEX_DEPLOIEMENT_NAS.md). Il détaille les
problèmes rencontrés : dossier NAS déjà existant, permissions Docker, ancien
conteneur PostgreSQL, DuckDNS, reverse proxy, certificat HTTPS et tests avec
`curl`.

L'architecture cible est :

```text
iPhone Swikko
  -> https://studyflow.ton-domaine.example
  -> reverse proxy du NAS, optionnel mais recommandé
  -> conteneur API Swikko
  -> conteneur PostgreSQL
```

En réseau local uniquement, l'app peut aussi appeler :

```text
http://IP_DU_NAS:5028
```

## 1. Ce qu'il faut sur le NAS

Le NAS doit pouvoir lancer des conteneurs Docker. Sur Synology, cela passe
souvent par `Container Manager`. Sur QNAP, cela passe par `Container Station`.

Prévois :

- Docker ou Container Manager ;
- un accès SSH au NAS, ou une interface capable de lancer un projet Compose ;
- assez d'espace disque pour PostgreSQL ;
- idéalement un nom de domaine ou sous-domaine si tu veux HTTPS.

## 2. Fichiers ajoutés pour le NAS

Le projet contient maintenant :

- `Dockerfile.api` : construit l'image Docker de l'API ASP.NET Core ;
- `compose.nas.yaml` : lance PostgreSQL et l'API ;
- `.env.nas.example` : modèle de variables et secrets ;
- `scripts/nas_generate_env.sh` : génère un `.env.nas` local avec des secrets
  aléatoires ;
- `scripts/nas_deploy.sh` : construit et lance la stack NAS ;
- `Database__ApplyMigrationsOnStartup=true` dans le compose NAS, pour appliquer
  les migrations Entity Framework au démarrage du conteneur API.

Les vraies valeurs doivent aller dans un fichier local `.env.nas`, ignoré par
Git.

## 3. Préparer le dossier sur le NAS

Copie le projet sur le NAS, par exemple dans :

```text
/volume1/docker/studyflow
```

Tu peux le faire par Git, rsync, SFTP ou l'interface fichier du NAS. Le dossier
doit contenir au minimum :

```text
Dockerfile.api
compose.nas.yaml
global.json
StudyFlow.sln
src/backend/
```

## 4. Créer `.env.nas`

Depuis le dossier du projet sur le NAS, la méthode la plus simple est :

```bash
./scripts/nas_generate_env.sh
```

Le script crée un fichier `.env.nas` ignoré par Git, avec :

- un mot de passe PostgreSQL aléatoire ;
- une clé JWT aléatoire ;
- une clé HMAC aléatoire.

Ensuite, ouvre `.env.nas` et adapte au minimum `STUDYFLOW_CORS_ORIGIN` si tu
passes par un domaine HTTPS.

Méthode manuelle si tu préfères :

```bash
cp .env.nas.example .env.nas
```

Remplace les valeurs sensibles.

Exemple :

```env
STUDYFLOW_POSTGRES_DB=studyflow
STUDYFLOW_POSTGRES_USER=studyflow
STUDYFLOW_POSTGRES_PASSWORD=un-mot-de-passe-long

STUDYFLOW_JWT_SIGNING_KEY=une-cle-jwt-tres-longue-au-moins-32-caracteres
STUDYFLOW_SECURITY_LOOKUP_KEY=une-cle-hmac-tres-longue-au-moins-32-caracteres

STUDYFLOW_API_PORT=5028
STUDYFLOW_CORS_ORIGIN=https://studyflow.ton-domaine.example
```

Les deux clés doivent faire au moins 32 caractères :

- `STUDYFLOW_JWT_SIGNING_KEY` signe les tokens de connexion ;
- `STUDYFLOW_SECURITY_LOOKUP_KEY` sert aux HMAC et recherches sécurisées.

Ne réutilise pas les clés de démonstration de la doc en vrai.

## 5. Lancer l'API sur le NAS

En SSH, depuis le dossier du projet :

```bash
./scripts/nas_deploy.sh
```

Ce script exécute le `docker compose` NAS avec le bon fichier `.env.nas`.

Commande équivalente manuelle :

```bash
docker compose --env-file .env.nas -f compose.nas.yaml up -d --build
```

Vérifie l'état :

```bash
docker compose --env-file .env.nas -f compose.nas.yaml ps
docker compose --env-file .env.nas -f compose.nas.yaml logs -f api
```

L'API doit répondre sur le NAS :

```bash
curl http://localhost:5028/api/status
```

Depuis ton Mac, remplace par l'IP du NAS :

```bash
curl http://IP_DU_NAS:5028/api/status
```

Si tu vois un JSON avec `StudyFlow.Api` et `ok`, l'API tourne.

## 6. Installer l'app iPhone avec l'URL du NAS

Sur le Mac, branche l'iPhone puis installe une version release :

```bash
cd /Users/gab/Documents/studentflow
./scripts/install_app.sh --clean --release --api-url=http://IP_DU_NAS:5028
```

Exemple :

```bash
./scripts/install_app.sh --clean --release --api-url=http://192.168.1.50:5028
```

Quand Flutter a fini, détache la session avec :

```text
d
```

Tu peux ensuite débrancher l'iPhone. L'app reste installée pendant la durée du
provisioning gratuit Apple, environ 7 jours.

Si iOS demande l'autorisation d'accès au réseau local, accepte-la.

## 7. Version recommandée avec HTTPS

Pour une utilisation plus propre, expose l'API via le reverse proxy du NAS :

```text
https://studyflow.ton-domaine.example -> http://127.0.0.1:5028
```

Sur Synology, le chemin habituel est :

1. `Panneau de configuration > Portail de connexion > Avancé > Proxy inversé`.
2. Créer une règle :
   - source : `https`, hôte `studyflow.ton-domaine.example`, port `443` ;
   - destination : `http`, hôte `127.0.0.1`, port `5028`.
3. Ajouter un certificat Let's Encrypt pour ce sous-domaine.
4. Vérifier depuis le Mac :

```bash
curl https://studyflow.ton-domaine.example/api/status
```

Puis installe l'app avec :

```bash
cd /Users/gab/Documents/studentflow
./scripts/install_app.sh --clean --release --api-url=https://studyflow.ton-domaine.example
```

HTTPS est préférable si tu veux utiliser l'app hors Wi-Fi local ou éviter les
limitations iOS liées au HTTP.

## 8. Sauvegarder les données

Les données importantes sont dans deux volumes Docker :

- `studyflow-nas-postgres-data` : base PostgreSQL ;
- `studyflow-nas-api-keys` : clés ASP.NET Data Protection.

Sauvegarde PostgreSQL régulièrement :

```bash
docker exec studyflow-nas-postgres pg_dump -U studyflow studyflow > studyflow-backup.sql
```

Pour restaurer, arrête l'API puis restaure dans PostgreSQL avant de la relancer.
Garde aussi une copie de `.env.nas`, car sans les mêmes clés certaines données
chiffrées ou tokens existants ne seront plus exploitables.

## 9. Mettre à jour l'API

Quand le code change :

```bash
cd /volume1/docker/studyflow
docker compose --env-file .env.nas -f compose.nas.yaml up -d --build
```

Le conteneur API redémarre. Les migrations sont appliquées automatiquement grâce
à `Database__ApplyMigrationsOnStartup=true`.

## 10. Dépannage

### Le port est déjà utilisé

Erreur typique :

```text
address already in use
```

Change `STUDYFLOW_API_PORT` dans `.env.nas`, ou arrête le service qui utilise
déjà le port.

### L'iPhone ne joint pas l'API

Vérifie :

1. L'iPhone et le NAS sont sur le même Wi-Fi.
2. L'URL passée à `--api-url` est bien celle du NAS.
3. `curl http://IP_DU_NAS:5028/api/status` répond depuis le Mac.
4. Le pare-feu du NAS autorise le port `5028`.
5. Si tu utilises HTTPS, le certificat est valide.

### L'API démarre puis s'arrête

Regarde les logs :

```bash
docker compose --env-file .env.nas -f compose.nas.yaml logs api
```

Les causes fréquentes sont :

- clé JWT trop courte ;
- clé `Security__LookupKey` trop courte ;
- mot de passe PostgreSQL différent entre `.env.nas` et le volume existant ;
- base PostgreSQL pas encore prête.

### Tu veux repartir de zéro

Attention, cela supprime les données :

```bash
docker compose --env-file .env.nas -f compose.nas.yaml down
docker volume rm studyflow_studyflow-nas-postgres-data
docker volume rm studyflow_studyflow-nas-api-keys
docker compose --env-file .env.nas -f compose.nas.yaml up -d --build
```

Le nom exact des volumes peut varier selon le nom du dossier Compose. Vérifie
avec :

```bash
docker volume ls
```

## Notifications push (Firebase)

L'API envoie les rappels de cours, de devoirs et les annonces via Firebase
Cloud Messaging.

1. Dans la console Firebase : Paramètres du projet > Comptes de service >
   Générer une nouvelle clé privée.
2. Copier le fichier sur le NAS, **hors Git**, sous ce nom exact :

   ```text
   /volume1/docker/studyflow/secrets/firebase-adminsdk.json
   ```

   puis le protéger : `chmod 600 secrets/firebase-adminsdk.json`.
3. Vérifier dans `.env.nas` :

   ```env
   STUDYFLOW_FIREBASE_CREDENTIALS_PATH=/run/secrets/studyflow/firebase-adminsdk.json
   STUDYFLOW_NOTIFICATIONS_ENABLED=true
   ```

4. Redéployer avec `./scripts/nas_deploy.sh`. Si le chemin est faux, l'API
   refuse de démarrer et le dit dans `docker compose ... logs api`.

Côté app Android, `src/app/firebase_config.json` (ignoré par Git) est pris en
compte automatiquement par `scripts/run_app.sh`.
