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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Chỉ thực hiện dừng timer nếu timer đang trong trạng thái chạy
            if self.isTimerRunning {
                self.stopTimer()
            }
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
                
                let yellowColor = NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .bold)
                    .applying(.init(hierarchicalColor: yellowColor))
                
                let sourceIcon = defaultIcon.withSymbolConfiguration(config) ?? defaultIcon
                
                // 1. Tạo một khung ảnh trống có kích thước chuẩn của thanh menu (22x22)
                let canvasSize = NSSize(width: 22, height: 22)
                let canvasImage = NSImage(size: canvasSize)
                
                canvasImage.lockFocus()
                
                let iconSize = sourceIcon.size
                let x = (canvasSize.width - iconSize.width) / 2
                
                // 2. Đẩy toạ độ Y lên trên thông qua yOffset
                let yOffset: CGFloat = 1.0 // Tăng/giảm số này để điều chỉnh độ cao (VD: 1.0, 2.0, 3.0)
                let y = (canvasSize.height - iconSize.height) / 2 + yOffset
                
                // Vẽ icon vào khung ảnh trống
                sourceIcon.draw(in: NSRect(x: x, y: y, width: iconSize.width, height: iconSize.height))
                
                canvasImage.unlockFocus()
                
                canvasImage.isTemplate = false
                self.menuIcon = canvasImage
            }
            return
        }
        
        // --- Hiển thị kiểu digital clock (không icon) ---
        let isRedAlert = remainingSeconds <= 900
        let timeColor: NSColor = isRedAlert ? .systemRed : NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // vàng gold
        
        // 1. Giảm độ dày font chữ xuống .medium (hoặc .regular) và giữ size 13
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: timeColor
        ]
        
        let textSize = shortTimeString.size(withAttributes: textAttributes)
        
        // 2. Tăng lề ngang và chiều cao khung bao
        let paddingH: CGFloat = 4
        let height: CGFloat = 20
        let width = textSize.width + paddingH * 2
        
        let imageSize = NSSize(width: width, height: height)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        // 3. Vẽ nền bo tròn (chỉnh bán kính bo góc cho phù hợp với khung lớn)
        let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
                                  xRadius: 4, yRadius: 4) // Giảm bo góc từ 5 xuống 4 để tỷ lệ chuẩn hơn
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
