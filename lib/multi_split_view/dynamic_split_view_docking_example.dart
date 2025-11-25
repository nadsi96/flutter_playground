import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// 1. Data Models
// =============================================================================

enum NodeType { split, leaf }

class TabData {
  String id;
  String title;
  TabData({required this.id, required this.title});

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
  factory TabData.fromJson(Map<String, dynamic> json) =>
      TabData(id: json['id'], title: json['title']);
}

class LayoutNode {
  String id;
  NodeType type;
  Axis? axis;
  List<LayoutNode> children;
  List<double>? ratios;
  List<TabData> tabs;
  int selectedTabIndex;

  LayoutNode({
    required this.id,
    required this.type,
    this.axis,
    List<LayoutNode>? children,
    this.ratios,
    List<TabData>? tabs,
    this.selectedTabIndex = 0,
  })  : children = children ?? [],
        tabs = tabs ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'axis': axis == Axis.horizontal ? 'horizontal' : 'vertical',
    'children': children.map((c) => c.toJson()).toList(),
    'ratios': ratios,
    'tabs': tabs.map((t) => t.toJson()).toList(),
    'selectedTabIndex': selectedTabIndex,
  };

  factory LayoutNode.fromJson(Map<String, dynamic> json) {
    NodeType type =
    json['type'] == 'NodeType.split' ? NodeType.split : NodeType.leaf;
    var node = LayoutNode(
      id: json['id'],
      type: type,
      axis: json['axis'] == 'horizontal' ? Axis.horizontal : Axis.vertical,
      selectedTabIndex: json['selectedTabIndex'] ?? 0,
      ratios: json['ratios'] != null ? List<double>.from(json['ratios']) : null,
    );
    if (json['children'] != null) {
      node.children = (json['children'] as List)
          .map((c) => LayoutNode.fromJson(c))
          .toList();
    }
    if (json['tabs'] != null) {
      node.tabs =
          (json['tabs'] as List).map((t) => TabData.fromJson(t)).toList();
    }
    return node;
  }
}

class DragPayload {
  final String sourceNodeId;
  final String tabId;
  DragPayload(this.sourceNodeId, this.tabId);
}

// =============================================================================
// 2. Main Screen & Logic
// =============================================================================

class DockingLayoutExample extends StatefulWidget {
  const DockingLayoutExample({super.key});

  @override
  State<DockingLayoutExample> createState() => _DockingLayoutExampleState();
}

class _DockingLayoutExampleState extends State<DockingLayoutExample> {
  LayoutNode? _rootNode;
  int _idCounter = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  String _generateId() {
    _idCounter++;
    return 'node_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  // --- Drag Callbacks ---
  void _onDragStarted() {
    if (!_isDragging) setState(() => _isDragging = true);
  }

  void _onDragEnded() {
    if (_isDragging) setState(() => _isDragging = false);
  }

  // --- Persistence ---
  Future<void> _saveLayout() async {
    if (_rootNode == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_layout_v9', jsonEncode(_rootNode!.toJson()));
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString('saved_layout_v9');
    if (json != null) {
      try {
        setState(() => _rootNode = LayoutNode.fromJson(jsonDecode(json)));
      } catch (e) {
        _initDefault();
      }
    } else {
      _initDefault();
    }
  }

  void _initDefault() {
    setState(() {
      _rootNode = LayoutNode(
        id: _generateId(),
        type: NodeType.leaf,
        tabs: [
          TabData(id: 't1', title: 'Watchlist'),
          TabData(id: 't2', title: 'Chart'),
        ],
      );
    });
  }

  // --- Helpers ---
  LayoutNode? _findNodeById(LayoutNode? current, String id) {
    if (current == null) return null;
    if (current.id == id) return current;
    for (var child in current.children) {
      var found = _findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // [핵심] 트리를 순회하며 빈 노드를 삭제하고, 자식이 1개인 경우 승격시키는 함수
  // ---------------------------------------------------------------------------
  LayoutNode? _cleanTree(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      // 탭이 없는 리프 노드는 삭제 대상(null 반환)
      return node.tabs.isEmpty ? null : node;
    } else {
      // Split Node: 자식들을 재귀적으로 정리
      List<LayoutNode> newChildren = [];
      for (var child in node.children) {
        var cleanedChild = _cleanTree(child);
        if (cleanedChild != null) {
          newChildren.add(cleanedChild);
        }
      }
      node.children = newChildren;

      // 자식이 다 없어졌으면 이 노드도 삭제
      if (node.children.isEmpty) return null;

      // 자식이 1개만 남았으면, 불필요한 분할이므로 자식을 위로 승격(Promotion)
      if (node.children.length == 1) {
        return node.children.first;
      }

      // 자식 수나 구조가 바뀌었을 수 있으므로 비율 정보는 초기화 (안전장치)
      if (node.ratios != null && node.ratios!.length != node.children.length) {
        node.ratios = null;
      }

      return node;
    }
  }

  // ---------------------------------------------------------------------------
  // 탭 드롭 처리 핸들러
  // ---------------------------------------------------------------------------
  void _handleTabDrop(String srcNodeId, String tabId, String targetNodeId,
      String action, {bool isRootDrop = false}) {

    setState(() => _isDragging = false);

    LayoutNode? srcNode = _findNodeById(_rootNode, srcNodeId);
    if (srcNode == null) return;

    // 자기 자신에게 드롭 시 방어 로직
    if (!isRootDrop && srcNodeId == targetNodeId) {
      if (action == 'center') return;
      if (srcNode.tabs.length <= 1) return;
    }

    // 1. 탭 찾기 및 제거
    int tabIndex = srcNode.tabs.indexWhere((t) => t.id == tabId);
    if (tabIndex == -1) return;
    TabData tabToMove = srcNode.tabs[tabIndex];

    setState(() {
      srcNode.tabs.removeAt(tabIndex);
      if (srcNode.selectedTabIndex >= srcNode.tabs.length) {
        srcNode.selectedTabIndex = srcNode.tabs.isEmpty ? 0 : srcNode.tabs.length - 1;
      }

      // 2. 트리 정리 (빈 노드 제거 및 승격)
      // 전체 영역 분할(isRootDrop)이거나 다른 노드로 이동할 때는
      // 소스 노드가 비면 즉시 정리하여 트리를 단순화해야 합니다.
      if (isRootDrop || srcNodeId != targetNodeId) {
        LayoutNode? cleanedRoot = _cleanTree(_rootNode!);
        // 모든 탭이 사라지는 경우는 없다고 가정(move이므로),
        // 하지만 만약 null이면 tabToMove만 가진 새 루트 생성
        if (cleanedRoot == null) {
          _rootNode = LayoutNode(
            id: _generateId(),
            type: NodeType.leaf,
            tabs: [],
          ); // 아래 로직에서 tabToMove 추가됨
        } else {
          _rootNode = cleanedRoot;
        }
      }

      // 3. 타겟 위치에 추가/분할
      if (isRootDrop) {
        // 루트 분할: 이미 _cleanTree를 거쳤으므로 _rootNode는 정리된 상태(예: 단일 노드)
        _splitRoot(tabToMove, action);
      } else {
        // 로컬 분할
        // _cleanTree 이후 targetNode 참조를 다시 찾아야 안전함 (ID 유지됨)
        LayoutNode? targetNode = _findNodeById(_rootNode, targetNodeId);
        if (targetNode != null) {
          if (action == 'center') {
            targetNode.tabs.add(tabToMove);
            targetNode.selectedTabIndex = targetNode.tabs.length - 1;
          } else {
            _splitNode(targetNode, tabToMove, action);
          }
        }
      }
      _saveLayout();
    });
  }

  void _splitNode(LayoutNode target, TabData newTab, String action) {
    LayoutNode existingChild = LayoutNode(
      id: _generateId(),
      type: NodeType.leaf,
      tabs: [...target.tabs],
      selectedTabIndex: target.selectedTabIndex,
    );
    LayoutNode newChild = LayoutNode(
        id: _generateId(),
        type: NodeType.leaf,
        tabs: [newTab],
        selectedTabIndex: 0);

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

  void _splitRoot(TabData newTab, String action) {
    LayoutNode oldRootContent = _rootNode!;
    LayoutNode newChild = LayoutNode(
      id: _generateId(),
      type: NodeType.leaf,
      tabs: [newTab],
    );

    LayoutNode newRoot = LayoutNode(
      id: _generateId(),
      type: NodeType.split,
      axis: (action == 'left' || action == 'right')
          ? Axis.horizontal
          : Axis.vertical,
      children: (action == 'left' || action == 'top')
          ? [newChild, oldRootContent]
          : [oldRootContent, newChild],
    );
    _rootNode = newRoot;
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {
    if (_rootNode == null) return const Scaffold();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Docking Layout'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                SharedPreferences.getInstance()
                    .then((p) => p.remove('saved_layout_v9'));
                _initDefault();
              })
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildRecursive(_rootNode!)),

          if (_isDragging) ...[
            _GlobalSplitButton(
              alignment: Alignment.topCenter,
              icon: Icons.keyboard_arrow_up,
              action: 'top',
              onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'top', isRootDrop: true),
            ),
            _GlobalSplitButton(
              alignment: Alignment.bottomCenter,
              icon: Icons.keyboard_arrow_down,
              action: 'bottom',
              onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'bottom', isRootDrop: true),
            ),
            _GlobalSplitButton(
              alignment: Alignment.centerLeft,
              icon: Icons.keyboard_arrow_left,
              action: 'left',
              onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'left', isRootDrop: true),
            ),
            _GlobalSplitButton(
              alignment: Alignment.centerRight,
              icon: Icons.keyboard_arrow_right,
              action: 'right',
              onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'right', isRootDrop: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecursive(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      return _DockingPane(
        node: node,
        onTabDrop: (src, tabId, action) =>
            _handleTabDrop(src, tabId, node.id, action),
        onAddTab: () => setState(() {
          node.tabs.add(TabData(id: _generateId(), title: 'New Tab'));
          node.selectedTabIndex = node.tabs.length - 1;
        }),
        onSelectTab: (idx) => setState(() => node.selectedTabIndex = idx),
        onDragStarted: _onDragStarted,
        onDragEnded: _onDragEnded,
      );
    } else {
      List<Widget> childrenWidgets =
      node.children.map((c) => _buildRecursive(c)).toList();

      List<Area> areas = [];
      for (int i = 0; i < childrenWidgets.length; i++) {
        // [수정 1] 저장된 비율(ratios)이 있으면 그것을 flex로 변환하여 적용
        // ratios는 0.0 ~ 1.0 사이의 값이므로 1000을 곱해 정수형 flex로 만듭니다.
        // 비율 정보가 없으면 기본값 1 (1:1 분할)을 사용합니다.
        double flex = 1;
        print("flag 1");
        if (node.ratios != null && i < node.ratios!.length) {
          print("flag 2 :: ${node.ratios![i]}");
          // 예: 비율이 0.3이면 flex는 300
          flex = (node.ratios![i] * 1000);
          print("flag 3 :: $flex");
          if (flex == 0) flex = 1; // 최소값 보정
        }
        print("flag 4 :: $flex");

        areas.add(Area(
          data: childrenWidgets[i],
          // size(고정 픽셀) 대신 flex(비율)를 사용해야 반응형으로 동작합니다.
          flex: flex,
        ));
      }

      MultiSplitViewController controller =
      MultiSplitViewController(areas: areas);

      return MultiSplitView(
        key: ValueKey(node.id),
        axis: node.axis!,
        controller: controller,
        builder: (context, area) => area.data as Widget,
        onDividerDragUpdate: (index) {
          // [수정] size 대신 flex를 사용하여 비율 계산

          // 1. 현재 영역들의 flex 합계 계산
          // flex로 생성된 Area는 드래그 시 flex 값이 자동으로 업데이트됩니다.
          double totalFlex = controller.areas.fold(0.0, (sum, area) => sum + (area.flex ?? 0.0));

          // 디버깅용 로그 (필요시 주석 해제)
          // print("dragFlag :: totalFlex: $totalFlex");

          if (totalFlex > 0) {
            // 2. 각 영역의 flex를 전체 flex로 나누어 비율(0.0~1.0)로 저장
            node.ratios = controller.areas.map((a) => (a.flex ?? 0.0) / totalFlex).toList();

            // 3. 저장
            _saveLayout();
          }
        },
      );
    }
  }
}

// =============================================================================
// 3. Global Split Button (이전과 동일)
// =============================================================================

class _GlobalSplitButton extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final String action;
  final Function(String srcNodeId, String tabId) onDrop;

  const _GlobalSplitButton({
    required this.alignment,
    required this.icon,
    required this.action,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 40;
    const double highlightThickness = 6;

    return Align(
      alignment: alignment,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        child: DragTarget<DragPayload>(
          onWillAccept: (_) => true,
          onAccept: (data) => onDrop(data.sourceNodeId, data.tabId),
          builder: (context, candidateData, rejectedData) {
            bool isHovering = candidateData.isNotEmpty;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (isHovering) _buildHighlight(action, highlightThickness),
                Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: isHovering ? Colors.blue : Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, spreadRadius: 1)
                    ],
                    border: Border.all(
                      color: isHovering ? Colors.blue.shade900 : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isHovering ? Colors.white : Colors.grey[700],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHighlight(String action, double thickness) {
    if (action == 'top') {
      return Positioned(top: 0, left: -5000, right: -5000, height: thickness, child: Container(color: Colors.blueAccent));
    } else if (action == 'bottom') {
      return Positioned(bottom: 0, left: -5000, right: -5000, height: thickness, child: Container(color: Colors.blueAccent));
    } else if (action == 'left') {
      return Positioned(left: 0, top: -5000, bottom: -5000, width: thickness, child: Container(color: Colors.blueAccent));
    } else {
      return Positioned(right: 0, top: -5000, bottom: -5000, width: thickness, child: Container(color: Colors.blueAccent));
    }
  }
}

// =============================================================================
// 4. Pane & Tab (이전과 동일)
// =============================================================================

class _DockingPane extends StatefulWidget {
  final LayoutNode node;
  final Function(String srcNode, String srcTab, String action) onTabDrop;
  final VoidCallback onAddTab;
  final Function(int) onSelectTab;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  const _DockingPane({
    required this.node,
    required this.onTabDrop,
    required this.onAddTab,
    required this.onSelectTab,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  State<_DockingPane> createState() => _DockingPaneState();
}

class _DockingPaneState extends State<_DockingPane> {
  String? _hoverAction;
  final GlobalKey _paneKey = GlobalKey();

  void _updateHoverAction(Offset globalPosition) {
    final RenderBox? renderBox =
    _paneKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size size = renderBox.size;
    final Offset localPos = renderBox.globalToLocal(globalPosition);
    final Offset center = Offset(size.width / 2, size.height / 2);

    const double selectorRadius = 60;
    final double dist = (localPos - center).distance;

    if (dist > selectorRadius * 1.5) {
      if (_hoverAction != null) setState(() => _hoverAction = null);
      return;
    }

    double dx = localPos.dx - center.dx;
    double dy = localPos.dy - center.dy;

    String newAction = 'center';
    const double centerZoneSize = 25;

    if (dx.abs() < centerZoneSize && dy.abs() < centerZoneSize) {
      newAction = 'center';
    } else {
      if (dx.abs() > dy.abs()) {
        newAction = dx > 0 ? 'right' : 'left';
      } else {
        newAction = dy > 0 ? 'bottom' : 'top';
      }
    }

    if (_hoverAction != newAction) {
      setState(() => _hoverAction = newAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      key: _paneKey,
      onWillAccept: (data) => data != null,
      onMove: (details) => _updateHoverAction(details.offset),
      onLeave: (_) => setState(() => _hoverAction = null),
      onAccept: (data) {
        if (_hoverAction != null) {
          widget.onTabDrop(data.sourceNodeId, data.tabId, _hoverAction!);
        }
        setState(() => _hoverAction = null);
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Stack(
          children: [
            Column(
              children: [
                Container(
                  height: 36,
                  color: Colors.grey[200],
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.node.tabs.length,
                          itemBuilder: (context, index) {
                            final tab = widget.node.tabs[index];
                            bool selected = index == widget.node.selectedTabIndex;
                            return _DraggableTab(
                              nodeId: widget.node.id,
                              tab: tab,
                              isSelected: selected,
                              onTap: () => widget.onSelectTab(index),
                              onDragStarted: widget.onDragStarted,
                              onDragEnded: widget.onDragEnded,
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: widget.onAddTab,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: widget.node.tabs.isEmpty
                        ? const Text("Empty")
                        : Text(widget.node.tabs[widget.node.selectedTabIndex].title,
                        style: const TextStyle(fontSize: 20, color: Colors.grey)),
                  ),
                ),
              ],
            ),
            if (isHovering) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  color: Colors.blueAccent.withOpacity(0.05),
                ),
              ),
              Center(
                child: _DockingSelectorVisual(highlightedAction: _hoverAction),
              ),
            ]
          ],
        );
      },
    );
  }
}

class _DockingSelectorVisual extends StatelessWidget {
  final String? highlightedAction;
  const _DockingSelectorVisual({this.highlightedAction});
  @override
  Widget build(BuildContext context) {
    const double boxSize = 40; const double gap = 4;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon('top', Icons.arrow_drop_up, boxSize),
          const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon('left', Icons.arrow_left, boxSize),
              const SizedBox(width: gap),
              _buildIcon('center', Icons.stop_rounded, boxSize, isCenter: true),
              const SizedBox(width: gap),
              _buildIcon('right', Icons.arrow_right, boxSize),
            ],
          ),
          const SizedBox(height: gap),
          _buildIcon('bottom', Icons.arrow_drop_down, boxSize),
        ],
      ),
    );
  }
  Widget _buildIcon(String action, IconData icon, double size, {bool isCenter = false}) {
    bool isHighlighted = highlightedAction == action;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.blue : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isHighlighted ? Colors.blue.shade900 : Colors.grey.shade400),
      ),
      child: Icon(icon, color: isHighlighted ? Colors.white : Colors.grey[600], size: isCenter ? 24 : 32),
    );
  }
}

class _DraggableTab extends StatelessWidget {
  final String nodeId;
  final TabData tab;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  const _DraggableTab({
    required this.nodeId,
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<DragPayload>(
      data: DragPayload(nodeId, tab.id),
      onDragStarted: onDragStarted,
      onDraggableCanceled: (_, __) => onDragEnded(),
      onDragEnd: (_) => onDragEnded(),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 150, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
            border: Border.all(color: Colors.blue),
          ),
          child: Text(tab.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildTabDesign()),
      child: GestureDetector(onTap: onTap, child: _buildTabDesign()),
    );
  }
  Widget _buildTabDesign() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isSelected ? Colors.white : Colors.transparent,
      child: Text(tab.title, style: TextStyle(color: isSelected ? Colors.blue : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }
}