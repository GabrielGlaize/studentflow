# StudyFlow — retour d’expérience du déploiement NAS

Cette documentation raconte le déploiement réellement effectué pour rendre
l’API StudyFlow accessible depuis un NAS, puis depuis Internet via DuckDNS,
reverse proxy et HTTPS.

Elle complète le guide technique [`NAS_DEPLOIEMENT.md`](./NAS_DEPLOIEMENT.md).
Le but ici n’est pas seulement de lister les commandes, mais aussi d’expliquer
les problèmes rencontrés et comment ils ont été résolus.

## 1. Objectif du déploiement

Au départ, l’application Flutter communiquait avec le backend lancé sur le Mac :

```text
iPhone
  -> API sur le Mac
  -> PostgreSQL local Docker
```

Ce fonctionnement est pratique pour développer, mais il a une limite évidente :
si le Mac est éteint ou si le backend local n’est pas lancé, l’application ne
peut plus accéder aux données.

L’objectif était donc de déplacer le backend sur le NAS :

```text
iPhone / ordinateur
  -> domaine HTTPS public
  -> box Internet
  -> NAS
  -> reverse proxy
  -> conteneur API StudyFlow
  -> conteneur PostgreSQL
```

En local, l’API du NAS répond sur :

```text
http://IP_DU_NAS:5028
```

En accès externe, l’API répond sur :

```text
https://SOUS_DOMAINE.duckdns.org
```

Dans notre installation de test, le NAS était accessible en local sur :

```text
192.168.1.14
```

Et le sous-domaine DuckDNS utilisé était :

```text
studyflow-dev.duckdns.org
```

## 2. Fichiers utilisés

Le déploiement repose sur les fichiers suivants :

- [`Dockerfile.api`](../Dockerfile.api) : construit l’image Docker de l’API ASP.NET Core ;
- [`compose.nas.yaml`](../compose.nas.yaml) : lance PostgreSQL et l’API ;
- [`.env.nas.example`](../.env.nas.example) : modèle de configuration NAS ;
- [`scripts/nas_generate_env.sh`](../scripts/nas_generate_env.sh) : génère un fichier `.env.nas` local avec des secrets ;
- [`scripts/nas_deploy.sh`](../scripts/nas_deploy.sh) : construit et lance les conteneurs ;
- [`scripts/run_iphone_developer.sh`](../scripts/run_iphone_developer.sh) : installe l’app iPhone avec l’URL du backend.

Le fichier important à ne pas commiter est :

```text
.env.nas
```

Il contient :

- le mot de passe PostgreSQL ;
- la clé de signature JWT ;
- la clé HMAC de sécurité ;
- l’origine CORS ;
- éventuellement des clés d’API externes.

## 3. Connexion au NAS

La connexion SSH au NAS s’est faite avec :

```bash
ssh gabriel@192.168.1.14
```

Le NAS a affiché un avertissement classique indiquant qu’il faut stocker les
données dans des dossiers partagés. Le dossier choisi pour StudyFlow est :

```text
/volume1/docker/studyflow
```

C’est cohérent avec une installation Docker sur NAS Synology.

## 4. Récupération du projet GitHub

Premier problème rencontré : le dossier existait déjà.

La commande :

```bash
git clone -b codex/nas-ready https://github.com/GabrielGlaize/studentflow.git .
```

a échoué avec :

```text
fatal: destination path '.' already exists and is not an empty directory.
```

Cela veut dire que le dossier courant n’était pas vide. Ensuite, dans
`/volume1/docker/studyflow`, Git indiquait :

```text
fatal: not a git repository
```

Le dossier contenait des fichiers, mais n’était pas encore un dépôt Git.

La solution utilisée a été :

```bash
cd /volume1/docker/studyflow

git init
git config --global --add safe.directory /volume1/docker/studyflow

git remote add origin https://github.com/GabrielGlaize/studentflow.git 2>/dev/null || git remote set-url origin https://github.com/GabrielGlaize/studentflow.git

git fetch origin
git checkout -B codex/nas-ready origin/codex/nas-ready
```

Le message `dubious ownership` a été corrigé avec :

```bash
git config --global --add safe.directory /volume1/docker/studyflow
```

Après récupération, le dossier contenait bien :

```text
CAHIER_DES_CHARGES.md
compose.nas.yaml
compose.yaml
Dockerfile.api
docs
global.json
README.md
scripts
src
StudyFlow.sln
```

## 5. Génération du fichier `.env.nas`

Les scripts ont été rendus exécutables :

```bash
chmod +x scripts/nas_generate_env.sh scripts/nas_deploy.sh
```

Puis le fichier `.env.nas` a été généré :

```bash
./scripts/nas_generate_env.sh
```

Résultat :

```text
Created /volume1/docker/studyflow/.env.nas
Keep this file private. It contains passwords and signing keys.
```

Ce fichier permet de ne pas mettre les secrets dans Git.

## 6. Premier lancement Docker

La première tentative sans `sudo` a échoué :

```bash
./scripts/nas_deploy.sh
```

Erreur :

```text
permission denied while trying to connect to the Docker daemon socket
```

Cela veut dire que l’utilisateur SSH n’avait pas le droit d’utiliser Docker
directement. Pour avancer rapidement, la solution a été d’utiliser `sudo` :

```bash
sudo ./scripts/nas_deploy.sh
```

Le build Docker a réussi :

```text
dotnet publish src/backend/StudyFlow.Api/StudyFlow.Api.csproj
naming to docker.io/library/studyflow-api:nas
```

## 7. Conflit avec un ancien conteneur PostgreSQL

Après le build, Docker a refusé de créer PostgreSQL :

```text
Conflict. The container name "/studyflow-nas-postgres" is already in use
```

Cela indiquait qu’un ancien conteneur du même nom existait déjà sur le NAS.

La solution a été de supprimer les anciens conteneurs StudyFlow :

```bash
cd /volume1/docker/studyflow

sudo docker ps -a --filter "name=studyflow"

sudo docker rm -f studyflow-nas-postgres studyflow-nas-api 2>/dev/null || true

sudo docker compose --env-file .env.nas -f compose.nas.yaml up -d
```

Ensuite, la vérification Docker indiquait bien :

```text
studyflow-nas-api        Up
studyflow-nas-postgres   Up healthy
```

## 8. Premier test local : `Empty reply from server`

Depuis le Mac, le premier test a donné :

```bash
curl http://192.168.1.14:5028/api/status
```

Résultat :

```text
curl: (52) Empty reply from server
```

Ce message ne voulait pas dire que tout était cassé. Il indiquait surtout que
le port répondait, mais que l’API n’avait pas encore renvoyé correctement de
réponse.

La vérification des logs a montré que l’API était en train d’appliquer les
migrations Entity Framework :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml logs --tail=120 api
```

Les logs montraient :

```text
Applying migration
CREATE TABLE
INSERT INTO "__EFMigrationsHistory"
```

Puis :

```text
Now listening on: http://[::]:8080
Application started.
Hosting environment: Production
```

Conclusion : l’API avait bien démarré, mais il fallait attendre la fin des
migrations au premier lancement.

## 9. Vérification du fonctionnement local

Les conteneurs ont été vérifiés avec :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml ps
```

Résultat attendu :

```text
studyflow-nas-api        0.0.0.0:5028->8080/tcp
studyflow-nas-postgres   healthy
```

Ensuite, test depuis le NAS :

```bash
curl http://localhost:5028/api/status
```

Puis depuis le Mac :

```bash
curl http://192.168.1.14:5028/api/status
```

Quand ce test répond, le backend NAS fonctionne sur le réseau local.

## 10. Création du sous-domaine DuckDNS

DuckDNS a été utilisé pour obtenir un nom de domaine gratuit.

La page DuckDNS est assez ancienne visuellement, mais le principe est simple :

1. se connecter sur [duckdns.org](https://www.duckdns.org) ;
2. choisir un nom dans le champ `sub domain` ;
3. cliquer sur `add domain`.

Il ne faut pas entrer le domaine complet dans le champ.

Exemple :

```text
studyflow-dev
```

Le domaine final devient :

```text
studyflow-dev.duckdns.org
```

## 11. Redirection des ports sur la box

Dans l’interface de la box, il fallait créer deux règles NAT vers le NAS.

Le NAS avait l’adresse locale :

```text
192.168.1.14
```

Règle HTTP :

```text
Nom : StudyFlow HTTP
Protocole : TCP
Port externe : 80
Port interne : 80
Destination : 192.168.1.14
IP externes autorisées : toutes
```

Règle HTTPS :

```text
Nom : StudyFlow HTTPS
Protocole : TCP
Port externe : 443
Port interne : 443
Destination : 192.168.1.14
IP externes autorisées : toutes
```

Il ne fallait pas choisir un profil `FTP server`, car StudyFlow n’utilise pas
FTP. Il fallait créer des règles personnalisées TCP.

## 12. Configuration du reverse proxy NAS

Dans l’interface du NAS, la règle de proxy inversé a été configurée ainsi.

Entrée :

```text
Nom du proxy inversé : StudyFlow API
Protocole : HTTPS
Nom d’hôte : studyflow-dev.duckdns.org
Port : 443
Profil de contrôle d’accès : aucun
```

Destination :

```text
Protocole : HTTP
Nom d’hôte : 127.0.0.1
Port : 5028
```

Cela donne :

```text
https://studyflow-dev.duckdns.org
  -> http://127.0.0.1:5028
```

`127.0.0.1` est correct ici parce que le reverse proxy tourne sur le NAS lui-même.

### HSTS

HSTS n’a pas été activé pendant la configuration.

Raison : HSTS force le navigateur/client à utiliser HTTPS. C’est utile en
production stable, mais dangereux pendant les tests parce qu’un mauvais
certificat peut bloquer les essais.

Décision :

```text
HSTS : désactivé pendant la mise en place
```

Il pourra être activé plus tard quand tout sera stable.

### En-têtes personnalisés

Les en-têtes personnalisés sont facultatifs. Si l’interface en demande un, on
peut utiliser :

```text
Nom de l’en-tête : X-Forwarded-Proto
Valeur : https
```

Éventuellement :

```text
Nom de l’en-tête : X-Forwarded-Host
Valeur : studyflow-dev.duckdns.org
```

Mais pour StudyFlow, la règle reverse proxy fonctionne déjà sans configuration
complexe d’en-têtes.

## 13. Modification de `.env.nas` sans nano

Le NAS ne possédait pas `nano`.

Deux solutions étaient possibles.

Avec `vi` :

```bash
cd /volume1/docker/studyflow
vi .env.nas
```

Dans `vi` :

1. appuyer sur `i` pour modifier ;
2. changer `STUDYFLOW_CORS_ORIGIN` ;
3. appuyer sur `Échap` ;
4. taper `:wq` ;
5. valider avec Entrée.

Solution plus directe avec `sed` :

```bash
cd /volume1/docker/studyflow

sudo sed -i 's|^STUDYFLOW_CORS_ORIGIN=.*|STUDYFLOW_CORS_ORIGIN=https://studyflow-dev.duckdns.org|' .env.nas
```

Puis relancer :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml up -d --build
```

## 14. Problème de certificat SSL

Le premier test HTTPS depuis le Mac a donné :

```bash
curl https://studyflow-dev.duckdns.org/api/status
```

Erreur :

```text
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

Cette erreur était une bonne nouvelle partielle :

- le domaine répondait ;
- le reverse proxy répondait ;
- mais le certificat HTTPS n’était pas encore valide ou pas bien assigné.

Pour confirmer, le test possible était :

```bash
curl -k https://studyflow-dev.duckdns.org/api/status
```

`-k` ignore la vérification du certificat. Il ne faut pas l’utiliser dans l’app,
mais c’est utile pour diagnostiquer.

La vraie correction a été :

1. créer un certificat Let’s Encrypt pour `studyflow-dev.duckdns.org` ;
2. vérifier que les ports `80` et `443` pointaient bien vers le NAS ;
3. assigner ce certificat au reverse proxy StudyFlow dans les paramètres du NAS.

Après cela :

```bash
curl https://studyflow-dev.duckdns.org/api/status
```

a fonctionné sans `-k`.

## 15. Installation de l’app iPhone avec l’API NAS publique

Une fois HTTPS fonctionnel, l’app iPhone peut être installée en pointant vers le
domaine DuckDNS :

```bash
cd /Users/gab/Documents/studentflow
./scripts/run_iphone_developer.sh --clean --release --api-url=https://studyflow-dev.duckdns.org
```

Le mode `--release` permet d’installer une app plus autonome qu’un simple
`flutter run` debug.

Avec un compte Apple gratuit, l’application reste installée environ 7 jours.
Elle peut ensuite être réinstallée avec le même script.

## 16. Commandes de maintenance

Mettre à jour le code sur le NAS :

```bash
cd /volume1/docker/studyflow
git fetch origin
git checkout codex/nas-ready
git pull origin codex/nas-ready
```

Relancer les conteneurs :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml up -d --build
```

Voir l’état :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml ps
```

Voir les logs API :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml logs -f api
```

Voir les logs PostgreSQL :

```bash
sudo docker compose --env-file .env.nas -f compose.nas.yaml logs -f postgres
```

Tester l’API localement depuis le NAS :

```bash
curl http://localhost:5028/api/status
```

Tester l’API depuis le Mac en HTTPS :

```bash
curl https://studyflow-dev.duckdns.org/api/status
```

Sauvegarder PostgreSQL :

```bash
sudo docker exec studyflow-nas-postgres pg_dump -U studyflow studyflow > studyflow-backup.sql
```

## 17. Points importants pour la présentation

Ce déploiement montre plusieurs compétences intéressantes :

- conteneurisation d’une API ASP.NET Core ;
- lancement d’une base PostgreSQL persistante avec Docker ;
- application automatique des migrations EF Core ;
- séparation des secrets dans un fichier `.env.nas` non versionné ;
- exposition locale via port Docker `5028 -> 8080` ;
- exposition publique via DuckDNS ;
- configuration NAT sur une box Internet ;
- reverse proxy HTTPS sur NAS ;
- certificat Let’s Encrypt ;
- diagnostic réseau avec `curl`, logs Docker et tests internes ;
- installation d’une app Flutter iPhone pointant vers une API distante.

Il est aussi important d’expliquer que le NAS n’est pas seulement un “serveur de
fichiers” ici : il joue le rôle d’un vrai serveur applicatif.

## 18. Problèmes rencontrés et résolution rapide

| Problème | Cause | Solution |
| --- | --- | --- |
| `destination path already exists` | Le dossier existait déjà | Initialiser/réparer le repo dans le dossier existant |
| `not a git repository` | Le dossier n’était pas un dépôt Git | `git init`, ajout du remote, fetch |
| `dubious ownership` | Git n’aimait pas le propriétaire du dossier NAS | `git config --global --add safe.directory ...` |
| `permission denied docker.sock` | L’utilisateur SSH n’avait pas accès à Docker | Utiliser `sudo` |
| `container name already in use` | Ancien conteneur présent | `docker rm -f studyflow-nas-postgres studyflow-nas-api` |
| `Empty reply from server` | API en démarrage/migrations | Attendre et vérifier les logs |
| DuckDNS confus | Interface ancienne | Entrer seulement le sous-domaine, sans `.duckdns.org` |
| Mauvais service box | Profil FTP proposé | Créer deux règles TCP personnalisées 80/443 |
| Pas de `nano` | Éditeur absent du NAS | Utiliser `vi` ou `sed` |
| `SSL certificate problem` | Certificat absent/mal assigné | Créer/assigner Let’s Encrypt |

## 19. Résultat final

À la fin, StudyFlow dispose d’un backend NAS accessible en HTTPS :

```text
https://studyflow-dev.duckdns.org/api/status
```

L’application mobile peut donc utiliser une API stable, indépendante du Mac de
développement.

Cela rapproche fortement le projet d’un fonctionnement réel :

- plusieurs téléphones peuvent utiliser le même backend ;
- les données sont centralisées dans PostgreSQL ;
- l’API reste disponible tant que le NAS est allumé ;
- l’app peut être présentée dans de meilleures conditions.
