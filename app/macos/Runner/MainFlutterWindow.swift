import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Must call super first to ensure window is properly initialized
    super.awakeFromNib()
    
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Ensure the window is visible and brought to front
    self.makeKeyAndOrderFront(nil)
    self.center()
  }
}
