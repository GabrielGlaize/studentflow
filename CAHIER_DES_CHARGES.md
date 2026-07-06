# Cahier des charges — StudyFlow Pro

> Application de gestion scolaire et de recherche d’alternances pour les élèves d’une classe
> Dernière mise à jour : 4 juillet 2026

---

## 1. Présentation du projet

**StudyFlow Pro** est une application destinée à faciliter l’organisation quotidienne des élèves d’une classe. Elle centralise l’emploi du temps, les devoirs, les rappels et la recherche d’alternances.

Dans un premier temps, l’application sera utilisée au sein d’un seul établissement et testée avec une classe réelle. Le projet doit avant tout démontrer sa capacité à répondre aux besoins concrets des élèves, tout en conservant une architecture permettant une évolution future.

Le moteur de recherche d’alternances constitue également un service Web public autonome. Il s’adresse notamment aux futurs élèves qui cherchent une entreprise avant de rejoindre une classe StudyFlow. Aucune installation, aucun compte et aucun code de classe ne sont nécessaires pour effectuer une recherche.

---

## 2. Objectifs

StudyFlow Pro doit permettre aux élèves de :

- consulter rapidement leur emploi du temps ;
- connaître la salle et le professeur associés à chaque cours ;
- consulter les devoirs donnés à la classe ;
- créer et gérer leurs propres tâches personnelles ;
- recevoir des rappels avant les cours et les échéances ;
- rechercher des offres d’alternance ;
- enregistrer des offres et des recherches favorites.

Certains élèves disposent également du rôle **Délégué**. Ils conservent toutes les fonctionnalités d’un élève, avec des droits limités à la gestion de la classe, de son code d’accès, des référentiels communs et des communications officielles.

StudyFlow repose sur un principe d’**autosuffisance de la classe** : les élèves créent et maintiennent collectivement les cours, les devoirs et les projets. Le délégué n’est pas responsable de ces contenus et ne remplace pas un administrateur technique.

---

## 3. Périmètre du projet

### 3.1 Périmètre initial

- un seul établissement ;
- une ou plusieurs classes, avec une classe utilisée pour la première version ;
- deux rôles : `Eleve` et `Delegue` ;
- aucun compte professeur ;
- application Flutter Android pour les élèves et les délégués ;
- interface Flutter Web responsive pour les smartphones et les ordinateurs ;
- recherche d’alternances accessible publiquement sur le Web, sans installation ni compte ;
- utilisation de la recherche possible avant toute appartenance à une classe ;
- API ASP.NET Core ;
- base de données PostgreSQL ;
- recherche d’alternances intégrée à l’application ;
- candidature réalisée sur le site d’origine de l’offre.

### 3.2 Éléments hors périmètre du MVP

- gestion de plusieurs établissements ;
- espace de connexion pour les professeurs ;
- messagerie entre élèves et professeurs ;
- dépôt de candidature directement depuis StudyFlow ;
- génération automatique complète des emplois du temps ;
- synchronisation avec les logiciels officiels de l’établissement.

---

## 4. Organisation de l’équipe

Le projet est réalisé par une équipe de **deux membres**.

| Rôle | Responsable | Missions principales |
| :--- | :--- | :--- |
| **Membre 1 — Produit, Flutter et intégration** | Gabriel | Parcours utilisateur, application Flutter, design, démonstration, intégration mobile/backend et documentation de présentation. |
| **Membre 2 — Sécurité, données et revue technique** | Garance | Revue sécurité, confidentialité, authentification, protection des données, base PostgreSQL, tests et documentation sécurité. |

Les deux membres participent aux choix techniques, aux revues de code et aux tests de bout en bout.

---

## 5. Utilisateurs et autorisations

### 5.1 Visiteur

Un visiteur non connecté peut, depuis un navigateur sur smartphone ou ordinateur :

- rechercher des offres d’alternance ;
- utiliser les filtres disponibles ;
- consulter le détail d’une offre ;
- ouvrir le site d’origine afin de candidater.
- démarrer la création d’une classe ; ce parcours crée simultanément son compte, sa classe et sa session.

La connexion est nécessaire pour synchroniser les favoris, enregistrer une recherche et recevoir des alertes.

### 5.2 Utilisateur sans classe

Un futur élève peut créer un compte sans rejoindre immédiatement une classe. Il peut :

- utiliser toutes les fonctions publiques de recherche ;
- synchroniser ses offres favorites ;
- sauvegarder ses recherches ;
- recevoir des alertes d’alternance ;
- rejoindre une classe plus tard avec un code ;
- utiliser un emploi du temps personnel pour ses entretiens, relances et rendez-vous liés à sa recherche ;
- utiliser l’agenda pour ses candidatures, tâches et échéances, même sans classe.

### 5.3 Élève

Un élève peut :

- demander à rejoindre une classe à l’aide de son code, puis attendre l’approbation d’un délégué ;
- consulter l’emploi du temps de sa classe ;
- proposer, modifier et corriger les cours de sa classe ;
- consulter les informations d’un cours ;
- créer et maintenir les devoirs ou projets collectifs ;
- suivre individuellement son avancement ;
- créer, modifier et supprimer ses tâches personnelles ;
- configurer ses notifications ;
- rechercher des alternances ;
- enregistrer des recherches et des offres favorites ;
- partager des offres et échanger dans le canal d’entraide alternance de sa classe ;
- consulter le fil d’informations importantes de sa classe.

### 5.4 Délégué

Un délégué est également un élève. En plus des fonctionnalités précédentes, il peut uniquement :

- gérer les informations générales de sa classe ;
- générer, communiquer et renouveler le code permettant de rejoindre la classe ;
- approuver ou refuser les demandes d’adhésion à la classe ;
- retirer un élève de la classe ;
- nommer un autre délégué ;
- quitter son propre rôle délégué ;
- gérer la liste commune des professeurs ;
- gérer la liste commune des matières ;
- publier des annonces officielles visibles par toute la classe ;
- épingler ou retirer de l’épingle les annonces importantes.

Le délégué ne possède aucun droit exclusif sur les cours et les devoirs. Ces contenus restent gérés par les élèves. Les autorisations du délégué sont vérifiées par l’API.

---

## 6. Fonctionnalités

### 6.1 Authentification

- connexion avec une adresse e-mail et un mot de passe ;
- mots de passe hachés et jamais stockés en clair ;
- authentification par jetons JWT ;
- accès aux fonctionnalités selon le rôle ;
- déconnexion et renouvellement sécurisé de session.

Après création de son compte, un utilisateur peut utiliser immédiatement l’outil d’alternances. Il rejoint une classe seulement lorsqu’il dispose d’un code communiqué par un délégué. Le code peut être renouvelé en cas de diffusion non souhaitée.

Un visiteur peut aussi choisir `Créer ma classe`. L’API crée alors, dans une seule transaction, son compte, la classe, son rattachement approuvé et le rôle `Delegue`. Un code de classe est généré après la création. Une demande faite avec ce code reste en attente tant qu’un délégué ne l’a pas approuvée ; elle ne donne accès à aucune donnée scolaire.

### 6.2 Tableau de bord élève

Le tableau de bord rassemble les informations les plus urgentes :

- le prochain cours, son horaire et sa salle ;
- les devoirs ou projets à rendre prochainement ;
- les tâches personnelles encore à faire ;
- les annonces épinglées par les délégués ;
- un raccourci vers la journée ou la semaine en cours ;
- un résumé facultatif des prochaines échéances liées à l’alternance ou à l’entreprise.

Sans classe, le tableau de bord remplace les contenus scolaires par le prochain événement personnel, les candidatures à relancer et les tâches liées à la recherche d’alternance.

### 6.3 Planning collaboratif

- affichage des cours du jour ;
- affichage de la semaine ;
- accès au nom de la matière, à la salle, aux horaires et au nom du professeur ;
- indication des cours modifiés ou annulés ;
- isolation des données selon la classe de l’élève ;
- ajout et correction des cours par les élèves de la classe ;
- modification directe d’un cours incorrect par tout élève approuvé de la classe, sans validation du délégué ;
- sélection d’une matière et d’un professeur dans les listes communes.

### 6.4 Gestion collaborative du calendrier

- création d’un cours par un élève pour sa propre classe ;
- modification et suppression d’un cours ;
- définition de la date, de l’heure de début et de l’heure de fin ;
- saisie de la matière, de la salle et du nom du professeur ;
- contrôle des conflits horaires simples ;
- conservation de l’auteur et des dates de modification ;
- possibilité pour n’importe quel élève de corriger ou supprimer une information ;
- suppression logique et historique minimal pour restaurer une modification erronée.

Le principe d’autosuffisance est prioritaire : un délégué n’approuve jamais la création ou la correction d’un cours. Les cours récurrents ne font pas partie du MVP final. Les modifications concurrentes sont détectées et l’historique indique l’auteur et l’état précédent.

### 6.5 Agenda, devoirs et tâches

Deux catégories sont distinguées :

- **devoir ou projet collectif** : créé par un élève pour sa classe ;
- **tâche personnelle** : visible uniquement par l’élève qui l’a créée.

Les tâches personnelles peuvent être classées dans trois espaces :

- `Ecole` pour les études ;
- `Entreprise` pour les missions professionnelles lorsque l’élève est en alternance ;
- `Alternance` pour les candidatures, relances, entretiens et démarches d’un futur élève.

L’emploi du temps personnel accepte également des événements `Alternance` ou `Entreprise`, indépendamment de l’appartenance à une classe.

Chaque devoir ou tâche peut comporter :

- un titre ;
- une description ;
- une échéance ;
- un cours associé facultatif ;
- un état : à faire ou terminé ;
- une préférence de notification.

### 6.6 Notifications

- rappel avant un cours, cinq minutes avant par défaut ;
- rappel d’un devoir la veille de son échéance ;
- activation ou désactivation des rappels de cours ;
- choix du délai global avant un cours, avec cinq minutes par défaut ;
- activation ou désactivation du rappel de chaque devoir ;
- enregistrement du jeton de notification de l’appareil.

Le délai avant un cours est configurable dans les réglages. Les valeurs initiales proposées sont : à l’heure, 5, 10, 15, 30 ou 60 minutes avant.

### 6.7 Recherche d’alternances

Le module permet de rechercher des offres d’alternance à partir d’une ou plusieurs sources externes autorisées. Il est disponible dans l’application installée et sur une interface Web publique et responsive.

L’interface Web publique comprend au minimum une page d’accueil/recherche, une page de résultats et une page de détail. Elle doit fonctionner sur smartphone et ordinateur, y compris pour une personne qui n’appartient à aucune classe.

Fonctionnalités attendues :

- recherche par métier, domaine ou mots-clés ;
- recherche par ville ou zone géographique ;
- filtre par distance lorsque la source le permet ;
- filtre par niveau d’études ou type de contrat lorsque disponible ;
- affichage de l’entreprise, du lieu, du titre et de la date de publication ;
- accès à la description de l’offre ;
- ouverture de la page d’origine pour candidater ;
- ajout et suppression d’une offre dans les favoris ;
- sauvegarde des critères d’une recherche.
- canal d’entraide réservé aux membres approuvés d’une classe pour partager des offres et conseils liés aux alternances ;
- message court avec lien d’offre facultatif ;
- suppression de son propre message et modération par un délégué.

La recherche, les filtres, la consultation d’une offre et l’ouverture du site de candidature ne nécessitent pas de compte. Les favoris synchronisés, les recherches sauvegardées et les alertes nécessitent une authentification.

Pour le MVP, StudyFlow ne stocke pas toutes les offres externes. La base conserve uniquement les favoris, les recherches sauvegardées et, si nécessaire, un cache temporaire.

Le scraping de sites n’est pas prévu dans le MVP. L’intégration passe par des APIs ou fournisseurs autorisés. Le backend peut agréger La Bonne Alternance, Adzuna et France Travail lorsque les clés nécessaires sont configurées.

Le canal d’entraide n’est ni public ni un chat généraliste : il est limité aux alternances et isolé par classe. Le fil officiel des délégués reste distinct, et Discord reste utilisé pour les conversations ordinaires.

### 6.8 Espace entreprise

Dans ses réglages, l’élève peut indiquer s’il possède déjà une entreprise :

- sans entreprise, la navigation affiche l’outil `Alternances` ;
- avec une entreprise, elle peut afficher un espace `Entreprise`.

La destination professionnelle conserve toujours un accès secondaire à la recherche et à l’entraide. Sans entreprise, elle met en avant `Recherche` et `Entraide`. Avec une entreprise, son libellé peut devenir `Entreprise` et elle met en avant :

- événements professionnels dans l’emploi du temps personnel ;
- missions et tâches dans l’agenda ;
- échéances de suivi, rendez-vous avec le tuteur et rappels ;
- liens et ressources importantes ;
- accès secondaire à la recherche et au canal d’entraide alternance.

Le stockage de fichiers et de pièces contractuelles est reporté. Le MVP ne conserve que des libellés et liens chiffrés afin de limiter les données sensibles.

### 6.9 Fil d’informations de la classe

- fil réservé aux informations réellement importantes ;
- annonces officielles publiées par les délégués ;
- annonces épinglées et centralisées ;
- consultation par tous les élèves de la classe ;
- aucune conversation instantanée, Discord restant utilisé pour les échanges ordinaires ;
- aucune messagerie avec les professeurs.

### 6.10 Profil et réglages

- modification des informations de profil autorisées ;
- thème clair, sombre ou système ;
- indication `J’ai une entreprise` ;
- préférences de notifications pour les cours, devoirs, tâches, annonces et alternances ;
- choix du délai des rappels lorsque disponible ;
- premier jour de la semaine et vue calendrier par défaut ;
- affichage ou masquage automatique des éléments terminés ;
- mise en sourdine temporaire des annonces non épinglées ;
- gestion des appareils et de la session ;
- confidentialité et suppression du compte ;
- réglages d’accessibilité simples, notamment taille du texte et réduction des animations lorsque possible.

---

## 7. Architecture technique

### 7.1 Technologies retenues

| Composant | Technologie |
| :--- | :--- |
| Application | Flutter / Dart, code partagé lorsque pertinent |
| Plateformes initiales | Android et Web responsive |
| Backend | ASP.NET Core — .NET 8 ou version LTS retenue au démarrage |
| ORM | Entity Framework Core, approche Code First |
| Base de données | PostgreSQL |
| Authentification | ASP.NET Core Identity et JWT |
| Documentation API | OpenAPI / Swagger |
| Notifications | Service de notifications push compatible avec Flutter |
| Maquettes | Figma |
| Gestion du code | Git et GitHub |

La version iOS reste possible avec Flutter, mais elle n’est pas prioritaire pour le MVP si l’équipe ne dispose pas du matériel ou des comptes nécessaires.

### 7.2 Organisation générale

```text
Application Flutter Android ----+
                                |
Flutter Web responsive ---------+--> API ASP.NET Core
                                     |       |
                                     |       +--> Source externe d'offres
                                     +--> PostgreSQL
                                     +--> Service de notifications push
```

L’application Flutter affiche les fonctions correspondant au rôle de l’utilisateur. La partie Web expose publiquement le module d’alternances et demande une connexion avant toute fonction personnelle. Les élèves gèrent collaborativement les cours et devoirs de leur classe ; les capacités réservées aux délégués sont contrôlées par l’API.

---

## 8. Modèle de données initial

| Entité | Attributs principaux | Relations |
| :--- | :--- | :--- |
| **Classe** | Id, Nom, CodeAccesHash, CodeAccesChiffre | Possède plusieurs utilisateurs, cours, devoirs et annonces. |
| **Utilisateur** | Id, Email, PasswordHash, Nom, Prenom, Role | Peut appartenir à une classe et possède des favoris et préférences. |
| **DemandeAdhesionClasse** | Id, ClasseId, UtilisateurId, Statut | Attend l’approbation ou le refus d’un délégué. |
| **Professeur** | Id, NomAfficheChiffre, NomRechercheHash | Référence commune chiffrée maintenue par les délégués d’une classe. |
| **Matiere** | Id, Nom | Référence commune maintenue par les délégués d’une classe. |
| **Cours** | Id, MatiereId, ProfesseurId, DateJour, DonneesChiffrees, EstAnnule | Appartient à une classe, possède un auteur et peut appartenir à une série. |
| **EvenementPersonnel** | Id, UtilisateurId, DateJour, DonneesChiffrees, Categorie | Alimente l’emploi du temps Alternance ou Entreprise d’un utilisateur. |
| **DevoirCollectif** | Id, Titre, Description, Deadline | Appartient à une classe et peut être lié à un cours. |
| **SuiviDevoir** | Id, EstTermine, NotificationActive | Relie un élève à son état individuel pour un devoir collectif. |
| **TachePersonnelle** | Id, Titre, Description, Deadline, EstTerminee | Appartient uniquement à son créateur et peut être liée à un cours. |
| **PreferenceNotification** | Id, CoursActifs, DevoirsActifs | Appartient à un utilisateur. |
| **AppareilNotification** | Id, Token, Plateforme | Appartient à un utilisateur. |
| **RechercheAlternance** | Id, MotsCles, Localisation, Distance, Filtres | Appartient à un utilisateur. |
| **OffreFavorite** | Id, OffreExterneId, Source, Titre, Entreprise, Url | Appartient à un utilisateur. |
| **MessageAlternance** | Id, ClasseId, AuteurId, ContenuChiffre, LienChiffre | Message du canal d’entraide alternance privé de la classe. |
| **AnnonceClasse** | Id, Contenu, EstEpingle | Appartient à une classe et possède un délégué auteur. |
| **RevisionContribution** | Id, EntiteType, EntiteId, Action, SnapshotJson | Conserve un historique minimal des cours et devoirs collaboratifs. |

Les offres favorites conservent quelques informations utiles afin de rester identifiables, même si l’offre externe devient indisponible.

---

## 9. API actuelle du MVP

```text
/api/v1/auth
/api/v1/classes
/api/v1/courses
/api/v1/homework
/api/v1/class-announcements
/api/v1/class-resources
/api/v1/notifications
/api/v1/personal-agenda
/api/v1/apprenticeships
/api/v1/apprenticeship-messages
/api/v1/public/alternances
```

La route `/api/v1/public/alternances` est accessible sans authentification. Les données scolaires nécessitent une connexion et une appartenance à la classe. La gestion du code, des matières, des professeurs et des annonces officielles nécessite le rôle `Delegue`.

Une appartenance n’est effective qu’après approbation. Un utilisateur en attente ne reçoit ni le rôle `Eleve`, ni les clés ou données permettant de lire l’emploi du temps.

---

## 10. Exigences non fonctionnelles

### 10.1 Sécurité

- communications réalisées en HTTPS ;
- mots de passe hachés avec un mécanisme reconnu ;
- validation des entrées côté API ;
- contrôle du rôle et de la classe pour chaque ressource protégée ;
- approbation explicite d’une demande d’adhésion avant tout accès scolaire ;
- chiffrement applicatif des noms et informations des professeurs, salles, horaires précis et contenus professionnels sensibles ;
- clés de chiffrement conservées hors de PostgreSQL et hors du dépôt ;
- chiffrement des disques, sauvegardes et connexions à PostgreSQL en production ;
- absence de noms de professeurs, horaires, salles ou codes de classe dans les journaux ;
- aucun secret ou mot de passe stocké dans le dépôt Git ;
- limitation des données personnelles collectées.

### 10.2 Protection des données

- collecte limitée aux données nécessaires ;
- possibilité de supprimer un compte et ses données personnelles ;
- information claire sur les données transmises aux services externes ;
- conservation limitée des journaux techniques ;
- prise en compte du RGPD avant une utilisation réelle dans l’établissement.

### 10.3 Confidentialité de l’emploi du temps

L’isolation par classe protège contre les accès ordinaires via l’API, mais elle ne suffit pas en cas de copie de la base. StudyFlow applique donc une défense en profondeur :

- `classeId`, la matière et le jour restent indexables pour charger une semaine ;
- le nom du professeur, ses informations, la salle et l’horaire précis sont chiffrés par l’API avant écriture ;
- la clé maîtresse n’est jamais stockée dans la même base ;
- les événements personnels, ressources Entreprise et messages d’entraide suivent le même principe lorsqu’ils contiennent des informations sensibles ;
- le déchiffrement n’a lieu qu’après authentification et contrôle d’une appartenance approuvée ;
- une fuite de PostgreSQL seule ne doit pas révéler les noms des professeurs ni leurs horaires précis.

### 10.4 Qualité et ergonomie

- interface adaptée aux écrans mobiles ;
- interface Web responsive utilisable sur smartphone et ordinateur sans installation ;
- navigation simple vers le planning, les devoirs et les alternances ;
- états de chargement et messages d’erreur compréhensibles ;
- temps de réponse raisonnable ;
- fonctionnement correct en cas d’indisponibilité temporaire d’une source d’alternances.

---

## 11. Planning prévisionnel

### Phase 1 — Conception

- validation du périmètre ;
- parcours utilisateur ;
- maquettes Flutter mobile et Web ;
- schéma de base de données ;
- contrat initial de l’API ;
- sélection de la source d’offres d’alternance.

### Phase 2 — Infrastructure

- création de l’API ASP.NET Core ;
- configuration de PostgreSQL et EF Core ;
- création du projet Flutter ;
- authentification et gestion des rôles ;
- première migration de la base.

### Phase 3 — Fonctionnalités scolaires

- gestion des classes et utilisateurs ;
- calendrier et cours ;
- devoirs collectifs et tâches personnelles ;
- fonctions réservées au délégué ;
- fil d’informations et annonces épinglées ;
- notifications.

### Phase 4 — Alternances

- intégration de la source externe ;
- recherche et filtres ;
- détail d’une offre ;
- favoris et recherches sauvegardées ;
- gestion des erreurs et du cache.

### Phase 5 — Tests et livraison

- tests unitaires de la logique sensible ;
- tests d’intégration de l’API ;
- tests des principaux parcours Flutter ;
- test de bout en bout ;
- correction des problèmes d’ergonomie ;
- rédaction du rapport et du `README.md`.

---

## 12. Priorités du MVP

### Priorité 1 — Indispensable

- authentification ;
- rôles Élève et Délégué ;
- code permettant de rejoindre une classe ;
- approbation d’un nouvel élève par un délégué ;
- création publique d’un compte et d’une classe avec attribution automatique du rôle Délégué ;
- tableau de bord élève ;
- consultation et gestion du calendrier ;
- devoirs collectifs et tâches personnelles ;
- matières et professeurs de la classe ;
- isolation des données par classe ;
- recherche d’alternances ;
- accès public à la recherche depuis un navigateur ;
- planning et agenda personnels utilisables sans classe ;
- chiffrement applicatif des informations sensibles de l’emploi du temps ;
- ouverture de l’offre externe.

### Priorité 2 — Importante

- notifications ;
- fil d’informations et annonces épinglées ;
- réglages du profil, du thème et du mode Entreprise ;
- favoris d’alternance ;
- recherches sauvegardées ;
- répétition hebdomadaire des cours.
- canal d’entraide alternance privé à la classe ;
- délai configurable du rappel avant un cours ;
- espace Entreprise avec événements, tâches et liens importants.

### Priorité 3 — Si le temps le permet

- alertes sur les nouvelles alternances ;
- mode sombre ;
- fonctionnement hors connexion partiel ;
- prise en charge complète d’iOS.
- stockage de documents dans l’espace Entreprise.

---

## 13. Critères de réussite

Le MVP est considéré comme réussi si :

- un élève peut se connecter et consulter uniquement les données de sa classe ;
- un élève peut créer un cours visible par sa classe ;
- tout élève approuvé peut corriger ce cours sans validation d’un délégué ;
- un futur élève sans classe peut organiser ses entretiens et candidatures dans son planning et son agenda ;
- un délégué peut approuver ou refuser une demande d’adhésion ;
- le créateur d’une classe devient automatiquement son premier délégué ;
- un élève peut publier un devoir ou projet collectif pour sa classe ;
- un délégué peut renouveler le code de classe et gérer les matières et professeurs ;
- un délégué peut publier une annonce épinglée ;
- un élève peut créer et terminer une tâche personnelle ;
- les rappels prévus sont reçus sur un appareil compatible ;
- un élève peut rechercher une alternance et ouvrir l’offre d’origine ;
- un visiteur peut effectuer cette recherche depuis un navigateur sans installer l’application et sans créer de compte ;
- un utilisateur peut créer un compte, conserver ses favoris et recevoir des alertes sans appartenir à une classe ;
- un élève peut enregistrer une offre favorite ;
- les membres approuvés peuvent partager une offre dans le canal d’entraide de leur classe ;
- une copie de la base seule ne permet pas de lire les noms de professeurs, salles ou horaires précis ;
- les principaux parcours sont testés et documentés ;
- le `README.md` explique clairement l’installation et le lancement du projet.

---

## 14. Décisions restant à prendre

- obtention et sécurisation des accès API externes réellement utilisés en production ;
- stratégie précise de notifications push ;
- hébergement de l’API et de PostgreSQL ;
- fournisseur de gestion des clés de chiffrement en production ;
- service SMTP pour la réinitialisation de mot de passe ;
- identité visuelle définitive de StudyFlow Pro pour une éventuelle publication.
