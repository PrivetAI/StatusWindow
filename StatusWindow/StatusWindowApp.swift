import SwiftUI

private let swPanelAddress = "https://statuswindow.org/click.php"
private let swPanelMarker = "termsfeed.com"

// MARK: - Redirect watcher for the launch check

/// Follows the launch redirect chain and *decides* at the first hop that carries
/// information, rather than waiting for the whole chain to resolve. The slowest
/// host in the chain is then no longer on the critical path of the launch.
final class SWGateTracker: NSObject, URLSessionTaskDelegate {
    /// Fires on every observed hop — this is what re-arms the stall watchdog.
    var onProgress: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var settledAddress: URL?
    private(set) var sawCheckDomain = false

    private let markerFragment: String
    private let ownHost: String
    private var decided = false

    init(markerFragment: String, ownHost: String) {
        self.markerFragment = markerFragment
        self.ownHost = ownHost
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        settledAddress = request.url
        onProgress?()

        if let address = request.url?.absoluteString {
            if address.contains(markerFragment) {
                // Definitive: the marker branch. Nothing later can change this.
                sawCheckDomain = true
                decide(false)
            } else if let host = request.url?.host, !hostIsOurs(host) {
                // The first hop that leaves our own domain without being the
                // marker: the route has already been decided upstream, and every
                // hop after this one belongs to that destination.
                decide(true)
            }
            // A hop that stays on our own host (root -> /click.php) decides nothing.
        }
        // Never stop the chain.
        completionHandler(request)
    }

    private func hostIsOurs(_ host: String) -> Bool {
        !ownHost.isEmpty && (host == ownHost || host.hasSuffix("." + ownHost))
    }

    private func decide(_ verdict: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(verdict)
    }
}

// MARK: - Launch gate

/// Owns the launch check. It resolves as early as the redirect chain allows,
/// retries once on a transport error, gives up on a *stall* instead of on a fixed
/// deadline, and — when it still cannot decide — hands over the native app right
/// away while it keeps looking in the background.
///
/// `@MainActor` is required: the network callbacks mutate published state, and the
/// `Task { @MainActor in ... }` hops below are what make that sound.
@MainActor
final class SWLaunchGate: ObservableObject {
    /// nil = still deciding (loading screen) · false = native app · true = web panel
    @Published private(set) var ready: Bool? = nil

    let sourceLink: String
    private let markerFragment: String
    private let ownHost: String

    /// Stall limit while the loading screen is up. Deliberately short: someone is
    /// staring at a splash, and a late verdict can still swap the panel in, so
    /// there is nothing to gain by making them wait here.
    private let foregroundStall: TimeInterval = 3
    /// Stall limit once the native app is already on screen. Nobody is waiting, so
    /// the background attempts can afford to be patient.
    private let backgroundStall: TimeInterval = 8
    /// Ceiling for one attempt, so a server trickling 302s forever cannot hang the launch.
    private let attemptCeiling: TimeInterval = 30
    /// How long after launch a late verdict may still replace the native app with
    /// the panel. Past this the swap is visible and jarring, so it is dropped.
    private let swapWindow: TimeInterval = 25
    private let backgroundRetryDelay: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var task: URLSessionTask?
    /// Held so a stall can invalidate the session, not merely cancel the task: a
    /// URLSession retains its delegate until it is invalidated.
    private var session: URLSession?

    init(sourceLink: String, markerFragment: String) {
        self.sourceLink = sourceLink
        self.markerFragment = markerFragment
        self.ownHost = URL(string: sourceLink)?.host ?? ""
    }

    func start() {
        guard attemptToken == 0 else { return }   // .onAppear can fire more than once
        startedAt = Date()
        attempt(1)
    }

    private func attempt(_ n: Int) {
        guard !settled else { return }
        guard let url = URL(string: sourceLink) else { settle(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET: the redirect chain resolves exactly the same way, but no
        // page body crosses the wire — the WebView refetches the page from scratch
        // anyway, so a GET here is pure waste.
        request.httpMethod = "HEAD"
        // 10, not 5. The gate must close on the marker, never on a slow connection:
        // a cold start alone measures 3.4 s of DNS + TLS across the redirect chain.
        request.timeoutInterval = 10
        // The one request whose entire value is being LIVE. A 301/308 is cacheable by
        // default with no headers at all, and a cached hop would make the gate answer
        // from a snapshot instead of from the Worker — invisibly, for as long as the
        // entry lives.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let configuration = URLSessionConfiguration.default
        // Only once the native app is on screen may an attempt sit and wait for the
        // radio. While the loading screen is up, -1009 must fail instantly.
        configuration.waitsForConnectivity = (ready != nil)
        configuration.timeoutIntervalForResource = attemptCeiling
        configuration.urlCache = nil
        // URLSession's cookie jar is NOT the WebView's. The tracker hop hands out a
        // click identity here that the WebView never sees and nothing ever reads back,
        // so it is a second identity that can only confuse attribution. Refuse it.
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false

        let tracker = SWGateTracker(markerFragment: markerFragment, ownHost: ownHost)
        tracker.onProgress = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        tracker.onEarlyVerdict = { [weak self] verdict in
            Task { @MainActor in self?.settle(verdict) }
        }

        let session = URLSession(configuration: configuration,
                                 delegate: tracker,
                                 delegateQueue: nil)
        self.session = session
        lastProgress = Date()
        armStallWatchdog(attempt: n, token: token)

        task = session.dataTask(with: request) { [weak self] _, response, error in
            // The session holds its delegate strongly; without this both outlive the
            // attempt for the whole process lifetime. Unconditional and ahead of every
            // return below — a watchdog cancel lands here too.
            session.finishTasksAndInvalidate()
            Task { @MainActor in
                guard let self = self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if tracker.sawCheckDomain { self.settle(false); return }
                if let finalAddress = tracker.settledAddress?.absoluteString,
                   finalAddress.contains(self.markerFragment) { self.settle(false); return }
                if let httpResponse = response as? HTTPURLResponse,
                   let responseAddress = httpResponse.url?.absoluteString,
                   responseAddress.contains(self.markerFragment) { self.settle(false); return }
                if error != nil { self.failed(attempt: n, token: token); return }
                self.settle(true)
            }
        }
        task?.resume()
    }

    /// Progress-aware watchdog. It never kills a chain that is still moving.
    private func armStallWatchdog(attempt n: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.ready == nil ? self.foregroundStall : self.backgroundStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving → keep waiting
                timer.invalidate()
                // Cancels the task AND frees the delegate.
                self.session?.invalidateAndCancel()
                self.failed(attempt: n, token: token)
            }
        }
    }

    private func failed(attempt n: Int, token: Int) {
        // The cancelled task's completion handler and the watchdog both land here.
        // The token makes whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        // One immediate retry. Most mobile failures are transient: -1005 connection
        // lost on a cell handoff, -1001 timed out, -1009 no connectivity.
        if n == 1 { attempt(2); return }

        // Out of fast options. Hand over the native app NOW rather than holding
        // anyone on a loading screen, and keep looking in the background.
        if ready == nil { ready = false }
        scheduleBackgroundAttempt(next: n + 1)
    }

    private func scheduleBackgroundAttempt(next n: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundRetryDelay) { [weak self] in
            Task { @MainActor in
                guard let self = self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.attempt(n)
            }
        }
    }

    private func settle(_ verdict: Bool) {
        guard !settled else { return }
        // A verdict arriving after the swap window may still close the gate — native
        // is where we already are — but must never yank someone who has been using
        // the app for half a minute into a web panel.
        if verdict, ready == false, Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        ready = verdict
    }
}

// MARK: - Entry point

@main
struct StatusWindowApp: App {
    @StateObject private var gate = SWLaunchGate(sourceLink: swPanelAddress,
                                                 markerFragment: swPanelMarker)
    @State private var swPagePainted = false
    /// The panel could not load anything at all — not live, not from cache. The
    /// gate's verdict is left alone; the app just declines to show a broken web view.
    @State private var swPanelDeadEnd = false
    @Environment(\.scenePhase) private var swScenePhase

    /// Where the panel actually was last time. The GATE is untouched — the HEAD check
    /// still runs on every launch, so the marker branch is unaffected. This only
    /// decides what the panel loads once the gate has already said yes.
    private var swResumeAddress: String? { SWPanelSession.resumeAddress() }
    private var swTrackerHost: String { URL(string: gate.sourceLink)?.host ?? "" }

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = gate.ready {
                    if ready && !swPanelDeadEnd {
                        // The loading screen stays on top until the page commits its
                        // first frame, or an opaque black WKWebView is all there is to
                        // look at for the seconds the page needs.
                        ZStack {
                            SWWebPanel(panelAddress: swResumeAddress ?? gate.sourceLink,
                                       trackerHost: swTrackerHost,
                                       fallbackAddress: swResumeAddress == nil ? nil : gate.sourceLink,
                                       onFirstPaint: { withAnimation { swPagePainted = true } },
                                       onDeadEnd: { swPanelDeadEnd = true })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !swPagePainted {
                                SWLoadingScreen()   // same screen as the check phase, no seam
                                    .transition(.opacity)
                                    .onAppear {
                                        // Hang guard, NOT a deadline. Long on purpose:
                                        // firing early just reveals the black page it
                                        // exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                            swPagePainted = true
                                        }
                                    }
                            }
                        }
                        // .dark draws the clock and battery WHITE over the black band.
                        // It belongs here, on the whole branch — never on the panel and
                        // the stack both.
                        .preferredColorScheme(.dark)
                    } else {
                        SWRootView()
                            .preferredColorScheme(.light)
                    }
                } else {
                    SWLoadingScreen()
                        .onAppear { gate.start() }
                        .preferredColorScheme(.light)
                }
            }
            // A late verdict can flip native → panel a few seconds in. Crossfade it;
            // an instant hard cut reads as a glitch.
            .animation(.easeInOut(duration: 0.25), value: gate.ready)
            .animation(.easeInOut(duration: 0.25), value: swPanelDeadEnd)
            // Leaving the foreground is the last reliable moment before the process
            // can be killed from the switcher. `.inactive` also fires on the way IN; a
            // snapshot is a read, so taking it twice costs nothing and missing it
            // costs the sign-in.
            .onChange(of: swScenePhase) { phase in
                guard gate.ready == true, phase != .active else { return }
                SWPanelCookies.snapshot()
            }
        }
    }
}
