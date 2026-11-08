pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "myplace.js" as MyPlace

PlasmoidItem {
    id: root
    readonly property bool isDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property var ac: deckClient.aircon
    readonly property var house: ac ? MyPlace.houseStats(MyPlace.sortedZones(ac)) : ({ average: NaN, count: 0 })

    Plasmoid.icon: "weather-few-clouds"
    Plasmoid.title: i18n("Climate Deck")
    Plasmoid.backgroundHints: isDesktop ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground
    preferredRepresentation: isDesktop ? fullRepresentation : compactRepresentation
    switchWidth: 0
    switchHeight: 0
    toolTipMainText: i18n("Climate Deck")
    toolTipSubText: {
        if (!deckClient.configured)
            return i18n("Set the tablet address in widget settings");
        if (!ac)
            return deckClient.lastError || i18n("Connecting to tablet…");
        const lines = [i18n("Inside %1", MyPlace.formatTemp(house.average, 1))];
        if (house.count > 1)
            lines.push(i18n("Rooms %1–%2", MyPlace.formatTemp(house.min, 1), MyPlace.formatTemp(house.max, 1)));
        lines.push(ac.info.state === "on"
            ? i18n("%1 · target %2", ({cool: i18n("Cooling"), heat: i18n("Heating"), vent: i18n("Fan"), dry: i18n("Dry"), myauto: i18n("Auto")})[ac.info.mode] || ac.info.mode, MyPlace.formatTemp(MyPlace.targetTemp(ac), 0))
            : i18n("Aircon off"));
        if (deckClient.stale || !deckClient.online)
            lines.unshift(i18n("Last known readings · %1", deckClient.online ? i18n("retrying") : i18n("offline")));
        return lines.join("\n");
    }

    Client {
        id: deckClient
        host: Plasmoid.configuration.host
        acKey: Plasmoid.configuration.airconKey
        pollSeconds: Plasmoid.configuration.pollSeconds
        store: HistoryStore {}
    }

    // Always use the compact reading in horizontal and vertical panels.
    compactRepresentation: Item {
        implicitWidth: compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Accessible.name: root.toolTipMainText + ": " + root.toolTipSubText
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        Keys.onSpacePressed: root.expanded = !root.expanded
        Keys.onReturnPressed: root.expanded = !root.expanded
        implicitHeight: Kirigami.Units.iconSizes.medium
        Controls.Label {
            id: compactLabel
            anchors.centerIn: parent
            text: MyPlace.formatTemp(root.house.average, 1)
            font.weight: Font.Medium
            color: Kirigami.Theme.textColor
            opacity: deckClient.stale || !deckClient.online ? 0.6 : 1
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 9
            width: Math.min(implicitWidth, parent.width)
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
