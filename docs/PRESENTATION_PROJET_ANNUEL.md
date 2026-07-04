# Présentation du projet annuel — StudyFlow Pro

> Préparation orale pour Gabriel et Garance — 1re année  
> Dernière mise à jour : 4 juillet 2026

## 1. Positionnement à donner au jury

StudyFlow Pro doit être présenté comme un **MVP fonctionnel avancé**, pas comme une application déjà prête à publier sur l’App Store.

La formulation la plus juste :

> StudyFlow est une application Flutter connectée à une API ASP.NET Core et une base PostgreSQL. Elle aide une classe à s’organiser de manière collaborative : planning, devoirs, annonces, tâches personnelles et recherche d’alternance. Le projet est suffisamment avancé pour être démontré localement avec un backend réel, mais il nécessiterait encore une phase de production pour être ouvert publiquement.

Ce positionnement est crédible : il valorise le travail réalisé sans promettre une production complète.

## 2. Problème de départ

Le problème à expliquer simplement :

- les informations de classe sont dispersées ;
- les changements de salle, devoirs et rappels ne sont pas toujours centralisés ;
- les élèves ont aussi besoin d’organiser leur recherche d’alternance ;
- les futurs élèves cherchent parfois une alternance avant même d’être dans une classe ;
- un outil trop administratif serait lourd pour un usage étudiant quotidien.

Phrase possible :

> Nous sommes partis d’un besoin concret : aider une classe à rester organisée sans dépendre d’un administrateur ou d’un professeur. L’idée était de créer un outil léger, collaboratif et compréhensible par des étudiants.

## 3. Idée centrale du projet

Le concept important est l’**autosuffisance de la classe**.

Cela signifie :

- les élèves approuvés peuvent créer et corriger les cours ;
- les élèves peuvent créer les devoirs de classe ;
- le délégué ne valide pas chaque contenu ;
- le délégué gère seulement la structure de la classe et les annonces importantes ;
- l’API contrôle les droits et l’isolation des données.

Phrase possible :

> Le délégué n’est pas un administrateur complet. Il sert à gérer l’accès à la classe, les informations communes et le fil officiel. Les cours et devoirs restent collaboratifs.

## 4. Répartition recommandée entre Gabriel et Garance

### Gabriel

Gabriel peut présenter :

- le besoin utilisateur ;
- le parcours produit ;
- l’application Flutter ;
- le design et la navigation ;
- le planning, l’agenda, les alternances et l’espace Entreprise ;
- la démonstration live ;
- les difficultés de lancement mobile/iPhone ;
- les perspectives produit.

### Garance

Garance peut présenter :

- l’authentification ;
- les rôles et autorisations ;
- l’isolation par classe ;
- les mots de passe hashés ;
- JWT et refresh tokens ;
- DataProtection et chiffrement des données sensibles ;
- HMAC pour les recherches/secrets ;
- rate limiting, CORS et headers HTTP ;
- limites de sécurité avant production.

Transition simple :

> Je vais d’abord présenter le besoin, l’expérience utilisateur et la démo. Garance détaillera ensuite la partie sécurité et protection des données, qui est centrale dans notre projet.

## 5. Plan de soutenance conseillé

Durée adaptable : environ 15 à 22 minutes.

L’objectif n’est pas seulement de lister les fonctionnalités. Il faut raconter un vrai projet : un besoin concret, des choix techniques, des problèmes rencontrés, des corrections, puis une démonstration qui prouve que l’app n’est pas juste une maquette.

### Slide 1 — Titre

Contenu :

- StudyFlow Pro ;
- gestion de classe et recherche d’alternance ;
- noms : Gabriel et Garance ;
- projet annuel de première année.

À dire :

> StudyFlow Pro est notre projet annuel. C’est une application pensée pour aider une classe à gérer son organisation quotidienne et sa recherche d’alternance.

### Slide 2 — Contexte réel

Contenu :

- classe réelle, besoins quotidiens ;
- devoirs, salles, changements, rappels ;
- recherche d’alternance en parallèle ;
- besoin d’un outil simple, pas d’un ENT complet.

À dire :

> Le point de départ est très concret : dans une classe, les informations circulent souvent sur plusieurs canaux. On voulait donc un outil à l’échelle de la classe, plus léger qu’un ENT, mais suffisamment structuré pour éviter les oublis.

### Slide 3 — Problème à résoudre

Contenu :

- les informations importantes ne sont pas toujours centralisées ;
- les élèves doivent pouvoir corriger rapidement une erreur ;
- les futurs élèves peuvent chercher une alternance avant d’être dans une classe ;
- un délégué ne doit pas devenir un administrateur lourd.

À dire :

> On a volontairement évité un modèle où tout dépend d’un admin. Le cœur du projet, c’est l’autosuffisance : si un cours est mal renseigné, un élève approuvé peut le corriger directement.

### Slide 4 — Objectifs produit

Contenu :

- centraliser planning, devoirs et annonces ;
- permettre une gestion collaborative ;
- garder un rôle délégué léger ;
- proposer un outil d’alternance utilisable avec ou sans classe.

À dire :

> Notre objectif était de faire une application utile dès maintenant pour une classe, tout en gardant une architecture qui pourrait évoluer plus tard vers plusieurs classes ou une vraie mise en production.

### Slide 5 — Utilisateurs et droits

Contenu :

- visiteur ;
- futur élève sans classe ;
- élève approuvé ;
- délégué.

À dire :

> Un futur élève peut déjà utiliser les alternances et son agenda personnel. Les données scolaires restent privées tant qu’il n’est pas approuvé dans une classe.

### Slide 6 — Parcours utilisateur

Contenu :

- créer un compte ;
- rejoindre une classe avec un code ;
- attendre l’approbation ;
- utiliser planning, agenda et alternances ;
- devenir délégué ou gérer la classe si on a ce rôle.

À dire :

> On a beaucoup réfléchi au parcours d’entrée. Un élève ne doit pas voir les données d’une classe juste parce qu’il connaît un code. Le code crée une demande, puis un délégué approuve.

### Slide 7 — Fonctionnalités principales

Contenu :

- tableau de bord : prochain cours, devoirs, tâches, annonces ;
- planning : jour/semaine, ajout et correction des cours ;
- agenda : tâches École et Entreprise/Alternance séparées ;
- alternances : recherche, favoris, recherches sauvegardées ;
- profil : classe, membres, préférences, documents ;
- délégué : approbation, annonces, matières, professeurs.

À dire :

> On a essayé de garder une navigation simple : ce qui est urgent arrive sur le tableau de bord, et chaque onglet correspond à un vrai usage quotidien.

### Slide 8 — Architecture globale

Schéma simple :

```text
Flutter mobile / Web
        |
        v
API ASP.NET Core
        |
        v
PostgreSQL + EF Core
```

À dire :

> Nous avons séparé l’interface, l’API et la base de données. Cela se rapproche d’une architecture professionnelle classique.

### Slide 9 — Organisation du backend

Contenu :

- `StudyFlow.Api` : routes HTTP, configuration, sécurité ;
- `StudyFlow.Application` : cas d’usage ;
- `StudyFlow.Domain` : entités métier ;
- `StudyFlow.Infrastructure` : EF Core, PostgreSQL, services externes ;
- migrations EF Core pour faire évoluer la base.

À dire :

> Même si c’est un projet étudiant, on n’a pas mis tout le backend dans un seul fichier. On a séparé les responsabilités pour que le code reste relisible et améliorable.

### Slide 10 — Organisation de l’app Flutter

Contenu :

- écrans par domaine : auth, dashboard, planning, agenda, alternances, profil ;
- appels API centralisés ;
- état de session restauré ;
- design inspiré des maquettes HTML ;
- thème clair/sombre.

À dire :

> On est partis de maquettes HTML pour trouver une direction visuelle, puis on a reconstruit les écrans en Flutter. Une difficulté a été de ne pas seulement copier le visuel, mais de rendre les écrans réellement fonctionnels.

### Slide 11 — Alternances : pourquoi passer par le backend ?

Contenu :

- sources externes : La Bonne Alternance, Adzuna, France Travail ;
- clés API protégées côté serveur ;
- résultats normalisés ;
- fallback de démonstration ;
- même logique pour mobile et web public.

À dire :

> Flutter ne contacte pas directement les APIs externes. Le backend sert d’intermédiaire : il protège les clés, unifie les résultats et évite de dupliquer la logique dans l’app mobile et la page web.

### Slide 12 — Démonstration

Voir scénario détaillé plus bas.

### Slide 13 — Sécurité, par Garance

Contenu :

- mots de passe hashés ;
- JWT minimal ;
- refresh tokens HMAC ;
- isolation par classe ;
- données sensibles chiffrées ;
- DataProtection persistée ;
- rate limiting et CORS.

### Slide 14 — Problèmes rencontrés et solutions

Contenu :

- passer d’une maquette HTML à une vraie app Flutter ;
- connecter mobile, backend et base ;
- gérer iPhone/Xcode/codesign ;
- garder une sécurité cohérente ;
- éviter le mode démo trop visible ;
- séparer École, Alternance et Entreprise.

À dire :

> Une partie importante du projet n’est pas visible sur une capture d’écran : faire communiquer un téléphone réel, une API locale, PostgreSQL, Docker, Xcode et Flutter. On a dû résoudre beaucoup de petits problèmes d’intégration.

### Slide 15 — Bilan et perspectives

Contenu :

- MVP fonctionnel local ;
- architecture évolutive ;
- documentation complète ;
- à faire avant production : hébergement HTTPS, SMTP, backups, monitoring, stores.

Conclusion possible :

> Ce projet nous a permis de travailler sur un cycle complet : besoin utilisateur, maquettes, application mobile, API, base de données, sécurité et démonstration. Il n’est pas encore en production, mais il constitue une base solide pour une vraie V1 testable.

## 6. Fil rouge narratif pour l’oral

Pour que la présentation soit fluide, vous pouvez la raconter en quatre temps.

### 1. Le besoin

> On est partis d’un problème qu’on connaît nous-mêmes : dans une classe, les devoirs, les changements de salle et les informations importantes sont souvent dispersés.

Ce passage permet de montrer que le projet n’est pas choisi au hasard. Il vient d’un usage réel.

### 2. La décision produit

> Au lieu de créer une application très administrative, on a choisi un modèle collaboratif. Les élèves approuvés peuvent corriger les cours et créer les devoirs. Le délégué garde seulement un rôle léger : gérer l’accès, les listes communes et les annonces officielles.

Ce passage explique ce qui rend StudyFlow différent d’un simple agenda.

### 3. La construction technique

> On a ensuite transformé ce besoin en architecture : une app Flutter, une API ASP.NET Core, une base PostgreSQL et des APIs externes pour les alternances.

Ce passage montre la capacité à construire un vrai système complet.

### 4. La sécurité et les limites

> Comme l’application manipule des données de classe, on a travaillé l’isolation, les rôles, les mots de passe hashés, les tokens et le chiffrement de certaines données sensibles. Le projet reste un MVP local, mais il est pensé avec des bases de production.

Ce passage donne de la maturité : vous montrez ce qui est fait, mais aussi ce qu’il reste avant production.

## 7. Chronologie de réalisation

Cette section peut servir à montrer au jury votre méthode de travail.

### Étape 1 — Cahier des charges

Ce qui a été fait :

- définition des utilisateurs : visiteur, élève sans classe, élève approuvé, délégué ;
- choix du principe d’autosuffisance ;
- clarification du rôle délégué ;
- séparation entre scolaire, alternance et entreprise.

À dire :

> Au départ, le projet ressemblait plutôt à une application scolaire classique. En avançant, on a compris que le plus intéressant était le modèle collaboratif : une classe capable de s’organiser elle-même.

### Étape 2 — Maquettes HTML

Ce qui a été fait :

- prototype visuel du tableau de bord ;
- planning ;
- agenda ;
- alternances ;
- profil ;
- direction artistique avec palette et cartes arrondies.

À dire :

> Les maquettes HTML nous ont servi de laboratoire visuel. Elles ont permis de tester l’ambiance de l’application avant de tout reconstruire proprement en Flutter.

### Étape 3 — Backend et base de données

Ce qui a été fait :

- création de l’API ASP.NET Core ;
- structure en couches ;
- entités et migrations EF Core ;
- PostgreSQL avec Docker ;
- seed de développement.

À dire :

> Le seed est important pour la démo : il permet d’avoir une classe réaliste à chaque lancement, avec des cours, des devoirs, des élèves et une demande d’approbation.

### Étape 4 — Application Flutter

Ce qui a été fait :

- écrans principaux ;
- connexion réelle à l’API ;
- session persistée ;
- navigation ;
- formulaires de cours, devoirs, tâches, profil ;
- thème clair/sombre.

À dire :

> La difficulté a été de passer du prototype statique à une application qui réagit vraiment aux données du backend.

### Étape 5 — Alternances

Ce qui a été fait :

- écran de recherche dans l’app ;
- interface web publique ;
- appels backend ;
- sauvegarde de recherches ;
- favoris ;
- début d’agrégation multi-sources.

À dire :

> On a choisi de faire passer les alternances par le backend pour éviter d’exposer les clés API et pour pouvoir ajouter plusieurs sources sans changer l’app mobile.

### Étape 6 — Sécurité et revue

Ce qui a été fait :

- hash des mots de passe ;
- JWT minimal ;
- refresh tokens sécurisés ;
- reset password ;
- DataProtection persistée ;
- CORS plus strict ;
- rate limiting ;
- headers de sécurité ;
- documentation dédiée.

À dire :

> La sécurité n’a pas été ajoutée seulement à la fin. Elle a fait évoluer le projet : par exemple, on a revu les tokens, les secrets, les données sensibles et le comportement du backend au redémarrage.

### Étape 7 — Démonstration sur téléphone réel

Ce qui a été fait :

- lancement backend local accessible depuis l’iPhone ;
- script de lancement automatisé ;
- correction des problèmes Xcode/codesign ;
- documentation de lancement.

À dire :

> Tester sur un vrai téléphone a révélé des problèmes qu’on ne voit pas forcément sur émulateur : réseau local, IP du Mac, signature iOS, permissions et environnement Flutter.

## 8. Script oral plus naturel

Vous pouvez vous entraîner avec ce script court, puis improviser autour.

### Introduction

> Bonjour, nous allons vous présenter StudyFlow Pro. C’est une application de gestion de classe et de recherche d’alternance. Le projet part d’un besoin très concret : dans une classe, les informations importantes sont souvent dispersées. Nous avons donc voulu créer une application simple, collaborative et utilisable au quotidien.

### Transition vers le produit

> La particularité de StudyFlow, c’est que la classe est autosuffisante. Les élèves approuvés peuvent corriger le planning et créer les devoirs. Le délégué ne contrôle pas tout : il gère l’accès à la classe, les annonces importantes et les informations communes.

### Transition vers la technique

> Pour construire ça, nous avons séparé le projet en trois parties : une application Flutter, une API ASP.NET Core et une base PostgreSQL. Cette séparation nous permet d’avoir une architecture proche d’un vrai projet professionnel.

### Transition vers la démo

> On va maintenant montrer le parcours principal sur l’application. La démo utilise une vraie API locale et une vraie base PostgreSQL lancée avec Docker.

### Transition vers la sécurité

> Comme l’application manipule des données scolaires, on ne pouvait pas se contenter d’un simple prototype. Garance va maintenant détailler la partie sécurité : authentification, tokens, isolation par classe et protection des données sensibles.

### Conclusion

> StudyFlow n’est pas encore une application publiée en production, mais c’est un MVP fonctionnel avancé. Le projet nous a permis de travailler sur toute la chaîne : besoin utilisateur, maquettes, Flutter, API, base de données, sécurité, documentation et démonstration sur téléphone réel.

## 9. Scénario de démo recommandé

Avant la démo :

1. lancer PostgreSQL avec Docker ;
2. lancer le backend ;
3. lancer l’app iPhone avec `./scripts/run_iphone_developer.sh` ;
4. vérifier que le compte seedé fonctionne.

Compte principal :

```txt
gabriel@studyflow.dev
Password1234!
```

### Démo en 7 minutes

1. **Connexion**
   - montrer l’écran de connexion ;
   - expliquer que l’app appelle le backend réel.

2. **Tableau de bord**
   - prochain cours ;
   - devoirs ;
   - tâches ;
   - annonce épinglée.

3. **Planning**
   - montrer la vue jour/semaine ;
   - ajouter ou modifier un cours ;
   - expliquer que tout élève approuvé peut corriger.

4. **Agenda**
   - montrer devoirs de classe ;
   - montrer tâches École / Entreprise ;
   - créer une tâche rapide.

5. **Alternances**
   - rechercher une offre ;
   - sauvegarder une recherche ;
   - montrer les favoris ou l’entraide de classe.

6. **Profil / Délégué**
   - montrer le code classe ;
   - montrer les demandes d’adhésion ;
   - montrer la liste des membres ;
   - expliquer que le rôle délégué reste limité.

7. **Sécurité**
   - laisser Garance enchaîner sur ce qui protège ces parcours.

## 10. Commandes de démo

Terminal 1 :

```bash
cd /Users/gab/Documents/studentflow

open -a Docker
docker compose up -d postgres

dotnet run --project src/backend/StudyFlow.Api \
  --urls http://0.0.0.0:5028
```

Terminal 2 :

```bash
cd /Users/gab/Documents/studentflow
./scripts/run_iphone_developer.sh
```

Si iOS recasse le codesign :

```bash
./scripts/run_iphone_developer.sh --clean
```

Test backend :

```bash
curl http://localhost:5028/api/status
```

## 11. Ce que Gabriel peut dire techniquement

### Flutter

> L’app est organisée par fonctionnalités : auth, classes, planning, agenda, alternances, entreprise, profil. Chaque fonctionnalité sépare les modèles, les repositories et l’interface, ce qui évite de mélanger toute la logique dans les écrans.

### Backend

> Le backend expose une API REST en ASP.NET Core. Entity Framework Core permet de travailler avec des entités C# et des migrations vers PostgreSQL.

### Alternances

> Les offres ne sont pas appelées directement depuis Flutter. Le backend joue le rôle d’intermédiaire pour protéger les clés API et normaliser les résultats.

### Démo locale

> Pour la soutenance, nous lançons le backend et PostgreSQL en local. C’est volontaire : cela permet de démontrer une vraie communication app/backend/base sans payer un hébergement de production.

## 12. Ce que Garance peut dire techniquement

### Authentification

> Les mots de passe ne sont jamais stockés en clair. ASP.NET Identity stocke un hash. L’utilisateur reçoit un access token JWT court et un refresh token opaque.

### JWT

> Le JWT est minimal : il contient seulement l’identifiant utilisateur, le security stamp et les rôles. Les informations personnelles ne sont pas copiées dans le token.

### Refresh tokens

> Les refresh tokens sont stockés sous forme de HMAC, pas en clair. En cas de renouvellement, ils sont tournés. Après reset password, les refresh tokens actifs sont révoqués.

### Données sensibles

> Les noms de professeurs, salles, horaires précis, événements personnels et tokens techniques sont chiffrés ou hashés selon leur usage.

### Isolation par classe

> Les routes scolaires récupèrent la classe depuis l’utilisateur connecté. Le client ne choisit jamais librement un `classId` pour lire des données.

### Durcissement HTTP

> Le backend limite CORS, ajoute des headers de sécurité et applique un rate limiting sur les routes sensibles d’authentification.

## 13. Problèmes rencontrés à raconter

Cette partie est importante : elle montre que vous n’avez pas seulement assemblé des écrans, mais que vous avez réellement construit, testé et corrigé un système.

| Problème rencontré | Ce que ça a bloqué | Solution apportée | Ce que ça montre au jury |
| :--- | :--- | :--- | :--- |
| L’iPhone ne pouvait pas joindre `localhost` | L’app marchait côté Mac, mais pas sur téléphone réel | Utilisation de l’IP locale du Mac et script `run_iphone_developer.sh` | Compréhension réseau client/serveur |
| Codesign iOS cassé par des attributs macOS | Flutter échouait au build sur iPhone | Copie propre dans `/Users/gab/Developer`, nettoyage `xattr`, option `--clean` | Capacité à diagnostiquer un problème d’environnement |
| Mode démo trop visible | L’app donnait l’impression d’une simple maquette | Seeder réaliste, backend réel, comptes, classe, cours, devoirs, élèves | Passage d’une maquette à un MVP testable |
| Données sensibles scolaires | Risque d’exposer professeurs, salles, horaires | Chiffrement, isolation par classe, JWT minimal, DataProtection persistée | Prise en compte de la confidentialité |
| Alternances multi-sources | Les APIs externes ont des formats et clés différents | Backend agrégateur qui normalise les offres | Architecture extensible |
| Design sombre peu lisible | Certaines cartes étaient belles mais difficiles à lire | Revue des contrastes en dark mode sans casser le thème clair | Attention à l’ergonomie |
| Parcours classe/délégué ambigu | Qui peut voir quoi ? Qui valide qui ? | Code classe + demande d’approbation + rôle délégué limité | Modélisation métier cohérente |
| Reset password sans e-mail en local | Impossible de tester sans service SMTP | Code renvoyé seulement en développement, hashé en base | Séparation dev/prod |

Phrase possible :

> Ce qui nous a le plus appris, ce n’est pas seulement coder les écrans. C’est de faire fonctionner ensemble Flutter, un téléphone réel, une API locale, PostgreSQL, Docker, Xcode, les migrations et la sécurité.

## 14. Choix techniques à justifier

### Flutter

Pourquoi c’est cohérent :

- une seule base de code pour Android, iOS et Web ;
- très adapté à une petite équipe ;
- permet une interface riche et proche des maquettes ;
- utile pour tester rapidement sur émulateur puis iPhone réel.

Limite à assumer :

> Flutter accélère le développement multi-plateforme, mais demande quand même de comprendre les spécificités iOS et Android, surtout pour les permissions, les notifications et le build.

### ASP.NET Core

Pourquoi c’est cohérent :

- framework solide pour créer une API REST ;
- bon support de l’authentification avec Identity ;
- facile à structurer en plusieurs couches ;
- compatible avec EF Core et PostgreSQL.

Limite à assumer :

> ASP.NET Core apporte beaucoup de sécurité et de structure, mais il faut faire attention à la configuration : secrets, CORS, JWT, DataProtection, migrations.

### PostgreSQL et EF Core

Pourquoi c’est cohérent :

- données très relationnelles : classes, utilisateurs, rôles, cours, devoirs ;
- migrations pour suivre l’évolution du modèle ;
- cohérent pour un projet qui doit garder une vraie intégrité de données.

Phrase possible :

> EF Core nous a permis de faire évoluer la base progressivement. À chaque fois que le modèle changeait, on pouvait créer une migration et garder un historique clair.

### Docker

Pourquoi c’est cohérent :

- lance PostgreSQL facilement ;
- évite d’installer/configurer une base à la main ;
- rend la démo plus reproductible.

Phrase possible :

> Docker ne sert pas à faire joli dans le projet : il nous permet d’avoir une base PostgreSQL locale stable, relançable, et plus proche d’un vrai environnement serveur.

## 15. Ce qu’il faut absolument montrer en démo

Si le temps est court, privilégier ces éléments :

1. connexion avec un compte seedé ;
2. tableau de bord avec annonce, prochain cours et devoirs ;
3. planning jour/semaine ;
4. ajout ou modification d’un cours ;
5. agenda avec séparation École / Entreprise ;
6. recherche d’alternance ;
7. profil délégué : code classe, membres, demandes ;
8. explication rapide de la sécurité.

Si quelque chose casse pendant la démo :

- ne pas paniquer ;
- expliquer que le projet dépend d’un backend local, Docker et un téléphone réel ;
- passer sur les captures préparées ;
- montrer le code ou les docs pour prouver l’implémentation.

Phrase de secours :

> Comme la démonstration dépend d’un environnement local complet, on a aussi préparé des captures et une documentation de lancement. Le plus important est que l’architecture et les parcours soient déjà implémentés.

## 16. Questions probables du jury

### Pourquoi Flutter ?

Réponse :

> Flutter permet de développer une application mobile Android/iOS avec une seule base de code. Pour une petite équipe de deux personnes, c’est plus réaliste que maintenir deux applications natives.

### Pourquoi ASP.NET Core ?

Réponse :

> ASP.NET Core est robuste, bien adapté aux APIs REST, et s’intègre bien avec Entity Framework Core et Identity pour l’authentification.

### Pourquoi PostgreSQL ?

Réponse :

> Les données sont relationnelles : utilisateurs, classes, cours, devoirs, rôles, demandes d’adhésion. PostgreSQL permet de garder cette structure proprement.

### Pourquoi ne pas avoir fait une vraie production ?

Réponse :

> La production nécessite HTTPS public, hébergement, sauvegardes, SMTP, monitoring, politique de secrets et distribution App Store/Play Store. Pour le projet annuel, nous avons priorisé un MVP local fonctionnel et démontrable.

### Qu’est-ce qui est le plus professionnel dans le projet ?

Réponse :

> L’architecture séparée, l’authentification réelle, la base PostgreSQL, les migrations, la sécurité des données sensibles, les tests et la documentation.

### Quelles sont les limites ?

Réponse :

> L’app n’est pas encore publiée, les notifications push serveur ne sont pas finalisées, l’envoi e-mail réel du reset password reste à brancher, et les sources alternance doivent être validées juridiquement avant une ouverture publique.

### Pourquoi avoir fait un seed ?

Réponse :

> Le seed permet d’avoir une démonstration stable. À chaque lancement de développement, on peut retrouver une classe avec des élèves, un délégué, des cours, des devoirs et une demande d’approbation. C’est plus fiable que de tout créer à la main avant chaque présentation.

### Pourquoi ne pas appeler directement les APIs alternance depuis Flutter ?

Réponse :

> Parce que les clés API ne doivent pas être embarquées dans l’application mobile. En passant par le backend, on protège les clés, on normalise les réponses et on peut changer ou ajouter une source sans mettre à jour toute l’app.

### Pourquoi `localhost` ne marche pas depuis l’iPhone ?

Réponse :

> Sur l’iPhone, `localhost` désigne l’iPhone lui-même, pas le Mac. Pour joindre le backend qui tourne sur le Mac, l’app doit utiliser l’adresse IP locale du Mac sur le Wi-Fi.

### Pourquoi utiliser Docker pour PostgreSQL ?

Réponse :

> Docker rend l’environnement plus reproductible. On peut lancer PostgreSQL avec une commande, sans dépendre d’une installation locale différente sur chaque machine.

### Pourquoi ne pas donner tous les droits au délégué ?

Réponse :

> Le but du projet est l’autosuffisance. Le délégué gère l’accès et les informations officielles, mais il ne valide pas chaque cours ou devoir. Les élèves approuvés restent responsables de l’organisation quotidienne.

### Est-ce que les professeurs ont un compte ?

Réponse :

> Non, c’est volontairement hors périmètre. StudyFlow est pensé comme un outil étudiant. Les professeurs sont seulement des informations associées aux cours, pas des utilisateurs de l’application.

### Pourquoi le projet n’est-il pas encore prêt pour une vraie production ?

Réponse :

> Pour être réellement en production, il faudrait un hébergement HTTPS stable, des sauvegardes automatiques, un SMTP réel pour les e-mails, une politique de rotation des secrets, du monitoring, des tests plus complets et une validation des conditions d’utilisation des APIs externes.

### Qu’est-ce que vous avez appris techniquement ?

Réponse possible pour Gabriel :

> J’ai appris à relier une app Flutter à un backend réel, à gérer les environnements, à tester sur iPhone, à structurer les écrans et à transformer une maquette en application fonctionnelle.

Réponse possible pour Garance :

> J’ai travaillé sur la sécurité applicative : mots de passe hashés, JWT, refresh tokens, isolation des données, chiffrement, CORS, rate limiting et documentation des limites.

## 17. À préparer avant l’oral

- vérifier que Docker Desktop démarre ;
- vérifier que `curl http://localhost:5028/api/status` répond ;
- vérifier que l’iPhone lance l’app ;
- préparer des captures au cas où la démo live bloque ;
- décider qui parle sur chaque slide ;
- chronométrer une première répétition ;
- garder le mot de passe seedé sous la main : `Password1234!`.
- préparer une capture de chaque écran important ;
- préparer une capture du terminal backend avec le seed ;
- préparer une capture de la base ou des migrations si besoin ;
- préparer une slide “limites et suite” honnête.

## 18. Répartition orale conseillée

### Gabriel — environ 60 %

Gabriel peut porter :

- contexte et besoin ;
- choix produit ;
- navigation dans l’application ;
- démonstration live ;
- difficultés Flutter/iPhone/backend ;
- perspectives produit.

### Garance — environ 40 %

Garance peut porter :

- sécurité ;
- authentification ;
- protection des données ;
- rôles et isolation par classe ;
- choix backend liés à la confidentialité ;
- limites avant production.

Transition naturelle :

> Je viens de montrer comment l’app fonctionne côté utilisateur. Garance va maintenant expliquer comment on protège ces parcours côté backend, parce que ce point est essentiel pour une application qui manipule des données de classe.

## 19. Ce qu’il faut éviter de dire

À éviter :

- “L’application est prête pour l’App Store” ;
- “Tout est sécurisé à 100 %” ;
- “Il n’y a plus rien à faire” ;
- “C’est juste une démo” ;
- “On a juste utilisé Flutter et une API”.

À dire plutôt :

- “C’est un MVP fonctionnel avancé” ;
- “La base est prête pour une phase de pré-production” ;
- “La sécurité a été prise en compte, mais une revue finale serait nécessaire avant ouverture publique” ;
- “La démo utilise une vraie API et une vraie base locale” ;
- “Le projet couvre tout le cycle : produit, design, mobile, backend, données, sécurité et documentation”.

## 20. Message final à faire passer

> StudyFlow est un projet complet, pas seulement une maquette. Il relie une application Flutter, une API ASP.NET Core, une base PostgreSQL, une authentification réelle et une réflexion sécurité. Le projet répond à un besoin concret d’organisation de classe et pose une base crédible pour une future V1.
