import SwiftUI

// MARK: - Vaccination record

struct SWVaccinationView: View {
    @ObservedObject var store: SWStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var addingKind: SWVaccineKind? = nil
    @State private var newDoseDate: Date = SWDay.today

    private var style: SWDateStyle { store.preferences.dateStyle }

    var body: some View {
        ZStack {
            SWScreen {
                SWScreenHeader(title: "Vaccination record",
                               subtitle: "Four vaccine-preventable entries",
                               onBack: { presentationMode.wrappedValue.dismiss() })
            } content: {
                introCard
                ForEach(SWVaccineKind.allCases) { kind in
                    vaccineCard(kind)
                }
                SWCard(background: SWTheme.mist.opacity(0.4), borderColor: SWTheme.hairline) {
                    SWSectionHeader(title: "Why this sits alongside the testing record")
                    Text("Hepatitis B is both vaccine-preventable and testable, and it sits on the routine schedule. If your record shows a completed course, that is directly relevant to whether repeat testing is worth scheduling — a conversation for your service, after which you can switch the entry off in Settings.")
                        .font(SWFont.bodyTight(12.5))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    NavigationLink(destination: SWReferenceCardView(card: SWReferenceLibrary.card("vac_record"))) {
                        HStack(spacing: 6) {
                            Text("Reference card")
                                .font(SWFont.label(11))
                                .foregroundColor(SWTheme.teal)
                            SWIcon(glyph: .chevronRight, size: 13, color: SWTheme.teal)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                SWDisclaimerLine(text: SWReferenceLibrary.disclaimerShort)
            }

            if let kind = addingKind {
                addDoseOverlay(kind)
            }
        }
    }

    private var introCard: some View {
        SWCard {
            SWSectionHeader(title: "Courses tracked")
            Text("Each course below uses the interval most commonly cited in published guidance, measured from your first recorded dose. Programs, eligibility and accelerated schedules vary considerably between countries, and your service's dates take precedence over these.")
                .font(SWFont.bodyTight(12.5))
                .foregroundColor(SWTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 0) {
                ForEach(SWVaccineKind.allCases) { kind in
                    VStack(spacing: 3) {
                        Text("\(store.vaccine(kind).recordedDoses)/\(kind.doseCount)")
                            .font(SWFont.mono(13))
                            .foregroundColor(store.vaccine(kind).isComplete ? SWTheme.teal : SWTheme.ink)
                        Text(kind.title)
                            .font(SWFont.label(9))
                            .foregroundColor(SWTheme.inkFaint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func vaccineCard(_ kind: SWVaccineKind) -> some View {
        let record = store.vaccine(kind)
        return SWCard {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle()
                        .fill(record.isComplete ? SWTheme.tealSoft : SWTheme.mist.opacity(0.7))
                        .frame(width: 36, height: 36)
                    SWIcon(glyph: .syringe, size: 17,
                           color: record.isComplete ? SWTheme.teal : SWTheme.inkSoft,
                           lineWidth: 1.5)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(SWFont.title(16))
                        .foregroundColor(SWTheme.ink)
                    Text(kind.scheduleSummary)
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            doseTrack(kind: kind, record: record)

            if record.doses.isEmpty {
                Text("No doses recorded.")
                    .font(SWFont.bodyTight(12))
                    .foregroundColor(SWTheme.inkFaint)
            } else {
                ForEach(record.doses.sorted { $0.index < $1.index }) { dose in
                    SWKeyValueRow(key: "Dose \(dose.index + 1)",
                                  value: SWFormat.medium(dose.date, style: style))
                }
            }

            if let next = record.nextDoseDueDate {
                let delta = SWDay.between(SWDay.today, next)
                SWNoticeCard(glyph: .calendar,
                             title: "Next dose commonly cited around \(SWFormat.medium(next, style: style))",
                             message: delta >= 0
                                ? "That is \(SWFormat.relativeDay(next)), counted from your first recorded dose. A service may set a different date for good reasons."
                                : "That date has passed. Published guidance generally describes a delayed dose as a reason to continue the course rather than restart it — confirm the specifics with a service.",
                             tint: delta >= 0 ? SWTheme.teal : SWTheme.amber,
                             background: delta >= 0 ? SWTheme.tealSoft.opacity(0.5) : SWTheme.amberSoft)
            } else if record.isComplete {
                SWNoticeCard(glyph: .check,
                             title: "Course recorded as complete",
                             message: "All \(kind.doseCount) doses commonly cited for this course are on the record.",
                             tint: SWTheme.teal,
                             background: SWTheme.tealSoft.opacity(0.5))
            }

            Text(kind.relevanceNote)
                .font(SWFont.bodyTight(11.5))
                .foregroundColor(SWTheme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                SWSecondaryButton(title: "Add dose", glyph: .plus, tint: SWTheme.teal) {
                    // The picker below caps at today. A due date in the future is
                    // only displayed as clamped — the binding would keep the future
                    // value and store a dose dated months ahead, which then
                    // re-anchors the rest of the course.
                    newDoseDate = min(record.nextDoseDueDate ?? SWDay.today, SWDay.today)
                    addingKind = kind
                }
                .opacity(record.isComplete ? 0.5 : 1)
                // Opacity alone does not stop the tap, so a completed course still
                // opened an overlay whose only outcome was a refusal.
                .allowsHitTesting(!record.isComplete)
                if !record.doses.isEmpty {
                    SWSecondaryButton(title: "Remove last", glyph: .minus, tint: SWTheme.alert) {
                        store.removeLastVaccineDose(kind)
                    }
                }
            }
        }
    }

    private func doseTrack(kind: SWVaccineKind, record: SWVaccineRecord) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(0..<kind.doseCount), id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index < record.recordedDoses ? SWTheme.teal : SWTheme.mist)
                    .frame(height: 9)
            }
        }
    }

    private func addDoseOverlay(_ kind: SWVaccineKind) -> some View {
        ZStack {
            Color.black.opacity(0.34)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { addingKind = nil }

            VStack(alignment: .leading, spacing: 12) {
                Text("Add a \(kind.title) dose")
                    .font(SWFont.title(17))
                    .foregroundColor(SWTheme.ink)
                Text("Dose \(min(kind.doseCount, store.vaccine(kind).recordedDoses + 1)) of \(kind.doseCount).")
                    .font(SWFont.body(13))
                    .foregroundColor(SWTheme.inkSoft)
                SWDateField(title: "Given on", date: $newDoseDate,
                            range: SWDay.adding(days: -7300, to: SWDay.today)...SWDay.today)
                SWPrimaryButton(title: "Add dose",
                                glyph: .check,
                                enabled: !store.vaccine(kind).isComplete) {
                    store.addVaccineDose(kind, date: newDoseDate)
                    addingKind = nil
                }
                if store.vaccine(kind).isComplete {
                    Text("Every dose commonly cited for this course is already recorded.")
                        .font(SWFont.bodyTight(11.5))
                        .foregroundColor(SWTheme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SWSecondaryButton(title: "Cancel", tint: SWTheme.inkSoft) {
                    addingKind = nil
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
}
