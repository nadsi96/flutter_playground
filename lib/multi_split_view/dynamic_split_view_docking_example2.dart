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
const ACCENT_PURPLE = Color(0xFF50CDEC);
const ACCENT_PURPLE_ACTIVE = Color(0xFF329FC4);

const double BTN_GLOBAL_SPLIT_SIZE = 40;
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
          // 자기 자신 헤더지만, 이미 나갔다 왔다면 분할 모드 (임계값 내면 top, 아니면 center)
          newAction = localPosition.dy < DOCKING_PANE_BORDER_THRESHOLD ? 'top' : 'center';
          globalDragNotifier.setGlobalVisibility(true);
        } else {
          // 순수 Reordering 모드
          newAction = null;
          globalDragNotifier.setGlobalVisibility(false);
        }
      } else {
        // 남의 헤더: 기본 top/center
        newAction = localPosition.dy < DOCKING_PANE_BORDER_THRESHOLD ? 'top' : 'center';
        globalDragNotifier.setGlobalVisibility(true);
        globalDragNotifier.markLeftTabHeader();
      }
    } else {
      // 컨텐츠 영역 진입: 무조건 헤더 이탈로 간주
      globalDragNotifier.markLeftTabHeader();
      globalDragNotifier.setGlobalVisibility(true);

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
      // 2. [추가] 테두리 감지 (영역 내 분할)
      else {
        double distLeft = localPosition.dx;
        double distRight = size.width - localPosition.dx;
        // top 계산 시 헤더 높이를 고려할지, 전체 높이 기준일지는 디자인에 따라 다르나 보통 전체 기준 혹은 컨텐츠 기준
        // 여기서는 전체 Pane 기준 테두리 감지
        double distTop = localPosition.dy;
        double distBottom = size.height - localPosition.dy;

        double minH = distLeft < distRight ? distLeft : distRight;
        double minV = distTop < distBottom ? distTop : distBottom;

        if (minH < DOCKING_PANE_BORDER_THRESHOLD && minH <= minV) {
          newAction = distLeft < distRight ? 'left' : 'right';
        } else if (minV < DOCKING_PANE_BORDER_THRESHOLD && minV <= minH) {
          newAction = distTop < distBottom ? 'top' : 'bottom';
        } else {
          // 테두리도 아니고 Selector도 아니면 기본 센터
          newAction = 'center';
        }
      }
    }

    // 상태 업데이트
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
      onLeave: (_) {
        ref.read(hoverActionProvider(widget.node.id).notifier).state = null;
        ref.read(globalDragStateProvider.notifier).setGlobalVisibility(false);
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
        return details.data.sourceNodeId == widget.nodeId && details.data.tabId != widget.tab.id;
      },
      onAcceptWithDetails: (details) {
        widget.onReorder(details.data.tabId, widget.index);
      },
      builder: (context, _, __) {
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

              // [수정] 헤더 이탈 상태 확인 (여기서는 ProviderScope 안이므로 ref 사용 가능하지 않음 - Draggable feedback은 Overlay)
              // feedback은 독립된 트리로 생성되므로 ref.read를 직접 쓸 수 없음 (No ProviderScope found).
              // 하지만 _DraggableTabState는 ProviderScope 안에 있음.
              // feedback builder 내부가 실행될 때 _DraggableTabState의 ref를 참조하는 것은 클로저 캡처링으로 가능함.

              if (currentPos != Offset.zero) {
                // 클로저를 통해 ref 접근
                final hasLeft = ref.read(globalDragStateProvider).hasLeftTabHeader;

                // [조건] 아직 헤더를 벗어난 적이 없을 때만 Y축 고정
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
                    color: Colors.white.withOpacity(0.9),
                    border: Border.all(color: GENIE_ACCENT_COLOR),
                  ),
                  child: Text(widget.tab.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
            ),
          ),

          childWhenDragging: Opacity(opacity: 0.3, child: _buildTabDesign(widget.isSelected, true)),
          child: GestureDetector(
            onTap: widget.onTap,
            child: _buildTabDesign(widget.isSelected, false),
          ),
        );
      },
    );
  }

  Widget _buildTabDesign(bool isSelected, bool isHovering) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
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
  final Alignment alignment; final IconData icon; final String action;
  final Size parentSize; final Function(String, String) onDrop; final VoidCallback onHover;

  const _GlobalSplitButton({
    required this.alignment, required this.icon, required this.action,
    required this.parentSize, required this.onDrop, required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: DragTarget<DragPayload>(
        onWillAcceptWithDetails: (_) { onHover(); return true; },
        onAcceptWithDetails: (d) => onDrop(d.data.sourceNodeId, d.data.tabId),
        builder: (context, candidateData, _) {
          bool isHovering = candidateData.isNotEmpty;
          return Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isHovering ? ACCENT_PURPLE : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey),
            ),
            child: Icon(icon, color: isHovering ? Colors.white : Colors.black),
          );
        },
      ),
    );
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