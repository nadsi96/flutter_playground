import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:window_manager/window_manager.dart';

/// 멀티 윈도 영역 밖 드랍 처리 체크
/// 밖에 떨구면 새 창으로 열기
/// 새 창에 드래그 앤 드랍으로는 탭 추가하지 않음
/// 새 창에서 외부로 드래그 드랍해도 새 창 생성하지 않음
/// 새 창에서 메인 윈도로 드래그 드랍하면 탭 이동 가능
final String TARGET_SCREEN = "multi_window_dnd_example2";
final String REMOVE_TAB = "remove_tab2";
final getWindowChannelName = (String windowId) => "multiWindowDnd2_$windowId";

class TabData{
  String id;
  String title;
  String content;

  int count = 0;

  TabData({required this.id, required this.title, required this.content, this.count = 0});
}

class DragPayload {
  String srcWindowId;
  TabData tabData;

  DragPayload({required this.srcWindowId, required this.tabData});
}

class MultiWindowDndExample extends StatefulWidget{

  final String windowId;
  TabData? tabData;

  final windowKey = GlobalKey();


  MultiWindowDndExample({required this.windowId, this.tabData});

  @override
  State<StatefulWidget> createState() {
    return MultiWindowDndState();
  }

}
class MultiWindowDndState extends State<MultiWindowDndExample> with WindowListener{

  List<TabData> tabs = [];
  TabData? selectedTabData;

  bool bOutSide = false; // 영역 외부 여부
  bool bPerformDropped = false;
  late WindowMethodChannel windowChannel;

  void initWindow() async {
    if(widget.windowId == "main") {
      await windowManager.setPreventClose(true);
    }

    windowChannel = WindowMethodChannel(
        getWindowChannelName(widget.windowId),
        mode: ChannelMode.unidirectional
    );
    windowChannel.setMethodCallHandler((call) async {
      // json data 전달했다 기준
      final jsonData = jsonDecode(call.arguments);
      if (call.method == REMOVE_TAB) {
        final tabId = jsonData["tabId"];
        removeTab(tabId);
        checkClose();
      }
      else {
        print("windowId: ${widget.windowId}, arguments: ${call.arguments}");
      }
    });
  }

  @override
  void initState() {
    super.initState();

    selectedTabData = widget.tabData;

    windowManager.addListener(this);

    initWindow();

    // 초기 데이터
    if(selectedTabData != null){
      tabs.add(selectedTabData!);
    } else{
      for(int idx = 1; idx <= 2; idx++){
        tabs.add(TabData(
            id: "tab_$idx",
            title: "Tab $idx",
            content: "Tab Content $idx"
        ));
      }
    }

    selectedTabData = tabs[0];
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
    final removeTargetIdx = tabs.indexWhere((tabItem) => tabItem.id == tabId);
    if(removeTargetIdx > -1) {
      int selectTargetIdx = tabs.length - 2;
      if(removeTargetIdx > 0){
        selectTargetIdx = removeTargetIdx - 1;
      }
      setState(() {
        selectedTabData = tabs[selectTargetIdx];
        tabs.removeWhere((tabItem) => tabItem.id == tabId);
      });
    }
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
      super.onWindowClose();
    }
    // super.onWindowClose();
  }


  Widget buildTabBar() {
    return DropRegion(
        formats: Formats.standardFormats,
        hitTestBehavior: HitTestBehavior.opaque,
        onDropEnded: (event) {

          if(bPerformDropped){
            return;
          }
          bPerformDropped = false;

          final item = event.session.items.first;
          print("onDropEnded :: $item");
          if(item.localData is Map<String, dynamic>) {
            // print("windowId: ${widget.windowId} :: ${item.localData}");

            final itemLocalData = (item.localData as Map<String, dynamic>);

            if(itemLocalData["srcWindowId"] == "main") {
              if(bOutSide) {
                // 기존 탭 삭제
                removeTab(itemLocalData["tabData"]["id"]);
                // 새 창 띄우기
                createNewWindow(mapTabData: itemLocalData["tabData"]);

              }
            }
          }



        },
        onDropOver: (event) {
          // widget.dragPosition = event.position.global;
          return DropOperation.copy;
        },
        onDropEnter: (event) {
          print("onDropEnter");
          bOutSide = false;
        },
        onDropLeave: (event) {
          print("onDropLeave");
          bOutSide = true;
        },
        onPerformDrop: (event) async {
          print("onPerformDrop");
          bPerformDropped = true;
          final item = event.session.items.first;
          final dataMap = item.localData as Map<String, dynamic>;

          String srcWindowId = dataMap["srcWindowId"];
          TabData tabData = TabData(
            id: dataMap["tabData"]["id"],
            title: dataMap["tabData"]["title"],
            content: dataMap["tabData"]["content"],
            count: dataMap["tabData"]["count"],
          );
          final payload = DragPayload(
              srcWindowId: srcWindowId,
              tabData: tabData
          );


          // 현재 윈도에서 이동이 아닌 경우,
          // 탭 보내준 원본 윈도에 삭제 요청
          if(payload.srcWindowId != widget.windowId) {
            await requestRemoveTab(payload.srcWindowId, payload.tabData.id);
          }

          // 자신 탭 목록에 추가
          if(!tabs.any((tab) => tab.id == payload.tabData.id)) {
            setState(() {
              tabs.add(payload.tabData);
            });
          }
        },
        child: SizedBox(
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

                        setState(() {
                          tabs.add(newTab);
                        });
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
        print("dragItemProvider");
        bPerformDropped = false;
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
                "content": tabData.content,
                "count": tabData.count
              }
            }
        );

        // print("dragItemProvider");
        // // 드래그 상태 변경시 타는 부분으로
        // // 외부 영역인지만 체크해서 처리
        // request.session.dragging.addListener(() {
        //   // 드래그 끝남
        //   // 위치 윈도 외부
        //   if(!request.session.dragging.value && !bInsideWindow){
        //     print("windowId: ${widget.windowId} :: exterior");
        //   } else {
        //     print("windowId: ${widget.windowId} :: interior");
        //   }
        // });
        return dragItem;
      },
      allowedOperations: () {
        return [DropOperation.copy, DropOperation.none];
      },
      child: DraggableWidget(
        child: InkWell(
          onTap: () {
            int targetIdx = tabs.indexWhere((t) => t.id == tabData.id);
            if(targetIdx > -1) {
              setState(() {
                selectedTabData = tabs[targetIdx];
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.red,
            child: Row(
              children: [
                Text(tabData.title),
                SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if(tabs.length > 1){
                      removeTab(tabData.id);
                      createNewWindow(tabData: tabData);
                    }
                  },
                  child: Icon(Icons.add_box_outlined, size: 24),
                ),
              ],
            ),
          ),
        ),
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

  void createNewWindow({TabData? tabData, Map<String, dynamic>? mapTabData}) async {
    if(tabData != null || mapTabData != null) {
      if(tabData != null) {
        mapTabData = {
          "id": tabData.id,
          "title": tabData.title,
          "content": tabData.content,
          "count": tabData.count,
        };
      }
    } else {
      return;
    }


    print("createNewWindow :: ${mapTabData}");
    final controller = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            "type": "newWindow",
            "targetScreen": TARGET_SCREEN,
            "data": {
              "tabData": mapTabData
            }
          }),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget.windowKey,
      appBar: AppBar(title: Text(widget.windowId == "main" ? "MultiWindow D&D" : getWindowChannelName(widget.windowId))),
      body: Column(
          children: [
            buildTabBar(),
            Expanded(
                child: Container(
                    color: Colors.grey,
                    child: Center(
                        child: Text(
                            tabs.isEmpty || selectedTabData == null ? "Empty" :  "${selectedTabData!.content} ${selectedTabData!.count}"
                        )
                    )
                )
            )
          ]
      ),
      floatingActionButton: Row(
          children: [
            FloatingActionButton(
                onPressed: () {
                  if(selectedTabData != null){
                    setState(() {
                      selectedTabData!.count -= 1;
                    });
                  }
                },
                child: Icon(Icons.exposure_minus_1)
            ),
            FloatingActionButton(
                onPressed: () {
                  if(selectedTabData != null){
                    setState(() {
                      selectedTabData!.count += 1;
                    });
                  }
                },
                child: Icon(Icons.plus_one)
            )
          ]
      ),
    );
  }
}


class MultiWindowDndExample_newWindow extends StatefulWidget {

  final String windowId;
  TabData? tabData;
  MultiWindowDndExample_newWindow({required this.windowId, this.tabData});

  @override
  State<StatefulWidget> createState() {
    return MultiWindowDndExample_newWindow_state();
  }

}
class MultiWindowDndExample_newWindow_state extends State<MultiWindowDndExample_newWindow> {

  TabData? selectedTabData;
  List<TabData> tabs = [];

  late WindowMethodChannel windowChannel;

  @override
  void initState() {
    super.initState();

    initWindow();

    selectedTabData = widget.tabData;

    // 초기 데이터
    if(selectedTabData != null){
      tabs.add(selectedTabData!);
    } else{
      for(int idx = 1; idx <= 2; idx++){
        tabs.add(TabData(
            id: "tab_$idx",
            title: "Tab $idx",
            content: "Tab Content $idx"
        ));
      }
    }

    selectedTabData = tabs[0];
  }

  void initWindow() async {

    windowChannel = WindowMethodChannel(
        getWindowChannelName(widget.windowId),
        mode: ChannelMode.unidirectional
    );
    windowChannel.setMethodCallHandler((call) async {
      print("windowId: ${widget.windowId} :: $call");
      // json data 전달했다 기준
      final jsonData = jsonDecode(call.arguments);
      if (call.method == REMOVE_TAB) {
        final tabId = jsonData["tabId"];
        removeTab(tabId);
        checkClose();
      }
      else {
        print("windowId: ${widget.windowId}, arguments: ${call.arguments}");
      }
    });
  }

  void checkClose(){
    if(tabs.isEmpty){
      print("window ${widget.windowId} is empty. closing ...");
      windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(getWindowChannelName(widget.windowId))),
      body: Column(
        children: [
          buildTabBar(),
          Expanded(
              child: Container(
                  color: Colors.grey,
                  child: Center(
                      child: Text(
                          tabs.isEmpty || selectedTabData == null ? "Empty" :  "${selectedTabData!.content} ${selectedTabData!.count}"
                      )
                  )
              )
          )
        ]
      )
    );
  }

  Widget buildTabBar() {
    return SizedBox(
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

                    setState(() {
                      tabs.add(newTab);
                    });
                  },
                  child: Icon(
                    Icons.add,
                    size: 50,
                  )
              )
            ]
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
                "content": tabData.content,
                "count": tabData.count
              }
            }
        );

        return dragItem;
      },
      allowedOperations: () {
        return [DropOperation.copy];
      },
      child: DraggableWidget(
        child: InkWell(
          onTap: () {
            int targetIdx = tabs.indexWhere((t) => t.id == tabData.id);
            if(targetIdx > -1) {
              setState(() {
                selectedTabData = tabs[targetIdx];
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.red,
            child: Row(
              children: [
                Text(tabData.title),
                SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if(tabs.length > 1){
                      removeTab(tabData.id);
                      createNewWindow(tabData: tabData);
                    }
                  },
                  child: Icon(Icons.add_box_outlined, size: 24),
                ),
              ],
            ),
          ),
        ),
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


  void removeTab(String tabId) {
    final removeTargetIdx = tabs.indexWhere((tabItem) => tabItem.id == tabId);
    if(removeTargetIdx > -1) {
      int selectTargetIdx = tabs.length - 2;
      if(removeTargetIdx > 0){
        selectTargetIdx = removeTargetIdx - 1;
      }
      setState(() {
        if(selectTargetIdx > -1){
         selectedTabData = tabs[selectTargetIdx];
        } else{
          selectedTabData = null;
        }
        tabs.removeWhere((tabItem) => tabItem.id == tabId);
      });
    }
  }

  void createNewWindow({TabData? tabData, Map<String, dynamic>? mapTabData}) async {
    if(tabData != null || mapTabData != null) {
      if(tabData != null) {
        mapTabData = {
          "id": tabData.id,
          "title": tabData.title,
          "content": tabData.content,
          "count": tabData.count,
        };
      }
    } else {
      return;
    }


    final controller = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            "type": "newWindow",
            "targetScreen": TARGET_SCREEN,
            "data": {
              "tabData": mapTabData
            }
          }),
        )
    );
  }
}