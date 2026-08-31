import SwiftUI

// MARK: - Prophylaxis record

struct SWPrEPView: View {
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var now = Date()
    @State private var showAddSequence = false
    @State private var newSequenceAt = Date()
    @State private var showModeInfo = false

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var style: SWDateStyle { store.preferences.dateStyle }

    private var contentWidth: CGFloat {
        // Page padding (16 × 2) plus card padding (14 × 2), subtracted from the
        // column the cards are actually laid out in rather than from the screen.
        max(180, SWMetrics.contentWidth(for: hSize) - 60)
    }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: "Prophylaxis record",
                               subtitle: "A record of a schedule you and a service have arranged",
                               onBack: { presentationMode.wrappedValue.dismiss() })
            } content: {
                framingCard
                modeCard

                switch store.prep.mode {
                case .none:
                    notRecordedCard
                case .daily:
                    dailyOnsetCard
                    adherenceCard
                    dayListCard
                case .onDemand:
                    onDemandCard
                    sequenceList
                }

                referenceLinks
                SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
            }

            if showAddSequence {
                addSequenceOverlay
            }

            if showModeInfo {
                SWInfoOverlay(title: "What this section is",
                              paragraphs: [
                                "This is a record of a schedule, not a recommendation of one. The app cannot assess whether any form of prophylaxis is appropriate for anyone; that is a clinical assessment involving baseline testing and periodic monitoring.",
                                "Published guidance describes pre-exposure prophylaxis as highly effective against HIV when taken as described, and describes it as having no effect on any other entry on this record. The dates for those entries still apply.",
                                "The intervals and the dosing pattern drawn here are descriptions of commonly cited published schedules. Your service's instructions take precedence over anything shown in this app."
                              ],
                              onClose: { showModeInfo = false })
            }
        }
        .onReceive(ticker) { value in now = value }
    }

    // MARK: Framing

    private var framingCard: some View {
        SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
            Text("This section records a schedule you have arranged with a clinical service. It does not recommend one, cannot assess suitability, and has no way of knowing whether any option is appropriate for you.")
                .font(SWFont.bodyTight(12.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: { showModeInfo = true }) {
                HStack(spacing: 6) {
                    SWIcon(glyph: .info, size: 13, color: SWTheme.teal, lineWidth: 1.4)
                    Text("More on this")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var modeCard: some View {
        SWCard {
            SWFieldLabel(text: "Schedule recorded")
            SWSegmented(options: SWPrEPMode.allCases,
                        titleFor: { mode in
                            switch mode {
                            case .none:     return "None"
                            case .daily:    return "Daily"
                            case .onDemand: return "2-1-1"
                            }
                        },
                        selection: Binding(
                            get: { store.prep.mode },
                            set: { store.setPrEPMode($0) }
                        ))
            Text(store.prep.mode.title)
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.inkFaint)
        }
    }

    private var notRecordedCard: some View {
        SWCard {
            SWEmptyState(glyph: .shield,
                         title: "No schedule recorded",
                         message: "If you and a clinical service have arranged a daily or an on-demand schedule, selecting it above lets this record track the dates and the doses. Nothing here is a suggestion to start one.")
        }
    }

    // MARK: Daily

    private var dailyOnsetCard: some View {
        SWCard {
            SWSectionHeader(title: "Daily schedule")
            SWDateField(title: "Start date",
                        date: Binding(
                            get: { store.prep.dailyStartDate ?? SWDay.today },
                            set: { store.setDailyStart($0) }
                        ),
                        range: SWDay.adding(days: -3650, to: SWDay.today)...SWDay.today)

            SWFieldLabel(text: "Onset profile",
                         caption: "Published guidance cites different intervals for different exposure types.")
            SWSegmented(options: SWOnsetProfile.allCases,
                        titleFor: { $0.title },
                        selection: Binding(
                            get: { store.prep.onsetProfile },
                            set: { store.setOnsetProfile($0) }
                        ),
                        compact: true)

            Rectangle().fill(SWTheme.hairline).frame(height: 1)

            if let onset = store.protectionOnsetDate {
                let daysLeft = SWDay.between(SWDay.today, onset)
                HStack(alignment: .top, spacing: 12) {
                    SWCountdownRing(elapsed: onsetElapsed(onset),
                                    headline: daysLeft > 0 ? "\(daysLeft)d" : "—",
                                    caption: daysLeft > 0 ? "to go" : "reached",
                                    tint: daysLeft > 0 ? SWTheme.amber : SWTheme.teal,
                                    size: 80)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(daysLeft > 0
                             ? "Published guidance cites \(SWFormat.dayCount(store.prep.onsetProfile.days)) of daily dosing before protection is described as established for this exposure type."
                             : "The interval commonly cited for this exposure type has passed, counted from the start date recorded above.")
                            .font(SWFont.bodyTight(12.5))
                            .foregroundColor(SWTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(store.prep.onsetProfile.citation)
                            .font(SWFont.label(10))
                            .foregroundColor(SWTheme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Reaches \(SWFormat.long(onset, style: style)).")
                            .font(SWFont.mono(11))
                            .foregroundColor(SWTheme.teal)
                    }
                }
            }
            SWDisclaimerLine(text: "A description of a published interval applied to a date you entered. It is not a statement about your own situation.")
        }
    }

    private func onsetElapsed(_ onset: Date) -> Double {
        guard let start = store.prep.dailyStartDate else { return 0 }
        let span = Double(SWDay.between(start, onset))
        let done = Double(SWDay.between(start, SWDay.today))
        guard let ratio = SWMath.safeDivide(done, span) else { return 1 }
        return SWMath.clamp(ratio, 0, 1)
    }

    private var adherenceCard: some View {
        let window = store.adherence(days: 30)
        let states = last30States
        return SWCard {
            SWSectionHeader(title: "Last 30 days",
                            trailingText: SWFormat.percentString(SWMath.percent(window.taken, of: window.total)))
            SWAdherenceStrip(states: states, width: contentWidth)
            HStack(spacing: 14) {
                legendDot(SWTheme.teal, "taken")
                legendDot(SWTheme.amber.opacity(0.55), "not recorded as taken")
                legendDot(SWTheme.mist.opacity(0.6), "before the start date")
            }
            HStack(spacing: 0) {
                statColumn("\(window.taken)", "taken")
                statColumn("\(window.missed)", "not marked")
                statColumn("\(window.total)", "days in range")
            }
            Rectangle().fill(SWTheme.hairline).frame(height: 1)
            SWKeyValueRow(key: "Current week began",
                          value: SWFormat.medium(SWDay.startOfWeek(SWDay.today), style: style))
            SWKeyValueRow(key: "Marked taken this week",
                          value: "\(weekTaken) of \(weekElapsed)")
            Text("Published guidance consistently ties effectiveness to consistent dosing. This strip records what you enter and computes a proportion; it makes no judgment about the result.")
                .font(SWFont.bodyTight(11))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Doses marked taken since the start of the current week, using the week-start
    /// preference set in Settings.
    private var weekTaken: Int {
        let weekStart = SWDay.startOfWeek(SWDay.today)
        var count = 0
        for offset in 0...max(0, SWDay.between(weekStart, SWDay.today)) {
            let day = SWDay.adding(days: offset, to: weekStart)
            if store.doseState(for: day) == true { count += 1 }
        }
        return count
    }

    private var weekElapsed: Int {
        max(1, SWDay.between(SWDay.startOfWeek(SWDay.today), SWDay.today) + 1)
    }

    private var last30States: [Bool?] {
        var result: [Bool?] = []
        let start = store.prep.dailyStartDate
        for offset in stride(from: 29, through: 0, by: -1) {
            let day = SWDay.adding(days: -offset, to: SWDay.today)
            if let start = start, SWDay.key(day) < SWDay.key(start) {
                result.append(nil)
                continue
            }
            if let state = store.doseState(for: day) {
                result.append(state)
            } else {
                result.append(false)
            }
        }
        return result
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func statColumn(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SWFont.monoLarge(19))
                .foregroundColor(SWTheme.ink)
            Text(label)
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var dayListCard: some View {
        SWCard {
            SWSectionHeader(title: "Mark the last fourteen days",
                            subtitle: "Tap a day to cycle between taken, missed and not recorded.")
            ForEach(0..<14, id: \.self) { offset in
                let day = SWDay.adding(days: -offset, to: SWDay.today)
                dayRow(day)
                if offset < 13 {
                    Rectangle().fill(SWTheme.hairline).frame(height: 1)
                }
            }
        }
    }

    private func dayRow(_ day: Date) -> some View {
        let state = store.doseState(for: day)
        let beforeStart: Bool = {
            guard let start = store.prep.dailyStartDate else { return false }
            return SWDay.key(day) < SWDay.key(start)
        }()

        return Button(action: {
            guard !beforeStart else { return }
            store.toggleDose(for: day)
        }) {
            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(SWFormat.medium(day, style: style))
                        .font(SWFont.heading(13))
                        .foregroundColor(beforeStart ? SWTheme.inkFaint : SWTheme.ink)
                    Text(SWFormat.weekdayName(day))
                        .font(SWFont.label(10))
                        .foregroundColor(SWTheme.inkFaint)
                }
                Spacer(minLength: 6)
                if beforeStart {
                    Text("Before start")
                        .font(SWFont.label(10))
                        .foregroundColor(SWTheme.inkFaint)
                } else {
                    SWPill(text: stateLabel(state), color: stateColor(state), filled: state == true)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func stateLabel(_ state: Bool?) -> String {
        guard let state = state else { return "Not recorded" }
        return state ? "Taken" : "Missed"
    }

    private func stateColor(_ state: Bool?) -> Color {
        guard let state = state else { return SWTheme.inkFaint }
        return state ? SWTheme.teal : SWTheme.amber
    }

    // MARK: On-demand

    private var onDemandCard: some View {
        SWCard {
            SWSectionHeader(title: "The 2-1-1 schedule",
                            subtitle: "A description of the dosing pattern published by the WHO and the CDC.")
            VStack(alignment: .leading, spacing: 7) {
                patternRow("2 tablets", "between 2 and 24 hours before an anticipated exposure")
                patternRow("1 tablet", "24 hours after the first dose")
                patternRow("1 tablet", "24 hours after that, so 48 hours after the first dose")
            }
            Text("The pattern above is reproduced from guidance published by the World Health Organization and the US Centers for Disease Control and Prevention. It is a description of a published schedule, not a recommendation from this app.")
                .font(SWFont.bodyTight(12))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text("That guidance describes this schedule in specific contexts and not in others, and describes suitability as a clinical decision that depends on the medication involved and on individual circumstances.")
                .font(SWFont.bodyTight(12))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            SWPrimaryButton(title: "Start a new sequence", glyph: .plus) {
                newSequenceAt = Date()
                showAddSequence = true
            }
        }
    }

    private func patternRow(_ dose: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(dose)
                .font(SWFont.mono(12))
                .foregroundColor(SWTheme.teal)
                .frame(width: 66, alignment: .leading)
            Text(detail)
                .font(SWFont.bodyTight(12.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var sequenceList: some View {
        if store.prep.sequences.isEmpty {
            SWCard {
                Text("No sequence recorded yet.")
                    .font(SWFont.body(13))
                    .foregroundColor(SWTheme.inkSoft)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SWSectionHeader(title: "Recorded sequences",
                                trailingText: "\(store.prep.sequences.count)")
                ForEach(store.prep.sequences) { sequence in
                    sequenceCard(sequence)
                }
            }
        }
    }

    private func sequenceCard(_ sequence: SWOnDemandSequence) -> some View {
        let isActive = !sequence.isComplete && sequence.thirdDoseAt.addingTimeInterval(24 * 3600) > now
        return SWCard(background: isActive ? SWTheme.tealSoft.opacity(0.45) : SWTheme.card,
                      borderColor: isActive ? SWTheme.teal.opacity(0.3) : SWTheme.cardEdge) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SWFormat.long(sequence.loadingDoseAt, style: style))
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                    Text("First dose at \(SWFormat.clock(sequence.loadingDoseAt))")
                        .font(SWFont.mono(11))
                        .foregroundColor(SWTheme.inkSoft)
                }
                Spacer(minLength: 6)
                SWPill(text: sequence.isComplete ? "Complete" : (isActive ? "In progress" : "Incomplete"),
                       color: sequence.isComplete ? SWTheme.teal : (isActive ? SWTheme.amber : SWTheme.inkFaint))
            }

            SWDoseTimeline(sequence: sequence, width: contentWidth, now: now)

            VStack(spacing: 6) {
                doseToggle(sequence, index: 0)
                doseToggle(sequence, index: 1)
                doseToggle(sequence, index: 2)
            }

            if let nextLabel = nextDoseLabel(sequence) {
                Text(nextLabel)
                    .font(SWFont.bodyTight(12))
                    .foregroundColor(SWTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: { store.deleteSequence(sequence.id) }) {
                HStack(spacing: 6) {
                    SWIcon(glyph: .trash, size: 13, color: SWTheme.alert, lineWidth: 1.4)
                    Text("Remove sequence")
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.alert)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func doseToggle(_ sequence: SWOnDemandSequence, index: Int) -> some View {
        let titles = ["2 tablets — loading dose", "1 tablet — 24 hours after", "1 tablet — 48 hours after"]
        let times = [sequence.loadingDoseAt, sequence.secondDoseAt, sequence.thirdDoseAt]
        let taken = [sequence.loadingTaken, sequence.secondTaken, sequence.thirdTaken]
        let safeIndex = SWMath.clampInt(index, 0, 2)

        return SWCheckRow(title: titles[safeIndex],
                          caption: "\(SWFormat.medium(times[safeIndex], style: style)) at \(SWFormat.clock(times[safeIndex]))",
                          isOn: taken[safeIndex]) {
            var updated = sequence
            switch safeIndex {
            case 0: updated.loadingTaken.toggle()
            case 1: updated.secondTaken.toggle()
            default: updated.thirdTaken.toggle()
            }
            store.updateSequence(updated)
        }
    }

    private func nextDoseLabel(_ sequence: SWOnDemandSequence) -> String? {
        guard !sequence.isComplete else { return nil }
        if !sequence.loadingTaken {
            return "The loading dose has not been marked as taken."
        }
        if !sequence.secondTaken {
            let remaining = sequence.secondDoseAt.timeIntervalSince(now)
            if remaining > 0 {
                return "Next dose window opens in \(SWFormat.countdown(remaining)), at \(SWFormat.clock(sequence.secondDoseAt))."
            }
            return "The 24-hour dose time has passed."
        }
        if !sequence.thirdTaken {
            let remaining = sequence.thirdDoseAt.timeIntervalSince(now)
            if remaining > 0 {
                return "Final dose window opens in \(SWFormat.countdown(remaining)), at \(SWFormat.clock(sequence.thirdDoseAt))."
            }
            return "The 48-hour dose time has passed."
        }
        return nil
    }

    private var addSequenceOverlay: some View {
        ZStack {
            Color.black.opacity(0.34)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { showAddSequence = false }

            VStack(alignment: .leading, spacing: 12) {
                Text("Record the first dose")
                    .font(SWFont.title(17))
                    .foregroundColor(SWTheme.ink)
                Text("The two follow-up doses are drawn at 24 and 48 hours after the time you set here.")
                    .font(SWFont.body(13))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                SWDateField(title: "First dose", date: $newSequenceAt, includeTime: true)
                SWPrimaryButton(title: "Add sequence", glyph: .check) {
                    store.addSequence(SWOnDemandSequence(loadingDoseAt: newSequenceAt, loadingTaken: true))
                    showAddSequence = false
                }
                SWSecondaryButton(title: "Cancel", tint: SWTheme.inkSoft) {
                    showAddSequence = false
                }
            }
            .padding(18)
            .frame(maxWidth: min(340, SWMetrics.screenWidth - 48))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SWTheme.card)
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: Reference

    private var referenceLinks: some View {
        SWCard {
            SWSectionHeader(title: "Related reference cards")
            ForEach(["prev_prep", "prev_daily", "prev_211", "prev_pep", "prev_doxy"], id: \.self) { cardID in
                if let card = SWReferenceLibrary.card(cardID) {
                    NavigationLink(destination: SWReferenceCardView(card: card)) {
                        HStack(spacing: 9) {
                            SWIcon(glyph: .book, size: 15, color: SWTheme.teal, lineWidth: 1.4)
                            Text(card.title)
                                .font(SWFont.bodyTight(13))
                                .foregroundColor(SWTheme.ink)
                            Spacer(minLength: 0)
                            SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.inkFaint)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}
