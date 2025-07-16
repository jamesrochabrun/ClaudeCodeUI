public actor AsyncPassthroughSubject<Element> {

  // MARK: Lifecycle

  deinit {
    for task in tasks { task.finish() }
  }

  public init() { }

  // MARK: Public

  public func notifications() -> AsyncStream<Element> {
    AsyncStream { [weak self] continuation in
      let task = Task { [weak self] in
        await self?.storeContinuation(continuation)
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  nonisolated
  public func send(_ element: Element) {
    Task { await _send(element) }
  }

  nonisolated
  public func finish() {
    Task { await _finish() }
  }

  // MARK: Internal

  var tasks: [AsyncStream<Element>.Continuation] = []

  func _send(_ element: Element) {
    let tasks = tasks
    for task in tasks {
      task.yield(element)
    }
  }

  func storeContinuation(_ continuation: AsyncStream<Element>.Continuation) {
    tasks.append(continuation)
  }

  func _finish() {
    let tasks = tasks
    self.tasks = []
    for task in tasks {
      task.finish()
    }
  }
}
