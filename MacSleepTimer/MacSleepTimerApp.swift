import SwiftUI
import Foundation
import Combine

@main
struct MacSleepTimerApp: App {
    @StateObject private var timerManager = TimerManager()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading) {
                if timerManager.isTimerRunning {
                    Text("Đang đếm ngược: \(timerManager.timeRemainingString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Hủy hẹn giờ") {
                        timerManager.stopTimer()
                    }
                    Divider()
                }
                
                Button("Sleep sau 1 phút (Test)") { timerManager.startTimer(minutes: 1) }
                Button("Sleep sau 15 phút") { timerManager.startTimer(minutes: 15) }
                Button("Sleep sau 30 phút") { timerManager.startTimer(minutes: 30) }
                Button("Sleep sau 60 phút") { timerManager.startTimer(minutes: 60) }
                Button("Sleep sau 90 phút") { timerManager.startTimer(minutes: 90) }
                Button("Sleep sau 120 phút") { timerManager.startTimer(minutes: 120) }
                
                Divider()
                
                Button("Thoát ứng dụng") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        } label: {
            HStack {
                Image(systemName: "moon.zzz.fill")
                if timerManager.isTimerRunning {
                    Text(timerManager.timeRemainingString)
                        .font(.body.monospacedDigit())
                }
            }
        }
    }
}

class TimerManager: ObservableObject {
    @Published var isTimerRunning = false
    @Published var timeRemainingString = ""
    
    private var timer: Timer?
    private var endTime: Date?
    
    init() {
        // Lắng nghe khi hệ thống bắt đầu đi vào chế độ ngủ
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }
    
    @objc private func handleSleep() {
        // Tự động hủy timer khi máy đi ngủ
        DispatchQueue.main.async {
            self.stopTimer()
        }
    }
    
    func startTimer(minutes: Int) {
        stopTimer()
        isTimerRunning = true
        let duration = TimeInterval(minutes * 60)
        endTime = Date().addingTimeInterval(duration)
        updateTimeString()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        if let currentTimer = timer {
            RunLoop.main.add(currentTimer, forMode: .common)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        timeRemainingString = ""
        endTime = nil
    }
    
    private func tick() {
        guard let endTime = endTime else { return }
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            stopTimer()
            sleepMac()
        } else {
            updateTimeString(remaining: remaining)
        }
    }
    
    private func updateTimeString(remaining: TimeInterval? = nil) {
        let time = remaining ?? (endTime?.timeIntervalSinceNow ?? 0)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        timeRemainingString = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func sleepMac() {
        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["sleepnow"]
        try? process.run()
    }
}
