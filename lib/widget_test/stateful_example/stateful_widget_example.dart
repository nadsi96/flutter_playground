import 'package:flutter/material.dart';

///
/// 탭 변경에 대한 state 관리
/// 최상위뷰의 root는 데이터만 갱신
/// setState로 처리는 각 pane에서만 처리하여 탭 변경, 카운트 변경 시
/// 해당 pane영역만 갱신되도록 처리
class StatefulWidgetExample extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("StatefulWidget Example")),
      body: _StatefulWidgetExample(),
    );
  }

}

class _StatefulWidgetExample extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return __StatefulWidgetExample();
  }
}

class __StatefulWidgetExample extends State<_StatefulWidgetExample> {

  late TabSet root;

  int idCount = 0;
  String getId(){
    return "node_${idCount++}";
  }
  @override
  void initState() {
    root = TabSet(
      id: getId(),
      children: [
        TabSet(
            id: getId(),
            tabs: [
              TabItem(id: getId()),
              TabItem(id: getId()),
              TabItem(id: getId()),
            ]
        ),
        TabSet(
            id: getId(),
            tabs: [
              TabItem(id: getId()),
              TabItem(id: getId()),
              TabItem(id: getId()),
            ],
        ),
      ],
    );
    super.initState();
  }

  Widget buildRecursive(TabSet node){
    if(node.children != null) {
      if(node.children!.isNotEmpty) {
        List<Widget> children = node.children!.map((childNode) => Expanded(child: buildRecursive(childNode))).toList();
        return Row(
          spacing: 4,
          children: children
        );
      }

    } else if(node.tabs != null) {
      return TabPane(node: node);
    }

    return getEmpty();
  }

  Widget getEmpty(){
    return Container(
        color: Colors.grey,
        alignment: Alignment.center,
        child: Text("empty")
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Expanded(
            child: buildRecursive(root),
          ),
          TextButton(onPressed: () {
            root;
          }, child: Container(
            color: Colors.blueGrey,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text("check"),
          ),),
        ]
    );
  }

}

class EmptyWidget extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
        child: Container(
            color: Colors.grey,
            alignment: Alignment.center,
            child: Text("empty")
        )
    );
  }
}

/// Pane
/// 각 영역에서 탭 변경, 카운트 갱신
class TabPane extends StatefulWidget{

  TabSet node;
  // final List<TabItem> tabList;
  TabPane({required this.node});

  @override
  State<StatefulWidget> createState() {
    return _TabPaneState();
  }

}
class _TabPaneState extends State<TabPane>{

  @override
  Widget build(BuildContext context) {
    return buildPane(widget.node);
  }

  Widget buildPane(TabSet node) {
    print("nTest :: ${node.id} selectedIdx: ${node.selectedIdx}");
    if (node.selectedIdx > -1) {
      print("selectedNode :: count: ${node.tabs![node.selectedIdx]!.count}");
    }
    return SizedBox.expand(
      child: Column(
        children: [
          /// 탭 헤더
          SizedBox(
              height: 50,
              width: double.infinity,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: node.tabs?.length ?? 0,
                itemBuilder: (context, idx) {
                  final title = node.tabs?[idx].title ??
                      "unSelected. idx: $idx";
                  return InkWell(
                      onTap: () {
                        setState(() {
                          node.selectedIdx = idx;
                        });
                      },
                      child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          color: idx == node.selectedIdx ? Colors.blue : Colors
                              .blueGrey,
                          child: Text(title)
                      )
                  );
                },
              )
          ),
          /// 탭 컨텐츠 영역
          Expanded(
            child: node.selectedIdx > -1
                ? Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.grey,
                    alignment: Alignment.center,
                    child: Text(
                        "${node.tabs?[node.selectedIdx].title ?? ""}_${node
                            .tabs?[node.selectedIdx].count ?? ""}"),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  right: 12,
                  child: IconButton(
                    icon: Icon(Icons.add, size: 36),
                    onPressed: () {
                      setState(() {
                        node.tabs?[node.selectedIdx].count++;
                      });
                    },),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: IconButton(
                    icon: Icon(Icons.horizontal_rule, size: 36),
                    onPressed: () {
                      setState(() {
                        node.tabs?[node.selectedIdx].count--;
                      });
                    },),
                ),
              ],
            )
                : EmptyWidget(),
          ),
        ],
      ),
    );
  }

}

/// 탭 컨테이너 노드
/// 영역을 분할하여 하위에 TabSet을 child로 갖거나
/// tabs로 탭을 보여주는 pane
class TabSet{
  String id;
  List<TabSet>? children;
  List<TabItem>? tabs;
  int selectedIdx = -1;

  TabSet({required this.id, this.children, this.tabs, this.selectedIdx = -1});
}
class TabItem{
  String id;
  int count;
  String title = '';
  TabItem({required this.id, this.count = 0}){
    title = id;
  }
}