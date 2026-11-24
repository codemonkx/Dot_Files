import QtQuick
pragma Singleton

QtObject {
    function toDate(value) {
        if (value === undefined || value === null)
            return null;

        if (value instanceof Date)
            return isNaN(value.getTime()) ? null : value;

        let numeric = Number(value);
        if (isNaN(numeric))
            return null;

        // Accept both seconds and milliseconds since epoch.
        return new Date(numeric < 1e+10 ? numeric * 1000 : numeric);
    }

    function timeAgo(value, now) {
        let date = toDate(value);
        let current = toDate(now);
        if (!date || !current)
            return "...";

        let diff = Math.floor((current.getTime() - date.getTime()) / 1000);
        if (diff < 0)
            diff = 0;

        if (diff < 60)
            return "Just now";

        if (diff < 3600)
            return Math.floor(diff / 60) + "m ago";

        if (diff < 86400)
            return Math.floor(diff / 3600) + "h ago";

        return Math.floor(diff / 86400) + "d ago";
    }

}
