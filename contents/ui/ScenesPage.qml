pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

// Scene list and editor. Scenes live on the tablet; every change is sent with
// setScene and confirmed from the next poll, because the tablet acks saves it
// didn't actually keep (for example past the 12-scene limit).
Item {
    id: page
    objectName: "scenesPage"
    property var deck
    readonly property var client: deck.client
    readonly property var scenes: MyPlace.sceneList(client.view)
    readonly property bool canAdd: MyPlace.nextSceneId(client.view) !== ""
    // Optimistic auto-run states, id -> bool, until a poll agrees.
    property var timerOverride: ({})
    // Editor state.
    property var draft: null
    property bool isNew: false
    property bool saving: false
    property string editorError: ""
    property string savingId: ""
    property int savePolls: 0

    implicitHeight: 0

    function startNew() {
        const id = MyPlace.nextSceneId(client.view);
        if (!id || !deck.ac)
            return;
        draft = MyPlace.draftFromCurrent(id, "", deck.ac, client.acKey);
        isNew = true;
        editorError = "";
    }

    function startEdit(scene) {
        const d = MyPlace.clone(scene);
        if (!MyPlace.sceneAircon(d, client.acKey) && deck.ac) {
            // A scene saved without aircon settings: start from the current ones.
            d.aircons = MyPlace.draftFromCurrent(d.id, d.name, deck.ac, client.acKey).aircons;
        }
        draft = d;
        isNew = false;
        editorError = "";
    }

    function closeEditor() {
        draft = null;
        saving = false;
        savingId = "";
        editorError = "";
    }

    function save(d) {
        saving = true;
        editorError = "";
        savingId = d.id;
        savePolls = 0;
        client.request("setScene", MyPlace.scenePayload(d, client.acKey), function(ok, reason) {
            if (!ok) {
                page.saving = false;
                page.savingId = "";
                page.editorError = i18n("The tablet refused the scene: %1", reason);
            }
        });
    }

    function run(scene) {
        client.request("runScene", { id: scene.id }, function(ok, reason) {
            deck.notify(ok ? i18n("Running “%1”", scene.name) : i18n("Couldn't run “%1”: %2", scene.name, reason), !ok);
        });
    }

    function remove(scene) {
        client.request("setScene", { id: scene.id, name: "" }, function(ok, reason) {
            deck.notify(ok ? i18n("Deleted “%1”", scene.name) : i18n("Couldn't delete “%1”: %2", scene.name, reason), !ok);
        });
    }

    function setTimer(scene, on) {
        const o = Object.assign({}, timerOverride);
        o[scene.id] = on;
        timerOverride = o;
        client.request("setScene", { id: scene.id, timerEnabled: on }, function(ok, reason) {
            if (!ok) {
                const r = Object.assign({}, page.timerOverride);
                delete r[scene.id];
                page.timerOverride = r;
                deck.notify(i18n("Couldn't change “%1”: %2", scene.name, reason), true);
            }
        });
    }

    Connections {
        target: page.client
        function onRefreshed() {
            // Drop overrides the tablet now agrees with.
            const o = {};
            for (const s of page.scenes) {
                if (page.timerOverride[s.id] !== undefined && Boolean(s.timerEnabled) !== page.timerOverride[s.id])
                    o[s.id] = page.timerOverride[s.id];
            }
            page.timerOverride = o;
            if (!page.saving || page.savingId === "")
                return;
            const saved = page.scenes.find(s => s.id === page.savingId);
            if (saved && saved.name === String(page.draft.name).slice(0, 12)) {
                page.deck.notify(i18n("Saved “%1”", saved.name), false);
                page.closeEditor();
            } else if (++page.savePolls >= 2) {
                page.saving = false;
                page.savingId = "";
                page.editorError = page.isNew
                    ? i18n("The tablet didn't keep the scene. It holds at most %1.", MyPlace.MAX_SCENES)
                    : i18n("The tablet didn't confirm the change. Try again.");
            }
        }
    }

    // List.
    ColumnLayout {
        anchors.fill: parent
        visible: page.draft === null
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            Controls.Label {
                Layout.fillWidth: true
                text: page.scenes.length
                    ? i18n("%1 of %2 scenes", page.scenes.length, MyPlace.MAX_SCENES)
                    : i18n("No scenes yet")
                color: page.deck.colors.muted
                font.pixelSize: Kirigami.Units.gridUnit * 0.55
            }
            PillButton {
                objectName: "newSceneButton"
                text: i18n("+ New scene")
                ink: page.deck.colors.ink
                tone: page.deck.unitOn ? page.deck.accent : page.deck.modeAccents.cool
                interactive: page.canAdd && page.deck.canControl
                onClicked: page.startNew()
                Controls.ToolTip.visible: !page.canAdd && newHover.hovered
                Controls.ToolTip.text: i18n("The tablet holds up to %1 scenes", MyPlace.MAX_SCENES)
                HoverHandler { id: newHover }
            }
        }

        Controls.ScrollView {
            id: listScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: listScroll.availableWidth
                spacing: Kirigami.Units.smallSpacing * 1.5
                Repeater {
                    model: page.scenes
                    delegate: SceneCard {
                        required property var modelData
                        Layout.fillWidth: true
                        scene: modelData
                        deck: page.deck
                        timerOn: page.timerOverride[modelData.id] !== undefined ? page.timerOverride[modelData.id] : Boolean(modelData.timerEnabled)
                        interactive: page.deck.canControl
                        onRun: page.run(modelData)
                        onEdit: page.startEdit(modelData)
                        onRemove: page.remove(modelData)
                        onTimerToggled: on => page.setTimer(modelData, on)
                    }
                }
                Controls.Label {
                    visible: page.scenes.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.gridUnit
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: i18n("A scene saves aircon settings to apply at once, or automatically on chosen days.")
                    color: page.deck.colors.muted
                }
            }
        }
    }

    SceneEditor {
        anchors.fill: parent
        visible: page.draft !== null
        deck: page.deck
        draft: page.draft || ({})
        isNew: page.isNew
        saving: page.saving
        error: page.editorError
        onEdited: d => { page.draft = d; }
        onSave: d => page.save(d)
        onCancel: page.closeEditor()
    }
}
