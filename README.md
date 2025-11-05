# AsyncToSyncBridge

Bridge modern Swift concurrency (async/await) to completion‑handler based APIs using a tiny set of `Task` convenience initializers. Keep your existing synchronous‑style public interface while migrating internals to async/await.

## Why this exists

It isn’t common to wrap an async function with a completion handler — usually, we do the reverse. But this becomes useful when some public API can’t change yet while your implementation is moving to async/await. This package provides small, focused helpers to:

- Run an async operation in a `Task`.
- Deliver results to a completion handler.
- Choose where the completion runs (MainActor or a specific DispatchQueue).

## Features

- MainActor delivery for UI‑safe callbacks
- DispatchQueue delivery when you need a specific GCD queue
- Overloads for:
  - async throwing returning a value → `Result<T, Error>` completion
  - async throwing returning `Void` → `Error?` completion
  - async returning `Void` → `() -> Void` completion
- `@Sendable` closures and `T: Sendable` constraints to help prevent data races across concurrency boundaries

## Quick start

### MainActor delivery (no Dispatch dependency)

```swift
// Async throwing returning a value → Result<T, Error> on MainActor
Task(operation: { try await doWorkReturningValue() }) { (result: Result<MyType, Error>) in
    // runs on MainActor
}

// Async throwing returning Void → Error? on MainActor
Task(operation: { try await doWorkThrowingVoid() }) { (error: Error?) in
    // runs on MainActor; error is nil on success
}

// Async returning Void → () -> Void on MainActor
Task(operation: { await doWorkVoid() }) {
    // runs on MainActor when finished
}
