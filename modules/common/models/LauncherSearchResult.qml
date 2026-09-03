import QtQuick
import Quickshell

QtObject {
    enum IconType { Material, Text, System, None }
    enum FontType { Normal, Monospace }

    // General stuff
    property string type: ""
    property var fontType: LauncherSearchResult.FontType.Normal
    property string name: ""
    property string rawValue: ""
    property string iconName: ""
    property var iconType: LauncherSearchResult.IconType.None
    property string verb: ""
    property bool blurImage: false
    property var execute: () => {
        print("Not implemented");
    }
    property var actions: []
    
    // Stuff needed for DesktopEntry 
    property string id: ""
    property bool shown: true
    property string comment: ""
    property bool runInTerminal: false
    property string genericName: ""
    property list<string> keywords: []

    // Extra stuff to allow for more flexibility
    property string category: type

    /**
     * Stable identity for `ScriptModel { objectProp: "key" }`, which every search
     * widget (ii / pixel / paper) sets. Without this property the model read
     * `undefined` for every row, so its incremental diff had nothing to key on and
     * the whole result list churned on each keystroke.
     *
     * Derived from content: a row whose fields are unchanged keeps its key, and so
     * keeps its delegate, even though `results` rebuilds fresh objects every time.
     */
    readonly property string key: [type, id, rawValue, name, comment].join("\u001f")
}
