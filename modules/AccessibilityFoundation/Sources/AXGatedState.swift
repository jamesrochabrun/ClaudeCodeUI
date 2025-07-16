// MARK: - AXGatedState

/// A state that is only available once Accessibility permissions have been granted.
public enum AXGatedState<State> {
  /// The initial value.
  case initializing
  /// The state is unknown.
  /// This is because Accessibility permissions have not been granted, and the application cannot be observed.
  case unknownDueToMissingAccessibilityPermissions
  /// The state is known.
  case known(_ state: State)
}

extension AXGatedState {
  public var knownState: State? {
    if case .known(let state) = self {
      return state
    }
    return nil
  }
}

extension AXGatedState: Equatable where State: Equatable { }

#if DEBUG
extension AXGatedState: CustomDebugStringConvertible where State: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .initializing:
      "Initializing"
    case .unknownDueToMissingAccessibilityPermissions:
      "unknown due to missing accessibility permissions:"
    case .known(let state):
      """

      State:
      \(state.debugDescription)
      """
    }
  }
}
#endif
