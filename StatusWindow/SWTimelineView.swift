import SwiftUI

// MARK: - Timeline

struct SWTimelineView: View {
    @ObservedObject var store: SWStore
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var now = Date()
    @State private var showCovered = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var contentWidth: CGFloat {
        // Page padding (16 × 2) plus card padding (14 × 2) are both subtracted —
        // from the column the cards are actually laid out in, never from the
        // screen: on an iPad the column is capped and the screen is not.
        max(180, SWMetrics.contentWidth(for: hSize) - 60)
    }

    private var schedule: SWSchedule { store.schedule }
    private var style: SWDateStyle { store.preferences.dateStyle }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: "Timeline",
                           subtitle: headerSubtitle)
        } content: {
            loadFailureNotice
            timeCriticalSection

            if store.encounters.isEmpty {
                emptyState
            } else if schedule.visits.isEmpty {
                nothingOutstandingCard
            } else {
                nextVisitCard
                visitsSection
                chartCard
            }

            pendingSection
            coveredSection
            methodCard
            SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
                .padding(.top, 2)
        }
        .onReceive(ticker) { value in
            // Only the countdowns need a per-second refresh — but this gates on
            // `schedule.flags` measured against the last rendered `now`, not on
            // `liveFlags`. `liveFlags` is filtered against a fresh `Date()` and is
            // empty the moment a deadline passes, so gating on it swallowed the
            // very tick that has to re-evaluate the body and take the expired card
            // off the screen. Comparing against `now` still lets exactly one
            // trailing tick through, and then stops the refresh for good.
            if schedule.flags.contains(where: { $0.deadline > now }) { now = value }
        }
    }

    /// Shown when a record file exists but could not be read. Without it the
    /// Timeline is simply empty, which reads as "my record was erased".
    @ViewBuilder
    private var loadFailureNotice: some View {
        if store.loadFailed {
            SWNoticeCard(glyph: .alert,
                         title: "The record could not be read",
                         message: "A record file is on this device but it could not be opened, so this screen is showing nothing rather than your entries. Nothing has been overwritten and nothing has been lost. The file cannot be read while the device is locked — unlock the device, then close and reopen the app.",
                         tint: SWTheme.amber,
                         background: SWTheme.amberSoft)
        }
    }

    private var headerSubtitle: String {
        if store.encounters.isEmpty { return "No exposures logged yet" }
        let count = schedule.openRows.count
        if count == 0 { return "Nothing outstanding on this record" }
        let visits = schedule.visits.count
        return "\(count) open \(count == 1 ? "row" : "rows") merged into \(visits) \(visits == 1 ? "date" : "dates")"
    }

    // MARK: Time-critical

    @ViewBuilder
    private var timeCriticalSection: some View {
        let live = schedule.liveFlags
        if !live.isEmpty {
            VStack(spacing: 12) {
                ForEach(live.filter { $0.kind == .postExposure }) { flag in
                    postExposureCard(flag)
                }
                ForEach(live.filter { $0.kind == .doxy }) { flag in
                    doxyCard(flag)
                }
            }
        }
    }

    private func postExposureCard(_ flag: SWTimeCriticalFlag) -> some View {
        SWCard(background: SWTheme.alertSoft, borderColor: SWTheme.alert.opacity(0.35)) {
            HStack(alignment: .top, spacing: 12) {
                SWCountdownRing(elapsed: flag.elapsedFraction(from: now),
                                headline: SWFormat.countdown(flag.remainingSeconds(from: now)),
                                caption: "remaining",
                                tint: SWTheme.alert,
                                size: 88)
                VStack(alignment: .leading, spacing: 5) {
                    Text("72-hour post-exposure window")
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.alert)
                    Text("An exposure logged at \(SWFormat.clock(flag.exposureAt)) on \(SWFormat.medium(flag.exposureAt, style: style)) was marked higher-risk.")
                        .font(SWFont.bodyTight(12.5))
                        .foregroundColor(SWTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Published guidance describes post-exposure prophylaxis as generally started within 72 hours of an exposure, and describes sooner as better. Contact a sexual health service or an emergency service now — this app cannot assess anything.")
                        .font(SWFont.bodyTight(12))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            NavigationLink(destination: SWReferenceCardView(card: SWReferenceLibrary.card("prev_pep"))) {
                HStack(spacing: 6) {
                    Text("What this means")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.alert)
                    SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.alert)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func doxyCard(_ flag: SWTimeCriticalFlag) -> some View {
        SWCard(background: SWTheme.amberSoft, borderColor: SWTheme.amber.opacity(0.3)) {
            HStack(alignment: .top, spacing: 11) {
                SWIcon(glyph: .clock, size: 20, color: SWTheme.amber, lineWidth: 1.7)
                VStack(alignment: .leading, spacing: 4) {
                    Text("72-hour doxycycline window")
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                    // Only the ticking value is monospaced, so the digits do not
                    // jitter. The sentence around it stays in the body face.
                    (Text(SWFormat.countdown(flag.remainingSeconds(from: now)))
                        .font(SWFont.mono(12))
                     + Text(" remaining from the exposure logged on \(SWFormat.medium(flag.exposureAt, style: style)).")
                        .font(SWFont.bodyTight(12)))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Guidance published by the US Centers for Disease Control and Prevention and by the World Health Organization describes a single dose of doxycycline taken within 72 hours as reducing the likelihood of certain bacterial infections. Guidance on it varies, this app is describing what those bodies have published rather than recommending it, and it is specifically something to discuss with a clinician.")
                        .font(SWFont.bodyTight(12))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            NavigationLink(destination: SWReferenceCardView(card: SWReferenceLibrary.card("prev_doxy"))) {
                HStack(spacing: 6) {
                    Text("Read the reference card")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.amber)
                    SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.amber)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: Next visit

    @ViewBuilder
    private var nextVisitCard: some View {
        if let visit = schedule.nextVisit {
            SWCard(background: SWTheme.card) {
                SWSectionHeader(title: visit.isDue ? "Available now" : "Next date",
                                trailingText: visit.kind.title)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(SWFormat.long(visit.date, style: style))
                        .font(SWFont.display(SWMetrics.isCompactHeight ? 20 : 23))
                        .foregroundColor(SWTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                }
                Text(visit.isDue
                     ? "This date has passed, so everything it lists is already conclusive."
                     : SWFormat.relativeDay(visit.date).capitalizingFirst)
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(visit.isDue ? SWTheme.teal : SWTheme.inkSoft)

                Rectangle().fill(SWTheme.hairline).frame(height: 1)

                ForEach(visit.lines) { line in
                    visitLineRow(line)
                }

                HStack(spacing: 8) {
                    SWIcon(glyph: .swab, size: 15, color: SWTheme.teal, lineWidth: 1.5)
                    Text(visit.siteSummary)
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.teal)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .padding(.top, 2)

                NavigationLink(destination: SWVisitDetailView(visit: visit, store: store)) {
                    HStack(spacing: 6) {
                        Text("What this date closes")
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

    private func visitLineRow(_ line: SWVisitLine) -> some View {
        HStack(alignment: .top, spacing: 9) {
            SWChipDot(colorIndex: SWInfectionCatalog.infection(line.infectionID)?.colorIndex ?? 0, size: 8)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.infectionName)
                    .font(SWFont.heading(13.5))
                    .foregroundColor(SWTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(line.assayShortName) · \(line.siteLabel)")
                    .font(SWFont.bodyTight(11.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Visit list

    @ViewBuilder
    private var visitsSection: some View {
        let rest = Array(schedule.visits.dropFirst(schedule.visits.isEmpty ? 0 : 1))
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SWSectionHeader(title: "Later dates",
                                subtitle: "Grouped within \(store.preferences.clusterToleranceDays) days of each other.",
                                trailingText: "\(rest.count)")
                ForEach(rest) { visit in
                    NavigationLink(destination: SWVisitDetailView(visit: visit, store: store)) {
                        visitRow(visit)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func visitRow(_ visit: SWVisit) -> some View {
        SWCard(padding: 13) {
            HStack(alignment: .top, spacing: 11) {
                VStack(spacing: 1) {
                    Text(dayNumber(visit.date))
                        .font(SWFont.monoLarge(20))
                        .foregroundColor(SWTheme.teal)
                    Text(monthAbbrev(visit.date))
                        .font(SWFont.label(9))
                        .foregroundColor(SWTheme.inkSoft)
                }
                .frame(width: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(visit.lines.map { SWInfectionCatalog.shortName($0.infectionID) }
                        .joined(separator: ", "))
                        .font(SWFont.heading(13.5))
                        .foregroundColor(SWTheme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(visit.siteSummary)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        SWPill(text: visit.kind.title,
                               color: visit.kind == .earlyScreen ? SWTheme.amber : SWTheme.teal)
                        SWPill(text: SWFormat.relativeDay(visit.date), color: SWTheme.indigo)
                    }
                }
                Spacer(minLength: 0)
                SWIcon(glyph: .chevronRight, size: 15, color: SWTheme.inkFaint)
                    .padding(.top, 6)
            }
        }
    }

    private func dayNumber(_ date: Date) -> String {
        let parts = SWDay.calendar.dateComponents([.day], from: date)
        return String(parts.day ?? 1)
    }

    private func monthAbbrev(_ date: Date) -> String {
        SWFormat.short(date, style: .dayMonthYear)
            .split(separator: " ").last.map(String.init)?.uppercased() ?? ""
    }

    // MARK: Chart

    @ViewBuilder
    private var chartCard: some View {
        let chartRows = SWWindowChartBuilder.rows(from: schedule.openRows)
        if !chartRows.isEmpty {
            SWCard {
                SWSectionHeader(title: "Open windows",
                                subtitle: "Each bar runs from the exposure to the date the window is described as closing. The amber line is today.")
                SWWindowChart(rows: chartRows, width: contentWidth, dateStyle: style)
                Text("The faded part of each bar is the period before a test is described as able to detect anything.")
                    .font(SWFont.bodyTight(11))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Awaiting results

    @ViewBuilder
    private var pendingSection: some View {
        let pending = schedule.pendingRows
        if !pending.isEmpty {
            SWCard(background: SWTheme.amberSoft.opacity(0.55),
                   borderColor: SWTheme.amber.opacity(0.28)) {
                SWSectionHeader(title: "Awaiting a value",
                                subtitle: "A specimen is on record but no value has been entered, so these rows are neither open nor closed.",
                                trailingText: "\(pending.count)")
                ForEach(pending.prefix(20)) { item in
                    HStack(alignment: .top, spacing: 9) {
                        SWIcon(glyph: .clock, size: 14, color: SWTheme.amber, lineWidth: 1.4)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(item.row.infectionShortName) · \(item.row.site.title)")
                                .font(SWFont.bodyTight(12.5))
                                .foregroundColor(SWTheme.ink)
                            Text(coverageCaption(item))
                                .font(SWFont.label(10))
                                .foregroundColor(SWTheme.inkFaint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                }
                if pending.count > 20 {
                    Text("\(pending.count - 20) further rows are not listed.")
                        .font(SWFont.label(10))
                        .foregroundColor(SWTheme.inkFaint)
                }
            }
        }
    }

    // MARK: Covered

    @ViewBuilder
    private var coveredSection: some View {
        let covered = schedule.coveredRows
        if !covered.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: { showCovered.toggle() }) {
                    HStack(spacing: 8) {
                        SWSectionHeader(title: "Covered and closed",
                                        trailingText: "\(covered.count)")
                        SWIcon(glyph: showCovered ? .chevronDown : .chevronRight,
                               size: 14, color: SWTheme.inkFaint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                if showCovered {
                    SWCard {
                        ForEach(covered.prefix(40)) { item in
                            coveredRow(item)
                            if item.id != covered.prefix(40).last?.id {
                                Rectangle().fill(SWTheme.hairline).frame(height: 1)
                            }
                        }
                        if covered.count > 40 {
                            Text("\(covered.count - 40) further closed rows are not listed.")
                                .font(SWFont.bodyTight(11))
                                .foregroundColor(SWTheme.inkFaint)
                        }
                    }
                }
            }
        }
    }

    private func coveredRow(_ item: SWEvaluatedRow) -> some View {
        HStack(alignment: .top, spacing: 9) {
            SWIcon(glyph: item.coverage.isSatisfied ? .check : .dot,
                   size: 14,
                   color: item.coverage == .underCare ? SWTheme.indigo : SWTheme.teal)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.row.infectionShortName) · \(item.row.site.title)")
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .strikethrough(item.coverage != .underCare, color: SWTheme.inkFaint)
                Text(coverageCaption(item))
                    .font(SWFont.label(10))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    private func coverageCaption(_ item: SWEvaluatedRow) -> String {
        switch item.coverage {
        case .closed(let date):
            return "Specimen taken \(SWFormat.medium(date, style: style)), after the conclusive date for the exposure on \(SWFormat.medium(item.row.exposureDate, style: style))."
        case .underCare:
            return "Marked as under clinical care, so this entry is not prompted."
        case .awaitingResult(let date):
            return "Specimen taken \(SWFormat.medium(date, style: style)); no value recorded yet."
        case .valueOnRecord(let date):
            return "A value other than a clear negative is on record from \(SWFormat.medium(date, style: style)), so this row is still listed."
        case .takenEarly(let date):
            return "Specimen taken \(SWFormat.medium(date, style: style)), inside the window."
        case .open:
            return "Open."
        }
    }

    // MARK: Method + empty states

    private var methodCard: some View {
        SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            SWSectionHeader(title: "How these dates were worked out")
            Text("Every logged exposure produces one row for each entry and specimen site that applies to it. Rows whose conclusive dates fall within \(store.preferences.clusterToleranceDays) days of each other are merged into a single date, placed on the latest of them so that everything listed is genuinely past its own window.")
                .font(SWFont.bodyTight(12.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text(SWReferenceLibrary.windowCaveat)
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink(destination: SWReferenceCardView(card: SWReferenceLibrary.card("win_merge"))) {
                HStack(spacing: 6) {
                    Text("More on merging")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.teal)
                    SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var emptyState: some View {
        SWCard {
            SWEmptyState(glyph: .timeline,
                         title: "No exposures logged",
                         message: "The Timeline is built entirely from what you record in the Log tab. Add an encounter — a date and the activity types involved is enough — and the dates appear here.")
            Rectangle().fill(SWTheme.hairline).frame(height: 1)
            Text("Nothing is sent anywhere. The record is a single protected file on this device.")
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private var nothingOutstandingCard: some View {
        SWCard {
            SWEmptyState(glyph: .check,
                         title: "Nothing outstanding",
                         message: "Every row generated by your logged exposures is either covered by a recorded specimen or belongs to an entry you have switched off or marked as under care.")
            SWDisclaimerLine(text: "This describes the completeness of your own record only. It is not a statement about your health.")
        }
    }
}

// MARK: - String helper

extension String {
    var capitalizingFirst: String {
        guard let first = first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

// MARK: - Visit detail

struct SWVisitDetailView: View {
    let visit: SWVisit
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    private var style: SWDateStyle { store.preferences.dateStyle }

    var body: some View {
        SWScreen {
            SWScreenHeader(title: SWFormat.medium(visit.date, style: style),
                           subtitle: visit.kind.title,
                           onBack: { presentationMode.wrappedValue.dismiss() })
        } content: {
            SWCard {
                Text(visit.kind.caption)
                    .font(SWFont.body(13.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(SWTheme.hairline).frame(height: 1)
                SWKeyValueRow(key: "Date", value: SWFormat.long(visit.date, style: style))
                SWKeyValueRow(key: "When", value: SWFormat.relativeDay(visit.date).capitalizingFirst)
                SWKeyValueRow(key: "Entries", value: "\(visit.infectionCount)")
                SWKeyValueRow(key: "Specimens", value: visit.siteSummary)
            }

            SWCard {
                SWSectionHeader(title: "What to ask for",
                                subtitle: "Each specimen site is listed separately because a test reports only on the sample it was given.")
                ForEach(visit.sites, id: \.rawValue) { site in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            SWIcon(glyph: site == .blood ? .vial : .swab, size: 16,
                                   color: SWTheme.teal, lineWidth: 1.5)
                            Text(site.shortLabel)
                                .font(SWFont.heading(13.5))
                                .foregroundColor(SWTheme.ink)
                            Spacer(minLength: 0)
                            Text(entriesAtSite(site))
                                .font(SWFont.label(10))
                                .foregroundColor(SWTheme.inkFaint)
                        }
                        Text(site.specimenName.capitalizingFirst)
                            .font(SWFont.bodyTight(11.5))
                            .foregroundColor(SWTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 3)
                }
            }

            SWCard {
                SWSectionHeader(title: "Entries on this date")
                ForEach(visit.lines) { line in
                    NavigationLink(destination: SWInfectionDetailView(infectionID: line.infectionID, store: store)) {
                        HStack(alignment: .top, spacing: 10) {
                            SWChipDot(colorIndex: SWInfectionCatalog.infection(line.infectionID)?.colorIndex ?? 0, size: 9)
                                .padding(.top, 3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.infectionName)
                                    .font(SWFont.heading(13.5))
                                    .foregroundColor(SWTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(line.assayShortName) · \(line.siteLabel)")
                                    .font(SWFont.bodyTight(11.5))
                                    .foregroundColor(SWTheme.inkSoft)
                                Text("Closes \(line.closesExposureIDs.count) logged \(line.closesExposureIDs.count == 1 ? "exposure" : "exposures"), earliest \(SWFormat.medium(line.earliestSourceDate, style: style)).")
                                    .font(SWFont.label(10))
                                    .foregroundColor(SWTheme.inkFaint)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            SWIcon(glyph: .chevronRight, size: 14, color: SWTheme.inkFaint)
                                .padding(.top, 3)
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            SWCard {
                SWSectionHeader(title: "Exposures this date covers")
                ForEach(visit.exposureDates, id: \.self) { date in
                    SWKeyValueRow(key: SWFormat.long(date, style: style),
                                  value: "\(SWDay.between(date, visit.date)) days")
                }
            }

            SWDisclaimerLine(text: SWReferenceLibrary.windowCaveat)
            SWDisclaimerLine()
        }
    }

    private func entriesAtSite(_ site: SWSpecimenSite) -> String {
        let count = visit.lines.filter { $0.sites.contains(site) }.count
        return "\(count) \(count == 1 ? "entry" : "entries")"
    }
}
