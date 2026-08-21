import Foundation

// MARK: - A single window row
//
// One exposure, one infection entry, one specimen site. The engine produces these
// first and then merges them into a small number of dates. Nothing here is a
// judgement about anyone's health; a row is a date on which a specific specimen
// is described in published guidance as becoming meaningful.

struct SWWindowRow: Identifiable, Equatable {
    let id: String
    let encounterID: UUID
    let exposureDate: Date
    let infectionID: String
    let assayID: String
    let site: SWSpecimenSite
    let earliestDate: Date
    let conclusiveDate: Date

    var infection: SWInfection? { SWInfectionCatalog.infection(infectionID) }
    var assay: SWAssay? { SWInfectionCatalog.assay(assayID) }

    var infectionName: String { SWInfectionCatalog.name(infectionID) }
    var infectionShortName: String { SWInfectionCatalog.shortName(infectionID) }

    var daysUntilConclusive: Int { SWDay.between(SWDay.today, conclusiveDate) }
    var isOpen: Bool { daysUntilConclusive > 0 }

    /// Position of today inside the window, 0 at the exposure and 1 at the
    /// conclusive date. Used only for drawing.
    var progress: Double {
        let span = Double(SWDay.between(exposureDate, conclusiveDate))
        let elapsed = Double(SWDay.between(exposureDate, SWDay.today))
        guard let ratio = SWMath.safeDivide(elapsed, span) else { return 0 }
        return SWMath.clamp(ratio, 0, 1)
    }
}

// MARK: - Coverage state of a row

enum SWCoverageState: Equatable {
    /// No test on record for this pairing yet.
    case open
    /// A specimen was taken after the conclusive date and reported negative.
    case closed(Date)
    /// A specimen was taken inside the window — informative but not window-closing.
    case takenEarly(Date)
    /// A specimen is on record but no value has been entered yet.
    case awaitingResult(Date)
    /// A value other than a clear negative is on record. It does not close the
    /// window, and the app draws no conclusion from it.
    case valueOnRecord(Date)
    /// The user has marked this entry as under clinical care, so it is not prompted.
    case underCare

    var isSatisfied: Bool {
        switch self {
        case .closed, .underCare: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .open:                 return "Open"
        case .closed:               return "Covered"
        case .takenEarly:           return "Tested inside window"
        case .awaitingResult:       return "Awaiting result"
        case .valueOnRecord:        return "Value on record"
        case .underCare:            return "Under care"
        }
    }
}

struct SWEvaluatedRow: Identifiable, Equatable {
    let row: SWWindowRow
    let coverage: SWCoverageState
    var id: String { row.id }
}

// MARK: - Merged visit

enum SWVisitKind: String, Equatable {
    case earlyScreen
    case windowClose

    var title: String {
        switch self {
        case .earlyScreen: return "Early screen"
        case .windowClose: return "Window closes"
        }
    }

    var caption: String {
        switch self {
        case .earlyScreen:
            return "These specimens are described as able to detect from this date. A result before the conclusive date does not close the window."
        case .windowClose:
            return "From this date every entry listed here is described in commonly cited guidance as conclusive for the exposures noted."
        }
    }
}

/// One display line inside a visit: an infection, its assay, and the sites.
struct SWVisitLine: Identifiable, Equatable {
    let id: String
    let infectionID: String
    let assayID: String
    let sites: [SWSpecimenSite]
    let closesExposureIDs: [UUID]
    let earliestSourceDate: Date

    var infectionName: String { SWInfectionCatalog.name(infectionID) }
    var assayShortName: String { SWInfectionCatalog.assay(assayID)?.shortName ?? "—" }

    var siteLabel: String {
        if sites.count == 1 { return sites[0].shortLabel }
        return sites.map { $0.title }.joined(separator: ", ")
    }
}

struct SWVisit: Identifiable, Equatable {
    let id: String
    let date: Date
    let kind: SWVisitKind
    let lines: [SWVisitLine]
    let sites: [SWSpecimenSite]
    let exposureIDs: [UUID]
    let exposureDates: [Date]

    var isDue: Bool { SWDay.between(SWDay.today, date) <= 0 }
    var daysAway: Int { SWDay.between(SWDay.today, date) }

    var siteSummary: String {
        if sites.isEmpty { return "No specimen listed" }
        return sites.map { $0.shortLabel }.joined(separator: " · ")
    }

    var infectionCount: Int { Set(lines.map { $0.infectionID }).count }
}

// MARK: - Time-critical flags

enum SWTimeCriticalKind: String, Equatable {
    case postExposure
    case doxy

    var title: String {
        switch self {
        case .postExposure: return "72-hour post-exposure window"
        case .doxy:         return "72-hour doxycycline window"
        }
    }
}

struct SWTimeCriticalFlag: Identifiable, Equatable {
    let id: String
    let kind: SWTimeCriticalKind
    let encounterID: UUID
    let exposureAt: Date
    let deadline: Date

    func remainingSeconds(from now: Date = Date()) -> Double {
        let value = deadline.timeIntervalSince(now)
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    func isLive(at now: Date = Date()) -> Bool { deadline > now }

    func elapsedFraction(from now: Date = Date()) -> Double {
        let total = deadline.timeIntervalSince(exposureAt)
        let done = now.timeIntervalSince(exposureAt)
        guard let ratio = SWMath.safeDivide(done, total) else { return 0 }
        return SWMath.clamp(ratio, 0, 1)
    }
}

// MARK: - The engine result

struct SWSchedule: Equatable {
    var evaluated: [SWEvaluatedRow]
    var visits: [SWVisit]
    var flags: [SWTimeCriticalFlag]
    var openRows: [SWWindowRow]
    var coveredRows: [SWEvaluatedRow]
    var pendingRows: [SWEvaluatedRow]
    var underCareIDs: [String]
    var horizonCutoff: Date

    static let empty = SWSchedule(evaluated: [], visits: [], flags: [],
                                  openRows: [], coveredRows: [], pendingRows: [],
                                  underCareIDs: [], horizonCutoff: SWDay.today)

    /// The one date every screen means by "next". Visits are sorted ascending and
    /// this design leads with the oldest outstanding one, so an overdue date is
    /// the next date to act on — the Timeline headline and the Health summary
    /// must not disagree about which date that is.
    var nextVisit: SWVisit? { visits.first }

    var overdueVisits: [SWVisit] { visits.filter { $0.daysAway < 0 } }
    var upcomingVisits: [SWVisit] { visits.filter { $0.daysAway >= 0 } }
    var liveFlags: [SWTimeCriticalFlag] { flags.filter { $0.isLive() } }
}

// MARK: - Engine

enum SWWindowEngine {

    /// Exposures older than this are not scheduled. The longest commonly cited
    /// window on the record is 180 days, so a year is a generous horizon.
    static let horizonDays = 365

    // MARK: Row construction

    static func buildRows(encounters: [SWEncounter],
                          preferences: SWPreferences,
                          careFlags: [SWCareFlag],
                          today: Date = SWDay.today) -> [SWWindowRow] {

        let cutoff = SWDay.adding(days: -horizonDays, to: today)
        let enabled = Set(preferences.enabledInfectionIDs)

        var rows: [SWWindowRow] = []

        for encounter in encounters {
            guard !encounter.activities.isEmpty else { continue }
            let day = SWDay.start(encounter.date)
            guard SWDay.key(day) >= SWDay.key(cutoff) else { continue }
            // A date entered in the future cannot produce a meaningful window.
            guard SWDay.key(day) <= SWDay.key(today) else { continue }

            let exposed = encounter.exposedSites

            for infection in SWInfectionCatalog.all {
                guard infection.schedulable else { continue }
                guard enabled.contains(infection.id) else { continue }
                // An entry marked as under care still gets its rows. Skipping it
                // here made `.underCare` unreachable in `coverage(for:)`, so those
                // rows vanished from the Timeline entirely instead of appearing in
                // the covered list labeled "Under care". They are excluded from
                // the visit schedule further down, in `build`, where the coverage
                // state is known.
                guard let assay = SWInfectionCatalog.preferredAssay(for: infection,
                                                                    preferences: preferences),
                      assay.scheduled else { continue }

                let sites = infection.specimenSites(forExposedSites: exposed)
                guard !sites.isEmpty else { continue }

                for site in sites {
                    let earliest = SWDay.adding(days: assay.earliestDay, to: day)
                    let conclusive = SWDay.adding(days: assay.conclusiveDay, to: day)
                    let rowID = "\(encounter.id.uuidString)|\(infection.id)|\(assay.id)|\(site.rawValue)"
                    rows.append(SWWindowRow(id: rowID,
                                            encounterID: encounter.id,
                                            exposureDate: day,
                                            infectionID: infection.id,
                                            assayID: assay.id,
                                            site: site,
                                            earliestDate: earliest,
                                            conclusiveDate: conclusive))
                }
            }
        }

        return rows.sorted { a, b in
            if SWDay.key(a.conclusiveDate) != SWDay.key(b.conclusiveDate) {
                return SWDay.key(a.conclusiveDate) < SWDay.key(b.conclusiveDate)
            }
            return a.id < b.id
        }
    }

    // MARK: Coverage

    static func coverage(for row: SWWindowRow,
                         testRecords: [SWTestRecord],
                         careFlags: [SWCareFlag]) -> SWCoverageState {

        if careFlags.contains(where: { $0.infectionID == row.infectionID }) {
            return .underCare
        }

        var bestClosed: Date?
        var bestEarly: Date?
        var bestPending: Date?
        var bestNonNegative: Date?

        // Keeps the latest of several candidate dates without any force unwrap.
        func isLater(_ candidateKey: Int, than existing: Date?) -> Bool {
            guard let existing = existing else { return true }
            return candidateKey > SWDay.key(existing)
        }

        let exposureKey = SWDay.key(row.exposureDate)
        let conclusiveKey = SWDay.key(row.conclusiveDate)

        for record in testRecords {
            let takenKey = SWDay.key(record.collectedOn)
            // A specimen taken before the exposure cannot say anything about it.
            guard takenKey >= exposureKey else { continue }

            for result in record.results
            where result.infectionID == row.infectionID && result.site == row.site {

                switch result.value {
                case .pending:
                    if isLater(takenKey, than: bestPending) {
                        bestPending = record.collectedOn
                    }
                case .negative:
                    if takenKey >= conclusiveKey {
                        if isLater(takenKey, than: bestClosed) {
                            bestClosed = record.collectedOn
                        }
                    } else {
                        if isLater(takenKey, than: bestEarly) {
                            bestEarly = record.collectedOn
                        }
                    }
                case .positive, .indeterminate:
                    // Values other than a clear negative never close a window here.
                    // A positive value creates a care flag when the record is saved,
                    // which is handled above. Once the person clears that flag the
                    // row must be listed again, so this is kept separate from a
                    // specimen that is genuinely still awaiting a value.
                    if isLater(takenKey, than: bestNonNegative) {
                        bestNonNegative = record.collectedOn
                    }
                }
            }
        }

        if let closed = bestClosed { return .closed(closed) }
        if let recorded = bestNonNegative { return .valueOnRecord(recorded) }
        if let pending = bestPending { return .awaitingResult(pending) }
        if let early = bestEarly { return .takenEarly(early) }
        return .open
    }

    // MARK: Clustering

    /// Greedy clustering of day keys. A cluster is opened at the first date and
    /// absorbs every later date within `tolerance` days of that opening date; the
    /// cluster's visit date is the LATEST date it contains, so every row inside it
    /// is past its own conclusive date on the day of the visit.
    static func clusterDates(_ dates: [Date], tolerance: Int) -> [[Date]] {
        guard !dates.isEmpty else { return [] }
        let tol = max(0, tolerance)
        let sorted = dates.sorted { SWDay.key($0) < SWDay.key($1) }
        var clusters: [[Date]] = []
        var current: [Date] = [sorted[0]]
        var anchor = sorted[0]

        for date in sorted.dropFirst() {
            if SWDay.between(anchor, date) <= tol {
                current.append(date)
            } else {
                clusters.append(current)
                current = [date]
                anchor = date
            }
        }
        clusters.append(current)
        return clusters
    }

    // MARK: Visit merging

    static func buildVisits(openRows: [SWWindowRow],
                            tolerance: Int,
                            today: Date = SWDay.today) -> [SWVisit] {

        guard !openRows.isEmpty else { return [] }

        // --- Closing visits -------------------------------------------------
        let conclusiveDates = openRows.map { $0.conclusiveDate }
        let clusters = clusterDates(conclusiveDates, tolerance: tolerance)

        var visits: [SWVisit] = []

        for cluster in clusters {
            guard let visitDate = cluster.max(by: { SWDay.key($0) < SWDay.key($1) }) else { continue }
            let clusterKeys = Set(cluster.map { SWDay.key($0) })
            let rows = openRows.filter { clusterKeys.contains(SWDay.key($0.conclusiveDate)) }
            guard !rows.isEmpty else { continue }
            visits.append(makeVisit(id: "close-\(SWDay.key(visitDate))",
                                    date: visitDate,
                                    kind: .windowClose,
                                    rows: rows))
        }

        visits.sort { SWDay.key($0.date) < SWDay.key($1.date) }

        // --- Optional early screen ------------------------------------------
        // Short-window specimens become meaningful well before the first closing
        // date. If that gap is worth a separate visit, offer exactly one.
        let shortRows = openRows.filter { row in
            guard let assay = row.assay else { return false }
            return assay.conclusiveDay <= 30
        }

        if let firstClosing = visits.first, !shortRows.isEmpty {
            let earlyCandidate = shortRows
                .map { $0.earliestDate }
                .max(by: { SWDay.key($0) < SWDay.key($1) })

            if let earlyDate = earlyCandidate,
               SWDay.between(earlyDate, firstClosing.date) >= 4,
               SWDay.between(today, firstClosing.date) > 0 {

                let earlyKey = SWDay.key(earlyDate)
                let rows = openRows.filter { SWDay.key($0.earliestDate) <= earlyKey }
                if !rows.isEmpty {
                    let early = makeVisit(id: "early-\(earlyKey)",
                                          date: earlyDate,
                                          kind: .earlyScreen,
                                          rows: rows)
                    visits.insert(early, at: 0)
                }
            }
        }

        return visits
    }

    private static func makeVisit(id: String,
                                  date: Date,
                                  kind: SWVisitKind,
                                  rows: [SWWindowRow]) -> SWVisit {

        // Group by infection + assay so a three-site NAAT is one line, not three.
        var order: [String] = []
        var grouped: [String: [SWWindowRow]] = [:]
        for row in rows {
            let key = "\(row.infectionID)|\(row.assayID)"
            if grouped[key] == nil {
                grouped[key] = []
                order.append(key)
            }
            grouped[key]?.append(row)
        }

        var lines: [SWVisitLine] = []
        for key in order {
            guard let group = grouped[key], let first = group.first else { continue }
            var siteSet = Set<SWSpecimenSite>()
            var exposureSet = Set<UUID>()
            var earliestSource = first.exposureDate
            for row in group {
                siteSet.insert(row.site)
                exposureSet.insert(row.encounterID)
                if SWDay.key(row.exposureDate) < SWDay.key(earliestSource) {
                    earliestSource = row.exposureDate
                }
            }
            lines.append(SWVisitLine(id: "\(id)|\(key)",
                                     infectionID: first.infectionID,
                                     assayID: first.assayID,
                                     sites: siteSet.sorted { $0.sortOrder < $1.sortOrder },
                                     closesExposureIDs: Array(exposureSet),
                                     earliestSourceDate: earliestSource))
        }

        lines.sort { a, b in
            let ai = SWInfectionCatalog.all.firstIndex { $0.id == a.infectionID } ?? 99
            let bi = SWInfectionCatalog.all.firstIndex { $0.id == b.infectionID } ?? 99
            if ai != bi { return ai < bi }
            return a.assayID < b.assayID
        }

        var siteSet = Set<SWSpecimenSite>()
        var exposureSet = Set<UUID>()
        var exposureDayKeys = Set<Int>()
        var exposureDates: [Date] = []
        for row in rows {
            siteSet.insert(row.site)
            exposureSet.insert(row.encounterID)
            let key = SWDay.key(row.exposureDate)
            if !exposureDayKeys.contains(key) {
                exposureDayKeys.insert(key)
                exposureDates.append(row.exposureDate)
            }
        }

        return SWVisit(id: id,
                       date: date,
                       kind: kind,
                       lines: lines,
                       sites: siteSet.sorted { $0.sortOrder < $1.sortOrder },
                       exposureIDs: Array(exposureSet),
                       exposureDates: exposureDates.sorted { SWDay.key($0) < SWDay.key($1) })
    }

    // MARK: Time-critical flags

    static func buildFlags(encounters: [SWEncounter], now: Date = Date()) -> [SWTimeCriticalFlag] {
        var flags: [SWTimeCriticalFlag] = []
        let seventyTwoHours: TimeInterval = 72 * 3600

        for encounter in encounters {
            guard !encounter.activities.isEmpty else { continue }
            let deadline = encounter.date.addingTimeInterval(seventyTwoHours)
            guard deadline > now else { continue }
            guard encounter.date <= now.addingTimeInterval(3600) else { continue }

            if encounter.higherRiskFlag {
                flags.append(SWTimeCriticalFlag(id: "pep-\(encounter.id.uuidString)",
                                                kind: .postExposure,
                                                encounterID: encounter.id,
                                                exposureAt: encounter.date,
                                                deadline: deadline))
            }

            let doxyRelevant = encounter.higherRiskFlag || encounter.barrierSummary != .used
            if doxyRelevant {
                flags.append(SWTimeCriticalFlag(id: "doxy-\(encounter.id.uuidString)",
                                                kind: .doxy,
                                                encounterID: encounter.id,
                                                exposureAt: encounter.date,
                                                deadline: deadline))
            }
        }

        return flags.sorted { $0.deadline < $1.deadline }
    }

    // MARK: Full build

    static func build(encounters: [SWEncounter],
                      testRecords: [SWTestRecord],
                      careFlags: [SWCareFlag],
                      preferences: SWPreferences,
                      today: Date = SWDay.today,
                      now: Date = Date()) -> SWSchedule {

        let rows = buildRows(encounters: encounters,
                             preferences: preferences,
                             careFlags: careFlags,
                             today: today)

        var evaluated: [SWEvaluatedRow] = []
        evaluated.reserveCapacity(rows.count)
        for row in rows {
            let state = coverage(for: row, testRecords: testRecords, careFlags: careFlags)
            evaluated.append(SWEvaluatedRow(row: row, coverage: state))
        }

        // A row still needs a date when nothing covers it, or when the only
        // specimen on record was taken inside the window and therefore did not
        // close it. Rows waiting on a result are left alone until a value arrives.
        let openRows = evaluated
            .filter { evaluatedRow in
                switch evaluatedRow.coverage {
                case .open, .takenEarly, .valueOnRecord: return true
                case .closed, .awaitingResult, .underCare: return false
                }
            }
            .map { $0.row }

        let visits = buildVisits(openRows: openRows,
                                 tolerance: preferences.clusterToleranceDays,
                                 today: today)

        let covered = evaluated.filter { $0.coverage.isSatisfied }
        let pending = evaluated.filter { item in
            if case .awaitingResult = item.coverage { return true }
            return false
        }

        return SWSchedule(evaluated: evaluated,
                          visits: visits,
                          flags: buildFlags(encounters: encounters, now: now),
                          openRows: openRows,
                          coveredRows: covered,
                          pendingRows: pending,
                          underCareIDs: careFlags.map { $0.infectionID },
                          horizonCutoff: SWDay.adding(days: -horizonDays, to: today))
    }

    // MARK: Plain-text summary used by the copyable status card

    static func statusSummary(schedule: SWSchedule,
                              encounters: [SWEncounter],
                              testRecords: [SWTestRecord],
                              preferences: SWPreferences) -> String {

        var lines: [String] = []
        lines.append("SELF-REPORTED SEXUAL HEALTH SUMMARY")
        lines.append("Prepared on \(SWFormat.long(Date(), style: preferences.dateStyle))")
        lines.append("")
        lines.append("This summary was written by the person who holds this record. It is not a clinical document, it has not been verified by any service, and it should not be used in place of laboratory reports.")
        lines.append("")

        let sortedTests = testRecords.sorted { $0.collectedOn > $1.collectedOn }
        if let latest = sortedTests.first {
            lines.append("MOST RECENT RECORDED PANEL")
            lines.append("Date: \(SWFormat.long(latest.collectedOn, style: preferences.dateStyle))")
            lines.append("Service: \(latest.displayClinic)")
            if latest.results.isEmpty {
                lines.append("Entries: none recorded")
            } else {
                for result in latest.results.sorted(by: { $0.infectionID < $1.infectionID }) {
                    let name = SWInfectionCatalog.name(result.infectionID)
                    lines.append("  - \(name), \(result.site.title): \(result.value.title)")
                }
            }
        } else {
            lines.append("MOST RECENT RECORDED PANEL")
            lines.append("None recorded.")
        }
        lines.append("")

        let sortedEncounters = encounters.sorted { $0.date > $1.date }
        if let latestTest = sortedTests.first {
            let since = sortedEncounters.filter { $0.date > latestTest.collectedOn }
            lines.append("EXPOSURES RECORDED SINCE THAT DATE: \(since.count)")
        } else {
            lines.append("EXPOSURES RECORDED: \(sortedEncounters.count)")
        }
        lines.append("")

        lines.append("NEXT DATES ON THIS RECORD")
        if schedule.visits.isEmpty {
            lines.append("No dates outstanding.")
        } else {
            for visit in schedule.visits.prefix(4) {
                let when = SWFormat.long(visit.date, style: preferences.dateStyle)
                let what = visit.lines.map { "\(SWInfectionCatalog.shortName($0.infectionID)) (\($0.siteLabel))" }
                    .joined(separator: "; ")
                lines.append("  - \(when) — \(visit.kind.title): \(what)")
            }
        }
        lines.append("")
        lines.append("Intervals used here are commonly cited published guidance. Windows vary by test and by laboratory, and your clinic's guidance takes precedence.")

        return lines.joined(separator: "\n")
    }
}
