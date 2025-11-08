/// AsyncToSyncBridge
///
/// A tiny set of `Task` convenience initializers that bridge modern async/await code
/// to completion-handler based callers. These helpers execute an async `operation`
/// in a new `Task` and then invoke a completion handler on a chosen executor
/// (either the `MainActor` or a specified `DispatchQueue`).
///
/// The closures in these APIs are annotated `@Sendable` and generic values are
/// constrained to `Sendable` where appropriate. This helps the compiler diagnose
/// and prevent data races that can occur when crossing concurrency domains.
///
/// Choose the MainActor variant when you want to return results to UI code with
/// actor isolation. Choose the Dispatch variant if you must deliver on a specific
/// GCD queue. Prefer `MainActor.run` to `DispatchQueue.main` when you need actor
/// semantics.

extension Task where Success == Void, Failure == any Error {
    /// Bridges an async throwing operation that returns a value to a completion-handler API.
    ///
    /// Runs `operation` in a new `Task` and delivers its `Result` to `completion` on the
    /// `MainActor`, making it safe to update UI.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async throwing work to perform. Must be `@Sendable` and return a
    ///     `Sendable` value.
    ///   - completion: A `@Sendable` closure called on the `MainActor` with the `Result` of
    ///     `operation`.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Important: If the task is cancelled and `operation` throws `CancellationError`, that
    ///   error is forwarded to `completion(.failure(_))`.
    /// - Concurrency: Parameters are `@Sendable` and `T` is constrained to `Sendable` to avoid
    ///   data races when crossing concurrency domains.
    /// - SeeAlso: The Dispatch-based overloads that deliver callbacks on a specific `DispatchQueue`.
    @discardableResult @inlinable
    public init<T: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> T,
        completion: @escaping @Sendable (Result<T, Error>) -> Void
    ) {
        self.init(priority: priority) {
            do {
                let result: Result<T, Error>
                do {
                    let value = try await operation()
                    result = .success(value)
                } catch {
                    result = .failure(error)
                }
                await MainActor.run {
                    completion(result)
                }
            }
        }
    }
    
    /// Bridges an async throwing `Void` operation to a completion-handler API that reports an optional error.
    ///
    /// Runs `operation` in a new `Task` and delivers `completion(nil)` on success or
    /// `completion(error)` on failure on the `MainActor`, making it safe to update UI.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async throwing work to perform. Must be `@Sendable`.
    ///   - completion: A `@Sendable` closure called on the `MainActor` with `nil` on success or the thrown `Error` on failure.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Important: If the task is cancelled and `operation` throws `CancellationError`, that error is forwarded to `completion` as a non-nil error.
    /// - Concurrency: Parameters are `@Sendable` to avoid data races when crossing concurrency domains.
    /// - SeeAlso: The Dispatch-based overload that delivers callbacks on a specific `DispatchQueue`.
    @discardableResult @inlinable
    public init(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) {
        self.init(priority: priority) {
            do {
                try await operation()
                await MainActor.run {
                    completion(nil)
                }
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
        }
    }
    
}

extension Task where Success == Void, Failure == Never {
    
    /// Bridges an async  operation that returns a value to a completion-handler API with no error.
    ///
    /// Runs `operation` in a new `Task` and delivers its returning value, i.e.  calls `completion(value)` on the `MainActor` when it finishes,
    /// making it safe to update UI.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async work to perform. Must be `@Sendable`.
    ///   - completion: A `@Sendable` closure called on the `MainActor` when the operation completes.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Concurrency: Parameters are `@Sendable`  and `T` is constrained to `Sendable` to avoid data races when crossing concurrency domains.
    /// - SeeAlso: The Dispatch-based overload that delivers callbacks on a specific `DispatchQueue`.
    @discardableResult @inlinable
    public init<T: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> T,
        completion: @escaping @Sendable (T) -> Void
    ) {
        self.init(priority: priority) {
            let value = await operation()
            await MainActor.run {
                completion(value)
            }
        }
    }
    
    /// Bridges an async `Void` operation to a completion-handler API with no error.
    ///
    /// Runs `operation` in a new `Task` and calls `completion()` on the `MainActor` when it finishes,
    /// making it safe to update UI.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async work to perform. Must be `@Sendable`.
    ///   - completion: A `@Sendable` closure called on the `MainActor` when the operation completes.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Concurrency: Parameters are `@Sendable` to avoid data races when crossing concurrency domains.
    /// - SeeAlso: The Dispatch-based overload that delivers callbacks on a specific `DispatchQueue`.
    @discardableResult @inlinable
    public init(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> Void,
        completion: @escaping @Sendable () -> Void
    ) {
        self.init(priority: priority) {
            await operation()
            await MainActor.run {
                completion()
            }
        }
    }

}

#if canImport(Dispatch)
import Dispatch

extension Task {
    /// Bridges an async throwing operation that returns a value to a completion-handler API,
    /// delivering the completion on a specific `DispatchQueue`.
    ///
    /// Runs `operation` in a new `Task` and invokes `completion` on `queue` with the
    /// `Result` of the operation.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async throwing work to perform. Must be `@Sendable` and return a
    ///     `Sendable` value.
    ///   - queue: The `DispatchQueue` on which `completion` is executed. Defaults to `.main`.
    ///   - completion: A `@Sendable` closure invoked on `queue` with the `Result`.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Note: Passing `.main` uses the main GCD queue. If you need `@MainActor` isolation,
    ///   prefer the MainActor overload (without Dispatch) which uses `await MainActor.run { ... }`.
    /// - Concurrency: Parameters are `@Sendable` and `T` is constrained to `Sendable` to avoid
    ///   data races when crossing concurrency domains.
    @discardableResult @inlinable
    public init<T: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> T,
        queue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<T, Error>) -> Void
    ) where Success == Void, Failure == any Error {
        self.init(priority: priority) {
            do {
                let value = try await operation()
                queue.async {
                    completion(.success(value))
                }
            } catch {
                queue.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Bridges an async throwing `Void` operation to a completion-handler API that reports an optional error,
    /// delivering the completion on a specific `DispatchQueue`.
    ///
    /// Runs `operation` in a new `Task` and invokes `completion(nil)` on success or
    /// `completion(error)` on failure, executing on `queue`.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async throwing work to perform. Must be `@Sendable`.
    ///   - queue: The `DispatchQueue` on which `completion` is executed. Defaults to `.main`.
    ///   - completion: A `@Sendable` closure invoked on `queue` with `nil` on success or an `Error` on failure.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Note: If you need `@MainActor` isolation instead of GCD main queue delivery, prefer the
    ///   MainActor overload pattern (see the value-returning variant above) or adapt this to use `MainActor.run`.
    @discardableResult @inlinable
    public init(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> Void,
        queue: DispatchQueue = .main,
        completion: @escaping @Sendable (Error?) -> Void
    ) where Success == Void, Failure == any Error {
        self.init(priority: priority) {
            do {
                try await operation()
                queue.async {
                    completion(nil)
                }
            } catch {
                queue.async {
                    completion(error)
                }
            }
        }
    }
    
    /// Bridges an async operation that returns a value to a completion-handler API,
    /// delivering the completion on a specific `DispatchQueue`.
    ///
    /// Runs `operation` in a new `Task` and invokes `completion` on `queue` with the
    /// `Result` of the operation.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async work to perform. Must be `@Sendable` and return a
    ///     `Sendable` value.
    ///   - queue: The `DispatchQueue` on which `completion` is executed. Defaults to `.main`.
    ///   - completion: A `@Sendable` closure invoked on `queue` with the resulting value.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Note: Passing `.main` uses the main GCD queue. If you need `@MainActor` isolation,
    ///   prefer the MainActor overload (without Dispatch) which uses `await MainActor.run { ... }`.
    /// - Concurrency: Parameters are `@Sendable` and `T` is constrained to `Sendable` to avoid
    ///   data races when crossing concurrency domains.
    @discardableResult @inlinable
    public init<T: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> T,
        queue: DispatchQueue = .main,
        completion: @escaping @Sendable (T) -> Void
    ) where Success == Void, Failure == Never {
        self.init(priority: priority) {
            let value = await operation()
            queue.async {
                completion(value)
            }
        }
    }
    
    /// Bridges an async `Void` operation to a completion-handler API with no error, delivering the
    /// completion on a specific `DispatchQueue`.
    ///
    /// Runs `operation` in a new `Task` and invokes `completion()` on `queue` when it finishes.
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the created task.
    ///   - operation: The async work to perform. Must be `@Sendable`.
    ///   - queue: The `DispatchQueue` on which `completion` is executed. Defaults to `.main`.
    ///   - completion: A `@Sendable` closure invoked on `queue` when the operation completes.
    /// - Returns: The created `Task`, which you may cancel.
    /// - Note: If you need `@MainActor` isolation instead of GCD main queue delivery, consider
    ///   using `await MainActor.run { completion() }`.
    @discardableResult @inlinable
    public init(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> Void,
        queue: DispatchQueue = .main,
        completion: @escaping @Sendable () -> Void
    ) where Success == Void, Failure == Never {
        self.init(priority: priority) {
            await operation()
            queue.async {
                completion()
            }
        }
    }

}
#endif
