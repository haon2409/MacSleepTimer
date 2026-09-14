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
                    Text("Countdown: \(timerManager.timeRemainingString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Cancel Timer") {
                        timerManager.stopTimer()
                    }
                    Divider()
                }
                            
                Button("15m") { timerManager.startTimer(minutes: 15) }
                Button("30m") { timerManager.startTimer(minutes: 30) }
                Button("45m") { timerManager.startTimer(minutes: 45) }
                Button("1h") { timerManager.startTimer(minutes: 60) }
                Button("1h15m") { timerManager.startTimer(minutes: 75) }
                Button("1h30m") { timerManager.startTimer(minutes: 90) }
                Button("2h") { timerManager.startTimer(minutes: 120) }
               
                Divider()
               
                Button("Quit") {
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
    private var remainingSeconds: TimeInterval = 0
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
        self.remainingSeconds = time
        
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
        
        // --- Hiển thị kiểu digital clock (không icon) ---
        let isRedAlert = remainingSeconds <= 900
        let timeColor: NSColor = isRedAlert ? .systemRed : NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // vàng gold
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: timeColor
        ]
        
        let textSize = shortTimeString.size(withAttributes: textAttributes)
        
        let paddingH: CGFloat = 7
        let height: CGFloat = 18
        let width = textSize.width + paddingH * 2
        
        let imageSize = NSSize(width: width, height: height)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        // Nền bo tròn tối
        let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
                                  xRadius: 5, yRadius: 5)
        NSColor(calibratedWhite: 0.15, alpha: 0.95).setFill()
        bgPath.fill()
        
        // Thời gian
        let textX = paddingH
        let textY = (height - textSize.height) / 2
        shortTimeString.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)
        
        image.unlockFocus()
        
        image.isTemplate = false
        self.menuIcon = image
    }
    
    private func sleepMac() {
        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["sleepnow"]
        try? process.run()
    }
}
