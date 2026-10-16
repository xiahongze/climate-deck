pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "myplace.js" as MyPlace

PlasmoidItem {
    id: root
    readonly property bool isDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property var ac: deckClient.aircon
    readonly property var house: ac ? MyPlace.houseStats(MyPlace.sortedZones(ac)) : ({ average: NaN })

    Plasmoid.icon: "weather-few-clouds"
    Plasmoid.title: i18n("Climate Deck")
    Plasmoid.backgroundHints: isDesktop ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground
    preferredRepresentation: isDesktop ? fullRepresentation : null
    switchWidth: isDesktop ? -1 : Kirigami.Units.gridUnit * 20
    switchHeight: isDesktop ? -1 : Kirigami.Units.gridUnit * 20
    toolTipMainText: i18n("Climate Deck")
    toolTipSubText: ac ? i18n("Inside %1 · aircon %2", MyPlace.formatTemp(house.average, 1), ac.info.state === "on" ? ac.info.mode : i18n("off")) : deckClient.lastError

    Client {
        id: deckClient
        host: Plasmoid.configuration.host
        acKey: Plasmoid.configuration.airconKey
        pollSeconds: Plasmoid.configuration.pollSeconds
    }

    // Panels get a compact reading; the widget is designed for the desktop.
    compactRepresentation: Item {
        implicitWidth: compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: Kirigami.Units.iconSizes.medium
        Controls.Label {
            id: compactLabel
            anchors.centerIn: parent
            text: MyPlace.formatTemp(root.house.average, 0)
            font.weight: Font.Light
        }
        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }
    }
    fullRepresentation: DeckView {
        client: deckClient
        desktop: root.isDesktop
        themeMode: Plasmoid.configuration.themeMode
        desktopOpacity: Plasmoid.configuration.desktopOpacity
        showSparklines: Plasmoid.configuration.showSparklines
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
    }
}
