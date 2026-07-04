# Identité visuelle StudyFlow

## Palette source

| Rôle | Couleur |
| :--- | :--- |
| Bleu pétrole | `#073B4C` |
| Menthe | `#84DCCF` |
| Bleu ciel | `#A6D9F7` |
| Bleu-gris | `#BCCCE0` |
| Rose poudré | `#BF98A0` |

Source : `studentflow palette 1.pdf`, fournie le 22 juin 2026.

## Utilisation dans l’interface

- `#073B4C` : texte fort, boutons principaux, navigation active et surfaces foncées ;
- `#84DCCF` : accents positifs, progression et espace Entreprise ;
- `#A6D9F7` : informations secondaires, catégories et surfaces légères ;
- `#BCCCE0` : bordures, fonds neutres et éléments désactivés ;
- `#BF98A0` : alertes, retards, annulations et éléments urgents.

Des teintes plus claires ou plus foncées peuvent être dérivées de ces cinq couleurs pour garantir la lisibilité. Le texte blanc n’est utilisé que sur le bleu pétrole ou une dérivée suffisamment foncée. La menthe, le bleu ciel, le bleu-gris et le rose poudré reçoivent du texte foncé.

## Principes

- garder le bleu pétrole comme couleur de marque dominante ;
- réserver le rose aux alertes pour ne pas banaliser sa signification ;
- utiliser la menthe pour les actions et statuts positifs, notamment l’espace Entreprise ;
- éviter de placer du texte blanc sur les teintes claires de la palette ;
- conserver des surfaces largement blanches ou légèrement bleutées pour ne pas surcharger les écrans.

## Thème sombre

Le thème sombre conserve la même direction artistique, mais n’utilise pas simplement les couleurs claires inversées. Les textes importants restent très contrastés et les cartes reçoivent des surfaces plus foncées pour éviter le problème initial de texte blanc ou pastel peu lisible.

Règle retenue :

- texte principal clair sur fond pétrole foncé ;
- texte secondaire suffisamment contrasté, jamais en bleu-gris trop transparent ;
- cartes claires seulement lorsque le texte est foncé ;
- cartes foncées avec bordure ou accent visuel lorsque l’écran est en thème sombre.

## Composants Flutter partagés

Le fichier `src/app/lib/core/theme/prototype_widgets.dart` centralise les petits composants visuels inspirés du prototype HTML :

- `ProtoCard` : carte blanche arrondie avec bordure légère ;
- `ProtoGradientCard` : carte forte bleu pétrole, utilisée pour les zones de mise en avant ;
- `ProtoScreenTitle` : titre d’écran cohérent avec sous-titre et action éventuelle ;
- `ProtoSectionHeading` : titre de section avec overline ;
- `ProtoIconBox` : icône dans un carré arrondi ;
- `ProtoChip` : puce courte ;
- `ProtoStateCard` : état vide, erreur ou information ;
- `ProtoPageLoader` : chargement pleine page.

Les états transversaux doivent utiliser `ProtoStateCard` ou `ProtoPageLoader` plutôt qu’un texte seul ou un spinner isolé.
