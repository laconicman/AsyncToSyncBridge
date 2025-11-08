# AsyncToSyncBridge

Bridge modern Swift concurrency (async/await) to completion‑handler based APIs using a tiny set of `Task` convenience initializers. Keep your existing synchronous‑style public interface while migrating internals to async/await.

## Why this exists

It isn’t common to wrap an async function with a completion handler — usually, we do the reverse. But this becomes useful when some public API can’t change yet while your implementation is moving to async/await. This package provides small, focused helpers to:

- Run an async operation in a `Task`.
- Deliver results to a completion handler.
- Choose where the completion runs (MainActor or a specific DispatchQueue).
- Avoid boilerplate and reduce the risk of incorrect callback queues.

## Features

- **Unlabeled `operation` closure** for ergonomic, trailing closure syntax (just like Swift’s native `Task` initializers)
- **MainActor delivery** for UI‑safe callbacks using `await MainActor.run { ... }`
- **DispatchQueue delivery** when you need a specific GCD queue
- Overloads for:
  - async throwing returning a value → `Result<T, Error>` completion
  - async throwing returning `Void` → `Error?` completion
  - async returning a value → `(T) -> Void` completion
  - async returning `Void` → `() -> Void` completion
- `@Sendable` closures and `T: Sendable` constraints to help prevent data races across concurrency boundaries
- Public APIs are marked `@inlinable` for maximal inlining and performance

## Use cases
The library can be helpful when:
1.    Apple frameworks mandate completion handlers (WidgetKit, some UIKit patterns) - [example](https://forums.swift.org/t/how-to-call-completion-handler-after-async-function/60040)
2.    Public API compatibility is non-negotiable (SDKs, frameworks)
3.    Gradual migration from legacy codebases with mixed paradigms
4.    Objective-C interoperability requirements (completion handlers bridge better than async/await)
5.    Testing infrastructure hasn’t fully adopted Swift Concurrency yet
The library eliminates boilerplate, ensures thread safety with `Sendable` constraints, and defaults to `MainActor` delivery for UI safety—making it significantly better than ad-hoc `Task` wrapping.

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
    // With trailing closure, this looks like native Task initializers:
    Task {
        await didReceiveRemoteNotification(userInfo:userInfo)
    } completion: { value in
        completionHandler(value)
    }
}

And other overloads for other types of completions are available:

```swift
// Async throwing returning a value → Result<T, Error> on MainActor
Task {
    try await doWorkReturningValue()
} completion: { (result: Result<MyType, Error>) in
    // runs on MainActor
}

// Async throwing returning Void → Error? on MainActor
Task {
    try await doWorkThrowingVoid()
} completion: { (error: Error?) in
    // runs on MainActor; error is nil on success
}

// Async returning a value → (T) -> Void on MainActor
Task {
    await doWorkReturningValue()
} completion: { value in
    // runs on MainActor when finished
}

// Async returning Void → () -> Void on MainActor
Task {
    await doWorkVoid()
} completion: {
    // runs on MainActor when finished
}
```

## DispatchQueue Delivery

If you must call your completion handler on a specific DispatchQueue (for example, a background queue, or for legacy code):

## Implementation notes

- Public API is marked @inlinable for performance and cross-module optimization.
- Trailing closure syntax makes adoption seamless and familiar for Swift developers.
- The difference between MainActor and .main queue is clearly documented and enforced at the API level.

```swift
Task(queue: .main) {
    try await doWorkReturningValue()
} completion: { (result: Result<MyType, Error>) in
    // runs on DispatchQueue.main (GCD), NOT MainActor
}
```

### Note:
- DispatchQueue.main.async is not the same as await MainActor.run {}.
- Use the MainActor overloads for UI updates and actor isolation.
- Use the DispatchQueue variants for legacy queue requirements.
