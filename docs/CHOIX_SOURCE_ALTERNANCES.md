# Choix des sources d’offres d’alternance

> Dernière mise à jour : 4 juillet 2026

## 1. Décision actuelle

Le MVP s’appuie maintenant sur un agrégateur backend. Il expose une recherche normalisée Swikko et peut interroger plusieurs fournisseurs :

- **La Bonne Alternance** : source publique française orientée alternance ;
- **Adzuna** : API d’offres d’emploi, utile comme source complémentaire ;
- **France Travail — Offres d’emploi v2** : source institutionnelle française, utilisable avec client id / client secret.

Flutter et l’interface Web publique ne contactent jamais directement ces APIs externes. Elles appellent uniquement le backend Swikko :

```text
Flutter / Web public
        |
        v
API Swikko
        |
        +--> La Bonne Alternance
        +--> Adzuna
        +--> France Travail
```

Ce choix protège les clés API et permet de garder un format de résultat stable même si un fournisseur change.

## 2. Pourquoi plusieurs sources ?

La recherche d’alternance est importante dans le projet, mais une seule API peut être incomplète, indisponible ou limitée par ses critères de recherche.

L’agrégation permet :

- d’obtenir davantage de résultats ;
- de comparer des sources publiques et privées ;
- de garder une démonstration fonctionnelle même si une source est mal configurée ;
- de brancher de nouvelles sources plus tard sans changer l’app mobile.

Le backend normalise les réponses dans un modèle commun : titre, entreprise, lieu, résumé, source, identifiant externe et URL de candidature.

## 3. Configuration locale

Les clés restent côté backend, dans `.env`, jamais dans Flutter et jamais dans Git.

Exemple :

```env
Adzuna__AppId=ton-app-id
Adzuna__AppKey=ton-app-key

FranceTravail__ClientId=ton-client-id
FranceTravail__ClientSecret=ton-client-secret
```

La Bonne Alternance peut aussi être configurée si un jeton est nécessaire :

```env
LaBonneAlternance__BaseUrl=https://api.apprentissage.beta.gouv.fr
LaBonneAlternance__SearchPath=/fr/explorer/recherche-offre
LaBonneAlternance__AccessToken=ton-token-si-necessaire
```

## 4. Mode démonstration

Pour garder l’application présentable même sans toutes les clés :

- La Bonne Alternance peut retourner un résultat de démonstration si elle n’est pas configurée ;
- Adzuna peut retourner un résultat de démonstration si elle n’est pas configurée ;
- France Travail est désactivé si ses identifiants ne sont pas fournis, car son OAuth nécessite une configuration réelle.

Cela permet de tester l’écran Alternances sans bloquer la soutenance sur une clé externe.

## 5. Limites actuelles

Le MVP ne fait pas encore :

- déduplication avancée entre fournisseurs ;
- cache persistant des résultats ;
- alertes automatiques envoyées par mail ou push ;
- tri intelligent par pertinence ;
- géolocalisation avancée ;
- vérification juridique complète des conditions de chaque fournisseur pour une production publique.

Ces points sont à traiter avant une mise en production ouverte.

## 6. Position produit

Swikko ne remplace pas les sites de candidature. L’app aide à chercher, sauvegarder et organiser les démarches, puis redirige l’élève vers le site source pour candidater.

La valeur ajoutée Swikko est donc :

- centraliser la recherche ;
- relier la recherche d’alternance aux tâches et événements personnels ;
- permettre l’entraide entre élèves d’une même classe ;
- garder un espace Carrière/Entreprise pour CV, contacts, ressources et relances.
