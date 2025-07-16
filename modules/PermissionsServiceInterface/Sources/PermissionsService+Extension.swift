import Combine

// MARK: - PermissionsStatus

public struct PermissionsStatus {
  public let isAccessibilityPermissionGranted: Bool?

  public var allGranted: Bool {
    isAccessibilityPermissionGranted == true
  }
}

extension PermissionsService {
  /// A publisher of the current value of whether Xcode extension permission is granted. This publisher will publish the current value upon subscription and
  /// updates to that value over time.
  public var permissionsStatusValuePublisher: AnyPublisher<PermissionsStatus, Never> {
    let accessibilityPublisher = isAccessibilityPermissionGrantedCurrentValuePublisher

    return accessibilityPublisher
      .map { PermissionsStatus(isAccessibilityPermissionGranted: $0) }
      .eraseToAnyPublisher()
  }

  public var permissionsStatus: Future<PermissionsStatus, Never> {
    permissionsStatusValuePublisher.future
  }

  public var isAccessibilityPermissionGranted: Future<Bool, Never> {
    isAccessibilityPermissionGrantedCurrentValuePublisher.compactMap { $0 }.eraseToAnyPublisher().future
  }
}

extension AnyPublisher {
  var future: Future<Output, Failure> {
    Future { promise in
      var cancellable: AnyCancellable?
      // If the publisher has been created from calling `eraseToAnyPublisher` on a CurrentValueSubject
      // the value that might have already been set is not lost here. But this is an assumption that I think might break.
      cancellable = self.sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          promise(.failure(error))
        case .finished:
          break
        }
        // Cancel the subscription on completion
        cancellable?.cancel()
      }, receiveValue: { value in
        promise(.success(value))
      })
    }
  }
}

extension Publisher where Failure == Never {
  public var currentValue: Output? {
    var result: Output? = nil
    _ = sink { value in
      result = value
    }
    return result
  }
}
