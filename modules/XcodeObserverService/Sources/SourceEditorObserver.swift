import AccessibilityFoundation
import AppKit
import XcodeObserverServiceInterface

// MARK: - SourceEditorObserver

/// This class observes the current editing window.
class SourceEditorObserver: ObservableObject {

  // MARK: Lifecycle

  @XcodeInspectorActor
  init(
    processIdentifier: Int32,
    element: AXUIElement,
    tabs: [String],
    activeTab: String?,
    activeTabURL: URL?,
    axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>>
  ) {
    self.processIdentifier = processIdentifier
    self.element = element
    state = .init(
      element: element,
      content: Self.getContent(element: element),
      tabs: tabs,
      activeTab: activeTab,
      activeTabURL: activeTabURL,
      isFocussed: false
    )
    self.axNotifications = axNotifications

    element.setMessagingTimeout(2)
    observeAXNotifications()
  }

  deinit {
    observeAXNotificationsTask?.cancel()
  }

  // MARK: Internal

  typealias Content = EditorInformation.SourceEditorContent

  @Published @XcodeInspectorActor private(set) var state: EditorState

  let element: AXUIElement

  @XcodeInspectorActor
  func update(tabs: [String]) {
    updateStateWith(tabs: tabs)
  }

  @XcodeInspectorActor
  func update(documentURL: URL?) {
    updateStateWith(activeTabURL: documentURL)
  }

  @XcodeInspectorActor
  func didChangeFocus(isFocussed: Bool) {
    updateStateWith(isFocussed: isFocussed)
  }

  // MARK: Private

  private let processIdentifier: Int32
  private var observeAXNotificationsTask: Task<Void, Never>?
  private let axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>>

  /// Get the content of the source editor.
  ///
  /// - note: This method might be expensive. It needs to convert index based ranges to line based ranges.
  private static func getContent(element: AXUIElement) -> Content {
    let content = element.value
    let selectionRange = element.selectedTextRange

    let lines = content?.breakLines() ?? []
    let selection = selectionRange.map { SourceEditorObserver.convertRangeToCursorRange($0, in: lines) }

    let lineAnnotationElements = element.children.filter { $0.identifier == "Line Annotation" }
    let lineAnnotations = lineAnnotationElements
      .map(\.description)
      .compactMap { $0 }

    return .init(
      content: content ?? "",
      lines: lines,
      selection: selection,
      cursorPosition: selection?.start ?? .outOfScope,
      lineAnnotations: lineAnnotations
    )
  }

  private func observeAXNotifications() {
    observeAXNotificationsTask = Task { @XcodeInspectorActor [weak self] in
      guard let self else { return }
      await withThrowingTaskGroup(of: Void.self) { [weak self] group in
        guard let self else { return }
        let editorNotifications = AXNotificationStream(
          processIdentifier: processIdentifier,
          element: element,
          notifications: [
            .selectedTextChanged,
            .valueChanged,
          ]
        )

        group.addTask { [weak self] in
          for await notification in editorNotifications {
            try Task.checkCancellation()
            await Task.yield()
            Task { @XcodeInspectorActor [weak self] in
              guard let self else { return }

              updateStateWith(content: Self.getContent(element: element))

              axNotifications.send(.init(
                kind: notification.kind,
                element: notification.element
              ))
            }
          }
        }

        if let scrollView = element.parent, let scrollBar = scrollView.verticalScrollBar {
          let scrollViewNotifications = AXNotificationStream(
            processIdentifier: processIdentifier,
            element: scrollBar,
            notifications: [.valueChanged]
          )

          group.addTask { [weak self] in
            for await notification in scrollViewNotifications {
              try Task.checkCancellation()
              await Task.yield()
              guard let self else { return }
              axNotifications.send(.init(
                kind: .scrollPositionChanged,
                element: notification.element
              ))
            }
          }
        }

        try? await group.waitForAll()
      }
    }
  }

}

extension SourceEditorObserver {

  @XcodeInspectorActor
  private func updateStateWith(
    content: EditorInformation.SourceEditorContent? = nil,
    tabs: [String]? = nil,
    activeTab: String?? = .none,
    activeTabURL: URL?? = .none,
    isFocussed: Bool? = nil
  ) {
    let newState = EditorState(
      element: state.element,
      content: content ?? state.content,
      tabs: tabs ?? state.tabs,
      activeTab: activeTab ?? state.activeTab,
      activeTabURL: activeTabURL ?? state.activeTabURL,
      isFocussed: isFocussed ?? state.isFocussed
    )
    if newState != state {
      state = newState
    }
  }
}

// MARK: - Helpers

extension SourceEditorObserver {

  private static func convertRangeToCursorRange(
    _ range: ClosedRange<Int>,
    in lines: [String]
  ) -> CursorRange {
    guard !lines.isEmpty else { return CursorRange(start: .zero, end: .zero) }
    var consumed = 0

    var start: CursorPosition?
    var end: CursorPosition?

    for (i, line) in lines.enumerated() {
      // The range is counted in UTF8, which causes line endings like \r\n to be of length 2.
      let lineEndingAddition = line.lineEnding.utf8.count - 1
      if
        consumed <= range.lowerBound,
        range.lowerBound < consumed + line.count + lineEndingAddition
      {
        start = .init(line: i, character: range.lowerBound - consumed)
      }
      if
        consumed <= range.upperBound,
        range.upperBound < consumed + line.count + lineEndingAddition
      {
        end = .init(line: i, character: range.upperBound - consumed)
        break
      }
      consumed += line.count + lineEndingAddition
    }
    if end == nil {
      end = .init(line: lines.endIndex - 1, character: lines.last?.count ?? 0)
    }
    if start == nil {
      start = .init(line: lines.endIndex - 1, character: lines.last?.count ?? 0)
    }
    return CursorRange(start: start!, end: end!)
  }
}

extension String {
  /// The line ending of the string (for ex it can be "\r\n" instead of "\n").
  /// Getting it right is important to work with cursor positions.
  ///
  /// We are pretty safe to just check the last character here, in most case, a line ending
  /// will be in the end of the string.
  ///
  /// For other situations, we can assume that they are "\n".
  public var lineEnding: Character {
    if let last, last.isNewline { return last }
    return "\n"
  }

  /// Break a string into lines.
  public func breakLines() -> [String] {
    // Split on character for better performance.
    let lines = split(separator: lineEnding, omittingEmptySubsequences: false)
    var all = [String]()
    for (index, line) in lines.enumerated() {
      if index == lines.endIndex - 1 {
        all.append(String(line))
      } else {
        all.append(String(line) + String(lineEnding))
      }
    }
    return all
  }
}
