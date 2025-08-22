@preconcurrency import ApplicationServices
import Combine
import CCPermissionsServiceInterface
import CCTerminalServiceInterface

// MARK: - DefaultPermissionsService

@Observable
public final class DefaultPermissionsService: PermissionsService, @unchecked Sendable {

  // MARK: Lifecycle

  @MainActor
  public init(
    terminalService: TerminalService,
    userDefaults: UserDefaults,
    bundle: Bundle,
    isAccessibilityPermissionGrantedClosure: @escaping () -> Bool,
    pollIntervalNanoseconds: UInt64 = 1_000_000_000
  ) {
    isAccessibilityPermissionGrantedSubject = .init(isAccessibilityPermissionGrantedClosure())
    self.isAccessibilityPermissionGrantedClosure = isAccessibilityPermissionGrantedClosure
    self.pollIntervalNanoseconds = pollIntervalNanoseconds
    self.terminalService = terminalService
    self.userDefaults = userDefaults
    self.bundle = bundle
  }

  // MARK: Public

  public var isAccessibilityPermissionGrantedCurrentValuePublisher: AnyPublisher<Bool, Never> {
    monitorAccessibilityPermissionStatus()
    return isAccessibilityPermissionGrantedSubject.eraseToAnyPublisher()
  }

  public func requestAccessibilityPermission() {
    AXIsProcessTrustedWithOptions([
      kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
    ] as NSDictionary)

    monitorAccessibilityPermissionStatus()
  }

  // MARK: Internal

  func monitorAccessibilityPermissionStatus() {
    guard !hasStartedMonitoringAccessibilityPermissionStatus else { return }
    hasStartedMonitoringAccessibilityPermissionStatus = true

    let pollInterval = pollIntervalNanoseconds
    
    Task { [weak self] in
      while true {
        // Wait and try again.
        try? await Task.sleep(nanoseconds: pollInterval)
        // Stop polling if we've been deallocated.
        guard let self = self else { return }
        // Stop polling if access has been granted.
        guard !self.isAccessibilityPermissionGrantedClosure() else {
          // Access has been granted!
          if self.isAccessibilityPermissionGrantedSubject.value != true {
            self.isAccessibilityPermissionGrantedSubject.send(true)
          }
          return
        }
      }
    }
  }

  // MARK: Private

  @ObservationIgnored private var hasStartedMonitoringAccessibilityPermissionStatus = false

  @ObservationIgnored private var hasStartedMonitoringXcodeExtensionPermissionStatus = false

  private let userDefaults: UserDefaults

  private let terminalService: TerminalService
  private let bundle: Bundle

  @ObservationIgnored private var hasStartedXcode = false

  private let isAccessibilityPermissionGrantedClosure: () -> Bool
  private let pollIntervalNanoseconds: UInt64
  private let isAccessibilityPermissionGrantedSubject: CurrentValueSubject<Bool, Never>

  private func isXcodeRunning() async throws -> Bool {
    guard let output = try await terminalService.output("ps aux | grep Xcode", quiet: true) else {
      return false
    }
    // When using an installation made by Xcodes, the path to the app is like
    // /Applications/Xcode-16.0.0.app/Contents/MacOS/Xcode
    return output.split(separator: "\n").contains { $0.hasSuffix("/Xcode") }
  }

  /// Start Xcode.
  /// This function will complete when Xcode is starting to launch, but likely before the application has had time to launch its extensions.
  private func startXcode() async throws {
    guard !hasStartedXcode else {
      // Only start the app once, to allow the user to close it without it being constantly re-opened.
      return
    }
    hasStartedXcode = true

    // For example, this is /Applications/Xcode-16.0.0.app/Contents/Developer
    let activeDeveloperDirectory = try await terminalService.output("xcode-select -p", quiet: true)
    guard let xcodePath = activeDeveloperDirectory?.split(separator: ".app").first?.appending(".app") else {
      return
    }
    _ = try await terminalService.output("open \(xcodePath)", quiet: true)
  }
}

extension String {
  static let xcodeExtensionPermissionHasBeenGrantedOnce = "xcodeExtensionPermissionHasBeenGrantedOnce"
}

extension UserDefaults {

  fileprivate var xcodeExtensionPermissionHasBeenGrantedOnce: Bool {
    bool(forKey: .xcodeExtensionPermissionHasBeenGrantedOnce) == true
  }

  fileprivate func setXcodeExtensionPermissionHasBeenGrantedOnce() {
    set(true, forKey: .xcodeExtensionPermissionHasBeenGrantedOnce)
  }
}
