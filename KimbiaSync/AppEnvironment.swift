import Foundation
import KimbiaKit

/// The constants and shared objects the app needs. Identifiers here are
/// mirrored in `project.yml` and the hosted OAuth client metadata
/// (`web/oauth-client-metadata.json`), so change them there too.
enum AppEnvironment {
    // MARK: Identifiers

    /// Keychain service name under which the `Session` is stored.
    static let keychainService = "me.byjp.KimbiaSync.session"

    /// The background app refresh task, listed in `BGTaskSchedulerPermittedIdentifiers`.
    static let refreshTaskIdentifier = "me.byjp.KimbiaSync.refresh"

    // MARK: OAuth

    /// The hosted client metadata document doubles as the ATProto `client_id`.
    static let oauthClientID = URL(string: "https://kimbia-sync.byjp.me/oauth-client-metadata.json")!

    /// Custom-scheme redirect registered in the app's `CFBundleURLTypes`: the
    /// reverse-DNS form of the `client_id` host, as ATProto requires.
    static let oauthRedirectURI = URL(string: "me.byjp.kimbia-sync:/oauth/callback")!

    /// The scheme part of `oauthRedirectURI`, as `ASWebAuthenticationSession` wants it.
    static let oauthCallbackScheme = "me.byjp.kimbia-sync"

    /// What the app asks permission for: `atproto`, plus access to Kimbia's
    /// activity collection and nothing else. Must match
    /// `web/oauth-client-metadata.json`.
    static let oauthScope = "atproto repo:\(KimbiaActivityMapper.collection)"

    static let oauthConfiguration = OAuthClientConfiguration(
        clientID: oauthClientID,
        redirectURI: oauthRedirectURI,
        scope: oauthScope
    )

    static let oauthClient = OAuthClient(configuration: oauthConfiguration)

    // MARK: Storage

    static let sessionStore = KeychainSessionStore(service: keychainService)

    static let ledgerStore: FileSyncLedgerStore = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileSyncLedgerStore(directory: support.appendingPathComponent("SyncLedgers", isDirectory: true))
    }()

    static let preferences = Preferences(defaults: .standard)

    // MARK: Factories

    /// An authenticated client for the signed-in user's own PDS. Token
    /// refreshes are written back to `sessionStore` transparently.
    static func makePDSClient(session: Session) -> PDSClient {
        PDSClient(session: session, sessionStore: sessionStore, configuration: oauthConfiguration)
    }
}
