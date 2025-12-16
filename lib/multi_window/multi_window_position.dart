import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';


/// 마우스 다운을 통해 새 창 생성
/// 마우스 클릭된 상태에서 드래그하면 새로 띄운 창 위치 커서에 맞춰 갱신
class MultiWindowPositionExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _MultiWindowPositionExample();
  }

}

class _MultiWindowPositionExample extends State<MultiWindowPositionExample> with WindowListener{


  WindowController? newWindowController;
  WindowMethodChannel? windowMethodChannel;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }
  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> initWindowCloseHandler() async{
    // 닫기버튼 눌렀을 때,
    // 바로 종료하지 않고, onWindowClose 호출되도록
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    exit(0);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("multi_window_drag_position")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text("Main Window"),
            Listener(
              onPointerDown: (event) async {
                print("onPointerDown");
                newWindowController = null;
                newWindowController = await WindowController.create(
                    WindowConfiguration(
                      arguments: jsonEncode({
                        "type": "newWindow",
                        "targetScreen": "multi_window_position",
                      }),
                    )
                );
                print("newWindowController created");

                windowMethodChannel = null;
                windowMethodChannel = WindowMethodChannel(
                    "window_control_${newWindowController!.windowId}",
                    mode: ChannelMode.unidirectional
                );
                print("windowMethodChannel created");

              },
              onPointerMove: (event) async {
                print("onPointerMove");
                if(newWindowController != null) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  Offset? absPos;
                  final currentWindowPosition = await windowManager.getPosition();
                  absPos = currentWindowPosition + event.position;

                  if(windowMethodChannel != null){
                    print("windowMethodChannel invoke");
                    windowMethodChannel!.invokeMethod("setPosition", jsonEncode({
                      "offset": {
                        "dx": absPos.dx,
                        "dy": absPos.dy
                      }
                    }));
                  }

                  // newWindowController.
                  // newWindowController!.invokeMethod("movePosition", {
                  //   "offset": {
                  //     "dx": absPos.dx,
                  //     "dy": absPos.dy
                  //   }
                  // });
                }
              },
              child: Container(
                  color: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Text("mouse down and drag to move position")
              )
            ),
          ]
        )
      )
    );
  }
}

class NewWindow extends StatefulWidget{
  String windowId;

  NewWindow({required this.windowId});

  @override
  State<StatefulWidget> createState() {
    return _NewWindow();
  }
}
class _NewWindow extends State<NewWindow> {

  late final WindowMethodChannel _windowMethodChannel;

  @override
  void initState() {
    super.initState();

    // 해당 윈도 전용 채널 생성
    _windowMethodChannel = WindowMethodChannel(
        "window_control_${widget.windowId}",
        mode: ChannelMode.unidirectional
    );

    // 메시지 핸들러 등록
    _windowMethodChannel.setMethodCallHandler(handleMethodCallback);
  }

  void dispose(){
    _windowMethodChannel.setMethodCallHandler(null);
    super.dispose();

  }

  Future<dynamic> handleMethodCallback(MethodCall call) async {
    print("${widget.windowId} :: $call");
    if(call.method == "setPosition") {
      final arguments = json.decode(call.arguments as String);

      final dx = arguments["offset"]["dx"];
      final dy = arguments["offset"]["dy"];
      windowManager.setPosition(Offset(dx, dy));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("New Window")),
      body: Center(
        child: Text(widget.windowId)
      )
    );
  }
}
