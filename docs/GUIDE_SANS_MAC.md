# Publier GoldenHour sans Mac

Tout se fait dans un navigateur et sur votre iPhone. Un Mac hébergé par GitHub compile l'app, Apple la signe à distance, puis vous l'installez avec **TestFlight** pour la tester avant de la soumettre.

**Durée** : environ 1 heure, plus 10 à 30 minutes de traitement par Apple après chaque envoi.

**Prérequis** :
- être inscrit au programme Apple Developer ;
- avoir accepté l'accord **Paid Apps** dans App Store Connect (**Accords, taxes et opérations bancaires**).

---

## 1. Noter votre Team ID (2 min)

1. Ouvrez <https://developer.apple.com/account>, rubrique **Membership details**.
2. Copiez le **Team ID** : 10 caractères, par exemple `A1B2C3D4E5`.

## 2. Réserver l'identifiant de l'app (5 min)

1. Ouvrez <https://developer.apple.com/account/resources/identifiers/list>, puis cliquez sur le bouton **+**.
2. Choisissez **App IDs › Continue › App › Continue**.
3. Remplissez :
   - **Description** : `GoldenHour` ;
   - **Bundle ID** : cochez **Explicit**, puis saisissez par exemple `com.votrenom.goldenhour`. Ne mettez que des minuscules, des chiffres et des points. Cet identifiant ne pourra plus changer.
4. Ne cochez aucune *Capability*. Cliquez sur **Continue › Register**.

## 3. Créer la fiche de l'app (5 min)

1. Ouvrez <https://appstoreconnect.apple.com/apps>, puis **+ › Nouvelle app**.
2. Remplissez :
   - Plateforme : **iOS** ;
   - Nom : le nom choisi (voir la section « Choisir le nom » de [GUIDE_PUBLICATION.md](GUIDE_PUBLICATION.md)) ;
   - Langue principale : **Français** ;
   - Bundle ID : celui de l'étape 2 ;
   - SKU : par exemple `goldenhour-001` ;
   - Accès : **Accès complet**.

## 4. Créer une clé d'API App Store Connect (5 min)

1. Dans App Store Connect, ouvrez **Utilisateurs et accès › Intégrations › App Store Connect API**.
2. La première fois, cliquez sur **Demander l'accès** et acceptez. Seul le titulaire du compte peut le faire.
3. Dans **Clés d'équipe**, cliquez sur **+** (Générer une clé API). Remplissez :
   - nom : `GitHub GoldenHour` ;
   - accès : **Admin**. Ce rôle est nécessaire pour la signature à distance.
4. Notez l'**ID d'émetteur** (*Issuer ID*), affiché au-dessus du tableau, et l'**ID de clé** (*Key ID*) de la nouvelle ligne.
5. Cliquez sur **Télécharger la clé API**. Vous obtenez un fichier `AuthKey_XXXXXXXXXX.p8`.

   ⚠️ Apple ne permet de le télécharger **qu'une seule fois**. Gardez-le en lieu sûr et ne le partagez avec personne, ni par message, ni par e-mail, ni dans une conversation avec moi.

## 5. Donner ces informations à GitHub (10 min)

1. Ouvrez <https://github.com/ougot0/golden-/settings/secrets/actions>.
2. Dans l'onglet **Secrets**, cliquez sur **New repository secret** et créez ces trois secrets :

| Nom | Valeur |
|---|---|
| `ASC_KEY_ID` | l'ID de clé (étape 4) |
| `ASC_ISSUER_ID` | l'ID d'émetteur (étape 4) |
| `ASC_KEY_P8` | **tout** le contenu du fichier `.p8`, lignes `-----BEGIN PRIVATE KEY-----` et `-----END PRIVATE KEY-----` comprises |

   Pour copier le contenu du `.p8` sur iPhone ou iPad, ouvrez-le avec l'app **Fichiers** puis un éditeur de texte. Sur un PC Windows, utilisez le Bloc-notes.

3. Passez à l'onglet **Variables**. Cliquez sur **New repository variable** et créez ces deux variables :

| Nom | Valeur |
|---|---|
| `APPLE_TEAM_ID` | votre Team ID (étape 1) |
| `APP_BUNDLE_ID` | votre Bundle ID (étape 2) |

Les secrets sont chiffrés par GitHub. Ils ne sont visibles par personne, pas même dans les journaux, et ne servent qu'au workflow TestFlight.

## 6. Lancer la compilation et l'envoi (2 min, puis environ 15 min d'attente)

1. Ouvrez <https://github.com/ougot0/golden-/actions/workflows/testflight.yml>.
2. Cliquez sur **Run workflow**, puis sur le bouton vert **Run workflow**.
3. Patientez environ 15 minutes. Une coche verte indique que l'app a été envoyée à Apple.
   - Si c'est une croix rouge, ouvrez le run, copiez le message d'erreur en rouge et envoyez-le-moi. Je corrigerai.

À chaque relance, le numéro de build augmente automatiquement.

## 7. Installer l'app sur votre iPhone avec TestFlight (10 min)

1. Après 10 à 30 minutes, dans App Store Connect, ouvrez l'app puis l'onglet **TestFlight**. La version passe de « Traitement » à « Prête à tester ».
2. Dans **Tests internes**, cliquez sur **+** pour créer un groupe (par exemple « Moi ») et ajoutez-vous comme testeur.
3. Sur l'iPhone, installez l'app **TestFlight** depuis l'App Store. Ouvrez l'invitation reçue par e-mail, puis touchez **Installer**.
4. Testez avec la liste de [LIMITES.md](LIMITES.md), en particulier :
   - la position ;
   - la comparaison des horaires avec timeanddate.com ;
   - la boussole, dehors ;
   - une notification de séance ;
   - le mode Avion.

Envoyez-moi tout ce qui ne va pas. Après correction, relancez l'étape 6 : la nouvelle version arrive dans TestFlight.

## 8. Mettre en ligne les pages web (5 min)

Suivez l'étape 6 de [GUIDE_PUBLICATION.md](GUIDE_PUBLICATION.md) : **Settings › Pages**, avec le dossier `/docs`.

## 9. Compléter la fiche et soumettre (30 min)

Suivez l'étape 7 de [GUIDE_PUBLICATION.md](GUIDE_PUBLICATION.md) :
- prix, confidentialité, catégorie ;
- textes et mots-clés, à copier depuis [APP_STORE.md](APP_STORE.md) ;
- captures d'écran : prenez les fichiers du dossier `screenshots/` du dépôt.

Ensuite, dans la version 1.0 :
1. Dans **Build**, choisissez la version envoyée par GitHub.
2. Cliquez sur **Ajouter pour vérification › Soumettre**.

Apple répond en général en 1 à 3 jours. En cas de refus, copiez-moi le message du **Resolution Center**.
