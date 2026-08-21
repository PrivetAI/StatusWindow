import SwiftUI

// MARK: - Partners roster

private enum SWPartnerSheet: Identifiable {
    case add
    case edit(SWPartner)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let partner): return "edit-\(partner.id.uuidString)"
        }
    }
}

struct SWPartnersView: View {
    @ObservedObject var store: SWStore
    @State private var sheet: SWPartnerSheet?
    @State private var searchText = ""

    private var style: SWDateStyle { store.preferences.dateStyle }

    private var filtered: [SWPartner] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.partners }
        return store.partners.filter {
            $0.displayLabel.lowercased().contains(query) || $0.notes.lowercased().contains(query)
        }
    }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: "Partners",
                           subtitle: subtitle) {
                SWIconButton(glyph: .plus, tint: .white, background: SWTheme.teal) {
                    sheet = .add
                }
            }
        } content: {
            if store.partners.isEmpty && store.anonymousEncounters.isEmpty {
                emptyState
            } else {
                overviewCard

                if store.partners.count > 4 {
                    searchField
                }

                if !filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SWSectionHeader(title: "Entries", trailingText: "\(filtered.count)")
                        ForEach(filtered) { partner in
                            NavigationLink(destination: SWPartnerDetailView(partnerID: partner.id, store: store)) {
                                partnerRow(partner)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } else if !store.partners.isEmpty {
                    SWCard {
                        Text("No entry matches that search.")
                            .font(SWFont.body(13))
                            .foregroundColor(SWTheme.inkSoft)
                    }
                }

                if !store.anonymousEncounters.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SWSectionHeader(title: "Unidentified",
                                        subtitle: "Encounters logged without a partner entry.")
                        NavigationLink(destination: SWPartnerDetailView(partnerID: nil, store: store)) {
                            anonymousRow
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            privacyNote
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .add:
                SWPartnerEditorView(store: store, existing: nil)
            case .edit(let partner):
                SWPartnerEditorView(store: store, existing: partner)
            }
        }
    }

    private var subtitle: String {
        let count = store.partners.count
        if count == 0 { return "Labels you choose — never real names" }
        return "\(count) \(count == 1 ? "entry" : "entries") · \(store.encounters.count) logged encounters"
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            SWIcon(glyph: .search, size: 16, color: SWTheme.inkFaint)
            TextField("Search labels and notes", text: $searchText)
                .font(SWFont.body(14))
                .foregroundColor(SWTheme.ink)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    SWIcon(glyph: .close, size: 14, color: SWTheme.inkFaint)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SWTheme.mist.opacity(0.5))
        )
    }

    private var overviewCard: some View {
        SWCard {
            SWSectionHeader(title: "Overview")
            HStack(spacing: 0) {
                statColumn("\(store.partners.count)", "entries")
                divider
                statColumn("\(store.encounters.count)", "encounters")
                divider
                statColumn("\(store.anonymousEncounters.count)", "unidentified")
            }
            Text("Nothing here is transmitted anywhere. If a result ever means previous partners should be told, most services will do the contacting for you, usually without naming you.")
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(SWTheme.hairline)
            .frame(width: 1, height: 34)
    }

    private func statColumn(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SWFont.monoLarge(21))
                .foregroundColor(SWTheme.ink)
            Text(label)
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func partnerRow(_ partner: SWPartner) -> some View {
        let summary = store.summary(for: partner.id)
        return SWCard(padding: 13) {
            HStack(alignment: .top, spacing: 12) {
                SWPartnerToken(initials: partner.initials, colorIndex: partner.colorIndex, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(partner.displayLabel)
                        .font(SWFont.heading(15))
                        .foregroundColor(SWTheme.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        SWPill(text: partner.relationship.title, color: SWTheme.chip(partner.colorIndex))
                        if summary.encounterCount > 0 {
                            SWPill(text: "\(summary.encounterCount) logged", color: SWTheme.indigo)
                        }
                    }
                    if let last = summary.lastDate {
                        Text("Last logged \(SWFormat.medium(last, style: style))")
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                    } else {
                        Text("No encounters logged yet")
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkFaint)
                    }
                }
                Spacer(minLength: 0)
                SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                    .padding(.top, 10)
            }
        }
    }

    private var anonymousRow: some View {
        let summary = store.summary(for: nil)
        return SWCard(padding: 13) {
            HStack(alignment: .top, spacing: 12) {
                SWPartnerToken(initials: "—", colorIndex: 7, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not identified")
                        .font(SWFont.heading(15))
                        .foregroundColor(SWTheme.ink)
                    SWPill(text: "\(summary.encounterCount) logged", color: SWTheme.chip(7))
                    if let last = summary.lastDate {
                        Text("Last logged \(SWFormat.medium(last, style: style))")
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                    .padding(.top, 10)
            }
        }
    }

    private var emptyState: some View {
        SWCard {
            SWEmptyState(glyph: .partners,
                         title: "No entries yet",
                         message: "Partner entries are optional. They exist so an encounter can be attributed to something you recognize later — initials or a nickname work well, and the app never asks for a real name.",
                         actionTitle: "Add an entry") {
                sheet = .add
            }
        }
    }

    private var privacyNote: some View {
        SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            SWSectionHeader(title: "About this tab")
            Text("Anything a partner tells you is stored as reported, along with the date you were told it. That is a statement about what a record can know rather than about anybody's honesty. Their own testing covers their exposures; your dates come from yours.")
                .font(SWFont.bodyTight(12.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink(destination: SWReferenceCardView(card: SWReferenceLibrary.card("conv_reported"))) {
                HStack(spacing: 6) {
                    Text("Reference card")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.teal)
                    SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Partner detail

struct SWPartnerDetailView: View {
    /// `nil` means the unidentified pool.
    let partnerID: UUID?
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    private var style: SWDateStyle { store.preferences.dateStyle }
    private var partner: SWPartner? { store.partner(partnerID) }

    private var encounters: [SWEncounter] {
        if let id = partnerID { return store.encounters(for: id) }
        return store.anonymousEncounters
    }

    private var summary: SWPartnerSummary { store.summary(for: partnerID) }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: partner?.displayLabel ?? "Not identified",
                               subtitle: partner?.relationship.title ?? "Encounters with no partner entry",
                               onBack: { presentationMode.wrappedValue.dismiss() }) {
                    if partner != nil {
                        SWIconButton(glyph: .pencil, tint: SWTheme.ink) {
                            showEditor = true
                        }
                    }
                }
            } content: {
                summaryCard
                if partner != nil { reportedCard }
                if let partner = partner, !partner.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                    notesCard(partner.notes)
                }
                encountersSection
                if partner != nil { dangerZone }
            }

            if showDeleteConfirm {
                SWConfirmOverlay(
                    title: "Delete this entry?",
                    message: "\(encounters.count) logged \(encounters.count == 1 ? "encounter is" : "encounters are") attached to it. Choose whether those stay on the record as unidentified or are deleted with the entry.",
                    confirmTitle: "Keep encounters, delete entry",
                    confirmTint: SWTheme.teal,
                    secondaryTitle: "Delete entry and its encounters",
                    onSecondary: {
                        if let id = partnerID { store.deletePartner(id, reassignEncounters: false) }
                        showDeleteConfirm = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    onConfirm: {
                        if let id = partnerID { store.deletePartner(id, reassignEncounters: true) }
                        showDeleteConfirm = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    onCancel: { showDeleteConfirm = false }
                )
            }
        }
        .sheet(isPresented: $showEditor) {
            SWPartnerEditorView(store: store, existing: partner)
        }
    }

    private var summaryCard: some View {
        SWCard {
            SWSectionHeader(title: "Summary")
            SWKeyValueRow(key: "Encounters logged", value: "\(summary.encounterCount)")
            if let first = summary.firstDate, let last = summary.lastDate {
                SWKeyValueRow(key: "Date range",
                              value: SWDay.isSameDay(first, last)
                                ? SWFormat.medium(first, style: style)
                                : "\(SWFormat.medium(first, style: style)) — \(SWFormat.medium(last, style: style))")
            }
            SWKeyValueRow(key: "Barrier recorded as used", value: summary.barrierLabel)
            SWKeyValueRow(key: "Marked higher-risk", value: "\(summary.higherRiskCount)")
            if !summary.sitesInvolved.isEmpty {
                SWKeyValueRow(key: "Sites involved",
                              value: summary.sitesInvolved.map { $0.title }.joined(separator: ", "))
            }
            Rectangle().fill(SWTheme.hairline).frame(height: 1)
            if let last = summary.lastDate {
                SWKeyValueRow(key: "Your specimens after that date",
                              value: "\(summary.testsAfterLastEncounter)",
                              valueColor: summary.testsAfterLastEncounter > 0 ? SWTheme.teal : SWTheme.amber)
                Text(summary.testsAfterLastEncounter > 0
                     ? "You have \(summary.testsAfterLastEncounter) recorded \(summary.testsAfterLastEncounter == 1 ? "specimen" : "specimens") collected on or after \(SWFormat.medium(last, style: style)). Whether any of them closed a particular window depends on the entry — see the Timeline."
                     : "No specimen on this record was collected on or after \(SWFormat.medium(last, style: style)).")
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SWDisclaimerLine(text: "Counts describe this record only. They are not an assessment of anyone.")
        }
    }

    @ViewBuilder
    private var reportedCard: some View {
        if let partner = partner {
            SWCard {
                SWSectionHeader(title: "Reported status",
                                subtitle: "Reported by them, not verified.")
                SWKeyValueRow(key: "Status", value: partner.reportedStatus.title)
                if let date = partner.reportedStatusDate {
                    SWKeyValueRow(key: "Told on", value: SWFormat.medium(date, style: style))
                    SWKeyValueRow(key: "That was", value: SWFormat.relativeDay(date).capitalizingFirst)
                }
                if !partner.reportedStatusNote.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(partner.reportedStatusNote)
                        .font(SWFont.body(13))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SWDisclaimerLine(text: "This field stores what you were told and when. The app cannot verify it and does not treat it as a result.")
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        SWCard {
            SWSectionHeader(title: "Notes")
            Text(notes)
                .font(SWFont.body(13.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var encountersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SWSectionHeader(title: "Encounter history", trailingText: "\(encounters.count)")
            if encounters.isEmpty {
                SWCard {
                    Text("No encounters are attached to this entry yet. Add one from the Log tab.")
                        .font(SWFont.body(13))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(encounters) { encounter in
                    NavigationLink(destination: SWEncounterDetailView(encounterID: encounter.id, store: store)) {
                        SWEncounterRow(encounter: encounter, store: store, showPartner: false)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var dangerZone: some View {
        SWCard(background: SWTheme.alertSoft.opacity(0.5), borderColor: SWTheme.alert.opacity(0.22)) {
            SWSectionHeader(title: "Remove this entry")
            Text("Deleting an entry never silently removes its encounters. You will be asked whether they stay on the record as unidentified or are deleted with it.")
                .font(SWFont.bodyTight(12))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            SWSecondaryButton(title: "Delete entry", glyph: .trash, tint: SWTheme.alert) {
                showDeleteConfirm = true
            }
        }
    }
}

// MARK: - Partner editor

struct SWPartnerEditorView: View {
    @ObservedObject var store: SWStore
    let existing: SWPartner?
    @Environment(\.presentationMode) private var presentationMode

    @State private var label: String = ""
    @State private var colorIndex: Int = 0
    @State private var relationship: SWRelationshipType = .occasional
    @State private var reportedStatus: SWReportedStatus = .unknown
    @State private var hasReportedDate: Bool = false
    @State private var reportedDate: Date = Date()
    @State private var reportedNote: String = ""
    @State private var notes: String = ""
    @State private var focusedTag: Int? = nil
    @State private var didLoad = false

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                header
                Rectangle().fill(SWTheme.hairline).frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        identityCard
                        reportedCard
                        notesCard
                        SWPrimaryButton(title: existing == nil ? "Add entry" : "Save changes",
                                        glyph: .check,
                                        enabled: !label.trimmingCharacters(in: .whitespaces).isEmpty) {
                            save()
                        }
                        SWDisclaimerLine(text: "Stored only on this device.")
                    }
                    .padding(.horizontal, SWMetrics.pagePadding)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear(perform: loadOnce)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(existing == nil ? "New partner entry" : "Edit entry")
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

    private var identityCard: some View {
        SWCard {
            SWFieldLabel(text: "Label",
                         caption: "Initials or a nickname. The app never needs a real name.")
            SWTextField(placeholder: "For example: J.M. or Blue Coat",
                        text: $label,
                        focusTag: 1,
                        focusedTag: $focusedTag)

            SWFieldLabel(text: "Color tag")
            HStack(spacing: 8) {
                ForEach(0..<SWTheme.chips.count, id: \.self) { index in
                    Button(action: { colorIndex = index }) {
                        SWChipDot(colorIndex: index, size: 20, ringed: colorIndex == index)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Text(SWTheme.chipName(colorIndex))
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.inkFaint)

            SWFieldLabel(text: "Relationship type")
            SWSegmented(options: SWRelationshipType.allCases,
                        titleFor: { $0.title },
                        selection: $relationship,
                        compact: true)
        }
    }

    private var reportedCard: some View {
        SWCard {
            SWFieldLabel(text: "Last shared status",
                         caption: "What they told you, and when. Recorded as reported, never as verified.")
            VStack(spacing: 6) {
                ForEach(SWReportedStatus.allCases) { status in
                    SWCheckRow(title: status.title,
                               isOn: reportedStatus == status) {
                        reportedStatus = status
                    }
                }
            }

            SWToggleRow(title: "Record the date I was told",
                        isOn: $hasReportedDate)
            if hasReportedDate {
                SWDateField(title: "Told on", date: $reportedDate)
            }

            SWFieldLabel(text: "Detail (optional)")
            SWTextField(placeholder: "For example: said a full panel in June",
                        text: $reportedNote,
                        focusTag: 2,
                        focusedTag: $focusedTag)
        }
    }

    private var notesCard: some View {
        SWCard {
            SWFieldLabel(text: "Notes (optional)")
            SWTextField(placeholder: "Anything you want to remember",
                        text: $notes,
                        focusTag: 3,
                        focusedTag: $focusedTag,
                        multiline: true)
        }
    }

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing = existing else {
            colorIndex = store.partners.count % SWTheme.chips.count
            return
        }
        label = existing.label
        colorIndex = existing.colorIndex
        relationship = existing.relationship
        reportedStatus = existing.reportedStatus
        if let date = existing.reportedStatusDate {
            hasReportedDate = true
            reportedDate = date
        }
        reportedNote = existing.reportedStatusNote
        notes = existing.notes
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var record = existing ?? SWPartner()
        record.label = trimmed
        record.colorIndex = colorIndex
        record.relationship = relationship
        record.reportedStatus = reportedStatus
        record.reportedStatusDate = hasReportedDate ? SWDay.start(reportedDate) : nil
        record.reportedStatusNote = reportedNote
        record.notes = notes
        if existing == nil {
            store.addPartner(record)
        } else {
            store.updatePartner(record)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
