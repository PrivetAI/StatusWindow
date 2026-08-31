import SwiftUI

// MARK: - Tabs

enum SWTab: Int, CaseIterable, Identifiable {
    case timeline = 0
    case partners = 1
    case log = 2
    case health = 3
    case settings = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .partners: return "Partners"
        case .log:      return "Log"
        case .health:   return "Health"
        case .settings: return "Settings"
        }
    }

    var glyph: SWGlyph {
        switch self {
        case .timeline: return .timeline
        case .partners: return .partners
        case .log:      return .log
        case .health:   return .health
        case .settings: return .settings
        }
    }
}

// MARK: - Root

struct SWRootView: View {
    @StateObject private var store = SWStore()
    @StateObject private var lock = SWLockController()
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: SWTab = .timeline
    @State private var showOnboarding = false
    @State private var didPrepare = false
    @State private var isFrontmost = true

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .timeline:
                        NavigationView { SWTimelineView(store: store) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case .partners:
                        NavigationView { SWPartnersView(store: store) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case .log:
                        NavigationView { SWLogView(store: store) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case .health:
                        NavigationView { SWHealthView(store: store) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case .settings:
                        NavigationView { SWSettingsView(store: store, lock: lock) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }

            if store.preferences.discreetModeEnabled && !isFrontmost {
                SWDiscreetOverlay(neutralTitle: store.preferences.neutralTitle)
                    .transition(.opacity)
            }

            if lock.isLocked && store.preferences.privacyLockEnabled {
                SWLockView(controller: lock, neutralTitle: store.preferences.neutralTitle)
            }

            // Last sibling: nothing scrolled can ever draw over the clock.
            VStack(spacing: 0) {
                SWStatusStrip()
                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $showOnboarding) {
            // On a first run the explainer is the only place `onboardingSeen` is
            // set, so a swipe-down would silently skip it. Every other
            // presentation stays freely dismissible.
            SWOnboardingView(preferences: $store.preferences, isFirstRun: !store.preferences.onboardingSeen)
                .interactiveDismissDisabled(!store.preferences.onboardingSeen)
        }
        .onAppear { prepare() }
        .onChange(of: lock.isLocked) { locked in
            if !locked { offerOnboardingIfNeeded() }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                isFrontmost = true
                // The record is written with complete file protection, so a load
                // attempted while the device was still locked genuinely could not
                // read it. Retrying now — foreground, and therefore unlocked — is
                // what recovers it. A no-op unless a load actually failed.
                store.retryLoadIfNeeded()
                // Onboarding is only offered from `prepare()` and on unlock, so a
                // swipe-dismissed first run would otherwise wait for a cold launch.
                offerOnboardingIfNeeded()
            case .inactive:
                isFrontmost = false
            case .background:
                isFrontmost = false
                // Re-lock only on a genuine background transition. `.inactive`
                // fires in both directions and would re-lock on every return.
                lock.engage(enabled: store.preferences.privacyLockEnabled)
            @unknown default:
                isFrontmost = false
            }
        }
    }

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true
        lock.engage(enabled: store.preferences.privacyLockEnabled)
        if store.preferences.privacyLockEnabled && lock.isLocked {
            lock.authenticate()
        }
        offerOnboardingIfNeeded()
        store.rebuildSchedule()
    }

    /// The explainer must never appear over the lock screen, so it waits until
    /// the record is actually open.
    private func offerOnboardingIfNeeded() {
        guard !store.preferences.onboardingSeen else { return }
        guard !(lock.isLocked && store.preferences.privacyLockEnabled) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if !store.preferences.onboardingSeen && !showOnboarding {
                showOnboarding = true
            }
        }
    }

    // MARK: Custom tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SWTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 5)
        .background(
            SWTheme.card
                .overlay(
                    Rectangle()
                        .fill(SWTheme.hairline)
                        .frame(height: 1),
                    alignment: .top
                )
                .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func tabButton(_ tab: SWTab) -> some View {
        let selected = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            VStack(spacing: 3) {
                SWIcon(glyph: tab.glyph,
                       size: 23,
                       color: selected ? SWTheme.teal : SWTheme.inkFaint,
                       lineWidth: selected ? 1.9 : 1.6)
                Text(tab.title)
                    .font(SWFont.label(10))
                    .foregroundColor(selected ? SWTheme.teal : SWTheme.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
