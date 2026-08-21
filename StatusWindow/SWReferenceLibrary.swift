import Foundation

// MARK: - Reference categories

enum SWReferenceCategory: String, CaseIterable, Identifiable {
    case windows
    case technology
    case entries
    case prevention
    case conversations
    case clinic
    case vaccines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windows:       return "Windows and timing"
        case .technology:    return "Tests and specimens"
        case .entries:       return "The twelve entries"
        case .prevention:    return "Prevention"
        case .conversations: return "Conversations"
        case .clinic:        return "Clinics and care"
        case .vaccines:      return "Vaccination"
        }
    }

    var shortTitle: String {
        switch self {
        case .windows:       return "Windows"
        case .technology:    return "Tests"
        case .entries:       return "Entries"
        case .prevention:    return "Prevention"
        case .conversations: return "Talking"
        case .clinic:        return "Clinics"
        case .vaccines:      return "Vaccines"
        }
    }

    var blurb: String {
        switch self {
        case .windows:
            return "Why a date matters more than a feeling, and how this record works out which dates to give you."
        case .technology:
            return "What the tests actually look for, and why the specimen a sample came from decides what it can report."
        case .entries:
            return "A short, plain description of each of the twelve entries this record tracks."
        case .prevention:
            return "The time-critical options, the ongoing ones, and what published guidance says about each."
        case .conversations:
            return "Wording you can borrow for the conversations that are hard to start."
        case .clinic:
            return "What an appointment involves, what to bring, and when published guidance describes waiting as the wrong move."
        case .vaccines:
            return "The commonly cited courses for the four vaccine-preventable entries on this record."
        }
    }

    var colorIndex: Int {
        switch self {
        case .windows:       return 0
        case .technology:    return 6
        case .entries:       return 1
        case .prevention:    return 3
        case .conversations: return 4
        case .clinic:        return 7
        case .vaccines:      return 5
        }
    }
}

// MARK: - Card

struct SWReferenceCard: Identifiable, Equatable {
    let id: String
    let category: SWReferenceCategory
    let title: String
    let summary: String
    let paragraphs: [String]
    let takeaway: String

    static func == (lhs: SWReferenceCard, rhs: SWReferenceCard) -> Bool { lhs.id == rhs.id }

    var searchBlob: String {
        ([title, summary, takeaway] + paragraphs).joined(separator: " ").lowercased()
    }
}

// MARK: - The library
//
// Everything below is written from commonly cited public health guidance and is
// deliberately general. None of it is a personal instruction, none of it
// interprets a result, and none of it substitutes for a conversation with a
// qualified clinician.

enum SWReferenceLibrary {

    static let disclaimerShort = "General information only. This app is not a medical device and does not provide medical advice."

    static let disclaimerLong = "Status Window is a personal record-keeping tool. It is not a medical device, it does not provide medical advice, and it cannot assess anyone's health. Every interval it uses is general published guidance and windows vary by test and by laboratory. Nothing shown here interprets a result or predicts one. For anything about your own health, speak to a qualified clinician or a sexual health service."

    static let windowCaveat = "Windows vary by test and by laboratory — your clinic's guidance takes precedence."

    static let cards: [SWReferenceCard] = [

        // ============================================ WINDOWS AND TIMING (8)

        SWReferenceCard(
            id: "win_what",
            category: .windows,
            title: "What a window period is",
            summary: "The gap between an exposure and the first date a test can report on it.",
            paragraphs: [
                "A window period is the interval between an exposure and the point at which a test is able to detect anything. It exists because tests do not look for the exposure itself; they look for something the body or the organism produces afterwards, and that takes time to reach a level the test can measure.",
                "Two dates matter, and they are not the same. The earliest day is when a test may begin to detect. The conclusive day is when published guidance describes the window as closed for that technology. Between those two dates a result is informative but does not settle anything.",
                "Different tests for the same entry can have very different windows. A laboratory HIV test and a rapid antibody self-test are both HIV tests, but the commonly cited conclusive figures are 45 days and 90 days respectively. That is why this record asks which technology to assume."
            ],
            takeaway: "A test result is only as meaningful as the date it was taken relative to the exposure."
        ),

        SWReferenceCard(
            id: "win_early",
            category: .windows,
            title: "Why testing early misleads",
            summary: "An early negative can feel like an answer while saying almost nothing.",
            paragraphs: [
                "The single most common pattern described in public health material is a person who has an exposure, feels anxious, tests within a few days, and receives a negative result. That result is accurate about what the test could see on that day, and it is not evidence that the window has closed.",
                "The problem is psychological rather than technical. A negative result on paper is enormously relieving, and once relief has arrived very few people go back for the second sample. The record then contains a test that reads as reassuring and covers nothing.",
                "This is exactly what this app exists to prevent. Nothing here says whether an early result was right or wrong. It simply shows the date after which that same specimen would have been conclusive, so that a repeat has a date on a calendar instead of a vague intention."
            ],
            takeaway: "An early test is not wasted, but it is not a closed window either. The second date is the one that closes it."
        ),

        SWReferenceCard(
            id: "win_one_date",
            category: .windows,
            title: "Why one date is rarely enough",
            summary: "The entries on a single panel close at very different times.",
            paragraphs: [
                "A panel taken on one day covers each entry only if the window for that entry has already closed. With commonly cited figures, a NAAT for chlamydia is described as conclusive at around 14 days while a hepatitis C antibody test is described as conclusive at around 180 days after the same exposure.",
                "That spread means a single visit almost never closes everything. What it usually closes is the short-window entries, leaving the blood-borne ones outstanding. A record that shows only 'tested in March' hides that difference completely.",
                "The Timeline in this app therefore groups by date rather than by entry. Each date tells you which entries it actually closes and which exposure it closes them for."
            ],
            takeaway: "One negative panel closes the entries whose windows had already passed, and nothing else."
        ),

        SWReferenceCard(
            id: "win_merge",
            category: .windows,
            title: "How this record merges dates",
            summary: "Every exposure generates rows; the rows are then collapsed into a few visits.",
            paragraphs: [
                "Internally, each logged exposure produces one row for every combination of entry and specimen site that applies to it. A single evening involving three sites and six entries can generate more than a dozen rows, and a list of a dozen dates is useless.",
                "The engine therefore clusters the conclusive dates. Any dates falling within a grouping tolerance of each other are merged into one visit, and that visit is placed on the latest date in the group so that every row inside it is genuinely past its own conclusive day.",
                "You can change the grouping tolerance in Settings. A wider tolerance means fewer visits, each slightly later. A narrower tolerance means earlier coverage of individual entries but more separate appointments."
            ],
            takeaway: "The Timeline shows visits, not rows. Each visit is placed where it closes everything it lists."
        ),

        SWReferenceCard(
            id: "win_day_zero",
            category: .windows,
            title: "Day zero is the exposure, not the test",
            summary: "Every interval on this record is counted from the exposure date.",
            paragraphs: [
                "All of the intervals used here are counted forward from the exposure, which is why the date you enter in the Log matters more than any other field in the app. An estimate is fine; published guidance works in weeks rather than hours for everything except the 72-hour flags.",
                "If you are unsure of a date, entering the later of two possibilities gives a later and therefore safer set of dates. If you enter a date and later remember it was earlier, editing the entry recalculates every downstream date automatically.",
                "The 72-hour flags are the one place where the time of day matters, so the Log records a time alongside the date."
            ],
            takeaway: "Get the exposure date roughly right and every other date on the record follows from it."
        ),

        SWReferenceCard(
            id: "win_repeat",
            category: .windows,
            title: "What a repeat test closes",
            summary: "A later sample closes the window for exposures that are old enough on that day.",
            paragraphs: [
                "When you record a test, this app compares the collection date against each outstanding row. A row is marked covered only when the sample was taken on or after that row's own conclusive date and the value recorded was a clear negative.",
                "That means one sample can close windows for several exposures at once, and can simultaneously leave a more recent exposure open. The Timeline shows both states rather than reducing them to a single verdict.",
                "A new exposure after a test does not undo the test. It opens its own set of rows with its own dates, which is why a person testing regularly still sees new dates appear."
            ],
            takeaway: "Coverage is per exposure and per entry, never a single overall state."
        ),

        SWReferenceCard(
            id: "win_overlap",
            category: .windows,
            title: "When exposures overlap",
            summary: "Regular activity produces a rolling schedule rather than a finish line.",
            paragraphs: [
                "If exposures happen regularly, the windows overlap continuously and there is never a moment when every row is closed. This is normal and is not a sign that anything is wrong; it is simply what a rolling schedule looks like.",
                "Public health material generally describes periodic screening at a fixed interval for people with ongoing activity, rather than trying to chase each individual date. Many services describe intervals of three, six or twelve months depending on circumstances.",
                "This record still shows per-exposure dates because they are what makes the logic visible, but a conversation with your service about a regular interval is usually the more practical arrangement."
            ],
            takeaway: "With ongoing activity, a regular interval agreed with a service tends to be more workable than chasing individual dates."
        ),

        SWReferenceCard(
            id: "win_conclusive",
            category: .windows,
            title: "What 'conclusive' means here",
            summary: "A commonly cited figure, not a guarantee and not a personal statement.",
            paragraphs: [
                "The conclusive day used for each entry is the figure most often cited in published guidance for that technology. It is a population-level figure describing when the great majority of results have settled, and it is presented here as general information.",
                "Laboratories differ. Some services use different cut-offs, some use different assays entirely, and some will recommend a repeat outside any published interval because of something specific to your circumstances. Any of those takes precedence over a number in an app.",
                "This app never states a likelihood, never estimates a probability, and never says whether anything is or is not present. It computes dates."
            ],
            takeaway: "Treat every figure here as general published guidance and let your service's advice override it."
        ),

        // =========================================== TESTS AND SPECIMENS (8)

        SWReferenceCard(
            id: "tech_naat",
            category: .technology,
            title: "What NAAT means",
            summary: "A test that amplifies genetic material from the sample you gave.",
            paragraphs: [
                "NAAT stands for nucleic acid amplification test. Instead of looking for the body's response to something, it copies any genetic material of the target organism present in the specimen until there is enough to detect. That is why its windows are shorter than antibody tests.",
                "The critical property of a NAAT is that it reports only on the specimen it was given. A NAAT run on urine reports on the urogenital tract. It has nothing to say about the throat or the rectum, because no material from those sites was in the tube.",
                "This is why the schedule in this app lists specimen sites separately rather than listing an entry once. The site is not a detail; it is the whole scope of the result."
            ],
            takeaway: "A NAAT answers a question about one site only — the site the sample came from."
        ),

        SWReferenceCard(
            id: "tech_ab_ag",
            category: .technology,
            title: "Antibody and antigen tests",
            summary: "One looks for the body's response, the other for the organism itself.",
            paragraphs: [
                "An antibody test looks for the immune response, which takes time to build. An antigen test looks for a component of the organism itself and generally turns positive earlier. A fourth-generation test looks for both at once, which is why its window is shorter than an antibody-only test for the same entry.",
                "Antibody tests also have a long tail: for some entries antibodies persist for life, so a positive antibody result does not by itself say whether something is currently present. Distinguishing those states is interpretive work for a clinical service and is not attempted anywhere in this app.",
                "When you record a result here, record what the report said and which test was used. The record is more useful later if it says 'fourth-generation laboratory test' than if it says 'HIV test'."
            ],
            takeaway: "Which technology was used changes the window, so it belongs in the record."
        ),

        SWReferenceCard(
            id: "tech_selftest",
            category: .technology,
            title: "What a self-test can and cannot close",
            summary: "Convenient and useful, with the longest commonly cited window of the three.",
            paragraphs: [
                "Self-tests and rapid tests are widely available and are described in public health material as a valuable way to reach people who would not otherwise test at all. They are real tests and their results matter.",
                "Their window is longer. For HIV, a rapid antibody or self-test is commonly cited as conclusive at around 90 days, compared with around 45 days for a fourth-generation laboratory test. A self-test at day 30 therefore does not close what a laboratory test at day 45 would have closed.",
                "If you are using self-tests, set the HIV assay preference in Settings accordingly so the dates on your Timeline match the technology you are actually using. Published guidance generally describes any reactive self-test result as needing confirmation through a service."
            ],
            takeaway: "Set the record to match the test you actually use, or the dates will be optimistic."
        ),

        SWReferenceCard(
            id: "tech_three_site",
            category: .technology,
            title: "Why three-site testing matters",
            summary: "The most frequently missed point in routine screening.",
            paragraphs: [
                "Published guidance repeatedly describes pharyngeal and rectal infections as common and as usually producing nothing noticeable. It also describes urine-only screening as missing them entirely, because the specimen never contained material from those sites.",
                "The practical consequence is that a person can screen regularly, always with a urine sample, and hold a long record of negative results that never examined two of the sites they were exposed at.",
                "This app derives specimen sites from the activity types you record, which is the only reason it asks about them. If an exposure involved the throat, the schedule lists a throat swab as its own line."
            ],
            takeaway: "Ask for swabs from every site involved. A urine sample is not a substitute for them."
        ),

        SWReferenceCard(
            id: "tech_throat",
            category: .technology,
            title: "Throat swabs",
            summary: "Quick, unremarkable, and the only specimen that covers the pharynx.",
            paragraphs: [
                "A pharyngeal swab is taken from the back of the throat and takes a few seconds. Some services will let you take it yourself. It is the only specimen that reports on that site.",
                "Published guidance describes pharyngeal gonorrhea in particular as frequently present without symptoms and as an important reservoir, which is why services that follow that guidance offer the swab routinely to anyone whose exposures involved the throat.",
                "If a service does not offer it and your record shows a throat exposure, published guidance supports asking. Saying 'my exposures included oral contact, could I have a throat swab as well' is enough."
            ],
            takeaway: "If the throat was involved, the throat needs its own swab."
        ),

        SWReferenceCard(
            id: "tech_rectal",
            category: .technology,
            title: "Rectal swabs",
            summary: "Often self-taken, and equally unsubstitutable.",
            paragraphs: [
                "A rectal swab is a short swab taken just inside the anus, and many services now offer it as a self-taken sample in a cubicle. Nobody needs to watch and it takes moments.",
                "As with the throat, published guidance describes rectal infection as commonly producing nothing noticeable, and describes urine samples as not covering it. Where an exposure involved receptive anal contact, this is the specimen that covers it.",
                "Some people find asking harder than doing. A neutral sentence works: 'I would like a rectal swab included, please.' Services that follow current guidance will not find the request unusual."
            ],
            takeaway: "Receptive anal exposure needs a rectal swab; nothing else reports on that site."
        ),

        SWReferenceCard(
            id: "tech_urine",
            category: .technology,
            title: "What a urine sample covers",
            summary: "The urogenital tract, and only that.",
            paragraphs: [
                "A first-catch urine sample is the standard urogenital specimen in many services and is well suited to it. Published guidance often describes holding urine for a period beforehand so the first part of the stream carries enough material.",
                "For people with a vaginal tract, a self-taken vaginal swab is often described as the preferred urogenital specimen rather than urine, because it is described as more sensitive. Either way, the scope is the same: the urogenital tract.",
                "The mistake is not using urine. The mistake is treating a urine result as a statement about the whole body."
            ],
            takeaway: "Urine covers the genital tract. It says nothing about the throat or the rectum."
        ),

        SWReferenceCard(
            id: "tech_indeterminate",
            category: .technology,
            title: "Indeterminate and pending results",
            summary: "Neither closes a window, and neither is interpreted here.",
            paragraphs: [
                "Sometimes a result comes back as indeterminate, equivocal or inconclusive. Published guidance generally describes this as a reason for a repeat sample or a different test, and the reasons vary considerably between entries and assays.",
                "This app records such a value factually and leaves the corresponding row open. It does not treat it as negative, it does not treat it as positive, and it offers no opinion about what it means.",
                "A pending result behaves the same way. The specimen is on record with its collection date, and the row stays open until a value is entered."
            ],
            takeaway: "Only a clear negative taken on or after the conclusive date closes a row here."
        ),

        // ============================================= THE TWELVE ENTRIES (11)

        SWReferenceCard(
            id: "ent_chlamydia",
            category: .entries,
            title: "Chlamydia",
            summary: "Bacterial, site-specific, short window, very commonly without symptoms.",
            paragraphs: [
                "Chlamydia is among the most frequently reported bacterial sexually transmitted infections in public health statistics. It is looked for with a site-specific NAAT, commonly cited as detectable from around day 7 and conclusive at around day 14.",
                "Published guidance describes a large share of infections as producing nothing noticeable, particularly at the throat and rectum. Where symptoms are described they include discharge, discomfort on passing urine, or discomfort at the exposed site.",
                "Because the window is short, chlamydia usually appears on the earliest visit in a schedule, well before any of the blood-borne entries."
            ],
            takeaway: "Short window, site-specific specimen, frequently silent."
        ),

        SWReferenceCard(
            id: "ent_gonorrhoea",
            category: .entries,
            title: "Gonorrhea",
            summary: "Bacterial, site-specific, and the strongest argument for a throat swab.",
            paragraphs: [
                "Gonorrhea follows the same testing pattern as chlamydia and is usually run from the same specimens with the same commonly cited window of around 7 to 14 days.",
                "Published guidance gives particular weight to the pharyngeal site for this entry, describing it as commonly carrying the organism without symptoms. Antimicrobial resistance is also a recurring theme in guidance, which is why some services take a culture alongside the NAAT.",
                "Genital infection is more often described as noticeable than pharyngeal or rectal infection, but 'more often' is not 'always', and published guidance does not describe symptoms as a reliable guide."
            ],
            takeaway: "Same window as chlamydia, and the entry that makes the throat swab worth asking for."
        ),

        SWReferenceCard(
            id: "ent_syphilis",
            category: .entries,
            title: "Syphilis",
            summary: "Blood test, wide window, and an early stage that is easy to miss.",
            paragraphs: [
                "Syphilis serology is a blood test, so a single sample covers every exposed site. The commonly cited window is wide — detectable from around day 21, conclusive at around day 90 — because antibody responses vary considerably.",
                "Published guidance describes an early stage consisting of a single painless sore that heals by itself, often at a site that is not easily seen, followed weeks later by a rash that can include the palms and soles. Both are described as easy to overlook.",
                "Two blood tests are usually run together, one treponemal and one non-treponemal. Reading them together is clinical work and this record does not attempt it; it stores what you were told."
            ],
            takeaway: "One blood sample covers every site, but the window runs to around ninety days."
        ),

        SWReferenceCard(
            id: "ent_hiv",
            category: .entries,
            title: "HIV",
            summary: "Three technologies, three very different windows.",
            paragraphs: [
                "HIV is looked for in blood. Which window applies depends entirely on the test: a fourth-generation antigen/antibody laboratory test is commonly cited as conclusive at 45 days, a nucleic acid test at 33 days, and a rapid antibody or self-test at 90 days.",
                "That spread is larger than for any other entry on this record except hepatitis C, and it is the reason this app asks which technology to assume rather than picking one silently.",
                "Published guidance also describes the two time-critical options — post-exposure and pre-exposure prophylaxis — both of which have their own cards in this library. Neither is something this app can advise on."
            ],
            takeaway: "Set the assay preference in Settings so the dates match the test you will actually take."
        ),

        SWReferenceCard(
            id: "ent_hepb",
            category: .entries,
            title: "Hepatitis B",
            summary: "Blood-borne, vaccine-preventable, multi-marker panel.",
            paragraphs: [
                "Hepatitis B is looked for in blood with a panel of markers, commonly cited as detectable from around day 21 and conclusive at around day 60.",
                "It is one of the four vaccine-preventable entries on this record. Where a completed course is recorded, published guidance describes the practical value of repeat testing as much lower, and a conversation with a service about immunity testing is the usual next step.",
                "The panel reports several markers whose combination distinguishes past exposure, current infection and vaccine response. That interpretation belongs with a clinician; this app stores the values and the dates."
            ],
            takeaway: "Vaccine-preventable, and worth checking your vaccination record before scheduling repeats."
        ),

        SWReferenceCard(
            id: "ent_hepc",
            category: .entries,
            title: "Hepatitis C",
            summary: "The widest window on the record, and it depends on the test.",
            paragraphs: [
                "Two very different windows apply. An antibody test is commonly cited as conclusive at around 180 days. An RNA test, which looks for viral genetic material directly, is commonly cited as conclusive at around 60 days.",
                "A six-month date is far enough out that people rarely keep track of it without a written record, which is one of the practical reasons this app exists. If an RNA test is available to you, the schedule shortens considerably.",
                "Published guidance describes most people as having no noticeable illness in the early period, so scheduled testing rather than symptom-watching is what it emphasizes."
            ],
            takeaway: "Antibody at around six months, RNA at around two — choose the assumption in Settings."
        ),

        SWReferenceCard(
            id: "ent_hsv",
            category: .entries,
            title: "Herpes simplex",
            summary: "Usually not part of a routine panel, and the blood test says less than people expect.",
            paragraphs: [
                "Most sexual health services do not include herpes serology in a routine screen, and this record leaves it switched off by default to match that rather than by oversight.",
                "The blood test reports whether type-specific antibodies are present. Published guidance is explicit that it cannot say where on the body an infection is or when it was acquired, and that a very large share of the adult population carries HSV-1 antibodies from childhood contact unrelated to sexual activity.",
                "Where an affected area is present, published guidance describes a swab taken directly from it as far more informative. That test is not run on a schedule, so it does not generate dates here."
            ],
            takeaway: "Off by default because most services do not screen for it; the swab beats the blood test when there is something to swab."
        ),

        SWReferenceCard(
            id: "ent_trich",
            category: .entries,
            title: "Trichomoniasis",
            summary: "Parasitic, urogenital only, and widely under-tested.",
            paragraphs: [
                "Trichomoniasis is a parasitic infection of the urogenital tract. It is not looked for at the throat or rectum, so this record schedules it only where an exposure involved the genital site.",
                "The commonly cited window is day 5 to day 28 — the earliest first-detection day of any entry here, with a comparatively long tail to the conclusive date.",
                "Published guidance describes it as commonly producing no symptoms, particularly in people with a urethra rather than a vaginal tract, and describes it as under-tested as a result."
            ],
            takeaway: "Genital specimen only, earliest detection day on the record, often missed."
        ),

        SWReferenceCard(
            id: "ent_mgen",
            category: .entries,
            title: "Mycoplasma genitalium",
            summary: "A newer entry, not part of a routine screen in most services.",
            paragraphs: [
                "Mycoplasma genitalium is a comparatively recent addition to sexual health testing. Published guidance generally describes testing where symptoms are present or where a previous course has not resolved something, rather than as part of an untargeted screen.",
                "This record leaves it switched off by default to match that, and you can switch it on in Settings if your service tests for it. The commonly cited window is day 14 to day 21.",
                "It is site-specific and is not looked for at the throat. Where it is available, guidance often describes it being run together with a resistance marker."
            ],
            takeaway: "Off by default; switch it on only if your service actually offers the test."
        ),

        SWReferenceCard(
            id: "ent_vaccine_three",
            category: .entries,
            title: "Hepatitis A, mpox and HPV",
            summary: "Tracked on this record, but not on the testing schedule.",
            paragraphs: [
                "Three entries appear in this library and in the vaccination record but never produce window dates, and that is deliberate rather than an omission.",
                "Hepatitis A is described as passing by the fecal-oral route including oral-anal contact, but published guidance emphasizes vaccination rather than periodic testing, and describes testing as something done when there is a specific reason such as an illness or a known outbreak. Mpox is tested by a swab taken from an affected area while one is present, so there is no window to compute. HPV has no routine test offered to most people after a particular exposure; where a cervical screening program applies, HPV testing runs on that program's own interval.",
                "For all three, what this record can usefully hold is the vaccination course, which it does."
            ],
            takeaway: "No window dates for these three — the vaccination record is where they live."
        ),

        SWReferenceCard(
            id: "ent_asymptomatic",
            category: .entries,
            title: "Most of this is silent",
            summary: "Waiting for something noticeable is not a testing strategy.",
            paragraphs: [
                "Across almost every entry on this record, published guidance describes a large share of infections as producing nothing a person would notice. That is stated for chlamydia, for gonorrhea at the throat and rectum, for trichomoniasis, for the early period of hepatitis C, and for many people with HIV.",
                "This has one practical consequence: feeling completely well carries very little information, and a schedule built on dates carries a great deal.",
                "The reverse also holds. Something noticeable is a reason to seek assessment promptly rather than waiting for a scheduled date, which is covered in the clinics section of this library."
            ],
            takeaway: "Absence of symptoms is not information. A date is."
        ),

        // ==================================================== PREVENTION (8)

        SWReferenceCard(
            id: "prev_pep",
            category: .prevention,
            title: "What post-exposure prophylaxis is",
            summary: "A time-critical option described in published guidance, started through a service.",
            paragraphs: [
                "Post-exposure prophylaxis, usually abbreviated to PEP, is a course of medication described in published guidance as being started after a possible HIV exposure. It is obtained through a sexual health service, an emergency department, or an equivalent urgent service depending on where you are.",
                "Published guidance describes it as time-critical: generally started as soon as possible and commonly cited as within 72 hours of the exposure, with earlier described as better. Whether it is appropriate in any individual situation is a clinical assessment.",
                "This app flags the 72-hour period when an exposure has been marked as higher-risk, and points to a service. It cannot assess anything and it does not recommend anything."
            ],
            takeaway: "If you think this may apply, contact a sexual health service or emergency service now rather than reading further."
        ),

        SWReferenceCard(
            id: "prev_72h",
            category: .prevention,
            title: "Where the 72-hour figure comes from",
            summary: "A commonly cited outer limit, not a target.",
            paragraphs: [
                "The 72-hour figure appears throughout published guidance as the outer limit within which post-exposure prophylaxis is generally considered. It is not a deadline to aim for; the same guidance consistently describes earlier as better, and often describes the first few hours as the most valuable.",
                "The countdown in this app exists because the figure is easy to lose track of at the exact moment it matters most — in the hours after an exposure, often at night, often while distracted.",
                "The countdown is information about a published interval. It is not an assessment of your situation, and the only thing it can usefully do is prompt a call to a service."
            ],
            takeaway: "Treat 72 hours as an outer edge. Published guidance describes sooner as better."
        ),

        SWReferenceCard(
            id: "prev_prep",
            category: .prevention,
            title: "What pre-exposure prophylaxis is",
            summary: "An ongoing option, started and monitored through a service.",
            paragraphs: [
                "Pre-exposure prophylaxis, usually abbreviated to PrEP, is medication taken before exposure rather than after. Public health guidance describes it as highly effective against HIV when taken as described, and describes it as having no effect on any other entry on this record.",
                "Starting it involves a clinical assessment including baseline testing, and continuing it involves periodic monitoring. Both are described in guidance as part of the arrangement rather than optional extras.",
                "This app can record whichever schedule you and your service have arranged. It does not recommend a schedule, cannot assess suitability, and has no way of knowing whether either is appropriate for you."
            ],
            takeaway: "PrEP covers HIV only. The other entries on this record still need their own dates."
        ),

        SWReferenceCard(
            id: "prev_daily",
            category: .prevention,
            title: "Daily schedules and onset",
            summary: "Published guidance describes protection as building over days, not immediately.",
            paragraphs: [
                "Where a daily schedule is used, published guidance commonly cites around 7 days of dosing before protection is described as established for receptive anal exposure, and around 20 days for vaginal and other exposure.",
                "The record in this app shows that interval as a countdown from the start date you enter, using whichever profile you select. It is a description of a published figure, not a statement about your own situation.",
                "The adherence strip exists because published guidance consistently ties effectiveness to consistent dosing. It records what you enter and computes a proportion; it makes no judgment about the result."
            ],
            takeaway: "The onset countdown is a published interval applied to your start date, nothing more."
        ),

        SWReferenceCard(
            id: "prev_211",
            category: .prevention,
            title: "The 2-1-1 on-demand schedule",
            summary: "A published dosing pattern: two, then one at 24 hours, then one at 48.",
            paragraphs: [
                "The on-demand schedule described in guidance published by the World Health Organization and by the US Centers for Disease Control and Prevention, usually written as 2-1-1, consists of two tablets taken between 2 and 24 hours before an anticipated exposure, one tablet 24 hours after that first dose, and one further tablet 24 hours after that. This card describes what those bodies have published; it is not a recommendation from this app.",
                "Guidance describes this schedule in specific contexts and not others, and describes suitability as a clinical decision that depends on the medication involved and on individual circumstances. It is not described as generally interchangeable with a daily schedule.",
                "The timeline in this app draws that published pattern against the time you enter for the first dose, so the two follow-up windows are visible rather than remembered. It is a timer for a published schedule, not a recommendation to follow one."
            ],
            takeaway: "Two before, one at 24 hours, one at 48 — and whether it applies to you is a clinical question."
        ),

        SWReferenceCard(
            id: "prev_doxy",
            category: .prevention,
            title: "What doxy-PEP is",
            summary: "A newer approach described in some guidelines, aimed at bacterial entries.",
            paragraphs: [
                "Guidance published by the US Centers for Disease Control and Prevention, and by the World Health Organization, describes a single dose of doxycycline taken after a possible exposure as reducing the likelihood of bacterial infections — chlamydia, syphilis and, less consistently, gonorrhea. The interval cited in that guidance is within 72 hours, and often within 24 hours. This card describes what those bodies have published; it is not a recommendation from this app.",
                "Guidance on it is more recent and more variable than for the other options in this section. Some services offer it to specific groups, some do not offer it at all, and antimicrobial resistance is a live consideration discussed throughout that guidance.",
                "This app raises a 72-hour flag so the interval is visible. Whether it is something to consider at all is a conversation with a clinician, and it has no effect on HIV or on any viral entry."
            ],
            takeaway: "Described in some guidelines, aimed at bacterial entries only, and specifically something to raise with a clinician."
        ),

        SWReferenceCard(
            id: "prev_barriers",
            category: .prevention,
            title: "Barrier methods",
            summary: "Recorded here as a fact about an exposure, never as a judgment.",
            paragraphs: [
                "Public health guidance describes external and internal condoms as substantially reducing the transmission of the entries that pass through fluids, and describes barriers for oral contact as reducing it further. It also describes them as offering less protection against entries that pass by skin contact, since a barrier covers only what it covers.",
                "The Log records barrier use per activity because it is a fact about the exposure that is useful later, not because the app has an opinion about it. Nothing in this app scores, ranks or comments on the answer.",
                "The per-partner summary shows a proportion for the same reason: it is a description of what you recorded."
            ],
            takeaway: "The record stores what happened. It does not grade it."
        ),

        SWReferenceCard(
            id: "prev_uu",
            category: .prevention,
            title: "Undetectable equals untransmittable",
            summary: "A widely stated public health position about HIV.",
            paragraphs: [
                "Public health bodies internationally state that a person with HIV who is on effective treatment and has a sustained undetectable viral load does not transmit HIV sexually. This position is usually summarized as undetectable equals untransmittable, or U=U.",
                "It is stated as a consensus position based on large studies, and it is relevant to how partner conversations are framed. A partner reporting that they are on treatment with an undetectable viral load is reporting something with a well-established public health meaning.",
                "As with everything reported by a partner, this record stores it as reported rather than verified, which is a statement about record-keeping and not about anybody's honesty."
            ],
            takeaway: "A widely stated consensus position; this record still labels anything a partner reports as reported."
        ),

        // ================================================= CONVERSATIONS (5)

        SWReferenceCard(
            id: "conv_notify",
            category: .conversations,
            title: "Partner notification",
            summary: "Services can do it for you, and usually anonymously.",
            paragraphs: [
                "If a result means previous partners should be told, sexual health services in most places offer to do the contacting themselves. This is usually described as partner notification or contact tracing, and it is generally done without naming the person who prompted it.",
                "That option exists precisely because the conversation is hard, and using it is entirely ordinary. Services describe it as routine work rather than a favor.",
                "The Partners tab in this app is a private aide-memoire for that conversation, not a contact list to be handed over. Nothing in it is transmitted anywhere."
            ],
            takeaway: "Ask the service to do the notifying. It is a standard offer and it is usually anonymous."
        ),

        SWReferenceCard(
            id: "conv_ask",
            category: .conversations,
            title: "Asking a partner about testing",
            summary: "A short script that keeps the tone practical.",
            paragraphs: [
                "The conversation goes better when it is framed as ordinary logistics rather than as an accusation. A version that works: 'I test regularly and I last tested in March. Where are you with that?'",
                "Stating your own position first turns it into an exchange of information rather than an interrogation, and it gives the other person a shape to answer in. If the answer is 'a while ago' or 'never', that is information rather than a verdict.",
                "If you want to name a preference, published guidance supports doing so plainly: 'I would rather we both tested first' is a complete sentence and needs no justification."
            ],
            takeaway: "Lead with your own last date. It makes the question an exchange rather than a demand."
        ),

        SWReferenceCard(
            id: "conv_reported",
            category: .conversations,
            title: "When a partner reports a status",
            summary: "Record it as reported, with the date you were told.",
            paragraphs: [
                "What a partner tells you is genuinely useful and is worth writing down, along with when they told you. A panel from eight months ago and a panel from last week are very different pieces of information, and the difference is easy to forget.",
                "This record labels everything in that field as reported rather than verified. That is a statement about what a record can know, not a suggestion that anyone is being untruthful.",
                "It also matters that a partner's own testing covers their exposures, not yours. Your dates come from your exposures, which is what the Timeline computes."
            ],
            takeaway: "Write down what you were told and when. Your own schedule is still your own."
        ),

        SWReferenceCard(
            id: "conv_positive",
            category: .conversations,
            title: "Talking about a positive result",
            summary: "Practical framing for a conversation nobody rehearses.",
            paragraphs: [
                "Most of the entries on this record are described in published guidance as straightforwardly manageable through a clinical service, and services are very used to these conversations. Starting with the practical fact usually works better than starting with an apology.",
                "A workable opening: 'I got a result back and wanted to tell you directly so you can get checked. The clinic can also contact people anonymously if that is easier.'",
                "If you would rather not have the conversation at all, the service's notification option exists for exactly that. Choosing it is not a lesser option."
            ],
            takeaway: "Lead with what the other person needs to do next, and mention that the service can do it instead."
        ),

        SWReferenceCard(
            id: "conv_boundaries",
            category: .conversations,
            title: "Saying no, and saying what you want",
            summary: "A complete sentence needs no justification.",
            paragraphs: [
                "Declining something, or asking for a barrier, or asking to wait until after a test, does not require an explanation, an apology or a negotiation. 'I would rather not' and 'I would rather we used something' are complete positions.",
                "Public health material consistently describes the ability to state a preference plainly as the single most practical prevention skill, ahead of any technical knowledge.",
                "This app has no view on what anybody chooses. It records dates."
            ],
            takeaway: "You do not owe anyone a reason. State the preference and leave it there."
        ),

        // ================================================ CLINICS AND CARE (5)

        SWReferenceCard(
            id: "clin_expect",
            category: .clinic,
            title: "What an appointment usually involves",
            summary: "Shorter and less eventful than most people expect.",
            paragraphs: [
                "A typical sexual health appointment involves a short set of questions about which sites were involved and when, so the right specimens are taken. Answering plainly is what gets the right swabs ordered, and services ask these questions of everyone.",
                "Specimens are commonly a urine sample or self-taken swab, swabs from any other sites involved, and a blood sample. Many services allow the throat and rectal swabs to be self-taken in a cubicle.",
                "Results usually follow within days, by text, by an online portal, or by a call. Many services contact you only if something needs discussing, so it is worth asking which convention they use."
            ],
            takeaway: "Answer the site questions plainly — that is what determines which swabs get taken."
        ),

        SWReferenceCard(
            id: "clin_bring",
            category: .clinic,
            title: "What to bring",
            summary: "Dates, sites and previous results.",
            paragraphs: [
                "The three things a service will find most useful are the dates of recent exposures, which sites were involved, and the date and content of your last panel. All three are in this record, and the status summary in the Health tab renders them as plain text you can copy.",
                "Bring anything you have from previous results, especially anything that names the test technology rather than just the entry.",
                "If you take medication of any kind, or have started a prophylaxis schedule, that belongs in the conversation too."
            ],
            takeaway: "Dates, sites, last panel. The status summary assembles all three for you."
        ),

        SWReferenceCard(
            id: "clin_now",
            category: .clinic,
            title: "When waiting is the wrong move",
            summary: "Some circumstances published guidance describes as prompt rather than scheduled.",
            paragraphs: [
                "This app schedules dates, but published guidance describes several circumstances as reasons to seek assessment promptly rather than waiting for any scheduled date: a possible higher-risk exposure within the last 72 hours, anything noticeable such as a sore, unusual discharge, unexplained rash, pain on passing urine, or fever after an exposure.",
                "A partner telling you about a result is also described as a reason to be assessed promptly rather than waiting, regardless of what any schedule says.",
                "None of that is a diagnosis and this app cannot make one. It is a list of circumstances in which published guidance describes contacting a service now."
            ],
            takeaway: "Anything noticeable, a partner's result, or a recent higher-risk exposure — contact a service rather than waiting for a date."
        ),

        SWReferenceCard(
            id: "clin_privacy",
            category: .clinic,
            title: "Privacy at a service",
            summary: "Confidentiality conventions are usually strong and worth asking about.",
            paragraphs: [
                "Sexual health services generally operate under specific confidentiality conventions, and in many places attendance is not shared with a general practitioner unless you ask for it to be. Conventions differ between countries and services, so it is a reasonable question to ask at the start.",
                "Many services offer results by a channel you choose. If a text message would be awkward, say so; alternatives are normally available.",
                "Some services offer testing without a name attached at all. If that matters to you, it is worth asking whether it is available where you are."
            ],
            takeaway: "Ask at the start how results will reach you and what is shared. Both are usually adjustable."
        ),

        SWReferenceCard(
            id: "clin_ownrecord",
            category: .clinic,
            title: "Keeping your own record",
            summary: "Services hold their own records; none of them holds all of yours.",
            paragraphs: [
                "If you have used more than one service, no single one of them has the whole picture. Your own record is the only place the dates line up, which is the practical case for keeping one at all.",
                "The most useful things to write down are the collection date, the service, the specific entries tested, the sites sampled, and the value for each. The site is the field most often omitted and the one most often needed later.",
                "Everything in this app stays on this device. There is no account, no sync, no analytics and no upload."
            ],
            takeaway: "Record the site alongside the entry. It is the field you will wish you had."
        ),

        // ==================================================== VACCINATION (5)

        SWReferenceCard(
            id: "vac_hpv",
            category: .vaccines,
            title: "HPV vaccination",
            summary: "Commonly cited as three doses over about six months for adults.",
            paragraphs: [
                "Public health guidance describes HPV vaccination as the main way to reduce the virus types most associated with later disease. Programs vary widely by country, by age and by eligibility.",
                "For people vaccinated as adults the commonly cited course is three doses: the second around two months after the first and the third around six months after the first. Younger programs often use fewer doses.",
                "There is no routine post-exposure test for most people, which is why HPV appears in this record as a vaccination course rather than as a testing schedule."
            ],
            takeaway: "Three doses over about six months for adults; eligibility varies a great deal by country."
        ),

        SWReferenceCard(
            id: "vac_hepatitis",
            category: .vaccines,
            title: "Hepatitis A and B vaccination",
            summary: "Two doses and three doses respectively, on commonly cited schedules.",
            paragraphs: [
                "Hepatitis A vaccination is commonly cited as two doses with the second around six months after the first. Hepatitis B is commonly cited as three doses, the second around one month after the first and the third around six months after the first.",
                "Accelerated schedules exist for both and are described in guidance for particular circumstances such as travel. Which schedule applies is a clinical decision.",
                "Combined preparations covering both are widely available. For hepatitis B, a completed course is often followed by a check of the response, which is a conversation for your service."
            ],
            takeaway: "Hep A: two doses. Hep B: three. Both are commonly offered together."
        ),

        SWReferenceCard(
            id: "vac_mpox",
            category: .vaccines,
            title: "Mpox vaccination",
            summary: "Commonly cited as two doses about 28 days apart.",
            paragraphs: [
                "Mpox vaccination is commonly cited as a two-dose course with the doses about 28 days apart. Eligibility criteria vary considerably between countries and have changed over time as outbreak situations changed.",
                "Public health guidance has also described vaccination after a known exposure in some circumstances, on a short timescale. Whether that applies is a matter for a service to assess.",
                "This record simply tracks the doses and the commonly cited interval between them."
            ],
            takeaway: "Two doses about four weeks apart; eligibility depends on where you are."
        ),

        SWReferenceCard(
            id: "vac_missed",
            category: .vaccines,
            title: "A missed or late dose",
            summary: "Published guidance generally describes continuing rather than restarting.",
            paragraphs: [
                "For the multi-dose courses tracked here, published guidance generally describes a delayed dose as a reason to continue the course from where it stopped rather than to begin it again. The precise handling depends on the vaccine and on how much time has passed.",
                "The dates this record shows for later doses are the commonly cited intervals measured from your first dose. They are a description of the published schedule, not an instruction, and a service may set different dates for good reasons.",
                "If a course has been interrupted, that is a straightforward question for a clinician and one they are asked constantly."
            ],
            takeaway: "Late usually means continue, not restart — but confirm the specifics with a service."
        ),

        SWReferenceCard(
            id: "vac_record",
            category: .vaccines,
            title: "Why the vaccination record sits here",
            summary: "Two of the entries on the testing schedule are vaccine-preventable.",
            paragraphs: [
                "Four entries on this record are vaccine-preventable: HPV, hepatitis A, hepatitis B and mpox. Two of them — hepatitis A and B — also appear as testable entries, and one of those, hepatitis B, sits on the routine schedule.",
                "That overlap is the reason the vaccination record lives alongside the testing record rather than in a separate app. A completed hepatitis B course is directly relevant to whether repeat testing for it is worth scheduling, and that is a question you can now answer from one screen.",
                "The schedule settings let you switch hepatitis B off once you have had that conversation with a service."
            ],
            takeaway: "Your vaccination history changes what is worth scheduling — which is why both live here."
        )
    ]

    // MARK: Lookup

    static func cards(in category: SWReferenceCategory) -> [SWReferenceCard] {
        cards.filter { $0.category == category }
    }

    static func card(_ id: String) -> SWReferenceCard? {
        cards.first { $0.id == id }
    }

    static func search(_ query: String) -> [SWReferenceCard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return cards }
        return cards.filter { $0.searchBlob.contains(trimmed) }
    }

    static var count: Int { cards.count }

    static func count(in category: SWReferenceCategory) -> Int {
        cards(in: category).count
    }
}
