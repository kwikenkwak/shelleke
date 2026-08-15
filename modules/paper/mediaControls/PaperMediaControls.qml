pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * PaperMediaControls — §4.7 Media controls of the paper family.
 *
 *   design/paper-a-hairline/SPEC.md   §4.7   design/paper-b-ledger/SPEC.md §4.6
 *   design/paper-c-broadsheet/SPEC.md §4.7   design/current-pixels/SPEC.md §4.7
 *
 * The window mechanism is copied from modules/pixel/mediaControls/
 * PixelMediaControls.qml verbatim, including HANDOFF gotcha #4: the layer
 * surface keeps a FIXED implicitHeight and only the inner card animates its
 * height between `size.mediaCollapsed` and `size.mediaExpanded` with
 * `clip: true`. Resizing a layer surface flickers on Hyprland. The surface is
 * masked to the card so the transparent remainder stays click-through, and the
 * same IpcHandler target ("mediaControls") and three GlobalShortcut names are
 * declared so the user's binds keep working.
 *
 * ALBUM ART IS THE ONE PLACE FULL COLOUR REACHES THE SCREEN in this shell — it
 * is a plain Image in a framed well and must never go through PaperAppIcon.
 *
 *   hairline   — 480 wide, no boxes: bare transport glyphs 26 px apart, the
 *                1 px meter with its head dot, and the player identity in
 *                micro-caps pushed to the right.
 *   ledger     — 440 wide, flush left; a ruled cell of three transport buttons
 *                and the blue ruler seek bar.
 *   broadsheet — 460 wide with corner ticks; the album art is mounted like a
 *                plate in a book (3 px paper mount, hairline frame, hairline
 *                printed just inside the image), oldstyle timestamps, and the
 *                rule gauge minus its ticks.
 */
Scope {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool lyricsEnabled: Config.options.media.lyrics.enabled
    readonly property bool lyricsShown: root.lyricsEnabled && Config.options.media.lyrics.show

    function hide(): void {
        GlobalStates.mediaControlsOpen = false;
    }

    PanelWindow {
        id: mediaRoot
        visible: GlobalStates.mediaControlsOpen

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "quickshell:paperMediaControls"

        implicitWidth: PaperTheme.size.mediaWidth
        // FIXED surface height — never animates. See the header.
        implicitHeight: root.lyricsEnabled ? PaperTheme.size.mediaExpanded : PaperTheme.size.mediaCollapsed

        anchors {
            top: !(Config.options.bar.bottom ?? false)
            bottom: (Config.options.bar.bottom ?? false)
            left: true
        }
        margins {
            top: PaperTheme.barPopupOffset
            bottom: PaperTheme.barHeight
            left: 0
        }

        // Only the visible card is interactive; clicking elsewhere dismisses
        // through the focus grab.
        mask: Region {
            item: card
        }

        HyprlandFocusGrab {
            windows: [mediaRoot]
            active: GlobalStates.mediaControlsOpen
            onCleared: () => {
                if (!active)
                    root.hide();
            }
        }

        PaperPanel {
            id: card
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            kind: "sheet"
            floating: true
            ticks: true
            // Flush with the left screen edge, so that border is dropped —
            // a sheet slid halfway out of the drawer (§4.6 of B).
            edgeLeft: false
            clip: true
            focus: GlobalStates.mediaControlsOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.hide();
                    event.accepted = true;
                }
            }

            readonly property MprisPlayer player: root.activePlayer
            readonly property bool hasPlayer: card.player !== null
            readonly property int playerHeight: PaperTheme.size.mediaCollapsed
            readonly property int padV: PaperTheme.pick(20, 14, 14)
            readonly property int padH: PaperTheme.pick(20, 16, 16)

            /// "Album · Year". MPRIS only guarantees the album; the year is
            /// dug out of xesam:contentCreated when the player supplies it.
            readonly property string albumLine: {
                const album = card.player?.trackAlbum ?? "";
                const created = card.player?.metadata?.["xesam:contentCreated"] ?? "";
                const year = (typeof created === "string") ? (created.match(/\d{4}/)?.[0] ?? "") : "";
                if (album === "")
                    return year;
                return year === "" ? album : `${album} · ${year}`;
            }

            // ONLY the card animates; the surface stays fixed.
            // C shortens the card to 110 px when there is no player (§4.7);
            // A and B keep the collapsed height.
            height: !card.hasPlayer ? (PaperTheme.isBroadsheet ? 110 : card.playerHeight) : (root.lyricsShown ? PaperTheme.size.mediaExpanded : card.playerHeight)
            Behavior on height {
                NumberAnimation {
                    duration: PaperTheme.motion.card
                    easing.type: PaperTheme.motion.type
                    easing.bezierCurve: PaperTheme.motion.bezierCurve
                }
            }

            // ---------------------------------------- no-player placeholder
            // Deliberately NOT `PaperEmpty`. That widget is a one-line 11 px
            // list placeholder ("No notifications") sized to sit inside a list;
            // this is the card's whole body — a centred note glyph over a lead
            // line, plus ledger's second line and its framed slot. Swapping it
            // would empty the card rather than fill it.
            Column {
                anchors.centerIn: parent
                visible: !card.hasPlayer && PaperTheme.isHairline
                spacing: PaperTheme.spacing.medium
                PaperIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "note"
                    size: 24
                    color: PaperTheme.ink4
                }
                PaperText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No active player"
                    role: "meta"
                    tone: "ink4"
                }
            }
            Row {
                anchors.centerIn: parent
                visible: !card.hasPlayer && !PaperTheme.isHairline
                spacing: PaperTheme.pick(11, 11, 10)

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: PaperTheme.pick(18, 32, 18)
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        visible: PaperTheme.isLedger
                        color: "transparent"
                        radius: PaperTheme.radiusControl
                        antialiasing: radius > 0
                        border.width: PaperTheme.ruleWidth
                        border.color: PaperTheme.rule
                    }
                    PaperIcon {
                        anchors.centerIn: parent
                        name: "note"
                        size: PaperTheme.pick(18, 17, 18)
                        color: PaperTheme.ink4
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: PaperTheme.spacing.hair
                    PaperTitle {
                        text: "No active player"
                        role: "lead"
                        caps: false
                        tone: PaperTheme.isBroadsheet ? "ink3" : "ink"
                        // C sets the empty state in Pagella italic.
                        font.italic: PaperTheme.italicPlaceholders
                        font.features: PaperTheme.font.features.none
                    }
                    PaperText {
                        visible: PaperTheme.isLedger
                        text: "Nothing is playing on MPRIS"
                        role: "meta"
                        tone: "ink3"
                    }
                }
            }

            // -------------------------------------------------- player area
            RowLayout {
                id: playerArea
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: card.padV
                    leftMargin: card.padH
                    rightMargin: card.padH
                }
                // Bounded so content never spills past the collapsed height.
                height: card.playerHeight - 2 * card.padV
                visible: card.hasPlayer
                spacing: PaperTheme.pick(18, 14, 14)

                // ---- album art: THE one sanctioned colour exception -------
                Item {
                    id: artMount
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: PaperTheme.size.albumArt + 2 * artMount.mount
                    Layout.preferredHeight: PaperTheme.size.albumArt + 2 * artMount.mount
                    /// C mounts the plate on 3 px of paper, like a plate in a
                    /// book; A and B frame the image directly.
                    readonly property int mount: PaperTheme.pick(0, 0, 3)

                    Rectangle {
                        anchors.fill: parent
                        color: PaperTheme.paper
                        radius: PaperTheme.radiusCard
                        antialiasing: radius > 0
                        border.width: PaperTheme.ruleWidth
                        border.color: PaperTheme.rule2
                    }

                    // The well behind the art — visible when there is no cover.
                    Rectangle {
                        id: artWell
                        anchors.fill: parent
                        anchors.margins: artMount.mount + PaperTheme.ruleWidth
                        color: PaperTheme.paperSunk
                        antialiasing: false

                        Image {
                            id: art
                            anchors.fill: parent
                            visible: art.status === Image.Ready
                            source: card.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: false
                        }

                        // C prints a hairline just inside the image, so the
                        // plate reads as pasted onto the page.
                        Rectangle {
                            anchors.fill: parent
                            visible: PaperTheme.isBroadsheet && art.visible
                            color: "transparent"
                            border.width: PaperTheme.ruleWidth
                            border.color: Qt.rgba(PaperTheme.paper.r, PaperTheme.paper.g, PaperTheme.paper.b, 0.35)
                            antialiasing: false
                        }

                        PaperIcon {
                            anchors.centerIn: parent
                            visible: !art.visible
                            name: "note"
                            size: PaperTheme.pick(28, 28, 26)
                            color: PaperTheme.ink4
                        }
                    }
                }

                // ---- info + controls -------------------------------------
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout { // title + lyrics toggle
                        Layout.fillWidth: true
                        spacing: PaperTheme.pick(12, 9, 8)

                        PaperTitle {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: StringUtils.cleanMusicTitle(card.player?.trackTitle) || "Untitled"
                            // A has no display face: the title is body type at
                            // `lead`. B is Charter 16 bold, C is Pagella 17.
                            role: PaperTheme.isHairline ? "lead" : "title"
                            caps: false
                            font.weight: PaperTheme.pick(Font.Normal, Font.Bold, Font.Normal)
                            // The media title is set in caps-and-lower, not in
                            // C's small caps.
                            font.features: PaperTheme.font.features.none
                            elide: Text.ElideRight
                        }

                        PaperButton {
                            id: lyricsToggle
                            Layout.alignment: Qt.AlignVCenter
                            visible: root.lyricsEnabled
                            shape: "icon"
                            // A's button IS its glyph; B and C frame it.
                            ghost: PaperTheme.isHairline
                            icon: "message"
                            iconSize: PaperTheme.pick(16, 14, 14)
                            implicitWidth: PaperTheme.pick(24, 26, 28)
                            implicitHeight: PaperTheme.pick(24, 24, 24)
                            checked: root.lyricsShown
                            onClicked: Config.options.media.lyrics.show = !Config.options.media.lyrics.show
                        }
                    }

                    PaperText {
                        Layout.fillWidth: true
                        Layout.topMargin: PaperTheme.pick(4, 3, 2)
                        text: card.player?.trackArtist ?? ""
                        role: PaperTheme.pick("small", "small", "meta")
                        tone: PaperTheme.isBroadsheet ? "ink3" : "ink2"
                        elide: Text.ElideRight
                    }

                    PaperText {
                        Layout.fillWidth: true
                        Layout.topMargin: PaperTheme.spacing.hair
                        visible: text !== ""
                        text: card.albumLine
                        // B sets the album in micro-caps; C in Pagella italic.
                        role: PaperTheme.pick("meta", "micro", "meta")
                        tone: "ink3"
                        footnote: PaperTheme.isBroadsheet
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillHeight: true
                    } // spacer — transport is pinned to the bottom

                    RowLayout { // elapsed … total
                        Layout.fillWidth: true
                        Layout.bottomMargin: PaperTheme.pick(9, 5, 4)
                        spacing: PaperTheme.spacing.small

                        PaperText {
                            Layout.fillWidth: true
                            text: StringUtils.friendlyTimeForSeconds(card.player?.position ?? 0)
                            // C's timestamps are Pagella oldstyle figures.
                            figure: true
                            role: "meta"
                            tone: "ink3"
                            font.pixelSize: PaperTheme.pick(11, 10, 11)
                        }
                        PaperText {
                            text: StringUtils.friendlyTimeForSeconds(card.player?.length ?? 0)
                            figure: true
                            role: "meta"
                            tone: PaperTheme.isLedger ? "ink4" : "ink3"
                            font.pixelSize: PaperTheme.pick(11, 10, 11)
                        }
                    }

                    PaperMeter { // the seek bar
                        id: seekBar
                        Layout.fillWidth: true
                        readonly property real len: card.player?.length ?? 0
                        readonly property real pos: card.player?.position ?? 0
                        value: seekBar.len > 0 ? seekBar.pos / seekBar.len : 0
                        interactive: card.player?.canSeek ?? false
                        // B keeps its ruler; C is "the ruled gauge again, minus
                        // its ticks"; A never had any.
                        ticks: PaperTheme.isLedger
                        onSeek: position => {
                            if (card.player && seekBar.len > 0)
                                card.player.position = position * seekBar.len;
                        }

                        Timer { // advance the head once a second while playing
                            running: (card.player?.isPlaying ?? false) && mediaRoot.visible
                            interval: 1000
                            repeat: true
                            onTriggered: card.player?.positionChanged()
                        }
                    }

                    RowLayout { // transport
                        Layout.fillWidth: true
                        Layout.topMargin: PaperTheme.pick(16, 12, 10)
                        spacing: PaperTheme.pick(26, 8, 10)

                        PaperButton {
                            shape: "icon"
                            ghost: PaperTheme.isHairline
                            icon: "prev"
                            iconSize: PaperTheme.pick(20, 14, 15)
                            implicitWidth: PaperTheme.pick(20, 38, 42)
                            implicitHeight: PaperTheme.pick(20, 28, 30)
                            onClicked: MprisController.previous()
                        }
                        PaperButton {
                            id: playButton
                            // B and C make play/pause the wide centre cell of a
                            // ruled row of three; A leaves three bare glyphs.
                            Layout.fillWidth: !PaperTheme.isHairline
                            shape: "icon"
                            ghost: PaperTheme.isHairline
                            implicitWidth: PaperTheme.pick(20, 120, 120)
                            implicitHeight: PaperTheme.pick(20, 28, 30)
                            onClicked: MprisController.togglePlaying()

                            // Drawn as a child rather than through `icon:` so A
                            // can print it in full `ink` — its transport is
                            // "prev, play/pause in ink, next" — WITHOUT taking
                            // the checked underline, which would read as a
                            // toggle. B and C track the button's own state.
                            PaperIcon {
                                anchors.centerIn: parent
                                name: MprisController.isPlaying ? "pause" : "play"
                                size: PaperTheme.pick(20, 14, 15)
                                color: PaperTheme.isHairline ? PaperTheme.ink : playButton.contentColor
                            }
                        }
                        PaperButton {
                            shape: "icon"
                            ghost: PaperTheme.isHairline
                            icon: "next"
                            iconSize: PaperTheme.pick(20, 14, 15)
                            implicitWidth: PaperTheme.pick(20, 38, 42)
                            implicitHeight: PaperTheme.pick(20, 28, 30)
                            onClicked: MprisController.next()
                        }
                        Item {
                            Layout.fillWidth: PaperTheme.isHairline
                            visible: PaperTheme.isHairline
                        }
                        PaperText { // A only: the player identity, pushed right
                            Layout.alignment: Qt.AlignVCenter
                            visible: PaperTheme.isHairline
                            text: `MPRIS · ${card.player?.identity ?? ""}`
                            role: "micro"
                        }
                    }
                }
            }

            // ------------------------------------------- the fold + lyrics
            // C closes the player block with a DOUBLE rule; A and B degrade to
            // a single hairline, which is what PaperRule already does.
            PaperRule {
                id: fold
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: card.playerHeight
                }
                weight: "double"
                visible: card.hasPlayer && card.height > card.playerHeight + 1
            }

            MediaLyricsView {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: card.padH
                    rightMargin: card.padH
                }
                y: card.playerHeight + fold.thickness + PaperTheme.pick(18, 12, 10)
                height: PaperTheme.size.mediaExpanded - y - PaperTheme.pick(18, 14, 14)
                // Mounted through the reveal; unmounted once collapsed.
                visible: card.hasPlayer && card.height > card.playerHeight + 1
                player: card.player
            }
        }
    }

    // Same IPC target + GlobalShortcut names as the ii/pixel media controls.
    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
        }
        function close(): void {
            GlobalStates.mediaControlsOpen = false;
        }
        function open(): void {
            GlobalStates.mediaControlsOpen = true;
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: "Toggles media controls on press"
        onPressed: GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: "Opens media controls on press"
        onPressed: GlobalStates.mediaControlsOpen = true
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: "Closes media controls on press"
        onPressed: GlobalStates.mediaControlsOpen = false
    }
}
