//
//  AppDelegate.swift
//  cornerflow
//
//  Created by Erwan Martin on 13/12/2022.
//

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var myPopover: NSPopover!
    var statusBar: NSStatusItem!
    var popoverIsOpen = false
    var isLocking = false
    
    enum CornerActions: String, CaseIterable {
        case none = "-"
        case lockAndBlur = "Lock the screen + blur background"
        case executeScript = "Execute a script"
    }
    
    struct CurrentWallpaperPaths {
        var screen: NSScreen
        var wallpaperPath: URL
    }
    
    var currentWallpaperPaths: [CurrentWallpaperPaths] = []
    var dnc: DistributedNotificationCenter!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupPopoverAndStatusBar()
        setupNotificationCenter()
        setupGlobalMouseMonitor()
    }
    
    private func setupPopoverAndStatusBar() {
        myPopover = NSPopover()
        statusBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBar.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "1")
            button.action = #selector(showPopover)
            button.target = self
        }
    }
    
    private func setupNotificationCenter() {
        dnc = DistributedNotificationCenter.default()
        
        // Handle screenIsLocked event
        dnc.addObserver(
            forName: .init("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { _ in
            self.isLocking = true
        }
        
        // Handle screenIsUnlocked event
        dnc.addObserver(
            forName: .init("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            for el in self.currentWallpaperPaths {
                self.setWallpaper(screen: el.screen, wallpaperPath: el.wallpaperPath)
            }
            self.isLocking = false
        }
    }
    
    private func setupGlobalMouseMonitor() {
        // Handle Mouse move events
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.mouseMoved, handler: { (mouseEvent: NSEvent) in
            let position = NSEvent.mouseLocation
            if position.x < 0.5 && position.y < 0.5 && self.isLocking == false {
                self.isLocking = true
                self.takeAndBlurScreenshot()
            }
        })
    }
    
    @objc func showPopover(sender: AnyObject) {
        let popoverContentView = createPopoverContentView()
        let viewController = NSViewController()
        viewController.view = popoverContentView
        
        // Création et configuration du popover
        self.myPopover.contentViewController = viewController
        self.myPopover.behavior = .transient
        self.myPopover.animates = true
        self.myPopover.show(relativeTo: sender.bounds, of: sender as! NSView, preferredEdge: NSRectEdge.maxY)
    }
    
    private func createPopoverContentView() -> NSView {
        let appTitle = createText(text: "Cornerflow")
        appTitle.textColor = .gray
        
        let cornerActions = CornerActions.allCases.map { $0.rawValue }
        let selectCornerTL = createPopUpButton(withTitles: cornerActions)
        let selectCornerTR = createPopUpButton(withTitles: cornerActions)
        let selectCornerBL = createPopUpButton(withTitles: cornerActions)
        let selectCornerBR = createPopUpButton(withTitles: cornerActions)
        
        let button = NSButton(title: "Quitter Cornerflow ⌘Q", target: self, action: #selector(quitCornerflow))
        button.keyEquivalent = "q"
        button.keyEquivalentModifierMask = [.command]
        button.isBordered = false
        
        let spacingRect = NSRect(x: 0, y: 0, width: 0, height: 10)
        
        let gridView = NSGridView(views: [
            [NSView(frame: spacingRect)],
            [appTitle],
            [NSView(frame: spacingRect)],
            [selectCornerTL, selectCornerTR],
            [selectCornerBL, selectCornerBR],
            [NSView(frame: spacingRect)],
            [button],
            [NSView(frame: spacingRect)],
        ])
        gridView.column(at: 0).width = 100
        gridView.column(at: 1).width = 100
        
        gridView.row(at: 1).mergeCells(in: NSRange(location: 0, length: 2))
        gridView.row(at: 6).mergeCells(in: NSRange(location: 0, length: 2))
        
        gridView.cell(for: appTitle)?.xPlacement = .center
        gridView.cell(for: button)?.xPlacement = .center
        
        return gridView
    }
    
    @objc func quitCornerflow() {
        NSApplication.shared.terminate(self)
    }
    
    private func createPopUpButton(withTitles titles: [String]) -> NSPopUpButton {
        let popUpButton = NSPopUpButton()
        popUpButton.addItems(withTitles: titles)
        return popUpButton
    }
    
    private func createText(text: String) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.isEditable = false
        textField.isBordered = false
        textField.isSelectable = false
        textField.drawsBackground = false
        textField.isBezeled = false
        
        return textField
    }
    
    // Utility functions
    
    private func setWallpaper(screen: NSScreen, wallpaperPath: URL) {
        do {
            try NSWorkspace.shared.setDesktopImageURL(wallpaperPath, for: screen, options: [:])
        } catch {
            print(error)
        }
    }
    
    private func takeAndBlurScreenshot() {
        let context = CIContext()
        self.currentWallpaperPaths = []

        for screen in NSScreen.screens {
            // Store the current wallpaper path for the screen
            self.currentWallpaperPaths.append(CurrentWallpaperPaths(
                screen: screen,
                wallpaperPath: NSWorkspace.shared.desktopImageURL(for: screen)!
            ))

            // Take a screenshot of the screen
            let rect = screen.frame
            guard let image = CGWindowListCreateImage(rect, .optionOnScreenOnly, CGWindowID(0), .bestResolution) else {
                continue
            }

            let screenshot = NSImage(cgImage: image, size: rect.size)
            guard let inputImage = CIImage(data: screenshot.tiffRepresentation!),
                  let blurredImage = applyGaussianBlur(to: inputImage, using: context) else {
                continue
            }

            // Save the blurred image to a temporary file
            let outputData = blurredImage.tiffRepresentation
            let outputURL = URL(fileURLWithPath: "/tmp/blurred-screenshot.tiff")
            do {
                try outputData?.write(to: outputURL)
                self.setWallpaper(screen: screen, wallpaperPath: outputURL)
            } catch {
                print(error)
            }
        }
        self.lockTheScreen()
    }
    
    private func applyGaussianBlur(to inputImage: CIImage, using context: CIContext) -> NSImage? {
        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        
        guard let outputImage = blurFilter?.outputImage,
              let outputCGImage = context.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }
        
        return NSImage(cgImage: outputCGImage, size: inputImage.extent.size)
    }
    
    private func lockTheScreen() {
        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        let sym = dlsym(libHandle, "SACLockScreenImmediate")
        typealias myFunction = @convention(c) () -> Void
        
        let SACLockScreenImmediate = unsafeBitCast(sym, to: myFunction.self)
        SACLockScreenImmediate()
    }
}
