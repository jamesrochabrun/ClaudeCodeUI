import AppKit

extension AXUIElement {

  // MARK: Public

  /// The frame of the AXUIElement in AppKit coordinate (bottom is y=0).
  public var appKitFrame: CGRect? {
    guard
      let rect = cgFrame,
      let screenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
    else { return nil }
    return CGRect(x: rect.minX, y: screenHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  /// The frame of the AXUIElement in CG coordinate (top is y=0).
  public var cgFrame: CGRect? {
    guard
      let position, let size
    else {
      return nil
    }
    return CGRect(origin: position, size: size)
  }

  // MARK: Private

  /// The position of the AXUIElement (top is y=0).
  private var position: CGPoint? {
    guard let value: AXValue = try? copyValue(key: kAXPositionAttribute)
    else { return nil }
    var point = CGPoint.zero
    if AXValueGetValue(value, .cgPoint, &point) {
      return point
    }
    return nil
  }

  /// The size of the AXUIElement.
  private var size: CGSize? {
    guard let value: AXValue = try? copyValue(key: kAXSizeAttribute)
    else { return nil }
    var size = CGSize.zero
    if AXValueGetValue(value, .cgSize, &size) {
      return size
    }
    return nil
  }

}
