import AppKit

extension AXUIElement {
  /// Read the identifier attribute.
  public var identifier: String? {
    (try? copyValue(key: kAXIdentifierAttribute))
  }

  /// Read the value (string) attribute.
  public var value: String? {
    (try? copyValue(key: kAXValueAttribute))
  }

  /// Read the title attribute.
  public var title: String? {
    (try? copyValue(key: kAXTitleAttribute))
  }

  /// Read the role attribute.
  public var role: String? {
    (try? copyValue(key: kAXRoleAttribute))
  }

  /// Read the value (double) attribute.
  public var doubleValue: Double? {
    (try? copyValue(key: kAXValueAttribute))
  }

  /// Read the document attribute.
  public var document: String? {
    try? copyValue(key: kAXDocumentAttribute)
  }

  /// Read the description attribute (label in Accessibility Inspector).
  public var description: String? {
    (try? copyValue(key: kAXDescriptionAttribute))
  }

  /// Read the description attribute (type in Accessibility Inspector).
  public var roleDescription: String? {
    (try? copyValue(key: kAXRoleDescriptionAttribute))
  }

  /// Read the label attribute.
  public var label: String? {
    (try? copyValue(key: kAXLabelValueAttribute))
  }

  /// Read the selected text range attribute.
  public var selectedTextRange: ClosedRange<Int>? {
    guard let value: AXValue = try? copyValue(key: kAXSelectedTextRangeAttribute)
    else { return nil }
    var range = CFRange(location: 0, length: 0)
    if AXValueGetValue(value, .cfRange, &range) {
      return range.location...(range.location + range.length)
    }
    return nil
  }

  /// Read the focused attribute.
  public var isFocussed: Bool {
    (try? copyValue(key: kAXFocusedAttribute)) ?? false
  }

  /// Read the enabled attribute.
  public var isEnabled: Bool {
    (try? copyValue(key: kAXEnabledAttribute)) ?? false
  }

  /// Read the hidden attribute.
  public var isHidden: Bool {
    (try? copyValue(key: kAXHiddenAttribute)) ?? false
  }

  /// Wether the AXUIElement is valid.
  /// It might be invalid if for the element has been removed from the UI hierarchy.
  public var isValid: Bool {
    var value: AnyObject?
    let error = AXUIElementCopyAttributeValue(self, kAXDescriptionAttribute as CFString, &value)
    switch error {
    case .invalidUIElement:
      return false
    default:
      return true
    }
  }

  /// Set global timeout in seconds.
  public static func setGlobalMessagingTimeout(_ timeout: Float) {
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
  }

  /// Set timeout in seconds for this element.
  public func setMessagingTimeout(_ timeout: Float) {
    AXUIElementSetMessagingTimeout(self, timeout)
  }

}

// MARK: - Helper

extension AXUIElement {
  func copyValue<T>(key: String, ofType _: T.Type = T.self) throws -> T {
    var value: AnyObject?
    let error = AXUIElementCopyAttributeValue(self, key as CFString, &value)
    if error == .success, let value = value as? T {
      return value
    }
    throw error
  }

  func copyParameterizedValue<T>(
    key: String,
    parameters: AnyObject,
    ofType _: T.Type = T.self
  ) throws -> T {
    var value: AnyObject?
    let error = AXUIElementCopyParameterizedAttributeValue(
      self,
      key as CFString,
      parameters as CFTypeRef,
      &value
    )
    if error == .success, let value = value as? T {
      return value
    }
    throw error
  }
}
