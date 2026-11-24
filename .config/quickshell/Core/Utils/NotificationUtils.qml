import QtQuick
pragma Singleton

QtObject {
    function parse(notifData) {
        if (!notifData)
            return {
            "app": "",
            "title": "",
            "message": ""
        };

        let app = (notifData.appName || "").trim();
        let sum = (notifData.summary || "").trim();
        let body = (notifData.body || "").trim();
        let isGenericApp = sum.toLowerCase().includes("whatsapp") || (app !== "" && sum.toLowerCase() === app.toLowerCase());
        // Case 1: summary is generic (e.g. "WhatsApp Web", "WhatsApp") and body contains sender + message separated by newline
        if (isGenericApp && body.includes("\n")) {
            let lines = body.split("\n").filter(function(l) {
                return l.trim().length > 0;
            });
            if (lines.length >= 2)
                return {
                "app": sum !== "" ? sum : app,
                "title": lines[0].trim(),
                "message": lines.slice(1).join("\n").trim()
            };

        }
        // Case 2: summary is generic and body has "Sender: Message"
        if (isGenericApp && body.includes(": ")) {
            let colonIdx = body.indexOf(": ");
            let sender = body.substring(0, colonIdx).trim();
            let msg = body.substring(colonIdx + 2).trim();
            if (sender.length > 0 && msg.length > 0)
                return {
                "app": sum !== "" ? sum : app,
                "title": sender,
                "message": msg
            };

        }
        // Case 3: We have a valid appName distinct from summary and System
        let hasDistinctApp = app !== "" && app !== "System" && app.toLowerCase() !== sum.toLowerCase();
        return {
            "app": hasDistinctApp ? app : (sum.toLowerCase().includes("whatsapp") ? sum : ""),
            "title": sum,
            "message": body
        };
    }

}
