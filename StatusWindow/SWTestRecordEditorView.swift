import SwiftUI

// MARK: - One entry inside the editor

private struct SWTestPick: Equatable {
    var sites: Set<SWSpecimenSite>
    var value: SWResultValue
    var note: String
}

// MARK: - Test record editor

struct SWTestRecordEditorView: View {
    @ObservedObject var store: SWStore
    let existing: SWTestRecord?
    @Environment(\.presentationMode) private var presentationMode

    @State private var collectedOn: Date = Date()
    @State private var clinicLabel: String = ""
    @State private var notes: String = ""
    @State private var picks: [String: SWTestPick] = [:]
    @State private var focusedTag: Int? = nil
    @State private var didLoad = false
    @State private var showSiteInfo = false

    private var catalogue: [SWInfection] {
        // Entries switched on first, then the rest, so the common case is at the top.
        let enabled = Set(store.preferences.enabledInfectionIDs)
        let on = SWInfectionCatalog.all.filter { enabled.contains($0.id) }
        let off = SWInfectionCatalog.all.filter { !enabled.contains($0.id) }
        return on + off
    }

    private var canSave: Bool {
        picks.values.contains { !$0.sites.isEmpty }
    }

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                header
                Rectangle().fill(SWTheme.hairline).frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        whenCard
                        quickFillCard
                        entriesCard
                        notesCard
                        SWPrimaryButton(title: existing == nil ? "Save record" : "Save changes",
                                        glyph: .check,
                                        enabled: canSave) {
                            save()
                        }
                        if !canSave {
                            Text("Select at least one entry and one specimen site for it.")
                                .font(SWFont.bodyTight(11.5))
                                .foregroundColor(SWTheme.amber)
                        }
                        SWDisclaimerLine(text: "Values are stored exactly as entered. The app never interprets a result.")
                    }
                    .padding(.horizontal, SWMetrics.pagePadding)
                    .padding(.top, 14)
                    .padding(.bottom, 44)
                }
            }

            if showSiteInfo {
                SWInfoOverlay(title: "Why the site is recorded",
                              paragraphs: [
                                "A test reports only on the specimen it was given. A urine sample or genital swab covers the urogenital tract and says nothing about the throat or the rectum.",
                                "Published guidance describes pharyngeal and rectal infection as commonly present without symptoms, and describes urine-only screening as missing them entirely.",
                                "Recording the site is therefore what allows this record to work out which Timeline rows a specimen actually closed. Systemic entries are looked for in blood, so one blood sample covers every site for those."
                              ],
                              onClose: { showSiteInfo = false })
            }
        }
        .onAppear(perform: loadOnce)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(existing == nil ? "New test record" : "Edit record")
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
            SWFieldLabel(text: "Collection date",
                         caption: "The date the specimen was taken, not the date the result arrived.")
            SWDateField(title: "Collected on", date: $collectedOn,
                        range: SWDay.adding(days: -3650, to: SWDay.today)...SWDay.adding(days: 1, to: SWDay.today))
            SWFieldLabel(text: "Service or laboratory")
            SWTextField(placeholder: "For example: City sexual health service",
                        text: $clinicLabel,
                        focusTag: 21,
                        focusedTag: $focusedTag)
        }
    }

    private var quickFillCard: some View {
        SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            SWFieldLabel(text: "Quick fill",
                         caption: "Sets a common combination as negative, which you can then adjust entry by entry.")
            HStack(spacing: 8) {
                quickButton("Blood panel") { applyQuickFill(sites: [.blood]) }
                quickButton("Three-site NAAT") { applyQuickFill(sites: [.urogenital, .pharyngeal, .rectal]) }
                quickButton("Clear all") { picks = [:] }
            }
            Button(action: { showSiteInfo = true }) {
                HStack(spacing: 6) {
                    SWIcon(glyph: .info, size: 13, color: SWTheme.teal, lineWidth: 1.4)
                    Text("Why the site is recorded")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.teal)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(SWTheme.tealSoft.opacity(0.75)))
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func applyQuickFill(sites requested: Set<SWSpecimenSite>) {
        let enabled = Set(store.preferences.enabledInfectionIDs)
        for infection in SWInfectionCatalog.all where enabled.contains(infection.id) {
            let allowed = Set(infection.systemic ? [SWSpecimenSite.blood] : infection.siteCoverage)
            let chosen = allowed.intersection(requested)
            guard !chosen.isEmpty else { continue }
            var pick = picks[infection.id] ?? SWTestPick(sites: [], value: .negative, note: "")
            pick.sites.formUnion(chosen)
            picks[infection.id] = pick
        }
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SWSectionHeader(title: "Entries tested",
                            subtitle: "Choose the sites the specimen covered and the value you were given.")
            ForEach(catalogue) { infection in
                entryCard(infection)
            }
        }
    }

    private func entryCard(_ infection: SWInfection) -> some View {
        let pick = picks[infection.id]
        let isOn = pick != nil
        let availableSites: [SWSpecimenSite] = infection.systemic ? [.blood] : infection.siteCoverage

        return SWCard(padding: 13,
                      background: isOn ? SWTheme.card : SWTheme.card.opacity(0.75),
                      borderColor: isOn ? SWTheme.teal.opacity(0.3) : SWTheme.cardEdge) {
            SWCheckRow(title: infection.name,
                       caption: isOn ? nil : infection.primaryAssay.name,
                       isOn: isOn) {
                if isOn {
                    picks.removeValue(forKey: infection.id)
                } else {
                    let defaultSite = availableSites.first ?? .blood
                    picks[infection.id] = SWTestPick(sites: [defaultSite], value: .negative, note: "")
                }
            }

            if isOn, let current = pick {
                SWFieldLabel(text: "Specimen sites")
                VStack(spacing: 5) {
                    ForEach(availableSites, id: \.rawValue) { site in
                        SWCheckRow(title: site.shortLabel,
                                   isOn: current.sites.contains(site)) {
                            var updated = current
                            if updated.sites.contains(site) {
                                updated.sites.remove(site)
                            } else {
                                updated.sites.insert(site)
                            }
                            picks[infection.id] = updated
                        }
                    }
                }

                SWFieldLabel(text: "Value")
                SWSegmented(options: SWResultValue.allCases,
                            titleFor: { $0.title },
                            selection: Binding(
                                get: { picks[infection.id]?.value ?? .negative },
                                set: { newValue in
                                    var updated = picks[infection.id] ?? SWTestPick(sites: [], value: .negative, note: "")
                                    updated.value = newValue
                                    picks[infection.id] = updated
                                }
                            ),
                            compact: true)

                if current.value == .positive {
                    Text("Recording a positive value marks this entry as under care so the Timeline stops prompting for it. The app draws no other conclusion — follow your clinic's guidance.")
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.indigo)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if current.sites.isEmpty {
                    Text("Select at least one site, or this entry will not be saved.")
                        .font(SWFont.bodyTight(11))
                        .foregroundColor(SWTheme.amber)
                }
            }
        }
    }

    private var notesCard: some View {
        SWCard {
            SWFieldLabel(text: "Notes (optional)",
                         caption: "For example the exact test technology named on the report.")
            SWTextField(placeholder: "Anything worth keeping",
                        text: $notes,
                        focusTag: 22,
                        focusedTag: $focusedTag,
                        multiline: true)
        }
    }

    // MARK: Load and save

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing = existing else { return }
        collectedOn = existing.collectedOn
        clinicLabel = existing.clinicLabel
        notes = existing.notes
        var map: [String: SWTestPick] = [:]
        for result in existing.results {
            var pick = map[result.infectionID] ?? SWTestPick(sites: [], value: result.value, note: result.note)
            pick.sites.insert(result.site)
            pick.value = result.value
            if !result.note.isEmpty { pick.note = result.note }
            map[result.infectionID] = pick
        }
        picks = map
    }

    private func save() {
        guard canSave else { return }
        var record = existing ?? SWTestRecord()
        record.collectedOn = SWDay.start(collectedOn)
        record.clinicLabel = clinicLabel
        record.notes = notes

        var results: [SWResultEntry] = []
        for infection in SWInfectionCatalog.all {
            guard let pick = picks[infection.id], !pick.sites.isEmpty else { continue }
            for site in pick.sites.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                results.append(SWResultEntry(infectionID: infection.id,
                                             site: site,
                                             value: pick.value,
                                             note: pick.note))
            }
        }
        record.results = results

        if existing == nil {
            store.addTestRecord(record)
        } else {
            store.updateTestRecord(record)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
