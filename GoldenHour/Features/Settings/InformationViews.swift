import SwiftUI
import SolarEngine
import GoldenHourCore

/// Long-form text page with the instrument styling.
private struct InformationPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .instrumentBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Paragraph: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AccuracyView: View {
    var body: some View {
        InformationPage(title: "Précision des calculs") {
            InstrumentSection(title: "Méthode") {
                Paragraph("Tous les calculs sont faits sur l'iPhone, sans connexion. La position du soleil est calculée avec les formules de Jean Meeus (Astronomical Algorithms, 2e éd., chap. 25), corrigées de la nutation, de l'aberration et de la parallaxe solaire. Les heures des événements sont obtenues en cherchant l'instant exact où le soleil franchit chaque seuil d'élévation, à la seconde près.")
                Paragraph("Les jours de changement d'heure (23 h ou 25 h), les jours sans lever ni coucher et les régions polaires sont traités directement par cette recherche.")
            }
            InstrumentSection(title: "Conventions") {
                ValueRow(label: "Lever, coucher", value: "−0,833°")
                ValueRow(label: "Heure dorée", value: "−4° à +6°")
                ValueRow(label: "Heure bleue", value: "−6° à −4°")
                ValueRow(label: "Crépuscule civil", value: "−6°")
                ValueRow(label: "Crépuscule nautique", value: "−12°")
                ValueRow(label: "Crépuscule astronomique", value: "−18°")
                Paragraph("Les élévations sont celles du centre du soleil, sans réfraction. Le seuil de −0,833° du lever et du coucher tient compte de la réfraction moyenne (34′) et du rayon apparent du soleil (16′), comme les éphémérides officielles.")
                Paragraph("L'heure dorée et l'heure bleue n'ont pas de définition officielle. GoldenHour utilise une convention photographique courante ; d'autres applications utilisent d'autres seuils et peuvent afficher des heures différentes de quelques minutes.")
            }
            InstrumentSection(title: "Vérification") {
                Paragraph("Le moteur est comparé, dans les tests automatisés, à des valeurs de référence calculées avec Skyfield et les éphémérides JPL DE421 : 13 lieux de 78° N à 55° S, 11 dates (équinoxes, solstices, changements d'heure, 1990, 2045), soit 1 603 passages de seuils.")
                ValueRow(label: "Latitudes < 50°", value: "écart max. 4 s")
                ValueRow(label: "Latitudes 50° à 67°", value: "écart max. 7 s")
                ValueRow(label: "Latitudes > 67°", value: "écart max. 38 s")
                ValueRow(label: "Position (élévation)", value: "écart max. 0,01°")
            }
            InstrumentSection(title: "Limites") {
                Paragraph("L'écart avec ce que vous observerez réellement est surtout dû à l'atmosphère : la réfraction varie avec la température et la pression et peut décaler le lever ou le coucher de une à deux minutes, davantage près des pôles. Le relief (montagnes, bâtiments) et l'altitude de l'observateur ne sont pas pris en compte : le calcul suppose un horizon dégagé au niveau de la mer.")
                Paragraph("Près des cercles polaires, quand le soleil frôle un seuil, l'heure d'un événement devient très sensible et peut différer de plusieurs minutes d'une source à l'autre.")
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        InformationPage(title: "Confidentialité") {
            InstrumentSection(title: "En résumé") {
                Paragraph("GoldenHour ne collecte aucune donnée. L'application n'a pas de serveur, pas de compte, pas de publicité, pas d'outil d'analyse ni de suivi.")
            }
            InstrumentSection(title: "Position") {
                Paragraph("Si vous l'autorisez, votre position est lue ponctuellement par l'iPhone pour calculer les heures du soleil et orienter la boussole. Elle reste sur l'appareil. Pour afficher le nom du lieu et son fuseau horaire, les coordonnées sont transmises au service de géocodage d'Apple, selon la politique de confidentialité d'Apple.")
            }
            InstrumentSection(title: "Recherche de lieux") {
                Paragraph("Le texte saisi dans la recherche est envoyé au service Plans d'Apple pour proposer des résultats. GoldenHour n'en conserve aucune trace.")
            }
            InstrumentSection(title: "Données enregistrées") {
                Paragraph("Vos lieux favoris, vos séances et vos réglages sont stockés uniquement sur cet iPhone. Ils sont supprimés avec l'application. Ils peuvent être inclus dans les sauvegardes iCloud ou locales de l'appareil, comme les données de toute application.")
            }
            InstrumentSection(title: "Notifications") {
                Paragraph("Les notifications sont programmées localement par iOS. Aucune notification n'est envoyée depuis un serveur.")
            }
        }
    }
}

struct AboutView: View {
    @Environment(AppModel.self) private var model

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        InformationPage(title: "À propos") {
            VStack(alignment: .leading, spacing: 6) {
                Text("GoldenHour")
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(Palette.ink)
                Text("La lumière naturelle, à la minute près.")
                    .foregroundStyle(Palette.inkSecondary)
            }
            InstrumentSection(title: "Application") {
                ValueRow(label: "Version", value: version)
                ValueRow(label: "Licence", value: model.entitlements.hasFullAccess ? "Version complète" : "—")
                ValueRow(label: "Calculs", value: "Sur l'appareil, hors ligne")
            }
            InstrumentSection(title: "Composants") {
                Paragraph("GoldenHour n'utilise aucune bibliothèque tierce : uniquement SwiftUI, SwiftData, Core Location, MapKit et UserNotifications d'Apple. Les algorithmes astronomiques sont issus de Jean Meeus, Astronomical Algorithms (Willmann-Bell, 1998), et de F. Espenak et J. Meeus pour ΔT (NASA/TP-2006-214141).")
            }
        }
    }
}
