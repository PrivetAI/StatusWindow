import SwiftUI

// MARK: - Settings

private enum SWSettingsSheet: Identifiable {
    case privacy
    case onboarding

    var id: String {
        switch self {
        case .privacy:    return "privacy"
        case .onboarding: return "onboarding"
        }
    }
}

private enum SWResetStage: Int {
    case idle = 0
    case first = 1
    case second = 2
}

struct SWSettingsView: View {
    @ObservedObject var store: SWStore
    @ObservedObject var lock: SWLockController

    @State private var sheet: SWSettingsSheet?
    @State private var resetStage: SWResetStage = .idle
    @State private var showDisclaimer = false
    @State private var focusedTag: Int? = nil
    @State private var titleDraft: String = ""
    @State private var didLoadTitle = false

    private let privacyAddress = "https://statuswindow.org"

    private var toleranceOptions: [Int] { [7, 14, 21, 30] }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: "Settings",
                               subtitle: "Privacy, schedule and display")
            } content: {
                privacyCard
                discreetCard
                scheduleCard
                assayCard
                mergingCard
                displayCard
                aboutCard
                resetCard
                footerCard
            }

            if showDisclaimer {
                SWInfoOverlay(title: "Full disclaimer",
                              paragraphs: [
                                SWReferenceLibrary.disclaimerLong,
                                "Status Window computes dates from information you enter. It does not and cannot assess anyone's health, it never states or estimates a likelihood, and it does not interpret any result you record.",
                                "Every clinical interval it uses is a figure commonly cited in published guidance. Windows vary by test and by laboratory, and the guidance given to you by your own clinical service takes precedence over anything shown in this app.",
                                "If you have had a possible higher-risk exposure in the last 72 hours, or if anything has appeared that concerns you, published guidance describes contacting a sexual health service or an emergency service now rather than waiting for any date."
                              ],
                              onClose: { showDisclaimer = false })
            }

            if resetStage == .first {
                SWConfirmOverlay(
                    title: "Erase everything?",
                    message: "This deletes every partner entry, encounter, test record, prophylaxis entry and vaccination dose, and removes the file they are stored in. It cannot be undone and there is no backup anywhere.",
                    confirmTitle: "Continue",
                    confirmTint: SWTheme.alert,
                    onConfirm: { resetStage = .second },
                    onCancel: { resetStage = .idle }
                )
            }

            if resetStage == .second {
                SWConfirmOverlay(
                    title: "Confirm once more",
                    message: eraseSummaryMessage,
                    confirmTitle: "Erase everything permanently",
                    confirmTint: SWTheme.alert,
                    onConfirm: {
                        store.eraseEverything()
                        resetStage = .idle
                    },
                    onCancel: { resetStage = .idle }
                )
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .privacy:
                SWPrivacyPanelSheet(address: privacyAddress)
            case .onboarding:
                SWOnboardingView(preferences: $store.preferences, isFirstRun: false)
            }
        }
        .onAppear {
            if !didLoadTitle {
                didLoadTitle = true
                titleDraft = store.preferences.neutralTitle
            }
        }
    }

    // MARK: Privacy

    /// Counts read back as a sentence, so a single record does not read "1 entries".
    private func plural(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private var eraseSummaryMessage: String {
        let counts = store.recordCounts
        return plural(counts.partners, "partner entry", "partner entries")
            + ", " + plural(counts.encounters, "encounter", "encounters")
            + ", " + plural(counts.tests, "test record", "test records")
            + " and " + plural(counts.doses, "recorded dose day", "recorded dose days")
            + " will be permanently erased."
    }

    /// Written per availability. Interpolating the method label directly produced
    /// "Uses Not available." on a device with neither biometrics nor a passcode.
    private var lockMethodCaption: String {
        switch lock.availability {
        case .biometric(let name):
            return "Uses \(name). If biometrics are unavailable the device passcode is used instead."
        case .passcodeOnly:
            return "Uses the device passcode. If you enroll biometrics they are used instead."
        case .unavailable:
            return "This device has neither biometrics nor a passcode set, so there is nothing for the lock to check."
        }
    }

    private var privacyCard: some View {
        SWCard {
            SWSectionHeader(title: "Privacy lock",
                            subtitle: "On by default. This is the most sensitive record in the app.")
            SWToggleRow(title: "Require authentication to open",
                        caption: lockMethodCaption,
                        isOn: Binding(
                            get: { store.preferences.privacyLockEnabled },
                            set: { newValue in
                                store.preferences.privacyLockEnabled = newValue
                                if !newValue { lock.unlockWithoutPrompt() }
                            }
                        ))

            if lock.availability == .unavailable {
                SWNoticeCard(glyph: .alert,
                             title: "No device passcode is set",
                             message: "Without a passcode or enrolled biometrics there is nothing for the lock to check, so it cannot be enforced and the app will open directly. Setting a device passcode in the system settings is what enables it. You are not shut out of your own record either way.",
                             tint: SWTheme.amber,
                             background: SWTheme.amberSoft)
            }

            Text("The record itself is written to a single file with the strongest file protection iOS offers, which means it cannot be read while the device is locked. Nothing is stored in preferences, nothing is synced and nothing is uploaded.")
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Discreet mode

    private var discreetCard: some View {
        SWCard {
            SWSectionHeader(title: "Discreet mode")
            SWToggleRow(title: "Hide contents when not frontmost",
                        caption: "Covers the interface whenever the app is not in the foreground, so the app switcher shows only a neutral card.",
                        isOn: Binding(
                            get: { store.preferences.discreetModeEnabled },
                            set: { store.preferences.discreetModeEnabled = $0 }
                        ))

            SWFieldLabel(text: "Neutral title",
                         caption: "Shown on the lock screen and on the discreet cover.")
            SWTextField(placeholder: "Status Window",
                        text: $titleDraft,
                        focusTag: 31,
                        focusedTag: $focusedTag)
            HStack(spacing: 8) {
                SWSecondaryButton(title: "Apply title", glyph: .check, tint: SWTheme.teal) {
                    let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.preferences.neutralTitle = trimmed.isEmpty ? "Status Window" : trimmed
                    if trimmed.isEmpty { titleDraft = "Status Window" }
                    focusedTag = nil
                }
                SWSecondaryButton(title: "Reset", tint: SWTheme.inkSoft) {
                    titleDraft = "Status Window"
                    store.preferences.neutralTitle = "Status Window"
                    focusedTag = nil
                }
            }
            Text("Currently: \(store.preferences.neutralTitle)")
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.inkFaint)
        }
    }

    // MARK: Schedule composition

    private var scheduleCard: some View {
        SWCard {
            SWSectionHeader(title: "Entries on the schedule",
                            subtitle: "Switch off anything your service does not test for, or anything already under care.",
                            trailingText: "\(store.preferences.enabledInfectionIDs.count)/\(SWInfectionCatalog.schedulableIDs.count)")
            ForEach(SWInfectionCatalog.all.filter { $0.schedulable }) { infection in
                VStack(alignment: .leading, spacing: 4) {
                    SWToggleRow(title: infection.name,
                                caption: scheduleCaption(infection),
                                isOn: Binding(
                                    get: { store.isInfectionEnabled(infection.id) },
                                    set: { store.setInfectionEnabled(infection.id, $0) }
                                ))
                    if store.isUnderCare(infection.id) {
                        SWPill(text: "Marked under care", color: SWTheme.indigo)
                    }
                }
                .padding(.vertical, 3)
                if infection.id != lastSchedulableID {
                    Rectangle().fill(SWTheme.hairline).frame(height: 1)
                }
            }
            Text("Three further entries — hepatitis A, mpox and HPV — never produce window dates and so cannot be scheduled. The reasons are described in the entry reference.")
                .font(SWFont.bodyTight(11))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lastSchedulableID: String {
        SWInfectionCatalog.all.filter { $0.schedulable }.last?.id ?? ""
    }

    private func scheduleCaption(_ infection: SWInfection) -> String {
        guard let assay = infection.assays.first(where: { $0.scheduled }) else { return "" }
        let base = "\(assay.shortName), day \(assay.earliestDay) to day \(assay.conclusiveDay)."
        return infection.defaultEnabled ? base : base + " Off by default — most services do not screen for this routinely."
    }

    // MARK: Assay preference

    private var assayCard: some View {
        SWCard {
            SWSectionHeader(title: "Which test the schedule assumes",
                            subtitle: "Two entries have very different windows depending on the technology used.")

            SWFieldLabel(text: "HIV")
            SWSegmented(options: ["hiv_agab", "hiv_nat", "hiv_rapid"],
                        titleFor: { SWInfectionCatalog.assay($0)?.shortName ?? "—" },
                        selection: Binding(
                            get: { store.preferences.hivAssayPreference },
                            set: { store.preferences.hivAssayPreference = $0 }
                        ),
                        compact: true)
            if let assay = SWInfectionCatalog.assay(store.preferences.hivAssayPreference) {
                Text("\(assay.name) — \(assay.note)")
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            SWFieldLabel(text: "Hepatitis C")
            SWSegmented(options: ["hcv_ab", "hcv_rna"],
                        titleFor: { SWInfectionCatalog.assay($0)?.shortName ?? "—" },
                        selection: Binding(
                            get: { store.preferences.hcvAssayPreference },
                            set: { store.preferences.hcvAssayPreference = $0 }
                        ),
                        compact: true)
            if let assay = SWInfectionCatalog.assay(store.preferences.hcvAssayPreference) {
                Text("\(assay.name) — \(assay.note)")
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Set these to match the tests actually available to you. Choosing a shorter window than the test you take would produce dates that are too early.")
                .font(SWFont.bodyTight(11))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Merging

    private var mergingCard: some View {
        SWCard {
            SWSectionHeader(title: "Grouping tolerance",
                            subtitle: "Dates within this many days of each other are merged into one visit.")
            SWSegmented(options: toleranceOptions,
                        titleFor: { "\($0) d" },
                        selection: Binding(
                            get: { store.preferences.clusterToleranceDays },
                            set: { store.preferences.clusterToleranceDays = $0 }
                        ),
                        compact: true)
            Text("A wider tolerance means fewer visits, each placed slightly later. A narrower one closes individual entries sooner but produces more separate dates.")
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            SWKeyValueRow(key: "Dates on your Timeline now",
                          value: "\(store.schedule.visits.count)")
        }
    }

    // MARK: Display

    private var displayCard: some View {
        SWCard {
            SWSectionHeader(title: "Display")
            SWFieldLabel(text: "Date format")
            VStack(spacing: 6) {
                ForEach(SWDateStyle.allCases) { option in
                    SWCheckRow(title: option.title,
                               caption: option.shortTitle,
                               isOn: store.preferences.dateStyle == option) {
                        store.preferences.dateStyle = option
                    }
                }
            }
            Rectangle().fill(SWTheme.hairline).frame(height: 1)
            SWToggleRow(title: "Week starts on Monday",
                        caption: "Used where this record groups days into weeks.",
                        isOn: Binding(
                            get: { store.preferences.weekStartsMonday },
                            set: { store.preferences.weekStartsMonday = $0 }
                        ))
        }
    }

    // MARK: About

    private var aboutCard: some View {
        SWCard {
            SWSectionHeader(title: "About")

            SWNavRow(title: "How this works",
                     caption: "Re-open the explainer shown on first run.") {
                sheet = .onboarding
            }

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            SWNavRow(title: "Full disclaimer",
                     caption: "What this app is, and what it is not.") {
                showDisclaimer = true
            }

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            SWNavRow(title: "Privacy Policy",
                     caption: "Opens in an in-app panel.") {
                sheet = .privacy
            }

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            SWKeyValueRow(key: "Version", value: "1.0", monospaced: true)
            SWKeyValueRow(key: "Reference cards", value: "\(SWReferenceLibrary.count)", monospaced: true)
            SWKeyValueRow(key: "Entries tracked", value: "12", monospaced: true)
            SWKeyValueRow(key: "Window rows in the table",
                          value: "\(SWInfectionCatalog.scheduledAssayCount)", monospaced: true)
        }
    }

    // MARK: Reset

    private var resetCard: some View {
        SWCard(background: SWTheme.alertSoft.opacity(0.55), borderColor: SWTheme.alert.opacity(0.25)) {
            SWSectionHeader(title: "Erase all data")
            Text("This deletes every record in the app and removes the file they live in. There is no backup, no copy on any server, and no way to recover anything afterwards.")
                .font(SWFont.bodyTight(12.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                countColumn("\(store.recordCounts.partners)", "partners")
                countColumn("\(store.recordCounts.encounters)", "encounters")
                countColumn("\(store.recordCounts.tests)", "tests")
                countColumn("\(store.recordCounts.doses)", "dose days")
            }
            SWSecondaryButton(title: "Erase everything", glyph: .trash, tint: SWTheme.alert) {
                resetStage = .first
            }
        }
    }

    private func countColumn(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SWFont.monoLarge(18))
                .foregroundColor(SWTheme.ink)
            Text(label)
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var footerCard: some View {
        SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            Text("Status Window keeps a private record and computes dates from it. It is not a medical device, it does not provide medical advice, and it never interprets a result. For anything about your own health, speak to a qualified clinician or a sexual health service.")
                .font(SWFont.bodyTight(12))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if store.lastWriteFailed {
                SWNoticeCard(glyph: .alert,
                             title: "The last save did not complete",
                             message: "The record could not be written to disk. If the device is very low on storage, freeing some space and reopening the app usually resolves it.",
                             tint: SWTheme.amber,
                             background: SWTheme.amberSoft)
            }
            if store.loadFailed {
                SWNoticeCard(glyph: .alert,
                             title: "The record could not be read",
                             message: "A record file is on this device but it could not be opened, so the app is showing an empty record. Nothing has been overwritten and nothing has been lost — no save can run while this is showing. The file cannot be read while the device is locked, so unlock the device, then close and reopen the app.",
                             tint: SWTheme.amber,
                             background: SWTheme.amberSoft)
            }
        }
    }
}

// MARK: - Privacy Policy sheet
//
// The panel itself carries no chrome of any kind, so presented bare it was a
// black rectangle dismissible only by a swipe, with nothing to say when the page
// did not load at all.

private struct SWPrivacyPanelSheet: View {
    let address: String
    @Environment(\.presentationMode) private var presentationMode

    @State private var failureMessage: String? = nil
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("Privacy Policy")
                        .font(SWFont.title(19))
                        .foregroundColor(SWTheme.ink)
                    Spacer(minLength: 6)
                    SWIconButton(glyph: .close, tint: SWTheme.inkSoft) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Rectangle().fill(SWTheme.hairline).frame(height: 1)

                if let message = failureMessage {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            SWNoticeCard(glyph: .alert,
                                         title: "The page could not be loaded",
                                         message: "\(message) This page is hosted online, so it needs a connection. Nothing in your record is involved either way.",
                                         tint: SWTheme.amber,
                                         background: SWTheme.amberSoft)
                            SWSecondaryButton(title: "Try again", tint: SWTheme.teal) {
                                failureMessage = nil
                                reloadToken += 1
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    }
                    Spacer(minLength: 0)
                } else {
                    SWWebPanel(panelAddress: address,
                               onLoadFailure: { message in failureMessage = message })
                        .id(reloadToken)
                        .edgesIgnoringSafeArea(.bottom)
                }
            }
        }
    }
}
