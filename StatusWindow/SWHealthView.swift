import SwiftUI

// MARK: - Health hub

struct SWHealthView: View {
    @ObservedObject var store: SWStore
    @State private var showCopiedNote = false
    @State private var showSummaryOverlay = false

    private var style: SWDateStyle { store.preferences.dateStyle }
    private var schedule: SWSchedule { store.schedule }

    private var summaryText: String {
        SWWindowEngine.statusSummary(schedule: schedule,
                                     encounters: store.encounters,
                                     testRecords: store.testRecords,
                                     preferences: store.preferences)
    }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: "Health", subtitle: "Your own record, kept on this device")
            } content: {
                statusCard
                careFlagsCard
                sectionsCard
                referenceCard
                SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
            }

            if showSummaryOverlay {
                SWInfoOverlay(title: "Self-reported summary",
                              paragraphs: [
                                "The text below has been copied to the clipboard. It is written by you, it has not been verified by any service, and it must not be used in place of laboratory reports.",
                                summaryText
                              ],
                              onClose: {
                                showSummaryOverlay = false
                                showCopiedNote = false
                              })
            }
        }
    }

    // MARK: Status

    private var statusCard: some View {
        let latest = store.latestTestRecord
        let fullPanel = store.latestFullPanel
        let covered = schedule.coveredRows.count
        let total = schedule.evaluated.count

        return SWCard {
            SWSectionHeader(title: "Status card",
                            subtitle: "A summary of what this record contains.")

            HStack(alignment: .top, spacing: 14) {
                SWCoverageDial(covered: covered, total: total, size: 76)
                VStack(alignment: .leading, spacing: 5) {
                    if let latest = latest {
                        Text("Last recorded specimen")
                            .font(SWFont.label(10))
                            .foregroundColor(SWTheme.inkFaint)
                        Text(SWFormat.long(latest.collectedOn, style: style))
                            .font(SWFont.heading(14))
                            .foregroundColor(SWTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(latest.displayClinic)
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                    } else {
                        Text("No specimen recorded")
                            .font(SWFont.heading(14))
                            .foregroundColor(SWTheme.ink)
                        Text("Add one from the test record section below.")
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            SWKeyValueRow(key: "Last panel covering every entry switched on",
                          value: fullPanel.map { SWFormat.medium($0.collectedOn, style: style) } ?? "—")
            SWKeyValueRow(key: "Exposures logged since the last specimen",
                          value: "\(store.encountersSinceLatestPanel)")
            // Deliberately the same accessor the Timeline headline uses, so the
            // two screens can never name different dates. When that date is
            // already overdue the caption has to say so rather than reading
            // "Next date … 12 days ago".
            if let next = schedule.nextVisit {
                SWKeyValueRow(key: next.isDue ? "Earliest date on the Timeline" : "Next date on the Timeline",
                              value: SWFormat.medium(next.date, style: style),
                              valueColor: SWTheme.teal)
                SWKeyValueRow(key: "That is",
                              value: next.isDue
                                ? "\(SWFormat.relativeDay(next.date).capitalizingFirst) — available now"
                                : SWFormat.relativeDay(next.date).capitalizingFirst)
            } else {
                SWKeyValueRow(key: "Next date on the Timeline",
                              value: "—",
                              valueColor: SWTheme.inkFaint)
            }

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            SWSecondaryButton(title: showCopiedNote ? "Copied to clipboard" : "Copy summary as text",
                              glyph: .copy,
                              tint: SWTheme.teal) {
                UIPasteboard.general.string = summaryText
                showCopiedNote = true
                showSummaryOverlay = true
            }
            Text("The copied text is explicitly marked as self-reported and not a clinical document. It contains dates, service labels and values you entered — nothing else, and nothing about any partner.")
                .font(SWFont.bodyTight(11))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Care flags

    @ViewBuilder
    private var careFlagsCard: some View {
        if !store.careFlags.isEmpty {
            SWCard(background: SWTheme.tealSoft.opacity(0.5), borderColor: SWTheme.teal.opacity(0.25)) {
                SWSectionHeader(title: "Marked as under care",
                                subtitle: "These entries are not prompted on the Timeline.")
                ForEach(store.careFlags) { flag in
                    HStack(alignment: .top, spacing: 9) {
                        SWIcon(glyph: .shield, size: 16, color: SWTheme.teal, lineWidth: 1.5)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SWInfectionCatalog.name(flag.infectionID))
                                .font(SWFont.heading(13.5))
                                .foregroundColor(SWTheme.ink)
                            Text("Since \(SWFormat.medium(flag.since, style: style)). Follow your clinic's guidance.")
                                .font(SWFont.bodyTight(11.5))
                                .foregroundColor(SWTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Button(action: { store.setCareFlag(flag.infectionID, active: false) }) {
                            Text("Clear")
                                .font(SWFont.label(10))
                                .foregroundColor(SWTheme.teal)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(SWTheme.card))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 3)
                }
                SWDisclaimerLine(text: "The app records the flag and stops prompting. It offers no interpretation of any result.")
            }
        }
    }

    // MARK: Sections

    private var sectionsCard: some View {
        SWCard {
            SWSectionHeader(title: "Sections")

            NavigationLink(destination: SWTestListView(store: store)) {
                sectionRow(glyph: .vial,
                           title: "Test results record",
                           caption: "Dates, services, specimen sites and the value for each entry.",
                           trailing: "\(store.testRecords.count)")
            }
            .buttonStyle(PlainButtonStyle())

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            NavigationLink(destination: SWPrEPView(store: store)) {
                sectionRow(glyph: .shield,
                           title: "Prophylaxis record",
                           caption: prepCaption,
                           trailing: store.prep.mode == .none ? "Off" : "On")
            }
            .buttonStyle(PlainButtonStyle())

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            NavigationLink(destination: SWVaccinationView(store: store)) {
                sectionRow(glyph: .syringe,
                           title: "Vaccination record",
                           caption: "HPV, hepatitis A, hepatitis B and mpox courses with commonly cited intervals.",
                           trailing: "\(completedVaccineCount)/4")
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var prepCaption: String {
        switch store.prep.mode {
        case .none:     return "Not recorded. Daily and on-demand schedules can both be tracked."
        case .daily:    return "Daily schedule with an adherence strip and the published onset interval."
        case .onDemand: return "On-demand 2-1-1 schedule drawn against your first dose."
        }
    }

    private var completedVaccineCount: Int {
        SWVaccineKind.allCases.filter { store.vaccine($0).isComplete }.count
    }

    private func sectionRow(glyph: SWGlyph, title: String, caption: String, trailing: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle()
                    .fill(SWTheme.tealSoft.opacity(0.7))
                    .frame(width: 34, height: 34)
                SWIcon(glyph: glyph, size: 17, color: SWTheme.teal, lineWidth: 1.5)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SWFont.heading(14))
                    .foregroundColor(SWTheme.ink)
                Text(caption)
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(spacing: 2) {
                Text(trailing)
                    .font(SWFont.label(10))
                    .foregroundColor(SWTheme.inkFaint)
                SWIcon(glyph: .chevronRight, size: 14, color: SWTheme.inkFaint)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var referenceCard: some View {
        SWCard {
            SWSectionHeader(title: "Reference")

            NavigationLink(destination: SWInfectionListView(store: store)) {
                sectionRow(glyph: .chart,
                           title: "The twelve entries",
                           caption: "Windows, specimens and a plain description of each entry this record tracks.",
                           trailing: "12")
            }
            .buttonStyle(PlainButtonStyle())

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            NavigationLink(destination: SWReferenceLibraryView()) {
                sectionRow(glyph: .book,
                           title: "Reference library",
                           caption: "Authored cards on windows, specimens, prevention, conversations and clinics.",
                           trailing: "\(SWReferenceLibrary.count)")
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Test record list

private enum SWTestSheet: Identifiable {
    case add
    case edit(SWTestRecord)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let record): return "edit-\(record.id.uuidString)"
        }
    }
}

struct SWTestListView: View {
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var sheet: SWTestSheet?

    private var style: SWDateStyle { store.preferences.dateStyle }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: "Test results",
                           subtitle: subtitle,
                           onBack: { presentationMode.wrappedValue.dismiss() }) {
                SWIconButton(glyph: .plus, tint: .white, background: SWTheme.teal) {
                    sheet = .add
                }
            }
        } content: {
            if store.testRecords.isEmpty {
                SWCard {
                    SWEmptyState(glyph: .vial,
                                 title: "No results recorded",
                                 message: "Record the collection date, the service, the entries tested, the specimen site for each one, and the value you were given. The site is the field most often omitted and the one most often needed later.",
                                 actionTitle: "Add a record") {
                        sheet = .add
                    }
                }
            } else {
                ForEach(store.testRecords) { record in
                    NavigationLink(destination: SWTestDetailView(recordID: record.id, store: store)) {
                        recordRow(record)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
                SWSectionHeader(title: "How a record closes a window")
                Text("A row on the Timeline is marked covered only when a specimen for that entry and that site was collected on or after the row's own conclusive date and the value recorded was a clear negative. A value of pending, indeterminate or positive never closes a row, and the app draws no other conclusion from any of them.")
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SWDisclaimerLine()
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .add:
                SWTestRecordEditorView(store: store, existing: nil)
            case .edit(let record):
                SWTestRecordEditorView(store: store, existing: record)
            }
        }
    }

    private var subtitle: String {
        let count = store.testRecords.count
        if count == 0 { return "Nothing recorded yet" }
        return "\(count) \(count == 1 ? "record" : "records")"
    }

    private func recordRow(_ record: SWTestRecord) -> some View {
        SWCard(padding: 13) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle()
                        .fill(statusColor(record).opacity(0.15))
                        .frame(width: 36, height: 36)
                    SWIcon(glyph: .vial, size: 17, color: statusColor(record), lineWidth: 1.5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(SWFormat.long(record.collectedOn, style: style))
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                    Text(record.displayClinic)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkSoft)
                    HStack(spacing: 6) {
                        SWPill(text: record.results.count == 1 ? "1 entry" : "\(record.results.count) entries",
                               color: SWTheme.indigo)
                        if !record.siteList.isEmpty {
                            SWPill(text: record.siteList.count == 1 ? "1 site" : "\(record.siteList.count) sites",
                                   color: SWTheme.teal)
                        }
                        if record.hasPending {
                            SWPill(text: "Pending", color: SWTheme.amber)
                        }
                    }
                }
                Spacer(minLength: 0)
                SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                    .padding(.top, 9)
            }
        }
    }

    private func statusColor(_ record: SWTestRecord) -> Color {
        if record.hasPositive { return SWTheme.indigo }
        if record.hasIndeterminate { return SWTheme.amber }
        if record.hasPending { return SWTheme.amber }
        return SWTheme.teal
    }
}

// MARK: - Test record detail

struct SWTestDetailView: View {
    let recordID: UUID
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    private var style: SWDateStyle { store.preferences.dateStyle }
    private var record: SWTestRecord? { store.testRecords.first { $0.id == recordID } }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: record.map { SWFormat.medium($0.collectedOn, style: style) } ?? "Record",
                               subtitle: record?.displayClinic,
                               onBack: { presentationMode.wrappedValue.dismiss() }) {
                    if record != nil {
                        SWIconButton(glyph: .pencil, tint: SWTheme.ink) { showEditor = true }
                    }
                }
            } content: {
                if let record = record {
                    SWCard {
                        SWSectionHeader(title: "Record")
                        SWKeyValueRow(key: "Collected", value: SWFormat.long(record.collectedOn, style: style))
                        SWKeyValueRow(key: "Service", value: record.displayClinic)
                        SWKeyValueRow(key: "Entries", value: "\(record.results.count)")
                        SWKeyValueRow(key: "Specimen sites",
                                      value: record.siteList.isEmpty ? "—" : record.siteList.map { $0.title }.joined(separator: ", "))
                    }

                    SWCard {
                        SWSectionHeader(title: "Values recorded")
                        if record.results.isEmpty {
                            Text("No entries were added to this record.")
                                .font(SWFont.body(13))
                                .foregroundColor(SWTheme.inkSoft)
                        } else {
                            ForEach(record.results.sorted(by: { $0.infectionID < $1.infectionID })) { result in
                                resultRow(result)
                            }
                        }
                        SWDisclaimerLine(text: "Values are stored exactly as you entered them. The app does not interpret them.")
                    }

                    if record.hasPositive {
                        SWNoticeCard(glyph: .info,
                                     title: "A positive value is on this record",
                                     message: "That entry has been marked as under care so the Timeline stops prompting for it, and can be cleared from the Health tab at any time. Follow your clinic's guidance — this app offers no interpretation and no next steps of its own.",
                                     tint: SWTheme.indigo,
                                     background: SWTheme.tealSoft.opacity(0.5))
                    }

                    if !record.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        SWCard {
                            SWSectionHeader(title: "Notes")
                            Text(record.notes)
                                .font(SWFont.body(13.5))
                                .foregroundColor(SWTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    SWCard(background: SWTheme.alertSoft.opacity(0.5), borderColor: SWTheme.alert.opacity(0.22)) {
                        SWSectionHeader(title: "Remove")
                        SWSecondaryButton(title: "Delete this record", glyph: .trash, tint: SWTheme.alert) {
                            showDeleteConfirm = true
                        }
                    }
                } else {
                    SWCard {
                        Text("This record is no longer stored.")
                            .font(SWFont.body(13))
                            .foregroundColor(SWTheme.inkSoft)
                    }
                }
                SWDisclaimerLine()
            }

            if showDeleteConfirm {
                SWConfirmOverlay(
                    title: "Delete this record?",
                    message: "Any Timeline row it closed will return to open. Care flags already created stay until you clear them.",
                    confirmTitle: "Delete",
                    onConfirm: {
                        store.deleteTestRecord(recordID)
                        showDeleteConfirm = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    onCancel: { showDeleteConfirm = false }
                )
            }
        }
        .sheet(isPresented: $showEditor) {
            SWTestRecordEditorView(store: store, existing: record)
        }
    }

    private func resultRow(_ result: SWResultEntry) -> some View {
        HStack(alignment: .top, spacing: 9) {
            SWChipDot(colorIndex: SWInfectionCatalog.infection(result.infectionID)?.colorIndex ?? 0, size: 8)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(SWInfectionCatalog.name(result.infectionID))
                    .font(SWFont.heading(13.5))
                    .foregroundColor(SWTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result.site.shortLabel)
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkSoft)
                if !result.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(result.note)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            SWPill(text: result.value.title, color: valueColor(result.value))
        }
        .padding(.vertical, 3)
    }

    private func valueColor(_ value: SWResultValue) -> Color {
        switch value {
        case .negative:      return SWTheme.teal
        case .positive:      return SWTheme.indigo
        case .indeterminate: return SWTheme.amber
        case .pending:       return SWTheme.inkFaint
        }
    }
}
