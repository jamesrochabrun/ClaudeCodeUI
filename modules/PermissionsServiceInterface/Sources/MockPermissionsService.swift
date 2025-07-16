import Combine
import Foundation

@Observable
public final class MockPermissionsService: PermissionsService {

  // MARK: Lifecycle

  public init(
    isAccessibilityPermissionGranted: Bool = false) {
    isAccessibilityPermissionGrantedSubject = .init(isAccessibilityPermissionGranted)
  }

  // MARK: Public

  public var isAccessibilityPermissionGrantedCurrentValuePublisher: AnyPublisher<Bool, Never> {
    isAccessibilityPermissionGrantedSubject.eraseToAnyPublisher()
  }

  public func requestAccessibilityPermission() {
    Task { @MainActor in
      isAccessibilityPermissionGrantedSubject.send(true)
    }
  }

  public func grantAccessibilityPermission() async {
    Task { @MainActor in
      isAccessibilityPermissionGrantedSubject.send(true)
    }
  }

  public func removeAccessibilityPermission() async {
    Task { @MainActor in
      isAccessibilityPermissionGrantedSubject.send(false)
    }
  }

  // MARK: Private

  private let isAccessibilityPermissionGrantedSubject: CurrentValueSubject<Bool, Never>
}
