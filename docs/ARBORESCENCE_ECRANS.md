# Arborescence des écrans du MVP

Cette arborescence prépare les maquettes Flutter Android et Web.

## 1. Navigation publique Web

```text
StudyFlow
├── Accueil Alternances
├── Résultats de recherche
├── Détail d’une offre
├── Connexion et création de compte
├── Créer ma classe
├── Favoris et recherches sauvegardées
├── Rejoindre une classe plus tard
└── Mentions légales et confidentialité
```

La recherche d’alternances est un véritable parcours Web public autonome, destiné aussi aux futurs élèves sans classe. Sur ordinateur, les filtres restent visibles dans une colonne latérale. Sur smartphone, ils s’ouvrent dans un panneau.

## 2. Navigation élève mobile

La navigation principale utilise cinq destinations :

```text
Tableau de bord | Planning | Agenda | Alternances ou Entreprise | Profil
```

Le profil et les réglages constituent la dernière destination de la navigation principale.

### Tableau de bord

- prochain cours ;
- horaire et salle du prochain cours ;
- devoirs et projets à rendre prochainement ;
- tâches personnelles à faire ;
- annonces épinglées des délégués ;
- prochaines échéances de la journée ou de la semaine ;
- résumé Alternance ou Entreprise si cela reste lisible.

### Planning

- vue personnelle disponible même sans classe ;
- événements de candidature, entretien, relance ou entreprise ;
- vue du jour ;
- vue de la semaine ;
- détail d’un cours ;
- état modifié ou annulé ;
- ajout ou correction collaborative d’un cours.
- correction immédiate par tout élève approuvé, sans validation du délégué.

### Agenda et tâches

- onglet `Ecole` : devoirs, projets et tâches scolaires ;
- onglet `Alternance` : candidatures, relances et entretiens, disponible sans classe ;
- onglet `Entreprise` : tâches et échéances professionnelles ;
- filtre `Collectif` ou `Personnel` lorsque nécessaire ;
- filtres à faire et terminés ;
- détail d’un devoir ;
- création et modification d’une tâche personnelle.

### Alternances ou Entreprise

L’intitulé et le contenu principal dépendent du réglage `J’ai une entreprise`.

Mode `Alternances` :

- recherche et suggestions de métiers ;
- localisation et rayon ;
- résultats ;
- détail d’une opportunité ;
- favoris ;
- recherches sauvegardées.
- section `Entraide` : messages et offres partagés uniquement au sein de la classe.

Mode `Entreprise` :

- tâches et échéances professionnelles ;
- événements et rendez-vous professionnels ;
- liens importants, sans stockage de fichiers dans le MVP ;
- informations utiles sur le contrat ;
- contacts ou ressources fréquentes.
- accès secondaire à la recherche et à l’entraide alternance.

### Profil et réglages

- identité et classe ;
- thème clair, sombre ou système ;
- réglage `J’ai une entreprise` ;
- préférences de notifications ;
- délai du rappel avant un cours ;
- vue calendrier et filtres par défaut ;
- masquage des tâches terminées ;
- mise en sourdine des annonces non épinglées ;
- options d’accessibilité ;
- gestion de la session ;
- confidentialité ;
- suppression du compte, si activée dans le MVP final.

### Informations de la classe

- fil d’annonces officielles publiées par les délégués ;
- annonces épinglées en tête ;
- accès depuis le tableau de bord ou une destination dédiée selon la priorité retenue ;
- aucun chat généraliste, les discussions restant sur Discord ; le canal `Entraide` est séparé et limité aux offres d’alternance.

## 3. Navigation délégué

Un délégué possède exactement la même navigation principale qu’un élève. Une entrée `Gestion de la classe` est ajoutée dans son profil.

```text
Gestion de la classe
├── Informations générales
├── Code de la classe
│   ├── Copier ou partager
│   └── Renouveler
├── Matières
│   ├── Liste
│   └── Ajouter, corriger ou archiver
├── Professeurs
│   ├── Liste
│   └── Ajouter, corriger ou archiver
├── Membres
│   ├── Demandes en attente
│   ├── Approuver ou refuser
│   ├── Retirer de la classe
│   └── Nommer ou retirer un délégué
└── Annonces
    ├── Publier
    ├── Épingler
    └── Archiver
```

Ces fonctions restent disponibles sur mobile et Web, sans créer un espace d’administration séparé.

## 4. États transversaux à maqueter

Chaque fonctionnalité importante doit prévoir :

- chargement initial ;
- liste vide ;
- erreur récupérable ;
- absence de connexion ;
- action réussie ;
- confirmation avant suppression ;
- accès interdit ;
- adhésion en attente ou refusée ;
- source d’alternances indisponible.

## 5. Maquettes prioritaires

Les maquettes de référence doivent couvrir ces écrans :

1. recherche publique d’alternances sur ordinateur ;
2. recherche publique d’alternances sur smartphone ;
3. résultats et détail d’une offre ;
4. connexion ;
5. accueil élève ;
6. calendrier de la semaine ;
7. agenda avec bascule École/Entreprise ;
8. création d’une tâche personnelle ;
9. création collaborative d’un cours ;
10. fil d’informations avec annonce épinglée ;
11. gestion de classe pour un délégué.
12. création d’une classe et attribution automatique du rôle délégué ;
13. demandes d’adhésion à approuver ;
14. planning Alternance sans classe ;
15. canal d’entraide alternance ;
16. espace Entreprise avec événements, tâches et ressources.

## 6. Règles responsive

- moins de 600 px : présentation mobile sur une colonne ;
- de 600 à 1023 px : présentation tablette ;
- à partir de 1024 px : présentation ordinateur avec contenu centré et panneaux latéraux lorsque pertinent ;
- largeur de lecture limitée pour les longs textes ;
- aucune action essentielle disponible uniquement au survol ;
- zones tactiles suffisamment grandes sur smartphone ;
- navigation au clavier et ordre de focus cohérent sur le Web.

Ces seuils sont des valeurs de départ et devront être validés visuellement pendant l’implémentation.

## 7. Composants partagés envisagés

- barre de recherche métier ;
- sélecteur de localisation ;
- puce de filtre ;
- carte d’offre ;
- carte de cours ;
- carte de devoir ;
- état vide ;
- message d’erreur ;
- bouton principal ;
- champ de formulaire ;
- dialogue de confirmation ;
- navigation mobile ;
- navigation latérale Web.
