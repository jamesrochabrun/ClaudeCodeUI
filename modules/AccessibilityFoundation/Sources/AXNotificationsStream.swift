import AppKit
import ApplicationServices

/// Subscribe to specific Accessibility notifications for a given element, and expose them as a stream.
public final class AXNotificationStream: AsyncSequence {

  // MARK: Lifecycle

  deinit {
    continuation.finish()
  }

  public init(
    processIdentifier: Int32,
    element: AXUIElement? = nil,
    notifications: [AXNotificationKind],
    file: StaticString = #file,
    line: UInt = #line,
    function: StaticString = #function
  ) {
    self.file = file
    self.line = line
    self.function = function
    let notificationNames = notifications.map(\.rawValue)
    var cont: Continuation!
    stream = Stream { continuation in
      cont = continuation
    }
    continuation = cont
    var observer: AXObserver?

    func callback(
      observer _: AXObserver,
      element: AXUIElement,
      notificationName: CFString,
      userInfo: CFDictionary,
      pointer: UnsafeMutableRawPointer?
    ) {
      guard
        let pointer = pointer?.assumingMemoryBound(to: Continuation.self),
        let kind = AXNotificationKind(rawValue: notificationName as String)
      else { return }
      pointer.pointee.yield((kind, element, userInfo))
    }

    _ = AXObserverCreateWithInfoCallback(
      processIdentifier,
      callback,
      &observer
    )
    guard let observer else {
      continuation.finish()
      return
    }

    let observingElement = element ?? AXUIElementCreateApplication(processIdentifier)
    continuation.onTermination = { @Sendable _ in
      for name in notificationNames {
        AXObserverRemoveNotification(observer, observingElement, name as CFString)
      }
      CFRunLoopRemoveSource(
        CFRunLoopGetMain(),
        AXObserverGetRunLoopSource(observer),
        .commonModes
      )
    }

    Task { @MainActor [weak self] in
      CFRunLoopAddSource(
        CFRunLoopGetMain(),
        AXObserverGetRunLoopSource(observer),
        .commonModes
      )
      var pendingRegistrationNames = Set(notificationNames)
      var retry = 0
      // TODO: use retry?
      while !pendingRegistrationNames.isEmpty, retry < 100 {
        guard let self else { return }
        retry += 1
        for name in notificationNames {
          await Task.yield()
          // Subscribe to the given notification. Events will be send to continuation, ie to the stream.
          let notificationRegistrationResult = withUnsafeMutablePointer(to: &continuation) { pointer in
            AXObserverAddNotification(
              observer,
              observingElement,
              name as CFString,
              pointer
            )
          }
          switch notificationRegistrationResult {
          case .success:
            pendingRegistrationNames.remove(name)

          case .actionUnsupported:
            print("AXObserver: Action unsupported: \(name)")
            pendingRegistrationNames.remove(name)

          case .apiDisabled:
            print("AXObserver: Accessibility API disabled, will try again later")
            retry -= 1

          case .invalidUIElement:
            print("AXObserver: Invalid UI element, notification name \(name)")
            pendingRegistrationNames.remove(name)

          case .invalidUIElementObserver:
            print("AXObserver: Invalid UI element observer")
            pendingRegistrationNames.remove(name)

          case .cannotComplete:
            print("AXObserver: Failed to observe \(name), will try again later")

          case .notificationUnsupported:
            print("AXObserver: Notification unsupported: \(name)")
            pendingRegistrationNames.remove(name)

          case .notificationAlreadyRegistered:
            print("AXObserver: Notification already registered: \(name)")
            pendingRegistrationNames.remove(name)

          default:
            print("AXObserver: error \(notificationRegistrationResult) when registering \(name), will try again")
          }
        }
        try await Task.sleep(nanoseconds: 1_500_000_000)
      }
    }
  }

  // MARK: Public

  public typealias Stream = AsyncStream<Element>
  public typealias Continuation = Stream.Continuation
  public typealias AsyncIterator = Stream.AsyncIterator
  public typealias Element = (kind: AXNotificationKind, element: AXUIElement, info: CFDictionary)

  public func makeAsyncIterator() -> Stream.AsyncIterator {
    stream.makeAsyncIterator()
  }

  // MARK: Private

  private var continuation: Continuation
  private let stream: Stream

  private let file: StaticString
  private let line: UInt
  private let function: StaticString

}
