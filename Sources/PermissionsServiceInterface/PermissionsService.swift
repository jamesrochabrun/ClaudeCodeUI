import Combine

// MARK: - PermissionsService

/// Manages the permissions for Accessibility and Xcode extension.
public protocol PermissionsService {
  /// Request Accessibility permissions.
  /// If this doesn't do anything and your are building your app locally, you'll want to run `tccutil reset Accessibility "$BUNDLE_IDENTIFIER"` in your terminal first.
  func requestAccessibilityPermission()

  /// A publisher of the current value of whether access is granted. This publisher will publish the current value upon subscription and
  /// updates to that value over time.
  var isAccessibilityPermissionGrantedCurrentValuePublisher: AnyPublisher<Bool, Never> { get }
}

// MARK: - PermissionsServiceProviding

public protocol PermissionsServiceProviding {
  var permissionsService: PermissionsService { get }
}
