// IAPManager.swift
// Drop into ios/Runner/ and ensure it's included in the app target.

import Foundation
import StoreKit

@objcMembers
public class IAPManager: NSObject, SKRequestDelegate {
  // Completion returns Result<String /*base64*/, Error>
  private var refreshCompletion: ((Result<String, Error>) -> Void)?
  private var refreshRequest: SKRequest?
  private var timeoutWorkItem: DispatchWorkItem?

  public override init() {
    super.init()
  }

  deinit {
    cancelRefreshIfNeeded()
  }

  // MARK: - Receipt Loading

  /// Read receipt if present and return base64 string, or nil.
  public func loadAppStoreReceiptBase64() -> String? {
    guard let receiptUrl = Bundle.main.appStoreReceiptURL else { return nil }
    if FileManager.default.fileExists(atPath: receiptUrl.path) {
      do {
        let data = try Data(contentsOf: receiptUrl)
        return data.base64EncodedString()
      } catch {
        // Return nil on read error
        return nil
      }
    }
    return nil
  }

  // MARK: - Refresh + Return Base64

  /// Refresh the app store receipt and return the base64 via completion.
  /// - Parameters:
  ///   - force: if true, always trigger a refresh request even if a receipt exists.
  ///   - timeout: safety timeout before we fail the refresh request.
  ///   - completion: completion called on main queue with Result(base64, Error).
  public func refreshReceiptAndReturnBase64(
  force: Bool = false,
  timeout: TimeInterval = 30.0, // 🔹 bumped to 30s
  completion: @escaping (Result<String, Error>) -> Void
) {
  if !force,
     let existing = loadAppStoreReceiptBase64(),
     !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    NSLog("DEBUG: IAPManager - Using existing receipt.")
    DispatchQueue.main.async {
      completion(.success(existing))
    }
    return
  }

  cancelRefreshIfNeeded()
  refreshCompletion = completion

  DispatchQueue.main.async {
    NSLog("DEBUG: IAPManager - Starting SKReceiptRefreshRequest...")
    let req = SKReceiptRefreshRequest()
    req.delegate = self
    self.refreshRequest = req
    req.start()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      if let cb = self.refreshCompletion {
        self.refreshCompletion = nil
        let err = NSError(
          domain: "IAPManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Receipt refresh timed out (no response from Apple)"]
        )
        NSLog("DEBUG: IAPManager - Timeout: \(err.localizedDescription)")
        DispatchQueue.main.async {
          cb(.failure(err))
        }
      }
    }
    self.timeoutWorkItem = workItem
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: workItem)
  }
}


  // MARK: - SKRequestDelegate

  // Called when refresh request finishes successfully
public func requestDidFinish(_ request: SKRequest) {
  NSLog("DEBUG: IAPManager - requestDidFinish called.")
  timeoutWorkItem?.cancel()
  timeoutWorkItem = nil

  if let existing = loadAppStoreReceiptBase64(),
     !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    NSLog("DEBUG: IAPManager - Receipt successfully refreshed.")
    if let cb = refreshCompletion {
      refreshCompletion = nil
      DispatchQueue.main.async { cb(.success(existing)) }
    }
  } else {
    NSLog("DEBUG: IAPManager - No receipt found after refresh.")
    if let cb = refreshCompletion {
      refreshCompletion = nil
      let err = NSError(
        domain: "IAPManager",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "No receipt found after refresh"]
      )
      DispatchQueue.main.async { cb(.failure(err)) }
    }
  }
  refreshRequest = nil
}

public func request(_ request: SKRequest, didFailWithError error: Error) {
  NSLog("DEBUG: IAPManager - Receipt refresh failed: \(error.localizedDescription)")
  timeoutWorkItem?.cancel()
  timeoutWorkItem = nil

  if let cb = refreshCompletion {
    refreshCompletion = nil
    DispatchQueue.main.async { cb(.failure(error)) }
  }
  refreshRequest = nil
}


  // Cancel any ongoing refresh + clear completion
  private func cancelRefreshIfNeeded() {
    // Cancel SKRequest if possible - SKRequest has no cancel API, but we can null references
    refreshRequest = nil

    if let work = timeoutWorkItem {
      work.cancel()
      timeoutWorkItem = nil
    }

    // If there's a pending completion, call it with a cancellation error to avoid leaks
    if let cb = refreshCompletion {
      refreshCompletion = nil
      let err = NSError(domain: "IAPManager", code: -999, userInfo: [NSLocalizedDescriptionKey: "Receipt refresh cancelled"])
      DispatchQueue.main.async {
        cb(.failure(err))
      }
    }
  }
}
