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

        // Invalidate any existing session just in case
        session?.invalidate()

        session = WKExtendedRuntimeSession()
        session?.delegate = self
        session?.start()
        print("ExtendedRuntimeManager: 請求啟動 Session...")
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
        print("ExtendedRuntimeManager: Session 失效。原因: \(reason.rawValue)")
        if let error = error {
            print("ExtendedRuntimeManager: Session 失效錯誤: \(error.localizedDescription)")
        }
        
        // Reset state
        session = nil
        DispatchQueue.main.async {
             self.isSessionRunning = false
        }
        
        // TODO: Potentially notify ViewModel or handle based on reason?
        // For example, if reason is .sessionEnded or .resourceConstraint
    }
} 