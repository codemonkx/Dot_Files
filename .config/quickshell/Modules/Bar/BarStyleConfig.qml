import QtQuick
import qs.Core
import qs.Core.Services
pragma Singleton

QtObject {
    id: root

    property var _styles: ({
        "convex": {
            "hasFrame": true,
            "hasExpandableHost": false,
            "usesFloatingPopups": true,
            "isPill": false
        },
        "island": {
            "hasFrame": false,
            "hasExpandableHost": true,
            "usesFloatingPopups": false,
            "isPill": true
        },
        "gaming": {
            "hasFrame": false,
            "hasExpandableHost": false,
            "usesFloatingPopups": true,
            "isPill": false
        }
    })

    function styleOf(style) {
        return _styles[style] || _styles["convex"];
    }

    function barHeight(style) {
        if (style === "gaming")
            return Constants.gamingBarHeight;

        if (style === "island")
            return Constants.islandBarHeight;

        return 40; // convex
    }

    function barMarginTop(style) {
        if (style === "gaming")
            return 0;

        if (style === "convex")
            return 0;

        return 8; // island
    }

    function barMarginSide(style) {
        return 0;
    }

    function isPill(style) {
        return style === "island";
    }

    function isExpandable(style) {
        return style === "island";
    }

}
