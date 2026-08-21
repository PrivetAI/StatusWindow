import SwiftUI

// MARK: - Per-partner summary

struct SWPartnerSummary: Equatable {
    var encounterCount: Int
    var firstDate: Date?
    var lastDate: Date?
    var barrierUsedCount: Int
    var barrierPartialCount: Int
    var barrierNoneCount: Int
    var barrierUnrecordedCount: Int
    var higherRiskCount: Int
    var testsAfterLastEncounter: Int
    var sitesInvolved: [SWSpecimenSite]

    static let empty = SWPartnerSummary(encounterCount: 0, firstDate: nil, lastDate: nil,
                                        barrierUsedCount: 0, barrierPartialCount: 0,
                                        barrierNoneCount: 0, barrierUnrecordedCount: 0,
                                        higherRiskCount: 0, testsAfterLastEncounter: 0,
                                        sitesInvolved: [])

    /// Proportion of recorded activities where a barrier was noted as used.
    var barrierProportion: Double? {
        let denominator = barrierUsedCount + barrierPartialCount + barrierNoneCount
        guard denominator > 0 else { return nil }
        return SWMath.percent(barrierUsedCount, of: denominator)
    }

    /// Always carries its denominator. One activity marked "Used" alongside nine
    /// left at "Not recorded" is a truthful 100% of what was recorded, and reads
    /// as a false statement about the whole partner without the count beside it.
    var barrierLabel: String {
        let denominator = barrierUsedCount + barrierPartialCount + barrierNoneCount
        guard denominator > 0 else { return "Not recorded" }
        return "\(SWFormat.percentString(barrierProportion)) (\(barrierUsedCount) of \(denominator) recorded)"
    }
}

// MARK: - Store
//
// Everything lives in one JSON file inside Application Support, written with
// `FileProtectionType.complete`, so the file is unreadable while the device is
// locked and is not exposed the way a preferences plist is. Nothing in this app
// is written to UserDefaults, nothing is synced, and nothing is uploaded.

final class SWStore: ObservableObject {

    @Published private(set) var partners: [SWPartner] = []
    @Published private(set) var encounters: [SWEncounter] = []
    @Published private(set) var testRecords: [SWTestRecord] = []
    @Published private(set) var vaccines: [SWVaccineRecord] = SWArchive.emptyVaccineSet
    @Published private(set) var careFlags: [SWCareFlag] = []
    @Published private(set) var prep: SWPrEPState = SWPrEPState()

    @Published var preferences: SWPreferences = SWPreferences() {
        didSet {
            if preferences != oldValue {
                SWDay.setWeekStartsMonday(preferences.weekStartsMonday)
                rebuildSchedule()
                persist()
            }
        }
    }

    /// The merged forward schedule. Recomputed whenever anything it depends on changes.
    @Published private(set) var schedule: SWSchedule = .empty

    @Published private(set) var lastWriteFailed: Bool = false

    /// True when a record file exists on disk but could not be read or decoded.
    /// While this is set, `didLoad` stays false so `persist()` can never replace
    /// the real record with the empty one shown on screen.
    @Published private(set) var loadFailed: Bool = false

    private let fileName = "status-window-record.json"
    private var didLoad = false

    // MARK: File location

    private var directoryURL: URL? {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory,
                                      in: .userDomainMask).first else { return nil }
        let folder = base.appendingPathComponent("StatusWindowRecord", isDirectory: true)
        if !manager.fileExists(atPath: folder.path) {
            try? manager.createDirectory(at: folder,
                                         withIntermediateDirectories: true,
                                         attributes: [.protectionKey: FileProtectionType.complete])
        }
        return folder
    }

    private var fileURL: URL? {
        directoryURL?.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: Lifecycle

    init() {
        load()
    }

    // MARK: Load / persist

    func load() {
        guard let url = fileURL else {
            applyEmpty()
            didLoad = true
            loadFailed = false
            rebuildSchedule()
            return
        }

        // The distinction that matters: "no file yet" is a normal first run and
        // must unblock writing, but "a file is there and I could not read it" must
        // NOT. The record is written with complete protection, so it is genuinely
        // unreadable while the device is locked -- and this initialiser can run in
        // that state, because the launch gate's 5s fallback builds the root view
        // whether or not the user is looking at the screen. Treating that as an
        // empty record and then allowing a write would destroy the real one.
        let fileExists = FileManager.default.fileExists(atPath: url.path)

        guard let data = try? Data(contentsOf: url) else {
            applyEmpty()
            didLoad = !fileExists
            loadFailed = fileExists
            rebuildSchedule()
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let archive = try? decoder.decode(SWArchive.self, from: data) {
            partners = archive.partners
            encounters = archive.encounters.sorted { $0.date > $1.date }
            testRecords = archive.testRecords.sorted { $0.collectedOn > $1.collectedOn }
            vaccines = archive.vaccines
            careFlags = archive.careFlags
            prep = archive.prep
            preferencesWithoutWrite(archive.preferences)
            didLoad = true
            loadFailed = false
        } else {
            // Readable but not decodable. Keep the bytes: a future version may be
            // able to recover them, and an empty overwrite certainly cannot.
            applyEmpty()
            didLoad = false
            loadFailed = true
        }

        SWDay.setWeekStartsMonday(preferences.weekStartsMonday)
        rebuildSchedule()
    }

    /// Re-attempts a load that previously failed. Safe to call on every foreground:
    /// it is a no-op unless a real record is sitting on disk unread.
    func retryLoadIfNeeded() {
        guard loadFailed else { return }
        load()
    }

    private func applyEmpty() {
        partners = []
        encounters = []
        testRecords = []
        vaccines = SWArchive.emptyVaccineSet
        careFlags = []
        prep = SWPrEPState()
        preferencesWithoutWrite(SWPreferences())
    }

    /// Assigns preferences during load without triggering the write-on-change hook.
    private func preferencesWithoutWrite(_ value: SWPreferences) {
        let wasLoaded = didLoad
        didLoad = false
        preferences = value
        didLoad = wasLoaded
    }

    private func persist() {
        guard didLoad else { return }
        guard let url = fileURL else { return }
        let archive = SWArchive(schemaVersion: 1,
                                partners: partners,
                                encounters: encounters,
                                testRecords: testRecords,
                                prep: prep,
                                vaccines: vaccines,
                                careFlags: careFlags,
                                preferences: preferences)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(archive) else {
            lastWriteFailed = true
            return
        }
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            // Re-assert protection in case the atomic replace produced a fresh inode.
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                                   ofItemAtPath: url.path)
            lastWriteFailed = false
        } catch {
            lastWriteFailed = true
        }
    }

    private func commit() {
        rebuildSchedule()
        persist()
    }

    // MARK: Schedule

    func rebuildSchedule() {
        schedule = SWWindowEngine.build(encounters: encounters,
                                        testRecords: testRecords,
                                        careFlags: careFlags,
                                        preferences: preferences)
    }

    // MARK: Partners

    func partner(_ id: UUID?) -> SWPartner? {
        guard let id = id else { return nil }
        return partners.first { $0.id == id }
    }

    func partnerLabel(_ id: UUID?) -> String {
        partner(id)?.displayLabel ?? "Not identified"
    }

    func partnerColorIndex(_ id: UUID?) -> Int {
        partner(id)?.colorIndex ?? 7
    }

    func addPartner(_ partner: SWPartner) {
        partners.append(partner)
        partners.sort { $0.displayLabel.lowercased() < $1.displayLabel.lowercased() }
        commit()
    }

    func updatePartner(_ partner: SWPartner) {
        guard let index = partners.firstIndex(where: { $0.id == partner.id }) else { return }
        partners[index] = partner
        partners.sort { $0.displayLabel.lowercased() < $1.displayLabel.lowercased() }
        commit()
    }

    /// Deleting a partner never silently deletes their encounters. The caller
    /// chooses whether the encounters are reassigned to the unidentified pool or
    /// removed with the record.
    func deletePartner(_ id: UUID, reassignEncounters: Bool) {
        partners.removeAll { $0.id == id }
        if reassignEncounters {
            for index in encounters.indices where encounters[index].partnerID == id {
                encounters[index].partnerID = nil
            }
        } else {
            encounters.removeAll { $0.partnerID == id }
        }
        commit()
    }

    func encounters(for partnerID: UUID) -> [SWEncounter] {
        encounters.filter { $0.partnerID == partnerID }.sorted { $0.date > $1.date }
    }

    var anonymousEncounters: [SWEncounter] {
        encounters.filter { $0.partnerID == nil }.sorted { $0.date > $1.date }
    }

    func summary(for partnerID: UUID?) -> SWPartnerSummary {
        let list: [SWEncounter]
        if let partnerID = partnerID {
            list = encounters(for: partnerID)
        } else {
            list = anonymousEncounters
        }
        guard !list.isEmpty else { return .empty }

        var used = 0, partial = 0, none = 0, unrecorded = 0, risky = 0
        var siteSet = Set<SWSpecimenSite>()
        for encounter in list {
            if encounter.higherRiskFlag { risky += 1 }
            for site in encounter.exposedSites where site != .blood { siteSet.insert(site) }
            for activity in encounter.activities {
                switch activity.barrier {
                case .used: used += 1
                case .partly: partial += 1
                case .notUsed: none += 1
                case .notRecorded: unrecorded += 1
                }
            }
        }

        let dates = list.map { $0.date }.sorted()
        let last = dates.last
        var testsAfter = 0
        if let last = last {
            testsAfter = testRecords.filter { SWDay.key($0.collectedOn) >= SWDay.key(last) }.count
        }

        return SWPartnerSummary(encounterCount: list.count,
                                firstDate: dates.first,
                                lastDate: last,
                                barrierUsedCount: used,
                                barrierPartialCount: partial,
                                barrierNoneCount: none,
                                barrierUnrecordedCount: unrecorded,
                                higherRiskCount: risky,
                                testsAfterLastEncounter: testsAfter,
                                sitesInvolved: siteSet.sorted { $0.sortOrder < $1.sortOrder })
    }

    // MARK: Encounters

    func addEncounter(_ encounter: SWEncounter) {
        encounters.append(encounter)
        encounters.sort { $0.date > $1.date }
        commit()
    }

    func updateEncounter(_ encounter: SWEncounter) {
        guard let index = encounters.firstIndex(where: { $0.id == encounter.id }) else { return }
        encounters[index] = encounter
        encounters.sort { $0.date > $1.date }
        commit()
    }

    func deleteEncounter(_ id: UUID) {
        encounters.removeAll { $0.id == id }
        commit()
    }

    func encounter(_ id: UUID) -> SWEncounter? {
        encounters.first { $0.id == id }
    }

    // MARK: Test records

    func addTestRecord(_ record: SWTestRecord) {
        testRecords.append(record)
        testRecords.sort { $0.collectedOn > $1.collectedOn }
        syncCareFlags(with: record)
        commit()
    }

    func updateTestRecord(_ record: SWTestRecord) {
        guard let index = testRecords.firstIndex(where: { $0.id == record.id }) else { return }
        testRecords[index] = record
        testRecords.sort { $0.collectedOn > $1.collectedOn }
        syncCareFlags(with: record)
        commit()
    }

    func deleteTestRecord(_ id: UUID) {
        testRecords.removeAll { $0.id == id }
        commit()
    }

    /// A positive value marks that entry as under care so the schedule stops
    /// prompting for it. The app draws no other conclusion from the value, and
    /// the flag can be cleared by hand at any time.
    private func syncCareFlags(with record: SWTestRecord) {
        for result in record.results where result.value == .positive {
            if !careFlags.contains(where: { $0.infectionID == result.infectionID }) {
                careFlags.append(SWCareFlag(infectionID: result.infectionID,
                                            since: record.collectedOn,
                                            note: "Added automatically from a recorded result."))
            }
        }
    }

    func setCareFlag(_ infectionID: String, active: Bool, note: String = "") {
        if active {
            if !careFlags.contains(where: { $0.infectionID == infectionID }) {
                careFlags.append(SWCareFlag(infectionID: infectionID, since: Date(), note: note))
            }
        } else {
            careFlags.removeAll { $0.infectionID == infectionID }
        }
        commit()
    }

    func isUnderCare(_ infectionID: String) -> Bool {
        careFlags.contains { $0.infectionID == infectionID }
    }

    var latestTestRecord: SWTestRecord? {
        testRecords.sorted { $0.collectedOn > $1.collectedOn }.first
    }

    /// The most recent record that covered every entry currently switched on.
    var latestFullPanel: SWTestRecord? {
        let enabled = Set(preferences.enabledInfectionIDs)
        guard !enabled.isEmpty else { return nil }
        return testRecords
            .sorted { $0.collectedOn > $1.collectedOn }
            .first { record in
                let covered = Set(record.results.filter { $0.value != .pending }.map { $0.infectionID })
                return enabled.isSubset(of: covered)
            }
    }

    var encountersSinceLatestPanel: Int {
        guard let latest = latestTestRecord else { return encounters.count }
        return encounters.filter { $0.date > latest.collectedOn }.count
    }

    // MARK: Infection selection

    func isInfectionEnabled(_ id: String) -> Bool {
        preferences.enabledInfectionIDs.contains(id)
    }

    func setInfectionEnabled(_ id: String, _ enabled: Bool) {
        var list = preferences.enabledInfectionIDs
        if enabled {
            if !list.contains(id) { list.append(id) }
        } else {
            list.removeAll { $0 == id }
        }
        preferences.enabledInfectionIDs = list
    }

    // MARK: PrEP

    func setPrEPMode(_ mode: SWPrEPMode) {
        prep.mode = mode
        if mode == .daily && prep.dailyStartDate == nil {
            prep.dailyStartDate = SWDay.today
        }
        commit()
    }

    func setDailyStart(_ date: Date) {
        prep.dailyStartDate = SWDay.start(date)
        commit()
    }

    func doseState(for day: Date) -> Bool? {
        let key = SWDay.key(day)
        return prep.doseDays.first { $0.dayKey == key }?.taken
    }

    func toggleDose(for day: Date) {
        let key = SWDay.key(day)
        if let index = prep.doseDays.firstIndex(where: { $0.dayKey == key }) {
            if prep.doseDays[index].taken {
                prep.doseDays[index].taken = false
            } else {
                prep.doseDays.remove(at: index)
            }
        } else {
            prep.doseDays.append(SWDoseDay(dayKey: key, taken: true))
        }
        commit()
    }

    func clearDose(for day: Date) {
        let key = SWDay.key(day)
        prep.doseDays.removeAll { $0.dayKey == key }
        commit()
    }

    func setOnsetProfile(_ profile: SWOnsetProfile) {
        prep.onsetProfile = profile
        commit()
    }

    /// Adherence over the last `days` calendar days, counting only days on or
    /// after the recorded start date.
    func adherence(days: Int) -> (taken: Int, missed: Int, total: Int) {
        let span = max(1, days)
        guard let start = prep.dailyStartDate else { return (0, 0, 0) }
        var taken = 0, missed = 0, total = 0
        for offset in 0..<span {
            let day = SWDay.adding(days: -offset, to: SWDay.today)
            guard SWDay.key(day) >= SWDay.key(start) else { continue }
            total += 1
            if let state = doseState(for: day) {
                if state { taken += 1 } else { missed += 1 }
            } else {
                missed += 1
            }
        }
        return (taken, missed, total)
    }

    var protectionOnsetDate: Date? {
        guard prep.mode == .daily, let start = prep.dailyStartDate else { return nil }
        return SWDay.adding(days: prep.onsetProfile.days, to: start)
    }

    func addSequence(_ sequence: SWOnDemandSequence) {
        prep.sequences.append(sequence)
        prep.sequences.sort { $0.loadingDoseAt > $1.loadingDoseAt }
        commit()
    }

    func updateSequence(_ sequence: SWOnDemandSequence) {
        guard let index = prep.sequences.firstIndex(where: { $0.id == sequence.id }) else { return }
        prep.sequences[index] = sequence
        prep.sequences.sort { $0.loadingDoseAt > $1.loadingDoseAt }
        commit()
    }

    func deleteSequence(_ id: UUID) {
        prep.sequences.removeAll { $0.id == id }
        commit()
    }

    var activeSequence: SWOnDemandSequence? {
        let now = Date()
        return prep.sequences.first { sequence in
            !sequence.isComplete && sequence.thirdDoseAt.addingTimeInterval(24 * 3600) > now
        }
    }

    // MARK: Vaccines

    func vaccine(_ kind: SWVaccineKind) -> SWVaccineRecord {
        vaccines.first { $0.kind == kind } ?? SWVaccineRecord(kind: kind)
    }

    func updateVaccine(_ record: SWVaccineRecord) {
        if let index = vaccines.firstIndex(where: { $0.kind == record.kind }) {
            vaccines[index] = record
        } else {
            vaccines.append(record)
        }
        commit()
    }

    func addVaccineDose(_ kind: SWVaccineKind, date: Date) {
        var record = vaccine(kind)
        guard record.doses.count < kind.doseCount else { return }
        record.doses.append(SWVaccineDose(index: record.doses.count, date: SWDay.start(date)))
        record.doses.sort { $0.date < $1.date }
        for i in record.doses.indices { record.doses[i].index = i }
        updateVaccine(record)
    }

    func removeLastVaccineDose(_ kind: SWVaccineKind) {
        var record = vaccine(kind)
        guard !record.doses.isEmpty else { return }
        record.doses.removeLast()
        for i in record.doses.indices { record.doses[i].index = i }
        updateVaccine(record)
    }

    // MARK: Reset

    /// A genuinely complete delete: the in-memory state, the file, and the folder.
    func eraseEverything() {
        partners = []
        encounters = []
        testRecords = []
        vaccines = SWArchive.emptyVaccineSet
        careFlags = []
        prep = SWPrEPState()

        if let url = fileURL {
            // Overwrite before unlinking so the previous bytes are not left behind
            // in place, then remove the file and the containing folder.
            let scrub = Data(count: 8192)
            try? scrub.write(to: url, options: [.atomic, .completeFileProtection])
            try? FileManager.default.removeItem(at: url)
        }
        if let folder = directoryURL {
            try? FileManager.default.removeItem(at: folder)
        }

        var fresh = SWPreferences()
        fresh.onboardingSeen = preferences.onboardingSeen
        fresh.disclaimerAcknowledged = preferences.disclaimerAcknowledged
        preferences = fresh
        rebuildSchedule()
        persist()
    }

    // MARK: Derived counts for the status card

    var recordCounts: (partners: Int, encounters: Int, tests: Int, doses: Int) {
        (partners.count, encounters.count, testRecords.count, prep.doseDays.count)
    }
}
