import SwiftUI

// MARK: - Shared encounter row

struct SWEncounterRow: View {
    let encounter: SWEncounter
    @ObservedObject var store: SWStore
    var showPartner: Bool = true

    private var style: SWDateStyle { store.preferences.dateStyle }

    var body: some View {
        SWCard(padding: 13) {
            HStack(alignment: .top, spacing: 11) {
                VStack(spacing: 1) {
                    Text(dayNumber)
                        .font(SWFont.monoLarge(19))
                        .foregroundColor(SWTheme.ink)
                    Text(monthAbbrev)
                        .font(SWFont.label(9))
                        .foregroundColor(SWTheme.inkFaint)
                }
                .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    if showPartner {
                        HStack(spacing: 6) {
                            SWChipDot(colorIndex: store.partnerColorIndex(encounter.partnerID), size: 8)
                            Text(store.partnerLabel(encounter.partnerID))
                                .font(SWFont.heading(13.5))
                                .foregroundColor(SWTheme.ink)
                                .lineLimit(1)
                        }
                    } else {
                        Text(SWFormat.long(encounter.date, style: style))
                            .font(SWFont.heading(13.5))
                            .foregroundColor(SWTheme.ink)
                    }

                    Text(activitySummary)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        SWPill(text: encounter.barrierSummary.shortTitle,
                               color: barrierColor)
                        if encounter.higherRiskFlag {
                            SWPill(text: "Flagged", color: SWTheme.alert)
                        }
                        let localSiteCount = encounter.exposedSites.filter { $0 != .blood }.count
                        if localSiteCount > 0 {
                            SWPill(text: localSiteCount == 1 ? "1 site" : "\(localSiteCount) sites",
                                   color: SWTheme.indigo)
                        }
                    }
                }
                Spacer(minLength: 0)
                SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                    .padding(.top, 8)
            }
        }
    }

    private var barrierColor: Color {
        switch encounter.barrierSummary {
        case .used:        return SWTheme.teal
        case .partly:      return SWTheme.amber
        case .notUsed:     return SWTheme.indigo
        case .notRecorded: return SWTheme.inkFaint
        }
    }

    private var activitySummary: String {
        if encounter.activities.isEmpty { return "No activity types recorded" }
        return encounter.activities
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
            .map { $0.type.title }
            .joined(separator: " · ")
    }

    private var dayNumber: String {
        String(SWDay.calendar.dateComponents([.day], from: encounter.date).day ?? 1)
    }

    private var monthAbbrev: String {
        SWFormat.short(encounter.date, style: .dayMonthYear)
            .split(separator: " ").last.map(String.init)?.uppercased() ?? ""
    }
}

// MARK: - Log tab

enum SWLogRange: String, CaseIterable, Identifiable {
    case all
    case ninety
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:    return "All"
        case .ninety: return "90 days"
        case .year:   return "12 months"
        }
    }

    var days: Int? {
        switch self {
        case .all:    return nil
        case .ninety: return 90
        case .year:   return 365
        }
    }
}

struct SWLogView: View {
    @ObservedObject var store: SWStore
    @State private var showEditor = false
    @State private var range: SWLogRange = .all
    @State private var partnerFilter: UUID? = nil
    @State private var filterUnidentified = false

    private var style: SWDateStyle { store.preferences.dateStyle }

    private var filtered: [SWEncounter] {
        var list = store.encounters
        if let days = range.days {
            let cutoff = SWDay.adding(days: -days, to: SWDay.today)
            list = list.filter { SWDay.key($0.date) >= SWDay.key(cutoff) }
        }
        if filterUnidentified {
            list = list.filter { $0.partnerID == nil }
        } else if let partnerFilter = partnerFilter {
            list = list.filter { $0.partnerID == partnerFilter }
        }
        return list.sorted { $0.date > $1.date }
    }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: "Log", subtitle: subtitle) {
                SWIconButton(glyph: .plus, tint: .white, background: SWTheme.teal) {
                    showEditor = true
                }
            }
        } content: {
            if store.encounters.isEmpty {
                emptyState
            } else {
                filterCard
                if filtered.isEmpty {
                    SWCard {
                        Text("No encounters match the current filter.")
                            .font(SWFont.body(13))
                            .foregroundColor(SWTheme.inkSoft)
                        SWSecondaryButton(title: "Clear filters") {
                            range = .all
                            partnerFilter = nil
                            filterUnidentified = false
                        }
                    }
                } else {
                    ForEach(groupedByMonth, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            SWSectionHeader(title: group.label, trailingText: "\(group.items.count)")
                            ForEach(group.items) { encounter in
                                NavigationLink(destination: SWEncounterDetailView(encounterID: encounter.id, store: store)) {
                                    SWEncounterRow(encounter: encounter, store: store)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }

            SWDisclaimerLine(text: "This log is a private record. Nothing in it is transmitted anywhere.")
        }
        .sheet(isPresented: $showEditor) {
            SWEncounterEditorView(store: store, existing: nil)
        }
    }

    private var subtitle: String {
        let count = store.encounters.count
        if count == 0 { return "Nothing logged yet" }
        return "\(count) \(count == 1 ? "encounter" : "encounters") recorded"
    }

    private struct SWMonthGroup {
        let key: Int
        let label: String
        let items: [SWEncounter]
    }

    private var groupedByMonth: [SWMonthGroup] {
        var order: [Int] = []
        var buckets: [Int: [SWEncounter]] = [:]
        for encounter in filtered {
            let parts = SWDay.calendar.dateComponents([.year, .month], from: encounter.date)
            let key = (parts.year ?? 2000) * 100 + (parts.month ?? 1)
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(encounter)
        }
        return order.compactMap { key in
            guard let items = buckets[key], let first = items.first else { return nil }
            return SWMonthGroup(key: key, label: SWFormat.monthLabel(first.date), items: items)
        }
    }

    private var filterCard: some View {
        SWCard(padding: 12) {
            SWFieldLabel(text: "Date range")
            SWSegmented(options: SWLogRange.allCases,
                        titleFor: { $0.title },
                        selection: $range,
                        compact: true)

            if !store.partners.isEmpty || !store.anonymousEncounters.isEmpty {
                SWFieldLabel(text: "Partner")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        filterChip(title: "Everyone",
                                   active: partnerFilter == nil && !filterUnidentified,
                                   color: SWTheme.ink) {
                            partnerFilter = nil
                            filterUnidentified = false
                        }
                        ForEach(store.partners) { partner in
                            filterChip(title: partner.displayLabel,
                                       active: partnerFilter == partner.id && !filterUnidentified,
                                       color: SWTheme.chip(partner.colorIndex)) {
                                filterUnidentified = false
                                partnerFilter = (partnerFilter == partner.id) ? nil : partner.id
                            }
                        }
                        if !store.anonymousEncounters.isEmpty {
                            filterChip(title: "Not identified",
                                       active: filterUnidentified,
                                       color: SWTheme.chip(7)) {
                                partnerFilter = nil
                                filterUnidentified.toggle()
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func filterChip(title: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SWFont.label(11))
                .foregroundColor(active ? .white : color)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(active ? color : color.opacity(0.12))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyState: some View {
        SWCard {
            SWEmptyState(glyph: .log,
                         title: "Nothing logged yet",
                         message: "An entry needs a date and the activity types involved. Those two answers are what the engine uses to work out which specimens matter and when each one becomes meaningful.",
                         actionTitle: "Log an encounter") {
                showEditor = true
            }
            Rectangle().fill(SWTheme.hairline).frame(height: 1)
            Text("Activity types are recorded in neutral clinical terms because they decide which specimen sites appear on your schedule. The app has no opinion about any of them.")
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Encounter detail

struct SWEncounterDetailView: View {
    let encounterID: UUID
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    private var style: SWDateStyle { store.preferences.dateStyle }
    private var encounter: SWEncounter? { store.encounter(encounterID) }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: encounter.map { SWFormat.medium($0.date, style: style) } ?? "Encounter",
                               subtitle: encounter.map { store.partnerLabel($0.partnerID) } ?? "",
                               onBack: { presentationMode.wrappedValue.dismiss() }) {
                    if encounter != nil {
                        SWIconButton(glyph: .pencil, tint: SWTheme.ink) { showEditor = true }
                    }
                }
            } content: {
                if let encounter = encounter {
                    detailCard(encounter)
                    activitiesCard(encounter)
                    sitesCard(encounter)
                    scheduleCard(encounter)
                    if !encounter.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        SWCard {
                            SWSectionHeader(title: "Notes")
                            Text(encounter.notes)
                                .font(SWFont.body(13.5))
                                .foregroundColor(SWTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    dangerZone
                } else {
                    SWCard {
                        Text("This entry is no longer on the record.")
                            .font(SWFont.body(13))
                            .foregroundColor(SWTheme.inkSoft)
                    }
                }
                SWDisclaimerLine()
            }

            if showDeleteConfirm {
                SWConfirmOverlay(
                    title: "Delete this encounter?",
                    message: "Every date on the Timeline that came from it will be removed as well. This cannot be undone.",
                    confirmTitle: "Delete",
                    onConfirm: {
                        store.deleteEncounter(encounterID)
                        showDeleteConfirm = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    onCancel: { showDeleteConfirm = false }
                )
            }
        }
        .sheet(isPresented: $showEditor) {
            SWEncounterEditorView(store: store, existing: encounter)
        }
    }

    private func detailCard(_ encounter: SWEncounter) -> some View {
        SWCard {
            SWSectionHeader(title: "Entry")
            SWKeyValueRow(key: "Date", value: SWFormat.long(encounter.date, style: style))
            SWKeyValueRow(key: "Time", value: SWFormat.clock(encounter.date), monospaced: true)
            SWKeyValueRow(key: "Partner", value: store.partnerLabel(encounter.partnerID))
            SWKeyValueRow(key: "Barrier", value: encounter.barrierSummary.title)
            SWKeyValueRow(key: "Higher-risk flag",
                          value: encounter.higherRiskFlag ? "Set" : "Not set",
                          valueColor: encounter.higherRiskFlag ? SWTheme.alert : SWTheme.ink)
            SWKeyValueRow(key: "Days ago", value: "\(max(0, SWDay.between(encounter.date, SWDay.today)))")
        }
    }

    private func activitiesCard(_ encounter: SWEncounter) -> some View {
        SWCard {
            SWSectionHeader(title: "Activity types",
                            subtitle: "Each one decides which specimen the schedule lists.")
            if encounter.activities.isEmpty {
                Text("None recorded, so this entry produces no dates.")
                    .font(SWFont.body(13))
                    .foregroundColor(SWTheme.inkSoft)
            } else {
                ForEach(encounter.activities.sorted { $0.type.sortOrder < $1.type.sortOrder }) { activity in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(activity.type.title)
                                .font(SWFont.heading(13.5))
                                .foregroundColor(SWTheme.ink)
                            Spacer(minLength: 4)
                            SWPill(text: activity.barrier.title, color: SWTheme.indigo)
                        }
                        Text(activity.type.clinicalNote)
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func sitesCard(_ encounter: SWEncounter) -> some View {
        SWCard {
            SWSectionHeader(title: "Specimen sites derived")
            ForEach(encounter.exposedSites, id: \.rawValue) { site in
                HStack(alignment: .top, spacing: 9) {
                    SWIcon(glyph: site == .blood ? .vial : .swab, size: 15,
                           color: SWTheme.teal, lineWidth: 1.5)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.shortLabel)
                            .font(SWFont.heading(13))
                            .foregroundColor(SWTheme.ink)
                        Text(site.explainer)
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func scheduleCard(_ encounter: SWEncounter) -> some View {
        let rows = store.schedule.evaluated.filter { $0.row.encounterID == encounter.id }
        return SWCard {
            SWSectionHeader(title: "Dates from this entry", trailingText: "\(rows.count)")
            if rows.isEmpty {
                Text("No dates are outstanding from this entry. That happens when the activity types produce no rows, when the entries involved are switched off in Settings, or when everything is already covered.")
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(rows.prefix(24)) { item in
                    HStack(alignment: .top, spacing: 8) {
                        SWChipDot(colorIndex: item.row.infection?.colorIndex ?? 0, size: 7)
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(item.row.infectionShortName) · \(item.row.site.title)")
                                .font(SWFont.bodyTight(12.5))
                                .foregroundColor(SWTheme.ink)
                            Text("Detectable from \(SWFormat.medium(item.row.earliestDate, style: style)) · described as conclusive \(SWFormat.medium(item.row.conclusiveDate, style: style))")
                                .font(SWFont.label(10))
                                .foregroundColor(SWTheme.inkFaint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text(item.coverage.title)
                            .font(SWFont.label(9))
                            .foregroundColor(item.coverage.isSatisfied ? SWTheme.teal : SWTheme.amber)
                    }
                    .padding(.vertical, 2)
                }
                if rows.count > 24 {
                    Text("\(rows.count - 24) further rows are not listed.")
                        .font(SWFont.label(10))
                        .foregroundColor(SWTheme.inkFaint)
                }
            }
            SWDisclaimerLine(text: SWReferenceLibrary.windowCaveat)
        }
    }

    private var dangerZone: some View {
        SWCard(background: SWTheme.alertSoft.opacity(0.5), borderColor: SWTheme.alert.opacity(0.22)) {
            SWSectionHeader(title: "Remove")
            SWSecondaryButton(title: "Delete this encounter", glyph: .trash, tint: SWTheme.alert) {
                showDeleteConfirm = true
            }
        }
    }
}
