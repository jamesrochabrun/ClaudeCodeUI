import Foundation
import CCAccessibilityFoundation

// MARK: - SourceLineAnnotation

/// A struct that represents a line annotation with its associated file information.
public struct SourceLineAnnotation: Equatable, Sendable {

  // MARK: Lifecycle

  public init(
    annotation: EditorInformation.LineAnnotation,
    fileURL: URL?,
    fileName: String?
  ) {
    self.annotation = annotation
    self.fileURL = fileURL
    self.fileName = fileName
  }

  // MARK: Public

  /// The underlying line annotation.
  public let annotation: EditorInformation.LineAnnotation
  /// The URL of the file containing the annotation.
  public let fileURL: URL?
  /// The name of the file containing the annotation.
  public let fileName: String?

  /// Whether this annotation represents an error.
  public var isError: Bool {
    annotation.type.lowercased().contains("error")
  }

  /// Whether this annotation represents a warning.
  public var isWarning: Bool {
    annotation.type.lowercased().contains("warning")
  }
}

// MARK: - SourceLineAnnotationCollection

/// A collection of source line annotations with filtering capabilities.
public struct SourceLineAnnotationCollection: Equatable, Sendable {

  // MARK: Lifecycle

  public init(annotations: [SourceLineAnnotation]) {
    self.annotations = annotations
  }

  // MARK: Public

  /// All annotations in the collection.
  public let annotations: [SourceLineAnnotation]

  /// All error annotations in the collection.
  public var errors: [SourceLineAnnotation] {
    annotations.filter(\.isError)
  }

  /// All warning annotations in the collection.
  public var warnings: [SourceLineAnnotation] {
    annotations.filter(\.isWarning)
  }

  /// A formatted XML description of all annotations in the collection.
  public var description: String? {
    let annotationsXML = annotations.map { annotation in
      """
      <annotation>
        <type>\(annotation.annotation.type)</type>
        <line>\(annotation.annotation.line)</line>
        <message>\(annotation.annotation.message)</message>
        <fileURL>\(annotation.fileURL?.absoluteString ?? "")</fileURL>
        <fileName>\(annotation.fileName ?? "")</fileName>
      </annotation>
      """
    }.joined(separator: "\n")

    guard !annotationsXML.isEmpty else {
      return nil
    }
    return "<annotations>\n\(annotationsXML)\n</annotations>"
  }

  /// Returns annotations of a specific type.
  /// - Parameter type: The type of annotations to filter for.
  /// - Returns: An array of annotations matching the specified type.
  public func annotations(ofType type: String) -> [SourceLineAnnotation] {
    annotations.filter { $0.annotation.type.lowercased().contains(type.lowercased()) }
  }

  /// Returns annotations grouped by file URL.
  /// - Returns: A dictionary mapping file URLs to arrays of annotations.
  public func groupedByFile() -> [URL?: [SourceLineAnnotation]] {
    Dictionary(grouping: annotations) { $0.fileURL }
  }

  /// Returns annotations sorted by severity (errors first) and then by line number.
  /// - Returns: A sorted array of annotations.
  public func sortedBySeverityAndLine() -> [SourceLineAnnotation] {
    annotations.sorted { first, second in
      if first.isError, !second.isError {
        true
      } else if !first.isError, second.isError {
        false
      } else {
        first.annotation.line < second.annotation.line
      }
    }
  }

}

// MARK: - SourceLineAnnotationProvider

/// A protocol for providing access to source line annotations.
public protocol SourceLineAnnotationProvider {
  /// Returns annotations from the currently focused editor.
  /// - Parameter state: The current XcodeObserver state.
  /// - Returns: A collection of annotations from the current editor.
  func getAnnotationsForCurrentEditor(from state: XcodeObserver.State) -> SourceLineAnnotationCollection

  /// Returns annotations from all open editors.
  /// - Parameter state: The current XcodeObserver state.
  /// - Returns: A collection of annotations from all editors.
  func getAnnotationsForAllEditors(from state: XcodeObserver.State) -> SourceLineAnnotationCollection

  /// Returns annotations for a specific file.
  /// - Parameters:
  ///   - fileURL: The URL of the file to get annotations for.
  ///   - state: The current XcodeObserver state.
  /// - Returns: A collection of annotations for the specified file.
  func getAnnotations(forFileURL fileURL: URL, from state: XcodeObserver.State) -> SourceLineAnnotationCollection
}

// MARK: - DefaultSourceLineAnnotationProvider

/// Default implementation of the SourceLineAnnotationProvider protocol.
public class DefaultSourceLineAnnotationProvider: SourceLineAnnotationProvider {

  // MARK: Lifecycle

  public init() {
    // No dependencies needed for stateless implementation
  }

  // MARK: Public

  public func getAnnotationsForCurrentEditor(from state: XcodeObserver.State) -> SourceLineAnnotationCollection {
    // Find the focused editor
    guard case .known(let instances) = state else {
      return SourceLineAnnotationCollection(annotations: [])
    }

    let focusedEditor = instances.flatMap { instance in
      instance.windows.compactMap { window in
        window.workspace?.editors.first { $0.isFocussed }
      }
    }.first

    if let editor = focusedEditor {
      return SourceLineAnnotationCollection(
        annotations: editor.content.lineAnnotations.map {
          SourceLineAnnotation(
            annotation: $0,
            fileURL: editor.activeTabURL,
            fileName: editor.activeTab
          )
        }
      )
    }

    return SourceLineAnnotationCollection(annotations: [])
  }

  public func getAnnotationsForAllEditors(from state: XcodeObserver.State) -> SourceLineAnnotationCollection {
    guard case .known(let instances) = state else {
      return SourceLineAnnotationCollection(annotations: [])
    }

    let allAnnotations = instances.flatMap { instance in
      instance.windows.compactMap { window in
        window.workspace?.editors.flatMap { editor in
          editor.content.lineAnnotations.map {
            SourceLineAnnotation(
              annotation: $0,
              fileURL: editor.activeTabURL,
              fileName: editor.activeTab
            )
          }
        }
      }.flatMap { $0 }
    }

    return SourceLineAnnotationCollection(annotations: allAnnotations)
  }

  public func getAnnotations(forFileURL fileURL: URL, from state: XcodeObserver.State) -> SourceLineAnnotationCollection {
    guard case .known(let instances) = state else {
      return SourceLineAnnotationCollection(annotations: [])
    }

    let fileAnnotations = instances.flatMap { instance in
      instance.windows.compactMap { window in
        window.workspace?.editors.filter { editor in
          editor.activeTabURL == fileURL
        }.flatMap { editor in
          editor.content.lineAnnotations.map {
            SourceLineAnnotation(
              annotation: $0,
              fileURL: editor.activeTabURL,
              fileName: editor.activeTab
            )
          }
        }
      }.flatMap { $0 }
    }

    return SourceLineAnnotationCollection(annotations: fileAnnotations)
  }
}

// MARK: - SourceLineAnnotationProviding

/// A protocol for providing access to a SourceLineAnnotationProvider.
public protocol SourceLineAnnotationProviding {
  var sourceLineAnnotationProvider: SourceLineAnnotationProvider { get }
}
