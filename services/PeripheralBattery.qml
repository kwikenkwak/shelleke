pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower

/**
 * Batteries of connected PERIPHERALS — headphones, earbuds, speakers, mice,
 * keyboards — as opposed to `Battery`, which is the laptop's own cell.
 *
 * Two sources, merged and deduplicated by MAC address:
 *   UPower   — the primary one. UPower's BlueZ backend publishes a device per
 *              connected peripheral that reports a battery, and it is the only
 *              source that knows a charge STATE (a charging case, say).
 *   BlueZ    — the fallback, via Quickshell.Bluetooth. Covers devices that
 *              expose `org.bluez.Battery1` before UPower has picked them up.
 * Both report their level as 0..1, like `Battery.percentage`.
 *
 * A UPower entry that matches a Bluetooth device which is NOT connected is
 * dropped: UPower can hold a device (with its last known level) for a moment
 * after the peripheral goes away, and a bar chip that lingers reads as a bug.
 *
 * Each entry is a plain object:
 *   { name, percentage (0..1), kind, charging, address, audio }
 * `kind` is one of "earbuds" | "headphones" | "speaker" | "mouse" |
 * "keyboard" | "phone" | "generic" — a semantic label, NOT an icon name; each
 * panel family maps it onto its own glyph set.
 *
 *   PeripheralBattery.available            // any audio peripheral reporting?
 *   PeripheralBattery.primary.percentage   // the one the bar shows
 */
Singleton {
    id: root

    /// UPower device types worth reporting. Anything else (line power, the
    /// laptop cell, UPSes, monitors) is not a peripheral battery.
    readonly property var peripheralTypes: [UPowerDeviceType.Headset, UPowerDeviceType.Headphones, UPowerDeviceType.Speakers, UPowerDeviceType.OtherAudio, UPowerDeviceType.Mouse, UPowerDeviceType.Keyboard, UPowerDeviceType.Phone, UPowerDeviceType.GamingInput, UPowerDeviceType.Pen, UPowerDeviceType.Tablet, UPowerDeviceType.Wearable, UPowerDeviceType.BluetoothGeneric]

    readonly property var audioKinds: ["earbuds", "headphones", "speaker"]

    /// "/org/bluez/hci0/dev_2C_BE_EE_2C_C0_16" -> "2C:BE:EE:2C:C0:16".
    /// Returns "" for anything that is not a BlueZ path.
    function addressFromPath(path: string): string {
        const m = /dev_([0-9A-Fa-f_]{17})$/.exec(path ?? "");
        return m ? m[1].replace(/_/g, ":").toUpperCase() : "";
    }

    function bluetoothFor(address: string): var {
        if (address === "")
            return null;
        return Bluetooth.devices.values.find(d => (d.address ?? "").toUpperCase() === address) ?? null;
    }

    /**
     * What KIND of thing this is, from the UPower type, the BlueZ icon name and
     * the product name — in that order of specificity, except that the name is
     * what separates earbuds from over-ear cans (BlueZ calls both a "headset",
     * and UPower inherits that).
     */
    function kindFor(type: int, icon: string, name: string): string {
        const n = (name ?? "").toLowerCase();
        if (icon === "audio-earbud" || /\b(buds?|pods?|earphones?|in-?ear)\b/.test(n))
            return "earbuds";
        if (type === UPowerDeviceType.Headphones || type === UPowerDeviceType.Headset || icon === "audio-headset" || icon === "audio-headphones")
            return "headphones";
        if (type === UPowerDeviceType.Speakers || type === UPowerDeviceType.OtherAudio || icon === "audio-speakers" || icon === "audio-card")
            return "speaker";
        if (type === UPowerDeviceType.Mouse || icon === "input-mouse")
            return "mouse";
        if (type === UPowerDeviceType.Keyboard || icon === "input-keyboard")
            return "keyboard";
        if (type === UPowerDeviceType.Phone || icon === "phone")
            return "phone";
        return "generic";
    }

    /// Every peripheral currently reporting a battery, audio ones first.
    readonly property list<var> devices: {
        const out = [];
        const seen = ({});

        for (const d of UPower.devices.values) {
            if (!d.ready || d.powerSupply || d.isLaptopBattery)
                continue;
            if (!root.peripheralTypes.includes(d.type))
                continue;
            // UPower reports 0 for "unknown", not for a flat peripheral.
            const percentage = d.percentage ?? 0;
            if (percentage <= 0)
                continue;

            const address = root.addressFromPath(d.nativePath);
            const bt = root.bluetoothFor(address);
            if (bt && !bt.connected)
                continue;

            const name = (bt?.name ?? "") !== "" ? bt.name : ((d.model ?? "") !== "" ? d.model : "Peripheral");
            const kind = root.kindFor(d.type, bt?.icon ?? "", name);
            if (address !== "")
                seen[address] = true;
            out.push({
                name: name,
                percentage: percentage,
                kind: kind,
                charging: d.state === UPowerDeviceState.Charging,
                address: address,
                audio: root.audioKinds.includes(kind)
            });
        }

        for (const b of Bluetooth.devices.values) {
            if (!b.connected || !b.batteryAvailable)
                continue;
            const address = (b.address ?? "").toUpperCase();
            if (seen[address])
                continue;
            const percentage = b.battery ?? 0;
            if (percentage <= 0)
                continue;

            const name = (b.name ?? "") !== "" ? b.name : address;
            const kind = root.kindFor(-1, b.icon ?? "", name);
            seen[address] = true;
            out.push({
                name: name,
                percentage: percentage,
                kind: kind,
                charging: false,
                address: address,
                audio: root.audioKinds.includes(kind)
            });
        }

        // Audio first (that is what the bar shows), then alphabetically, so the
        // chip does not jump between devices as levels change.
        out.sort((a, b) => (a.audio === b.audio) ? a.name.localeCompare(b.name) : (a.audio ? -1 : 1));
        return out;
    }

    readonly property list<var> audioDevices: root.devices.filter(d => d.audio)

    /// The device the bar reports. Null when nothing audio is connected.
    readonly property var primary: root.audioDevices[0] ?? null
    readonly property bool available: root.primary !== null

    readonly property real percentage: root.primary?.percentage ?? 0
    readonly property string kind: root.primary?.kind ?? "headphones"
    readonly property string name: root.primary?.name ?? ""
    readonly property bool charging: root.primary?.charging ?? false
}
