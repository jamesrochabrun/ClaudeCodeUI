import CCAccessibilityFoundation
import Combine

// MARK: - XcodeObserver

/// A class that monitor Xcode's state, and publishes its observations.
public protocol XcodeObserver {
  typealias State = AXGatedState<[InstanceState]>

  /// The current state of the app.
  var state: State { get }

  var statePublisher: AnyPublisher<State, Never> { get }

  /// A stream of notifications describing what changed in Xcode's state.
  /// Some notifications, such as `.scrollPositionChanged`, can be broadcasted without changing the state as they relate to a property not represented in the state.
  var axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>> { get }

  /// Restarts the observation by clearing all cached data and re-scanning for Xcode instances.
  func restartObservation()
}

// MARK: - XcodeObserverProviding

public protocol XcodeObserverProviding {
  var xcodeObserver: XcodeObserver { get }
}
