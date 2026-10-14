# Limites connues et vérifications sur iPhone

## Limites connues

**Calcul**
- Horizon supposé dégagé, au niveau de la mer : relief, bâtiments et altitude de l'observateur ne sont pas pris en compte.
- Réfraction standard (10 °C, 1010 hPa) : l'atmosphère réelle peut décaler lever et coucher de 1 à 2 minutes aux latitudes moyennes, davantage près des pôles.
- Échantillonnage de 5 minutes : deux passages d'un même seuil à moins de 5 minutes d'intervalle (soleil qui frôle un seuil, uniquement près des cercles polaires) peuvent être manqués. Aucun cas de ce type n'apparaît dans les 1 603 passages de référence.
- Heure dorée et heure bleue : convention −4°/+6° et −6°/−4°, non universelle (voir [ASTRONOMIE.md](ASTRONOMIE.md)).
- Le compte à rebours cherche la prochaine période sur 30 jours ; au-delà (nuit polaire profonde), il l'indique sans inventer de date.

**Application**
- Interface en français uniquement (chaînes en dur ; pas encore de catalogue de traductions).
- iPhone uniquement, en portrait.
- Recherche de lieux et géocodage inverse (nom, fuseau) nécessitent le réseau. Hors ligne, des coordonnées saisies à la main utilisent le fuseau choisi dans la liste ; si rien n'est choisi, le fuseau de l'appareil est utilisé et signalé « à confirmer ».
- Pour une position GPS sans réseau, le fuseau de l'appareil est utilisé (correct si l'iPhone règle l'heure automatiquement et se trouve sur place).
- Notifications : fenêtre de 7 jours pour les alertes solaires, 64 notifications au maximum (limite iOS), séances prioritaires. Les alertes ne sont reprogrammées qu'à l'ouverture de l'app : sans ouverture pendant plus d'une semaine, elles s'arrêtent.
- Les alertes solaires suivent le lieu actif ; changer de lieu les reprogramme.
- Boussole : sans position autorisée, iOS ne fournit que le nord magnétique ; la déclinaison n'est pas corrigée, l'orientation est alors marquée « approximative ».
- Si le stockage SwiftData ne peut pas être ouvert, l'app démarre avec un stockage en mémoire (les données de la session ne sont pas conservées). Aucun message n'est affiché dans ce cas.
- Pas de synchronisation iCloud des favoris et séances.

## Ce qui n'a pas été vérifié

L'app compile et ses tests (unitaires, interface, package) passent sur simulateur iOS dans la CI GitHub Actions. Rien n'a été exécuté sur un iPhone physique : capteurs (GPS, magnétomètre), notifications réelles, rendu en plein soleil et performances restent à vérifier avec la liste ci-dessous. Les tests d'interface tournent avec un lieu fixe (Paris) et ne couvrent pas les demandes d'autorisation.

## Vérifications à faire sur un iPhone réel

**Position**
- [ ] Première demande d'autorisation : texte affiché, acceptation, nom du lieu et fuseau corrects
- [ ] Refus puis bouton « Ouvrir les Réglages »
- [ ] Position approximative (« Position exacte » désactivée) : le calcul fonctionne
- [ ] Mode Avion : « Utiliser ma position » sans réseau (nom « Position actuelle », fuseau de l'appareil)

**Recherche et favoris**
- [ ] Recherche d'une ville étrangère (ex. Tokyo) : heures en heure de Tokyo
- [ ] Ajout aux favoris, redémarrage de l'app en mode Avion, favori utilisable
- [ ] Saisie manuelle en degrés décimaux et en DMS, détermination du fuseau

**Tableau de bord**
- [ ] Comparer lever/coucher avec une source officielle (ex. IMCCE, timeanddate) pour votre ville : écart attendu ≤ 1 min
- [ ] Compte à rebours qui bascule correctement au début et à la fin d'une heure dorée
- [ ] Passage de minuit avec l'app ouverte puis mise en arrière-plan/retour
- [ ] Un jour de changement d'heure (frise de 23 h et de 25 h)

**Boussole**
- [ ] Le cadran pointe le nord réel (comparer avec l'app Boussole d'Apple)
- [ ] Message de calibration près d'un objet métallique
- [ ] Le soleil affiché correspond à sa direction réelle
- [ ] Magnétomètre arrêté en quittant l'onglet (Instruments ou consommation)

**Notifications**
- [ ] Autorisation demandée à l'activation des alertes ou à la création d'une séance avec rappel
- [ ] Alerte reçue à l'heure prévue, app fermée, téléphone verrouillé
- [ ] Rappel de séance 5/10/15/30/60 min avant
- [ ] Notification d'une séance supprimée bien annulée
- [ ] Changer le format 12/24 h met à jour le texte des notifications

**Accessibilité et affichage**
- [ ] VoiceOver : frise, cadran, calendrier, compte à rebours lisibles
- [ ] Dynamic Type jusqu'à « Accessibilité XXXL » : rien de tronqué de manière gênante (notamment la grille du mois)
- [ ] Lisibilité en plein soleil (thème clair) et de nuit (thème sombre)

**Données**
- [ ] Création, modification, suppression de séances ; persistance après redémarrage
- [ ] Suppression d'un favori utilisé par une séance : la séance reste valide
