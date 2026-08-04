import SwiftUI
import Foundation
import Combine
import AppKit

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
            Image(nsImage: timerManager.menuIcon)
        }
    }
}

class TimerManager: ObservableObject {
    @Published var isTimerRunning = false
    @Published var timeRemainingString = ""
    @Published var menuIcon: NSImage = NSImage()
    
    private var shortTimeString = ""
    private var remainingSeconds: TimeInterval = 0 // Biến lưu số giây thực tế
    private var timer: Timer?
    private var endTime: Date?
    
    init() {
        updateMenuIcon()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }
    
    @objc private func handleSleep() {
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
        shortTimeString = ""
        remainingSeconds = 0
        endTime = nil
        updateMenuIcon()
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
        self.remainingSeconds = time // Lưu lại số giây để tính toán màu
        
        let totalMinutesForMenu = Int(time) / 60
        let seconds = Int(time) % 60
        timeRemainingString = String(format: "%02d:%02d", totalMinutesForMenu, seconds)
        
        let totalMinutes = Int(time) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            shortTimeString = String(format: "%d:%02d", hours, minutes)
        } else {
            shortTimeString = String(format: "%d", minutes)
        }
        
        updateMenuIcon()
    }
    
    private func updateMenuIcon() {
        if !isTimerRunning {
            if let defaultIcon = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil) {
                defaultIcon.isTemplate = true
                self.menuIcon = defaultIcon
            }
            return
        }
        
        // 1. Kiểm tra mốc 15 phút (900 giây)
        let isRedAlert = remainingSeconds <= 900
        
        // 2. Chuyển màu text sang Đỏ nếu thỏa điều kiện
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .heavy),
            .foregroundColor: isRedAlert ? NSColor.systemRed : NSColor.black
        ]
        
        let textSize = shortTimeString.size(withAttributes: textAttributes)
        let requiredWidth = max(24.0, 7.0 + textSize.width + 2.0)
        
        let imageSize = NSSize(width: requiredWidth, height: 18)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        if let moon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil) {
            var config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            
            // Nếu bật màu đỏ, buộc phải tô màu mặt trăng theo hệ thống (trắng/đen)
            // vì chế độ tự động (Template) sẽ bị tắt để hiển thị được màu đỏ
            if isRedAlert {
                config = config.applying(.init(hierarchicalColor: .labelColor))
            }
            
            if let configuredMoon = moon.withSymbolConfiguration(config) {
                configuredMoon.draw(at: NSPoint(x: 0, y: 1), from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }
        
        shortTimeString.draw(at: NSPoint(x: 7, y: 6), withAttributes: textAttributes)
        
        image.unlockFocus()
        
        // 3. Tắt chế độ Template nếu đang hiển thị màu đỏ
        image.isTemplate = !isRedAlert
        
        self.menuIcon = image
    }
    
    private func sleepMac() {
        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["sleepnow"]
        try? process.run()
    }
}
