import SwiftUI

// MARK: - Redirect watcher for the launch check

final class SWRouteWatcher: NSObject, URLSessionTaskDelegate {
    var settledAddress: URL?
    var matchedMarker = false
    private let markerFragment: String

    init(markerFragment: String) {
        self.markerFragment = markerFragment
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let address = request.url?.absoluteString, address.contains(markerFragment) {
            matchedMarker = true
        }
        settledAddress = request.url
        // Never stop the chain.
        completionHandler(request)
    }
}

// MARK: - Entry point

@main
struct StatusWindowApp: App {
    @State private var swPanelReady: Bool? = nil

    private let swPanelAddress = "https://statuswindow.org/click.php"
    private let swPanelMarker = "termsfeed.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = swPanelReady {
                    if ready {
                        SWWebPanel(panelAddress: swPanelAddress)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                            .preferredColorScheme(.dark)
                    } else {
                        SWRootView()
                            .preferredColorScheme(.light)
                    }
                } else {
                    SWLoadingScreen()
                        .onAppear { runSWLaunchCheck() }
                        .preferredColorScheme(.light)
                }
            }
        }
    }

    private func runSWLaunchCheck() {
        guard let url = URL(string: swPanelAddress) else {
            swPanelReady = false
            return
        }
        var request = URLRequest(url: url)
        // HEAD, never GET: the redirect chain still resolves exactly the same way,
        // but no page body crosses the wire — the WebView refetches the page from
        // scratch anyway, so a GET here is pure waste. It also keeps the 5 s
        // timeout a real error path instead of one a slow connection trips.
        request.httpMethod = "HEAD"
        // 10, not 5. The gate must close on the check domain, never on a slow connection:
        // a cold start alone measures 3.4 s of DNS + TLS across the redirect chain.
        request.timeoutInterval = 10

        let watcher = SWRouteWatcher(markerFragment: swPanelMarker)
        let session = URLSession(configuration: .default, delegate: watcher, delegateQueue: nil)

        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if watcher.matchedMarker {
                    swPanelReady = false
                    return
                }
                if let finalAddress = watcher.settledAddress?.absoluteString,
                   finalAddress.contains(swPanelMarker) {
                    swPanelReady = false
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   let responseAddress = httpResponse.url?.absoluteString,
                   responseAddress.contains(swPanelMarker) {
                    swPanelReady = false
                    return
                }
                if error != nil {
                    swPanelReady = false
                    return
                }
                swPanelReady = true
            }
        }.resume()

        // Backstop only. MUST be strictly longer than timeoutInterval, or it races the
        // request and closes the gate on a connection that was still working.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if swPanelReady == nil { swPanelReady = false }
        }
    }
}
