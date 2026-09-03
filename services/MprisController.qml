pragma Singleton
pragma ComponentBehavior: Bound

// From https://git.outfoxxed.me/outfoxxed/nixnew
// It does not have a license, but the author is okay with redistribution.

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * A service that provides easy access to the active Mpris player.
 */
Singleton {
	id: root;
	property list<MprisPlayer> players: Mpris.players.values.filter(p => root.isRealPlayer(p));
	property MprisPlayer trackedPlayer: null;
	// Never expose a deduped/native duplicate as the active player: if the tracked
	// one got filtered out (e.g. the browser's native bus), fall back to a real one.
	property MprisPlayer activePlayer: (trackedPlayer && root.isRealPlayer(trackedPlayer))
		? trackedPlayer : (root.players[0] ?? null);
	signal trackChanged(reverse: bool);

	property bool __reverse: false;

	property var activeTrack;

	// Browsers expose BOTH a native MPRIS bus (often without album art) and the
	// richer Plasma browser-integration bus for the same tab. Only treat the
	// native bus as a duplicate when this Plasma bus is actually present.
	readonly property bool plasmaPlayerPresent: Mpris.players.values.some(p =>
		p.dbusName?.startsWith('org.mpris.MediaPlayer2.plasma-browser-integration'));

	property bool hasPlasmaIntegration: false
    Process {
        id: plasmaIntegrationAvailabilityCheckProc
        running: true
        command: ["bash", "-c", "command -v plasma-browser-integration-host"]
        onExited: (exitCode, exitStatus) => {
            root.hasPlasmaIntegration = (exitCode === 0);
        }
    }
	function isRealPlayer(player) {
        if (!Config.options.media.filterDuplicatePlayers) {
            return true;
        }
        return (
            // Remove unnecessary native buses from browsers, but only when the richer
            // Plasma browser-integration bus is actually present for the same tab.
            // Without it the native bus is the only one there is, so keep it.
            !(root.plasmaPlayerPresent && (player.dbusName?.startsWith('org.mpris.MediaPlayer2.firefox') || player.dbusName?.startsWith('org.mpris.MediaPlayer2.chromium'))) &&
            // playerctld just copies other buses and we don't need duplicates
            !player.dbusName?.startsWith('org.mpris.MediaPlayer2.playerctld') &&
            // Non-instance mpd bus
            !(player.dbusName?.endsWith('.mpd') && !player.dbusName.endsWith('MediaPlayer2.mpd')));
    }

	// Cover-art fallback: some players (Firefox's native MPRIS bus) publish
	// title/artist/album but never mpris:artUrl. When the active track has no
	// art, look it up on the iTunes Search API and cache it; consumers fall
	// back to this when the player itself offers nothing.
	property string fetchedArtUrl: ""
	// The art consumers should display for the active track. Prefer what the
	// player publishes, but survive plasma-browser-integration's habit of
	// re-publishing the previous track's artwork after a skip (it only
	// corrects itself on the next pause/play) - see fetchArtFallback below.
	readonly property string coverArtUrl: root.activeTrack?.artUrl ?? ""
	Process {
		id: artFetchProc
		property string artist: ""
		property string title: ""
		property string album: ""
		// The player's artUrl at request time: "" when it had none, or the
		// suspected-stale URL carried over from the previous track.
		property string supersedes: ""
		command: [Quickshell.shellPath("scripts/images/fetch_cover_art.sh"), artist, title, album, Directories.coverArt]
		stdout: StdioCollector {
			onStreamFinished: {
				const path = text.trim();
				if (path.length === 0) return;
				// A killed fetch still delivers its buffered stdout after the
				// next one was requested. The cache filename embeds
				// md5(artist|album|title), so accept only the current request.
				if (path.indexOf(Qt.md5(`${artFetchProc.artist}|${artFetchProc.album}|${artFetchProc.title}`)) === -1) return;
				// If the player has since published fresh art of its own for
				// this track, that wins over the lookup.
				const playerArt = root.activePlayer?.trackArtUrl ?? "";
				if (playerArt && playerArt !== artFetchProc.supersedes) return;
				root.fetchedArtUrl = "file://" + path;
				// Patch the already-published track object so consumers pick
				// the art up without a track-change animation.
				if (root.activeTrack) {
					root.activeTrack.artUrl = root.fetchedArtUrl;
					root.activeTrackChanged();
				}
			}
		}
	}
	function fetchArtFallback() {
		const title = this.activePlayer?.trackTitle ?? "";
		const artist = this.activePlayer?.trackArtist ?? "";
		this.fetchedArtUrl = "";
		artFetchProc.running = false;
		if (!title) return; // nothing to search by
		artFetchProc.artist = artist;
		artFetchProc.title = title;
		artFetchProc.album = this.activePlayer?.trackAlbum ?? "";
		artFetchProc.supersedes = this.activePlayer?.trackArtUrl ?? "";
		artFetchProc.running = true;
	}

	// Original stuff from fox below
	Instantiator {
		model: Mpris.players;

		Connections {
			required property MprisPlayer modelData;
			target: modelData;

			Component.onCompleted: {
				if (root.isRealPlayer(modelData) && (root.trackedPlayer == null || modelData.isPlaying)) {
					root.trackedPlayer = modelData;
				}
			}

			Component.onDestruction: {
				if (root.trackedPlayer == null || !root.trackedPlayer.isPlaying) {
					for (const player of root.players) {
						if (player.isPlaying) {
							root.trackedPlayer = player;
							break;
						}
					}

					if (trackedPlayer == null && root.players.length != 0) {
						trackedPlayer = root.players[0];
					}
				}
			}

			function onPlaybackStateChanged() {
				if (root.isRealPlayer(modelData) && root.trackedPlayer !== modelData) root.trackedPlayer = modelData;
			}
		}
	}

	Connections {
		target: activePlayer

		function onPostTrackChanged() {
			root.updateTrack();
		}

		function onTrackArtUrlChanged() {
			// console.log("arturl:", activePlayer.trackArtUrl)
			// root.updateTrack();
			if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
				// cantata likes to send cover updates *BEFORE* updating the track info.
				// as such, art url changes shouldn't be able to break the reverse animation
				const r = root.__reverse;
				root.updateTrack();
				root.__reverse = r;

			}
		}
	}

	onActivePlayerChanged: this.updateTrack();

	// The artUrl the player last claimed, across tracks - used to spot a
	// track change where the player kept publishing the previous artwork.
	property string __lastPlayerArt: ""

	function updateTrack() {
		//console.log(`update: ${this.activePlayer?.trackTitle ?? ""} : ${this.activePlayer?.trackArtists}`)
		const newId = this.activePlayer?.uniqueId ?? 0;
		const playerArt = this.activePlayer?.trackArtUrl ?? "";
		const prev = this.activeTrack;
		const isNewTrack = !prev || prev.uniqueId !== newId;
		// Same track with the art momentarily gone from the bus (metadata
		// updates during transitions/ads drop mpris:artUrl): keep what we had.
		const artUrl = (!isNewTrack && !playerArt) ? prev.artUrl : playerArt;

		this.activeTrack = {
			uniqueId: newId,
			artUrl: artUrl,
			title: this.activePlayer?.trackTitle || Translation.tr("Unknown Title"),
			artist: this.activePlayer?.trackArtist || Translation.tr("Unknown Artist"),
			album: this.activePlayer?.trackAlbum || Translation.tr("Unknown Album"),
		};

		this.trackChanged(__reverse);
		this.__reverse = false;

		// Look the art up ourselves when the player has none for a new track,
		// or when a new track arrived with the previous track's artwork URL
		// unchanged: plasma-browser-integration often fails to refresh
		// artwork on skips (it only corrects on a later pause/play). An
		// unchanged URL on a new track is either that staleness or a
		// same-album track, and the lookup returns the right image for both.
		if (isNewTrack && (!playerArt || playerArt === this.__lastPlayerArt)) this.fetchArtFallback();
		if (playerArt) this.__lastPlayerArt = playerArt;
	}

	property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying;
	property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false;
	function togglePlaying() {
		if (this.canTogglePlaying) this.activePlayer.togglePlaying();
	}

	property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false;
	function previous() {
		if (this.canGoPrevious) {
			this.__reverse = true;
			this.activePlayer.previous();
		}
	}

	property bool canGoNext: this.activePlayer?.canGoNext ?? false;
	function next() {
		if (this.canGoNext) {
			this.__reverse = false;
			this.activePlayer.next();
		}
	}

	property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl;

	property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl;
	property var loopState: this.activePlayer?.loopState ?? MprisLoopState.None;
	function setLoopState(loopState: var) {
		if (this.loopSupported) {
			this.activePlayer.loopState = loopState;
		}
	}

	property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl;
	property bool hasShuffle: this.activePlayer?.shuffle ?? false;
	function setShuffle(shuffle: bool) {
		if (this.shuffleSupported) {
			this.activePlayer.shuffle = shuffle;
		}
	}

	function setActivePlayer(player: MprisPlayer) {
		const targetPlayer = player ?? Mpris.players[0];
		console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

		if (targetPlayer && this.activePlayer) {
			this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer);
		} else {
			// always animate forward if going to null
			this.__reverse = false;
		}

		this.trackedPlayer = targetPlayer;
	}

	IpcHandler {
		target: "mpris"

		function pauseAll(): void {
			for (const player of Mpris.players.values) {
				if (player.canPause) player.pause();
			}
		}

		function activeInfo(): string {
			return JSON.stringify({
				tracked: root.trackedPlayer?.dbusName ?? null,
				active: root.activePlayer?.dbusName ?? null,
				activeArtUrl: root.activePlayer?.trackArtUrl ?? "",
				activeTitle: root.activePlayer?.trackTitle ?? "",
				trackArt: root.activeTrack?.artUrl ?? "",
				trackTitle: root.activeTrack?.title ?? "",
				fetched: root.fetchedArtUrl,
				players: root.players.map(p => p.dbusName),
			}, null, 1);
		}

		function playPause(): void { root.togglePlaying(); }
		function previous(): void { root.previous(); }
		function next(): void { root.next(); }
	}
}
