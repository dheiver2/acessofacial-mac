import Foundation
import AppKit
import UserNotifications

/// Dispara alertas de segurança (som + notificação do sistema) quando uma
/// pessoa em watchlist (bloqueada/alerta) é detectada. Tudo guardado para
/// nunca derrubar o app caso as notificações não estejam disponíveis.
enum Alerter {
    private static var authorizationRequested = false

    static func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        guard let center = safeCenter() else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// `blocked = true` usa som de alarme mais chamativo (pessoa bloqueada).
    static func fire(title: String, body: String, blocked: Bool, playSound: Bool) {
        if playSound {
            let name: NSSound.Name = blocked ? "Sosumi" : "Funk"
            (NSSound(named: name) ?? NSSound(named: "Ping"))?.play()
        }
        guard let center = safeCenter() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = blocked ? .defaultCritical : .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(req, withCompletionHandler: nil)
    }

    /// `UNUserNotificationCenter.current()` só é válido em um app empacotado
    /// com bundle identifier; retorna `nil` se não for o caso (ex.: binário
    /// solto rodado direto de `.build`), evitando crash.
    private static func safeCenter() -> UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }
}
