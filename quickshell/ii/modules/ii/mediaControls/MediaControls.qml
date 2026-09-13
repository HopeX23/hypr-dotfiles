pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool visible: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: MprisController.players
    readonly property var meaningfulPlayers: {
        const preferred = (Config.options.bar?.media?.preferredPlayer ?? "").trim().toLowerCase()
        if (preferred.length === 0) return filterDuplicatePlayers(realPlayers)
        const filtered = realPlayers.filter(p =>
            (p.identity ?? "").toLowerCase().includes(preferred) ||
            (p.desktopEntry ?? "").toLowerCase().includes(preferred)
        )
        if (filtered.length === 0) return filterDuplicatePlayers(realPlayers)
        return filterDuplicatePlayers(filtered)
    }
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    readonly property string mediaPosition: {
        if ((Config.options.bar?.layouts?.leftLayout ?? []).includes("media")) return "left"
        if ((Config.options.bar?.layouts?.middleLayout ?? []).includes("media")) return "center"
        if ((Config.options.bar?.layouts?.rightLayout ?? []).includes("media")) return "right"
        return "center"
    }

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real gap: Config.options.bar.cornerStyle === 3 ? Appearance.sizes.hyprlandGapsOut : 0
    readonly property bool cornerStyleReducesGap: Config.options.bar.cornerStyle === 1 || Config.options.bar.cornerStyle === 2
    readonly property real barThickness: barVertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight

    function filterDuplicatePlayers(players) {
        let filtered = [];
        let used = new Set();

        for (let i = 0; i < players.length; ++i) {
            if (used.has(i))
                continue;
            let p1 = players[i];
            let group = [i];

            // Find duplicates by trackTitle prefix
            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if (p1.trackTitle && p2.trackTitle && (p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle)) || (p1.position - p2.position <= 2 && p1.length - p2.length <= 2)) {
                    group.push(j);
                }
            }

            // Pick the one with non-empty trackArtUrl, or fallback to the first
            let chosenIdx = group.find(idx => players[idx].trackArtUrl && players[idx].trackArtUrl.length > 0);
            if (chosenIdx === undefined)
                chosenIdx = group[0];

            filtered.push(players[chosenIdx]);
            group.forEach(idx => used.add(idx));
        }
        return filtered;
    }

    Process {
        id: cavaProc
        running: (GlobalStates.mediaControlsOpen ||
            GlobalStates.sidebarRightOpen ||
            (GlobalStates.sidebarLeftOpen && !GlobalStates.mediaLyricsVisible) ||
            GlobalStates.equalizerOpen ||
            (Config.options.bar?.layouts?.leftLayout ?? []).includes("visualizer") ||
            (Config.options.bar?.layouts?.middleLayout ?? []).includes("visualizer") ||
            (Config.options.bar?.layouts?.rightLayout ?? []).includes("visualizer") ||
            (Config.options.background?.widgets?.visualizer?.enable ?? false))
            && MprisController.activePlayer !== null
        onRunningChanged: {
            if (!cavaProc.running) {
                GlobalStates.visualizerPoints = [];
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                GlobalStates.visualizerPoints = points;
            }
        }
    }

    Loader {
        id: mediaControlsLoader
        active: true
        sourceComponent: PanelWindow {
            id: panelWindow
            visible: GlobalStates.mediaControlsOpen
            color: "transparent"

            anchors {
                top: true
                left: true
                bottom: true
                right: true
            }

            property real dragX: 200
            property real dragY: 200
            property real dragStartX: 200
            property real dragStartY: 200

            mask: Region { item: draggableContainer }

            Item {
                id: draggableContainer
                x: panelWindow.dragX
                y: panelWindow.dragY
                width: playerColumnLayout.implicitWidth
                height: playerColumnLayout.implicitHeight

                DragHandler {
                    target: null
                    onActiveChanged: {
                        if (active) {
                            panelWindow.dragStartX = panelWindow.dragX
                            panelWindow.dragStartY = panelWindow.dragY
                        }
                    }
                    onTranslationChanged: {
                        if (active) {
                            panelWindow.dragX = panelWindow.dragStartX + translation.x
                            panelWindow.dragY = panelWindow.dragStartY + translation.y
                        }
                    }
                }

                ColumnLayout {
                    id: playerColumnLayout
                    spacing: -Appearance.sizes.elevationMargin

                    Repeater {
                        model: ScriptModel {
                            values: root.meaningfulPlayers
                        }
                        delegate: Player {
                            implicitHeight: showLyrics ? 290 : Appearance.sizes.mediaControlsHeight
                            required property MprisPlayer modelData
                            player: modelData
                            visualizerPoints: root.visualizerPoints
                            implicitWidth: showLyrics ? root.widgetWidth + 150 : root.widgetWidth
                            radius: root.popupRounding
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.leftMargin: Appearance.sizes.hyprlandGapsOut
                        Layout.rightMargin: Appearance.sizes.hyprlandGapsOut
                        visible: root.meaningfulPlayers.length === 0
                        implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
                        implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

                        StyledRectangularShadow {
                            target: placeholderBackground
                        }

                        Rectangle {
                            id: placeholderBackground
                            anchors.centerIn: parent
                            color: Appearance.colors.colLayer0
                            radius: root.popupRounding
                            property real padding: 20
                            implicitWidth: placeholderLayout.implicitWidth + padding * 2
                            implicitHeight: placeholderLayout.implicitHeight + padding * 2

                            ColumnLayout {
                                id: placeholderLayout
                                anchors.centerIn: parent

                                StyledText {
                                    text: Translation.tr("No active player")
                                    font.pixelSize: Appearance.font.pixelSize.large
                                }
                                StyledText {
                                    color: Appearance.colors.colSubtext
                                    text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            mediaControlsLoader.active = !mediaControlsLoader.active;
            if (mediaControlsLoader.active)
                Notifications.timeoutAll();
        }

        function close(): void {
            mediaControlsLoader.active = false;
        }

        function open(): void {
            mediaControlsLoader.active = true;
            Notifications.timeoutAll();
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: "Toggles media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
        }
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: "Opens media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = true;
        }
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: "Closes media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = false;
        }
    }
}
