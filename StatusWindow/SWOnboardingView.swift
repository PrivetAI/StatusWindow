import SwiftUI

// MARK: - Onboarding
//
// Shown on first run and re-openable from Settings at any time. The last page
// carries the full disclaimer and is the only page with a required action.

private struct SWOnboardingPage: Identifiable {
    let id: Int
    let glyph: SWGlyph
    let title: String
    let body: [String]
    let footnote: String?
}

struct SWOnboardingView: View {
    @Binding var preferences: SWPreferences
    var isFirstRun: Bool
    @Environment(\.presentationMode) private var presentationMode

    @State private var pageIndex: Int = 0

    private let pages: [SWOnboardingPage] = [
        SWOnboardingPage(
            id: 0,
            glyph: .calendar,
            title: "One question, answered precisely",
            body: [
                "Status Window answers a single question: given what you have logged and when it happened, which tests are worth asking for, and on which date does each one become meaningful.",
                "It works out dates. It never states or estimates a result, and it has no opinion about anything you record."
            ],
            footnote: nil
        ),
        SWOnboardingPage(
            id: 1,
            glyph: .timeline,
            title: "Why the date matters",
            body: [
                "Every infection has a window period — the interval after an exposure during which a test cannot yet detect anything. Test inside that window and a negative result is accurate about that day while saying almost nothing about the exposure.",
                "The windows are very different from each other. With commonly cited figures, a chlamydia NAAT is described as conclusive at around 14 days and a hepatitis C antibody test at around 180 days after the same exposure.",
                "This app takes every exposure you log and merges the resulting dates into a small number of visits, each one placed where it actually closes what it lists."
            ],
            footnote: SWReferenceLibrary.windowCaveat
        ),
        SWOnboardingPage(
            id: 2,
            glyph: .swab,
            title: "The site is part of the answer",
            body: [
                "A test reports only on the specimen it was given. A urine sample covers the genital tract and says nothing about the throat or the rectum, which published guidance describes as commonly carrying infection without symptoms.",
                "That is why the Log asks which activity types were involved, in neutral clinical terms. The answers decide which specimen sites appear on your schedule — a throat swab, a rectal swab, or both, listed separately rather than folded into one line."
            ],
            footnote: nil
        ),
        SWOnboardingPage(
            id: 3,
            glyph: .partners,
            title: "Labels, not names",
            body: [
                "Partner entries are labels you choose. Initials or a nickname work better than a full name, and the app never asks for one.",
                "Anything a partner tells you is stored as reported, with the date you were told it. That is a statement about what a record can know, not about anybody's honesty.",
                "Encounters can also be logged with no partner entry at all."
            ],
            footnote: nil
        ),
        SWOnboardingPage(
            id: 4,
            glyph: .lock,
            title: "Nothing leaves this phone",
            body: [
                "Everything you enter is written to a single protected file on this device. There is no account, no sync, no analytics, no upload and no export to anywhere external.",
                "The privacy lock is on by default and uses whichever method your device already has. A discreet mode hides the contents in the app switcher. Both can be changed in Settings."
            ],
            footnote: nil
        ),
        SWOnboardingPage(
            id: 5,
            glyph: .info,
            title: "What this app is not",
            body: [
                SWReferenceLibrary.disclaimerLong,
                "If you have had a possible higher-risk exposure in the last 72 hours, or if anything has appeared that concerns you, published guidance describes contacting a sexual health service or an emergency service now rather than waiting for any date."
            ],
            footnote: nil
        )
    ]

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                header
                Rectangle().fill(SWTheme.hairline).frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        pageBody(pages[safeIndex])
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                footer
            }
        }
    }

    private var safeIndex: Int {
        SWMath.clampInt(pageIndex, 0, max(0, pages.count - 1))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(isFirstRun ? "Welcome" : "How this works")
                .font(SWFont.title(19))
                .foregroundColor(SWTheme.ink)
            Spacer(minLength: 6)
            if !isFirstRun {
                SWIconButton(glyph: .close, tint: SWTheme.inkSoft) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func pageBody(_ page: SWOnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(SWTheme.tealSoft.opacity(0.6))
                    .frame(width: 72, height: 72)
                SWIcon(glyph: page.glyph, size: 32, color: SWTheme.teal, lineWidth: 1.7)
            }

            Text(page.title)
                .font(SWFont.display(23))
                .foregroundColor(SWTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            SWParagraphs(paragraphs: page.body, size: 14)

            if let footnote = page.footnote {
                SWDisclaimerLine(text: footnote)
                    .padding(.top, 2)
            }

            if page.id == pages.count - 1 {
                SWNoticeCard(glyph: .alert,
                             title: "Please confirm",
                             message: "By continuing you acknowledge that Status Window is a record-keeping tool, that it is not a medical device, and that it does not provide medical advice.",
                             tint: SWTheme.amber,
                             background: SWTheme.amberSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == safeIndex ? SWTheme.teal : SWTheme.inkFaint.opacity(0.4))
                        .frame(width: index == safeIndex ? 18 : 7, height: 7)
                }
            }

            HStack(spacing: 10) {
                if safeIndex > 0 {
                    SWSecondaryButton(title: "Back", glyph: .chevronLeft) {
                        pageIndex = max(0, safeIndex - 1)
                    }
                }
                SWPrimaryButton(title: primaryTitle) {
                    advance()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(SWTheme.paper)
    }

    private var primaryTitle: String {
        if safeIndex == pages.count - 1 {
            return isFirstRun ? "I understand — continue" : "Close"
        }
        return "Continue"
    }

    private func advance() {
        if safeIndex < pages.count - 1 {
            pageIndex = safeIndex + 1
        } else {
            preferences.onboardingSeen = true
            preferences.disclaimerAcknowledged = true
            presentationMode.wrappedValue.dismiss()
        }
    }
}
