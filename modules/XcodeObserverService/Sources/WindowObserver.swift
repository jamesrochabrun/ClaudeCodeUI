import AccessibilityFoundation
import AppKit
import Combine
import Foundation
import XcodeObserverServiceInterface

// MARK: - WindowObserver

/// This class observes a single window.
class WindowObserver: ObservableObject {

  // MARK: Lifecycle

  @XcodeInspectorActor
  init(window: AXUIElement, state: WindowState) {
    self.window = window
    self.state = state
    window.setMessagingTimeout(2)
  }

  // MARK: Internal

  let window: AXUIElement
  @Published @XcodeInspectorActor var state: WindowState

}
