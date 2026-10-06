import Foundation

/// L'app s'appelait Halo (identifiant com.matthieu.halo). Au premier lancement de Hello, on reprend
/// ses réglages, ses statistiques et son dossier de données, pour que rien ne soit perdu au changement de nom.
enum LegacyMigration {
    private static let oldDomain = "com.matthieu.halo"
    private static let doneKey = "migratedFromHalo"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        if let old = defaults.persistentDomain(forName: oldDomain) {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldDir = support.appendingPathComponent("Halo", isDirectory: true)
        let newDir = support.appendingPathComponent("Hello", isDirectory: true)
        if fm.fileExists(atPath: oldDir.path), !fm.fileExists(atPath: newDir.path) {
            try? fm.moveItem(at: oldDir, to: newDir)
        }
        defaults.set(true, forKey: doneKey)
    }
}
