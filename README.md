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
  - async returning a value → `(T) -> Void` completion
  - async returning `Void` → `() -> Void` completion
- `@Sendable` closures and `T: Sendable` constraints to help prevent data races across concurrency boundaries

## Quick start

Add package dependency

### MainActor delivery (no Dispatch dependency)

```swift
import AsyncToSyncBridge

// Suppose you have "Modern Concurrency" API
    func didReceiveRemoteNotification(userInfo:[AnyHashable: Any]) async -> UIBackgroundFetchResult {
        // ...
        return .newData
    }

// But you need to use it inside a synchronous completion-based API, i.e. `UIApplicationDelegate`
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Then you could write:             
        Task(operation: { await didReceiveRemoteNotification(userInfo:userInfo) }) { value in
            completionHandler(value)
        }
        // Or even shorter – it depends on whether you prefer shorthand syntax.             
    }
```

And other overloads for other types of completions are available:
```swift
// Async throwing returning a value → Result<T, Error> on MainActor
Task(operation: { try await doWorkReturningValue() }) { (result: Result<MyType, Error>) in
    // runs on MainActor
}

// Async throwing returning Void → Error? on MainActor
Task(operation: { try await doWorkThrowingVoid() }) { (error: Error?) in
    // runs on MainActor; error is nil on success
}

// Async returning a value → (T) -> Void on MainActor
Task(operation: { await doWorkReturningValue() }) { value in
    // runs on MainActor when finished
}

// Async returning Void → () -> Void on MainActor
Task(operation: { await doWorkVoid() }) {
    // runs on MainActor when finished
}
```

## Use cases
The library can be helpful when:
1.    Apple frameworks mandate completion handlers (WidgetKit, some UIKit patterns) - [example](https://forums.swift.org/t/how-to-call-completion-handler-after-async-function/60040)
2.    Public API compatibility is non-negotiable (SDKs, frameworks)
3.    Gradual migration from legacy codebases with mixed paradigms
4.    Objective-C interoperability requirements (completion handlers bridge better than async/await)
5.    Testing infrastructure hasn’t fully adopted Swift Concurrency yet
The library eliminates boilerplate, ensures thread safety with `Sendable` constraints, and defaults to `MainActor` delivery for UI safety—making it significantly better than ad-hoc `Task` wrapping.
