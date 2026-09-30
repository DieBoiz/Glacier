//
//  TaskTimeout.swift
//  Ice
//

import Foundation

extension Task where Failure == any Error {
    /// Runs the given throwing operation asynchronously as part of a new top-level task
    /// on behalf of the current actor.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///   - timeout: The amount of time to wait before throwing a ``TaskTimeoutError``.
    ///   - tolerance: The tolerance of the clock.
    ///   - clock: The clock to use in the timeout operation.
    ///   - operation: The operation to perform.
    @discardableResult
    init<C: Clock>(
        priority: TaskPriority? = nil,
        timeout: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
        operation: @escaping @Sendable () async throws -> Success
    ) {
        self.init(priority: priority) {
            try await Task.run(operation: operation, withTimeout: timeout, tolerance: tolerance, clock: clock)
        }
    }

    /// Runs the given throwing operation asynchronously as part of a new top-level task.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///   - timeout: The amount of time to wait before throwing a ``TaskTimeoutError``.
    ///   - tolerance: The tolerance of the clock.
    ///   - clock: The clock to use in the timeout operation.
    ///   - operation: The operation to perform.
    ///
    /// - Returns: A reference to the task.
    @discardableResult
    static func detached<C: Clock>(
        priority: TaskPriority? = nil,
        timeout: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
        operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        detached(priority: priority) {
            try await run(operation: operation, withTimeout: timeout, tolerance: tolerance, clock: clock)
        }
    }

    private static func run<C: Clock>(
        operation: @escaping @Sendable () async throws -> Success,
        withTimeout timeout: C.Instant.Duration,
        tolerance: C.Instant.Duration?,
        clock: C
    ) async throws -> Success {
        let state = TaskTimeoutState<Success>()
        let operationTask = _Concurrency.Task {
            do {
                state.finish(with: .success(try await operation()))
            } catch {
                state.finish(with: .failure(error))
            }
        }
        let timeoutTask = _Concurrency.Task {
            try await _Concurrency.Task.sleep(for: timeout, tolerance: tolerance, clock: clock)
            state.finish(with: .failure(TaskTimeoutError()))
        }
        defer {
            operationTask.cancel()
            timeoutTask.cancel()
        }
        return try await withTaskCancellationHandler {
            try await state.result()
        } onCancel: {
            state.finish(with: .failure(_Concurrency.CancellationError()))
        }
    }
}

// MARK: - TaskTimeoutState

/// A one-shot state that resumes its waiter with the first result it receives,
/// without waiting on operations that don't respond to cancellation.
private final class TaskTimeoutState<Success>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<Success, any Error>?
    private var continuation: CheckedContinuation<Success, any Error>?

    func finish(with result: Result<Success, any Error>) {
        lock.lock()
        guard storedResult == nil else {
            lock.unlock()
            return
        }
        storedResult = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    func result() async throws -> Success {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let storedResult {
                lock.unlock()
                continuation.resume(with: storedResult)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }
}

// MARK: - TaskTimeoutError

/// An error that indicates that a task timed out.
struct TaskTimeoutError: Error, CustomStringConvertible {
    let description = "Task timed out before completion"
}

// MARK: TaskTimeoutError: LocalizedError
extension TaskTimeoutError: LocalizedError {
    var errorDescription: String? { description }
}
