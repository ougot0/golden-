# App Store

## Fiche proposée (français)

**Nom** (30 caractères max.) : `GoldenHour – Lumière photo`

> Vérifier dans App Store Connect que le nom n'est pas déjà pris ; « GoldenHour » seul est probablement utilisé. Variantes : `GoldenHour : heure dorée`, `Heure Dorée Pro – GoldenHour`.

**Sous-titre** (30 caractères max.) : `Heure dorée, bleue et soleil`

**Texte promotionnel** (170 max.) :
Préparez chaque lumière : heures dorées et bleues à la minute, boussole solaire et rappels avant vos séances. Tout est calculé sur votre iPhone, même hors ligne.

**Description** :

GoldenHour est l'outil de lumière naturelle des photographes, vidéastes et amateurs de paysage.

LA LUMIÈRE DU JOUR, EN UN COUP D'ŒIL
• Lever et coucher du soleil, midi solaire, durée du jour
• Heures dorées et heures bleues du matin et du soir
• Aubes et crépuscules civils, nautiques et astronomiques
• Compte à rebours jusqu'à la prochaine heure dorée ou bleue
• Position du soleil en direct : azimut et élévation
• Frise de la journée avec la courbe du soleil et chaque phase de lumière

PARTOUT, À TOUTE DATE
• Votre position, une recherche de lieu ou des coordonnées saisies à la main
• Lieux favoris disponibles hors ligne
• Heures affichées dans le fuseau du lieu, changements d'heure compris
• Régions polaires gérées : soleil de minuit, nuit polaire, journées sans heure dorée
• Calendrier jour, semaine et mois, de 1900 à 2100

BOUSSOLE SOLAIRE
• Course du soleil sur la journée, directions du lever et du coucher
• Cadran orienté selon votre iPhone quand la mesure est fiable — et clairement signalé quand elle ne l'est pas

PLANIFIEZ VOS SÉANCES
• Créez un shooting avec date, lieu et notes
• Calez-le sur l'heure dorée, l'heure bleue, le lever ou le coucher
• Rappel 5, 10, 15, 30 ou 60 minutes avant
• Alertes de début d'heure dorée, d'heure bleue, de lever et de coucher

PRÉCIS ET RESPECTUEUX
• Calculs astronomiques sur l'appareil, sans connexion, vérifiés contre les éphémérides du JPL
• Aucune collecte de données, aucun compte, aucune publicité, aucun abonnement
• Thème clair et sombre, Dynamic Type et VoiceOver

Les définitions de l'heure dorée (−4° à +6°) et de l'heure bleue (−6° à −4°) sont détaillées dans l'application.

**Mots-clés** (100 caractères max.) : `heure dorée,heure bleue,soleil,lever,coucher,photo,photographie,crépuscule,boussole,paysage,lumière`

**Catégorie** : Photo et vidéo (secondaire : Météo ou Utilitaires).
**Prix** : niveau 4,99 €. **Classification** : 4+.
**Confidentialité (App Privacy)** : « Aucune donnée collectée ».

## Checklist de publication

### Compte et projet
- [ ] Programme Apple Developer actif ; accords « Paid Apps », coordonnées bancaires et fiscales remplis dans App Store Connect
- [ ] Identifiant de bundle définitif (remplacer `com.example.goldenhour` dans `project.yml` puis `xcodegen generate`, ou dans Xcode)
- [ ] Équipe de signature (`DEVELOPMENT_TEAM`), signature automatique
- [ ] `MARKETING_VERSION` = 1.0.0, `CURRENT_PROJECT_VERSION` incrémenté à chaque envoi
- [ ] Compilation Release sans erreur ni avertissement bloquant avec le dernier Xcode stable

### Qualité
- [ ] ⌘U : tests unitaires, tests du package et tests d'interface au vert
- [ ] Toutes les vérifications de [LIMITES.md](LIMITES.md) faites sur au moins un iPhone réel
- [ ] Test d'une installation neuve (aucune donnée) et d'une mise à jour
- [ ] Mode Avion : lieux favoris, calendrier et boussole fonctionnent
- [ ] Refus de chaque autorisation (position, notifications) : aucun écran bloqué
- [ ] Tailles de texte extrêmes (Réglages › Accessibilité › Texte plus grand) et VoiceOver sur chaque onglet
- [ ] Thèmes clair et sombre, en extérieur au soleil
- [ ] Instruments (Energy Log) : pas de position ni de magnétomètre actifs hors de la boussole

### Conformité
- [ ] `PrivacyInfo.xcprivacy` présent (UserDefaults, raison CA92.1) — vérifier le rapport de confidentialité de l'archive (Xcode › Organizer › Generate Privacy Report)
- [ ] Texte `NSLocationWhenInUseUsageDescription` relu
- [ ] Politique de confidentialité hébergée à une URL publique (texte : [CONFIDENTIALITE.md](CONFIDENTIALITE.md))
- [ ] URL d'assistance (page web ou adresse e-mail de contact)
- [ ] `ITSAppUsesNonExemptEncryption = NO` (aucun chiffrement propre)
- [ ] Questionnaire « App Privacy » : aucune donnée collectée
- [ ] Vérification de marque sur le nom choisi

### Fiche
- [ ] Captures 6,9″ (1320 × 2868) obligatoires, 6,5″ recommandées — prises depuis l'app réelle, sans données fictives
- [ ] Icône 1024 × 1024 sans transparence (fournie : `GoldenHour/Resources/Assets.xcassets/AppIcon.appiconset`)
- [ ] Description, mots-clés, sous-titre, texte promotionnel
- [ ] Notes pour la revue : l'app fonctionne sans compte ; la position est facultative (saisie manuelle possible)

### Envoi
- [ ] Product › Archive › Distribute App › App Store Connect
- [ ] TestFlight interne, puis externe si souhaité
- [ ] Soumission à la revue
