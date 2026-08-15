pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.paper.common
import qs.modules.paper.widgets

/**
 * Full editor for one hyprdynamicmonitors profile (or a brand-new one): the
 * required monitors, the match mode, the conditions, the template values and the
 * priority, plus "capture the current live layout into this profile".
 *
 * Every write goes through the `Monitors` service → hdm-control.py, which edits
 * the profile's block surgically; this file never touches the config itself.
 * The behaviour is identical to the pixel ProfileEditor — only the visual layer
 * changed.
 */
Item {
    id: root

    /// An existing profile object, or { __new__: true }.
    property var profile: ({})
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

    readonly property real gap: PaperTheme.pick(14, 10, 12)
    readonly property real labelColumn: PaperTheme.pick(48, 38, 40)

    ListModel {
        id: requiredModel
    }
    ListModel {
        id: staticModel
    }

    Component.onCompleted: {
        root.pName = root.profile.name ?? "";
        root.configType = root.profile.config_file_type ?? "template";
        root.power = root.profile.power ?? "";
        root.lid = root.profile.lid ?? "";
        root.profEnabled = root.profile.enabled ?? true;
        const req = root.profile.required ?? [];
        for (let i = 0; i < req.length; i++)
            requiredModel.append({
                by: req[i].by || "description",
                value: req[i].value || "",
                regex: !!req[i].regex,
                tag: req[i].tag || ""
            });
        const st = root.profile.static ?? ({});
        for (const k in st)
            staticModel.append({
                key: k,
                value: String(st[k])
            });
        if (root.isNew && requiredModel.count === 0) {
            // Prefill from the connected monitors, matched by description.
            for (const m of Monitors.monitors)
                requiredModel.append({
                    by: m.description ? "description" : "name",
                    value: m.description || m.name || "",
                    regex: false,
                    tag: ""
                });
            nameField.focusInput();
        }
    }

    function collectRequired(): var {
        const out = [];
        for (let i = 0; i < requiredModel.count; i++) {
            const r = requiredModel.get(i);
            if ((r.value || "").trim().length > 0)
                out.push({
                    by: r.by,
                    value: r.value,
                    regex: r.regex,
                    tag: r.tag
                });
        }
        return out;
    }
    function collectStatic(): var {
        const out = {};
        for (let i = 0; i < staticModel.count; i++) {
            const s = staticModel.get(i);
            if ((s.key || "").trim().length > 0)
                out[s.key] = s.value;
        }
        return out;
    }
    function save(): void {
        Monitors.saveProfile({
            name: root.isNew ? nameField.text : root.pName,
            "new": root.isNew,
            from_current: root.isNew && root.fromCurrent,
            config_file_type: root.configType,
            required: root.collectRequired(),
            power: root.power,
            lid: root.lid,
            static: root.collectStatic()
        });
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
            spacing: root.gap

            // ---- back bar ----
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperButton {
                    shape: "icon"
                    icon: "chevL"
                    onClicked: root.done()
                }
                PaperTitle {
                    Layout.fillWidth: true
                    text: root.isNew ? "New profile" : root.pName
                    elide: Text.ElideRight
                }
                PaperButton {
                    label: "Save"
                    primary: true
                    onClicked: root.save()
                }
            }
            PaperRule {
                visible: PaperTheme.ornament.oxfordRules
                Layout.fillWidth: true
                weight: "oxford"
            }

            // ---- name ----
            PaperField {
                id: nameField
                Layout.fillWidth: true
                label: "Name"
                text: root.pName
                readOnly: !root.isNew
                placeholder: "profile name (letters, digits, - _)"
                hint: root.isNew ? "" : "read-only for existing profiles"
            }

            // ---- config type ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.xs

                PaperSectionHeader {
                    Layout.fillWidth: true
                    label: "Type"
                }
                PaperSegment {
                    Layout.fillWidth: true
                    options: [
                        {
                            label: "Template",
                            value: "template"
                        },
                        {
                            label: "Static",
                            value: "static"
                        }
                    ]
                    value: root.configType
                    onPicked: v => root.configType = v
                }
            }

            // ---- layout capture ----
            PaperButton {
                Layout.fillWidth: !PaperTheme.isHairline
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: PaperTheme.pick(24, 30, 34)
                icon: "layers"
                checked: root.isNew && root.fromCurrent
                label: root.isNew ? "Capture current layout" : "Apply current layout to this profile"
                onClicked: {
                    if (root.isNew)
                        root.fromCurrent = !root.fromCurrent;
                    else
                        Monitors.applyCurrent(root.pName);
                }
            }

            // ---- required monitors ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Required monitors"

                PaperButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "+ Add"
                    onClicked: requiredModel.append({
                        by: "description",
                        value: "",
                        regex: false,
                        tag: ""
                    })
                }
            }

            Repeater {
                model: requiredModel

                delegate: PaperPanel {
                    id: reqCard

                    required property int index
                    required property string by
                    required property string value
                    required property bool regex

                    readonly property real cardPad: PaperTheme.pick(0, 8, 9)

                    Layout.fillWidth: true
                    kind: "card"
                    implicitHeight: reqCol.implicitHeight + 2 * reqCard.cardPad

                    ColumnLayout {
                        id: reqCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: reqCard.cardPad
                        spacing: PaperTheme.spacing.xs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: PaperTheme.spacing.xs

                            PaperSegment {
                                Layout.preferredWidth: PaperTheme.pick(150, 150, 120)
                                options: [
                                    {
                                        label: "Name",
                                        value: "name"
                                    },
                                    {
                                        label: "Desc",
                                        value: "description"
                                    }
                                ]
                                value: reqCard.by
                                onPicked: v => requiredModel.setProperty(reqCard.index, "by", v)
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            PaperButton {
                                shape: "icon"
                                icon: "regex"
                                checked: reqCard.regex
                                onClicked: requiredModel.setProperty(reqCard.index, "regex", !reqCard.regex)
                                PaperTooltip {
                                    text: "Match with a regular expression"
                                }
                            }
                            PaperButton {
                                shape: "icon"
                                icon: "trash"
                                onClicked: requiredModel.remove(reqCard.index)
                            }
                        }

                        PaperField {
                            Layout.fillWidth: true
                            text: reqCard.value
                            placeholder: reqCard.by === "name" ? "connector, e.g. DP-1" : "description, e.g. Dell U2720Q"
                            onEdited: t => requiredModel.setProperty(reqCard.index, "value", t)
                        }
                    }
                }
            }

            // Quick-add from the connected monitors.
            Flow {
                Layout.fillWidth: true
                spacing: PaperTheme.gap.chip
                visible: Monitors.monitors.length > 0

                Repeater {
                    model: Monitors.monitors

                    delegate: PaperChip {
                        required property var modelData

                        label: "+ " + (modelData.name || "?")
                        mono: true
                        onClicked: requiredModel.append({
                            by: modelData.description ? "description" : "name",
                            value: modelData.description || modelData.name || "",
                            regex: false,
                            tag: ""
                        })
                    }
                }
            }

            // ---- conditions ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Conditions"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperText {
                    Layout.preferredWidth: root.labelColumn
                    text: "Power"
                    role: "micro"
                }
                PaperSegment {
                    Layout.fillWidth: true
                    options: [
                        {
                            label: "Any",
                            value: ""
                        },
                        {
                            label: "AC",
                            value: "AC"
                        },
                        {
                            label: "Battery",
                            value: "BAT"
                        }
                    ]
                    value: root.power
                    onPicked: v => root.power = v
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.small

                PaperText {
                    Layout.preferredWidth: root.labelColumn
                    text: "Lid"
                    role: "micro"
                }
                PaperSegment {
                    Layout.fillWidth: true
                    options: [
                        {
                            label: "Any",
                            value: ""
                        },
                        {
                            label: "Open",
                            value: "Opened"
                        },
                        {
                            label: "Closed",
                            value: "Closed"
                        }
                    ]
                    value: root.lid
                    onPicked: v => root.lid = v
                }
            }

            // ---- template values ----
            PaperSectionHeader {
                Layout.fillWidth: true
                label: "Template values"

                PaperButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "+ Add"
                    onClicked: staticModel.append({
                        key: "",
                        value: ""
                    })
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
                    spacing: PaperTheme.spacing.xs

                    PaperField {
                        Layout.preferredWidth: PaperTheme.pick(110, 110, 104)
                        text: kvRow.key
                        placeholder: "key"
                        onEdited: t => staticModel.setProperty(kvRow.index, "key", t)
                    }
                    PaperField {
                        Layout.fillWidth: true
                        text: kvRow.value
                        placeholder: "value"
                        onEdited: t => staticModel.setProperty(kvRow.index, "value", t)
                    }
                    PaperButton {
                        shape: "icon"
                        icon: "trash"
                        onClicked: staticModel.remove(kvRow.index)
                    }
                }
            }

            // ---- existing-profile actions ----
            PaperRule {
                visible: !root.isNew
                Layout.fillWidth: true
                weight: "double"
            }
            RowLayout {
                visible: !root.isNew
                Layout.fillWidth: true
                spacing: PaperTheme.spacing.xs

                PaperButton {
                    Layout.fillWidth: !PaperTheme.isHairline
                    label: root.profEnabled ? "Disable" : "Enable"
                    onClicked: {
                        Monitors.setProfileEnabled(root.pName, !root.profEnabled);
                        root.done();
                    }
                }
                PaperButton {
                    shape: "icon"
                    // Broadsheet finally has real arrows; the others use chevrons.
                    icon: PaperTheme.isBroadsheet ? "arrowU" : "chevU"
                    onClicked: {
                        Monitors.moveProfile(root.pName, "up");
                        root.done();
                    }
                    PaperTooltip {
                        text: "Higher in file (lower priority on ties)"
                    }
                }
                PaperButton {
                    shape: "icon"
                    icon: PaperTheme.isBroadsheet ? "arrowD" : "chevD"
                    onClicked: {
                        Monitors.moveProfile(root.pName, "down");
                        root.done();
                    }
                    PaperTooltip {
                        text: "Lower in file (wins ties)"
                    }
                }
                Item {
                    Layout.fillWidth: PaperTheme.isHairline
                }
                PaperButton {
                    shape: "icon"
                    icon: "trash"
                    destructive: true
                    onClicked: root.confirmRemove = true
                }
            }
            PaperText {
                visible: !root.isNew
                Layout.fillWidth: true
                text: "When several profiles match, the highest score wins; ties go to the profile defined last."
                role: "meta"
                tone: "ink4"
                footnote: true
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.preferredHeight: PaperTheme.spacing.tiny
            }
        }
    }

    // ---- remove confirmation ----
    // A full cover on an opaque ground: the safe action is deliberately the
    // visually stronger of the two.
    Rectangle {
        anchors.fill: parent
        visible: root.confirmRemove
        color: PaperTheme.paper

        // Ledger frames the confirmation in a red hairline over a red wash — the
        // one red field in the shell.
        PaperPanel {
            id: confirmSheet
            anchors.centerIn: parent
            width: parent.width
            implicitHeight: confirmCol.implicitHeight + 2 * PaperTheme.pad.sheet
            kind: PaperTheme.isLedger ? "card" : "sheet"
            color: PaperTheme.isLedger ? PaperTheme.alertWash : PaperTheme.paper
            frameTone: PaperTheme.isLedger ? "alert" : ""
            edgeTop: !PaperTheme.isHairline
            edgeBottom: !PaperTheme.isHairline
            edgeLeft: !PaperTheme.isHairline
            edgeRight: !PaperTheme.isHairline
            ticks: true

            ColumnLayout {
                id: confirmCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: PaperTheme.pad.sheet
                spacing: PaperTheme.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: PaperTheme.spacing.small

                    PaperIcon {
                        visible: !PaperTheme.isHairline
                        name: "warn"
                        size: PaperTheme.icon.control
                        color: PaperTheme.alert
                    }
                    PaperTitle {
                        Layout.fillWidth: true
                        text: "Remove profile"
                        tone: PaperTheme.isHairline ? "ink" : "alert"
                        elide: Text.ElideRight
                    }
                }
                PaperText {
                    Layout.fillWidth: true
                    text: "Delete profile “" + root.pName + "”? This edits your hyprdynamicmonitors config."
                    role: "small"
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: PaperTheme.spacing.small

                    PaperCheck {
                        checked: root.deleteTemplate
                        onToggled: root.deleteTemplate = !root.deleteTemplate
                    }
                    PaperText {
                        Layout.fillWidth: true
                        text: "also delete its template file"
                        role: "small"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteTemplate = !root.deleteTemplate
                        }
                    }
                }
                PaperRule {
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: PaperTheme.spacing.large

                    PaperButton {
                        Layout.fillWidth: !PaperTheme.isHairline
                        label: "Cancel"
                        checked: true
                        onClicked: root.confirmRemove = false
                    }
                    PaperButton {
                        Layout.fillWidth: !PaperTheme.isHairline
                        label: "Remove"
                        destructive: true
                        // Ledger and broadsheet fill the confirming verb; hairline
                        // marks it with an alert underline instead.
                        primary: !PaperTheme.isHairline
                        onClicked: {
                            Monitors.removeProfile(root.pName, root.deleteTemplate);
                            root.done();
                        }
                    }
                }
            }
        }
    }
}
