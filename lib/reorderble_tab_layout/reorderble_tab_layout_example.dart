import 'package:flutter/material.dart';

class ReorderableTabLayoutExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ReorderableTabLayoutState();
  }
}

class ReorderableTabLayoutState extends State<ReorderableTabLayoutExample> {

  // test tab data
  List<TabData> tabItemList = [
    TabData(tabTitle: "item1", tabId: 1),
    TabData(tabTitle: "item2", tabId: 2),
    TabData(tabTitle: "item3", tabId: 3),
    TabData(tabTitle: "item4", tabId: 4),
    TabData(tabTitle: "item5", tabId: 5),
  ];

  // 현재 선택된 탭 id
  int selectedTabId = 1;


  @override
  Widget build(BuildContext context) {

    // 현재 선택된 탭 제목 찾기
    final selectedTabTitle = tabItemList.firstWhere((elem) {
      if(elem.tabId == selectedTabId) {
        return true;
      } else{
        return false;
      }
    });

    return Scaffold(
      body: Column(
        children: [
          // 탭바 영역
          Container(
            width: double.infinity,
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // tab list rendering
                for(int idx = 0; idx < tabItemList.length; idx++)
                  buildDraggableTab(idx, tabItemList[idx]),

                Expanded(
                  child: DragTarget<TabData>(
                    builder: (context, candidateData, rejectedData) {
                      return ColoredBox(
                        color: Colors.transparent
                      );
                    },
                    onWillAcceptWithDetails: (detail) {
                      if(detail.data != tabItemList.last){
                        setState(() {
                          moveTab(detail.data, tabItemList.length - 1);
                        });
                        return true;
                      }
                      return false;
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                "Selected $selectedTabTitle"
              )
            )
          )
        ],
      )
    );
  }

  /// tab 아이템 작성
  Widget buildDraggableTab(int idx, TabData tabData){
    bool bSelected = selectedTabId == tabData.tabId;

    Widget tabWidget({bool bGhost = false, bool bFeedback = false}) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bGhost
              ? Color(0xFF252525)
              : (bSelected ? Color(0xFF4A4A4A) : Colors.transparent),
          border: bSelected && !bGhost ? Border(top: BorderSide(color: Colors.blue, width: 2)) : null,
        ),
        child: Text(tabData.tabTitle, style: TextStyle(
          color: bGhost ? Colors.transparent : (bSelected ? Colors.white : Colors.grey),
          fontWeight: bSelected ? FontWeight.bold: FontWeight.normal,
          fontSize: 14,
          decoration: bFeedback ? TextDecoration.none : null,
        ),
        ),
      );
    }

    return DragTarget<TabData>(
        onWillAcceptWithDetails: (dragTargetDetail){
          if(dragTargetDetail.data.tabId != tabData.tabId) {
            setState(() {
              moveTab(dragTargetDetail.data, idx);
            });
            return true;
          }
          return false;
        },
        builder: (context, candidateData, rejectedData){
          return Draggable<TabData>(
            data: tabData,
            feedback: Container(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.7,
                child: tabWidget(bFeedback: true),
              ),
            ),
            childWhenDragging: tabWidget(bGhost: true),
            onDragStarted: (){},
            key: ValueKey(tabData.tabId),
            child: GestureDetector(
              onTap: () {
                setState( () {
                  selectedTabId = tabData.tabId;
                });
              },
              child: tabWidget(),
            ),
          );
        }
    );
  }

  void moveTab(TabData tabData, int newIdx){
    int oldIdx = tabItemList.indexOf(tabData);
    if(oldIdx == -1) return;

    if(oldIdx < newIdx){
      newIdx -= 1;
    }

    TabData temp = tabItemList.removeAt(oldIdx);
    tabItemList.insert(newIdx, temp);
  }
}

class TabData {
  String tabTitle;
  int tabId;

  TabData({required this.tabTitle, required this.tabId});
}