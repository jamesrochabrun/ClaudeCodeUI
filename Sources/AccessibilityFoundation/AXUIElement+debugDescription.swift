import AppKit

#if DEBUG
extension AXUIElement {
  public var debugDescription: String {
    var desc = ""

    if let identifier {
      desc = "\(desc) - identifier: \(identifier)"
    }
    if let value {
      desc = "\(desc) - value: \(value.prefix(100))"
    }
    if let title {
      desc = "\(desc) - title: \(title)"
    }
    if let role {
      desc = "\(desc) - role: \(role)"
    }
    if let doubleValue {
      desc = "\(desc) - doubleValue: \(doubleValue)"
    }
    if let description {
      desc = "\(desc) - description: \(description)"
    }
    if let roleDescription {
      desc = "\(desc) - roleDescription: \(roleDescription)"
    }
    if let label {
      desc = "\(desc) - label: \(label)"
    }

    if children.count > 0 {
      return "\(desc)\n\(children.map { $0.debugDescription.indented }.joined(separator: "\n"))"
    } else {
      return desc
    }
  }
}

extension String {
  var indented: String {
    split(separator: "\n", omittingEmptySubsequences: false)
      .map { "  \($0)" }
      .joined(separator: "\n")
  }
}
#endif
