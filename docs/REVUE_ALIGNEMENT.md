# Revue d’alignement produit et maquettes

Dernière revue : 4 juillet 2026.

Ce document sert de garde-fou entre trois sources :

- le cahier des charges ;
- les maquettes HTML du dossier `design/` ;
- l’application Flutter actuelle.

## Ce qui est bien aligné

- L’app mobile reprend la navigation principale voulue : Accueil, Planning, Agenda, Alternances ou Entreprise, Profil.
- Le rôle délégué reste léger : code de classe, demandes d’adhésion, informations communes, matières et professeurs.
- Les élèves gardent l’autosuffisance sur les cours, devoirs et tâches : l’objectif n’est pas de bloquer derrière une validation.
- L’onglet Alternances contient la recherche, les recherches sauvegardées, les favoris et l’entraide de classe.
- L’espace Entreprise conserve maintenant un accès secondaire aux outils Alternances, pour éviter de couper l’utilisateur de la recherche et de l’entraide.
- Le mode futur élève sans classe dispose d’un agenda et d’un planning personnel pour organiser candidatures, entretiens et relances.
- Le Web public Alternances peut appeler l’API publique puis utiliser un fallback de démonstration si le backend n’est pas disponible.
- Les notifications locales natives sont branchées côté Flutter pour les rappels calculés.
- Le backend d’alternance peut agréger La Bonne Alternance, Adzuna et France Travail selon les clés configurées.
- Le lancement iPhone est automatisé par `scripts/install_app.sh` pour éviter les erreurs récurrentes de codesign liées aux attributs macOS.
- La sécurité backend est alignée avec les remarques de revue : DataProtection persistée, clés locales dans `.env`, CORS limité, rate limiting auth, headers HTTP et mot de passe avec caractère spécial.
- La palette, les cartes arrondies, les états vides, les badges et les chargements utilisent la direction artistique du prototype HTML.

## Petites corrections intégrées après revue

- Ajout d’un bouton pour copier rapidement le code de classe côté délégué.
- Ajout d’une entrée “Recherche et entraide alternance” dans l’espace Entreprise.
- Ajout d’un retour explicite depuis les outils Alternances vers l’espace Entreprise.
- Ajout des événements personnels dans l’agenda.
- Ajout des conflits de cours, de l’historique et de la restauration du dernier état.
- Ajout de la gestion délégué des membres : retirer un élève, nommer un autre délégué, quitter son propre rôle.
- Branchement de la page publique Alternances sur `/api/v1/public/alternances`.
- Branchement du scheduler natif `flutter_local_notifications`.
- Ajout de la réinitialisation de mot de passe côté API.
- Ajout du mot de passe seedé renforcé : `Password1234!`.
- Mise à jour de la recette de maquette avec ces comportements.

## Écarts à décider avant gros développement

Ces points changent davantage le produit ou le temps de développement. Ils ne sont donc pas modifiés automatiquement.

### 1. Cours récurrents

Le cours répété chaque semaine n’est pas retenu pour l’instant. Les conflits horaires et l’historique/restauration sont, eux, intégrés.

Décision : ne pas développer les cours récurrents maintenant.

### 2. Suppression du rôle délégué d’un autre élève

Un délégué peut nommer un autre délégué et quitter son propre rôle. Il ne peut pas retirer le rôle délégué d’un autre élève.

Décision : ne pas ajouter cette action, pour éviter les conflits de pouvoir dans la classe.

### 3. Agenda personnel pour futur élève sans classe

Le concept prévoit qu’un futur élève puisse utiliser l’emploi du temps et l’agenda pour gérer sa recherche d’alternance avant d’être dans une classe. Les événements personnels sont maintenant disponibles dans l’agenda.

Suite possible : afficher ces événements aussi dans l’écran Planning, pas seulement dans l’Agenda.

### 4. Web public alternance final

Les maquettes web publiques existent pour les futurs élèves. La page de recherche appelle maintenant l’API publique et affiche un fallback de démonstration si le backend n’est pas lancé.

Suite possible : créer une vraie fiche détail dynamique par offre.

### 5. Notifications natives

Le planificateur de rappels existe, les préférences sont visibles et le scheduler natif Flutter est branché.

Suite possible : stabiliser les tests sur vrai iPhone, puis ajouter de vraies notifications push serveur si le projet est mis en production.

### 6. Sécurité production

Le MVP local est mieux protégé, mais une production nécessiterait encore un serveur HTTPS, un SMTP réel pour la réinitialisation de mot de passe, une rotation des clés, des sauvegardes automatiques et du monitoring.

## Priorité proposée

Pour rester cohérent avec ton idée et avec une soutenance étudiante, l’ordre le plus rentable est :

1. figer le scénario de démonstration ;
2. tester backend + iPhone avec le script automatisé ;
3. préparer les captures finales ;
4. préparer le support oral Gabriel/Garance ;
5. garder les améliorations production comme perspectives, pas comme promesse de MVP.
