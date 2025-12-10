import Cocoa
import FlutterMacOS
// bitsdojo >>
/**
 bitsdojo_window_macos import 추가
 MainFlutterWindow 상속 NSWindow -> BitsdojoWindow
 bitsdojo_window_configure() 함수 추가
 */
import bitsdojo_window_macos


class MainFlutterWindow: BitsdojoWindow {
    
    override func bitsdojo_window_configure() -> UInt {
      return BDW_HIDE_ON_STARTUP
    }
//class MainFlutterWindow: NSWindow {
// << bitsdojo
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
