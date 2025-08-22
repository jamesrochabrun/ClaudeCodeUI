import CCAccessibilityFoundation
@preconcurrency import Combine

extension XcodeObserver {

  /// Creates a publisher of accessibility notifications related to the Xcode.app instance state.
  /// The publisher retains a `Task` responsible for receiving the notifications from Xcode.app. The task will be cancelled when the
  /// returned publisher is deallocated.
  public func makeAXNotificationPublisher() -> AnyPublisher<AXNotification<InstanceState>, Never> {
    let subject = PassthroughSubject<AXNotification<InstanceState>, Never>()
    let notifications = axNotifications

    // We use the `.userInitiated` priority since the user is controlling the macOS window being
    // monitored.
    let task = Task(priority: .userInitiated) {
      for await notification in await notifications.notifications() {
        subject.send(notification)
      }
    }

    let cancellable = AnyCancellable { task.cancel() }
    let publisher = PublisherWithCancellable(wrappedPublisher: subject, cancellable: cancellable)
    return publisher.eraseToAnyPublisher()
  }
}

// MARK: - PublisherWithCancellable

/// A wrapper that attaches a cancellable to the lifecycle of a publisher.
private struct PublisherWithCancellable<WrappedPublisher: Publisher>: Publisher {
  typealias Output = WrappedPublisher.Output
  typealias Failure = WrappedPublisher.Failure

  func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    wrappedPublisher.receive(subscriber: subscriber)
  }

  let wrappedPublisher: WrappedPublisher
  let cancellable: AnyCancellable
}
