import AccessibilityFoundation
import Combine

#if DEBUG
public final class MockXcodeObserver: XcodeObserver {

  // MARK: Lifecycle

  public init(initialState: State = .initializing) {
    _state = Published(initialValue: initialState)
  }

  // MARK: Public

  @Published public var state: State

  public let axNotifications = AsyncPassthroughSubject<AXNotification<InstanceState>>()

  public var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }

}
#endif
