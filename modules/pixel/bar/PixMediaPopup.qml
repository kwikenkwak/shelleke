import QtQuick
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Media hover popup content for the pixel bar. Monochrome throughout EXCEPT the
 * album art, which is the one sanctioned color exception: it is rendered with a
 * plain Image (not PixAppIcon) inside a hard-bordered square frame.
 *
 * Bound to MprisController.activePlayer (null-safe): track title/artist + the
 * previous / play-pause / next transport controls. When nothing is playing the
 * popup shows a muted "Nothing playing".
 */
Row {
    id: root
    spacing: 14

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null
    readonly property string trackTitle: player?.trackTitle ?? ""
    readonly property string trackArtist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property bool isPlaying: MprisController.isPlaying

    // ---- Album art (COLOR exception) in a hard-bordered square frame ----
    PixPanel {
        id: artFrame
        anchors.verticalCenter: parent.verticalCenter
        borderWidth: PixTheme.borderWidth
        implicitWidth: 72
        implicitHeight: 72

        Image {
            id: art
            anchors.fill: parent
            anchors.margins: PixTheme.borderWidth
            visible: root.artUrl !== "" && status === Image.Ready
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: false
            mipmap: false
            cache: true
        }

        // Placeholder pixel note glyph when there's no cover art.
        PixIcon {
            anchors.centerIn: parent
            visible: !art.visible
            name: "note"
            size: 28
            color: PixTheme.colors.grey
        }
    }

    // ---- Text + transport controls ----
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        PixTitle {
            id: titleText
            width: 200
            visible: root.hasPlayer
            text: root.trackTitle !== "" ? root.trackTitle : "Unknown Title"
            font.pixelSize: PixTheme.font.pixelSize.title
            elide: Text.ElideRight
        }

        PixText {
            width: 200
            visible: root.hasPlayer
            text: root.trackArtist
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.normal
            elide: Text.ElideRight
        }

        PixText {
            visible: !root.hasPlayer
            text: "Nothing playing"
            color: PixTheme.colors.grey
            font.pixelSize: PixTheme.font.pixelSize.large
        }

        // Transport controls
        Row {
            visible: root.hasPlayer
            spacing: 8

            // Previous
            PixButton {
                id: prevBtn
                implicitWidth: 34
                implicitHeight: 34
                interactive: MprisController.canGoPrevious
                onClicked: MprisController.previous()
                PixIcon {
                    anchors.centerIn: parent
                    name: "chevL"
                    size: 14
                    color: prevBtn.contentColor
                }
            }

            // Play / pause (simple Rectangle glyphs so it reads unambiguously)
            PixButton {
                id: playBtn
                implicitWidth: 34
                implicitHeight: 34
                interactive: MprisController.canTogglePlaying
                onClicked: MprisController.togglePlaying()

                // Pause: two bars
                Row {
                    anchors.centerIn: parent
                    visible: root.isPlaying
                    spacing: 4
                    Repeater {
                        model: 2
                        Rectangle {
                            width: 4
                            height: 14
                            radius: 0
                            antialiasing: false
                            color: playBtn.contentColor
                        }
                    }
                }

                // Play: filled triangle drawn from stacked Rectangles
                Canvas {
                    id: playGlyph
                    anchors.centerIn: parent
                    visible: !root.isPlaying
                    width: 14
                    height: 14
                    antialiasing: false
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = playBtn.contentColor;
                        ctx.beginPath();
                        ctx.moveTo(1, 0);
                        ctx.lineTo(13, 7);
                        ctx.lineTo(1, 14);
                        ctx.closePath();
                        ctx.fill();
                    }
                    Connections {
                        target: playBtn
                        function onContentColorChanged() { playGlyph.requestPaint(); }
                    }
                }
            }

            // Next
            PixButton {
                id: nextBtn
                implicitWidth: 34
                implicitHeight: 34
                interactive: MprisController.canGoNext
                onClicked: MprisController.next()
                PixIcon {
                    anchors.centerIn: parent
                    name: "chevR"
                    size: 14
                    color: nextBtn.contentColor
                }
            }
        }
    }
}
