import Foundation

// MARK: - Forgiving decoding
//
// Every stored struct decodes field by field with a fallback. Adding a field in a
// later version therefore cannot throw and wipe a person's saved record, which is
// the one failure mode this app can least afford.

extension KeyedDecodingContainer {
    func decodeValue<T: Decodable>(_ key: Key, default fallback: T) -> T {
        do {
            if let value = try decodeIfPresent(T.self, forKey: key) { return value }
        } catch {
            return fallback
        }
        return fallback
    }

    func decodeOptional<T: Decodable>(_ key: Key) -> T? {
        do { return try decodeIfPresent(T.self, forKey: key) } catch { return nil }
    }
}

// MARK: - Specimen sites
//
// The site the sample is taken from. Site matters: a urine sample does not cover
// the throat or the rectum, which is the most frequently missed point in routine
// screening and one of the reasons this record exists.

enum SWSpecimenSite: String, Codable, CaseIterable, Identifiable {
    case blood
    case urogenital
    case pharyngeal
    case rectal
    case lesion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blood:      return "Blood"
        case .urogenital: return "Urogenital"
        case .pharyngeal: return "Throat"
        case .rectal:     return "Rectum"
        case .lesion:     return "Lesion"
        }
    }

    var specimenName: String {
        switch self {
        case .blood:      return "blood draw or finger-prick"
        case .urogenital: return "urine sample or urethral / vaginal swab"
        case .pharyngeal: return "pharyngeal (throat) swab"
        case .rectal:     return "rectal swab"
        case .lesion:     return "swab of an affected area"
        }
    }

    var shortLabel: String {
        switch self {
        case .blood:      return "Blood"
        case .urogenital: return "Urine / swab"
        case .pharyngeal: return "Throat swab"
        case .rectal:     return "Rectal swab"
        case .lesion:     return "Lesion swab"
        }
    }

    var explainer: String {
        switch self {
        case .blood:
            return "Systemic infections are looked for in blood, so one sample covers the whole body regardless of which site was exposed."
        case .urogenital:
            return "A urine sample or a urethral or vaginal swab covers the genital tract only."
        case .pharyngeal:
            return "A throat swab is the only specimen that covers the pharynx. Published guidance repeatedly notes that pharyngeal infection is usually without symptoms and is missed entirely if the swab is not taken."
        case .rectal:
            return "A rectal swab is the only specimen that covers the rectum. As with the throat, a urine sample does not substitute for it."
        case .lesion:
            return "Some tests are taken directly from an affected area rather than on a schedule, and only while that area is present."
        }
    }

    var sortOrder: Int {
        switch self {
        case .blood: return 0
        case .urogenital: return 1
        case .pharyngeal: return 2
        case .rectal: return 3
        case .lesion: return 4
        }
    }
}

// MARK: - Activity types
//
// Anatomical and neutral, exactly as a clinic intake form words them. Each type
// determines which specimen sites the schedule will include. The app makes no
// assumption about the anatomy or identity of anyone involved.

enum SWActivityType: String, Codable, CaseIterable, Identifiable {
    case oralGiving
    case oralReceiving
    case vaginalInsertive
    case vaginalReceptive
    case analInsertive
    case analReceptive
    case sharedItems
    case skinContact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oralGiving:       return "Oral — giving"
        case .oralReceiving:    return "Oral — receiving"
        case .vaginalInsertive: return "Vaginal — insertive"
        case .vaginalReceptive: return "Vaginal — receptive"
        case .analInsertive:    return "Anal — insertive"
        case .analReceptive:    return "Anal — receptive"
        case .sharedItems:      return "Shared items"
        case .skinContact:      return "Skin-to-skin genital contact"
        }
    }

    var clinicalNote: String {
        switch self {
        case .oralGiving:
            return "Your pharynx was the exposed site, so a throat swab is the specimen that covers it."
        case .oralReceiving:
            return "Your urogenital tract was the exposed site; a urine sample or swab covers it."
        case .vaginalInsertive:
            return "Your urethra was the exposed site; a urine sample or urethral swab covers it."
        case .vaginalReceptive:
            return "Your vaginal tract was the exposed site; a vaginal swab or urine sample covers it."
        case .analInsertive:
            return "Your urethra was the exposed site; a urine sample or urethral swab covers it."
        case .analReceptive:
            return "Your rectum was the exposed site, so a rectal swab is the specimen that covers it. Published guidance describes rectal infection as commonly without symptoms."
        case .sharedItems:
            return "Items used between sites or between people are described in published guidance as a route for the same organisms, so the sites involved are included."
        case .skinContact:
            return "Some organisms are described as passing by contact with skin rather than by fluids, so this is recorded even where no fluid exchange occurred."
        }
    }

    /// Which of the user's own sites this exposes, and therefore which specimens
    /// the schedule will list.
    var exposedSites: [SWSpecimenSite] {
        switch self {
        case .oralGiving:       return [.pharyngeal]
        case .oralReceiving:    return [.urogenital]
        case .vaginalInsertive: return [.urogenital]
        case .vaginalReceptive: return [.urogenital]
        case .analInsertive:    return [.urogenital]
        case .analReceptive:    return [.rectal]
        case .sharedItems:      return [.urogenital, .rectal]
        case .skinContact:      return [.urogenital]
        }
    }

    /// Relative weighting used only to decide whether the higher-risk prompt is offered.
    /// It is a prompt, never a verdict, and the user always decides.
    var promptsRiskQuestion: Bool {
        switch self {
        case .analReceptive, .analInsertive, .vaginalReceptive, .vaginalInsertive:
            return true
        default:
            return false
        }
    }

    var sortOrder: Int {
        switch self {
        case .oralGiving: return 0
        case .oralReceiving: return 1
        case .vaginalInsertive: return 2
        case .vaginalReceptive: return 3
        case .analInsertive: return 4
        case .analReceptive: return 5
        case .sharedItems: return 6
        case .skinContact: return 7
        }
    }
}

// MARK: - Barrier use

enum SWBarrierUse: String, Codable, CaseIterable, Identifiable {
    case used
    case partly
    case notUsed
    case notRecorded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .used:        return "Used"
        case .partly:      return "Partly"
        case .notUsed:     return "Not used"
        case .notRecorded: return "Not recorded"
        }
    }

    var shortTitle: String {
        switch self {
        case .used:        return "Barrier"
        case .partly:      return "Partial"
        case .notUsed:     return "None"
        case .notRecorded: return "—"
        }
    }
}

// MARK: - Relationship type

enum SWRelationshipType: String, Codable, CaseIterable, Identifiable {
    case regular
    case occasional
    case oneTime
    case anonymous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular:    return "Regular"
        case .occasional: return "Occasional"
        case .oneTime:    return "One time"
        case .anonymous:  return "Not identified"
        }
    }
}

// MARK: - Reported status of a partner
//
// Explicitly labelled as reported, never as verified. The app stores what the
// user was told and the date they were told it, and nothing more.

enum SWReportedStatus: String, Codable, CaseIterable, Identifiable {
    case unknown
    case reportedRecentPanel
    case reportedNoRecentPanel
    case reportedUnderCare
    case notDiscussed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown:                return "Unknown"
        case .reportedRecentPanel:    return "Reported a recent panel"
        case .reportedNoRecentPanel:  return "Reported no recent panel"
        case .reportedUnderCare:      return "Reported being under clinical care"
        case .notDiscussed:           return "Not discussed"
        }
    }
}

// MARK: - Test result values

enum SWResultValue: String, Codable, CaseIterable, Identifiable {
    case negative
    case positive
    case indeterminate
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .negative:      return "Negative"
        case .positive:      return "Positive"
        case .indeterminate: return "Indeterminate"
        case .pending:       return "Pending"
        }
    }

    var isConclusiveNegative: Bool { self == .negative }
}

// MARK: - PrEP mode

enum SWPrEPMode: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case onDemand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:     return "Not recorded"
        case .daily:    return "Daily schedule"
        case .onDemand: return "On-demand (2-1-1) schedule"
        }
    }
}

// MARK: - Date presentation preference

enum SWDateStyle: String, Codable, CaseIterable, Identifiable {
    case dayMonthYear
    case monthDayYear
    case isoNumeric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dayMonthYear: return "12 September 2026"
        case .monthDayYear: return "September 12, 2026"
        case .isoNumeric:   return "2026-09-12"
        }
    }

    var shortTitle: String {
        switch self {
        case .dayMonthYear: return "Day first"
        case .monthDayYear: return "Month first"
        case .isoNumeric:   return "Numeric"
        }
    }
}

// MARK: - Partner record

struct SWPartner: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var colorIndex: Int
    var relationship: SWRelationshipType
    var reportedStatus: SWReportedStatus
    var reportedStatusDate: Date?
    var reportedStatusNote: String
    var notes: String
    var createdAt: Date

    init(id: UUID = UUID(),
         label: String = "",
         colorIndex: Int = 0,
         relationship: SWRelationshipType = .occasional,
         reportedStatus: SWReportedStatus = .unknown,
         reportedStatusDate: Date? = nil,
         reportedStatusNote: String = "",
         notes: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.label = label
        self.colorIndex = colorIndex
        self.relationship = relationship
        self.reportedStatus = reportedStatus
        self.reportedStatusDate = reportedStatusDate
        self.reportedStatusNote = reportedStatusNote
        self.notes = notes
        self.createdAt = createdAt
    }

    // Written by hand so a future field can be added without wiping saved records.
    enum CodingKeys: String, CodingKey {
        case id, label, colorIndex, relationship, reportedStatus
        case reportedStatusDate, reportedStatusNote, notes, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        label = c.decodeValue(.label, default: "")
        colorIndex = c.decodeValue(.colorIndex, default: 0)
        relationship = c.decodeValue(.relationship, default: .occasional)
        reportedStatus = c.decodeValue(.reportedStatus, default: .unknown)
        reportedStatusDate = c.decodeOptional(.reportedStatusDate)
        reportedStatusNote = c.decodeValue(.reportedStatusNote, default: "")
        notes = c.decodeValue(.notes, default: "")
        createdAt = c.decodeValue(.createdAt, default: Date())
    }

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unlabeled entry" : trimmed
    }

    var initials: String {
        let trimmed = displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        if letters.isEmpty { return "?" }
        return letters.joined()
    }
}

// MARK: - Activity entry inside an encounter

struct SWActivityEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var type: SWActivityType
    var barrier: SWBarrierUse

    init(id: UUID = UUID(), type: SWActivityType, barrier: SWBarrierUse = .notRecorded) {
        self.id = id
        self.type = type
        self.barrier = barrier
    }

    enum CodingKeys: String, CodingKey { case id, type, barrier }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        type = c.decodeValue(.type, default: .skinContact)
        barrier = c.decodeValue(.barrier, default: .notRecorded)
    }
}

// MARK: - Encounter (a logged exposure)

struct SWEncounter: Identifiable, Codable, Equatable {
    var id: UUID
    var date: Date
    var partnerID: UUID?
    var activities: [SWActivityEntry]
    var higherRiskFlag: Bool
    var notes: String
    var createdAt: Date

    init(id: UUID = UUID(),
         date: Date = Date(),
         partnerID: UUID? = nil,
         activities: [SWActivityEntry] = [],
         higherRiskFlag: Bool = false,
         notes: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.date = date
        self.partnerID = partnerID
        self.activities = activities
        self.higherRiskFlag = higherRiskFlag
        self.notes = notes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, date, partnerID, activities, higherRiskFlag, notes, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        date = c.decodeValue(.date, default: Date())
        partnerID = c.decodeOptional(.partnerID)
        activities = c.decodeValue(.activities, default: [])
        higherRiskFlag = c.decodeValue(.higherRiskFlag, default: false)
        notes = c.decodeValue(.notes, default: "")
        createdAt = c.decodeValue(.createdAt, default: Date())
    }

    var dayKey: Int { SWDay.key(date) }

    var exposedSites: [SWSpecimenSite] {
        var set = Set<SWSpecimenSite>()
        for entry in activities {
            for site in entry.type.exposedSites { set.insert(site) }
        }
        // Every logged exposure carries a blood component for the systemic entries.
        if !activities.isEmpty { set.insert(.blood) }
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    var barrierSummary: SWBarrierUse {
        if activities.isEmpty { return .notRecorded }
        if activities.allSatisfy({ $0.barrier == .used }) { return .used }
        if activities.contains(where: { $0.barrier == .notUsed }) { return .notUsed }
        if activities.contains(where: { $0.barrier == .partly }) { return .partly }
        return .notRecorded
    }

    var activityTitleList: String {
        if activities.isEmpty { return "No activity types recorded" }
        return activities
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
            .map { $0.type.title }
            .joined(separator: ", ")
    }
}

// MARK: - A single infection result inside a test record

struct SWResultEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var infectionID: String
    var site: SWSpecimenSite
    var value: SWResultValue
    var note: String

    init(id: UUID = UUID(),
         infectionID: String,
         site: SWSpecimenSite,
         value: SWResultValue = .negative,
         note: String = "") {
        self.id = id
        self.infectionID = infectionID
        self.site = site
        self.value = value
        self.note = note
    }

    enum CodingKeys: String, CodingKey { case id, infectionID, site, value, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        infectionID = c.decodeValue(.infectionID, default: "")
        site = c.decodeValue(.site, default: .blood)
        value = c.decodeValue(.value, default: .pending)
        note = c.decodeValue(.note, default: "")
    }
}

// MARK: - Test record

struct SWTestRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var collectedOn: Date
    var clinicLabel: String
    var results: [SWResultEntry]
    var notes: String
    var createdAt: Date

    init(id: UUID = UUID(),
         collectedOn: Date = Date(),
         clinicLabel: String = "",
         results: [SWResultEntry] = [],
         notes: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.collectedOn = collectedOn
        self.clinicLabel = clinicLabel
        self.results = results
        self.notes = notes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, collectedOn, clinicLabel, results, notes, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        collectedOn = c.decodeValue(.collectedOn, default: Date())
        clinicLabel = c.decodeValue(.clinicLabel, default: "")
        results = c.decodeValue(.results, default: [])
        notes = c.decodeValue(.notes, default: "")
        createdAt = c.decodeValue(.createdAt, default: Date())
    }

    var displayClinic: String {
        let trimmed = clinicLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed service" : trimmed
    }

    var siteList: [SWSpecimenSite] {
        var set = Set<SWSpecimenSite>()
        for r in results { set.insert(r.site) }
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasPending: Bool { results.contains { $0.value == .pending } }
    var hasPositive: Bool { results.contains { $0.value == .positive } }
    var hasIndeterminate: Bool { results.contains { $0.value == .indeterminate } }
}

// MARK: - PrEP daily adherence entry

struct SWDoseDay: Codable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
    var taken: Bool

    init(id: UUID = UUID(), dayKey: Int, taken: Bool) {
        self.id = id
        self.dayKey = dayKey
        self.taken = taken
    }

    enum CodingKeys: String, CodingKey { case id, dayKey, taken }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        dayKey = c.decodeValue(.dayKey, default: 0)
        taken = c.decodeValue(.taken, default: false)
    }
}

// MARK: - On-demand (2-1-1) sequence

struct SWOnDemandSequence: Codable, Equatable, Identifiable {
    var id: UUID
    /// Time of the loading dose. The remaining two doses are anchored to it.
    var loadingDoseAt: Date
    var loadingTaken: Bool
    var secondTaken: Bool
    var thirdTaken: Bool
    var note: String

    init(id: UUID = UUID(),
         loadingDoseAt: Date = Date(),
         loadingTaken: Bool = false,
         secondTaken: Bool = false,
         thirdTaken: Bool = false,
         note: String = "") {
        self.id = id
        self.loadingDoseAt = loadingDoseAt
        self.loadingTaken = loadingTaken
        self.secondTaken = secondTaken
        self.thirdTaken = thirdTaken
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id, loadingDoseAt, loadingTaken, secondTaken, thirdTaken, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        loadingDoseAt = c.decodeValue(.loadingDoseAt, default: Date())
        loadingTaken = c.decodeValue(.loadingTaken, default: false)
        secondTaken = c.decodeValue(.secondTaken, default: false)
        thirdTaken = c.decodeValue(.thirdTaken, default: false)
        note = c.decodeValue(.note, default: "")
    }

    var secondDoseAt: Date { loadingDoseAt.addingTimeInterval(24 * 3600) }
    var thirdDoseAt: Date { loadingDoseAt.addingTimeInterval(48 * 3600) }

    var isComplete: Bool { loadingTaken && secondTaken && thirdTaken }
}

// MARK: - PrEP state

struct SWPrEPState: Codable, Equatable {
    var mode: SWPrEPMode
    var dailyStartDate: Date?
    var doseDays: [SWDoseDay]
    var sequences: [SWOnDemandSequence]
    var onsetProfile: SWOnsetProfile

    init(mode: SWPrEPMode = .none,
         dailyStartDate: Date? = nil,
         doseDays: [SWDoseDay] = [],
         sequences: [SWOnDemandSequence] = [],
         onsetProfile: SWOnsetProfile = .receptiveAnal) {
        self.mode = mode
        self.dailyStartDate = dailyStartDate
        self.doseDays = doseDays
        self.sequences = sequences
        self.onsetProfile = onsetProfile
    }

    enum CodingKeys: String, CodingKey {
        case mode, dailyStartDate, doseDays, sequences, onsetProfile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = c.decodeValue(.mode, default: .none)
        dailyStartDate = c.decodeOptional(.dailyStartDate)
        doseDays = c.decodeValue(.doseDays, default: [])
        sequences = c.decodeValue(.sequences, default: [])
        onsetProfile = c.decodeValue(.onsetProfile, default: .receptiveAnal)
    }
}

enum SWOnsetProfile: String, Codable, CaseIterable, Identifiable {
    case receptiveAnal
    case otherExposure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .receptiveAnal:  return "Receptive anal exposure"
        case .otherExposure:  return "Vaginal or other exposure"
        }
    }

    /// Commonly cited days from starting a daily schedule to the point published
    /// guidance describes protection as established. Descriptive, not instruction.
    var days: Int {
        switch self {
        case .receptiveAnal: return 7
        case .otherExposure: return 20
        }
    }

    var citation: String {
        switch self {
        case .receptiveAnal:
            return "Commonly cited as about 7 days of daily dosing for receptive anal exposure."
        case .otherExposure:
            return "Commonly cited as about 20 days of daily dosing for vaginal and other exposure."
        }
    }
}

// MARK: - Vaccination record

enum SWVaccineKind: String, Codable, CaseIterable, Identifiable {
    case hpv
    case hepatitisA
    case hepatitisB
    case mpox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hpv:        return "HPV"
        case .hepatitisA: return "Hepatitis A"
        case .hepatitisB: return "Hepatitis B"
        case .mpox:       return "Mpox"
        }
    }

    var doseCount: Int {
        switch self {
        case .hpv:        return 3
        case .hepatitisA: return 2
        case .hepatitisB: return 3
        case .mpox:       return 2
        }
    }

    /// Commonly cited days from the FIRST dose to each subsequent dose.
    var offsetsFromFirstDose: [Int] {
        switch self {
        case .hpv:        return [0, 60, 180]
        case .hepatitisA: return [0, 180]
        case .hepatitisB: return [0, 30, 180]
        case .mpox:       return [0, 28]
        }
    }

    var scheduleSummary: String {
        switch self {
        case .hpv:
            return "Commonly cited as three doses over about six months for people vaccinated as adults: the second around two months after the first, the third around six months after the first."
        case .hepatitisA:
            return "Commonly cited as two doses, the second around six months after the first."
        case .hepatitisB:
            return "Commonly cited as three doses: the second around one month after the first, the third around six months after the first. Accelerated schedules exist and are a clinical decision."
        case .mpox:
            return "Commonly cited as two doses about 28 days apart."
        }
    }

    var relevanceNote: String {
        switch self {
        case .hpv:
            return "HPV is very common and usually clears without any intervention. Vaccination is described in public health guidance as the main way to reduce the types most associated with later disease. There is no routine screening test for most people, which is why it does not appear on the testing schedule."
        case .hepatitisA:
            return "Hepatitis A is described as passing by the fecal-oral route, which includes oral-anal contact. It appears in the reference library rather than on the routine schedule because vaccination, not periodic testing, is what published guidance emphasizes."
        case .hepatitisB:
            return "Hepatitis B is both vaccine-preventable and testable. If your record shows a completed course, you may wish to switch hepatitis B off in the schedule settings and discuss immunity testing with your clinician."
        case .mpox:
            return "Mpox testing is described as being done from an affected area when one is present, rather than on a fixed schedule, which is why it does not generate window dates."
        }
    }
}

struct SWVaccineDose: Codable, Equatable, Identifiable {
    var id: UUID
    var index: Int
    var date: Date

    init(id: UUID = UUID(), index: Int, date: Date) {
        self.id = id
        self.index = index
        self.date = date
    }

    enum CodingKeys: String, CodingKey { case id, index, date }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        index = c.decodeValue(.index, default: 0)
        date = c.decodeValue(.date, default: Date())
    }
}

struct SWVaccineRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: SWVaccineKind
    var doses: [SWVaccineDose]
    var notApplicable: Bool
    var note: String

    init(id: UUID = UUID(),
         kind: SWVaccineKind,
         doses: [SWVaccineDose] = [],
         notApplicable: Bool = false,
         note: String = "") {
        self.id = id
        self.kind = kind
        self.doses = doses
        self.notApplicable = notApplicable
        self.note = note
    }

    enum CodingKeys: String, CodingKey { case id, kind, doses, notApplicable, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        kind = c.decodeValue(.kind, default: .hpv)
        doses = c.decodeValue(.doses, default: [])
        notApplicable = c.decodeValue(.notApplicable, default: false)
        note = c.decodeValue(.note, default: "")
    }

    var recordedDoses: Int { doses.count }
    var isComplete: Bool { recordedDoses >= kind.doseCount }

    var firstDoseDate: Date? {
        doses.sorted { $0.index < $1.index }.first?.date
    }

    /// The commonly cited date of the next dose, if the course is unfinished.
    var nextDoseDueDate: Date? {
        guard !isComplete, let first = firstDoseDate else { return nil }
        let offsets = kind.offsetsFromFirstDose
        let nextIndex = recordedDoses // 0-based index of the next dose
        guard nextIndex < offsets.count else { return nil }
        return SWDay.adding(days: offsets[nextIndex], to: first)
    }
}

// MARK: - Preferences

struct SWPreferences: Codable, Equatable {
    var privacyLockEnabled: Bool
    var discreetModeEnabled: Bool
    var neutralTitle: String
    var dateStyle: SWDateStyle
    var weekStartsMonday: Bool
    var enabledInfectionIDs: [String]
    var hivAssayPreference: String
    var hcvAssayPreference: String
    var clusterToleranceDays: Int
    var onboardingSeen: Bool
    var disclaimerAcknowledged: Bool

    init(privacyLockEnabled: Bool = true,
         discreetModeEnabled: Bool = true,
         neutralTitle: String = "Status Window",
         dateStyle: SWDateStyle = .dayMonthYear,
         weekStartsMonday: Bool = true,
         enabledInfectionIDs: [String] = SWInfectionCatalog.defaultEnabledIDs,
         hivAssayPreference: String = "hiv_agab",
         hcvAssayPreference: String = "hcv_ab",
         clusterToleranceDays: Int = 14,
         onboardingSeen: Bool = false,
         disclaimerAcknowledged: Bool = false) {
        self.privacyLockEnabled = privacyLockEnabled
        self.discreetModeEnabled = discreetModeEnabled
        self.neutralTitle = neutralTitle
        self.dateStyle = dateStyle
        self.weekStartsMonday = weekStartsMonday
        self.enabledInfectionIDs = enabledInfectionIDs
        self.hivAssayPreference = hivAssayPreference
        self.hcvAssayPreference = hcvAssayPreference
        self.clusterToleranceDays = clusterToleranceDays
        self.onboardingSeen = onboardingSeen
        self.disclaimerAcknowledged = disclaimerAcknowledged
    }

    enum CodingKeys: String, CodingKey {
        case privacyLockEnabled, discreetModeEnabled, neutralTitle, dateStyle
        case weekStartsMonday, enabledInfectionIDs, hivAssayPreference
        case hcvAssayPreference, clusterToleranceDays, onboardingSeen
        case disclaimerAcknowledged
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        privacyLockEnabled = c.decodeValue(.privacyLockEnabled, default: true)
        discreetModeEnabled = c.decodeValue(.discreetModeEnabled, default: true)
        neutralTitle = c.decodeValue(.neutralTitle, default: "Status Window")
        dateStyle = c.decodeValue(.dateStyle, default: .dayMonthYear)
        weekStartsMonday = c.decodeValue(.weekStartsMonday, default: true)
        enabledInfectionIDs = c.decodeValue(.enabledInfectionIDs, default: SWInfectionCatalog.defaultEnabledIDs)
        hivAssayPreference = c.decodeValue(.hivAssayPreference, default: "hiv_agab")
        hcvAssayPreference = c.decodeValue(.hcvAssayPreference, default: "hcv_ab")
        clusterToleranceDays = c.decodeValue(.clusterToleranceDays, default: 14)
        onboardingSeen = c.decodeValue(.onboardingSeen, default: false)
        disclaimerAcknowledged = c.decodeValue(.disclaimerAcknowledged, default: false)
    }
}

// MARK: - Under-care flags
//
// When a result is recorded as positive, that infection is marked as under care
// and the schedule stops prompting for it. The app offers no interpretation of
// the result beyond pointing back to the user's own clinical service.

struct SWCareFlag: Codable, Equatable, Identifiable {
    var id: UUID
    var infectionID: String
    var since: Date
    var note: String

    init(id: UUID = UUID(), infectionID: String, since: Date = Date(), note: String = "") {
        self.id = id
        self.infectionID = infectionID
        self.since = since
        self.note = note
    }

    enum CodingKeys: String, CodingKey { case id, infectionID, since, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeValue(.id, default: UUID())
        infectionID = c.decodeValue(.infectionID, default: "")
        since = c.decodeValue(.since, default: Date())
        note = c.decodeValue(.note, default: "")
    }
}

// MARK: - The persisted archive

struct SWArchive: Codable, Equatable {
    var schemaVersion: Int
    var partners: [SWPartner]
    var encounters: [SWEncounter]
    var testRecords: [SWTestRecord]
    var prep: SWPrEPState
    var vaccines: [SWVaccineRecord]
    var careFlags: [SWCareFlag]
    var preferences: SWPreferences

    init(schemaVersion: Int = 1,
         partners: [SWPartner] = [],
         encounters: [SWEncounter] = [],
         testRecords: [SWTestRecord] = [],
         prep: SWPrEPState = SWPrEPState(),
         vaccines: [SWVaccineRecord] = SWArchive.emptyVaccineSet,
         careFlags: [SWCareFlag] = [],
         preferences: SWPreferences = SWPreferences()) {
        self.schemaVersion = schemaVersion
        self.partners = partners
        self.encounters = encounters
        self.testRecords = testRecords
        self.prep = prep
        self.vaccines = vaccines
        self.careFlags = careFlags
        self.preferences = preferences
    }

    static var emptyVaccineSet: [SWVaccineRecord] {
        SWVaccineKind.allCases.map { SWVaccineRecord(kind: $0) }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, partners, encounters, testRecords, prep
        case vaccines, careFlags, preferences
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.decodeValue(.schemaVersion, default: 1)
        partners = c.decodeValue(.partners, default: [])
        encounters = c.decodeValue(.encounters, default: [])
        testRecords = c.decodeValue(.testRecords, default: [])
        prep = c.decodeValue(.prep, default: SWPrEPState())
        var loadedVaccines: [SWVaccineRecord] = c.decodeValue(.vaccines, default: [])
        // Guarantee one row per kind even if the file predates a kind being added.
        for kind in SWVaccineKind.allCases where !loadedVaccines.contains(where: { $0.kind == kind }) {
            loadedVaccines.append(SWVaccineRecord(kind: kind))
        }
        vaccines = loadedVaccines
        careFlags = c.decodeValue(.careFlags, default: [])
        preferences = c.decodeValue(.preferences, default: SWPreferences())
    }
}
