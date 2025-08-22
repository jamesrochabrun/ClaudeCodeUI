import Observation
import XCTest

@testable import PermissionsServiceInterface

final class PermissionsServiceTests: XCTestCase {

  func test_isAccessibilityPermissionGranted_returnsCurrentValue() async throws {
    let subject = MockPermissionsService(isAccessibilityPermissionGranted: false)
    var isAccessibilityPermissionGranted = await subject.isAccessibilityPermissionGranted.value
    XCTAssertFalse(isAccessibilityPermissionGranted)

    let exp = expectation(description: "permission granted")
    let cancellable = subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink { value in
      if value {
        exp.fulfill()
      }
    }
    await subject.grantAccessibilityPermission()

    await fulfillment(of: [exp], timeout: 1)
    isAccessibilityPermissionGranted = await subject.isAccessibilityPermissionGranted.value
    XCTAssertTrue(isAccessibilityPermissionGranted)

    _ = cancellable
  }
}
