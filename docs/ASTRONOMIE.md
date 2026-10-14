# Moteur astronomique

## Position du soleil

`SolarCalculator` (`Packages/GoldenHourKit/Sources/SolarEngine/SolarPosition.swift`) :

1. Jour julien UT à partir de l'instant ; temps terrestre TT = UT + ΔT (polynômes Espenak & Meeus 2006).
2. Coordonnées solaires « basse précision » de Meeus, *Astronomical Algorithms*, 2e éd., chap. 25 : longitude moyenne, anomalie moyenne, équation du centre, longitude apparente corrigée de la nutation et de l'aberration, obliquité corrigée de la nutation. Précision documentée : environ 0,01°.
3. Temps sidéral moyen de Greenwich (Meeus 12.4) + équation des équinoxes.
4. Angle horaire local, élévation et azimut (Meeus chap. 13), azimut compté depuis le nord géographique dans le sens horaire.
5. Parallaxe solaire (8,794″ × cos h).

L'élévation de référence est **géométrique** (sans réfraction). L'élévation « apparente » affichée ajoute la réfraction standard (formule de Sæmundsson, Meeus 16.4).

## Événements d'une journée

`SolarDayCalculator` :

- Le jour est le jour calendaire du lieu, `[00:00, 00:00 du lendemain)` dans son fuseau IANA : 23, 24 ou 25 heures selon les changements d'heure. Les fuseaux où minuit n'existe pas certains jours sont gérés (`startOfDay` à partir de midi).
- L'élévation est échantillonnée toutes les 5 minutes sur le jour étendu de 12 h de chaque côté. Chaque changement de signe de `élévation − seuil` est affiné par dichotomie à mieux que 0,5 s.
- Le midi solaire est le passage de l'angle horaire à 0.
- Les périodes (heure dorée, heure bleue) sont les intervalles où l'élévation reste dans la bande ; leurs bornes réelles sont rapportées même si elles tombent la veille ou le lendemain (affichées avec « (veille) » / « (lendemain) »). Une période est *du matin* si le soleil monte, *du soir* s'il descend, *continue* si le soleil entre et sort de la bande du même côté (journée d'hiver très basse, nuit d'été polaire).
- **Régions polaires** : aucune hypothèse n'est faite ; un jour sans passage à −0,833° est classé « soleil de minuit » ou « nuit polaire » selon l'élévation. Les événements absents sont affichés « — ».
- **Dates** : l'interface propose 1900–2100. La théorie de Meeus reste valable bien au-delà ; la limite tient à ΔT et à la base de fuseaux horaires.

## Conventions

| Phase | Élévation géométrique du centre du soleil |
|---|---|
| Plein jour | ≥ +6° |
| **Heure dorée** | de −4° à +6° |
| **Heure bleue** | de −6° à −4° |
| Lever / coucher | −0,833° (34′ de réfraction + 16′ de demi-diamètre, convention USNO) |
| Crépuscule civil | −6° |
| Crépuscule nautique | −12° |
| Crépuscule astronomique | −18° |
| Nuit | < −18° |

L'heure dorée et l'heure bleue n'ont **pas de définition officielle**. Ces seuils sont une convention photographique répandue ; ils sont regroupés dans `LightConventions` et peuvent être changés en un seul endroit. Avec ces valeurs, l'aube civile et le début de l'heure bleue du matin coïncident (−6°).

## Validation

Les références sont produites par `tools/reference/generate_solar_references.py` avec **Skyfield** et l'éphéméride **JPL DE421** (fournie hors ligne par le paquet `skyfield-data`), avec les mêmes conventions (élévation géométrique topocentrique, jour local du lieu). Skyfield est plus précis que l'algorithme embarqué de deux à trois ordres de grandeur ; il sert de vérité de référence. Le fichier généré est `Packages/GoldenHourKit/Tests/SolarEngineTests/Fixtures/skyfield_reference.json`.

Jeu de test : Paris, New York, Los Angeles, Quito, Singapour, Sydney, Le Cap, Tokyo, Reykjavik, Ushuaïa, Tromsø, Longyearbyen, Kiritimati (UTC+14) × équinoxes et solstices 2026, changements d'heure américain, européen et australien, 15 juillet 1990, 10 février 2045.

Résultats mesurés (Swift 6.0.3, Linux) :

| Mesure | Écart max. observé | Tolérance du test |
|---|---|---|
| Passages de seuils, \|lat\| < 50° | 3,3 s | 10 s |
| Passages de seuils, 50° ≤ \|lat\| < 67° | 6,9 s | 15 s |
| Passages de seuils, \|lat\| ≥ 67° | 37 s | 60 s |
| Nombre de passages par jour et par seuil | identique sur les 1 603 cas | égalité |
| Midi solaire | 2,0 s | 10 s |
| Élévation | 0,009° | 0,02° |
| Azimut × cos(élévation) | < 0,02° | 0,02° |

Pour régénérer les références :

```sh
python3 -m venv .venv && .venv/bin/pip install skyfield skyfield-data
.venv/bin/python tools/reference/generate_solar_references.py \
  > Packages/GoldenHourKit/Tests/SolarEngineTests/Fixtures/skyfield_reference.json
```

## Écart avec l'observation réelle

L'écart dominant n'est pas le calcul mais l'atmosphère : la réfraction réelle varie avec la température et la pression (± 1 à 2 min sur le lever/coucher aux latitudes moyennes, davantage près des pôles). Le relief, les bâtiments et l'altitude de l'observateur ne sont pas pris en compte (horizon dégagé au niveau de la mer).
