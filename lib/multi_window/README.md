# desktop_multi_window를 사용한 새 창 띄우기
```
flutter pub add desktop_multi_window
```

새 창을 띄울 때, 이전에 띄웠던 윈도가 리빌드 되는 현상   
디버깅 모드일 때만 나타난 현상으로 릴리즈 모드에서는 정상 동작함   

**디버그 모드 이슈 (가장 유력)**:
   *   `flutter run` (디버그 모드)으로 실행 중일 때, 새로운 Isolate가 생성되거나 연결될 때 개발 도구(DevTools/Debugger)와의 동기화 과정에서 기존 Isolate들이 **Hot Restart** 되거나 재실행되는 현상이 발생할 수 있습니다.
   *   **로그가 다시 찍히는 이유**: 기존에 열려있던 윈도우(count: 1)가 재시작되면서 `main()` 함수가 다시 실행되기 때문입니다.
   *   **데이터가 초기화되는 이유**: `main()` 함수가 다시 실행되면 `WindowController`에서 받아오는 `arguments`는 **처음 윈도우를 생성할 때 넘겨준 값**(`count: 1`) 그대로입니다. 따라서 `NewWindow` 위젯이 `count: 1`로 다시 생성되면서, `setState`로 증가시켰던 값은 메모리에서 사라지고 초기값으로 돌아갑니다.


# window_manager를 사용하여 윈도 커스텀
* 윈도 타이틀바 커스텀
* 생성 시 초기 사이즈 지정 등
```
flutter pub add window_manager
```
## 가이드에는 설명 없으나 사용하기 위해 초기 세팅 필요함
* 단순 실행에는 이상 없지만, 새 윈도를 띄우면 새로운 Flutter 엔진이 생성되지만, 이 엔진에는 window_manager 플러그인이 네이티브에 등록되지 않아서 오류 나옴
* 메인은 flutter가 알아서 등록하지만, 서브 윈도는 직접 수정해야함
   
### MAC OS
MainFlutterWindow.swift (또는 프로젝트 설정에 따라 AppDelegate.swift) 파일에 서브 윈도우 생성 시 플러그인을 등록하는 콜백 추가

```diff
// macos/runner/MainFlutterWindow.swift

  import Cocoa
  import FlutterMacOS
+ import desktop_multi_window


  class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
      ...
      
      RegisterGeneratedPlugins(registry: flutterViewController)
      
+     FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
+       RegisterGeneratedPlugins(registry: controller)
+     }

      super.awakeFromNib()
    }
  }
```
### Windows
flutter_window.cpp 파일에 서브 윈도우 생성 시 플러그인을 등록하는 콜백 추가

```diff
// windows/runner/main.cpp

  ...

  #include "flutter_window.h"
  #include "utils.h"

+ #include <desktop_multi_window/desktop_multi_window_plugin.h>

  int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,

  ...
  
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());
  
+ DesktopMultiWindowPlugin::SetWindowCreatedCallback([](void *controller) {
+   auto *flutter_view_controller = reinterpret_cast<flutter::FlutterViewController *>(controller);
+   RegisterPlugins(flutter_view_controller->engine());
+ });
  
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  
  ...

```