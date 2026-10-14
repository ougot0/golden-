# Guide de publication pas à pas

Ce guide couvre tout ce qui reste à faire de votre côté pour publier GoldenHour sur l'App Store. Comptez une demi-journée de travail, plus le délai de validation par Apple (en général 1 à 3 jours).

**Ce qui est déjà fait**
- l'app, compilée et testée automatiquement sur simulateur à chaque modification ;
- les captures d'écran App Store, en thèmes clair et sombre ;
- les pages web d'assistance et de confidentialité (dossier `docs/`) ;
- le texte de la fiche App Store ([APP_STORE.md](APP_STORE.md)).

**Ce dont vous avez besoin**
- un Mac récent avec macOS à jour ;
- un iPhone sous iOS 17 ou plus récent, et son câble ;
- un compte Apple (identifiant Apple) ;
- 99 € par an pour le programme Apple Developer.

---

## Étape 1 — S'inscrire au programme Apple Developer (1 à 2 jours)

1. Allez sur <https://developer.apple.com/programs/enroll/> et connectez-vous avec votre identifiant Apple. Celui-ci doit avoir la validation en deux étapes activée.
2. Choisissez **Particulier** (le plus simple) ou **Organisation** (il faut alors un numéro D-U-N-S, gratuit mais long à obtenir).
3. Payez les 99 €. L'activation prend de quelques heures à 2 jours.
4. Une fois inscrit, ouvrez <https://appstoreconnect.apple.com>, puis **Accords, taxes et opérations bancaires**. Acceptez l'accord **Paid Apps** et remplissez les coordonnées bancaires et fiscales.

   ⚠️ Sans ce point, impossible de vendre une app payante.

## Étape 2 — Installer Xcode et récupérer le projet (1 h)

1. Installez **Xcode** depuis l'App Store du Mac (gratuit, environ 10 Go). Ouvrez-le une fois pour qu'il installe ses composants.
2. Récupérez le projet, au choix :
   - **sans Terminal** : sur <https://github.com/ougot0/golden->, cliquez sur **Code › Download ZIP**, puis décompressez le fichier ;
   - **avec Terminal** : `git clone https://github.com/ougot0/golden-.git`
3. Double-cliquez sur **`GoldenHour.xcodeproj`**.

## Étape 3 — Mettre l'app à votre nom (10 min)

1. Dans Xcode, dans la colonne de gauche, cliquez sur l'icône bleue **GoldenHour** tout en haut.
2. Au centre, sous **TARGETS**, sélectionnez **GoldenHour**, puis ouvrez l'onglet **Signing & Capabilities**.
3. Dans **Team**, choisissez votre compte. S'il n'apparaît pas, ajoutez-le via **Xcode › Settings › Accounts › +**.
4. Dans **Bundle Identifier**, remplacez `com.example.goldenhour` par un identifiant unique, par exemple `com.votrenom.goldenhour`. Cet identifiant ne pourra plus changer après la publication.
5. Faites la même chose pour les cibles **GoldenHourTests** et **GoldenHourUITests**, avec le même identifiant suivi de `.tests` et `.uitests`.

## Étape 4 — Installer l'app sur votre iPhone (15 min)

1. Branchez l'iPhone et déverrouillez-le. Acceptez « Faire confiance à cet ordinateur ».
2. Sur l'iPhone, activez le **Mode développeur** : **Réglages › Confidentialité et sécurité › Mode développeur**. L'iPhone redémarre.
3. Dans Xcode, en haut au centre, choisissez votre iPhone dans la liste des appareils, puis appuyez sur **▶︎** (ou ⌘R).
4. Au premier lancement, iOS peut refuser l'app. Allez alors dans **Réglages › Général › VPN et gestion de l'appareil**, et faites confiance à votre profil développeur.

## Étape 5 — Tester sur l'iPhone (1 à 2 h, à faire en partie dehors)

Suivez la liste complète de [LIMITES.md](LIMITES.md). Les points essentiels :

- [ ] Autorisez la position : votre ville et votre fuseau s'affichent.
- [ ] Comparez le lever et le coucher du jour avec <https://www.timeanddate.com/sun/> pour votre ville. L'écart doit être inférieur ou égal à 1 minute.
- [ ] Ouvrez la boussole dehors et comparez-la avec l'app Boussole d'Apple. Vérifiez que le soleil dessiné est bien dans la direction du vrai soleil.
- [ ] Créez une séance pour dans 20 minutes avec un rappel 5 min avant. Verrouillez le téléphone : la notification doit arriver.
- [ ] Activez le mode Avion : les favoris, le calendrier et la boussole doivent continuer à fonctionner.
- [ ] Réglez la taille de texte au maximum (**Réglages › Accessibilité › Affichage et taille du texte › Texte plus grand**) et parcourez les 5 onglets.

Si quelque chose ne va pas, notez l'écran concerné, ce que vous avez fait et ce qui s'est passé, puis transmettez-le-moi : je corrigerai le code.

## Étape 6 — Publier les pages web (5 min)

Apple exige une adresse web pour la politique de confidentialité et une pour l'assistance. Les pages sont prêtes dans `docs/`.

1. Remplacez dans `docs/index.html` et `docs/confidentialite.html` :
   - `CONTACT_EMAIL` par votre adresse de contact ;
   - `PUBLISHER_NAME` par votre nom ou celui de votre société ;
   - `LAST_UPDATED` par la date du jour.

   Vous pouvez aussi me donner ces informations et je le fais.
2. Sur GitHub, ouvrez le dépôt, puis **Settings › Pages**.
3. Dans **Source**, choisissez **Deploy from a branch**. Comme branche, prenez la branche par défaut du dépôt (aujourd'hui `claude/new-session-ne9xer`), puis le dossier **/docs**. Cliquez sur **Save**.
4. Après 1 à 2 minutes, les pages sont en ligne :
   - assistance : `https://ougot0.github.io/golden-/`
   - confidentialité : `https://ougot0.github.io/golden-/confidentialite.html`

## Étape 7 — Créer la fiche dans App Store Connect (1 h)

1. Sur <https://appstoreconnect.apple.com>, allez dans **Apps › +  › Nouvelle app**.
   - Plateforme : iOS.
   - Nom : voir [Choisir le nom](#choisir-le-nom) plus bas.
   - Langue principale : Français.
   - Bundle ID : celui de l'étape 3.
   - SKU : un code libre, par exemple `goldenhour-001`.
2. **Tarifs et disponibilité** : prix **4,99 €**, tous les pays ou une sélection.
3. **Confidentialité de l'app** : URL de la politique (étape 6), puis **Commencer › Non, nous ne collectons pas de données**.
4. **Informations sur l'app** :
   - catégorie **Photo et vidéo** ;
   - classification par âge : répondez « Non » partout, ce qui donne 4+.
5. Dans la version **1.0**, remplissez :
   - sous-titre, texte promotionnel, description et mots-clés : copiez-les depuis [APP_STORE.md](APP_STORE.md) ;
   - URL d'assistance : celle de l'étape 6 ;
   - **Captures d'écran** : glissez les fichiers PNG du dossier `screenshots/` du dépôt (taille 6,9″). Choisissez 5 à 8 captures, dans l'ordre que vous voulez montrer.
   - **Notes pour la revue** : « Aucun compte nécessaire. La position est facultative : on peut rechercher un lieu ou saisir des coordonnées. Tous les calculs sont faits sur l'appareil. »

### Choisir le nom

Le nom affiché sur l'App Store doit être unique. Une recherche faite le 14 octobre 2026 montre que « Golden Hour », « GoldenHour: Sun Tracker », « Heure dorée » et « Golden Hour Calculator » sont déjà pris.

Pistes que je n'ai pas vues sur l'App Store (seul App Store Connect donne la réponse définitive) :
- **Lueur – Heure dorée & bleue**
- **GoldenHour Pro : lumière photo**
- **Ambre – Heure dorée photo**

Le nom de l'App Store peut être différent du nom affiché sous l'icône (« GoldenHour »). Si vous voulez les aligner, dites-moi le nom choisi et je mets l'app à jour.

## Étape 8 — Envoyer l'app à Apple (30 min)

1. Dans Xcode, choisissez **Any iOS Device (arm64)** comme appareil, en haut au centre.
2. **Product › Archive**. La compilation prend quelques minutes, puis la fenêtre **Organizer** s'ouvre.
3. Cliquez sur **Distribute App › App Store Connect › Upload** et gardez les options par défaut.
4. Après 10 à 30 minutes, la version apparaît dans App Store Connect, onglet **TestFlight**.
5. Conseillé : installez l'app via **TestFlight** sur votre iPhone et refaites un tour rapide.
6. Dans la fiche de la version 1.0, section **Build**, sélectionnez la version envoyée, puis cliquez sur **Ajouter pour vérification › Soumettre**.

Pour chaque envoi suivant, augmentez le numéro de **Build** (cible GoldenHour › onglet General › Build : 2, 3…).

## En cas de refus par Apple

Apple explique le motif dans App Store Connect (**Resolution Center**). Copiez-moi le message : je vous dirai quoi corriger, dans le code ou dans la fiche.
