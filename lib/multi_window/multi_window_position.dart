import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';


/// 마우스 다운을 통해 새 창 생성
/// 마우스 클릭된 상태에서 드래그하면 새로 띄운 창 위치 커서에 맞춰 갱신
/// 새로 띄운 윈도 드래그 시 메인 윈도로 드래그 중인 커서의 위치 정보 전송
class MultiWindowPositionExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _MultiWindowPositionExample();
  }

}

class _MultiWindowPositionExample extends State<MultiWindowPositionExample> with WindowListener{


  WindowController? newWindowController;
  WindowMethodChannel? windowMethodChannel;
  late WindowMethodChannel toMainMethodChannel;

  final key = GlobalKey();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    toMainMethodChannel = WindowMethodChannel(
        "toMainWin",
        mode: ChannelMode.unidirectional
    );
    toMainMethodChannel.setMethodCallHandler((MethodCall call) async {
      print("toMainMethodChannel called $call");
      if(call.method == "sendSubWinPosition") {
        final arguments = json.decode(call.arguments as String);

        final dx = arguments["offset"]["dx"];
        final dy = arguments["offset"]["dy"];
        // windowManager.setPosition(Offset(dx, dy));

        if(key.currentContext != null) {
          final RenderBox box = key.currentContext!.findRenderObject() as RenderBox;
          final Offset topLeft = box.localToGlobal(Offset.zero);
          final Offset btmRight = box.localToGlobal(box.size.bottomRight(Offset.zero));

          // final Rect rect = Rect.fromPoints(topLeft, btmRight);

          // box의 위치만 사용하면 Flutter widget 기준
          // 넘어오는 Offset 정보는 윈도 전체 화면 기준이기 때문에 오차 발생
          // box의 offset에 현재 윈도의 위치 정보를 추가하여 보정
          final curWinPos = await windowManager.getPosition();
          final Rect rect = Rect.fromPoints(topLeft + curWinPos, btmRight + curWinPos);

          Offset subWinOffset = Offset(dx, dy);
          print("rect: ${rect}, subWinOffset: $subWinOffset");
          if(rect.contains(subWinOffset)){
            print("rect.contains(subWinOffset) :: ${rect.contains(subWinOffset)}");
          }
        }
        return null;
      }
    });
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

  // @override
  // void onWindowMove() async {
  //   print("onWindowMove");
  //   // final curPos = await windowManager.getPosition();
  //   // print("curPos: $curPos");
  //   // super.onWindowMove();
  // }
  // @override
  // void onWindowMoved() {
  //   print("onWindowMoved");
  //   super.onWindowMoved();
  // }

  @override
  void onWindowClose() async {
    exit(0);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
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
class _NewWindow extends State<NewWindow> with WindowListener {

  late final WindowMethodChannel _windowMethodChannel;
  late final WindowMethodChannel toMainWinMethodChannel;
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // 해당 윈도 전용 채널 생성
    _windowMethodChannel = WindowMethodChannel(
        "window_control_${widget.windowId}",
        mode: ChannelMode.unidirectional
    );

    // 메시지 핸들러 등록
    _windowMethodChannel.setMethodCallHandler(handleMethodCallback);

    toMainWinMethodChannel = WindowMethodChannel(
        "toMainWin",
        mode: ChannelMode.unidirectional
    );
  }

  @override
  void dispose(){
    _windowMethodChannel.setMethodCallHandler(null);
    toMainWinMethodChannel.setMethodCallHandler(null);

    windowManager.removeListener(this);
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

  @override
  void onWindowMoved() async {
    print("onWindowMoved");
    // 현재 마우스 커서 위치
    final curPos = await screenRetriever.getCursorScreenPoint();

    toMainWinMethodChannel.invokeMethod("sendSubWinPosition", jsonEncode({
      "offset": {
        "dx": curPos.dx,
        "dy": curPos.dy
      }
    }));

    super.onWindowMoved();
  }
}