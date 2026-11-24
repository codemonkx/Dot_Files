import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Services
import qs.Core.Utils

Rectangle {
    id: bgRect

    property bool isDark: ColorUtils.isDark(Theme.bg)

    color: Theme.bg
    opacity: 1

    Image {
        id: wallpaperImg

        anchors.fill: parent
        sourceSize: Qt.size(480, 270)
        source: {
            let p = WallpaperManager.currentWallpaperPath;
            if (!p)
                return "";

            return p.startsWith("file://") ? p : ("file://" + p);
        }
        fillMode: {
            let mode = HyprlandService.wpResizeMode;
            if (mode === "fit")
                return Image.PreserveAspectFit;

            if (mode === "stretch")
                return Image.Stretch;

            return Image.PreserveAspectCrop;
        }
        horizontalAlignment: {
            let g = HyprlandService.wpCropGravity || "center";
            if (g.includes("left"))
                return Image.AlignLeft;

            if (g.includes("right"))
                return Image.AlignRight;

            return Image.AlignHCenter;
        }
        verticalAlignment: {
            let g = HyprlandService.wpCropGravity || "center";
            if (g.includes("top"))
                return Image.AlignTop;

            if (g.includes("bottom"))
                return Image.AlignBottom;

            return Image.AlignVCenter;
        }
        asynchronous: true
        cache: true
        layer.enabled: true

        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: Constants.size5Xl
        }

    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: 0.7
    }

}
