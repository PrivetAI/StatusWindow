import SwiftUI
import LocalAuthentication
import Security

// MARK: - Lock controller
//
// The privacy lock is ON by default in this app. It uses the device owner
// authentication policy, which falls back to the device passcode automatically
// when biometrics are unavailable. If no passcode is set at all the lock cannot
// work, and in that case the user is told plainly rather than being shut out of
// their own record.

final class SWLockController: ObservableObject {

    enum Availability: Equatable {
        case biometric(String)
        case passcodeOnly
        case unavailable
    }

    @Published var isLocked: Bool = true
    @Published var isEvaluating: Bool = false
    @Published var lastFailureMessage: String? = nil
    @Published private(set) var availability: Availability = .passcodeOnly

    init() {
        refreshAvailability()
    }

    func refreshAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                availability = .biometric("Face ID")
            case .touchID:
                availability = .biometric("Touch ID")
            default:
                availability = .biometric("Biometrics")
            }
            return
        }
        var passcodeError: NSError?
        let passcodeContext = LAContext()
        if passcodeContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &passcodeError),
           SWLockController.deviceCredentialExists() {
            availability = .passcodeOnly
        } else {
            availability = .unavailable
        }
    }

    /// Second opinion on whether a device credential actually exists.
    ///
    /// `canEvaluatePolicy(.deviceOwnerAuthentication)` can answer true on a device
    /// that has no passcode set at all. Acting on that answer presents a system
    /// sheet the person can never satisfy and there is no way back out of it, which
    /// would shut them out of their own record permanently. The keychain is the
    /// check that does not lie: an item guarded by
    /// `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` can only be written when a
    /// passcode is actually set. The probe item is deleted again immediately and
    /// holds no data.
    static func deviceCredentialExists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.statuswindow.app.lock-probe",
            kSecAttrAccount as String: "lock-probe"
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        add[kSecValueData as String] = Data([0x01])

        let status = SecItemAdd(add as CFDictionary, nil)
        SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }

    /// Errors that mean no credential can ever satisfy the prompt. Staying locked
    /// after one of these would be a dead end rather than a security measure.
    private static func meansNoCredential(_ error: Error?) -> Bool {
        guard let laError = error as? LAError else { return false }
        switch laError.code {
        case .passcodeNotSet, .biometryNotAvailable, .notInteractive:
            return true
        case .biometryNotEnrolled:
            return !deviceCredentialExists()
        default:
            return false
        }
    }

    var methodLabel: String {
        switch availability {
        case .biometric(let name): return name
        case .passcodeOnly:        return "Device passcode"
        case .unavailable:         return "Not available"
        }
    }

    /// Engages the lock. Called on launch and whenever the app is backgrounded.
    func engage(enabled: Bool) {
        guard enabled else {
            isLocked = false
            return
        }
        refreshAvailability()
        if availability == .unavailable {
            // Nothing can authenticate. Do not trap the user out of their record.
            isLocked = false
            return
        }
        isLocked = true
    }

    func unlockWithoutPrompt() {
        isLocked = false
        lastFailureMessage = nil
    }

    func authenticate(reason: String = "Unlock your private record") {
        refreshAvailability()
        if availability == .unavailable {
            isLocked = false
            return
        }
        guard !isEvaluating else { return }
        isEvaluating = true
        lastFailureMessage = nil

        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isEvaluating = false
                if success {
                    self.isLocked = false
                    self.lastFailureMessage = nil
                } else if SWLockController.meansNoCredential(error) {
                    // Nothing on this device can answer the prompt. Open the record
                    // rather than leave the person outside it.
                    self.availability = .unavailable
                    self.isLocked = false
                    self.lastFailureMessage = nil
                } else {
                    self.lastFailureMessage = SWLockController.describe(error)
                }
            }
        }
    }

    private static func describe(_ error: Error?) -> String {
        guard let laError = error as? LAError else {
            return "Authentication did not complete. Try again."
        }
        switch laError.code {
        case .userCancel, .systemCancel, .appCancel:
            return "Authentication was canceled."
        case .userFallback:
            return "Choose the passcode option to continue."
        case .biometryLockout:
            return "Biometrics are locked out. Use the device passcode instead."
        case .passcodeNotSet:
            return "No device passcode is set, so the lock cannot be used."
        case .biometryNotEnrolled:
            return "No biometrics are enrolled. The device passcode will be used instead."
        case .authenticationFailed:
            return "Authentication was not recognized. Try again."
        default:
            return "Authentication did not complete. Try again."
        }
    }
}

// MARK: - Lock screen

struct SWLockView: View {
    @ObservedObject var controller: SWLockController
    let neutralTitle: String

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)

            // In landscape there is roughly a third of the height to work with,
            // and this stack is taller than that once a failure message and the
            // no-credential escape hatch are both showing. `minHeight` keeps the
            // centered portrait layout and lets the short case scroll rather than
            // clip the unlock button off the bottom.
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        ZStack {
                            Circle()
                                .fill(SWTheme.tealSoft.opacity(0.65))
                                .frame(width: 108, height: 108)
                            SWIcon(glyph: .lock, size: 46, color: SWTheme.teal, lineWidth: 2)
                        }

                        Text(displayTitle)
                            .font(SWFont.display(23))
                            .foregroundColor(SWTheme.ink)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)

                        Text("This record is locked.")
                            .font(SWFont.body(14))
                            .foregroundColor(SWTheme.inkSoft)
                            .padding(.top, 6)

                        if let message = controller.lastFailureMessage {
                            Text(message)
                                .font(SWFont.bodyTight(12.5))
                                .foregroundColor(SWTheme.alert)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 28)
                                .padding(.top, 12)
                        }

                        Spacer(minLength: 24)

                        VStack(spacing: 10) {
                            SWPrimaryButton(title: unlockTitle,
                                            glyph: .unlock,
                                            enabled: !controller.isEvaluating) {
                                controller.authenticate()
                            }
                            Text("Unlocking uses \(controller.methodLabel).")
                                .font(SWFont.bodyTight(11.5))
                                .foregroundColor(SWTheme.inkFaint)

                            // Escape hatch. If this device has neither biometrics nor a
                            // passcode there is nothing that can answer the prompt, and the
                            // record must not become unreachable to the person who owns it.
                            if controller.availability == .unavailable {
                                Button(action: { controller.unlockWithoutPrompt() }) {
                                    Text("Open the record without the lock")
                                        .font(SWFont.label(12.5))
                                        .foregroundColor(SWTheme.teal)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

                                Text("No passcode or biometrics are set on this device, so the lock cannot be applied. Setting a device passcode in the system settings turns it back on.")
                                    .font(SWFont.bodyTight(11))
                                    .foregroundColor(SWTheme.inkFaint)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 34)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    // iPad: a single unlock button stretched across the whole
                    // display reads as a broken layout. No effect on a phone.
                    .swColumnCap(SWMetrics.narrowMaxWidth)
                }
            }
        }
    }

    private var displayTitle: String {
        let trimmed = neutralTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Status Window" : trimmed
    }

    private var unlockTitle: String {
        controller.isEvaluating ? "Waiting…" : "Unlock"
    }
}

// MARK: - Discreet overlay
//
// Covers the interface whenever the app is not frontmost, so the app switcher
// snapshot shows nothing but the neutral title.

struct SWDiscreetOverlay: View {
    let neutralTitle: String

    var body: some View {
        ZStack {
            SWTheme.paper.edgesIgnoringSafeArea(.all)
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(SWTheme.tealSoft.opacity(0.6))
                        .frame(width: 84, height: 84)
                    SWIcon(glyph: .calendar, size: 36, color: SWTheme.teal, lineWidth: 1.8)
                }
                Text(displayTitle)
                    .font(SWFont.title(19))
                    .foregroundColor(SWTheme.inkSoft)
            }
        }
    }

    private var displayTitle: String {
        let trimmed = neutralTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Status Window" : trimmed
    }
}
