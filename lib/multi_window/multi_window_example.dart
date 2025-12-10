import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class MultiWindowExample extends StatefulWidget {
  MultiWindowExample({super.key});

  @override
  State<StatefulWidget> createState() {
    return MultiWindowExampleState();
  }

}

class MultiWindowExampleState extends State<MultiWindowExample> with WindowListener{

  List<String> childWindowIds = [];

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
  void onWindowClose() async{
    for(final childWindowId in childWindowIds) {
      // 서브 윈도에 close 메시지 전송
      final channel = WindowMethodChannel(
        "window_control_${childWindowId}",
        mode: ChannelMode.unidirectional
      );
      await channel.invokeMethod("close");
    }

    // 메인 윈도 종료
    await windowManager.destroy();
  }
  @override
  Widget build(BuildContext context) {

    int count = 0;

    return Scaffold(
      appBar: AppBar(title: Text("MultiWindow Example"),),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: [
            getNewWindowBtn(sText: "open new window", onTapFunc: () async {
              count += 1;
              final controller = await WindowController.create(
                  WindowConfiguration(
                    arguments: jsonEncode({
                      "type": "newWindow",
                      "data": {
                        "count": count
                      }
                    }),
                  )
              );
              childWindowIds.add(controller.windowId);
            }),
          ],
        ),
      ),
    );
  }

  Widget getNewWindowBtn({required String sText, Function()? onTapFunc}){
    return InkWell(
      onTap: onTapFunc,
      child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.blue,
          child: Text(sText)
      ),
    );
  }

}


class NewWindow extends StatefulWidget{
  String windowId;
  int count;

  NewWindow({super.key, required this.windowId, required this.count});

  @override
  State<StatefulWidget> createState() {
    return NewWindowState();
  }
}

class NewWindowState extends State<NewWindow>{

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

  Future<dynamic> handleMethodCallback(MethodCall call) async {

    // 종료 처리
    if(call.method == "close") {
      await windowManager.close();
      return "closed";
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("New Window ${widget.windowId}")),
        body: Center(
            child: Text("new window count: ${widget.count}")
        ),
      floatingActionButton: FloatingActionButton(onPressed: (){
        setState(() {
          widget.count++;
        });
      }),
    );
  }
}