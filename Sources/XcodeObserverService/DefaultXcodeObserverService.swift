import AccessibilityFoundation
import AccessibilityServiceInterface
import AppKit
import Combine
import PermissionsServiceInterface
import XcodeObserverServiceInterface

// MARK: - XcodeInspectorActor

@globalActor
public enum XcodeInspectorActor: GlobalActor {
  public actor Actor { }
  public static let shared = Actor()
}

// MARK: - DefaultXcodeObserver

/// Observes and describe the state of the Xcode application.
public final class DefaultXcodeObserver: XcodeObserver, @unchecked Sendable {

  // MARK: Lifecycle

  public init(
    accessibilityService: AccessibilityService,
    permissionsService: PermissionsService
  ) {
    self.accessibilityService = accessibilityService
    permissionsService
      .isAccessibilityPermissionGrantedCurrentValuePublisher
      .sink { [weak self] isAccessibilityPermissionGranted in
        if isAccessibilityPermissionGranted {
          self?.accessibilityAccessGranted()
        } else {
          self?.update(state: .unknownDueToMissingAccessibilityPermissions)
        }
      }
      .store(in: &cancellables)
  }

  // MARK: Public

  @Published public private(set) var state = State.initializing

  public let axNotifications = AsyncPassthroughSubject<AXNotification<InstanceState>>()

  public var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }

  // MARK: Private

  private let accessibilityService: AccessibilityService

  private var cancellables = Set<AnyCancellable>()

  private var xcodesCancellableBag = [Int32: AnyCancellable]()

  private var appObservationTask: Task<Void, Never>?

  private var xcodes: [InstanceObserver] = []

  private func accessibilityAccessGranted() {
    Task { @XcodeInspectorActor in
      self.restartObserving()
    }
  }

  @XcodeInspectorActor
  private func restartObserving() {
    let runningApplications = NSWorkspace.shared.runningApplications
    xcodes = runningApplications
      .filter { $0.isXcode }
      .map { InstanceObserver(
        accessibilityService: accessibilityService,
        processIdentifier: $0.processIdentifier,
        axNotifications: axNotifications
      ) }

    update(state: .known(xcodes.map { $0.state }))
    for item in xcodes { observe(xcode: item) }

    appObservationTask?.cancel()
    appObservationTask = nil

    appObservationTask = Task(priority: .utility) { [weak self] in
      guard let self else { return }

      await withThrowingTaskGroup(of: Void.self) { [weak self] group in
        // App activation
        group.addTask { [weak self] in
          let sequence = NSWorkspace.shared.notificationCenter
            .notifications(named: NSWorkspace.didActivateApplicationNotification)

          for await notification in sequence {
            try Task.checkCancellation()
            guard
              let app = (
                notification
                  .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
              )
            else { continue }
            if app.isXcode {
              let pid = app.processIdentifier
              Task { @XcodeInspectorActor [weak self] in
                self?.handleXcodeActivation(pid)
                self?.axNotifications.send(.init(kind: .applicationActivated, element: AXUIElementCreateApplication(pid)))
              }
            }
          }
        }

        // App termination
        group.addTask { [weak self] in
          let sequence = NSWorkspace.shared.notificationCenter
            .notifications(named: NSWorkspace.didTerminateApplicationNotification)

          for await notification in sequence {
            try Task.checkCancellation()
            guard
              let app = (
                notification
                  .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
              )
            else { continue }
            if app.isXcode {
              let pid = app.processIdentifier
              Task { @XcodeInspectorActor [weak self] in
                self?.handleXcodeTermination(pid)
                self?.axNotifications.send(.init(kind: .applicationTerminated, element: AXUIElementCreateApplication(pid)))
              }
            }
          }
        }
      }
    }
  }

  nonisolated private func update(state: State) {
    Task { @MainActor in
      self.state = state
    }
  }

  @XcodeInspectorActor
  private func observe(xcode: InstanceObserver) {
    xcodesCancellableBag[xcode.state.processId] = xcode.$state.sink { xcode in
      Task { @MainActor [weak self] in
        guard let self, let instances = state.knownState else { return }
        updateStateWith(
          instances: instances.map { $0.processId == xcode.processId ? xcode : $0 }
        )
      }
    }
  }

  private func stopObservingXcodeWith(processIdentifier: Int32) {
    xcodesCancellableBag[processIdentifier]?.cancel()
    xcodesCancellableBag[processIdentifier] = nil
  }

  @XcodeInspectorActor
  private func handleXcodeActivation(_ processIdentifier: Int32) {
    if let xcode = xcodes.first(where: { $0.state.processId == processIdentifier }) {
      xcode.refresh()
    } else {
      let new = InstanceObserver(
        accessibilityService: accessibilityService,
        processIdentifier: processIdentifier,
        axNotifications: axNotifications
      )
      xcodes.append(new)
      update(state: .known(xcodes.map { $0.state }))
      observe(xcode: new)

      new.refresh()
    }
  }

  @XcodeInspectorActor
  private func handleXcodeTermination(_ processIdentifier: Int32) {
    if
      let xcode = xcodes.first(where: {
        $0.state.processId == processIdentifier
      })
    {
      stopObservingXcodeWith(processIdentifier: processIdentifier)
      xcodes = xcodes.filter { $0 !== xcode }

      update(state: .known(xcodes.map { $0.state }))
    }
  }

  @MainActor
  private func updateStateWith(instances: [InstanceState]) {
    if case .known(let currentKnownState) = state {
      if currentKnownState != instances {
        state = .known(instances)
      }
    } else {
      state = .known(instances)
    }
  }
}

extension NSRunningApplication {
  var isXcode: Bool {
    bundleIdentifier == "com.apple.dt.Xcode"
  }
}
