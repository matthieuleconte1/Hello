import AppKit

struct Leftover {
    let path: String
    let kind: String
}

/// Désinstallation "propre" façon AppCleaner : l'app + ses fichiers dans les Library,
/// retrouvés par identifiant de bundle et par nom. Tout part à la corbeille (récupérable).
enum Uninstaller {
    static func canUninstall(_ app: AppEntry) -> Bool { app.uninstallable }

    static func bundleID(_ appPath: String) -> String? {
        Bundle(path: appPath)?.bundleIdentifier
    }

    static func find(_ app: AppEntry) -> [Leftover] {
        let fm = FileManager.default
        let id = bundleID(app.path)?.lowercased() ?? ""
        let bundleName = ((app.path as NSString).lastPathComponent as NSString).deletingPathExtension
        let names = Set([app.name, bundleName].flatMap { name -> [String] in
            let folded = Fuzzy.fold(name)
            return [folded, folded.replacingOccurrences(of: " ", with: "")]
        }).filter { $0.count >= 3 }

        let userLib = Shell.home + "/Library"
        let places: [(dir: String, kind: String, loose: Bool)] = [
            (userLib + "/Application Support", "Données", false),
            (userLib + "/Caches", "Cache", false),
            (userLib + "/Preferences", "Préférences", false),
            (userLib + "/Preferences/ByHost", "Préférences", false),
            (userLib + "/Saved Application State", "État de fenêtres", false),
            (userLib + "/Containers", "Conteneur", false),
            (userLib + "/Group Containers", "Conteneur partagé", true),
            (userLib + "/Application Scripts", "Scripts", true),
            (userLib + "/HTTPStorages", "Données web", false),
            (userLib + "/WebKit", "Données web", false),
            (userLib + "/Cookies", "Cookies", false),
            (userLib + "/Logs", "Journaux", false),
            (userLib + "/LaunchAgents", "Agent au démarrage", true),
            ("/Library/Application Support", "Données (système)", false),
            ("/Library/Caches", "Cache (système)", false),
            ("/Library/Preferences", "Préférences (système)", false),
            ("/Library/LaunchAgents", "Agent au démarrage (système)", true),
            ("/Library/LaunchDaemons", "Service (système)", true),
            ("/Library/PrivilegedHelperTools", "Outil privilégié", true),
        ]

        var out = [Leftover(path: app.path, kind: "Application")]
        for place in places {
            guard let entries = try? fm.contentsOfDirectory(atPath: place.dir) else { continue }
            for entry in entries {
                let lower = entry.lowercased()
                var stem = lower
                for ext in [".plist", ".savedstate", ".binarycookies"] where stem.hasSuffix(ext) {
                    stem = String(stem.dropLast(ext.count))
                }
                let byID = !id.isEmpty && (stem == id || stem.hasPrefix(id + ".") || (place.loose && lower.contains(id)))
                let byName = names.contains(Fuzzy.fold(stem))
                if byID || byName {
                    out.append(Leftover(path: (place.dir as NSString).appendingPathComponent(entry), kind: place.kind))
                }
            }
        }
        return out
    }

    static func size(_ path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys),
                                                        options: [], errorHandler: { _, _ in true })
        while let file = enumerator?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: keys))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// Met à la corbeille, hors du fil principal : le Finder peut afficher sa fenêtre de mot de passe
    /// (ou macOS sa demande d'autorisation) et attendre la réponse sans figer Hello.
    /// Ce qui demande des droits admin passe par le Finder ; `beforeFinder` est appelé (sur le fil principal)
    /// juste avant, pour libérer l'écran.
    static func trash(_ paths: [String], beforeFinder: @escaping () -> Void,
                      completion: @escaping (_ done: Int, _ failed: [String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var failed = paths.filter { path in
                (try? FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)) == nil
            }
            if !failed.isEmpty {
                DispatchQueue.main.sync(execute: beforeFinder)
                finderDelete(failed)
                failed = failed.filter { FileManager.default.fileExists(atPath: $0) }
            }
            DispatchQueue.main.async { completion(paths.count - failed.count, failed) }
        }
    }

    /// osascript plutôt que NSAppleScript : un processus à part, qu'on peut attendre sans bloquer l'interface.
    /// Les chemins passent en arguments (aucun échappement à faire).
    private static func finderDelete(_ paths: [String]) {
        let script = """
            on run argv
                set targets to {}
                repeat with p in argv
                    set end of targets to ((POSIX file (contents of p)) as alias)
                end repeat
                with timeout of 600 seconds
                    tell application "Finder" to delete targets
                end timeout
            end run
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script] + paths
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
    }
}
