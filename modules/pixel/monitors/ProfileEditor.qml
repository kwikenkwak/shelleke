pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.pixel.common
import qs.modules.pixel.widgets

/**
 * Full editor for one hyprdynamicmonitors profile (or a brand-new one). Edits the
 * metadata block (required monitors, match mode, conditions, template values,
 * priority) and can capture the current live layout into the profile's template.
 * All writes go through the Monitors service -> hdm-control.py (surgical, block-only).
 */
Item {
    id: root
    property var profile: ({})            // existing profile object, or {__new__:true}
    readonly property bool isNew: profile.__new__ === true
    signal done

    property string pName: ""
    property string configType: "template"
    property bool fromCurrent: true
    property string power: ""
    property string lid: ""
    property bool profEnabled: true
    property bool confirmRemove: false
    property bool deleteTemplate: false

    ListModel { id: requiredModel }
    ListModel { id: staticModel }

    Component.onCompleted: {
        pName = profile.name ?? "";
        configType = profile.config_file_type ?? "template";
        power = profile.power ?? "";
        lid = profile.lid ?? "";
        profEnabled = profile.enabled ?? true;
        const req = profile.required ?? [];
        for (let i = 0; i < req.length; i++)
            requiredModel.append({ by: req[i].by || "description", value: req[i].value || "",
                                   regex: !!req[i].regex, tag: req[i].tag || "" });
        const st = profile.static ?? ({});
        for (const k in st)
            staticModel.append({ key: k, value: String(st[k]) });
        if (isNew && requiredModel.count === 0) {
            // prefill from connected monitors, matched by description
            for (const m of Monitors.monitors)
                requiredModel.append({ by: m.description ? "description" : "name",
                                       value: m.description || m.name || "", regex: false, tag: "" });
            nameField.focusInput();
        }
    }

    function collectRequired() {
        const out = [];
        for (let i = 0; i < requiredModel.count; i++) {
            const r = requiredModel.get(i);
            if ((r.value || "").trim().length > 0)
                out.push({ by: r.by, value: r.value, regex: r.regex, tag: r.tag });
        }
        return out;
    }
    function collectStatic() {
        const out = {};
        for (let i = 0; i < staticModel.count; i++) {
            const s = staticModel.get(i);
            if ((s.key || "").trim().length > 0)
                out[s.key] = s.value;
        }
        return out;
    }
    function save() {
        const spec = {
            name: root.isNew ? nameField.text : root.pName,
            "new": root.isNew,
            from_current: root.isNew && root.fromCurrent,
            config_file_type: root.configType,
            required: root.collectRequired(),
            power: root.power,
            lid: root.lid,
            static: root.collectStatic()
        };
        Monitors.saveProfile(spec);
        root.done();
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 10

            // ---- back bar ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PixButton {
                    implicitWidth: 34
                    implicitHeight: 30
                    onClicked: root.done()
                    PixIcon { anchors.centerIn: parent; name: "chevL"; size: 14; color: parent.contentColor }
                }
                PixTitle {
                    Layout.fillWidth: true
                    text: root.isNew ? "NEW PROFILE" : root.pName.toUpperCase()
                    font.pixelSize: PixTheme.font.pixelSize.title
                    elide: Text.ElideRight
                }
                PixButton {
                    id: saveBtn
                    implicitWidth: 58
                    implicitHeight: 30
                    filled: true
                    onClicked: root.save()
                    PixText { anchors.centerIn: parent; text: "Save"; font.bold: true
                        font.pixelSize: PixTheme.font.pixelSize.small; color: saveBtn.contentColor }
                }
            }

            // ---- name ----
            PixText { text: "NAME"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            PixField {
                id: nameField
                Layout.fillWidth: true
                text: root.pName
                editable: root.isNew
                placeholder: "profile name (letters, digits, - _)"
            }

            // ---- config type ----
            PixText { text: "TYPE"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            PixSegment {
                Layout.fillWidth: true
                options: [{ label: "Template", value: "template" }, { label: "Static", value: "static" }]
                value: root.configType
                onPicked: v => root.configType = v
            }

            // ---- layout capture ----
            PixButton {
                id: layoutBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                filled: root.isNew && root.fromCurrent
                onClicked: {
                    if (root.isNew)
                        root.fromCurrent = !root.fromCurrent;
                    else
                        Monitors.applyCurrent(root.pName);
                }
                PixText {
                    anchors.centerIn: parent
                    text: root.isNew ? (root.fromCurrent ? "✓ capture current layout" : "capture current layout")
                        : "Apply current layout to this profile"
                    font.pixelSize: PixTheme.font.pixelSize.small
                    color: layoutBtn.contentColor
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

            // ---- required monitors ----
            RowLayout {
                Layout.fillWidth: true
                PixText { Layout.fillWidth: true; text: "REQUIRED MONITORS"; font.bold: true
                    color: PixTheme.colors.grey; font.pixelSize: PixTheme.font.pixelSize.smaller }
                PixButton {
                    implicitWidth: 30; implicitHeight: 26
                    onClicked: requiredModel.append({ by: "description", value: "", regex: false, tag: "" })
                    PixText { anchors.centerIn: parent; text: "+"; font.bold: true
                        font.pixelSize: PixTheme.font.pixelSize.large; color: parent.contentColor }
                }
            }

            Repeater {
                model: requiredModel
                delegate: ColumnLayout {
                    id: reqRow
                    required property int index
                    required property string by
                    required property string value
                    required property bool regex
                    required property string tag
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        PixSegment {
                            Layout.preferredWidth: 150
                            options: [{ label: "Name", value: "name" }, { label: "Desc", value: "description" }]
                            value: reqRow.by
                            onPicked: v => requiredModel.setProperty(reqRow.index, "by", v)
                        }
                        PixButton {
                            implicitWidth: 40; implicitHeight: 30
                            filled: reqRow.regex
                            onClicked: requiredModel.setProperty(reqRow.index, "regex", !reqRow.regex)
                            PixText { anchors.centerIn: parent; text: ".*"; font.bold: true
                                font.pixelSize: PixTheme.font.pixelSize.small; color: parent.contentColor }
                            PixTooltip { text: "Match with a regular expression" }
                        }
                        PixButton {
                            implicitWidth: 34; implicitHeight: 30
                            onClicked: requiredModel.remove(reqRow.index)
                            PixIcon { anchors.centerIn: parent; name: "trash"; size: 13; color: parent.contentColor }
                        }
                    }
                    PixField {
                        Layout.fillWidth: true
                        text: reqRow.value
                        placeholder: reqRow.by === "name" ? "connector, e.g. DP-1" : "description, e.g. Dell U2720Q"
                        onEdited: t => requiredModel.setProperty(reqRow.index, "value", t)
                    }
                }
            }

            // quick add from connected monitors
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: Monitors.monitors.length > 0
                Repeater {
                    model: Monitors.monitors
                    delegate: PixButton {
                        id: addChip
                        required property var modelData
                        implicitHeight: 26
                        implicitWidth: chipT.implicitWidth + 18
                        onClicked: requiredModel.append({ by: addChip.modelData.description ? "description" : "name",
                            value: addChip.modelData.description || addChip.modelData.name || "", regex: false, tag: "" })
                        PixText { id: chipT; anchors.centerIn: parent
                            text: "+ " + (addChip.modelData.name || "?")
                            font.pixelSize: PixTheme.font.pixelSize.smallest; color: addChip.contentColor }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

            // ---- conditions ----
            PixText { text: "CONDITIONS"; font.bold: true; color: PixTheme.colors.grey
                font.pixelSize: PixTheme.font.pixelSize.smaller }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PixText { text: "Power"; Layout.preferredWidth: 42
                    font.pixelSize: PixTheme.font.pixelSize.small }
                PixSegment {
                    Layout.fillWidth: true
                    options: [{ label: "Any", value: "" }, { label: "AC", value: "AC" }, { label: "Battery", value: "BAT" }]
                    value: root.power
                    onPicked: v => root.power = v
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PixText { text: "Lid"; Layout.preferredWidth: 42
                    font.pixelSize: PixTheme.font.pixelSize.small }
                PixSegment {
                    Layout.fillWidth: true
                    options: [{ label: "Any", value: "" }, { label: "Open", value: "Opened" }, { label: "Closed", value: "Closed" }]
                    value: root.lid
                    onPicked: v => root.lid = v
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }

            // ---- template values ----
            RowLayout {
                Layout.fillWidth: true
                PixText { Layout.fillWidth: true; text: "TEMPLATE VALUES"; font.bold: true
                    color: PixTheme.colors.grey; font.pixelSize: PixTheme.font.pixelSize.smaller }
                PixButton {
                    implicitWidth: 30; implicitHeight: 26
                    onClicked: staticModel.append({ key: "", value: "" })
                    PixText { anchors.centerIn: parent; text: "+"; font.bold: true
                        font.pixelSize: PixTheme.font.pixelSize.large; color: parent.contentColor }
                }
            }
            Repeater {
                model: staticModel
                delegate: RowLayout {
                    id: kvRow
                    required property int index
                    required property string key
                    required property string value
                    Layout.fillWidth: true
                    spacing: 6
                    PixField {
                        Layout.preferredWidth: 110
                        text: kvRow.key
                        placeholder: "key"
                        onEdited: t => staticModel.setProperty(kvRow.index, "key", t)
                    }
                    PixField {
                        Layout.fillWidth: true
                        text: kvRow.value
                        placeholder: "value"
                        onEdited: t => staticModel.setProperty(kvRow.index, "value", t)
                    }
                    PixButton {
                        implicitWidth: 34; implicitHeight: 30
                        onClicked: staticModel.remove(kvRow.index)
                        PixIcon { anchors.centerIn: parent; name: "trash"; size: 13; color: parent.contentColor }
                    }
                }
            }

            // ---- existing-profile actions ----
            Rectangle { visible: !root.isNew; Layout.fillWidth: true
                Layout.preferredHeight: PixTheme.borderWidth; color: PixTheme.colors.line }
            RowLayout {
                visible: !root.isNew
                Layout.fillWidth: true
                spacing: 6
                PixButton {
                    id: enBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    onClicked: { Monitors.setProfileEnabled(root.pName, !root.profEnabled); root.done(); }
                    PixText { anchors.centerIn: parent
                        text: root.profEnabled ? "Disable" : "Enable"
                        font.pixelSize: PixTheme.font.pixelSize.small; color: enBtn.contentColor }
                }
                PixButton {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 32
                    onClicked: { Monitors.moveProfile(root.pName, "up"); root.done(); }
                    PixIcon { anchors.centerIn: parent; name: "chevL"; size: 13; rotation: 90; color: parent.contentColor }
                    PixTooltip { text: "Higher in file (lower priority on ties)" }
                }
                PixButton {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 32
                    onClicked: { Monitors.moveProfile(root.pName, "down"); root.done(); }
                    PixIcon { anchors.centerIn: parent; name: "chevR"; size: 13; rotation: 90; color: parent.contentColor }
                    PixTooltip { text: "Lower in file (wins ties)" }
                }
                PixButton {
                    id: rmBtn
                    Layout.preferredWidth: 40; Layout.preferredHeight: 32
                    onClicked: root.confirmRemove = true
                    PixIcon { anchors.centerIn: parent; name: "trash"; size: 14; color: rmBtn.contentColor }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }

    // ---- remove confirmation ----
    Rectangle {
        anchors.fill: parent
        visible: root.confirmRemove
        color: PixTheme.colors.bg
        radius: 0
        antialiasing: false

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 12
            PixTitle {
                Layout.fillWidth: true
                text: "REMOVE PROFILE"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: PixTheme.font.pixelSize.title
            }
            PixText {
                Layout.fillWidth: true
                text: "Delete profile \"" + root.pName + "\"? This edits your hyprdynamicmonitors config."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: PixTheme.font.pixelSize.small
            }
            PixButton {
                id: delTmpl
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                filled: root.deleteTemplate
                onClicked: root.deleteTemplate = !root.deleteTemplate
                PixText { anchors.centerIn: parent
                    text: (root.deleteTemplate ? "✓ " : "") + "also delete its template file"
                    font.pixelSize: PixTheme.font.pixelSize.small; color: delTmpl.contentColor }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PixButton {
                    id: cancelBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    onClicked: root.confirmRemove = false
                    PixText { anchors.centerIn: parent; text: "Cancel"
                        font.pixelSize: PixTheme.font.pixelSize.small; color: cancelBtn.contentColor }
                }
                PixButton {
                    id: confirmBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    filled: true
                    onClicked: { Monitors.removeProfile(root.pName, root.deleteTemplate); root.done(); }
                    PixText { anchors.centerIn: parent; text: "Remove"; font.bold: true
                        font.pixelSize: PixTheme.font.pixelSize.small; color: confirmBtn.contentColor }
                }
            }
        }
    }
}
