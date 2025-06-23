import AccessibilityFoundation
import Combine

#if DEBUG
public final class MockXcodeObserver: XcodeObserver {

  // MARK: Lifecycle

  @MainActor
  public init(initialState: State = .initializing) {
    state = initialState
  }

  // MARK: Public

  @MainActor @Published public var state: State

  public let axNotifications = AsyncPassthroughSubject<AXNotification<InstanceState>>()

  public var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }

}
#endif
