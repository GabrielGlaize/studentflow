# Maquettes Figma

- Fichier de travail : [StudyFlow Pro — MVP](https://www.figma.com/design/ecUTTTa55gZ59MYblQzmKb)
- Design system retenu : Material 3 Design Kit
- Cibles : Flutter Android et Flutter Web responsive
- État : parcours MVP maquettés, repris dans Flutter et vérifiés localement ; intégration Figma à reprendre lorsque le quota le permettra

## Prototype Web local

En attendant la reprise des écritures Figma, une maquette responsive révisable a été créée dans [`design/alternances-web`](../design/alternances-web/).

Elle couvre :

- la page publique de recherche et de résultats ;
- les filtres ordinateur et leur adaptation mobile ;
- les cartes d’offres et de candidatures spontanées ;
- la fiche détaillée d’une opportunité ;
- une action de candidature persistante sur smartphone.

Une seconde maquette locale est disponible dans [`design/app-mobile`](../design/app-mobile/) :

- tableau de bord élève ;
- annonce importante épinglée ;
- prochain cours avec salle et professeur ;
- devoirs, projets et tâches personnelles ;
- résumé des nouvelles alternances ;
- navigation mobile à cinq destinations ;
- emploi du temps hebdomadaire collaboratif ;
- cours modifiés, annulés et ajout rapide d’un cours.
- agenda interactif avec distinction devoir collectif et tâche personnelle ;
- bascule École/Entreprise ;
- missions, échéances et ressources importantes de l’entreprise.
- création d’une tâche personnelle École ou Entreprise ;
- rappels, priorité et rattachement facultatif à un cours ;
- ajout collaboratif d’un cours ;
- récurrence hebdomadaire et contrôle de conflit.
- fil d’informations importantes sans chat ;
- annonces épinglées et publication réservée aux délégués ;
- gestion du code, des membres, matières, professeurs et délégués ;
- profil, thème, notifications et bascule Alternances/Entreprise.

Depuis la maquette, l’application Flutter a aussi intégré le lancement iPhone, les états sombres lisibles, la réinitialisation de mot de passe, les documents/contacts Entreprise et les corrections de sécurité backend.
- connexion et création de compte sans appartenance obligatoire à une classe ;
- choix d'entrée entre recherche d'alternance et vie de classe ;
- saisie facultative du code, prévisualisation puis adhésion à la classe.

## Écrans prioritaires couverts

1. Recherche publique d’alternances — ordinateur
2. Recherche publique d’alternances — smartphone
3. Résultats d’alternances
4. Détail partageable d’une offre
5. Connexion ou création de compte sans classe
6. Accueil élève
7. Calendrier hebdomadaire
8. Agenda avec bascule École/Entreprise
9. Création d’une tâche
10. Création collaborative d’un cours
11. Fil d’informations et annonce épinglée
12. Gestion de classe du délégué
13. Profil et réglages
14. Choix du parcours après inscription
15. Rejoindre une classe avec un code
16. Créer une classe et devenir premier délégué
17. Attente d’approbation et traitement par un délégué
18. Planning et agenda Alternance sans classe
19. Canal d’entraide et partage d’offres
20. Espace Entreprise avec événements, tâches et ressources

Les parcours, contenus et règles responsive sont définis dans [ARBORESCENCE_ECRANS.md](./ARBORESCENCE_ECRANS.md).

La navigation et les interactions du prototype ont été vérifiées dans [RECETTE_MAQUETTE.md](./RECETTE_MAQUETTE.md).

Les écrans 16 à 20 correspondent à l’évolution validée après la première recette. Ils doivent être intégrés lors de la prochaine itération visuelle avant la recette finale.

## État de l’intégration Figma

La bibliothèque Material 3 est liée au fichier. Les premiers composants identifiés sont notamment les boutons, la barre de recherche, les barres de navigation, les rails de navigation et les styles de titres.

La génération automatisée des maquettes est temporairement limitée par le quota d’appels du plan Figma Starter. Aucun écran incomplet n’a été écrit dans le fichier. Les prototypes HTML locaux constituent la référence visuelle validée avant l'implémentation Flutter.
