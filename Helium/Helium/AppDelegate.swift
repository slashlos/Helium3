//
//  AppDelegate.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//
//  We have user IBAction centrally here, share by panel and webView controllers
//  The design is to centrally house the preferences and notify these interested
//  parties via notification.  In this way all menu state can be consistency for
//  statusItem, main menu, and webView contextual menu.
//
import Cocoa

struct RequestUserUrlStrings {
    let currentURL: String?
    let alertMessageText: String
    let alertButton1stText: String
    let alertButton1stInfo: String?
    let alertButton2ndText: String
    let alertButton2ndInfo: String?
    let alertButton3rdText: String?
    let alertButton3rdInfo: String?
}

fileprivate class URLField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
    
    convenience init(withValue: String?) {
        self.init()
        
        if let string = withValue {
            self.stringValue = string
        }
        self.lineBreakMode = NSLineBreakMode.byTruncatingHead
        self.usesSingleLineMode = true
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    @IBOutlet weak var magicURLMenu: NSMenuItem!

    //  MARK:- Global IBAction, but ship to keyWindow when able
    @IBOutlet weak var appMenu: NSMenu!
	var appStatusItem:NSStatusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            Swift.print("Menu '\(menuItem.title)' clicked")
        }
    }
	@IBAction func hideAppStatusItem(_ sender: NSMenuItem) {
		UserSettings.HideAppMenu.value = (sender.state == NSOffState)
		if UserSettings.HideAppMenu.value {
			NSStatusBar.system().removeStatusItem(appStatusItem)
		}
		else
		{
			appStatusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
			appStatusItem.image = NSImage.init(named: "statusIcon")
			appStatusItem.menu = appMenu
		}
	}
    @IBAction func homePagePress(_ sender: AnyObject) {
        didRequestUserUrl(RequestUserUrlStrings (
            currentURL: UserSettings.homePageURL.value,
            alertMessageText: "Enter new home Page URL",
            alertButton1stText: "Set",      alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Default",  alertButton3rdInfo: UserSettings.homePageURL.default),
                          onWindow: NSApp.keyWindow as? HeliumPanel,
                          acceptHandler: { (newUrl: String) in
                            UserSettings.homePageURL.value = newUrl
        }
        )
    }

    @IBAction func magicURLRedirectPress(_ sender: NSMenuItem) {
        UserSettings.disabledMagicURLs.value = (sender.state == NSOnState)
    }
    
    fileprivate func doOpenFile(fileURL: URL) -> Bool {
        let dc = NSDocumentController.shared()
        let fileType = fileURL.pathExtension
        dc.noteNewRecentDocumentURL(fileURL)

        if let hwc = NSApp.keyWindow?.windowController, let doc = NSApp.keyWindow?.windowController?.document {

            //  If it's a "h2w" type read it and load its fileURL
            if fileType == "h2w" {
                (doc as! Document).updateURL(to: fileURL, ofType: fileType)
                
                (hwc.contentViewController as! WebViewController).loadURL(url: (doc as! Document).fileURL!)
            }
            else
            {
                (hwc.contentViewController as! WebViewController).loadURL(url: fileURL)
            }
            
            return true
        }
        else
        {
            //  This could be anything so add/if a doc and initialize
            do {
                let doc = try Document.init(contentsOf: fileURL, ofType: fileType)
                doc.makeWindowControllers()
                dc.addDocument(doc)

                if let hwc = (doc as NSDocument).windowControllers.first {
                    hwc.window?.orderFront(self)
                    (hwc.contentViewController as! WebViewController).loadURL(url: fileURL)
                    
                    return true
                }
                else
                {
                    return false
                }
            } catch let error {
                print("*** Error open file: \(error.localizedDescription)")
                return false
            }
        }
    }
	@IBAction func openDocument(_ sender: Any) {
		self.openFilePress(sender as AnyObject)
	}
    @IBAction func openFilePress(_ sender: AnyObject) {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = false
        open.canChooseFiles = true
        open.canChooseDirectories = false
        open.orderFront(sender)
        
        if open.runModal() == NSModalResponseOK {
            if let url = open.url, let fileURL = URL(string: url.absoluteString.removingPercentEncoding!) {
                _ = self.doOpenFile(fileURL: fileURL)
            }
        }
    }
    
    @IBAction func openLocationPress(_ sender: AnyObject) {
        didRequestUserUrl(RequestUserUrlStrings (
            currentURL: UserSettings.homePageURL.value,
            alertMessageText: "Enter Destination URL",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.homePageURL.value),
                          onWindow: NSApp.keyWindow as? HeliumPanel,
                          acceptHandler: { (newUrl: String) in
                            do {
                                if let panel = NSApp.keyWindow as? HeliumPanel {
                                    if let hpc = panel.windowController as? HeliumPanelController {
                                        hpc.webViewController.loadURL(text: newUrl)
                                    }
                                }
                                else
                                {
                                    do {
                                        let doc = try NSDocumentController.shared().openUntitledDocumentAndDisplay(true)
                                        if let hpc = doc.windowControllers.first as? HeliumPanelController {
                                            hpc.webViewController.loadURL(text: newUrl)
                                        }
                                    } catch let error {
                                        NSApp.presentError(error)
                                    }
                                }
                            }
        })
    }
    
    @IBAction func presentPlaylistSheet(_ sender: AnyObject) {
        if let window = NSApp.mainWindow {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let pvc = storyboard.instantiateController(withIdentifier: "PlaylistViewController") as! PlaylistViewController
            let wvc = window.windowController?.contentViewController
            wvc?.presentViewControllerAsSheet(pvc)
        }
        else
        {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let ppc = storyboard.instantiateController(withIdentifier: "PlaylistPanelController") as! PlaylistPanelController
            ppc.window?.center()
            
            NSApp.runModal(for: ppc.window!)
        }
    }
    
	@IBAction func updateOpenNewTitle(_ sender: NSMenu) {
		sender.title = (nil != NSApp.keyWindow ? "Open" : "New")
	}
	@IBOutlet weak var openNewMenu: NSMenuItem!
	@IBOutlet weak var appOpenNewMenu: NSMenuItem!
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let currDoc = NSDocumentController.shared().currentDocument
        switch menuItem.title {
		case "Open/New", "Open", "New":
			menuItem.title = (nil != currDoc ? "Open" : "New")
			break
        case "Preferences":
            break
        case "Home Page":
            break
        case "Magic URL Redirects":
            menuItem.state = UserSettings.disabledMagicURLs.value ? NSOffState : NSOnState
            break
        case "New Window":
            menuItem.target = currDoc
            break
        case "Quit":
            break

        default:
            break
        }
        return true;
    }

    //  MARK:- Lifecyle

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true//NSApp.windows.count == 0
    }

    let toHMS = hmsTransformer()
    let rectToString = rectTransformer()
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(AppDelegate.handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        //  So they can interact everywhere with us without focus
        appStatusItem.image = NSImage.init(named: "statusIcon")
        appStatusItem.menu = appMenu

        //  Initialize our h:m:s transformer
        ValueTransformer.setValueTransformer(toHMS, forName: NSValueTransformerName(rawValue: "hmsTransformer"))
        
        //  Initialize our rect [point,size] transformer
        ValueTransformer.setValueTransformer(rectToString, forName: NSValueTransformerName(rawValue: "rectTransformer"))

        //  Maintain a history of titles
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AppDelegate.haveNewTitle(_:)),
            name: NSNotification.Name(rawValue: "HeliumNewURL"),
            object: nil)
    }

    var histories = Array<PlayItem>()
    var defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // Restore history name change
        if let historyName = UserDefaults.standard.value(forKey: UserSettings.HistoryName.keyPath) {
            UserSettings.HistoryName.value = historyName as! String
        }
        
        // Load histories from defaults
        if let items = defaults.array(forKey: UserSettings.HistoryList.keyPath) {
            for playitem in items {
                let item = playitem as! Dictionary <String,AnyObject>
                let name = item[k.name] as! String
                let path = item[k.link] as! String
                let time = item[k.time] as? TimeInterval
                let link = URL.init(string: path)
                let rank = item[k.rank] as! Int
                let temp = PlayItem(name:name, link:link!, time:time!, rank:rank)
                
                // Non-visible (tableView) cells
                temp.rect = item[k.rect]?.rectValue ?? NSZeroRect
                temp.label = item[k.label]?.boolValue ?? false
                temp.hover = item[k.hover]?.boolValue ?? false
                temp.alpha = item[k.alpha]?.floatValue ?? 0.6
                temp.trans = item[k.trans]?.intValue ?? 0

                histories.append(temp)
            }
        }
   }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application

        // Save histories to defaults
        var temp = Array<AnyObject>()
        for item in histories {
            let item : [String:AnyObject] = [k.name:item.name as AnyObject, k.link:item.link.absoluteString as AnyObject, k.time:item.time as AnyObject, k.rank:item.rank as AnyObject]
            temp.append(item as AnyObject)
        }
        defaults.set(temp, forKey: UserSettings.HistoryList.keyPath)
        defaults.synchronize()
    }

    //MARK: - handleURLEvent(s)

    func metadataDictionaryForFileAt(_ fileName: String) -> Dictionary<NSObject,AnyObject>? {
        
        let item = MDItemCreate(kCFAllocatorDefault, fileName as CFString)
        if ( item == nil) { return nil };
        
        let list = MDItemCopyAttributeNames(item)
        let resDict = MDItemCopyAttributes(item,list) as Dictionary
        return resDict
    }

    @objc fileprivate func haveNewTitle(_ notification: Notification) {
        if let itemURL = notification.object as? URL {
            let item: PlayItem = PlayItem.init()
            var fileURL: URL? = nil

            if let testURL: URL = (itemURL as NSURL).filePathURL {
                fileURL = testURL
            }
            else
            if (itemURL as NSURL).isFileReferenceURL() {
                fileURL = (itemURL as NSURL).filePathURL
            }
            if fileURL != nil {
                let path = fileURL?.absoluteString//.stringByRemovingPercentEncoding
                let attr = metadataDictionaryForFileAt((fileURL?.path)!)
                let fuzz = (itemURL as AnyObject).deletingPathExtension!!.lastPathComponent as NSString
                item.name = fuzz.removingPercentEncoding!
                item.link = URL.init(string: path!)!
                item.time = attr?[kMDItemDurationSeconds] as? TimeInterval ?? 0
            }
            else
            {
                let fuzz = itemURL.deletingPathExtension().lastPathComponent
                let name = fuzz.removingPercentEncoding
                
                // Ignore our home page from the history queue
                if name! == UserSettings.homePageName.value { return }

                item.name = name!
                item.link = itemURL
                item.time = 0
            }
            histories.append(item)
            item.rank = histories.count

            let notif = Notification(name: Notification.Name(rawValue: "HeliumNewHistoryItem"), object: item)
            NotificationCenter.default.post(notif)
        }
    }
    
    /// Shows alert asking user to input URL on their window or floating.
    /// Process response locally, validate, dispatch via supplied handler
    func didRequestUserUrl(_ strings: RequestUserUrlStrings,
                           onWindow: HeliumPanel?,
                           acceptHandler: @escaping (String) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.alertStyle = NSAlertStyle.informational
        alert.messageText = strings.alertMessageText
        
        // Create urlField
        let urlField = URLField(withValue: strings.currentURL)
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        
        // Add urlField and buttons to alert
        alert.accessoryView = urlField
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }

        if let urlWindow = onWindow {
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are accept, cancel, default
                if response == NSAlertThirdButtonReturn {
                    var newUrl = (alert.buttons[2] as NSButton).toolTip
                    newUrl = UrlHelpers.ensureScheme(newUrl!)
                    if UrlHelpers.isValid(urlString: newUrl!) {
                        acceptHandler(newUrl!)
                    }
                }
                else
                if response == NSAlertFirstButtonReturn {
                    // swiftlint:disable:next force_cast
                    var newUrl = (alert.accessoryView as! NSTextField).stringValue
                    newUrl = UrlHelpers.ensureScheme(newUrl)
                    if UrlHelpers.isValid(urlString: newUrl) {
                        acceptHandler(newUrl)
                    }
                }
            })
        }
        else {
            switch alert.runModal() {
            case NSAlertThirdButtonReturn:
                var newUrl = (alert.buttons[2] as NSButton).toolTip
                newUrl = UrlHelpers.ensureScheme(newUrl!)
                if UrlHelpers.isValid(urlString: newUrl!) {
                    acceptHandler(newUrl!)
                }

                break
                
            case NSAlertFirstButtonReturn:
                var newUrl = (alert.accessoryView as! NSTextField).stringValue
                newUrl = UrlHelpers.ensureScheme(newUrl)
                if UrlHelpers.isValid(urlString: newUrl) {
                    acceptHandler(newUrl)
                }

            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on urlField
        alert.accessoryView!.becomeFirstResponder()
    }

    
    // Called when the App opened via URL.
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        let hwc = NSApp.keyWindow?.windowController

        guard let keyDirectObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)),
            let urlString = keyDirectObject.stringValue else {
                return print("No valid URL to handle")
        }

        //  strip helium://
        let index = urlString.index(urlString.startIndex, offsetBy: 9)
        let url = urlString.substring(from: index)

        NotificationCenter.default.post(name: Notification.Name(rawValue: "HeliumLoadURL"),
                                        object: url,
                                        userInfo: ["hwc" : hwc as Any])
    }

    @objc func handleURLPboard(_ pboard: NSPasteboard, userData: NSString, error: NSErrorPointer) {
        if let selection = pboard.string(forType: NSPasteboardTypeString) {
            let hwc = NSApp.keyWindow?.windowController

            // Notice: string will contain whole selection, not just the urls
            // So this may (and will) fail. It should instead find url in whole
            // Text somehow
            NotificationCenter.default.post(name: Notification.Name(rawValue: "HeliumLoadURL"),
                                            object: selection,
                                            userInfo: ["hwc" : hwc as Any])
        }
    }
    // MARK: Finder drops
    func application(_ sender: NSApplication, openFile: String) -> Bool {
        let urlString = (openFile.hasPrefix("file://") ? openFile : "file://" + openFile)
        let fileURL = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!
        return self.doOpenFile(fileURL: fileURL)
    }
    
    func application(_ sender: NSApplication, openFiles: [String]) {
        Swift.print("sender \(sender) list \(openFiles)")
        // Create a FileManager instance
        let fileManager = FileManager.default
        
        for path in openFiles {

            do {
                let files = try fileManager.contentsOfDirectory(atPath: path)
                for file in files {
                    _ = self.application(sender, openFile: file)
                }
            }
            catch let error as NSError {
                if fileManager.fileExists(atPath: path) {
                    _ = self.application(sender, openFile: path)
                }
                else
                {
                    print("Yoink \(error.localizedDescription)")
                }
            }
        }
    }
}

