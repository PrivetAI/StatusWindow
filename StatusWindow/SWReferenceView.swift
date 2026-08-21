import SwiftUI

// MARK: - Reference library

struct SWReferenceLibraryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var query: String = ""
    @State private var category: SWReferenceCategory? = nil

    private var results: [SWReferenceCard] {
        var list = SWReferenceLibrary.search(query)
        if let category = category {
            list = list.filter { $0.category == category }
        }
        return list
    }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: "Reference library",
                           subtitle: "\(SWReferenceLibrary.count) authored cards",
                           onBack: { presentationMode.wrappedValue.dismiss() })
        } content: {
            searchField
            categoryChips

            if results.isEmpty {
                SWCard {
                    Text("Nothing matches that search.")
                        .font(SWFont.body(13))
                        .foregroundColor(SWTheme.inkSoft)
                    SWSecondaryButton(title: "Clear") {
                        query = ""
                        category = nil
                    }
                }
            } else if category == nil && query.trimmingCharacters(in: .whitespaces).isEmpty {
                ForEach(SWReferenceCategory.allCases) { section in
                    categorySection(section)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SWSectionHeader(title: "Results", trailingText: "\(results.count)")
                    ForEach(results) { card in
                        cardRow(card)
                    }
                }
            }

            SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
                Text("Every card is written from commonly cited public health guidance and is deliberately general. None of it is a personal instruction and none of it interprets a result.")
                    .font(SWFont.bodyTight(12))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            SWIcon(glyph: .search, size: 16, color: SWTheme.inkFaint)
            TextField("Search the library", text: $query)
                .font(SWFont.body(14))
                .foregroundColor(SWTheme.ink)
                .disableAutocorrection(true)
            if !query.isEmpty {
                Button(action: { query = "" }) {
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

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                chip(title: "All", active: category == nil, color: SWTheme.ink) {
                    category = nil
                }
                ForEach(SWReferenceCategory.allCases) { item in
                    chip(title: item.shortTitle,
                         active: category == item,
                         color: SWTheme.chip(item.colorIndex)) {
                        category = (category == item) ? nil : item
                    }
                }
            }
            .padding(.vertical, 2)
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

    private func categorySection(_ section: SWReferenceCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SWSectionHeader(title: section.title,
                            subtitle: section.blurb,
                            trailingText: "\(SWReferenceLibrary.count(in: section))")
            ForEach(SWReferenceLibrary.cards(in: section)) { card in
                cardRow(card)
            }
        }
    }

    private func cardRow(_ card: SWReferenceCard) -> some View {
        NavigationLink(destination: SWReferenceCardView(card: card)) {
            SWCard(padding: 13) {
                HStack(alignment: .top, spacing: 11) {
                    SWChipDot(colorIndex: card.category.colorIndex, size: 9)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(SWFont.heading(14))
                            .foregroundColor(SWTheme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(card.summary)
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                        .padding(.top, 3)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - A single card

struct SWReferenceCardView: View {
    let card: SWReferenceCard?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        SWScreen {
            SWScreenHeader(title: card?.title ?? "Reference",
                           subtitle: card?.category.title,
                           onBack: { presentationMode.wrappedValue.dismiss() })
        } content: {
            if let card = card {
                SWCard {
                    Text(card.summary)
                        .font(SWFont.title(15))
                        .foregroundColor(SWTheme.teal)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle().fill(SWTheme.hairline).frame(height: 1)
                    SWParagraphs(paragraphs: card.paragraphs, size: 14)
                }

                SWNoticeCard(glyph: .info,
                             title: "In short",
                             message: card.takeaway,
                             tint: SWTheme.teal,
                             background: SWTheme.tealSoft.opacity(0.55))

                let related = SWReferenceLibrary.cards(in: card.category).filter { $0.id != card.id }
                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SWSectionHeader(title: "More in \(card.category.title.lowercased())")
                        ForEach(related.prefix(6)) { other in
                            NavigationLink(destination: SWReferenceCardView(card: other)) {
                                HStack(spacing: 9) {
                                    SWIcon(glyph: .book, size: 14, color: SWTheme.teal, lineWidth: 1.4)
                                    Text(other.title)
                                        .font(SWFont.bodyTight(13))
                                        .foregroundColor(SWTheme.ink)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.inkFaint)
                                }
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } else {
                SWCard {
                    Text("That card is not available.")
                        .font(SWFont.body(13))
                        .foregroundColor(SWTheme.inkSoft)
                }
            }

            SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
        }
    }
}

// MARK: - The twelve entries

struct SWInfectionListView: View {
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        SWScreen {
            SWScreenHeader(title: "The twelve entries",
                           subtitle: "\(SWInfectionCatalog.scheduledAssayCount) scheduled window rows across 12 entries",
                           onBack: { presentationMode.wrappedValue.dismiss() })
        } content: {
            SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
                Text("Every interval below is general published guidance counted from the exposure, and the day figures are the ones most commonly cited for that technology.")
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text(SWReferenceLibrary.windowCaveat)
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(SWInfectionCatalog.all) { infection in
                NavigationLink(destination: SWInfectionDetailView(infectionID: infection.id, store: store)) {
                    infectionRow(infection)
                }
                .buttonStyle(PlainButtonStyle())
            }

            SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
        }
    }

    private func infectionRow(_ infection: SWInfection) -> some View {
        SWCard(padding: 13) {
            HStack(alignment: .top, spacing: 11) {
                SWChipDot(colorIndex: infection.colorIndex, size: 10)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(infection.name)
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(windowLabel(infection))
                        .font(SWFont.mono(11))
                        .foregroundColor(SWTheme.inkSoft)
                    HStack(spacing: 6) {
                        SWPill(text: infection.family.title, color: SWTheme.chip(infection.colorIndex))
                        if store.isInfectionEnabled(infection.id) {
                            SWPill(text: "On schedule", color: SWTheme.teal)
                        } else if infection.schedulable {
                            SWPill(text: "Off", color: SWTheme.inkFaint)
                        } else {
                            SWPill(text: "Not scheduled", color: SWTheme.indigo)
                        }
                    }
                }
                Spacer(minLength: 0)
                SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                    .padding(.top, 3)
            }
        }
    }

    private func windowLabel(_ infection: SWInfection) -> String {
        guard let assay = infection.assays.first(where: { $0.scheduled }) else {
            return "No window date — see the entry"
        }
        return "\(assay.shortName): day \(assay.earliestDay) to day \(assay.conclusiveDay)"
    }
}

// MARK: - Entry detail

struct SWInfectionDetailView: View {
    let infectionID: String
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    private var infection: SWInfection? { SWInfectionCatalog.infection(infectionID) }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: infection?.shortName ?? "Entry",
                           subtitle: infection?.family.title,
                           onBack: { presentationMode.wrappedValue.dismiss() })
        } content: {
            if let infection = infection {
                SWCard {
                    Text(infection.name)
                        .font(SWFont.display(20))
                        .foregroundColor(SWTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    SWParagraphs(paragraphs: [infection.explainer], size: 13.5)
                }

                SWCard {
                    SWSectionHeader(title: "Windows commonly cited",
                                    subtitle: "Counted in days from the exposure.")
                    ForEach(infection.assays, id: \.id) { assay in
                        assayRow(assay, infection: infection)
                    }
                    Text(SWReferenceLibrary.windowCaveat)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SWCard {
                    SWSectionHeader(title: "Specimen")
                    if infection.systemic {
                        siteRow(.blood)
                        Text("A single blood sample covers every exposed site for this entry.")
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(infection.siteCoverage, id: \.rawValue) { site in
                            siteRow(site)
                        }
                        Text("This entry is site-specific: a specimen reports only on the site it came from.")
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SWCard {
                    SWSectionHeader(title: "How published guidance describes it presenting")
                    Text(infection.presentationNote)
                        .font(SWFont.body(13.5))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    SWDisclaimerLine(text: "A general description only. The app cannot assess symptoms and does not attempt to.")
                }

                scheduleStateCard(infection)

                if infection.vaccinePreventable || infection.doxyRelevant {
                    SWCard {
                        SWSectionHeader(title: "Related")
                        if infection.vaccinePreventable {
                            NavigationLink(destination: SWVaccinationView(store: store)) {
                                relatedRow(glyph: .syringe, title: "Vaccination record",
                                           caption: "This entry is vaccine-preventable and its course is tracked there.")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if infection.doxyRelevant, let card = SWReferenceLibrary.card("prev_doxy") {
                            NavigationLink(destination: SWReferenceCardView(card: card)) {
                                relatedRow(glyph: .book, title: card.title, caption: card.summary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } else {
                SWCard {
                    Text("That entry is not in the catalog.")
                        .font(SWFont.body(13))
                        .foregroundColor(SWTheme.inkSoft)
                }
            }

            SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
        }
    }

    private func assayRow(_ assay: SWAssay, infection: SWInfection) -> some View {
        let isPreferred = SWInfectionCatalog.preferredAssay(for: infection,
                                                            preferences: store.preferences)?.id == assay.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assay.name)
                        .font(SWFont.heading(13.5))
                        .foregroundColor(SWTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(assay.technology)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if isPreferred && assay.scheduled {
                    SWPill(text: "In use", color: SWTheme.teal)
                }
            }
            if assay.scheduled {
                HStack(spacing: 10) {
                    dayBadge("Earliest", "\(assay.earliestDay)")
                    dayBadge("Conclusive", "\(assay.conclusiveDay)")
                    Text("\(assay.windowSpan)-day spread")
                        .font(SWFont.label(10))
                        .foregroundColor(SWTheme.inkFaint)
                }
            } else {
                SWPill(text: "Not run on a schedule", color: SWTheme.indigo)
            }
            Text(assay.note)
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }

    private func dayBadge(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.inkFaint)
            Text("day \(value)")
                .font(SWFont.mono(11))
                .foregroundColor(SWTheme.teal)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(SWTheme.tealSoft.opacity(0.6)))
    }

    private func siteRow(_ site: SWSpecimenSite) -> some View {
        HStack(alignment: .top, spacing: 9) {
            SWIcon(glyph: site == .blood ? .vial : .swab, size: 15, color: SWTheme.teal, lineWidth: 1.4)
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
        .padding(.vertical, 3)
    }

    private func scheduleStateCard(_ infection: SWInfection) -> some View {
        SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            SWSectionHeader(title: "On your schedule")
            if !infection.schedulable {
                Text("This entry does not produce window dates, so it is never scheduled. The reason is described above.")
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                SWToggleRow(title: "Include in the schedule",
                            caption: infection.defaultEnabled
                                ? "On by default because it appears in most routine panels."
                                : "Off by default because most services do not include it in a routine screen.",
                            isOn: Binding(
                                get: { store.isInfectionEnabled(infection.id) },
                                set: { store.setInfectionEnabled(infection.id, $0) }
                            ))
                if store.isUnderCare(infection.id) {
                    Text("This entry is currently marked as under clinical care, so it is not prompted regardless of the setting above. Clear the flag from the Health tab.")
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.indigo)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func relatedRow(glyph: SWGlyph, title: String, caption: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            SWIcon(glyph: glyph, size: 15, color: SWTheme.teal, lineWidth: 1.4)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SWFont.heading(13))
                    .foregroundColor(SWTheme.ink)
                    .multilineTextAlignment(.leading)
                Text(caption)
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.inkFaint)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
