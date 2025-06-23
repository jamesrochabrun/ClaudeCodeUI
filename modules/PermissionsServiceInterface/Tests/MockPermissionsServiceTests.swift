import Combine
import Observation
import XCTest

@testable import PermissionsServiceInterface

final class MockPermissionsServiceTests: XCTestCase {

  // MARK: Internal

  override func tearDown() {
    super.tearDown()
    cancellables.removeAll()
  }

  func test_isAccessibilityPermissionGrantedCurrentValuePublisher_sendsInitialValueToSubscriber() throws {
    let subject = MockPermissionsService(isAccessibilityPermissionGranted: false)
    let exp = expectation(description: "sends initial value")
    subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink {
      XCTAssertFalse($0)
      exp.fulfill()
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)
  }

  func test_isAccessibilityPermissionGrantedCurrentValuePublisher_accessIsGranted_updatesSubscriber() async throws {
    let subject = MockPermissionsService(isAccessibilityPermissionGranted: false)
    let exp = expectation(description: "sends two values")
    var counter = 0
    subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink {
      if counter == 0 {
        XCTAssertFalse($0)
      } else {
        XCTAssertTrue($0)
        exp.fulfill()
      }
      counter += 1
    }.store(in: &cancellables)
    await subject.grantAccessibilityPermission()
    await fulfillment(of: [exp], timeout: 1)
  }

  func test_isXcodeExtensionPermissionGrantedCurrentValuePublisher_sendsInitialValueToSubscriber() throws {
    let subject = MockPermissionsService(isXcodeExtensionPermissionGranted: false)
    let exp = expectation(description: "sends initial value")
    subject.isXcodeExtensionPermissionGrantedCurrentValuePublisher.sink {
      XCTAssertFalse($0)
      exp.fulfill()
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)
  }

  func test_isXcodeExtensionPermissionGrantedCurrentValuePublisher_accessIsGranted_updatesSubscriber() async throws {
    let subject = MockPermissionsService(isXcodeExtensionPermissionGranted: false)
    let exp = expectation(description: "sends two values")
    var counter = 0
    subject.isXcodeExtensionPermissionGrantedCurrentValuePublisher.sink {
      if counter == 0 {
        XCTAssertFalse($0)
      } else {
        XCTAssertTrue($0)
        exp.fulfill()
      }
      counter += 1
    }.store(in: &cancellables)
    await subject.grantXcodeExtensionPermission()
    await fulfillment(of: [exp], timeout: 1)
  }

  // MARK: Private

  private var cancellables = Set<AnyCancellable>()

}
