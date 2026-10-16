pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

Kirigami.FormLayout {
    id: page
    property alias cfg_host: host.text
    property string cfg_airconKey
    property alias cfg_pollSeconds: poll.value
    property string cfg_themeMode
    property alias cfg_desktopOpacity: opacitySlider.value
    property alias cfg_showSparklines: sparklines.checked
    property string cfg_hostDefault: ""
    property string cfg_airconKeyDefault: "ac1"
    property int cfg_pollSecondsDefault: 10
    property string cfg_themeModeDefault: "system"
    property int cfg_desktopOpacityDefault: 70
    property bool cfg_showSparklinesDefault: true
    property string testResult: ""

    // A read-only probe of the address being typed.
    function testConnection() {
        const url = MyPlace.systemDataUrl(host.text);
        if (!url) {
            testResult = i18n("Enter an address first.");
            return;
        }
        testResult = i18n("Checking…");
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            const r = xhr.status === 200 ? MyPlace.parseSystem(xhr.responseText) : { ok: false, reason: i18n("no reply") };
            if (r.ok) {
                const n = Object.keys(r.data.aircons).length;
                const zones = Object.keys(r.data.aircons.ac1 ? r.data.aircons.ac1.zones || {} : {}).length;
                page.testResult = i18n("Found “%1”: %2 aircon(s), %3 zones.", r.data.system ? r.data.system.name : "MyPlace", n, zones);
            } else {
                page.testResult = i18n("Not a MyPlace tablet (%1).", r.reason);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Tablet address:")
        Controls.TextField {
            id: host
            placeholderText: i18n("e.g. 192.168.1.50")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        }
        Controls.Button {
            text: i18n("Test")
            icon.name: "network-connect"
            onClicked: page.testConnection()
        }
    }
    Controls.Label {
        visible: page.testResult !== ""
        text: page.testResult
        wrapMode: Text.Wrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
    }
    Controls.Label {
        text: i18n("The wall tablet's IP, port 2025 by default. A DHCP reservation on your router keeps it stable.")
        wrapMode: Text.Wrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
        Layout.maximumWidth: Kirigami.Units.gridUnit * 20
    }
    Controls.ComboBox {
        id: airconKey
        Kirigami.FormData.label: i18n("Aircon:")
        model: ["ac1", "ac2", "ac3", "ac4"]
        currentIndex: Math.max(0, indexOfValue(page.cfg_airconKey))
        onActivated: page.cfg_airconKey = currentValue
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Refresh every:")
        Controls.SpinBox { id: poll; from: 3; to: 300 }
        Controls.Label { text: i18n("seconds") }
    }
    Item { Kirigami.FormData.isSection: true }
    Controls.ComboBox {
        id: theme
        Kirigami.FormData.label: i18n("Theme:")
        textRole: "text"
        valueRole: "value"
        model: [{text: i18n("System"), value: "system"}, {text: i18n("Light"), value: "light"}, {text: i18n("Dark"), value: "dark"}]
        currentIndex: Math.max(0, indexOfValue(page.cfg_themeMode))
        onActivated: page.cfg_themeMode = currentValue
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Background opacity:")
        Controls.Slider { id: opacitySlider; from: 0; to: 100; stepSize: 5 }
        Controls.Label { text: i18n("%1%", opacitySlider.value) }
    }
    Controls.CheckBox { id: sparklines; text: i18n("Show temperature history") }
}
