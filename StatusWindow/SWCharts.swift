import SwiftUI

// MARK: - Window chart
//
// One bar per outstanding entry, running from the exposure date to the date the
// window is described as closing, with a marker on today crossing all of them.
// This is the drawing that makes a window period intuitive.

struct SWWindowChartRow: Identifiable, Equatable {
    let id: String
    let label: String
    let colorIndex: Int
    let exposureDate: Date
    let earliestDate: Date
    let conclusiveDate: Date
    let siteCount: Int
}

enum SWWindowChartBuilder {

    /// Collapses the engine's rows into at most `limit` bars, one per entry.
    static func rows(from openRows: [SWWindowRow], limit: Int = 8) -> [SWWindowChartRow] {
        var order: [String] = []
        var grouped: [String: [SWWindowRow]] = [:]
        for row in openRows {
            if grouped[row.infectionID] == nil {
                grouped[row.infectionID] = []
                order.append(row.infectionID)
            }
            grouped[row.infectionID]?.append(row)
        }

        var built: [SWWindowChartRow] = []
        for key in order {
            guard let group = grouped[key], let first = group.first else { continue }
            var minExposure = first.exposureDate
            var minEarliest = first.earliestDate
            var maxConclusive = first.conclusiveDate
            var siteSet = Set<SWSpecimenSite>()
            for row in group {
                if SWDay.key(row.exposureDate) < SWDay.key(minExposure) { minExposure = row.exposureDate }
                if SWDay.key(row.earliestDate) < SWDay.key(minEarliest) { minEarliest = row.earliestDate }
                if SWDay.key(row.conclusiveDate) > SWDay.key(maxConclusive) { maxConclusive = row.conclusiveDate }
                siteSet.insert(row.site)
            }
            let infection = SWInfectionCatalog.infection(key)
            built.append(SWWindowChartRow(id: key,
                                          label: infection?.shortName ?? key,
                                          colorIndex: infection?.colorIndex ?? 0,
                                          exposureDate: minExposure,
                                          earliestDate: minEarliest,
                                          conclusiveDate: maxConclusive,
                                          siteCount: siteSet.count))
        }

        built.sort { SWDay.key($0.conclusiveDate) < SWDay.key($1.conclusiveDate) }
        if built.count > limit { built = Array(built.prefix(limit)) }
        return built
    }
}

struct SWWindowChart: View {
    let rows: [SWWindowChartRow]
    /// The content width available to the chart. Every nested inset has already
    /// been subtracted by the caller.
    let width: CGFloat
    let dateStyle: SWDateStyle

    private let labelWidth: CGFloat = 74
    private let rowHeight: CGFloat = 26
    private let barHeight: CGFloat = 13

    private var barWidth: CGFloat { max(40, width - labelWidth - 6) }

    private var domain: (start: Date, end: Date) {
        let today = SWDay.today
        guard let firstExposure = rows.map({ $0.exposureDate })
            .min(by: { SWDay.key($0) < SWDay.key($1) }),
              let lastConclusive = rows.map({ $0.conclusiveDate })
            .max(by: { SWDay.key($0) < SWDay.key($1) }) else {
            return (SWDay.adding(days: -7, to: today), SWDay.adding(days: 30, to: today))
        }
        var start = firstExposure
        if SWDay.key(today) < SWDay.key(start) { start = today }
        var end = lastConclusive
        if SWDay.between(start, end) < 7 { end = SWDay.adding(days: 7, to: start) }
        if SWDay.key(today) > SWDay.key(end) { end = SWDay.adding(days: 3, to: today) }
        return (start, end)
    }

    private func fraction(_ date: Date) -> CGFloat {
        let bounds = domain
        let span = Double(SWDay.between(bounds.start, bounds.end))
        let offset = Double(SWDay.between(bounds.start, date))
        guard let ratio = SWMath.safeDivide(offset, span) else { return 0 }
        return CGFloat(SWMath.clamp(ratio, 0, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        chartRow(row)
                            .frame(height: rowHeight)
                    }
                }

                // Today marker, drawn once across every bar.
                if !rows.isEmpty {
                    Rectangle()
                        .fill(SWTheme.amber)
                        .frame(width: 2, height: CGFloat(rows.count) * rowHeight)
                        .offset(x: labelWidth + 6 + barWidth * fraction(SWDay.today) - 1, y: 0)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, alignment: .leading)

            axisLabels
        }
        .frame(width: width, alignment: .leading)
    }

    private func chartRow(_ row: SWWindowChartRow) -> some View {
        let color = SWTheme.chip(row.colorIndex)
        let startX = barWidth * fraction(row.exposureDate)
        let earlyX = barWidth * fraction(row.earliestDate)
        let endX = barWidth * fraction(row.conclusiveDate)
        let preWidth = max(0, earlyX - startX)
        let liveWidth = max(2, endX - earlyX)

        return HStack(spacing: 6) {
            Text(row.label)
                .font(SWFont.label(10))
                .foregroundColor(SWTheme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: labelWidth, alignment: .leading)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SWTheme.mist.opacity(0.7))
                    .frame(width: barWidth, height: barHeight)

                Capsule()
                    .fill(color.opacity(0.22))
                    .frame(width: preWidth, height: barHeight)
                    .offset(x: startX)

                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: liveWidth, height: barHeight)
                    .offset(x: earlyX)
            }
            .frame(width: barWidth, height: barHeight, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }

    private var axisLabels: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: labelWidth + 6)
            Text(SWFormat.short(domain.start, style: dateStyle))
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.inkFaint)
            Spacer(minLength: 4)
            Text("today")
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.amber)
            Spacer(minLength: 4)
            Text(SWFormat.short(domain.end, style: dateStyle))
                .font(SWFont.label(9))
                .foregroundColor(SWTheme.inkFaint)
        }
        .frame(width: width, alignment: .leading)
    }
}

// MARK: - Countdown ring

struct SWCountdownRing: View {
    /// 0 at the exposure, 1 at the deadline.
    let elapsed: Double
    let headline: String
    let caption: String
    var tint: Color = SWTheme.alert
    var size: CGFloat = 92

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(SWMath.clamp(1 - elapsed, 0, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(headline)
                    .font(.system(size: size * 0.20, weight: .semibold, design: .monospaced))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(caption)
                    .font(SWFont.label(9))
                    .foregroundColor(SWTheme.inkSoft)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Adherence strip
//
// Thirty cells, oldest on the left. Taken, missed and not-yet-started are all
// distinct states so an unstarted day never reads as a missed one.

struct SWAdherenceStrip: View {
    /// Newest last. `nil` means the day is outside the recorded schedule.
    let states: [Bool?]
    let width: CGFloat
    var cellHeight: CGFloat = 26

    private var columns: Int { max(1, states.count) }

    private var cellWidth: CGFloat {
        let spacing: CGFloat = 2
        let total = width - spacing * CGFloat(columns - 1)
        guard let each = SWMath.safeDivide(Double(total), Double(columns)) else { return 6 }
        return max(3, CGFloat(each))
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(states.enumerated()), id: \.offset) { pair in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: pair.element))
                    .frame(width: cellWidth, height: cellHeight)
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private func color(for state: Bool?) -> Color {
        guard let state = state else { return SWTheme.mist.opacity(0.6) }
        return state ? SWTheme.teal : SWTheme.amber.opacity(0.55)
    }
}

// MARK: - 2-1-1 dose timeline
//
// A drawing of the published on-demand schedule against the time the first dose
// was recorded. It is a timer for a described schedule, not a recommendation.

struct SWDoseTimeline: View {
    let sequence: SWOnDemandSequence
    let width: CGFloat
    let now: Date

    private var marks: [(title: String, detail: String, at: Date, taken: Bool)] {
        [
            ("2 tablets", "Loading dose", sequence.loadingDoseAt, sequence.loadingTaken),
            ("1 tablet", "24 hours after", sequence.secondDoseAt, sequence.secondTaken),
            ("1 tablet", "48 hours after", sequence.thirdDoseAt, sequence.thirdTaken)
        ]
    }

    private var trackWidth: CGFloat { max(60, width - 24) }

    private func offsetFor(_ index: Int) -> CGFloat {
        guard marks.count > 1 else { return 0 }
        guard let step = SWMath.safeDivide(Double(trackWidth), Double(marks.count - 1)) else { return 0 }
        return CGFloat(step) * CGFloat(index)
    }

    private var nowFraction: CGFloat {
        let span = sequence.thirdDoseAt.timeIntervalSince(sequence.loadingDoseAt)
        let done = now.timeIntervalSince(sequence.loadingDoseAt)
        guard let ratio = SWMath.safeDivide(done, span) else { return 0 }
        return CGFloat(SWMath.clamp(ratio, 0, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SWTheme.mist)
                    .frame(width: trackWidth, height: 5)
                Capsule()
                    .fill(SWTheme.teal.opacity(0.75))
                    .frame(width: trackWidth * nowFraction, height: 5)

                ForEach(Array(marks.enumerated()), id: \.offset) { pair in
                    Circle()
                        .fill(pair.element.taken ? SWTheme.teal : SWTheme.card)
                        .overlay(
                            Circle().stroke(pair.element.taken ? SWTheme.teal : SWTheme.inkFaint,
                                            lineWidth: 2)
                        )
                        .frame(width: 16, height: 16)
                        .offset(x: offsetFor(pair.offset) - 8)
                }
            }
            .frame(width: trackWidth, height: 18, alignment: .leading)
            .padding(.leading, 8)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(marks.enumerated()), id: \.offset) { pair in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pair.element.title)
                            .font(SWFont.label(10))
                            .foregroundColor(SWTheme.ink)
                        Text(SWFormat.clock(pair.element.at))
                            .font(SWFont.mono(10))
                            .foregroundColor(SWTheme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: pair.offset == 0 ? .leading : (pair.offset == marks.count - 1 ? .trailing : .center))
                }
            }
            .frame(width: width, alignment: .leading)

            // The pattern drawn above is a published dosing schedule, so the
            // guidance it comes from is named wherever it is shown.
            Text("The pattern shown here is the schedule described in guidance published by the World Health Organization and the US Centers for Disease Control and Prevention. This is a timer for that published schedule, not a recommendation to follow it.")
                .font(SWFont.bodyTight(10.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }
}

// MARK: - Coverage donut
//
// A compact summary of how many outstanding rows are covered. Purely a picture
// of the record's own completeness — it says nothing about anyone's health.

struct SWCoverageDial: View {
    let covered: Int
    let total: Int
    var size: CGFloat = 78

    private var fraction: Double {
        guard let value = SWMath.safeDivide(Double(covered), Double(total)) else { return 0 }
        return SWMath.clamp(value, 0, 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SWTheme.mist, lineWidth: 9)
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(SWTheme.teal, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(total > 0 ? "\(covered)/\(total)" : "—")
                    .font(.system(size: size * 0.21, weight: .semibold, design: .monospaced))
                    .foregroundColor(SWTheme.ink)
                Text("covered")
                    .font(SWFont.label(8))
                    .foregroundColor(SWTheme.inkFaint)
            }
        }
        .frame(width: size, height: size)
    }
}
