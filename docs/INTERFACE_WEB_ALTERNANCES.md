# Interface Web publique — Alternances

## 1. Objectif

L’interface Web permet à toute personne, notamment un futur élève, de rechercher une alternance sans installer StudyFlow, sans posséder de compte et sans appartenir à une classe.

Elle constitue une porte d’entrée publique vers StudyFlow, distincte des fonctionnalités scolaires privées.

## 2. Publics

- visiteur anonyme recherchant une alternance ;
- futur élève souhaitant sauvegarder ses recherches avant son inscription ;
- futur élève utilisant son planning et son agenda personnels pour organiser ses démarches ;
- élève StudyFlow déjà rattaché à une classe ;
- utilisateur sur smartphone ou ordinateur.

## 3. Pages du MVP

### Accueil et recherche

- présentation courte du service ;
- métier avec suggestions basées sur le référentiel ROME ;
- ville ou code postal ;
- rayon de recherche ;
- bouton de recherche ;
- accès facultatif à la connexion et à la création de compte.

Implémentation actuelle : `design/alternances-web/index.html` appelle `/api/v1/public/alternances` via `prototype.js`. Si le backend n’est pas lancé ou refuse l’appel, la page affiche automatiquement des résultats de démonstration pour rester présentable.

La route publique est servie par le backend StudyFlow. Celui-ci peut ensuite interroger La Bonne Alternance, Adzuna et France Travail selon les clés configurées. Les clés restent côté serveur et ne sont jamais exposées dans le JavaScript public.

### Résultats

- rappel des critères ;
- filtres disponibles ;
- nombre de résultats lorsque fourni ;
- cartes d’offres ou de candidatures spontanées ;
- pagination ou chargement progressif ;
- tri fourni ou permis par la source ;
- message adapté lorsqu’aucun résultat n’est trouvé.

### Détail d’une opportunité

- intitulé ;
- entreprise ;
- localisation et distance ;
- type de contrat ;
- niveau de diplôme visé ;
- description ;
- date de publication ou d’expiration ;
- bouton vers la candidature d’origine ;
- ajout aux favoris pour un utilisateur connecté ;
- URL partageable.

### Compte facultatif

- création de compte sans code de classe ;
- connexion ;
- favoris synchronisés ;
- recherches sauvegardées ;
- alertes sur de nouvelles opportunités ;
- possibilité de rejoindre une classe ultérieurement.
- possibilité de créer sa propre classe et de devenir automatiquement son premier délégué ;
- accès au canal d’entraide après rattachement et approbation dans une classe.

### Pages obligatoires

- mentions légales ;
- politique de confidentialité ;
- conditions d’utilisation ;
- déclaration ou informations d’accessibilité ;
- attribution claire de la source La bonne alternance.

## 4. Parcours

```text
Recherche publique
      |
      v
Résultats ----> Nouvelle recherche
      |
      v
Détail de l’offre ----> Site de candidature
      |
      +----> Connexion facultative ----> Favori ou alerte
```

Le code de classe n’apparaît jamais dans le parcours principal d’alternance. Il reste accessible depuis le profil d’un utilisateur qui souhaite rejoindre la partie scolaire.

La saisie d’un code crée une demande en attente. Tant qu’un délégué ne l’a pas approuvée, l’utilisateur ne voit ni messages d’entraide, ni cours, ni professeur, ni horaire de la classe.

## 5. Espace connecté autour de l’alternance

Après connexion, un utilisateur sans classe dispose de :

- son agenda de candidatures et relances ;
- son planning d’entretiens et rendez-vous ;
- ses favoris, recherches et alertes.

Un membre approuvé dispose en plus d’un canal `Entraide` privé à sa classe pour publier un message court et partager un lien d’offre. Ce canal n’est jamais indexé publiquement.

## 6. Responsive

### Smartphone

- formulaire sur une colonne ;
- filtres dans un panneau ;
- cartes compactes ;
- action de candidature toujours facilement accessible ;
- aucune installation proposée comme obligation.

### Ordinateur

- contenu centré ;
- filtres dans une colonne latérale ;
- liste de résultats plus dense ;
- détail lisible avec largeur de texte limitée.

## 7. États à prévoir

- chargement ;
- aucun résultat ;
- paramètres invalides ;
- API La bonne alternance indisponible ;
- quota temporairement atteint ;
- offre expirée ou supprimée ;
- connexion perdue ;
- favori déjà enregistré.

## 8. Sécurité et protection

- les jetons de La bonne alternance restent uniquement sur le backend ;
- limitation des recherches publiques par adresse IP ;
- validation de tous les paramètres ;
- cache court des recherches identiques ;
- aucune donnée scolaire exposée sur les routes publiques ;
- collecte minimale de données personnelles ;
- consentement explicite pour les alertes par e-mail ou notification.

## 9. Référencement et technologie

Flutter Web permet de partager une grande partie du code de présentation et convient pour une démonstration ou un accès par lien direct.

Si l’objectif devient d’attirer des visiteurs depuis les moteurs de recherche, les pages publiques devront bénéficier d’un rendu HTML indexable, de titres et descriptions par page, d’URL partageables et de bonnes performances initiales. Deux trajectoires sont possibles :

1. conserver Flutter Web pour le MVP et ajouter plus tard une façade publique optimisée pour le référencement ;
2. créer dès le départ la façade publique avec une technologie Web rendue côté serveur, tout en conservant Flutter pour l’application mobile.

Pour une équipe de deux, la première trajectoire reste la plus raisonnable tant que le référencement n’est pas un critère de réussite immédiat.

## 10. Mesure facultative

Des statistiques anonymisées pourront mesurer :

- les recherches effectuées ;
- les recherches sans résultat ;
- les ouvertures d’offres ;
- les redirections vers une candidature.

Elles ne sont pas indispensables au MVP et nécessitent une configuration respectueuse de la vie privée.
