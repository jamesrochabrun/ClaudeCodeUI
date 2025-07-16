import AccessibilityFoundation
import AccessibilityServiceInterface
import AppKit
import Combine
import XcodeObserverServiceInterface

// MARK: - InstanceObserver

/// This class observes a given instance of Xcode.
/// One instance can have several windows, which can be workspaces or other window types like Devices & Simulators for instance.
class InstanceObserver: ObservableObject {

  // MARK: Lifecycle

  @XcodeInspectorActor
  init(
    accessibilityService: AccessibilityService,
    processIdentifier: Int32,
    axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>>
  ) {
    self.accessibilityService = accessibilityService
    self.processIdentifier = processIdentifier
    self.axNotifications = axNotifications
    appElement = AXUIElementCreateApplication(processIdentifier)
    appElement.setMessagingTimeout(2)

    windowObservers = appElement.windows
      .map { window in
        if window.identifier == "Xcode.WorkspaceWindow" {
          WorkspaceWindowObserver(
            accessibilityService: accessibilityService,
            processIdentifier: processIdentifier,
            axNotifications: axNotifications,
            window: window
          )
        } else {
          WindowObserver(window: window, state: WindowState(element: window, workspace: nil))
        }
      }

    state = .init(
      isActive: true,
      processId: processIdentifier,
      focusedWindow: nil,
      focusedElement: nil,
      windows: windowObservers.compactMap { $0.state }
    )

    Task { @XcodeInspectorActor in
      observeFocusedWindow()
      observeAXNotifications()
      observeDidActivateApplicationNotification()
      pollActiveInstance()
    }
  }

  deinit {
    axObservationTask?.cancel()
    focusedWindowObservation?.cancel()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  // MARK: Internal

  @Published @XcodeInspectorActor private(set) var state: InstanceState

  @XcodeInspectorActor
  func refresh() {
    if let focusedWindow = focusedWindow as? WorkspaceWindowObserver {
      focusedWindow.refresh()
    } else {
      observeFocusedWindow()
    }
    handleFocusedUIElementChanged()
  }

  // MARK: Private

  private let accessibilityService: AccessibilityService

  private let processIdentifier: Int32
  private let axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>>
  private var focusedWindow: WindowObserver?
  private var windowObservers: [WindowObserver]

  private var axObservationTask: Task<Void, Error>?
  private var focusedWindowObservation: AnyCancellable?

  private let appElement: AXUIElement

  private var focusedWorkspace: WorkspaceWindowObserver? {
    focusedWindow as? WorkspaceWindowObserver
  }

  /// Observe the currently focussed window, and subscribe to changes.
  @XcodeInspectorActor
  private func observeFocusedWindow() {
    if let window = appElement.focusedWindow {
      guard focusedWindow?.window != window else {
        return
      }
      let windowObserver: WindowObserver
      if
        let (idx, existingWindowObserver) = windowObservers.enumerated().first(where: { $0.element.window == window }),
        let existingObserver = existingWindowObserver as? WorkspaceWindowObserver
      {
        windowObserver = existingObserver
        windowObservers.insert(windowObservers.remove(at: idx), at: 0)
      } else {
        windowObserver = window.identifier == "Xcode.WorkspaceWindow"
          ? WorkspaceWindowObserver(
            accessibilityService: accessibilityService,
            processIdentifier: processIdentifier,
            axNotifications: axNotifications,
            window: window
          )
          : WindowObserver(window: window, state: WindowState(element: window, workspace: nil))
        windowObservers.insert(windowObserver, at: 0)
      }

      focusedWindowObservation?.cancel()
      focusedWindowObservation = nil
      focusedWindow = windowObserver

      updateStateWith(
        isActive: true,
        focusedWindow: windowObserver.window,
        windows: windowObservers.map { $0.state }
      )

      focusedWindowObservation = windowObserver.$state
        .sink { [weak self] windowState in
          guard let self else { return }
          updateStateWith(
            windows: state.windows.compactMap { $0.element != window ? $0 : windowState }
          )
        }
    } else {
      focusedWindow = nil
      updateStateWith(isActive: false, focusedWindow: .some(nil))
    }
  }

  @objc
  private func activeAppDidChange(notification: NSNotification) {
    if let activeApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
      Task { @XcodeInspectorActor [weak self] in
        self?.updateStateWith(isActive: activeApp.processIdentifier == processIdentifier)
      }
    }
  }

  /// This duplicates the observation of the active app done through the Accessibility API.
  /// This is to help ensure that we don't miss when Xcode becomes inactive,
  /// which might happen and be the reason that we sometime see floating windows.
  private func observeDidActivateApplicationNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeAppDidChange),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )
  }

  /// Subscribe to Accessibility notifications send by the instance.
  private func observeAXNotifications() {
    axObservationTask?.cancel()
    axObservationTask = nil

    let axNotificationStream = AXNotificationStream(
      processIdentifier: processIdentifier,
      notifications: [
        .applicationActivated,
        .applicationDeactivated,
        .moved,
        .resized,
        .mainWindowChanged,
        .focusedWindowChanged,
        .focusedUIElementChanged,
        .windowMoved,
        .windowResized,
        .windowMiniaturized,
        .windowDeminiaturized,
        .created,
        .uiElementDestroyed,
      ]
    )

    axObservationTask = Task { @XcodeInspectorActor [weak self] in
      for await notification in axNotificationStream {
        guard let self else { return }
        try Task.checkCancellation()
        await Task.yield()

        switch notification.kind {
        case .applicationActivated:
          updateStateWith(isActive: true)

        case .applicationDeactivated:
          updateStateWith(isActive: false)

        case .moved:
          break

        case .resized:
          break

        case .mainWindowChanged:
          break

        case .focusedWindowChanged:
          observeFocusedWindow()

        case .focusedUIElementChanged:
          handleFocusedUIElementChanged()

        case .windowMoved:
          break

        case .windowResized:
          break

        case .windowMiniaturized:
          break

        case .windowDeminiaturized:
          break

        default:
          // Not possible as not subscribed
          break
        }

        axNotifications.send(.init(kind: notification.kind, element: notification.element, state: state))
      }
    }
  }

  /// Poll the active instance to ensure that we don't miss when Xcode becomes active/inactive.
  /// This is done as a reliable back up for when we miss one of the two notification sources we already listen to.
  ///
  /// The reason for missing such notification is unknown, but we have observed that on some rare occasion the state is not updated accordingly.
  /// This poll based mechanism will ensure that we are not in an inaccurate state for too long, and that the developer doesn't experience floating windows.
  private func pollActiveInstance() {
    Task { @XcodeInspectorActor [weak self] in
      guard let self else { return }
      // Wait 1s.
      try await Task.sleep(nanoseconds: 1000000000)

      if let activeApp = NSWorkspace.shared.activeApplication() {
        let isActive = activeApp["NSApplicationProcessIdentifier"] as? Int32 == processIdentifier
        updateStateWith(isActive: isActive)
      }

      pollActiveInstance()
    }
  }

  @XcodeInspectorActor
  private func handleFocusedUIElementChanged() {
    // focusedWindowChanged is not send reliably, so also rely on this event to update the focussed window.
    observeFocusedWindow()

    // Update workspaces
    focusedWorkspace?.updateURLs()

    let focusedElement = appElement.focusedElement
    let editorElement = focusedElement.map { $0.isSourceEditor
      ? $0
      : accessibilityService.firstParent(
        from: $0,
        where: \.isSourceEditor,
        cacheKey: "source-editor"
      )
    } ?? nil
    focusedWorkspace?.updateEditors(focusedElement: editorElement)

    updateStateWith(focusedElement: focusedElement)
  }

  @XcodeInspectorActor
  private func updateStateWith(
    isActive: Bool? = nil,
    focusedWindow: AXUIElement?? = .none,
    focusedElement: AXUIElement?? = .none,
    windows: [WindowState]? = nil
  ) {
    let newState = InstanceState(
      isActive: isActive ?? state.isActive,
      processId: state.processId,
      focusedWindow: focusedWindow ?? state.focusedWindow,
      focusedElement: focusedElement ?? state.focusedElement,
      windows: windows ?? state.windows
    )
    if newState != state {
      state = newState
    }
  }
}

extension AXUIElement {
  var isSourceEditor: Bool {
    description == "Source Editor"
  }

  var isCompletionPanel: Bool {
    identifier == "_XC_COMPLETION_TABLE_"
  }
}
