//
//  DiffHelpers.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI

// MARK: - ViewSizeReader

struct ViewSizeReader<Content: View>: View {
  let content: Content
  @Binding var size: CGSize
  
  var body: some View {
    content
      .background(
        GeometryReader { geometry in
          Color.clear
            .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
      )
      .onPreferenceChange(SizePreferenceKey.self) { newSize in
        size = newSize
      }
  }
}


/// A preference key for passing size information up the SwiftUI view hierarchy.
/// This is commonly used to measure view dimensions and synchronize sizes between views,
/// such as ensuring line numbers and code content have matching heights in diff views.
struct SizePreferenceKey: PreferenceKey {
  /// The default size value when no preference has been set
  static var defaultValue: CGSize = .zero
  
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

// MARK: - View Extensions

extension View {
  func readSize(_ size: Binding<CGSize>) -> some View {
    ViewSizeReader(content: self, size: size)
  }
  
  func readingSize(_ read: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { geometry in
        Color.clear
          .preference(key: SizePreferenceKey.self, value: geometry.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self) { size in
      read(size)
    }
  }
}

// MARK: - Observable Value

@MainActor
class ObservableValue<Value: Sendable>: ObservableObject {
  @Published var value: Value
  
  init(_ initial: Value) {
    self.value = initial
  }
}

// MARK: - HoverReader

struct HoverReader<Content: View>: View {
  @ViewBuilder let content: (ObservableValue<CGPoint?>) -> Content
  @StateObject private var hoverLocation = ObservableValue<CGPoint?>(nil)
  
  var body: some View {
    content(hoverLocation)
      .onContinuousHover { phase in
        switch phase {
        case .active(let point):
          hoverLocation.value = point
        case .ended:
          hoverLocation.value = nil
        }
      }
  }
}

