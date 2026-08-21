import Foundation

// MARK: - Infection families

enum SWInfectionFamily: String, CaseIterable {
    case bacterial
    case viral
    case parasitic

    var title: String {
        switch self {
        case .bacterial: return "Bacterial"
        case .viral:     return "Viral"
        case .parasitic: return "Parasitic"
        }
    }
}

// MARK: - Assay
//
// One test technology with the interval commonly cited in published guidance
// between an exposure and the point at which that technology is described as
// able to detect, and later as conclusive. These are general published figures,
// not a personal instruction, and laboratories differ.

struct SWAssay: Identifiable, Equatable {
    let id: String
    let infectionID: String
    /// What a clinic would call this test.
    let name: String
    /// Short label used in dense rows.
    let shortName: String
    /// What the technology actually looks for.
    let technology: String
    /// Commonly cited first day a result may be meaningful.
    let earliestDay: Int
    /// Commonly cited day at which the window is described as closed.
    let conclusiveDay: Int
    /// Whether this assay is used on a schedule at all.
    let scheduled: Bool
    let note: String

    var windowSpan: Int { max(0, conclusiveDay - earliestDay) }

    var intervalLabel: String {
        if !scheduled { return "Not scheduled" }
        return "day \(earliestDay) to day \(conclusiveDay)"
    }
}

// MARK: - Infection profile

struct SWInfection: Identifiable, Equatable {
    let id: String
    let name: String
    let shortName: String
    let family: SWInfectionFamily
    /// Systemic entries are looked for in blood, so one specimen covers every site.
    let systemic: Bool
    /// For site-specific entries: the sites at which a local specimen is meaningful.
    let siteCoverage: [SWSpecimenSite]
    let assays: [SWAssay]
    /// Whether this entry produces window dates at all.
    let schedulable: Bool
    let defaultEnabled: Bool
    let colorIndex: Int
    /// Four to five sentences, plain language, no interpretation of any result.
    let explainer: String
    /// How published guidance describes it presenting — including how often it does not.
    let presentationNote: String
    let doxyRelevant: Bool
    let vaccinePreventable: Bool

    static func == (lhs: SWInfection, rhs: SWInfection) -> Bool { lhs.id == rhs.id }

    var primaryAssay: SWAssay { assays.first ?? SWAssay(id: "none", infectionID: id, name: "—", shortName: "—", technology: "—", earliestDay: 0, conclusiveDay: 0, scheduled: false, note: "") }

    /// Which specimen sites this entry needs, given the sites an exposure involved.
    func specimenSites(forExposedSites exposed: [SWSpecimenSite]) -> [SWSpecimenSite] {
        if systemic { return [.blood] }
        let exposedSet = Set(exposed)
        return siteCoverage
            .filter { exposedSet.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - The catalogue
//
// Twelve entries. Every interval below is presented in the interface as commonly
// cited published guidance, always paired with the reminder that windows vary by
// test and by laboratory and that the user's own service has the final word.

enum SWInfectionCatalog {

    static let all: [SWInfection] = [

        // 1 --------------------------------------------------------------- HIV
        SWInfection(
            id: "hiv",
            name: "HIV",
            shortName: "HIV",
            family: .viral,
            systemic: true,
            siteCoverage: [.blood],
            assays: [
                SWAssay(id: "hiv_agab", infectionID: "hiv",
                        name: "Fourth-generation antigen/antibody laboratory test",
                        shortName: "4th-gen Ag/Ab",
                        technology: "A laboratory immunoassay that looks for both the p24 antigen and antibodies, which is why it turns positive earlier than an antibody-only test.",
                        earliestDay: 18, conclusiveDay: 45, scheduled: true,
                        note: "Commonly cited as detecting from around day 18, with day 45 described as the point the window is closed for this technology."),
                SWAssay(id: "hiv_nat", infectionID: "hiv",
                        name: "Nucleic acid test (RNA)",
                        shortName: "NAT / RNA",
                        technology: "Looks for viral genetic material directly. It is the earliest of the three but is not offered routinely everywhere.",
                        earliestDay: 10, conclusiveDay: 33, scheduled: true,
                        note: "Commonly cited as detecting from around day 10, with day 33 described as conclusive."),
                SWAssay(id: "hiv_rapid", infectionID: "hiv",
                        name: "Rapid antibody or self-test",
                        shortName: "Rapid antibody",
                        technology: "A finger-prick or oral-fluid device that looks for antibodies only, so it turns positive later than a laboratory test.",
                        earliestDay: 23, conclusiveDay: 90, scheduled: true,
                        note: "Commonly cited as detecting from around day 23, with day 90 described as conclusive. This is the longest of the three windows and is the usual reason a self-test taken early is repeated.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 0,
            explainer: "HIV is looked for in blood, so a single sample covers every exposed site. Which window applies depends entirely on the technology the laboratory uses: a fourth-generation antigen/antibody test is commonly cited as conclusive at 45 days, a nucleic acid test at 33 days, and a rapid antibody or self-test at 90 days. That is a very wide spread, and it is the single most common reason people believe they have finished testing when the record says otherwise. You can set which technology this record assumes in Settings, and your clinic's own guidance takes precedence over anything shown here.",
            presentationNote: "Published guidance describes an early illness in some people a few weeks after exposure, and describes many others as having no noticeable illness at all. Because of that variability, testing at the right date is what published guidance relies on rather than symptoms.",
            doxyRelevant: false,
            vaccinePreventable: false
        ),

        // 2 -------------------------------------------------------- Chlamydia
        SWInfection(
            id: "chlamydia",
            name: "Chlamydia",
            shortName: "Chlamydia",
            family: .bacterial,
            systemic: false,
            siteCoverage: [.urogenital, .pharyngeal, .rectal],
            assays: [
                SWAssay(id: "ct_naat", infectionID: "chlamydia",
                        name: "Nucleic acid amplification test (NAAT)",
                        shortName: "NAAT",
                        technology: "Amplifies bacterial genetic material from the specimen. It is site-specific: it only reports on the site the specimen came from.",
                        earliestDay: 7, conclusiveDay: 14, scheduled: true,
                        note: "Commonly cited as detectable from around day 7, with day 14 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 1,
            explainer: "Chlamydia is looked for with a NAAT taken from the specific site that was exposed. A urine sample or genital swab reports only on the genital tract; it says nothing about the throat or the rectum. Published guidance describes pharyngeal and rectal infection as frequently present without symptoms, which is why three-site sampling is emphasized for anyone whose exposures involved those sites. The window is short compared with the blood-borne entries, so a NAAT date usually arrives well before the blood dates on this record.",
            presentationNote: "Commonly described as producing no symptoms in a large share of people. When symptoms are described they include discharge, discomfort on passing urine, or discomfort at the exposed site.",
            doxyRelevant: true,
            vaccinePreventable: false
        ),

        // 3 -------------------------------------------------------- Gonorrhea
        SWInfection(
            id: "gonorrhoea",
            name: "Gonorrhea",
            shortName: "Gonorrhea",
            family: .bacterial,
            systemic: false,
            siteCoverage: [.urogenital, .pharyngeal, .rectal],
            assays: [
                SWAssay(id: "ng_naat", infectionID: "gonorrhoea",
                        name: "Nucleic acid amplification test (NAAT)",
                        shortName: "NAAT",
                        technology: "Amplifies bacterial genetic material from the specimen and, like all NAATs, reports only on the site sampled. A culture is sometimes taken alongside it for susceptibility work.",
                        earliestDay: 7, conclusiveDay: 14, scheduled: true,
                        note: "Commonly cited as detectable from around day 7, with day 14 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 2,
            explainer: "Gonorrhea follows the same site logic as chlamydia and is usually run from the same specimens. Published guidance places particular emphasis on the pharyngeal site, which is described as commonly carrying the organism without symptoms and as being missed entirely when only urine is sent. Where an exposure involved the throat, this record will list a throat swab separately rather than folding it into the genital row. A culture is sometimes taken in addition to the NAAT so that susceptibility can be examined; that is a clinical decision and not something this record schedules.",
            presentationNote: "Published guidance describes genital infection as often producing discharge or discomfort, and pharyngeal and rectal infection as frequently producing nothing noticeable at all.",
            doxyRelevant: true,
            vaccinePreventable: false
        ),

        // 4 ---------------------------------------------------------- Syphilis
        SWInfection(
            id: "syphilis",
            name: "Syphilis",
            shortName: "Syphilis",
            family: .bacterial,
            systemic: true,
            siteCoverage: [.blood],
            assays: [
                SWAssay(id: "syph_trep", infectionID: "syphilis",
                        name: "Treponemal antibody test",
                        shortName: "Treponemal antibody",
                        technology: "A blood test looking for antibodies, usually paired with a second, non-treponemal test that is used to follow activity over time.",
                        earliestDay: 21, conclusiveDay: 90, scheduled: true,
                        note: "Commonly cited as detectable from around day 21, with day 90 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 3,
            explainer: "Syphilis serology is a blood test, so one sample covers every exposed site. The commonly cited window is wide — detectable from around three weeks, conclusive at around ninety days — because antibody responses vary a great deal between people. Published guidance describes an early painless sore that is easy to miss entirely, particularly at sites that are not easily seen. Because of that, testing at the scheduled date rather than waiting for something visible is what published guidance relies on. Two different blood tests are usually run together and interpreting them is work for your clinical service, not for this record.",
            presentationNote: "Commonly described as beginning with a single painless sore that heals on its own, and later as a rash that can appear on the palms and soles. Both stages are described as easy to overlook.",
            doxyRelevant: true,
            vaccinePreventable: false
        ),

        // 5 ------------------------------------------------------- Hepatitis B
        SWInfection(
            id: "hep_b",
            name: "Hepatitis B",
            shortName: "Hep B",
            family: .viral,
            systemic: true,
            siteCoverage: [.blood],
            assays: [
                SWAssay(id: "hbv_sag", infectionID: "hep_b",
                        name: "Surface antigen and core antibody panel",
                        shortName: "HBsAg / anti-HBc",
                        technology: "A blood panel looking for the surface antigen and for core antibodies. A third marker, surface antibody, is what a completed vaccination course is usually assessed against.",
                        earliestDay: 21, conclusiveDay: 60, scheduled: true,
                        note: "Commonly cited as detectable from around day 21, with day 60 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 4,
            explainer: "Hepatitis B is looked for in blood and is one of the two entries on this record that is also vaccine-preventable. If your vaccination record shows a completed course, published guidance describes the practical value of repeat testing as much lower, and you may prefer to switch this entry off in the schedule settings after discussing it with your clinical service. The panel usually reports several markers at once; distinguishing between them — past exposure, current infection, vaccine response — is interpretive work this record deliberately does not attempt. It records the dates and the values you were given, and nothing more.",
            presentationNote: "Published guidance describes many people as having no noticeable illness, and others as having tiredness, nausea or yellowing of the skin and eyes some weeks after exposure.",
            doxyRelevant: false,
            vaccinePreventable: true
        ),

        // 6 ------------------------------------------------------- Hepatitis C
        SWInfection(
            id: "hep_c",
            name: "Hepatitis C",
            shortName: "Hep C",
            family: .viral,
            systemic: true,
            siteCoverage: [.blood],
            assays: [
                SWAssay(id: "hcv_ab", infectionID: "hep_c",
                        name: "Antibody test (anti-HCV)",
                        shortName: "Antibody",
                        technology: "A blood test looking for antibodies. It carries by far the longest window on this record.",
                        earliestDay: 56, conclusiveDay: 180, scheduled: true,
                        note: "Commonly cited as detectable from around day 56, with day 180 described as conclusive."),
                SWAssay(id: "hcv_rna", infectionID: "hep_c",
                        name: "RNA test (HCV RNA)",
                        shortName: "RNA",
                        technology: "Looks for viral genetic material directly, so it closes much sooner than the antibody test. It is not offered routinely everywhere.",
                        earliestDay: 14, conclusiveDay: 60, scheduled: true,
                        note: "Commonly cited as detectable from around day 14, with day 60 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 5,
            explainer: "Hepatitis C has two very different windows depending on which test is run. The antibody test is commonly cited as conclusive only at around six months, while an RNA test is commonly cited as conclusive at around sixty days. That gap matters more here than for any other entry on this record, so the schedule shows which of the two it has assumed and you can change it in Settings. Whether an RNA test is available to you is a question for your clinical service.",
            presentationNote: "Published guidance describes most people as having no noticeable illness in the early period, which is the reason scheduled testing rather than symptom-watching is emphasized.",
            doxyRelevant: false,
            vaccinePreventable: false
        ),

        // 7 -------------------------------------------------- Herpes simplex
        SWInfection(
            id: "hsv",
            name: "Herpes simplex (HSV-1 and HSV-2)",
            shortName: "HSV",
            family: .viral,
            systemic: true,
            siteCoverage: [.blood, .lesion],
            assays: [
                SWAssay(id: "hsv_igg", infectionID: "hsv",
                        name: "Type-specific IgG antibody test",
                        shortName: "Type-specific IgG",
                        technology: "A blood test that reports whether antibodies to HSV-1 or HSV-2 are present. It cannot say where on the body an infection is, or when it was acquired.",
                        earliestDay: 84, conclusiveDay: 112, scheduled: true,
                        note: "Commonly cited as detectable from around day 84, with day 112 described as conclusive."),
                SWAssay(id: "hsv_pcr", infectionID: "hsv",
                        name: "PCR from an affected area",
                        shortName: "Lesion PCR",
                        technology: "Taken directly from an affected area while one is present. It is the test published guidance describes as most informative, and it is not run on a schedule.",
                        earliestDay: 0, conclusiveDay: 0, scheduled: false,
                        note: "Taken when an area is present rather than on a fixed date.")
            ],
            schedulable: true,
            defaultEnabled: false,
            colorIndex: 6,
            explainer: "Herpes is the entry most sexual health services do not include in a routine panel, and this record leaves it switched off by default for that reason rather than as an oversight. The blood test reports only whether antibodies are present; published guidance is explicit that it cannot say where an infection is on the body or when it was acquired, and that a very large share of the adult population carries HSV-1 antibodies from childhood. Where an affected area is present, published guidance describes a swab taken directly from it as far more informative than blood. If you switch this entry on, the schedule will include the antibody window, which is the longest of the site-independent windows on this record.",
            presentationNote: "Published guidance describes recurring areas of soreness or blistering in some people, and describes many others as never noticing anything.",
            doxyRelevant: false,
            vaccinePreventable: false
        ),

        // 8 --------------------------------------------------- Trichomoniasis
        SWInfection(
            id: "trichomoniasis",
            name: "Trichomoniasis",
            shortName: "Trichomoniasis",
            family: .parasitic,
            systemic: false,
            siteCoverage: [.urogenital],
            assays: [
                SWAssay(id: "tv_naat", infectionID: "trichomoniasis",
                        name: "Nucleic acid amplification test (NAAT)",
                        shortName: "NAAT",
                        technology: "A site-specific test on a urogenital specimen. Older microscopy methods are described in published guidance as far less sensitive.",
                        earliestDay: 5, conclusiveDay: 28, scheduled: true,
                        note: "Commonly cited as detectable from around day 5, with day 28 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: true,
            colorIndex: 7,
            explainer: "Trichomoniasis is a parasitic infection of the urogenital tract. It is not looked for at the throat or rectum, so this record only schedules it where an exposure involved the genital site. Published guidance describes it as commonly producing no symptoms, particularly in people with a urethra rather than a vaginal tract, and describes it as under-tested for that reason. It has the earliest detection day of any entry on this record but a comparatively long tail to the conclusive date.",
            presentationNote: "Commonly described as producing discharge, irritation or discomfort in some people and nothing noticeable in many others.",
            doxyRelevant: false,
            vaccinePreventable: false
        ),

        // 9 ------------------------------------------- Mycoplasma genitalium
        SWInfection(
            id: "mycoplasma",
            name: "Mycoplasma genitalium",
            shortName: "M. genitalium",
            family: .bacterial,
            systemic: false,
            siteCoverage: [.urogenital, .rectal],
            assays: [
                SWAssay(id: "mg_naat", infectionID: "mycoplasma",
                        name: "Nucleic acid amplification test (NAAT)",
                        shortName: "NAAT",
                        technology: "A site-specific test. Where it is available, published guidance often describes it being run together with a resistance marker.",
                        earliestDay: 14, conclusiveDay: 21, scheduled: true,
                        note: "Commonly cited as detectable from around day 14, with day 21 described as conclusive.")
            ],
            schedulable: true,
            defaultEnabled: false,
            colorIndex: 0,
            explainer: "Mycoplasma genitalium is a comparatively recent addition to sexual health testing and is not part of a routine panel in most services. Published guidance generally describes testing for it where symptoms are present, or where a previous course has not resolved something, rather than as part of an untargeted screen. This record leaves it switched off by default to match that, and you can switch it on in Settings if your service tests for it. It is site-specific and is not looked for at the throat.",
            presentationNote: "Published guidance describes it as a cause of persistent urethral or cervical irritation in some people, and as present without symptoms in many others.",
            doxyRelevant: false,
            vaccinePreventable: false
        ),

        // 10 ------------------------------------------------------ Hepatitis A
        SWInfection(
            id: "hep_a",
            name: "Hepatitis A",
            shortName: "Hep A",
            family: .viral,
            systemic: true,
            siteCoverage: [.blood],
            assays: [
                SWAssay(id: "hav_igm", infectionID: "hep_a",
                        name: "IgM antibody test",
                        shortName: "IgM antibody",
                        technology: "A blood test used when there is a reason to look, such as an illness or a known local outbreak, rather than on a routine schedule.",
                        earliestDay: 15, conclusiveDay: 50, scheduled: false,
                        note: "Published guidance describes this as a test used when there is a specific reason, not as part of a routine periodic panel.")
            ],
            schedulable: false,
            defaultEnabled: false,
            colorIndex: 1,
            explainer: "Hepatitis A is described in published guidance as passing by the fecal-oral route, which includes oral-anal contact, and outbreaks have been described in that context. It does not appear on the routine schedule because vaccination rather than periodic testing is what public health guidance emphasizes for it, and because testing is described as something done when there is a specific reason. The vaccination record in this app tracks the commonly cited two-dose course. If you have been told there is an outbreak locally, that is a conversation for your clinical service rather than something this record can schedule.",
            presentationNote: "Published guidance describes tiredness, nausea, abdominal discomfort and yellowing of the skin and eyes in many people, appearing some weeks after exposure.",
            doxyRelevant: false,
            vaccinePreventable: true
        ),

        // 11 ------------------------------------------------------------ Mpox
        SWInfection(
            id: "mpox",
            name: "Mpox",
            shortName: "Mpox",
            family: .viral,
            systemic: false,
            siteCoverage: [.lesion],
            assays: [
                SWAssay(id: "mpox_pcr", infectionID: "mpox",
                        name: "PCR from an affected area",
                        shortName: "Lesion PCR",
                        technology: "Taken directly from an affected area while one is present. There is no blood test used to close a window for it.",
                        earliestDay: 0, conclusiveDay: 0, scheduled: false,
                        note: "Taken when an area is present rather than on a fixed date.")
            ],
            schedulable: false,
            defaultEnabled: false,
            colorIndex: 2,
            explainer: "Mpox is included on this record for completeness rather than for scheduling. Published guidance describes the test as a swab taken directly from an affected area while one is present, so there is no window date to compute and nothing useful for a calendar to hold. What this record can do is track the commonly cited two-dose vaccination course, which appears in the vaccination section. Published guidance describes an illness that generally begins within about three weeks of exposure, and describes prompt assessment rather than waiting as the usual advice where something appears.",
            presentationNote: "Published guidance describes areas of skin change, sometimes with fever or swollen glands, generally beginning within about three weeks of exposure.",
            doxyRelevant: false,
            vaccinePreventable: true
        ),

        // 12 ------------------------------------------------------------- HPV
        SWInfection(
            id: "hpv",
            name: "Human papillomavirus (HPV)",
            shortName: "HPV",
            family: .viral,
            systemic: false,
            siteCoverage: [.urogenital],
            assays: [
                SWAssay(id: "hpv_screen", infectionID: "hpv",
                        name: "Cervical screening (where offered)",
                        shortName: "Screening",
                        technology: "Where a cervical screening program applies, HPV testing is part of it and runs on the program's own interval, which has nothing to do with any single exposure.",
                        earliestDay: 0, conclusiveDay: 0, scheduled: false,
                        note: "Runs on a screening program interval, not on an exposure window.")
            ],
            schedulable: false,
            defaultEnabled: false,
            colorIndex: 3,
            explainer: "HPV is described in published guidance as extremely common and as clearing on its own in most people without anything ever being noticed. There is no routine test offered to most people after a particular exposure, so there is no window date for this record to compute. Where a cervical screening program applies, HPV testing forms part of that program and runs on its own schedule. Vaccination is what public health guidance emphasizes, and the commonly cited three-dose adult course is tracked in the vaccination section of this app.",
            presentationNote: "Published guidance describes most infections as clearing without ever being noticed, and describes skin changes in a minority of people.",
            doxyRelevant: false,
            vaccinePreventable: true
        )
    ]

    static var defaultEnabledIDs: [String] {
        all.filter { $0.defaultEnabled }.map { $0.id }
    }

    static var schedulableIDs: [String] {
        all.filter { $0.schedulable }.map { $0.id }
    }

    static func infection(_ id: String) -> SWInfection? {
        all.first { $0.id == id }
    }

    static func name(_ id: String) -> String {
        infection(id)?.name ?? "Unknown entry"
    }

    static func shortName(_ id: String) -> String {
        infection(id)?.shortName ?? "Unknown"
    }

    static var allAssays: [SWAssay] {
        all.flatMap { $0.assays }
    }

    static func assay(_ id: String) -> SWAssay? {
        allAssays.first { $0.id == id }
    }

    /// The assay the schedule should assume for an infection, honouring the two
    /// user-selectable preferences.
    static func preferredAssay(for infection: SWInfection, preferences: SWPreferences) -> SWAssay? {
        switch infection.id {
        case "hiv":
            if let match = infection.assays.first(where: { $0.id == preferences.hivAssayPreference }) {
                return match
            }
        case "hep_c":
            if let match = infection.assays.first(where: { $0.id == preferences.hcvAssayPreference }) {
                return match
            }
        default:
            break
        }
        return infection.assays.first { $0.scheduled }
    }

    /// The number of distinct scheduled window rows in the published table.
    static var scheduledAssayCount: Int {
        allAssays.filter { $0.scheduled }.count
    }
}
