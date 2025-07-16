// MARK: - VisitorAction

enum VisitorAction {
  case skipDescendants
  case stop
  case `continue`
}

// MARK: - VisitorResult

enum VisitorResult {
  case stop
  case `continue`
}

func traverseTree<Node>(
  root: Node,
  getChildren: (Node) -> [Node],
  visitNode: (Node, inout [Node]) -> VisitorAction
) -> [Node] {
  var result = [Node]()

  @discardableResult
  func traverse(_ node: Node) -> VisitorResult {
    switch visitNode(node, &result) {
    case .skipDescendants:
      return .continue

    case .stop:
      return .stop

    case .continue:
      let children = getChildren(node)
      for child in children {
        switch traverse(child) {
        case .stop:
          return .stop
        case .continue:
          break
        }
      }
      return .continue
    }
  }

  traverse(root)
  return result
}
