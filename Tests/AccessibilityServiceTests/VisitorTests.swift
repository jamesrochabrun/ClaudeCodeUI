import XCTest
@testable import AccessibilityService

final class TreeTraversalTests: XCTestCase {

  // MARK: - Test Node

  class TreeNode {

    // MARK: Lifecycle

    init(value: Int, children: [TreeNode] = []) {
      self.value = value
      self.children = children
    }

    // MARK: Internal

    let value: Int
    var children: [TreeNode]

  }

  // MARK: - Tests

  func testEmptyTree() {
    let root = TreeNode(value: 1)
    let result = traverseTree(
      root: root,
      getChildren: { $0.children },
      visitNode: { node, result in
        result.append(node)
        return .continue
      }
    )

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].value, 1)
  }

  func testFullTraversal() {
    // Create a tree:
    //       1
    //     /   \
    //    2     3
    //   / \
    //  4   5
    let node4 = TreeNode(value: 4)
    let node5 = TreeNode(value: 5)
    let node2 = TreeNode(value: 2, children: [node4, node5])
    let node3 = TreeNode(value: 3)
    let root = TreeNode(value: 1, children: [node2, node3])

    let result = traverseTree(
      root: root,
      getChildren: { $0.children },
      visitNode: { node, result in
        result.append(node)
        return .continue
      }
    )

    XCTAssertEqual(result.count, 5)
    XCTAssertEqual(result.map { $0.value }, [1, 2, 4, 5, 3])
  }

  func testSkipDescendants() {
    let node4 = TreeNode(value: 4)
    let node5 = TreeNode(value: 5)
    let node2 = TreeNode(value: 2, children: [node4, node5])
    let node3 = TreeNode(value: 3)
    let root = TreeNode(value: 1, children: [node2, node3])

    let result = traverseTree(
      root: root,
      getChildren: { $0.children },
      visitNode: { node, result in
        result.append(node)
        return node.value == 2 ? .skipDescendants : .continue
      }
    )

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result.map { $0.value }, [1, 2, 3])
  }

  func testEarlyStop() {
    let node4 = TreeNode(value: 4)
    let node5 = TreeNode(value: 5)
    let node2 = TreeNode(value: 2, children: [node4, node5])
    let node3 = TreeNode(value: 3)
    let root = TreeNode(value: 1, children: [node2, node3])

    let result = traverseTree(
      root: root,
      getChildren: { $0.children },
      visitNode: { node, result in
        result.append(node)
        return node.value == 2 ? .stop : .continue
      }
    )

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result.map { $0.value }, [1, 2])
  }
}
