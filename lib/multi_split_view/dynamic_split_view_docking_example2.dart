import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// 0. Riverpod Providers
// =============================================================================

// [상태 1] 각 패널(Node)별 호버 액션 상태
final hoverActionProvider = StateProvider.family<String?, String>((ref, nodeId) => null);

// [상태 2] 전역 드래그 상태 관리
class GlobalDragState {
  final bool isDragging;
  final bool isGlobalButtonsVisible;
  final bool hasLeftTabHeader;

  GlobalDragState({
    this.isDragging = false,
    this.isGlobalButtonsVisible = false,
    this.hasLeftTabHeader = false,
  });

  GlobalDragState copyWith({bool? isDragging, bool? isGlobalButtonsVisible, bool? hasLeftTabHeader}) {
    return GlobalDragState(
      isDragging: isDragging ?? this.isDragging,
      isGlobalButtonsVisible: isGlobalButtonsVisible ?? this.isGlobalButtonsVisible,
      hasLeftTabHeader: hasLeftTabHeader ?? this.hasLeftTabHeader,
    );
  }
}

class GlobalDragStateNotifier extends StateNotifier<GlobalDragState> {
  GlobalDragStateNotifier() : super(GlobalDragState());

  void startDrag() => state = state.copyWith(isDragging: true, isGlobalButtonsVisible: false, hasLeftTabHeader: false);

  void endDrag() => state = state.copyWith(isDragging: false, isGlobalButtonsVisible: false, hasLeftTabHeader: false);

  void setGlobalVisibility(bool visible) {
    if (state.isGlobalButtonsVisible != visible) {
      state = state.copyWith(isGlobalButtonsVisible: visible);
    }
  }

  void markLeftTabHeader() {
    if (!state.hasLeftTabHeader) {
      state = state.copyWith(hasLeftTabHeader: true, isGlobalButtonsVisible: true);
    }
  }
}

final globalDragStateProvider = StateNotifierProvider<GlobalDragStateNotifier, GlobalDragState>((ref) {
  return GlobalDragStateNotifier();
});

// =============================================================================
// 1. Constants & Data Models
// =============================================================================

const KEY_SAVED_LAYOUT_DATA = "saved_layout_riverpod_v3"; // 버전 업
const APP_BACKGROUND_COLOR = Color(0xFFF0F2F5);
const GENIE_ACCENT_COLOR = Color(0xFF52C2DF);
const GENIE_ACCENT_COLOR_OP05 = Color.fromRGBO(82, 194, 223, 0.05);
const GENIE_ACCENT_COLOR_OP10 = Color.fromRGBO(82, 194, 223, 0.1);
const GENIE_ACCENT_COLOR_OP30 = Color.fromRGBO(82, 194, 223, 0.3);
const ACCENT_PURPLE = Color(0xFF50CDEC);
const ACCENT_PURPLE_ACTIVE = Color(0xFF329FC4);

const double BTN_GLOBAL_SPLIT_SIZE = 40;
const double BTN_GLOBAL_SPLIT_HIGHLIGHT_THICKNESS = 6;
const double TAB_TITLE_FONT_SIZE = 10;
const double TAB_HEADER_HEIGHT = 36.0;
const double BTN_DOCKING_SELECTOR_SIZE = 40;
const double BTN_DOCKING_SELECOTR_GAP = 4;
const double DOCKING_PANE_BORDER_THRESHOLD = 15.0;

enum NodeType { split, leaf }

class TabData {
  String id;
  String title;
  String categoryId;
  TabData({required this.id, required this.title, required this.categoryId});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'categoryId': categoryId};
  factory TabData.fromJson(Map<String, dynamic> json) => TabData(
    id: json['id'], title: json['title'], categoryId: json['categoryId'],
  );
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
    required this.id, required this.type, this.axis,
    List<LayoutNode>? children, this.ratios, List<TabData>? tabs,
    this.selectedTabIndex = 0,
  }) : children = children ?? [], tabs = tabs ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.toString(), 'axis': axis == Axis.horizontal ? 'horizontal' : 'vertical',
    'children': children.map((c) => c.toJson()).toList(), 'ratios': ratios,
    'tabs': tabs.map((t) => t.toJson()).toList(), 'selectedTabIndex': selectedTabIndex,
  };

  factory LayoutNode.fromJson(Map<String, dynamic> json) {
    NodeType type = json['type'] == 'NodeType.split' ? NodeType.split : NodeType.leaf;
    var node = LayoutNode(
      id: json['id'], type: type,
      axis: json['axis'] == 'horizontal' ? Axis.horizontal : Axis.vertical,
      selectedTabIndex: json['selectedTabIndex'] ?? 0,
      ratios: json['ratios'] != null ? List<double>.from(json['ratios']) : null,
    );
    if (json['children'] != null) node.children = (json['children'] as List).map((c) => LayoutNode.fromJson(c)).toList();
    if (json['tabs'] != null) node.tabs = (json['tabs'] as List).map((t) => TabData.fromJson(t)).toList();
    return node;
  }
}

class DragPayload {
  final String sourceNodeId;
  final String tabId;
  DragPayload(this.sourceNodeId, this.tabId);
}

// =============================================================================
// 2. Main Wrapper
// =============================================================================

class DockingLayoutExample2 extends StatelessWidget {
  const DockingLayoutExample2({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _DockingLayoutContent(),
    );
  }
}

// =============================================================================
// 3. Main Logic
// =============================================================================

class _DockingLayoutContent extends ConsumerStatefulWidget {
  const _DockingLayoutContent();

  @override
  ConsumerState<_DockingLayoutContent> createState() => _DockingLayoutContentState();
}

class _DockingLayoutContentState extends ConsumerState<_DockingLayoutContent> {
  LayoutNode? _rootNode;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _initDefaultSync();
    _loadLayout();
  }

  String _generateId() {
    _idCounter++;
    return 'node_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  void _initDefaultSync() {
    _rootNode = LayoutNode(
      id: _generateId(), type: NodeType.leaf,
      tabs: [
        TabData(id: 't1', title: 'Watchlist', categoryId: 's20000'),
        TabData(id: 't2', title: 'Chart', categoryId: 's20001'),
      ],
    );
  }

  Future<void> _loadLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? json = prefs.getString(KEY_SAVED_LAYOUT_DATA);
      if (json != null && mounted) {
        setState(() => _rootNode = LayoutNode.fromJson(jsonDecode(json)));
      }
    } catch (_) {}
  }

  Future<void> _saveLayout() async {
    if (_rootNode == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(KEY_SAVED_LAYOUT_DATA, jsonEncode(_rootNode!.toJson()));
    } catch (_) {}
  }

  LayoutNode? _findNodeById(LayoutNode? current, String id) {
    if (current == null) return null;
    if (current.id == id) return current;
    for (var child in current.children) {
      var found = _findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  LayoutNode? _cleanTree(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      return node.tabs.isEmpty ? null : node;
    } else {
      List<LayoutNode> newChildren = [];
      for (var child in node.children) {
        var cleanedChild = _cleanTree(child);
        if (cleanedChild != null) newChildren.add(cleanedChild);
      }
      node.children = newChildren;
      if (node.children.isEmpty) return null;
      if (node.children.length == 1) return node.children.first;
      if (node.ratios != null && node.ratios!.length != node.children.length) node.ratios = null;
      return node;
    }
  }

  void _handleTabReorder(String nodeId, String tabId, int targetIndex) {
    ref.read(globalDragStateProvider.notifier).endDrag();
    LayoutNode? node = _findNodeById(_rootNode, nodeId);
    if (node == null) return;
    int oldIndex = node.tabs.indexWhere((t) => t.id == tabId);
    if (oldIndex == -1) return;

    setState(() {
      if (oldIndex < targetIndex) {
        targetIndex -= 1;
      }

      TabData tab = node.tabs.removeAt(oldIndex);
      node.tabs.insert(targetIndex, tab);
      node.selectedTabIndex = targetIndex;
      _saveLayout();
    });
  }

  void _handleTabDrop(String srcNodeId, String tabId, String targetNodeId, String action, {bool isRootDrop = false}) {
    ref.read(globalDragStateProvider.notifier).endDrag();
    LayoutNode? srcNode = _findNodeById(_rootNode, srcNodeId);
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
        LayoutNode? cleanedRoot = _cleanTree(_rootNode!);
        _rootNode = cleanedRoot ?? LayoutNode(id: _generateId(), type: NodeType.leaf, tabs: []);
      }

      if (isRootDrop) {
        _splitRoot(tabToMove, action);
      } else {
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
    LayoutNode existingChild = LayoutNode(id: _generateId(), type: NodeType.leaf, tabs: [...target.tabs], selectedTabIndex: target.selectedTabIndex);
    LayoutNode newChild = LayoutNode(id: _generateId(), type: NodeType.leaf, tabs: [newTab], selectedTabIndex: 0);

    target.type = NodeType.split;
    target.tabs = [];
    target.ratios = null;

    if (action == 'left') { target.axis = Axis.horizontal; target.children = [newChild, existingChild]; }
    else if (action == 'right') { target.axis = Axis.horizontal; target.children = [existingChild, newChild]; }
    else if (action == 'top') { target.axis = Axis.vertical; target.children = [newChild, existingChild]; }
    else if (action == 'bottom') { target.axis = Axis.vertical; target.children = [existingChild, newChild]; }
  }

  void _splitRoot(TabData newTab, String action) {
    LayoutNode oldRootContent = _rootNode!;
    LayoutNode newChild = LayoutNode(id: _generateId(), type: NodeType.leaf, tabs: [newTab]);
    LayoutNode newRoot = LayoutNode(
      id: _generateId(),
      type: NodeType.split,
      axis: (action == 'left' || action == 'right') ? Axis.horizontal : Axis.vertical,
      children: (action == 'left' || action == 'top') ? [newChild, oldRootContent] : [oldRootContent, newChild],
    );
    _rootNode = newRoot;
  }

  @override
  Widget build(BuildContext context) {
    if (_rootNode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: APP_BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text('Docking Layout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              SharedPreferences.getInstance().then((p) => p.remove(KEY_SAVED_LAYOUT_DATA));
              _initDefaultSync();
              setState(() {});
            },
          ),
        ],
      ),
      body: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size parentSize = constraints.biggest;

            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildRecursive(_rootNode!)),

                  Consumer(
                    builder: (context, ref, _) {
                      final dragState = ref.watch(globalDragStateProvider);
                      if (!dragState.isDragging || !dragState.isGlobalButtonsVisible) {
                        return const SizedBox.shrink();
                      }
                      final notify = ref.read(globalDragStateProvider.notifier);

                      return Stack(
                        children: [
                          _GlobalSplitButton(
                            alignment: Alignment.topCenter, icon: Icons.keyboard_arrow_up, action: 'top', parentSize: parentSize,
                            onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'top', isRootDrop: true),
                            onHover: notify.markLeftTabHeader,
                          ),
                          _GlobalSplitButton(
                            alignment: Alignment.bottomCenter, icon: Icons.keyboard_arrow_down, action: 'bottom', parentSize: parentSize,
                            onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'bottom', isRootDrop: true),
                            onHover: notify.markLeftTabHeader,
                          ),
                          _GlobalSplitButton(
                            alignment: Alignment.centerLeft, icon: Icons.keyboard_arrow_left, action: 'left', parentSize: parentSize,
                            onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'left', isRootDrop: true),
                            onHover: notify.markLeftTabHeader,
                          ),
                          _GlobalSplitButton(
                            alignment: Alignment.centerRight, icon: Icons.keyboard_arrow_right, action: 'right', parentSize: parentSize,
                            onDrop: (src, tab) => _handleTabDrop(src, tab, '', 'right', isRootDrop: true),
                            onHover: notify.markLeftTabHeader,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecursive(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      return _DockingPane(
        key: ValueKey(node.id),
        node: node,
        onTabDrop: (src, tabId, action) => _handleTabDrop(src, tabId, node.id, action),
        onAddTab: () => setState(() {
          node.tabs.add(TabData(id: _generateId(), title: 'New Tab', categoryId: 's20002'));
          node.selectedTabIndex = node.tabs.length - 1;
        }),
        onSelectTab: (idx) => setState(() => node.selectedTabIndex = idx),
        onTabReorder: (tabId, targetIndex) => _handleTabReorder(node.id, tabId, targetIndex),
      );
    } else {
      List<Widget> childrenWidgets = node.children.map((c) => _buildRecursive(c)).toList();
      List<Area> areas = [];
      for (int i = 0; i < childrenWidgets.length; i++) {
        double flex = 1.0;
        if (node.ratios != null && i < node.ratios!.length) flex = node.ratios![i];
        areas.add(Area(data: childrenWidgets[i], flex: flex));
      }

      return MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 5,
          dividerPainter: DividerPainter(backgroundColor: Colors.red, highlightedBackgroundColor: Colors.blue),
        ),
        child: MultiSplitView(
          key: ValueKey(node.id),
          axis: node.axis!,
          controller: MultiSplitViewController(areas: areas),
          builder: (context, area) => area.data as Widget,
          onDividerDragUpdate: (index) { /* Ratio update logic */ },
        ),
      );
    }
  }
}

// =============================================================================
// 4. Pane & Tab
// =============================================================================

class _DockingPane extends ConsumerStatefulWidget {
  final LayoutNode node;
  final Function(String, String, String) onTabDrop;
  final VoidCallback onAddTab;
  final Function(int) onSelectTab;
  final Function(String, int) onTabReorder;

  const _DockingPane({
    super.key,
    required this.node,
    required this.onTabDrop,
    required this.onAddTab,
    required this.onSelectTab,
    required this.onTabReorder,
  });

  @override
  ConsumerState<_DockingPane> createState() => _DockingPaneState();
}

class _DockingPaneState extends ConsumerState<_DockingPane> {
  final GlobalKey _headerKey = GlobalKey();

  Rect? _getHeaderRect() {
    final RenderBox? box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      return offset & box.size;
    }
    return null;
  }

  void _updateHoverAction(Offset localPosition, Size size, DragPayload payload) {
    bool inHeader = localPosition.dy < TAB_HEADER_HEIGHT;
    bool isSelf = payload.sourceNodeId == widget.node.id;

    final globalDragNotifier = ref.read(globalDragStateProvider.notifier);
    final hasLeftTabHeader = ref.read(globalDragStateProvider).hasLeftTabHeader;

    String? newAction;

    if (inHeader) {
      if (isSelf) {
        if (hasLeftTabHeader) {
          // 한 번 나갔다 들어오면 분할 모드
          newAction = localPosition.dy < DOCKING_PANE_BORDER_THRESHOLD ? 'top' : 'center';
          globalDragNotifier.setGlobalVisibility(true);
        } else {
          // 순수 Reordering 모드 -> Global Button 숨김
          newAction = null;
          globalDragNotifier.setGlobalVisibility(false);
        }
      } else {
        // 타 패널 헤더 -> 분할 모드
        newAction = localPosition.dy < DOCKING_PANE_BORDER_THRESHOLD ? 'top' : 'center';
        globalDragNotifier.setGlobalVisibility(true);
        globalDragNotifier.markLeftTabHeader();
      }
    } else {
      // 컨텐츠 영역 -> Global Button 보임
      globalDragNotifier.markLeftTabHeader();
      globalDragNotifier.setGlobalVisibility(true);

      // --- Selector & Border Logic ---
      final double contentHeight = size.height - TAB_HEADER_HEIGHT;
      final Offset contentCenter = Offset(size.width / 2, TAB_HEADER_HEIGHT + (contentHeight / 2));
      final double distFromCenter = (localPosition - contentCenter).distance;
      const double selectorRadius = (BTN_DOCKING_SELECTOR_SIZE * 1.5) + BTN_DOCKING_SELECOTR_GAP;

      // 1. Selector 감지
      if (distFromCenter < selectorRadius) {
        double dx = localPosition.dx - contentCenter.dx;
        double dy = localPosition.dy - contentCenter.dy;
        const double centerZoneSize = BTN_DOCKING_SELECTOR_SIZE / 2 + BTN_DOCKING_SELECOTR_GAP;
        if (dx.abs() < centerZoneSize && dy.abs() < centerZoneSize) {
          newAction = 'center';
        } else {
          if (dx.abs() > dy.abs()) newAction = dx > 0 ? 'right' : 'left';
          else newAction = dy > 0 ? 'bottom' : 'top';
        }
      }
      // 2. 테두리 감지
      else {
        double distLeft = localPosition.dx;
        double distRight = size.width - localPosition.dx;
        double distTop = localPosition.dy;
        double distBottom = size.height - localPosition.dy;

        double minH = distLeft < distRight ? distLeft : distRight;
        double minV = distTop < distBottom ? distTop : distBottom;

        if (minH < DOCKING_PANE_BORDER_THRESHOLD && minH <= minV) {
          newAction = distLeft < distRight ? 'left' : 'right';
        } else if (minV < DOCKING_PANE_BORDER_THRESHOLD && minV <= minH) {
          newAction = distTop < distBottom ? 'top' : 'bottom';
        } else {
          newAction = 'center';
        }
      }
    }

    if (ref.read(hoverActionProvider(widget.node.id)) != newAction) {
      ref.read(hoverActionProvider(widget.node.id).notifier).state = newAction;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset localPos = box.globalToLocal(details.offset);
        _updateHoverAction(localPos, box.size, details.data);
      },

      // [수정 핵심] onLeave에서 setGlobalVisibility(false)를 제거했습니다.
      onLeave: (_) {
        // 해당 패널의 파란색 오버레이(Hover Action)는 지워야 함
        ref.read(hoverActionProvider(widget.node.id).notifier).state = null;

        // 중요: 여기서 setGlobalVisibility(false)를 호출하면
        // 마우스가 Global Button 위로 올라갔을 때(Pane을 떠났을 때)
        // 버튼이 사라져버려서 깜빡임 현상이 발생함.
        // 따라서 제거함. Global Button 숨김 처리는 endDrag() 등에서 담당.
      },

      onAcceptWithDetails: (details) {
        final action = ref.read(hoverActionProvider(widget.node.id));
        if (action != null) {
          widget.onTabDrop(details.data.sourceNodeId, details.data.tabId, action);
        }
        ref.read(hoverActionProvider(widget.node.id).notifier).state = null;
        ref.read(globalDragStateProvider.notifier).endDrag();
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Stack(
          children: [
            Column(
              children: [
                // 1. 헤더
                Container(
                  key: _headerKey,
                  height: TAB_HEADER_HEIGHT,
                  color: Colors.grey[200],
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.node.tabs.length,
                          itemBuilder: (context, index) {
                            final tab = widget.node.tabs[index];
                            return _DraggableTab(
                              key: ValueKey(tab.id),
                              nodeId: widget.node.id,
                              tab: tab,
                              index: index,
                              isSelected: index == widget.node.selectedTabIndex,
                              onTap: () => widget.onSelectTab(index),
                              onReorder: widget.onTabReorder,
                              getHeaderRect: _getHeaderRect,
                            );
                          },
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.add, size: 18), onPressed: widget.onAddTab),
                    ],
                  ),
                ),
                // 2. 컨텐츠
                Expanded(
                  child: Container(
                    color: Colors.white, alignment: Alignment.center,
                    child: widget.node.tabs.isEmpty
                        ? const Text("Empty")
                        : Text(widget.node.tabs[widget.node.selectedTabIndex].categoryId),
                  ),
                ),
              ],
            ),

            // 3. 오버레이
            if (isHovering)
              Consumer(
                builder: (context, ref, _) {
                  final hoverAction = ref.watch(hoverActionProvider(widget.node.id));
                  if (hoverAction == null) return const SizedBox.shrink();

                  return Stack(
                    children: [
                      Positioned.fill(child: IgnorePointer(child: _buildDropOverlay(hoverAction))),
                      Positioned.fill(
                        top: TAB_HEADER_HEIGHT,
                        child: Center(child: IgnorePointer(child: _DockingSelectorVisual(highlightedAction: hoverAction))),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildDropOverlay(String action) {
    // ... 스타일 코드 동일 ...
    const double thickWidth = 8.0;
    const double thinWidth = 2.0;

    if (action == 'center') {
      return Container(
        decoration: BoxDecoration(
          color: GENIE_ACCENT_COLOR_OP10,
          border: Border.all(color: GENIE_ACCENT_COLOR, width: thinWidth),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: GENIE_ACCENT_COLOR_OP05,
        border: Border(
          top: BorderSide(color: GENIE_ACCENT_COLOR, width: action == 'top' ? thickWidth : thinWidth),
          bottom: BorderSide(color: GENIE_ACCENT_COLOR, width: action == 'bottom' ? thickWidth : thinWidth),
          left: BorderSide(color: GENIE_ACCENT_COLOR, width: action == 'left' ? thickWidth : thinWidth),
          right: BorderSide(color: GENIE_ACCENT_COLOR, width: action == 'right' ? thickWidth : thinWidth),
        ),
      ),
    );
  }
}

class _DraggableTab extends ConsumerStatefulWidget {
  final String nodeId;
  final TabData tab;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String, int) onReorder;
  final Rect? Function() getHeaderRect;

  const _DraggableTab({
    super.key,
    required this.nodeId,
    required this.tab,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onReorder,
    required this.getHeaderRect,
  });

  @override
  ConsumerState<_DraggableTab> createState() => _DraggableTabState();
}

class _DraggableTabState extends ConsumerState<_DraggableTab> {
  final ValueNotifier<Offset> _localPointerPos = ValueNotifier(Offset.zero);

  // 현재 드래그가 탭의 왼쪽('left')인지 오른쪽('right')인지 저장
  String? _hoverSide;

  @override
  void dispose() {
    _localPointerPos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) {
        final hasLeft = ref.read(globalDragStateProvider).hasLeftTabHeader;
        if (hasLeft) return false;
        // 자기 자신 위로는 드롭 불가
        return details.data.sourceNodeId == widget.nodeId && details.data.tabId != widget.tab.id;
      },
      // 드래그 위치에 따라 왼쪽/오른쪽 판별
      onMove: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset localPos = box.globalToLocal(details.offset);
        final double width = box.size.width;

        // 가로 중심 기준으로 왼쪽/오른쪽 결정
        final String newSide = localPos.dx < (width / 2) ? 'left' : 'right';

        if (_hoverSide != newSide) {
          setState(() {
            _hoverSide = newSide;
          });
        }
      },
      onLeave: (_) {
        setState(() => _hoverSide = null);
      },
      onAcceptWithDetails: (details) {
        // 오른쪽에 드롭했다면 인덱스를 +1 하여 뒤로 이동
        int targetIndex = widget.index;
        if (_hoverSide == 'right') {
          targetIndex += 1;
        }

        widget.onReorder(details.data.tabId, targetIndex);
        setState(() => _hoverSide = null);
      },
      builder: (context, candidateData, rejectedData) {
        // 드래그 대상이 들어왔을 때만 하이라이트 표시
        final bool showHighlight = candidateData.isNotEmpty && _hoverSide != null;

        return Draggable<DragPayload>(
          data: DragPayload(widget.nodeId, widget.tab.id),
          onDragStarted: () => ref.read(globalDragStateProvider.notifier).startDrag(),
          onDraggableCanceled: (_, __) => ref.read(globalDragStateProvider.notifier).endDrag(),
          onDragEnd: (_) => ref.read(globalDragStateProvider.notifier).endDrag(),

          onDragUpdate: (details) {
            _localPointerPos.value = details.globalPosition;
          },
          dragAnchorStrategy: pointerDragAnchorStrategy,

          feedback: ValueListenableBuilder<Offset>(
            valueListenable: _localPointerPos,
            builder: (context, currentPos, child) {
              double offsetY = 0;
              if (currentPos != Offset.zero) {
                final hasLeft = ref.read(globalDragStateProvider).hasLeftTabHeader;
                if (!hasLeft) {
                  final Rect? headerRect = widget.getHeaderRect();
                  if (headerRect != null &&
                      currentPos.dy >= headerRect.top &&
                      currentPos.dy <= headerRect.bottom) {
                    offsetY = headerRect.center.dy - currentPos.dy;
                  }
                }
              }
              return Transform.translate(
                offset: Offset(0, offsetY),
                child: child,
              );
            },
            child: Transform.translate(
              offset: const Offset(-50, -18),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 100, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GENIE_ACCENT_COLOR_OP30,
                    border: Border.all(color: GENIE_ACCENT_COLOR),
                  ),
                  child: Text(widget.tab.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: _buildTabDesign(widget.isSelected, false)),
          // 하이라이트 처리를 위해 파라미터 전달
          child: GestureDetector(
            onTap: widget.onTap,
            child: _buildTabDesign(widget.isSelected, showHighlight),
          ),
        );
      },
    );
  }

  Widget _buildTabDesign(bool isSelected, bool showHighlight) {
    // 하이라이트 보더 설정
    BorderSide? leftBorder;
    BorderSide? rightBorder;

    if (showHighlight) {
      const side = BorderSide(color: GENIE_ACCENT_COLOR, width: 3.0); // 두꺼운 파란선
      if (_hoverSide == 'left') leftBorder = side;
      if (_hoverSide == 'right') rightBorder = side;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        // 조건부 보더 적용
        border: Border(
          left: leftBorder ?? BorderSide.none,
          right: rightBorder ?? BorderSide.none,
        ),
      ),
      child: Text(
        widget.tab.title,
        style: TextStyle(
          color: isSelected ? GENIE_ACCENT_COLOR : Colors.black,
          fontSize: TAB_TITLE_FONT_SIZE,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _GlobalSplitButton extends StatelessWidget {
  // 전체영역 분할 버튼 위치 지정
  final Alignment alignment;
  final IconData icon;
  final String action; // 상하좌우 구분
  final Size parentSize; // 부모 영역 크기 (테두리 하이라이트 위치 계산용)
  final Function(String srcNodeId, String tabId) onDrop;
  final VoidCallback onHover; // 호버 시 상태 업데이트용

  const _GlobalSplitButton({
    super.key,
    required this.alignment,
    required this.icon,
    required this.action,
    required this.parentSize,
    required this.onDrop,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: BTN_GLOBAL_SPLIT_SIZE,
        height: BTN_GLOBAL_SPLIT_SIZE,
        child: DragTarget<DragPayload>(
          // onWillAcceptWithDetails: (_) {
          //   // onHover(); // 글로벌 버튼에 진입하면 무조건 헤더 이탈로 간주
          //   return true;
          // },
          onAcceptWithDetails: (details) {
            onDrop(details.data.sourceNodeId, details.data.tabId);
          },
          builder: (context, candidateData, rejectedData) {
            bool isHovering = candidateData.isNotEmpty;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. 하이라이트 (호버 시에만 표시)
                if (isHovering)
                  _buildHighlight(action, BTN_GLOBAL_SPLIT_HIGHLIGHT_THICKNESS),

                // 2. 원형 버튼
                Container(
                  width: BTN_GLOBAL_SPLIT_SIZE,
                  height: BTN_GLOBAL_SPLIT_SIZE,
                  decoration: BoxDecoration(
                    color: isHovering
                        ? ACCENT_PURPLE
                        : Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(
                      color: isHovering
                          ? ACCENT_PURPLE_ACTIVE
                          : Colors.grey.shade300,
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
    // 버튼의 중심에서 부모 컨테이너의 중심으로 좌표 변환 계산
    // 버튼은 Align으로 배치되어 있으므로, Stack의 center(0,0) 기준이 아니라 버튼 자체의 center가 기준이 됨
    // 따라서 부모 크기의 절반만큼 이동시켜야 화면 끝에 붙음

    double sizeBtnHalf = BTN_GLOBAL_SPLIT_SIZE / 2;
    double translateHor = -(parentSize.width / 2) + sizeBtnHalf;
    double translateVer = -(parentSize.height / 2) + sizeBtnHalf;

    // 액션에 따라 화면 가장자리에 파란색 하이라이트 바 표시
    if (action == 'top') {
      return Positioned(
        top: 0, // 버튼 기준 위쪽
        // 가로로는 화면 전체 너비
        // 버튼이 TopCenter에 있다면 left 이동 필요
        left: translateHor,
        width: parentSize.width,
        height: thickness,
        child: Container(color: ACCENT_PURPLE),
      );
    } else if (action == 'bottom') {
      return Positioned(
        bottom: 0,
        left: translateHor,
        width: parentSize.width,
        height: thickness,
        child: Container(color: ACCENT_PURPLE),
      );
    } else if (action == 'left') {
      return Positioned(
        left: 0,
        top: translateVer,
        width: thickness,
        height: parentSize.height,
        child: Container(color: ACCENT_PURPLE),
      );
    } else { // right
      return Positioned(
        right: 0,
        top: translateVer,
        width: thickness,
        height: parentSize.height,
        child: Container(color: ACCENT_PURPLE),
      );
    }
  }
}

class _DockingSelectorVisual extends StatelessWidget {
  final String? highlightedAction;
  const _DockingSelectorVisual({this.highlightedAction});

  @override
  Widget build(BuildContext context) {
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
          _buildIcon('top', Icons.arrow_drop_up),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon('left', Icons.arrow_left),
              const SizedBox(width: 4),
              _buildIcon('center', Icons.stop_rounded, isCenter: true),
              const SizedBox(width: 4),
              _buildIcon('right', Icons.arrow_right),
            ],
          ),
          const SizedBox(height: 4),
          _buildIcon('bottom', Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Widget _buildIcon(String action, IconData icon, {bool isCenter = false}) {
    bool isHighlighted = highlightedAction == action;
    return Container(
      width: BTN_DOCKING_SELECTOR_SIZE, height: BTN_DOCKING_SELECTOR_SIZE,
      decoration: BoxDecoration(
        color: isHighlighted ? ACCENT_PURPLE : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isHighlighted ? ACCENT_PURPLE_ACTIVE : Colors.grey.shade400),
      ),
      child: Icon(icon, color: isHighlighted ? Colors.white : Colors.grey[600], size: isCenter ? 24 : 32),
    );
  }
}