import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:window_manager/window_manager.dart';

final String REMOVE_TAB = "remove_tab";
final getWindowChannelName = (String windowId) => "window_$windowId";

class TabData{
  String id;
  String title;
  String content;

  TabData({required this.id, required this.title, required this.content});
}

class DragPayload {
  String srcWindowId;
  TabData tabData;

  DragPayload({required this.srcWindowId, required this.tabData});
}

class MultiWindowDndExample extends StatefulWidget{

  final String windowId;
  final TabData? tabData;

  MultiWindowDndExample({required this.windowId, this.tabData});

  @override
  State<StatefulWidget> createState() {
    return MultiWindowDndState();
  }

}
class MultiWindowDndState extends State<MultiWindowDndExample> with WindowListener{

  List<TabData> tabs = [];
  int selectedTabIdx = 0;

  late WindowMethodChannel windowChannel;

  @override
  void initState() async {
    super.initState();
    windowManager.addListener(this);

    await windowManager.setPreventClose(true);

    windowChannel = WindowMethodChannel(
        getWindowChannelName(widget.windowId),
      mode: ChannelMode.unidirectional
    );
    windowChannel.setMethodCallHandler((call) async {
      // json data 전달했다 기준
      final jsonData = jsonDecode(call.arguments);
      if(call.method == REMOVE_TAB){
        final tabId = jsonData["tabId"];
        removeTab(tabId);
        checkClose();
      }
      else {
        print("windowId: ${widget.windowId}, arguments: ${call.arguments}");
      }
    });

    // 초기 데이터
    if(widget.tabData != null){
      tabs.add(widget.tabData!);
    } else{
      for(int idx = 1; idx <= 2; idx++){
        tabs.add(TabData(
          id: "tab_$idx",
          title: "Tab $idx",
          content: "Tab Content $idx"
        ));
      }
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    // 핸들러 해제 // 메모리 누수 방지 및 채널 정리
    windowChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> requestRemoveTab(String targetWindowId, String tabId) async {
    // 상대방 윈도 채널 타겟팅
    final targetChannel = WindowMethodChannel(
        getWindowChannelName(targetWindowId),
        mode: ChannelMode.unidirectional
    );

    try{
      await targetChannel.invokeMethod(REMOVE_TAB, jsonEncode({"tabId": tabId}));
    } catch (e) {
      print(e);
    }
  }

  void removeTab(String tabId) {
    setState(() {
      tabs.removeWhere((tabItem) => tabItem.id == tabId);
    });
  }

  void checkClose(){
    if(tabs.isEmpty && widget.windowId != "main"){
      print("window ${widget.windowId} is empty. closing ...");
      windowManager.close();
    }
  }

  @override
  void onWindowClose() async {
    if(widget.windowId == "main") {
      // 메인 윈도 종료면 서브 윈도들 종료 처리
      exit(0);
    } else{
      await windowManager.destroy();
    }
    // super.onWindowClose();
  }


  Widget buildTabBar() {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        // 앱 내부 드래그인가
        final item = event.session.items.first;
        if(item.localData is Map<String, dynamic>) {
          return DropOperation.copy;
        } else {
          return DropOperation.none;
        }
      },
      onPerformDrop: (event) async {
        final item = event.session.items.first;
        final dataMap = item.localData as Map<String, dynamic>;

        String srcWindowId = dataMap["srcWindowId"];
        TabData tabData = TabData(
          id: dataMap["tabData"]["id"],
          title: dataMap["tabData"]["title"],
          content: dataMap["tabData"]["content"],

        );
        final payload = DragPayload(
            srcWindowId: srcWindowId,
            tabData: tabData
        );

        // 자신 탭 목록에 추가
        if(!tabs.any((tab) => tab.id == payload.tabData.id)) {
          setState(() {
            tabs.add(payload.tabData);
          });
        }

        // 탭 보내준 원본 윈도에 삭제 요청
        if(payload.srcWindowId != widget.windowId) {
          await requestRemoveTab(payload.srcWindowId, payload.tabData.id);
        }
      },
      child: Container(
        height: 50,
        width: double.infinity,
        child: Row(
          children: [
            for(final tabItem in tabs) getDraggableTab(tabItem),
            InkWell(
              onTap: () {
                final newTab = TabData(
                  id: DateTime.now().toString(),
                  title: "New Tab",
                  content: "new Content"
                );

                createNewWindow(newTab);
              },
              child: Icon(
                Icons.add,
                size: 50,
              )
            )
          ]
        )
      )
    );
  }

  Widget getDraggableTab(TabData tabData) {
    return DragItemWidget(
      dragItemProvider: (request) async {
        // 드래그 데이터
        final payload = DragPayload(
          srcWindowId: widget.windowId,
          tabData: tabData
        );

        final dragItem = DragItem(
          localData: {
            "srcWindowId": widget.windowId,
            "tabData": {
              "id": tabData.id,
              "title": tabData.title,
              "content": tabData.content
            }
          }
        );

        dragItem.add(Formats.plainText(tabData.title));

        return dragItem;
      },
      allowedOperations: () {
        return [DropOperation.copy];
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        color: Colors.red,
        child: Text(tabData.title)
      ),
      dragBuilder: (context, child) {
        return Opacity(
          opacity: 0.5,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.blue,
            child: Text(tabData.title),
          ),
        );
      },

    );
  }

  void createNewWindow(TabData tabData) {
    // todo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.windowId == "main" ? "MultiWindow D&D" : getWindowChannelName(widget.windowId))),
      body: Column(
        children: [
          buildTabBar(),
          Expanded(
            child: Container(
              color: Colors.grey,
              child: Center(
                child: Text(
                  tabs.isEmpty && tabs.length > selectedTabIdx ? "Empty" :  tabs[selectedTabIdx].content
                )
              )
            )
          )
        ]
      ),
    );
  }
  
}