import CCAccessibilityFoundation
import CCAccessibilityServiceInterface
import AppKit
import Combine
import Foundation
import CCXcodeObserverServiceInterface

/// This class observes a single window that is a workspace.
final class WorkspaceWindowObserver: WindowObserver {

  // MARK: Lifecycle

  @XcodeInspectorActor
  init(
    accessibilityService: AccessibilityService,
    processIdentifier: Int32,
    axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>>,
    window: AXUIElement
  ) {
    self.accessibilityService = accessibilityService
    self.processIdentifier = processIdentifier
    self.axNotifications = axNotifications
    let documentURL = Self.extractDocumentURL(from: window)
    let workspaceURL = Self.extractWorkspaceURL(from: window)

    let state = WindowState(
      element: window,
      workspace: WorkspaceState(
        documentURL: documentURL,
        workspaceURL: workspaceURL,
        editors: []
      )
    )
    super.init(window: window, state: state)

    updateEditors(focusedElement: nil)
  }

  // MARK: Internal

  /// Get the URL of the workspace's current document.
  static func extractDocumentURL(
    from window: AXUIElement
  ) -> URL? {
    let path = window.document
    if let path = path?.removingPercentEncoding {
      let url = URL(
        fileURLWithPath: path
          .replacingOccurrences(of: "file://", with: "")
      )
      return url
    }
    return nil
  }

  /// Get the URL for this workspace (the xcodeproj / xcworkspace file).
  static func extractWorkspaceURL(
    from window: AXUIElement
  ) -> URL? {
    for child in window.children {
      if let description = child.description, description.starts(with: "/"), description.count > 1 {
        let path = description
        let trimmedNewLine = path.trimmingCharacters(in: .newlines)
        let url = URL(fileURLWithPath: trimmedNewLine)
        return url
      }
    }
    return nil
  }

  /// Sync the observer to match the current state of the workspace.
  @XcodeInspectorActor
  func refresh() {
    updateURLs()
  }

  @XcodeInspectorActor
  func updateURLs() {
    let documentURL = Self.extractDocumentURL(from: window)
    let workspaceURL = state.workspace?.workspaceURL ?? Self.extractWorkspaceURL(from: window)
    updateStateWith(
      workspace: state.workspace?.updatedWith(documentURL: documentURL, workspaceURL: workspaceURL)
    )
    editors.first(where: { $0.state.isFocussed })?.update(documentURL: documentURL)
  }

  @XcodeInspectorActor
  func updateEditors(focusedElement: AXUIElement?) {
    guard
      let editorArea = accessibilityService.firstChild(
        from: window,
        where: { $0.description == "editor area" },
        skipDescendants: { $0.role == kAXScrollAreaRole },
        cacheKey: "editor-area"
      )
    else {
      return
    }

    // This element is the UI element that contains all the editors in the workspace.
    // It has one child view for each editor, which contains the tabs as well as the text area.
    let editorsUIElement = accessibilityService.withCachedResult(element: editorArea, cacheKey: "editors") {
      let editorContexts = accessibilityService.children(
        from: editorArea,
        where: { $0.identifier == "editor context" },
        skipDescendants: { element in
          guard let identifier = element.identifier else { return false }
          return identifier == "jump bar" || identifier == "debug area"
        }
      )
      .compactMap { el in accessibilityService.firstParent(
        from: el,
        where: { $0.description == el.description },
        cacheKey: nil
      ) }

      return editorContexts.first?.firstParent(
        accessibilityService: accessibilityService,
        where: { $0.role == kAXSplitGroupRole },
        cacheKey: nil
      ).map { [$0] } ?? []
    }.first

    let editorChildren = editorsUIElement?.children ?? []

    editors = editorChildren.compactMap { editorWrapper -> SourceEditorObserver? in
      // Get the editor text area
      guard
        let editorElement = accessibilityService.firstChild(
          from: editorWrapper,
          where: { $0.isSourceEditor },
          cacheKey: "source-editor"
        )
      else {
        return nil
      }

      // Get the tabs info
      let tabsElements = accessibilityService
        .firstChild(from: editorWrapper, where: { $0.roleDescription == "tab group" }, cacheKey: "tab-group")?
        .children(accessibilityService: accessibilityService, where: { $0.roleDescription == "tab" }) ?? []
      let tabTitles = tabsElements.compactMap { $0.title }
      let activeTabTitle = tabsElements.first(where: { $0.doubleValue == 1 })?.title

      if let existingEditor = editors.first(where: { $0.element == editorElement }) {
        existingEditor.update(tabs: tabTitles, activeTab: activeTabTitle)
        return existingEditor
      } else {
        return SourceEditorObserver(
          processIdentifier: processIdentifier,
          element: editorElement,
          tabs: tabTitles,
          activeTab: activeTabTitle,
          activeTabURL: nil,
          axNotifications: axNotifications
        )
      }
    }


    for editor in editors {
      let isFocussed = editor.element == focusedElement
      editor.didChangeFocus(isFocussed: isFocussed)

      if isFocussed {
        editor.update(documentURL: Self.extractDocumentURL(from: window))
      }
    }

    updateStateWith(
      workspace: state.workspace?.updatedWith(
        editors: editors.map { $0.state }
      )
    )

    if let focussedEditor = editors.first(where: { $0.state.isFocussed }) {
      didFocus(on: focussedEditor)
    }
  }

  /// Handle a focus event, and start observing changes in the focus editor if any.
  @XcodeInspectorActor
  func didFocus(on editor: SourceEditorObserver) {
    guard focusedEditor !== editor else { return }
    focusedEditor = editor

    editorObservation?.cancel()
    editorObservation = nil

    editorObservation = editor.$state.sink { [weak self] newState in
      guard let self else { return }
      updateStateWith(
        workspace: state.workspace?.updatedWith(
          editors: state.workspace?.editors.map { $0.element == editor.element ? newState : $0 }
        )
      )
    }
  }

  @XcodeInspectorActor
  func updateStateWith(workspace: WorkspaceState? = nil) {
    let newState = WindowState(element: state.element, workspace: workspace)
    if newState != state {
      state = newState
    }
  }

  // MARK: Private

  private let accessibilityService: AccessibilityService
  private let processIdentifier: Int32
  private let axNotifications: AsyncPassthroughSubject<AXNotification<InstanceState>>
  private var focusedEditor: SourceEditorObserver?
  private var editors = [SourceEditorObserver]()
  private var editorObservation: AnyCancellable?

}
