import SwiftUI
import WebKit

/// The single web surface in the app. It serves both the launch panel and the
/// Privacy Policy sheet reached from Settings.
struct SWWebPanel: UIViewRepresentable {
    let panelAddress: String
    /// Optional. When supplied, a failed load is reported back so the presenting
    /// screen can say something instead of leaving a blank black rectangle.
    var onLoadFailure: ((String) -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadFailure: ((String) -> Void)?

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            report(error)
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            // A canceled load is what an ordinary redirect looks like here, so it
            // is not a failure worth showing anyone.
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
            onLoadFailure?(nsError.localizedDescription)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onLoadFailure = onLoadFailure
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Keeps scrollable content clear of the home indicator once the frame
        // extends past the bottom safe area. Never `.never`.
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        // The branch presenting this runs in the dark scheme so the status bar
        // glyphs draw white. Pin the page itself back to light.
        webView.overrideUserInterfaceStyle = .light

        if let url = URL(string: panelAddress) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    /// Deliberately does not reload: doing so would restart the page on every
    /// SwiftUI re-render. Only the failure callback is refreshed.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onLoadFailure = onLoadFailure
    }
}
