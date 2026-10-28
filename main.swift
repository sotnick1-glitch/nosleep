import Cocoa
import IOKit.pwr_mgt

// Ноутбук: спит — контур экрана и «zz»; не спит — экран залит и в нём открытый глаз. t: 0 = спит, 1 = не спит.
func icon(_ t: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { _ in
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.translateBy(x: -0.8, y: -2.8)  // ноутбук занимает почти всю ширину 20 пт
        ctx.scaleBy(x: 1.2, y: 1.2)
        let black = NSColor.black
        let screen = CGRect(x: 2.5, y: 6.25, width: 13, height: 9)
        let screenPath = CGPath(roundedRect: screen, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil)

        // основание
        ctx.setFillColor(black.cgColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: 1, y: 2.75, width: 16, height: 1.6), cornerWidth: 0.8, cornerHeight: 0.8, transform: nil))
        ctx.fillPath()

        // контур экрана
        ctx.setStrokeColor(black.cgColor)
        ctx.setLineWidth(1.3)
        ctx.addPath(CGPath(roundedRect: screen.insetBy(dx: 0.65, dy: 0.65), cornerWidth: 1, cornerHeight: 1, transform: nil))
        ctx.strokePath()

        // всё остальное — внутри экрана
        ctx.saveGState()
        ctx.addPath(screenPath)
        ctx.clip()

        // заливка поднимается снизу вверх
        let fill = min(1, max(0, t))
        ctx.setFillColor(black.cgColor)
        ctx.fill(CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height * fill))

        // глаз: вырез-миндаль и зрачок
        let s = max(0, (t - 0.45) / 0.55)
        if s > 0.01 {
            let c = CGPoint(x: screen.midX, y: screen.midY)
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: CGRect(x: c.x - 4.2 * s, y: c.y - 2.3 * s, width: 8.4 * s, height: 4.6 * s))
            ctx.setBlendMode(.normal)
            ctx.setFillColor(black.cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x - 1.3 * s, y: c.y - 1.3 * s, width: 2.6 * s, height: 2.6 * s))
        }

        // «zz» уплывают вверх и гаснут
        let a = max(0, 1 - t * 2.2)
        if a > 0.02 {
            ctx.setStrokeColor(black.withAlphaComponent(a).cgColor)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let lift = t * 4
            func z(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ w: CGFloat) {
                ctx.setLineWidth(w)
                ctx.move(to: CGPoint(x: cx - r, y: cy + r + lift))
                ctx.addLine(to: CGPoint(x: cx + r, y: cy + r + lift))
                ctx.addLine(to: CGPoint(x: cx - r, y: cy - r + lift))
                ctx.addLine(to: CGPoint(x: cx + r, y: cy - r + lift))
                ctx.strokePath()
            }
            z(7.2, 10.2, 1.5, 1.2)
            z(12.0, 12.2, 1.0, 1.0)
        }
        ctx.restoreGState()
        return true
    }
    img.isTemplate = true  // система сама красит под светлое/тёмное меню
    return img
}

func easeOutBack(_ x: Double) -> Double {
    let c1 = 1.6, c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var assertion: IOPMAssertionID = 0
    var awake = false
    var progress: CGFloat = 0
    var timer: Timer?
    var sig: DispatchSourceSignal?
    let hud = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 180, height: 46),
                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let hudIcon = NSImageView(frame: NSRect(x: 12, y: 14, width: 22, height: 18))
    let hudTitle = NSTextField(labelWithString: "")
    let hudSub = NSTextField(labelWithString: "")
    var hideTimer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        let b = item.button!
        b.target = self
        b.action = #selector(click)
        b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        b.image = icon(0)
        b.toolTip = "Сон включён"

        // плашка в стиле системных (как громкость или Пункт управления): размытое стекло, значок, заголовок и серая подпись
        let glass = NSVisualEffectView(frame: hud.contentRect(forFrameRect: hud.frame))
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 12
        glass.layer?.masksToBounds = true
        hudIcon.contentTintColor = .labelColor
        hudTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        hudTitle.frame = NSRect(x: 42, y: 24, width: 130, height: 16)
        hudSub.font = .systemFont(ofSize: 11)
        hudSub.textColor = .secondaryLabelColor
        hudSub.frame = NSRect(x: 42, y: 7, width: 130, height: 14)
        [hudIcon, hudTitle, hudSub].forEach { glass.addSubview($0) }
        hud.contentView = glass
        hud.isOpaque = false
        hud.backgroundColor = .clear
        hud.hasShadow = true
        hud.level = .statusBar
        hud.ignoresMouseEvents = true
        hud.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // kill -USR1 <pid> переключает без мыши — для проверки
        signal(SIGUSR1, SIG_IGN)
        sig = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        sig?.setEventHandler { [self] in toggle() }
        sig?.resume()
    }

    @objc func click() {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            let m = NSMenu()
            m.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = m
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            toggle()
        }
    }

    func toggle() {
        awake.toggle()
        if awake {
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "NoSleep" as CFString, &assertion)
        } else {
            IOPMAssertionRelease(assertion)
        }
        item.button?.toolTip = awake ? "Не засыпает" : "Сон включён"
        animate(to: awake ? 1 : 0)
        showStatus()
    }

    // плашка под иконкой: плавно появляется и через 1.8 с гаснет
    func showStatus() {
        hudIcon.image = icon(awake ? 1 : 0)
        hudTitle.stringValue = awake ? "No Sleep" : "Sleep"
        hudSub.stringValue = awake ? "Mac не засыпает" : "Сон работает как обычно"

        // ширина по тексту, чтобы ничего не обрезалось
        hudTitle.sizeToFit(); hudSub.sizeToFit()
        let width = 42 + max(hudTitle.frame.width, hudSub.frame.width) + 16
        hud.setContentSize(NSSize(width: width, height: 46))
        if let w = item.button?.window {
            let s = w.screen?.visibleFrame ?? .zero
            let x = min(w.frame.midX - width / 2, s.maxX - width - 8)
            hud.setFrameOrigin(NSPoint(x: x, y: w.frame.minY - 6 - 46))
        }
        if !hud.isVisible {
            hud.alphaValue = 0
            hud.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; hud.animator().alphaValue = 1 }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [self] _ in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; hud.animator().alphaValue = 0 },
                                                 completionHandler: { [self] in if hud.alphaValue == 0 { hud.orderOut(nil) } })
        }
    }

    func animate(to: CGFloat) {
        let from = progress, start = CACurrentMediaTime(), dur = 0.5
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [self] t in
            let x = min(1, (CACurrentMediaTime() - start) / dur)
            progress = from + (to - from) * CGFloat(easeOutBack(x))
            item.button?.image = icon(progress)
            if x >= 1 { t.invalidate() }
        }
        RunLoop.main.add(timer!, forMode: .common)  // .common — чтобы анимация шла и при открытом меню
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
