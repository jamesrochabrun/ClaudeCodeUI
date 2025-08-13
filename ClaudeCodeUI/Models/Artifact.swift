import Foundation

enum Artifact: Identifiable {
  
  case diagram(String)
  
  var id: String {
    switch self {
    case .diagram(let content):
      return "diagram_\(content.hashValue)"
    }
  }
}
