# GoldenHour

Application iPhone native (Swift, SwiftUI, SwiftData) pour photographes et vidéastes : heures dorées et bleues, lever et coucher du soleil, crépuscules, position du soleil, boussole solaire, planification de séances et rappels. Tous les calculs astronomiques se font **sur l'appareil, hors ligne**. Pas de serveur, pas de compte, pas de dépendance tierce, pas de publicité.

> État de vérification : voir [Ce qui a été vérifié](#ce-qui-a-été-vérifié). L'app compile et tous les tests passent sur simulateur iOS (CI GitHub Actions) ; le comportement sur iPhone réel (GPS, boussole, notifications) reste à valider.

## Architecture

```
golden-/
├── project.yml                     Spécification XcodeGen (source du projet Xcode)
├── GoldenHour.xcodeproj            Projet Xcode généré (app + tests + package local)
├── Packages/GoldenHourKit/         Package Swift local, sans UIKit/SwiftUI (testable sous Linux)
│   ├── Sources/SolarEngine/        Moteur astronomique (Foundation uniquement)
│   │   ├── AstroMath.swift           Jour julien, ΔT, angles
│   │   ├── SolarPosition.swift       Position du soleil (Meeus ch. 25), réfraction
│   │   ├── LightConventions.swift    Seuils documentés (heure dorée, bleue, crépuscules)
│   │   ├── LocalDate.swift           Jour calendaire indépendant du fuseau
│   │   ├── SolarDay.swift            Événements, frise, périodes, cas polaires
│   │   └── LightForecast.swift       Compte à rebours, événements à venir, course du soleil
│   ├── Sources/GoldenHourCore/     Logique applicative indépendante de l'UI
│   │   ├── NotificationPlanner.swift Planification sous la limite iOS de 64 notifications
│   │   ├── CoordinateParser.swift    Saisie de coordonnées (décimal, DMS, N/S/E/O)
│   │   ├── CompassMath.swift         Fiabilité du cap, angles
│   │   ├── SolarFormatting.swift     Heures dans le fuseau du lieu, 12/24 h, durées
│   │   └── Entitlements.swift        Point d'extension StoreKit 2
│   └── Tests/                      34 tests, dont la comparaison aux références Skyfield/JPL
├── GoldenHour/                     Application iOS
│   ├── App/                        Point d'entrée, état partagé, onglets
│   ├── Models/                     SwiftData : SavedPlace, PhotoSession ; ActivePlace
│   ├── Services/                   Réglages, Core Location, MapKit, notifications
│   ├── DesignSystem/               Palette, composants, libellés
│   ├── Features/                   Dashboard, Calendar, Compass, Planner, Places, Settings
│   └── Resources/                  Icône, couleur de lancement, manifeste de confidentialité
├── GoldenHourTests/                Tests unitaires de l'app (réglages, SwiftData, textes)
├── GoldenHourUITests/              Tests d'interface (lancement en mode test, sans GPS)
├── tools/                          Références astronomiques, icône, scripts
└── docs/                           Astronomie, App Store, limites, confidentialité
```

Principes :

- **Séparation stricte** : le moteur (`SolarEngine`) et la logique (`GoldenHourCore`) ne dépendent d'aucun framework Apple d'interface ; ils compilent et se testent sur macOS, iOS et Linux.
- **Fuseau du lieu partout** : un jour est un `LocalDate` (année, mois, jour) interprété dans le fuseau IANA du lieu, jamais celui de l'appareil. Les heures affichées sont toujours l'heure locale du lieu.
- **Hors ligne** : lieux favoris et séances stockés avec coordonnées et fuseau (SwiftData). Seules la recherche de lieux et le géocodage inverse nécessitent le réseau (services Apple gratuits).
- **Batterie** : pas de suivi de position continu (une requête ponctuelle), magnétomètre actif uniquement quand la boussole est affichée et l'app au premier plan.

## Publier sans Mac

Voir [docs/GUIDE_SANS_MAC.md](docs/GUIDE_SANS_MAC.md) : compilation, signature et envoi sur TestFlight par GitHub Actions (`.github/workflows/testflight.yml`), test sur iPhone via TestFlight.

## Compiler et installer

Prérequis : Mac avec **Xcode 16** ou plus récent, iOS 17 minimum sur l'iPhone.

1. Ouvrir `GoldenHour.xcodeproj`.
2. Cible *GoldenHour* › *Signing & Capabilities* : choisir votre équipe et remplacer l'identifiant `com.example.goldenhour` par le vôtre (idem pour les deux cibles de test si vous les lancez sur appareil).
3. Choisir un simulateur ou un iPhone branché, puis *Product › Run* (⌘R).
4. Tests : *Product › Test* (⌘U) exécute les tests unitaires de l'app, les tests d'interface et les tests du package.

En ligne de commande :

```sh
# Tests du moteur et de la logique (macOS, ou Linux avec Swift 5.9+)
swift test --package-path Packages/GoldenHourKit

# Linux sans Swift installé, via Docker
./tools/test-linux.sh

# Application + tous les tests sur simulateur
xcodebuild test -project GoldenHour.xcodeproj -scheme GoldenHour \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Après ajout ou suppression de fichiers, régénérer le projet : `brew install xcodegen && xcodegen generate`.

La CI (`.github/workflows/ci.yml`) exécute les tests du package sous Linux et compile/teste l'app sur un simulateur iOS (runner macOS).

## Ce qui a été vérifié

| Élément | Statut |
|---|---|
| Moteur astronomique et logique (`GoldenHourKit`) | Compilé et **34 tests passés** (Swift 6.0.3, Linux) |
| Précision vs Skyfield + JPL DE421 | 1 603 passages de seuils, 13 lieux (78° N à 55° S), 11 dates : écart max. 3,3 s sous 50° de latitude, 6,9 s entre 50° et 67°, 37 s au-delà ; midi solaire 2 s ; élévation 0,009° |
| Compilation de l'app iOS | **Réussie** sur GitHub Actions (macOS 15, Xcode par défaut du runner, simulateur iPhone) |
| Tests de l'app sur simulateur | **7 tests unitaires et 5 tests d'interface passés**, plus les 34 tests du package, dans le même run |
| Comportement sur iPhone (GPS, boussole, notifications) | **Non vérifié** : voir [docs/LIMITES.md](docs/LIMITES.md) |

## Monétisation

Recommandation : **application payante à l'achat (4,99 €)**, sans achat intégré, sans abonnement, sans publicité. Toutes les fonctions sont incluses. Le code passe par le protocole `EntitlementProviding` (implémentation `PaidUpfrontEntitlements`), ce qui permet d'ajouter plus tard un déverrouillage StoreKit 2 (`Product`, `Transaction.currentEntitlements`, `AppTransaction` pour reconnaître les acheteurs de la version payante) sans toucher aux écrans. Aucun achat intégré n'est imposé dans cette version.

## Documentation

- [docs/ASTRONOMIE.md](docs/ASTRONOMIE.md) — méthode, conventions, validation
- [docs/APP_STORE.md](docs/APP_STORE.md) — fiche App Store, checklist de publication
- [docs/LIMITES.md](docs/LIMITES.md) — limites connues et vérifications à faire sur iPhone
- [docs/CONFIDENTIALITE.md](docs/CONFIDENTIALITE.md) — politique de confidentialité à publier
