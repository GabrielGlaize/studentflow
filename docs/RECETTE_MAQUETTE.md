# Recette de la maquette

Dernière vérification : 4 juillet 2026.

## Parcours validés

- connexion, création de compte et restauration de session ;
- affichage/masquage du mot de passe ;
- réinitialisation de mot de passe côté API avec code temporaire hashé ;
- création d’un compte sans classe avec code de classe optionnel ;
- création d’une classe avec création simultanée du compte délégué ;
- choix entre la recherche d’alternance, l’usage sans classe et la création d’une classe ;
- validation et normalisation du code de classe ;
- navigation complète entre accueil, emploi du temps, agenda, alternances et profil ;
- création, modification et suppression de cours ;
- détection de conflit horaire lors de la création/modification d’un cours ;
- consultation de l’historique d’un cours et restauration du dernier état ;
- création, modification et suppression de devoirs de classe ;
- création d’une tâche École, Alternance ou Entreprise et réglage du rappel ;
- création, modification et suppression d’un événement personnel d’alternance ou d’entreprise ;
- tâches terminées et filtres À faire/Terminés ;
- bascule École/Entreprise sans perte de cohérence du filtre ;
- annonces épinglées, fil officiel et accès à la gestion de classe ;
- affichage, modification et renouvellement du code de classe côté délégué ;
- copie rapide du code de classe côté délégué ;
- approbation et refus des demandes d’adhésion ;
- liste des membres, retrait d’un élève, nomination d’un autre délégué et retrait de son propre rôle délégué ;
- mode Entreprise, nom d’entreprise, thème sombre et préférences de notification ;
- accès secondaire aux outils Alternances depuis l’espace Entreprise ;
- prévisualisation des rappels prévus selon les préférences de notification ;
- sauvegarde et relance d’une recherche alternance ;
- ajout et retrait d’une offre alternance en favori ;
- filtrage backend des cours, devoirs, annonces et messages supprimés logiquement ;
- états de chargement, erreur et vide harmonisés sur les écrans principaux ;
- lignes de réglages cliquables entièrement pour améliorer l’usage mobile ;
- recherche publique, recherches populaires, filtres mobiles et réinitialisation ;
- recherche publique branchée sur `/api/v1/public/alternances` avec fallback de démonstration ;
- chargement de résultats et fiche détaillée d’une offre ;
- entraide alternance privée de classe ;
- agrégation backend de sources alternance : La Bonne Alternance, Adzuna et France Travail selon configuration ;
- notifications locales natives branchées côté Flutter avec `flutter_local_notifications` ;
- lancement iPhone automatisé via `scripts/run_iphone_developer.sh` ;
- durcissement sécurité backend : CORS limité, rate limiting auth, headers HTTP, DataProtection persistée et politique de mot de passe renforcée.

## Responsive vérifié

- les 11 écrans mobiles ont été contrôlés à 390 × 844 px sans débordement horizontal ;
- les 2 écrans publics d’alternances ont été contrôlés à 390 × 844 px et 1366 × 900 px ;
- les scripts interactifs sont chargés sur tous les écrans.

## Limites volontaires du prototype

Le mode démo permet encore de tester sans backend. En mode API réelle, les écrans Flutter sont branchés via `dart-define` sur les routes d’authentification, classes, cours, devoirs, annonces, préférences et alternances.

## Évolution à intégrer dans la prochaine recette

- alertes alternance et filtres de recherche plus avancés ;
- captures finales des écrans Flutter ;
- tests de bout en bout avec backend, base PostgreSQL et app mobile ;
- revue production : HTTPS public, SMTP réel, sauvegardes, rotation des clés et monitoring.
