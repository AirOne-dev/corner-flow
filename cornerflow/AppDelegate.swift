//
//  AppDelegate.swift
//  cornerflow
//
//  Created by Erwan Martin on 13/12/2022.
//

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    let cornerActions = [
        0: "-",
        2: "Mission Control",
        3: "Show application windows",
        4: "Desktop",
        5: "Start screen saver",
        6: "Disable screen saver",
        7: "Dashboard",
        10: "Put display to sleep",
        11: "Launchpad",
        12: "Notification Center",
        13: "Lock the screen + blur background",
        14: "Execute a script"
    ];
    
    var myPopover: NSPopover!
    var statusBar: NSStatusItem!
    var popoverIsOpen = false
    var isLocking = false;
    var preferences = UserDefaults.standard
    
    struct CurrentWallpaperPaths {
        var screen : NSScreen
        var wallpaperPath: URL
    }
    
    var currentWallpaperPaths: [CurrentWallpaperPaths] = [];
    var dnc: DistributedNotificationCenter!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if((preferences.object(forKey: "corners") as? [String: Int] ?? [:]).count != 4) {
            preferences.set(["top-left": 0, "top-right": 0, "bottom-left": 0, "bottom-right": 0], forKey: "corners")
        }
        // preferences.object(forKey: "corners") as! [String: Int]
        
        myPopover = NSPopover();
        statusBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBar.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "1")
            button.action = #selector(showPopover)
            button.target = self
        }
        
        dnc = DistributedNotificationCenter.default()
        
        //
        // Handle Mouse move events
        //
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.mouseMoved, handler: {(mouseEvent:NSEvent) in
            let position = NSEvent.mouseLocation
            if(position.x < 0.5 && position.y < 0.5 && self.isLocking == false) {
                self.isLocking = true;
                self.screenShotWallpaper();
            }
        })
        
        //
        // Handle screenIsLocked event
        //
        dnc.addObserver(
            forName: .init("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { _ in
            self.isLocking = true
        }
        
        //
        // Handle screenIsUnlocked event
        //
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
    
    @objc func showPopover(sender: AnyObject) {
        getMachineCornersInfo();
        
        let cornersPreferences = preferences.object(forKey: "corners") as! [String: Int]
        
        let appTitle = createText(text: "Cornerflow")
        appTitle.textColor = .gray
        
        let selectCornerTL = NSPopUpButton()
        selectCornerTL.addItems(withTitles: cornerActions.values.map { $0 })
        selectCornerTL.selectItem(at: cornersPreferences["top-left"] ?? 0)
        selectCornerTL.action = #selector(popUpButtonTopLeft(_:))
        
        let selectCornerTR = NSPopUpButton()
        selectCornerTR.addItems(withTitles: cornerActions.values.map { $0 })
        selectCornerTR.selectItem(at: cornersPreferences["top-right"] ?? 0)
        selectCornerTR.action = #selector(popUpButtonTopRight(_:))
        
        let selectCornerBL = NSPopUpButton()
        selectCornerBL.addItems(withTitles: cornerActions.values.map { $0 })
        selectCornerBL.selectItem(at: cornersPreferences["bottom-left"] ?? 0)
        selectCornerBL.action = #selector(popUpButtonBottomLeft(_:))
        
        let selectCornerBR = NSPopUpButton()
        selectCornerBR.addItems(withTitles: cornerActions.values.map { $0 })
        selectCornerBR.selectItem(at: cornersPreferences["bottom-right"] ?? 0)
        selectCornerBR.action = #selector(popUpButtonBottomRight(_:))
        
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
        
        // Création du view controller et ajout de la vue de grille et du menu
        let viewController = NSViewController()
        viewController.view = gridView

        // Création et configuration du popover
        self.myPopover.contentViewController = viewController
        self.myPopover.behavior = .transient
        self.myPopover.animates = true
        self.myPopover.show(relativeTo: sender.bounds, of: sender as! NSView, preferredEdge: NSRectEdge.maxY)
    }
    
    @objc func popUpButtonTopLeft(_ sender: NSPopUpButton) { setPopupPreference(popupName: "top-left", selectedItem: sender.indexOfSelectedItem) }
    @objc func popUpButtonTopRight(_ sender: NSPopUpButton) { setPopupPreference(popupName: "top-right", selectedItem: sender.indexOfSelectedItem) }
    @objc func popUpButtonBottomLeft(_ sender: NSPopUpButton) { setPopupPreference(popupName: "bottom-left", selectedItem: sender.indexOfSelectedItem) }
    @objc func popUpButtonBottomRight(_ sender: NSPopUpButton) { setPopupPreference(popupName: "bottom-right", selectedItem: sender.indexOfSelectedItem) }
    
    func setPopupPreference(popupName: String, selectedItem: Int) {
        var cornersPreferences = preferences.object(forKey: "corners") as? [String: Int] ?? [:]
        cornersPreferences[popupName] = selectedItem
        preferences.set(cornersPreferences, forKey: "corners")
    }
    
    @objc func quitCornerflow() {
        NSApplication.shared.terminate(self)
    }

    
    func createText(text: String) -> NSTextField {
        let text = NSTextField(string: text)
        text.isEditable = false
        text.isBordered = false
        text.isSelectable = false
        text.drawsBackground = false
        text.isBezeled = false
        
        return text
    }
    
    
    //
    // Utility functions
    //
    func setWallpaper(screen: NSScreen, wallpaperPath: URL) {
        print(wallpaperPath)
        do {
            try NSWorkspace.shared.setDesktopImageURL(wallpaperPath, for: screen, options: [:])
        } catch {
            print(error)
        }
    }
    
    func screenShotWallpaper() {
        let context = CIContext()
        self.currentWallpaperPaths = []
        
        
        for (index, screen) in NSScreen.screens.enumerated() {
            // Récupération du chemin du fond d'écran de l'écran
            self.currentWallpaperPaths.append(CurrentWallpaperPaths(
                screen: screen,
                wallpaperPath: NSWorkspace.shared.desktopImageURL(for: screen)!
            ))

            // Prise de capture d'écran de l'écran
            let rect = screen.frame
            let image = CGWindowListCreateImage(rect, CGWindowListOption.optionOnScreenOnly, CGWindowID(0), CGWindowImageOption.bestResolution)!
            let screenshot = NSImage(cgImage: image, size: rect.size)

            // Floutage de l'image
            let inputImage = CIImage(data: screenshot.tiffRepresentation!)
            let blurFilter = CIFilter(name: "CIGaussianBlur")!
            blurFilter.setValue(inputImage, forKey: kCIInputImageKey)
            let outputImage = blurFilter.outputImage!

            // Mise en fond d'écran de l'image floue
            let outputCGImage = context.createCGImage(outputImage, from: inputImage!.extent)!
            let outputNSImage = NSImage(cgImage: outputCGImage, size: inputImage!.extent.size)
            let outputData = outputNSImage.tiffRepresentation!
            let outputURL = URL(fileURLWithPath: "/tmp/blurred-screenshot-" + String(index) + ".tiff")
            do {
                try outputData.write(to: outputURL)
                self.setWallpaper(screen: screen, wallpaperPath: outputURL)
            } catch {
                print(error)
            }
        }
        self.lockTheScreen()
    }
    
    
    func checkScreenshotPermission() -> Bool {
      let image: CGImage?
      do {
          image = try CGWindowListCreateImage(.infinite, .optionOnScreenOnly, CGWindowID(0), CGWindowImageOption.nominalResolution)
      } catch let e as NSError {
          print(e)
        return false
      }
        if image != nil {
        return true
      } else {
        return false
      }
    }

    
    func lockTheScreen() {
        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
            let sym = dlsym(libHandle, "SACLockScreenImmediate")
            typealias myFunction = @convention(c) () -> Void

            let SACLockScreenImmediate = unsafeBitCast(sym, to: myFunction.self)
            SACLockScreenImmediate()
    }
    
    func getMachineCornersInfo() {
        let corners = ["wvous-tl-corner", "wvous-tr-corner", "wvous-bl-corner", "wvous-br-corner"]
        var activeCorners = [String: Any]()

        let userDefaults = UserDefaults(suiteName: "com.apple.dock")
        userDefaults?.set(true, forKey: "ApplicationType")

        for (key, value) in userDefaults!.dictionaryRepresentation() {
            if(corners.contains(key)) { activeCorners[key] = value }
        }
        
        print(activeCorners)
    }
}
