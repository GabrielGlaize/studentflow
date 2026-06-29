# Parcours utilisateurs du MVP

Ce document traduit le cahier des charges en parcours vérifiables. Il sert de référence pour les maquettes, l’API et les tests fonctionnels.

## 1. Principes retenus

- Le module d’alternances est public sur le Web.
- Les données scolaires sont toujours privées.
- Un délégué est un élève disposant de droits limités sur la structure commune et les annonces.
- Les cours, devoirs et projets sont alimentés collectivement par les élèves.
- Toute correction d’un cours par un membre approuvé est immédiate et ne nécessite jamais l’accord d’un délégué.
- Les droits sont contrôlés par l’API, même si l’interface masque les actions interdites.
- Un utilisateur connecté ne peut consulter que les données scolaires de sa classe.
- Une demande d’adhésion en attente ne donne accès à aucune donnée de la classe.
- Les noms de professeurs, salles et horaires précis sont déchiffrés seulement après le contrôle d’accès.

## 2. Visiteur non connecté

### Parcours V1 — Rechercher une alternance

1. Le visiteur ouvre la page publique des alternances depuis un smartphone ou un ordinateur.
2. Il saisit des mots-clés et, facultativement, une localisation et des filtres.
3. Le système vérifie les critères puis interroge la source externe via l’API StudyFlow.
4. Le visiteur consulte une liste paginée de résultats.
5. Il ouvre le détail d’une offre.
6. Il peut être redirigé vers le site d’origine pour candidater.

Résultat attendu : aucune installation et aucun compte ne sont nécessaires.

### Parcours V2 — Utiliser une fonction personnelle

1. Le visiteur tente d’enregistrer une offre, une recherche ou une alerte.
2. StudyFlow lui propose de se connecter.
3. Après connexion, l’action initiale peut être reprise.

Résultat attendu : la consultation reste publique, mais les données synchronisées sont rattachées à un compte.

### Parcours V3 — Créer un compte sans classe

1. Le futur élève utilise la recherche publique.
2. Il crée un compte afin de conserver une offre ou une recherche.
3. Aucun code de classe ne lui est demandé.
4. Il retrouve ses favoris et alertes sur ses différents appareils.
5. Il pourra rejoindre une classe plus tard depuis son profil.

Il peut immédiatement créer des événements personnels et des tâches `Alternance` pour organiser entretiens, relances, candidatures et échéances.

### Parcours V4 — Créer sa classe

1. Le visiteur choisit `Créer ma classe`.
2. Il renseigne son compte et les informations minimales de la classe.
3. L’API crée le compte, la classe et le rattachement approuvé dans une transaction unique.
4. L’utilisateur est connecté et reçoit les rôles `Eleve` et `Delegue`.
5. Le premier code d’accès est affiché pour être communiqué aux autres élèves.

Résultat attendu : aucune classe anonyme ou sans délégué n’est créée.

## 3. Élève connecté

### Parcours E1 — Se connecter

1. L’élève saisit son adresse e-mail et son mot de passe.
2. L’API vérifie ses identifiants.
3. L’application récupère son identité, son rôle et sa classe.
4. L’élève arrive sur son tableau de bord.

En cas d’échec, aucun détail ne permet de déterminer si l’adresse e-mail existe.

### Parcours E2 — Rejoindre une classe

1. L’élève saisit le code transmis par un délégué.
2. L’API vérifie le code et crée une demande d’adhésion en attente.
3. Le futur élève voit l’état `En attente d’approbation`, sans aucune donnée scolaire.
4. Après approbation par un délégué, l’API rattache l’élève, lui attribue le rôle `Eleve` et rend les données accessibles.

Un code expiré ou renouvelé ne permet plus de rejoindre la classe.

### Parcours E3 — Consulter le tableau de bord

1. L’élève ouvre StudyFlow.
2. Il voit son prochain cours, sa salle et son horaire.
3. Il consulte les prochains devoirs ou projets.
4. Il retrouve ses tâches personnelles à faire.
5. Il voit les annonces épinglées de la classe.

### Parcours E4 — Consulter l’emploi du temps

1. L’élève ouvre le calendrier.
2. L’application demande les cours de sa classe pour la période affichée.
3. L’élève passe de la vue du jour à la vue de la semaine.
4. Il ouvre un cours pour consulter la matière, les horaires, la salle et le nom du professeur.

Résultat attendu : aucun cours d’une autre classe n’est retourné par l’API.

### Parcours E5 — Ajouter ou corriger un cours

1. L’élève ouvre l’emploi du temps de sa classe.
2. Il crée un cours ou ouvre un cours existant à corriger.
3. Il choisit une matière et un professeur dans les listes de la classe.
4. Il renseigne la salle et les horaires.
5. L’API contrôle la classe et les conflits simples, puis conserve l’auteur de la modification.

Résultat attendu : la classe reste autosuffisante sans intervention ni approbation du délégué. L’historique permet d’identifier et restaurer une mauvaise correction.

### Parcours E6 — Gérer une tâche personnelle

1. L’élève crée une tâche avec un titre et une échéance.
2. Il peut ajouter une description, lier un cours et activer un rappel.
3. Il peut modifier, terminer ou supprimer sa tâche.

Résultat attendu : la tâche est visible uniquement par son propriétaire.

La tâche est classée dans `Ecole`, `Alternance` ou `Entreprise`.

Pour un utilisateur sans classe, elle peut être classée dans `Alternance`. Il peut également ajouter un événement daté à son emploi du temps personnel.

### Parcours E7 — Créer ou suivre un devoir collectif

1. L’élève consulte les devoirs et projets de sa classe.
2. Il peut publier un nouveau devoir ou corriger une information commune.
3. Il ouvre un devoir et consulte son échéance et le cours associé.
4. Il gère son propre état d’avancement sans modifier celui des autres.

Résultat attendu : la progression d’un élève n’affecte pas celle des autres.

### Parcours E8 — Enregistrer une alternance

1. L’élève effectue une recherche publique ou depuis son espace connecté.
2. Il ajoute une offre aux favoris.
3. Le favori est enregistré sur son compte et devient disponible sur ses autres appareils.
4. Il peut également sauvegarder ses critères de recherche.

### Parcours E9 — Consulter les informations de la classe

1. L’élève ouvre le fil d’informations de sa classe.
2. Il consulte d’abord les annonces épinglées, puis les autres annonces récentes.
3. Les échanges ordinaires restent sur Discord.

### Parcours E10 — Partager une offre avec sa classe

1. L’élève ouvre la section `Entraide` de la destination Alternances ou Entreprise.
2. Il publie un message court avec, facultativement, un lien vers une offre.
3. Seuls les membres approuvés de sa classe voient le message.
4. Il peut supprimer son message ; un délégué peut le masquer pour modération.

Résultat attendu : le canal centralise uniquement l’entraide liée aux alternances et ne remplace pas Discord.

### Parcours E11 — Modifier le rappel des cours

1. L’élève ouvre les préférences de notifications.
2. Il choisit le délai global avant un cours : à l’heure, 5, 10, 15, 30 ou 60 minutes.
3. Le prochain rappel utilise immédiatement ce réglage personnel.

## 4. Délégué

### Parcours D1 — Communiquer le code de classe

1. Le délégué ouvre les réglages de sa classe.
2. Il obtient le code lors de sa création ou de son renouvellement et peut le copier ou le partager.
3. S’il le renouvelle, l’ancien code devient invalide.

### Parcours D2 — Gérer les informations mutuelles

1. Le délégué ouvre les informations de la classe.
2. Il ajoute, renomme, archive ou corrige une matière ou un professeur.
3. Les élèves retrouvent ces valeurs dans les formulaires de cours.

### Parcours D3 — Publier une annonce

1. Le délégué rédige une annonce officielle.
2. Il choisit de l’épingler ou non.
3. L’annonce apparaît dans le fil d’informations et, si elle est épinglée, sur le tableau de bord.
4. Le délégué peut retirer l’épingle ou archiver l’annonce.

Le délégué n’a pas de pouvoir particulier sur les cours, devoirs ou tâches des autres élèves.

### Parcours D4 — Gérer les membres et délégués

1. Le délégué consulte la liste des membres de sa classe.
2. Il peut retirer un membre de la classe.
3. Il peut attribuer ou retirer le rôle `Delegue` à un autre élève.
4. L’API empêche la classe de se retrouver sans aucun délégué actif.

### Parcours D5 — Approuver un nouvel élève

1. Le délégué reçoit et ouvre la liste des demandes en attente.
2. Il voit uniquement l’identité nécessaire à la décision, jamais un mot de passe ou une donnée privée inutile.
3. Il approuve ou refuse la demande.
4. En cas d’approbation, l’élève obtient l’accès à la classe ; en cas de refus, aucune donnée scolaire n’est révélée.

## 5. Matrice d’accès

| Fonction | Visiteur | Élève | Délégué |
| :--- | :---: | :---: | :---: |
| Rechercher une alternance | Oui | Oui | Oui |
| Consulter une offre | Oui | Oui | Oui |
| Ouvrir le site de candidature | Oui | Oui | Oui |
| Synchroniser des favoris | Non | Oui | Oui |
| Sauvegarder une recherche | Non | Oui | Oui |
| Utiliser son planning et agenda personnels | Après création de compte | Oui | Oui |
| Consulter les données scolaires | Non | Sa classe | Sa classe |
| Gérer ses tâches personnelles | Non | Oui | Oui |
| Créer ou corriger les cours et devoirs collectifs | Non | Oui | Oui |
| Partager une offre dans l’entraide de classe | Non | Oui | Oui |
| Gérer ses tâches École et Entreprise | Non | Oui | Oui |
| Consulter le fil d’informations | Non | Oui | Oui |
| Gérer le code et les informations de classe | Non | Non | Oui |
| Gérer les matières et professeurs | Non | Non | Oui |
| Publier et épingler une annonce officielle | Non | Non | Oui |
| Retirer un membre ou gérer les délégués | Non | Non | Oui |
| Approuver une demande d’adhésion | Non | Non | Oui |
| Créer une classe et en devenir délégué | Avec création de compte | Oui, sans classe | Non pertinent |

## 6. Décisions à prendre avant les maquettes

- comportement des favoris d’un visiteur non connecté ;
- durée de validité et format du code de classe.
- durée de conservation des messages d’entraide ;
- fournisseur de clés de chiffrement en production.
