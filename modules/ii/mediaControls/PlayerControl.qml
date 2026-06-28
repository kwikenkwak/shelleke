pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item { // Player instance
    id: root
    required property MprisPlayer player
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000 // Max value in the data points
    property int visualizerSmoothing: 2 // Number of points to average for smoothing
    property real radius

    // Height of the player (non-lyrics) area; the popup grows below it for lyrics.
    property real playerHeight: 160
    readonly property real playerContentHeight: root.playerHeight - Appearance.sizes.elevationMargin * 2
    readonly property bool lyricsEnabled: Config.options.media.lyrics.enabled
    readonly property bool lyricsShown: root.lyricsEnabled && Config.options.media.lyrics.show
    property real lyricsPanelHeight: 210
    // The layer-shell surface stays a FIXED height: the compositor only animates a
    // surface grow (never a shrink) and resizing it per-frame stutters. Instead we
    // animate the inner card height in QML and reveal a fixed-size (cached) blur.
    // The area below the card is transparent and made click-through via maskHeight.
    readonly property real fullContentHeight: root.playerContentHeight + (root.lyricsEnabled ? root.lyricsPanelHeight : 0)
    implicitHeight: root.playerHeight + (root.lyricsEnabled ? root.lyricsPanelHeight : 0)

    // Visible card height (incl. elevation margins) — MediaControls masks input to this.
    readonly property real maskHeight: background.height + Appearance.sizes.elevationMargin * 2

    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24

        property var iconName
        colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple: blendedColors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer
            text: iconName

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    Timer { // Force update for revision
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: {
            root.player.positionChanged()
        }
    }

    onArtFilePathChanged: {
        if (root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            return;
        }

        // Binding does not work in Process
        coverArtDownloader.targetFile = root.artUrl 
        coverArtDownloader.artFilePath = root.artFilePath
        // Download
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: [ "bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'` ]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    StyledRectangularShadow {
        target: background
    }
    Rectangle { // Background
        id: background
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Appearance.sizes.elevationMargin
        }
        // Only this inner card animates; the surface stays fixed (see implicitHeight).
        // The rounded mask below tracks this height, so corners follow the reveal.
        height: root.lyricsShown ? root.fullContentHeight : root.playerContentHeight
        Behavior on height {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: root.radius

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            // Fixed full height so the blur is rasterized once and merely revealed by
            // the animating card (no re-blur per frame). The card's mask clips it.
            height: root.fullContentHeight
            source: root.displayedArtFilePath
            sourceSize.width: background.width
            sourceSize.height: root.fullContentHeight
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.playerContentHeight
            live: root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        RowLayout {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 13
            }
            height: root.playerContentHeight - 26
            spacing: 15

            Rectangle { // Art background
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: Appearance.rounding.verysmall
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                MaterialSymbol { // Placeholder when no art is available
                    anchors.centerIn: parent
                    visible: mediaArt.status !== Image.Ready
                    text: "music_note"
                    iconSize: Appearance.font.pixelSize.huge * 1.5
                    fill: 1
                    color: blendedColors.colOnLayer1
                }

                StyledImage { // Art image
                    id: mediaArt
                    property int size: parent.height
                    anchors.fill: parent

                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true

                    width: size
                    height: size
                    sourceSize.width: size
                    sourceSize.height: size
                }
            }

            ColumnLayout { // Info & controls
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        id: trackTitle
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: blendedColors.colOnLayer0
                        elide: Text.ElideRight
                        text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                        animateChange: true
                        animationDistanceX: 6
                        animationDistanceY: 0
                    }

                    RippleButton { // Lyrics toggle
                        id: lyricsToggle
                        visible: root.lyricsEnabled
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 28
                        implicitHeight: 28
                        toggled: root.lyricsShown
                        buttonRadius: height / 2
                        colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
                        colBackgroundHover: blendedColors.colSecondaryContainerHover
                        colBackgroundToggled: blendedColors.colPrimary
                        colBackgroundToggledHover: blendedColors.colPrimaryHover
                        colRipple: blendedColors.colSecondaryContainerActive
                        colRippleToggled: blendedColors.colPrimaryActive
                        releaseAction: () => {
                            Config.options.media.lyrics.show = !Config.options.media.lyrics.show;
                        }
                        contentItem: MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            text: "lyrics"
                            iconSize: Appearance.font.pixelSize.larger
                            fill: lyricsToggle.toggled ? 1 : 0
                            color: lyricsToggle.toggled ? blendedColors.colOnPrimary : blendedColors.colOnLayer0
                        }
                    }
                }
                StyledText {
                    id: trackArtist
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: root.player?.trackArtist
                    animateChange: true
                    animationDistanceX: 6
                    animationDistanceY: 0
                }
                Item { Layout.fillHeight: true }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                    StyledText {
                        id: trackTime
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        anchors.left: parent.left
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: blendedColors.colSubtext
                        elide: Text.ElideRight
                        text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                    }
                    RowLayout {
                        id: sliderRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        TrackChangeButton {
                            iconName: "skip_previous"
                            downAction: () => root.player?.previous()
                        }
                        Item {
                            id: progressBarContainer
                            Layout.fillWidth: true
                            implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                            Loader {
                                id: sliderLoader
                                anchors.fill: parent
                                active: root.player?.canSeek ?? false
                                sourceComponent: StyledSlider { 
                                    configuration: StyledSlider.Configuration.Wavy
                                    highlightColor: blendedColors.colPrimary
                                    trackColor: blendedColors.colSecondaryContainer
                                    handleColor: blendedColors.colPrimary
                                    value: root.player?.position / root.player?.length
                                    onMoved: {
                                        root.player.position = value * root.player.length;
                                    }
                                }
                            }

                            Loader {
                                id: progressBarLoader
                                anchors {
                                    verticalCenter: parent.verticalCenter
                                    left: parent.left
                                    right: parent.right
                                }
                                active: !(root.player?.canSeek ?? false)
                                sourceComponent: StyledProgressBar { 
                                    wavy: root.player?.isPlaying
                                    highlightColor: blendedColors.colPrimary
                                    trackColor: blendedColors.colSecondaryContainer
                                    value: root.player?.position / root.player?.length
                                }
                            }

                            
                        }
                        TrackChangeButton {
                            iconName: "skip_next"
                            downAction: () => root.player?.next()
                        }
                    }

                    RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        property real size: 44
                        implicitWidth: size
                        implicitHeight: size
                        downAction: () => root.player.togglePlaying();

                        buttonRadius: root.player?.isPlaying ? Appearance?.rounding.normal : size / 2
                        colBackground: root.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                        colBackgroundHover: root.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                        colRipple: root.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive

                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge
                            fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: root.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                            text: root.player?.isPlaying ? "pause" : "play_arrow"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }
                }
            }
        }

        LyricsView { // Live lyrics
            id: lyricsView
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: root.playerContentHeight
            }
            // Fixed position/height: the card's animating mask reveals or clips it.
            height: root.lyricsPanelHeight
            clip: true
            // Stay mounted through the reveal/collapse animation; hidden (timers off)
            // only once fully collapsed.
            visible: root.lyricsEnabled && background.height > root.playerContentHeight + 1
            player: root.player
            colors: root.blendedColors
        }
    }
}
