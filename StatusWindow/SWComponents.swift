import SwiftUI

// MARK: - Safe area probe

enum SWSafeArea {
    private static var firstScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private static var window: UIWindow? {
        guard let scene = firstScene else { return nil }
        return scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
    }

    /// The real top inset once a window exists. The 20 pt fallback applies only
    /// before there is a window to ask: in landscape the inset is legitimately 0
    /// and forcing a floor there would draw an opaque strip over the header.
    static var top: CGFloat {
        guard let window = window else { return 20 }
        return max(0, window.safeAreaInsets.top)
    }

    static var bottom: CGFloat {
        window?.safeAreaInsets.bottom ?? 0
    }
}

/// An opaque strip pinned over the status bar. Placed as the LAST sibling of the
/// root ZStack so nothing scrolled can ever draw over the clock.
struct SWStatusStrip: View {
    var color: Color = SWTheme.paper

    var body: some View {
        color
            .frame(height: SWSafeArea.top)
            .edgesIgnoringSafeArea(.top)
            .allowsHitTesting(false)
    }
}

// MARK: - Card container

struct SWCard<Content: View>: View {
    var padding: CGFloat = 14
    var background: Color = SWTheme.card
    var borderColor: Color = SWTheme.cardEdge
    let content: () -> Content

    init(padding: CGFloat = 14,
         background: Color = SWTheme.card,
         borderColor: Color = SWTheme.cardEdge,
         @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.background = background
        self.borderColor = borderColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: SWMetrics.cardCorner, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SWMetrics.cardCorner, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Headings

struct SWSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingText: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(SWFont.label(11))
                    .tracking(0.9)
                    .foregroundColor(SWTheme.inkSoft)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(SWFont.bodyTight(12))
                        .foregroundColor(SWTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            if let trailingText = trailingText {
                Text(trailingText)
                    .font(SWFont.label(11))
                    .foregroundColor(SWTheme.inkFaint)
            }
        }
    }
}

/// The header every screen carries in place of a navigation bar.
struct SWScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    let trailing: () -> Trailing

    init(title: String,
         subtitle: String? = nil,
         onBack: (() -> Void)? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let onBack = onBack {
                Button(action: onBack) {
                    SWIcon(glyph: .chevronLeft, size: 20, color: SWTheme.ink)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(SWTheme.mist.opacity(0.7))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(SWFont.title(20))
                    .foregroundColor(SWTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(SWFont.bodyTight(12))
                        .foregroundColor(SWTheme.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, SWMetrics.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(SWTheme.paper)
    }
}

extension SWScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, onBack: onBack, trailing: { EmptyView() })
    }
}

// MARK: - Screen scaffold
//
// One scroll container for every screen, so the bottom inset that clears the
// floating tab bar is defined in exactly one place.

struct SWScreen<Header: View, Content: View>: View {
    let header: () -> Header
    let content: () -> Content
    var bottomInset: CGFloat = SWMetrics.scrollBottomInset

    init(bottomInset: CGFloat = SWMetrics.scrollBottomInset,
         @ViewBuilder header: @escaping () -> Header,
         @ViewBuilder content: @escaping () -> Content) {
        self.bottomInset = bottomInset
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Capped on the same column as the content below it, so the title and
            // the cards share one left edge on iPad. The hairline stays full bleed.
            header()
                .swColumnCap()
            Rectangle()
                .fill(SWTheme.hairline)
                .frame(height: 1)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .padding(.horizontal, SWMetrics.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, bottomInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                // iPad: the reading column is capped and centred instead of a
                // card being stretched to ~1000 pt. No effect on a phone.
                .swColumnCap()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SWTheme.paper.edgesIgnoringSafeArea(.bottom))
        .navigationBarHidden(true)
        .navigationBarTitle("")
    }
}

// MARK: - Pills and tags

struct SWPill: View {
    let text: String
    var color: Color = SWTheme.teal
    var filled: Bool = false
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(SWFont.label(size))
            .foregroundColor(filled ? Color.white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.12))
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Buttons

struct SWPrimaryButton: View {
    let title: String
    var glyph: SWGlyph? = nil
    var tint: Color = SWTheme.teal
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 8) {
                if let glyph = glyph {
                    SWIcon(glyph: glyph, size: 17, color: .white, lineWidth: 1.9)
                }
                Text(title)
                    .font(SWFont.heading(15))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(enabled ? tint : SWTheme.inkFaint)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(enabled ? 1 : 0.7)
    }
}

struct SWSecondaryButton: View {
    let title: String
    var glyph: SWGlyph? = nil
    var tint: Color = SWTheme.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let glyph = glyph {
                    SWIcon(glyph: glyph, size: 16, color: tint, lineWidth: 1.8)
                }
                Text(title)
                    .font(SWFont.heading(14))
                    .foregroundColor(tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(SWTheme.mist.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(SWTheme.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SWIconButton: View {
    let glyph: SWGlyph
    var tint: Color = SWTheme.ink
    var background: Color = SWTheme.mist
    var size: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SWIcon(glyph: glyph, size: size * 0.55, color: tint)
                .frame(width: size, height: size)
                .background(Circle().fill(background.opacity(0.7)))
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Rows

struct SWKeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = SWTheme.ink
    var monospaced: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(SWFont.bodyTight(13))
                .foregroundColor(SWTheme.inkSoft)
            Spacer(minLength: 8)
            Text(value)
                .font(monospaced ? SWFont.mono(13) : SWFont.heading(13))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SWToggleRow: View {
    let title: String
    var caption: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SWFont.heading(14))
                    .foregroundColor(SWTheme.ink)
                if let caption = caption {
                    Text(caption)
                        .font(SWFont.bodyTight(12))
                        .foregroundColor(SWTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            SWSwitch(isOn: $isOn)
        }
    }
}

/// A hand-drawn switch, so the control looks the same regardless of system tint.
struct SWSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? SWTheme.teal : SWTheme.inkFaint.opacity(0.5))
                    .frame(width: 46, height: 28)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .padding(.horizontal, 3)
            }
            .frame(width: 46, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SWNavRow<Leading: View>: View {
    let title: String
    var caption: String? = nil
    var trailingText: String? = nil
    let leading: () -> Leading
    let action: () -> Void

    init(title: String,
         caption: String? = nil,
         trailingText: String? = nil,
         @ViewBuilder leading: @escaping () -> Leading,
         action: @escaping () -> Void) {
        self.title = title
        self.caption = caption
        self.trailingText = trailingText
        self.leading = leading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading()
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                        .multilineTextAlignment(.leading)
                    if let caption = caption {
                        Text(caption)
                            .font(SWFont.bodyTight(12))
                            .foregroundColor(SWTheme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                if let trailingText = trailingText {
                    Text(trailingText)
                        .font(SWFont.label(11))
                        .foregroundColor(SWTheme.inkFaint)
                }
                SWIcon(glyph: .chevronRight, size: 16, color: SWTheme.inkFaint)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension SWNavRow where Leading == EmptyView {
    init(title: String,
         caption: String? = nil,
         trailingText: String? = nil,
         action: @escaping () -> Void) {
        self.init(title: title, caption: caption, trailingText: trailingText,
                  leading: { EmptyView() }, action: action)
    }
}

// MARK: - Checkbox row

struct SWCheckRow: View {
    let title: String
    var caption: String? = nil
    let isOn: Bool
    var tint: Color = SWTheme.teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isOn ? tint : SWTheme.inkFaint, lineWidth: 1.6)
                        .frame(width: 22, height: 22)
                    if isOn {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tint)
                            .frame(width: 22, height: 22)
                        SWIcon(glyph: .check, size: 15, color: .white, lineWidth: 2.1)
                    }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SWFont.heading(14))
                        .foregroundColor(SWTheme.ink)
                        .multilineTextAlignment(.leading)
                    if let caption = caption {
                        Text(caption)
                            .font(SWFont.bodyTight(12))
                            .foregroundColor(SWTheme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Segmented picker

struct SWSegmented<T: Hashable>: View {
    let options: [T]
    let titleFor: (T) -> String
    @Binding var selection: T
    var tint: Color = SWTheme.teal
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { pair in
                let option = pair.element
                let selected = option == selection
                Button(action: { selection = option }) {
                    Text(titleFor(option))
                        .font(SWFont.label(compact ? 11 : 12))
                        .foregroundColor(selected ? .white : SWTheme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 7 : 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selected ? tint : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SWTheme.mist.opacity(0.6))
        )
    }
}

// MARK: - Disclaimer line

struct SWDisclaimerLine: View {
    var text: String = SWReferenceLibrary.disclaimerShort
    var tint: Color = SWTheme.inkFaint

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            SWIcon(glyph: .info, size: 13, color: tint, lineWidth: 1.4)
                .padding(.top, 1)
            Text(text)
                .font(SWFont.bodyTight(11))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty state

struct SWEmptyState: View {
    let glyph: SWGlyph
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SWTheme.tealSoft.opacity(0.6))
                    .frame(width: 66, height: 66)
                SWIcon(glyph: glyph, size: 30, color: SWTheme.teal, lineWidth: 1.6)
            }
            Text(title)
                .font(SWFont.title(17))
                .foregroundColor(SWTheme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(SWFont.body(13))
                .foregroundColor(SWTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle = actionTitle, let action = action {
                SWPrimaryButton(title: actionTitle, glyph: .plus, action: action)
                    .padding(.top, 2)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 12)
    }
}

// MARK: - Field wrappers

struct SWFieldLabel: View {
    let text: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text.uppercased())
                .font(SWFont.label(10))
                .tracking(0.8)
                .foregroundColor(SWTheme.inkSoft)
            if let caption = caption {
                Text(caption)
                    .font(SWFont.bodyTight(11))
                    .foregroundColor(SWTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A text field that takes a tap reliably. In a multi-field SwiftUI form only the
/// first field responds unless focus is driven explicitly, so every field in this
/// app is wrapped here and given its own focus identity.
struct SWTextField: View {
    let placeholder: String
    @Binding var text: String
    var focusTag: Int
    @Binding var focusedTag: Int?
    var multiline: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(SWTheme.mist.opacity(0.45))
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(focusedTag == focusTag ? SWTheme.teal.opacity(0.7) : SWTheme.hairline,
                        lineWidth: 1.2)
            if text.isEmpty {
                Text(placeholder)
                    .font(SWFont.body(14))
                    .foregroundColor(SWTheme.inkFaint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, multiline ? 12 : 11)
                    .allowsHitTesting(false)
            }
            SWFocusableField(text: $text,
                             multiline: multiline,
                             tag: focusTag,
                             focusedTag: $focusedTag)
                .padding(.horizontal, 8)
                .padding(.vertical, multiline ? 6 : 5)
        }
        .frame(height: multiline ? 96 : 44)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onTapGesture { focusedTag = focusTag }
    }
}

private struct SWFocusableField: View {
    @Binding var text: String
    let multiline: Bool
    let tag: Int
    @Binding var focusedTag: Int?
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if multiline {
                TextEditor(text: $text)
                    .font(SWFont.body(14))
                    .foregroundColor(SWTheme.ink)
                    .focused($isFocused)
                    .onAppear {
                        UITextView.appearance().backgroundColor = .clear
                    }
            } else {
                TextField("", text: $text)
                    .font(SWFont.body(14))
                    .foregroundColor(SWTheme.ink)
                    .focused($isFocused)
                    .disableAutocorrection(true)
            }
        }
        .onChange(of: focusedTag) { newValue in
            isFocused = (newValue == tag)
        }
        .onChange(of: isFocused) { newValue in
            if newValue { focusedTag = tag }
            else if focusedTag == tag { focusedTag = nil }
        }
    }
}

// MARK: - Date field

struct SWDateField: View {
    let title: String
    @Binding var date: Date
    var includeTime: Bool = false
    var range: ClosedRange<Date>? = nil

    private var labelRow: some View {
        HStack(spacing: 10) {
            SWIcon(glyph: .calendar, size: 17, color: SWTheme.teal, lineWidth: 1.5)
            Text(title)
                .font(SWFont.bodyTight(13))
                .foregroundColor(SWTheme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 6)
        }
    }

    private var picker: some View {
        Group {
            if let range = range {
                DatePicker("", selection: $date,
                           in: range,
                           displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
            } else {
                DatePicker("", selection: $date,
                           displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
            }
        }
        .labelsHidden()
        .accentColor(SWTheme.teal)
        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        // The picker draws its year with the environment calendar, which is the
        // device's. On a phone set to a non-Gregorian calendar that produced a
        // year the rest of the record never uses. Pin it to the same calendar
        // every computed date in this app is built from.
        .environment(\.calendar, SWDay.calendar)
        .environment(\.timeZone, SWDay.calendar.timeZone)
    }

    var body: some View {
        Group {
            if includeTime {
                // A date AND time picker leaves no room for an inline label: the
                // label used to be squeezed until it wrapped one character per
                // line. Stack it instead, which also holds up at 375 pt.
                VStack(alignment: .leading, spacing: 8) {
                    labelRow
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        picker
                    }
                }
            } else {
                HStack(spacing: 10) {
                    labelRow
                    picker
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(SWTheme.mist.opacity(0.45))
        )
    }
}

// MARK: - Notice card

struct SWNoticeCard: View {
    let glyph: SWGlyph
    let title: String
    let message: String
    var tint: Color = SWTheme.amber
    var background: Color = SWTheme.amberSoft

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            SWIcon(glyph: glyph, size: 20, color: tint, lineWidth: 1.7)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SWFont.heading(14))
                    .foregroundColor(SWTheme.ink)
                Text(message)
                    .font(SWFont.bodyTight(12.5))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Paragraph block

struct SWParagraphs: View {
    let paragraphs: [String]
    var size: CGFloat = 13.5
    var color: Color = SWTheme.inkSoft

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { pair in
                Text(pair.element)
                    .font(SWFont.body(size))
                    .foregroundColor(color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Confirmation overlay
//
// Destructive actions use an authored in-app overlay rather than a system alert,
// which also sidesteps the one-modifier-per-view limits on iOS 15.

struct SWConfirmOverlay: View {
    let title: String
    let message: String
    var confirmTitle: String = "Delete"
    var confirmTint: Color = SWTheme.alert
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { onCancel() }

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(SWFont.title(17))
                    .foregroundColor(SWTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(SWFont.body(13))
                    .foregroundColor(SWTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    SWPrimaryButton(title: confirmTitle, tint: confirmTint, action: onConfirm)
                    if let secondaryTitle = secondaryTitle, let onSecondary = onSecondary {
                        SWSecondaryButton(title: secondaryTitle, tint: SWTheme.ink, action: onSecondary)
                    }
                    SWSecondaryButton(title: "Cancel", tint: SWTheme.inkSoft, action: onCancel)
                }
                .padding(.top, 2)
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

// MARK: - Info overlay

struct SWInfoOverlay: View {
    let title: String
    let paragraphs: [String]
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { onClose() }

            // The card is measured against the space actually available rather
            // than against a fixed 280 pt scroll area: title + button + padding
            // added up to roughly 411 pt, which is taller than a landscape phone,
            // and the title and the Close button were both cut off. The scroll
            // area is the only flexible row, so it absorbs the shortfall.
            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(title)
                            .font(SWFont.title(17))
                            .foregroundColor(SWTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        SWIconButton(glyph: .close, tint: SWTheme.inkSoft, size: 30, action: onClose)
                    }
                    ScrollView(.vertical, showsIndicators: false) {
                        SWParagraphs(paragraphs: paragraphs, size: 13)
                    }
                    .frame(maxHeight: 280)
                    SWSecondaryButton(title: "Close", action: onClose)
                }
                .padding(18)
                .frame(maxWidth: min(360, max(200, geo.size.width - 40)),
                       maxHeight: max(150, geo.size.height - 24))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SWTheme.card)
                )
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
        }
    }
}
