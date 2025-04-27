import Foundation
import WatchKit
import Combine

// Service to manage WKExtendedRuntimeSession for background execution
class ExtendedRuntimeManager: NSObject, WKExtendedRuntimeSessionDelegate, ObservableObject {
    
    private var session: WKExtendedRuntimeSession?
    @Published var isSessionRunning: Bool = false

    override init() {
        super.init()
        print("ExtendedRuntimeManager 初始化完成。")
    }

    // MARK: - Session Management
    func startSession() {
        guard !isSessionRunning else {
            print("ExtendedRuntimeManager: Session 已在運行。")
            return
        }

        session?.invalidate()

        // Explicitly create a workout processing session
        session = WKExtendedRuntimeSession()
        session?.delegate = self
        // No need to explicitly set type for default init for workout-processing?
        // Let's try the default init first, as WKExtendedRuntimeSession defaults might cover workout if capability is set.
        // If this fails, we might need HKWorkoutSession as well.
        session?.start()
        print("ExtendedRuntimeManager: 請求啟動 Workout Processing Session...")
    }

    func stopSession() {
        guard let currentSession = session else {
            print("ExtendedRuntimeManager: 沒有正在運行的 Session 可以停止。")
            isSessionRunning = false // Ensure state is correct
            return
        }
        print("ExtendedRuntimeManager: 請求停止 Session...")
        currentSession.invalidate()
        // Delegate method will set session = nil and isSessionRunning = false
    }

    // MARK: - WKExtendedRuntimeSessionDelegate Methods
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("ExtendedRuntimeManager: Session 已成功啟動。")
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // This should ideally not happen if we manage the session duration correctly
        // (e.g., stop it when the nap timer finishes or is cancelled).
        print("ExtendedRuntimeManager: Session 即將過期！")
        // We might want to stop related services here if this occurs unexpectedly.
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        // Add more detailed logging
        print("ExtendedRuntimeManager: Session 失效。原因: \(reason.rawValue) - \(invalidationReasonString(reason))")
        if let error = error as NSError? { // Try casting to NSError for more details
            print("ExtendedRuntimeManager: Session 失效錯誤: \(error.localizedDescription)")
            print("ExtendedRuntimeManager: Error Domain: \(error.domain), Code: \(error.code)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("ExtendedRuntimeManager: Underlying Error: \(underlyingError.localizedDescription)")
                print("ExtendedRuntimeManager: Underlying Domain: \(underlyingError.domain), Code: \(underlyingError.code)")
            }
            print("ExtendedRuntimeManager: Error UserInfo: \(error.userInfo)")
        } else if let error = error {
             print("ExtendedRuntimeManager: Session 失效錯誤 (非 NSError): \(error.localizedDescription)")
        }
        
        // Reset state
        session = nil
        DispatchQueue.main.async {
             self.isSessionRunning = false
        }
        
        // TODO: Potentially notify ViewModel or handle based on reason?
        // For example, if reason is .sessionEnded or .resourceConstraint
    }
    
    // Helper function to convert reason enum to string (Simplified to ensure compilation)
    private func invalidationReasonString(_ reason: WKExtendedRuntimeSessionInvalidationReason) -> String {
        // Temporarily rely on @unknown default to bypass compiler issues with case names.
        // We can refine this later based on observed rawValues during testing.
        switch reason {
        // Remove specific cases for now
        /*
        case .sessionEnded: return "Session Ended"
        case .forceEnded: return "System Force Ended"
        case .userEnded: return "User Ended"
        case .resourceConstraint: return "Resource Constraint"
        case .backgroundModeSuspended: return "Background Mode Suspended"
        case .backgroundModeDenied: return "Background Mode Denied"
        case .extensionRequestDenied: return "Extension Request Denied"
        */
        @unknown default:
            return "Unknown Reason (rawValue: \(reason.rawValue))"
        }
    }
} 