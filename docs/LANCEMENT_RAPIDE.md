# StudyFlow — lancement rapide

Cette mini doc sert à lancer le projet en local pour développer ou faire une démonstration.

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
Password1234
```

## 2. Lancer l’app sur émulateur Android

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

## 3. Lancer l’app sur iPhone physique

Le backend tourne sur le Mac. L’iPhone doit donc appeler l’adresse IP locale du Mac, pas `localhost`.

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

## 4. Si l’app dit “impossible de joindre le serveur”

Vérifie dans cet ordre :

1. Le backend est bien lancé avec `--urls http://0.0.0.0:5028`.
2. L’iPhone et le Mac sont sur le même Wi-Fi.
3. L’IP utilisée dans `STUDYFLOW_API_URL` est bien l’IP actuelle du Mac.
4. L’URL commence par `http://`, pas `https://`.
5. L’app a été relancée après modification de l’URL.

## 5. Rappel important

`localhost` signifie “cet appareil”.

Donc :

- sur le Mac, `localhost` = le Mac ;
- sur l’iPhone, `localhost` = l’iPhone ;
- sur Android emulator, il faut utiliser `10.0.2.2` ;
- sur iPhone physique, il faut utiliser l’IP locale du Mac.
