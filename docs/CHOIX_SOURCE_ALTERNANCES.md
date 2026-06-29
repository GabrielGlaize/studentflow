# Choix de la source d’offres d’alternance

> Décision du 22 juin 2026 — à revalider avant la mise en production

## 1. Source retenue

La source unique retenue pour le MVP est l’[API La bonne alternance](https://api.apprentissage.beta.gouv.fr/fr/explorer/recherche-offre), service public porté par la Mission interministérielle pour l’apprentissage.

Cette source est particulièrement adaptée à StudyFlow car elle :

- centralise des offres déposées sur La bonne alternance et des offres de partenaires ;
- expose aussi des entreprises susceptibles de recruter pour des candidatures spontanées ;
- couvre le territoire français ;
- fournit des critères ROME, RNCP, géographiques, de niveau de diplôme et de rayon ;
- fournit les informations de redirection ou de candidature disponibles ;
- est mise à jour quotidiennement ;
- propose une API documentée et un widget de secours.

## 2. Conditions et limites connues

- Un compte développeur et un jeton d’accès sont nécessaires.
- L’utilisation annoncée est gratuite pour les usages non lucratifs.
- La revente des données ou la facturation de leur accès est interdite.
- Les quotas indiqués varient selon les routes, actuellement entre 5 et 20 appels par seconde.
- Le service public affiche un taux de disponibilité qui n’est pas de 100 % ; StudyFlow doit donc gérer les indisponibilités.
- Les clés et jetons de l’API ne doivent jamais être intégrés dans Flutter.

StudyFlow étant un projet de démonstration au service d’une classe et sans monétisation des offres, son usage prévu est cohérent avec la restriction non lucrative. Les conditions devront être relues si le projet devient commercial.

## 3. Mode d’intégration

```text
Flutter Android ou Web
          |
          v
API publique StudyFlow
          |
          +--> cache court
          |
          +--> adaptateur LaBonneAlternance
                         |
                         v
                API La bonne alternance
```

Le backend ASP.NET Core :

1. valide et normalise la recherche ;
2. transforme le métier choisi en un ou plusieurs codes ROME ;
3. résout la localisation en coordonnées lorsque nécessaire ;
4. consulte son cache ;
5. appelle l’API externe avec le jeton serveur ;
6. transforme la réponse dans le modèle public de StudyFlow ;
7. retire les coordonnées de contact qui ne sont pas nécessaires au MVP ;
8. retourne les résultats à Flutter.

## 4. Recherche par mots-clés

La route d’offres officielle recherche principalement à partir de codes ROME ou RNCP, et non d’un texte métier libre directement transmis tel quel.

L’interface StudyFlow présentera donc un champ de recherche avec suggestions :

1. l’utilisateur saisit par exemple `développeur web` ;
2. StudyFlow propose des métiers correspondants ;
3. le métier sélectionné fournit un ou plusieurs codes ROME ;
4. ces codes sont transmis à la recherche d’offres.

Pour le tout premier prototype, le référentiel métier peut être limité aux domaines utiles à la classe. Avant la version publique, il faudra brancher un référentiel ROME complet et officiel.

## 5. Localisation

La saisie de ville ou de code postal est transformée en coordonnées géographiques. Le rayon proposé dans le MVP utilise les valeurs prises en charge par la source :

- 10 km ;
- 30 km ;
- 60 km ;
- 100 km.

Le backend conserve les coordonnées normalisées dans les recherches sauvegardées afin d’éviter de résoudre la même ville à chaque alerte.

## 6. Modèle normalisé StudyFlow

L’API interne ne reproduit pas directement le modèle du fournisseur. Elle expose un modèle stable :

```text
AlternanceSearchResult
├── source
├── externalId
├── opportunityType
├── title
├── company
├── location
├── distanceKm
├── publishedAt
├── expiresAt
├── contractTypes
├── targetDiploma
├── remoteMode
├── summary
└── applicationUrl
```

`opportunityType` distingue :

- une offre publiée ;
- une offre partenaire ;
- une entreprise ouverte à une candidature spontanée.

Cette couche de normalisation garde la possibilité d’ajouter un autre fournisseur plus tard, sans que cela fasse partie du MVP.

## 7. Composants backend prévus

```text
IAlternanceProvider
├── SearchAsync(...)
└── GetByIdAsync(...)

LaBonneAlternanceProvider : IAlternanceProvider
AlternanceSearchService
AlternanceResultMapper
AlternanceCache
LocationResolver
OccupationResolver
```

Le contrôleur public dépend de `AlternanceSearchService`, jamais directement du fournisseur externe.

## 8. Résilience et protection

- cache initial recommandé : 5 minutes pour une recherche identique ;
- délai maximal d’appel externe : à tester, avec une valeur initiale courte ;
- un nouvel essai uniquement sur les erreurs temporaires et avec attente progressive ;
- limite de requêtes par adresse IP sur l’API publique StudyFlow ;
- message clair si la source est momentanément indisponible ;
- conservation possible du dernier résultat en cache pendant une indisponibilité courte ;
- journalisation du fournisseur, de la durée et du statut, sans journaliser le jeton.

## 9. Solution de repli

Si l’accès API n’est pas obtenu à temps, le widget officiel La bonne alternance peut être intégré temporairement à la version Web. Cette option permet une démonstration rapide, mais elle offre moins de contrôle visuel et ne permet pas une expérience identique dans Flutter Android.

Le développement doit donc prévoir :

- un fournisseur simulé pour travailler sans jeton ;
- l’adaptateur API comme cible principale ;
- le widget uniquement comme solution de repli Web.

## 10. Actions nécessaires

1. Créer un compte sur l’espace développeurs La bonne alternance.
2. Demander ou générer un jeton d’accès.
3. Stocker le jeton dans les secrets du backend local et de l’hébergement.
4. Tester les recherches correspondant aux formations de la classe.
5. Vérifier les champs et quotas réels avec le jeton attribué.
6. Relire les conditions d’utilisation avant toute ouverture publique.

## 11. Sources officielles consultées

- [Espace développeurs La bonne alternance](https://labonnealternance.apprentissage.beta.gouv.fr/espace-developpeurs)
- [Documentation de la recherche d’opportunités](https://api.apprentissage.beta.gouv.fr/fr/explorer/recherche-offre)
- [Fiche API sur data.gouv.fr](https://www.data.gouv.fr/dataservices/api-la-bonne-alternance)
