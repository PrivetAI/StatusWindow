import SwiftUI

// MARK: - Encounter editor

struct SWEncounterEditorView: View {
    @ObservedObject var store: SWStore
    let existing: SWEncounter?
    @Environment(\.presentationMode) private var presentationMode

    @State private var date: Date = Date()
    @State private var partnerID: UUID? = nil
    @State private var selected: [SWActivityType: SWBarrierUse] = [:]
    @State private var higherRisk: Bool = false
    @State private var notes: String = ""
    @State private var focusedTag: Int? = nil
    @State private var didLoad = false
    @State private var showRiskInfo = false

    private var orderedActivities: [SWActivityType] {
        SWActivityType.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var canSave: Bool { !selected.isEmpty }

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                header
                Rectangle().fill(SWTheme.hairline).frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        whenCard
                        partnerCard
                        activitiesCard
                        riskCard
                        notesCard
                        previewCard
                        SWPrimaryButton(title: existing == nil ? "Save encounter" : "Save changes",
                                        glyph: .check,
                                        enabled: canSave) {
                            save()
                        }
                        if !canSave {
                            Text("Select at least one activity type. That is what tells the engine which specimens to schedule.")
                                .font(SWFont.bodyTight(11.5))
                                .foregroundColor(SWTheme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        SWDisclaimerLine(text: "Stored only on this device. The app records what you enter and computes dates from it.")
                    }
                    .padding(.horizontal, SWMetrics.pagePadding)
                    .padding(.top, 14)
                    .padding(.bottom, 44)
                }
            }

            if showRiskInfo {
                SWInfoOverlay(title: "What the higher-risk flag does",
                              paragraphs: [
                                "Setting this flag is the only thing that arms the 72-hour post-exposure countdown on the Timeline. It does not change any window date and it does not alter which specimens are scheduled.",
                                "The flag is yours to set. The app does not assess risk, does not score anything you enter, and has no opinion about any activity type or about barrier use.",
                                "Published guidance describes post-exposure prophylaxis as generally started within 72 hours of an exposure, and describes sooner as better. Whether it is appropriate in any particular situation is a clinical assessment made by a service, not by an app.",
                                "If you think that may apply to you right now, contact a sexual health service or an emergency service rather than reading further here."
                              ],
                              onClose: { showRiskInfo = false })
            }
        }
        .onAppear(perform: loadOnce)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(existing == nil ? "Log an encounter" : "Edit encounter")
                .font(SWFont.title(18))
                .foregroundColor(SWTheme.ink)
            Spacer(minLength: 6)
            SWIconButton(glyph: .close, tint: SWTheme.inkSoft) {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding(.horizontal, SWMetrics.pagePadding)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var whenCard: some View {
        SWCard {
            SWFieldLabel(text: "When",
                         caption: "Every window date is counted from this moment. The time matters only for the 72-hour flags.")
            SWDateField(title: "Date and time", date: $date, includeTime: true,
                        range: SWDay.adding(days: -3650, to: SWDay.today)...SWDay.adding(days: 1, to: SWDay.today))
            HStack(spacing: 8) {
                quickDateButton("Today", days: 0)
                quickDateButton("Yesterday", days: 1)
                quickDateButton("3 days ago", days: 3)
                quickDateButton("A week ago", days: 7)
            }
        }
    }

    private func quickDateButton(_ title: String, days: Int) -> some View {
        Button(action: {
            let base = SWDay.adding(days: -days, to: SWDay.today)
            let parts = SWDay.calendar.dateComponents([.hour, .minute], from: date)
            date = SWDay.calendar.date(bySettingHour: parts.hour ?? 21,
                                       minute: parts.minute ?? 0,
                                       second: 0,
                                       of: base) ?? base
        }) {
            Text(title)
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.teal)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(SWTheme.tealSoft.opacity(0.7)))
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var partnerCard: some View {
        SWCard {
            SWFieldLabel(text: "Partner",
                         caption: "Optional. An encounter can stay unidentified.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    chip(title: "Not identified", active: partnerID == nil, color: SWTheme.chip(7)) {
                        partnerID = nil
                    }
                    ForEach(store.partners) { partner in
                        chip(title: partner.displayLabel,
                             active: partnerID == partner.id,
                             color: SWTheme.chip(partner.colorIndex)) {
                            partnerID = partner.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            if store.partners.isEmpty {
                Text("You have no partner entries yet. Add them from the Partners tab whenever you want to; encounters can always be reattributed later.")
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func chip(title: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SWFont.label(11))
                .foregroundColor(active ? .white : color)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? color : color.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var activitiesCard: some View {
        SWCard {
            SWFieldLabel(text: "Activity types",
                         caption: "Neutral clinical terms, exactly as a clinic intake form words them. Each selection decides which specimen sites appear on your schedule.")
            VStack(spacing: 10) {
                ForEach(orderedActivities, id: \.rawValue) { type in
                    activityRow(type)
                }
            }
        }
    }

    private func activityRow(_ type: SWActivityType) -> some View {
        let isOn = selected[type] != nil
        return VStack(alignment: .leading, spacing: 7) {
            SWCheckRow(title: type.title,
                       caption: isOn ? type.clinicalNote : nil,
                       isOn: isOn) {
                if isOn {
                    selected.removeValue(forKey: type)
                } else {
                    selected[type] = .notRecorded
                }
            }
            if isOn {
                SWSegmented(options: SWBarrierUse.allCases,
                            titleFor: { $0.title },
                            selection: Binding(
                                get: { selected[type] ?? .notRecorded },
                                set: { selected[type] = $0 }
                            ),
                            compact: true)
                    .padding(.leading, 33)
            }
        }
        .padding(.vertical, 2)
    }

    private var riskCard: some View {
        SWCard(background: higherRisk ? SWTheme.alertSoft : SWTheme.card,
               borderColor: higherRisk ? SWTheme.alert.opacity(0.3) : SWTheme.cardEdge) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mark as higher-risk")
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                    Text("Arms the 72-hour post-exposure countdown on the Timeline. It changes nothing else, and the app never sets it for you.")
                        .font(SWFont.bodyTight(12))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                SWSwitch(isOn: $higherRisk)
            }
            Button(action: { showRiskInfo = true }) {
                HStack(spacing: 6) {
                    SWIcon(glyph: .info, size: 13, color: SWTheme.teal, lineWidth: 1.4)
                    Text("What this means")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if !higherRisk && promptsRiskQuestion && withinSeventyTwoHours {
                Text("One or more of the activity types you selected is among those published guidance most often discusses in the context of the 72-hour window. Whether to set the flag is entirely your decision — the app does not assess anything.")
                    .font(SWFont.bodyTight(12))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if higherRisk && withinSeventyTwoHours {
                Text("This exposure is inside the 72-hour period described in published guidance. If you have not already, contact a sexual health service or an emergency service now.")
                    .font(SWFont.bodyTight(12))
                    .foregroundColor(SWTheme.alert)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// True when a selected activity type is one published guidance most often
    /// discusses in the context of the 72-hour window. It only surfaces a neutral
    /// note; it never sets the flag and it never scores anything.
    private var promptsRiskQuestion: Bool {
        selected.keys.contains { $0.promptsRiskQuestion }
    }

    private var withinSeventyTwoHours: Bool {
        date.addingTimeInterval(72 * 3600) > Date() && date <= Date().addingTimeInterval(3600)
    }

    private var notesCard: some View {
        SWCard {
            SWFieldLabel(text: "Notes (optional)")
            SWTextField(placeholder: "Anything you want to remember",
                        text: $notes,
                        focusTag: 11,
                        focusedTag: $focusedTag,
                        multiline: true)
        }
    }

    private var previewCard: some View {
        let sites = derivedSites
        return SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            SWSectionHeader(title: "What this will schedule")
            if sites.isEmpty {
                Text("Nothing yet — select at least one activity type.")
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
            } else {
                ForEach(sites, id: \.rawValue) { site in
                    HStack(spacing: 8) {
                        SWIcon(glyph: site == .blood ? .vial : .swab, size: 14,
                               color: SWTheme.teal, lineWidth: 1.4)
                        Text(site.shortLabel)
                            .font(SWFont.bodyTight(12.5))
                            .foregroundColor(SWTheme.ink)
                        Spacer(minLength: 0)
                    }
                }
                Text("Which entries are included, and therefore which dates appear, depends on the selection in Settings.")
                    .font(SWFont.label(10))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var derivedSites: [SWSpecimenSite] {
        guard !selected.isEmpty else { return [] }
        var set = Set<SWSpecimenSite>()
        for type in selected.keys {
            for site in type.exposedSites { set.insert(site) }
        }
        set.insert(.blood)
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: Load and save

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing = existing else {
            date = Date()
            return
        }
        date = existing.date
        partnerID = existing.partnerID
        higherRisk = existing.higherRiskFlag
        notes = existing.notes
        var map: [SWActivityType: SWBarrierUse] = [:]
        for entry in existing.activities { map[entry.type] = entry.barrier }
        selected = map
    }

    private func save() {
        guard canSave else { return }
        var record = existing ?? SWEncounter()
        record.date = date
        record.partnerID = partnerID
        record.higherRiskFlag = higherRisk
        record.notes = notes
        record.activities = selected
            .map { SWActivityEntry(type: $0.key, barrier: $0.value) }
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
        if existing == nil {
            store.addEncounter(record)
        } else {
            store.updateEncounter(record)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
