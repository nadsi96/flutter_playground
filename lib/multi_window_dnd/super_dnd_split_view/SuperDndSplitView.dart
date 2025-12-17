import 'package:docking/docking.dart' hide TabData;
import 'package:flutter/material.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_split_view/docking_pane.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_split_view/global_split_btn.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_split_view/split_view_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_split_view/super_dnd_split_view_model.dart';

class SuperDndSplitView extends ConsumerStatefulWidget {
  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _SuperDndSplitView();
  }


}

class _SuperDndSplitView extends ConsumerState<SuperDndSplitView> {

  LayoutNode? _rootNode;
  int idCounter = 0;


  String generateId(){
    return "nodeId_${idCounter++}";
  }

  LayoutNode? findNodeById(LayoutNode? current, String id) {
    if (current == null) return null;
    if (current.id == id) return current;
    for (var child in current.children) {
      var found = findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  LayoutNode? cleanTree(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      return node.tabs.isEmpty ? null : node;
    } else {
      List<LayoutNode> newChildren = [];
      for (var child in node.children) {
        var cleanedChild = cleanTree(child);
        if (cleanedChild != null) {
          newChildren.add(cleanedChild);
        }
      }
      node.children = newChildren;

      if (node.children.isEmpty) return null;
      if (node.children.length == 1) return node.children.first;

      if (node.ratios != null && node.ratios!.length != node.children.length) {
        node.ratios = null;
      }
      return node;
    }
  }

  /// 탭 순서 변경(동일 영역 내)
  void handleTabReorder(String nodeId, String tabId, int targetIndex, String? tabHoverSide) {
    LayoutNode? node = findNodeById(_rootNode, nodeId);
    if (node == null) return;
    int oldIndex = node.tabs.indexWhere((t) => t.id == tabId);
    if (oldIndex == -1) return;

    if (oldIndex < targetIndex && tabHoverSide != "right") {
      return;
    } else if (oldIndex > targetIndex && tabHoverSide != "left") {
      return;
    }

    setState(() {
      TabData tab = node.tabs.removeAt(oldIndex);
      node.tabs.insert(targetIndex, tab);
      node.selectedTabIndex = targetIndex;
    });
  }

  /// 다른 영역으로 이동/분할 처리
  void handleTabDrop(String srcNodeId, String tabId, String targetNodeId, String action, {bool isRootDrop = false}) {
    ref.read(sDNDGlobalDragStateProvider.notifier).endDrag();
    ref.read(globalSplitBtnProvider.notifier).setGlobalSplitBtnVisible(false);
    LayoutNode? srcNode = findNodeById(_rootNode, srcNodeId);
    if (srcNode == null) return;

    if (!isRootDrop && srcNodeId == targetNodeId) {
      if (action == 'center') return;
      if (srcNode.tabs.length <= 1) return;
    }

    int tabIndex = srcNode.tabs.indexWhere((t) => t.id == tabId);
    if (tabIndex == -1) return;
    TabData tabToMove = srcNode.tabs[tabIndex];

    setState(() {
      srcNode.tabs.removeAt(tabIndex);
      if (srcNode.selectedTabIndex >= srcNode.tabs.length) {
        srcNode.selectedTabIndex = srcNode.tabs.isEmpty ? 0 : srcNode.tabs.length - 1;
      }

      if (isRootDrop || srcNodeId != targetNodeId) {
        LayoutNode? cleanedRoot = cleanTree(_rootNode!);
        _rootNode = cleanedRoot ?? LayoutNode(id: generateId(), type: NodeType.leaf, tabs: []);
      }

      if (isRootDrop) {
        splitRoot(tabToMove, action);
      } else {
        LayoutNode? targetNode = findNodeById(_rootNode, targetNodeId);
        if (targetNode != null) {
          if (action == 'center') {
            targetNode.tabs.add(tabToMove);
            targetNode.selectedTabIndex = targetNode.tabs.length - 1;
          } else {
            splitNode(targetNode, tabToMove, action);
          }
        }
      }
    });
  }

  /// 영역 분할 후 탭 추가
  void splitNode(LayoutNode target, TabData newTab, String action) {
    LayoutNode existingChild = LayoutNode(
      id: generateId(),
      type: NodeType.leaf,
      tabs: [...target.tabs],
      selectedTabIndex: target.selectedTabIndex,
    );
    LayoutNode newChild = LayoutNode(id: generateId(), type: NodeType.leaf, tabs: [newTab]);

    target.type = NodeType.split;
    target.tabs = [];
    target.ratios = null;

    if (action == 'left') {
      target.axis = Axis.horizontal;
      target.children = [newChild, existingChild];
    } else if (action == 'right') {
      target.axis = Axis.horizontal;
      target.children = [existingChild, newChild];
    } else if (action == 'top') {
      target.axis = Axis.vertical;
      target.children = [newChild, existingChild];
    } else if (action == 'bottom') {
      target.axis = Axis.vertical;
      target.children = [existingChild, newChild];
    }
  }

  /// 전체 영역(최상위 노드) 분할하여 탭 추가
  void splitRoot(TabData newTab, String action) {
    LayoutNode oldRootContent = _rootNode!;
    LayoutNode newChild = LayoutNode(id: generateId(), type: NodeType.leaf, tabs: [newTab]);

    _rootNode = LayoutNode(
      id: generateId(),
      type: NodeType.split,
      axis: (action == 'left' || action == 'right') ? Axis.horizontal : Axis.vertical,
      children: (action == 'left' || action == 'top') ? [newChild, oldRootContent] : [oldRootContent, newChild],
    );
  }

  Widget buildRecursive(LayoutNode node) {
    if(node.type == NodeType.leaf) {
      return DockingPane();
    } else{
      List<Widget> childrenWidgets = node.children.map((child) => buildRecursive(child)).toList();
      List<Area> areas = [];
      for(int idx = 0; idx < childrenWidgets.length; idx++){
        double? flex = (node.ratios != null && idx < node.ratios!.length) ? node.ratios![idx] : null;
        areas.add(Area(data:childrenWidgets[idx], flex: flex));
      }

      MultiSplitViewController controller = MultiSplitViewController(areas: areas);

      return MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 5,
          dividerPainter: DividerPainter(
            backgroundColor: Colors.grey,
            highlightedBackgroundColor: Colors.blueAccent,
          ),
        ),
        child: MultiSplitView(
          key: ValueKey(node.id),
          axis: node.axis!,
          controller: controller,
          builder: (context, area) {
            return area.data as Widget;
          },
          onDividerDragUpdate: (idx) {
            double totalFlex = controller.areas.fold(0.0, (sum, area) {
              return sum + (area.flex ?? 1.0);
            });

            // 저장
          }
        )
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _rootNode = LayoutNode(
        id: generateId(),
        type: NodeType.split,
        axis: Axis.horizontal,
      ratios: [1,1],
      children: [
        LayoutNode(
            id: generateId(),
            type: NodeType.leaf,
            tabs: [
              TabData(id: generateId(), title: "tab_$idCounter", categoryId: "tabContents"),
              TabData(id: generateId(), title: "tab_$idCounter", categoryId: "tabContents"),
              TabData(id: generateId(), title: "tab_$idCounter", categoryId: "tabContents"),
            ]
        ),
        LayoutNode(
            id: generateId(),
            type: NodeType.leaf,
            tabs: [
              TabData(id: generateId(), title: "tab_$idCounter", categoryId: "tabContents"),
              TabData(id: generateId(), title: "tab_$idCounter", categoryId: "tabContents"),
              TabData(id: generateId(), title: "tab_$idCounter", categoryId: "tabContents"),
            ]
        )
      ]

    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Scaffold(
          appBar: AppBar(title: Text("SuperDndSplitView example")),
          body: SizedBox.expand(
              child: LayoutBuilder(
                  builder: (context, constraits) {
                    return ClipRect(
                        child: Stack(
                            children: [
                              Positioned.fill(child: buildRecursive(_rootNode!)),
                              Stack(
                                  children: [
                                    GlobalSplitBtn(align: Alignment.topCenter, icon: Icons.keyboard_arrow_up, onGlobalSplit: (String nodeId, String tabId) { handleTabDrop(nodeId, tabId, "", "top", isRootDrop: true); },),
                                    GlobalSplitBtn(align: Alignment.centerRight, icon: Icons.keyboard_arrow_right, onGlobalSplit: (String nodeId, String tabId) { handleTabDrop(nodeId, tabId, "", "right", isRootDrop: true); },),
                                    GlobalSplitBtn(align: Alignment.bottomCenter, icon: Icons.keyboard_arrow_down, onGlobalSplit: (String nodeId, String tabId) { handleTabDrop(nodeId, tabId, "", "bottom", isRootDrop: true); },),
                                    GlobalSplitBtn(align: Alignment.centerLeft, icon: Icons.keyboard_arrow_left, onGlobalSplit: (String nodeId, String tabId) { handleTabDrop(nodeId, tabId, "", "left", isRootDrop: true); },),
                                  ]
                              )
                            ]
                        )
                    );
                  }
              )
          )
      )
    );
  }
}