# Swikko — lancement rapide

Cette mini doc sert à lancer le projet en local pour développer ou faire une démonstration.

## 0. Vérifier le fichier `.env`

Le backend charge automatiquement le fichier `.env` à la racine du projet. Ce fichier est ignoré par Git et doit contenir au minimum les clés locales :

```env
Jwt__SigningKey=une-cle-locale-longue
Security__LookupKey=une-autre-cle-locale-longue
Security__DataProtectionKeysPath=.data-protection-keys
```

Sans ces deux premières clés, le backend refuse de démarrer, car il ne peut pas signer les JWT ni calculer les HMAC de sécurité.

## 1. Lancer le backend

Depuis la racine du projet :

```bash
cd /Users/gab/Documents/studentflow

dotnet run --project src/backend/StudyFlow.Api \
  --urls http://0.0.0.0:5028
```

Le backend écoute alors sur le port `5028`.

En mode développement, la base est seedée automatiquement. Les comptes de test sont affichés dans le terminal au lancement du backend.

Compte principal :

```txt
gabriel@studyflow.dev
Password1234!
```

## 2. Lancer l’app Web / frontend local

Si le frontend tourne sur Vite, l’adresse est souvent :

```txt
http://localhost:5173
```

Le backend autorise maintenant les origines de développement courantes :

- `http://localhost:5173`
- `http://127.0.0.1:5173`
- `http://localhost:4173`
- `http://127.0.0.1:4173`
- `http://localhost:4174`
- `http://127.0.0.1:4174`
- `http://localhost:3000`
- `http://localhost:8080`

Important : en CORS, il ne faut pas mettre de slash final dans l’origine. Il
faut écrire `http://localhost:5173`, pas `http://localhost:5173/`.

Pour vérifier que le backend répond :

```bash
curl http://localhost:5028/api/status
```

Si le navigateur affiche “impossible de joindre le serveur”, vérifier que le
frontend appelle bien `http://localhost:5028` et que le backend tourne encore.

## 3. Lancer l’app sur émulateur Android

Dans un deuxième terminal :

```bash
cd /Users/gab/Documents/studentflow/src/app
flutter run
```

Sur Android emulator, l’app utilise automatiquement :

```txt
http://10.0.2.2:5028
```

C’est l’adresse spéciale qui permet à l’émulateur Android de joindre le backend lancé sur le Mac.

## 3 bis. Script universel Flutter

Le script [`scripts/run_app.sh`](../scripts/run_app.sh) permet de lancer
Swikko sur presque n’importe quelle cible Flutter : Android emulator, iPhone,
Chrome ou macOS.

Lister les appareils disponibles :

```bash
cd /Users/gab/Documents/studentflow
./scripts/run_app.sh --list
```

Android emulator :

```bash
./scripts/run_app.sh --device=emulator-5554
```

Chrome :

```bash
./scripts/run_app.sh --device=chrome
```

macOS :

```bash
./scripts/run_app.sh --device=macos
```

iPhone avec le backend NAS public :

```bash
./scripts/run_app.sh --device=TON_ID_IPHONE --nas --release --sync --clean
```

iPhone avec une URL précise :

```bash
./scripts/run_app.sh --device=TON_ID_IPHONE --release --sync --clean \
  --api-url=https://studyflow-dev.duckdns.org
```

Le flag `--sync` copie le projet dans `/Users/gab/Developer/studentflow` avant
le lancement. C’est utile pour iOS, car cela évite les erreurs de codesign
causées par les attributs macOS dans le dossier `Documents`.

## 4. Lancer l’app sur iPhone physique

Le backend tourne sur le Mac. L’iPhone doit donc appeler l’adresse IP locale du Mac, pas `localhost`.

### Bloc complet recommandé

Le plus simple est d’utiliser le script automatisé. Il copie le projet dans
`/Users/gab/Developer/studentflow`, nettoie les attributs macOS qui cassent
parfois le codesign iOS, trouve l’IP du Mac et lance Flutter avec la bonne URL
backend.

Terminal 1 — backend :

```bash
cd /Users/gab/Documents/studentflow

open -a Docker
docker compose up -d postgres

dotnet run --project src/backend/StudyFlow.Api \
  --urls http://0.0.0.0:5028
```

Terminal 2 — app iPhone/iPad/Android (le script demande sur quel appareil
connecté installer ; `--device=NOM_OU_ID` pour le choisir directement) :

```bash
cd /Users/gab/Documents/studentflow
./scripts/install_app.sh
```

Pour installer une app autonome pendant environ 7 jours avec le compte Apple
gratuit, utilise le mode release :

```bash
cd /Users/gab/Documents/studentflow
./scripts/install_app.sh --clean --release
```

Quand Flutter affiche les commandes interactives, utilise `d` pour détacher la
session, puis débranche l'iPhone. L'app reste sur l'écran d'accueil, mais l'API
locale du Mac doit rester allumée si l'app pointe encore vers le Mac.

Pour utiliser un backend sur NAS :

```bash
cd /Users/gab/Documents/studentflow
./scripts/install_app.sh --clean --release --api-url=http://IP_DU_NAS:5028
```

Le guide complet est dans [`docs/NAS_DEPLOIEMENT.md`](./NAS_DEPLOIEMENT.md).

Si Xcode/iOS recommence à parler de `resource fork`, relance en mode réparation :

```bash
cd /Users/gab/Documents/studentflow
./scripts/install_app.sh --clean
```

### Bloc manuel si besoin

Terminal 1 — backend :

```bash
cd /Users/gab/Documents/studentflow

open -a Docker
docker compose up -d postgres

dotnet run --project src/backend/StudyFlow.Api \
  --urls http://0.0.0.0:5028
```

Terminal 2 — app iPhone :

```bash
cd /Users/gab/Documents/studentflow/src/app

MAC_IP="$(ipconfig getifaddr en0)"

flutter devices

flutter run -d 00008120-0009098822A2201E \
  --dart-define=STUDYFLOW_API_URL=http://$MAC_IP:5028
```

Si `ipconfig getifaddr en0` ne renvoie rien, utilise cette variante :

```bash
MAC_IP="$(ifconfig en0 | awk '/inet / {print $2; exit}')"

flutter run -d 00008120-0009098822A2201E \
  --dart-define=STUDYFLOW_API_URL=http://$MAC_IP:5028
```

### Étape 1 — trouver l’IP du Mac

Sur le Mac :

```bash
ipconfig getifaddr en0
```

Exemple de résultat :

```txt
192.168.1.41
```

### Étape 2 — vérifier que l’iPhone est sur le même Wi-Fi

Le Mac et l’iPhone doivent être connectés au même réseau Wi-Fi.

### Étape 3 — lancer Flutter avec l’URL du backend

Dans le dossier Flutter :

```bash
cd /Users/gab/Documents/studentflow/src/app

flutter devices
```

Repère l’identifiant de ton iPhone, puis lance :

```bash
flutter run -d TON_ID_IPHONE \
  --dart-define=STUDYFLOW_API_URL=http://IP_DU_MAC:5028
```

Exemple :

```bash
flutter run -d 00008120-0009098822A2201E \
  --dart-define=STUDYFLOW_API_URL=http://192.168.1.41:5028
```

## 5. Si l’app dit “impossible de joindre le serveur”

Vérifie dans cet ordre :

1. Le backend est bien lancé avec `--urls http://0.0.0.0:5028`.
2. L’iPhone et le Mac sont sur le même Wi-Fi.
3. L’IP utilisée dans `STUDYFLOW_API_URL` est bien l’IP actuelle du Mac.
4. L’URL commence par `http://`, pas `https://`.
5. L’app a été relancée après modification de l’URL.

## 6. Rappel important

`localhost` signifie “cet appareil”.

Donc :

- sur le Mac, `localhost` = le Mac ;
- sur l’iPhone, `localhost` = l’iPhone ;
- sur Android emulator, il faut utiliser `10.0.2.2` ;
- sur iPhone physique, il faut utiliser l’IP locale du Mac.

Pour que l'iPhone continue à utiliser les données quand le Mac est éteint, il
faut remplacer l'IP du Mac par une API disponible ailleurs, par exemple sur un
NAS. Voir [`NAS_DEPLOIEMENT.md`](./NAS_DEPLOIEMENT.md).

Le déploiement NAS réellement effectué, avec les erreurs rencontrées et leurs
solutions, est documenté dans
[`RETEX_DEPLOIEMENT_NAS.md`](./RETEX_DEPLOIEMENT_NAS.md).
