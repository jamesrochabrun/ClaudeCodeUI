import XCTest
@testable import XcodeObserverServiceInterface

final class MockXcodeObserverTests: XCTestCase {
  @MainActor
  func test_stateUpdate_hasTheRightInitialState() throws {
    // The default value is `.initializing`
    var mock = MockXcodeObserver()
    XCTAssertEqual(mock.state, .initializing)

    let state = MockXcodeObserver.State.known([InstanceState(
      isActive: true,
      processId: 123,
      focusedWindow: nil,
      focusedElement: nil,
      completionPanel: nil,
      windows: []
    )])
    mock = MockXcodeObserver(initialState: state)
    XCTAssertEqual(mock.state, state)
  }

  @MainActor
  func test_stateUpdate_broadcastsUpdate() throws {
    let mock = MockXcodeObserver()
    let exp = expectation(description: "State was updated")
    let newState = MockXcodeObserver.State.known([InstanceState(
      isActive: true,
      processId: 123,
      focusedWindow: nil,
      focusedElement: nil,
      completionPanel: nil,
      windows: []
    )])
    let cancellable = mock.$state.sink { newValue in
      if newValue == newState {
        exp.fulfill()
      }
    }
    mock.state = newState
    waitForExpectations(timeout: 1)
    _ = cancellable
  }
}
