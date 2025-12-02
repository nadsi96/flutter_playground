import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/**
 * 영역 처리 수정 == webull
 * 아직은 이전 코드 복붙
 */

const APP_BACKGROUND_COLOR = Color(0xFFF0F2F5);
const GENIE_ACCENT_COLOR = Color(0xFF52C2DF);
const GENIE_ACCENT_COLOR_OP05 = Color.fromRGBO(82, 194, 223, 0.05);
const GENIE_ACCENT_COLOR_OP10 = Color.fromRGBO(82, 194, 223, 0.1);
const GENIE_ACCENT_COLOR_OP30 = Color.fromRGBO(82, 194, 223, 0.3);
const ACCENT_PURPLE = Color(0xFF50CDEC);
const ACCENT_PURPLE_SUB = Color(0xFF3BB8E0);
const ACCENT_PURPLE_HOVER = Color(0xFF5AC3E8);
const ACCENT_PURPLE_ACTIVE = Color(0xFF329FC4);

// 전체영역 분할 버튼 크기
const double BTN_GLOBAL_SPLIT_SIZE = 40;
// 전체영역 분할 테두리 하이라이트 두께
const double BTN_GLOBAL_SPLIT_HIGHLIGHT_THICKNESS = 6;

// tab
// text 크기
const double TAB_TITLE_FONT_SIZE = 10;

// 영역 분할 버튼
const double BTN_DOCKING_SELECTOR_SIZE = 40;
const double BTN_DOCKING_SELECOTR_GAP = 4;

// =============================================================================
// 1. Data Models (데이터 모델)
// =============================================================================

/// 노드 타입: 분할된 화면(split)인지, 실제 탭이 있는 말단 화면(leaf)인지 구분
enum NodeType { split, leaf }

/// 개별 탭 데이터
class TabData {
  String id; // 탭 구분용 id
  String title; // 탭 헤더에 표기될 타이틀
  String categoryId; // 탭 컨텐츠에 작성될 메뉴id

  TabData({required this.id, required this.title, required this.categoryId});

  // JSON 직렬화/역직렬화
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'categoryId': categoryId};

  factory TabData.fromJson(Map<String, dynamic> json) =>
      TabData(id: json['id'], title: json['title'], categoryId: json['categoryId']);
}

/// 레이아웃 트리 노드 (재귀적 구조)
class LayoutNode {
  String id;
  NodeType type;
  Axis? axis; // 분할 방향 (가로/세로)
  List<LayoutNode> children; // 자식 노드들 (split 타입일 경우)
  List<double>? ratios; // 자식 노드 간의 비율
  List<TabData> tabs; // 포함된 탭들 (leaf 타입일 경우)
  int selectedTabIndex; // 현재 선택된 탭 인덱스

  LayoutNode({
    required this.id,
    required this.type,
    this.axis,
    List<LayoutNode>? children,
    this.ratios,
    List<TabData>? tabs,
    this.selectedTabIndex = 0,
  }) : children = children ?? [],
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
    NodeType type = json['type'] == 'NodeType.split'
        ? NodeType.split
        : NodeType.leaf;
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
      node.tabs = (json['tabs'] as List)
          .map((t) => TabData.fromJson(t))
          .toList();
    }
    return node;
  }
}

/// 드래그 앤 드롭 시 전달되는 데이터
class DragPayload {
  final String sourceNodeId; // 드래그 시작된 패널 ID
  final String tabId; // 드래그된 탭 ID
  DragPayload(this.sourceNodeId, this.tabId);
}

// =============================================================================
// 2. Main Screen & Logic (메인 화면 및 비즈니스 로직)
// =============================================================================

class DockingLayoutExample extends StatefulWidget {
  const DockingLayoutExample({super.key});

  @override
  State<DockingLayoutExample> createState() => _DockingLayoutExampleState();
}

class _DockingLayoutExampleState extends State<DockingLayoutExample> {
  LayoutNode? _rootNode; // 트리의 최상위 노드
  int _idCounter = 0;
  bool _isDragging = false; // 현재 드래그 중인지 여부 (전역 버튼 표시용)

  @override
  void initState() {
    super.initState();
    _loadLayout(); // 저장된 레이아웃 불러오기
  }

  String _generateId() {
    _idCounter++;
    return 'node_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  // --- 드래그 상태 관리 ---
  void _onDragStarted() {
    if (!_isDragging) setState(() => _isDragging = true);
  }

  void _onDragEnded() {
    // 이미 로직에 의해 false가 된 경우 중복 호출 방지
    if (_isDragging) setState(() => _isDragging = false);
  }

  // --- 데이터 저장 및 불러오기 (SharedPreferences) ---
  Future<void> _saveLayout() async {
    if (_rootNode == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_layout_v13', jsonEncode(_rootNode!.toJson()));
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString('saved_layout_v13');
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
          TabData(id: 't1', title: 'Watchlist', categoryId: 's20000'),
          TabData(id: 't2', title: 'Chart', categoryId: 's20001'),
        ],
      );
    });
  }

  // --- 트리 탐색 및 정리 헬퍼 ---

  /// ID로 노드 찾기 (재귀 탐색)
  LayoutNode? _findNodeById(LayoutNode? current, String id) {
    if (current == null) return null;
    if (current.id == id) return current;
    for (var child in current.children) {
      var found = _findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  /// 빈 노드 제거 및 트리 구조 정리 (재귀)
  LayoutNode? _cleanTree(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      // 탭이 없는 잎 노드는 삭제 대상
      return node.tabs.isEmpty ? null : node;
    } else {
      // 자식 노드 재귀 정리
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

      // 비율 배열 길이 동기화
      if (node.children.length == 1) {
        return node.children.first;
      }

      if (node.ratios != null && node.ratios!.length != node.children.length) {
        node.ratios = null;
      }
      return node;
    }
  }

  // --- 탭 동작 핸들러 ---

  /// 같은 패널 내에서 탭 순서 변경
  void _handleTabReorder(String nodeId, String tabId, int targetIndex) {
    // 1. 드래그 상태 강제 해제 (글로벌 버튼 숨김)
    setState(() => _isDragging = false); // 드래그 종료 처리

    LayoutNode? node = _findNodeById(_rootNode, nodeId);
    if (node == null) return;

    int oldIndex = node.tabs.indexWhere((t) => t.id == tabId);
    if (oldIndex == -1) return;

    setState(() {
      // 2. 탭 이동 로직
      // 기존 항목 삭제
      TabData tab = node.tabs.removeAt(oldIndex);
      // 새로운 위치에 삽입
      node.tabs.insert(targetIndex, tab);
      // 선택 index 갱신
      node.selectedTabIndex = targetIndex;

      // 변경값 저장
      _saveLayout();
    });
  }

  /// 탭을 다른 패널로 이동하거나 화면 분할 처리
  void _handleTabDrop(
      String srcNodeId,
      String tabId,
      String targetNodeId,
      String action, {
        bool isRootDrop = false,
      }) {
    // 1. 드래그 상태 강제 해제
    setState(() => _isDragging = false);

    LayoutNode? srcNode = _findNodeById(_rootNode, srcNodeId);
    if (srcNode == null) return;

    // 자기 자신에게 센터 드롭이나 탭이 1개일 때의 불필요한 동작 방지
    if (!isRootDrop && srcNodeId == targetNodeId) {
      if (action == 'center') return;
      if (srcNode.tabs.length <= 1) return;
    }

    int tabIndex = srcNode.tabs.indexWhere((t) => t.id == tabId);
    if (tabIndex == -1) return;
    TabData tabToMove = srcNode.tabs[tabIndex];

    setState(() {
      // 1. 기존 노드에서 탭 제거
      srcNode.tabs.removeAt(tabIndex);
      if (srcNode.selectedTabIndex >= srcNode.tabs.length) {
        srcNode.selectedTabIndex = srcNode.tabs.isEmpty
            ? 0
            : srcNode.tabs.length - 1;
      }

      // 2. 트리 정리 (탭이 없어진 빈 노드 제거 등)
      if (isRootDrop || srcNodeId != targetNodeId) {
        LayoutNode? cleanedRoot = _cleanTree(_rootNode!);
        _rootNode = cleanedRoot ?? LayoutNode(
          id: _generateId(),
          type: NodeType.leaf,
          tabs: [],
        );
      }

      // 3. 새로운 위치에 탭 추가 또는 분할
      if (isRootDrop) {
        _splitRoot(tabToMove, action); // 화면 전체 분할
      } else {
        LayoutNode? targetNode = _findNodeById(_rootNode, targetNodeId);
        if (targetNode != null) {
          if (action == 'center') {
            // 기존 패널에 탭 추가
            targetNode.tabs.add(tabToMove);
            targetNode.selectedTabIndex = targetNode.tabs.length - 1;
          } else {
            // 패널 분할 (상하좌우)
            _splitNode(targetNode, tabToMove, action);
          }
        }
      }
      _saveLayout();
    });
  }

  /// 특정 노드를 분할하여 새 탭 배치
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
      selectedTabIndex: 0,
    );

    // 타겟 노드를 Split 타입으로 변경하고 자식으로 기존 내용과 새 내용을 배치
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

  /// 화면 전체(루트)를 분할
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

  @override
  Widget build(BuildContext context) {
    if (_rootNode == null) return const Scaffold();

    return Scaffold(
      backgroundColor: APP_BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text('Docking Layout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              SharedPreferences.getInstance().then(
                    (p) => p.remove('saved_layout_v14'),
              );
              _initDefault();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final Size parentSize = constraints.biggest;

          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(child: _buildRecursive(_rootNode!)),
                if (_isDragging) ...[
                  _GlobalSplitButton(
                    alignment: Alignment.topCenter,
                    icon: Icons.keyboard_arrow_up,
                    action: 'top',
                    parentSize: parentSize,
                    onDrop: (src, tab) =>
                        _handleTabDrop(src, tab, '', 'top', isRootDrop: true),
                  ),
                  _GlobalSplitButton(
                    alignment: Alignment.bottomCenter,
                    icon: Icons.keyboard_arrow_down,
                    action: 'bottom',
                    parentSize: parentSize,
                    onDrop: (src, tab) =>
                        _handleTabDrop(src, tab, '', 'bottom', isRootDrop: true),
                  ),
                  _GlobalSplitButton(
                    alignment: Alignment.centerLeft,
                    icon: Icons.keyboard_arrow_left,
                    action: 'left',
                    parentSize: parentSize,
                    onDrop: (src, tab) =>
                        _handleTabDrop(src, tab, '', 'left', isRootDrop: true),
                  ),
                  _GlobalSplitButton(
                    alignment: Alignment.centerRight,
                    icon: Icons.keyboard_arrow_right,
                    action: 'right',
                    parentSize: parentSize,
                    onDrop: (src, tab) =>
                        _handleTabDrop(src, tab, '', 'right', isRootDrop: true),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// 트리를 순회하며 위젯 빌드
  Widget _buildRecursive(LayoutNode node) {
    if (node.type == NodeType.leaf) {
      // 말단 노드: 실제 탭 화면 표시
      return _DockingPane(
        node: node,
        onTabDrop: (src, tabId, action) =>
            _handleTabDrop(src, tabId, node.id, action),
        onAddTab: () => setState(() {
          node.tabs.add(TabData(id: _generateId(), title: 'New Tab', categoryId: 's20002'));
          node.selectedTabIndex = node.tabs.length - 1;
        }),
        onSelectTab: (idx) => setState(() => node.selectedTabIndex = idx),
        onDragStarted: _onDragStarted,
        onDragEnded: _onDragEnded,
        onTabReorder: (tabId, targetIndex) =>
            _handleTabReorder(node.id, tabId, targetIndex),
      );
    } else {
      // 분할 노드: MultiSplitView를 사용하여 화면 분할
      List<Widget> childrenWidgets = node.children
          .map((c) => _buildRecursive(c))
          .toList();

      List<Area> areas = [];
      for (int i = 0; i < childrenWidgets.length; i++) {
        double flex = 1.0;
        if (node.ratios != null && i < node.ratios!.length) {
          flex = node.ratios![i];
        }
        areas.add(Area(data: childrenWidgets[i], flex: flex));
      }

      MultiSplitViewController controller = MultiSplitViewController(
        areas: areas,
      );

      return MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            dividerThickness: 5,
            dividerPainter: DividerPainter(backgroundColor: Colors.red,
              highlightedBackgroundColor: Colors.blue,),
          ),
          child: MultiSplitView(
            key: ValueKey(node.id),
            axis: node.axis!,
            controller: controller,
            builder: (context, area) => area.data as Widget,
            onDividerDragUpdate: (index) {
              // 사용자가 분할 크기를 조절하면 비율 저장
              double totalFlex = controller.areas.fold(
                0.0,
                    (sum, area) => sum + (area.flex ?? 0.0),
              );
              if (totalFlex > 0) {
                node.ratios = controller.areas
                    .map((a) => (a.flex ?? 0.0) / totalFlex)
                    .toList();
                _saveLayout();
              }
            },
          )
      );
    }
  }
}

// =============================================================================
// 3. Global Split Button (화면 가장자리 분할 영역)
// =============================================================================

class _GlobalSplitButton extends StatelessWidget {
  // 전체영역 분할 버튼 위치 지정
  // top: topCenter
  // right: centerRight,
  // bottom: bottomCenter,
  // left: centerLeft
  final Alignment alignment;
  final IconData icon;
  final String action; // 상하좌우 구분
  final Size parentSize; // 부모 영역 크기 // 테두리 하이라이트 시 사이즈 처리
  final Function(String srcNodeId, String tabId) onDrop;

  const _GlobalSplitButton({
    required this.alignment,
    required this.icon,
    required this.action,
    required this.parentSize,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: BTN_GLOBAL_SPLIT_SIZE,
        height: BTN_GLOBAL_SPLIT_SIZE,
        child: DragTarget<DragPayload>(
          onWillAccept: (_) => true,
          onAccept: (data) => onDrop(data.sourceNodeId, data.tabId),
          builder: (context, candidateData, rejectedData) {
            bool isHovering = candidateData.isNotEmpty;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (isHovering) _buildHighlight(action, BTN_GLOBAL_SPLIT_HIGHLIGHT_THICKNESS),
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

    // 상/하 버튼 - 가로축 중앙 정렬
    // 좌/우 버튼 - 세로축 중앙 정렬
    // 상/하 버튼인 경우, 왼쪽 끝에서부터 부모영역 너비만큼 너비를 지정하여 테두리 작성
    // 버튼의 offset 0, 0부터 처리하기 때문에 버튼 크기만큼 오차 발생
    // 버튼 크기만큼 조정
    double sizeBtnHalf = BTN_GLOBAL_SPLIT_SIZE / 2;
    double translateHor = -(parentSize.width / 2) + sizeBtnHalf;
    double translateVer = -(parentSize.height / 2) + sizeBtnHalf;

    // 액션에 따라 화면 가장자리에 파란색 하이라이트 표시
    if (action == 'top') {
      return Positioned(
        top: 0,
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
    } else {
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

// =============================================================================
// 4. Pane & Tab (개별 패널 및 탭 위젯)
// =============================================================================

class _DockingPane extends StatefulWidget {
  final LayoutNode node;
  final Function(String srcNode, String srcTab, String action) onTabDrop;
  final VoidCallback onAddTab;
  final Function(int) onSelectTab;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final Function(String tabId, int targetIndex) onTabReorder;

  const _DockingPane({
    required this.node,
    required this.onTabDrop,
    required this.onAddTab,
    required this.onSelectTab,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onTabReorder,
  });

  @override
  State<_DockingPane> createState() => _DockingPaneState();
}

class _DockingPaneState extends State<_DockingPane> {
  String? _hoverAction;
  final GlobalKey _contentKey = GlobalKey();

  /// 드래그 위치에 따라 분할 액션(상하좌우, 센터) 판별
  /// 1. 중앙 Selector 근처에서는 아이콘 위치에 따라 동작
  /// 2. 그 외 영역에서는 가장자리(Edge) 감지 및 센터(Center) 동작
  void _updateHoverAction(Offset localPosition, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    // --- 1. 중앙 아이콘(Selector) 영역 우선 감지 ---
    // Selector의 반지름 이내에 마우스가 있다면
    // (버튼 1개(상/하/좌/우) 크기 + 버튼 크기/2 (중앙버튼)) + (버튼 gap 및 padding)
    // 중앙 selector 동작 우선
    const double selectorRadius = (BTN_DOCKING_SELECTOR_SIZE + BTN_DOCKING_SELECTOR_SIZE/2) + BTN_DOCKING_SELECOTR_GAP;
    final double distFromCenter = (localPosition - center).distance;

    if (distFromCenter < selectorRadius) {
      double dx = localPosition.dx - center.dx;
      double dy = localPosition.dy - center.dy;
      const double centerZoneSize = BTN_DOCKING_SELECTOR_SIZE/2 + BTN_DOCKING_SELECOTR_GAP; // 중앙 '합치기' 네모 크기

      if (dx.abs() < centerZoneSize && dy.abs() < centerZoneSize) {
        // 정중앙
        if (_hoverAction != 'center') setState(() => _hoverAction = 'center');
      } else {
        // Selector 내의 상하좌우 아이콘 판별
        //   ______
        //  (\    /)
        // (  \  /  )
        // (  /  \  )
        //  (/    \)
        //   ------
        String newAction;
        if (dx.abs() > dy.abs()) {
          newAction = dx > 0 ? 'right' : 'left';
        } else {
          newAction = dy > 0 ? 'bottom' : 'top';
        }
        if (_hoverAction != newAction) setState(() => _hoverAction = newAction);
      }
      return; // 중앙 로직 처리 완료 시 리턴
    }

    // --- 2. 바깥 영역 (border 근처 감지) 로직 ---
    // Selector 범위 밖에서 수행

    // 테두리 근처 감지 임계값 10px
    double thresholdX = 15;
    double thresholdY = 15;

    double distLeft = localPosition.dx;
    double distRight = size.width - localPosition.dx;
    double distTop = localPosition.dy;
    double distBottom = size.height - localPosition.dy;

    double minH = distLeft < distRight ? distLeft : distRight;
    double minV = distTop < distBottom ? distTop : distBottom;

    String newAction = 'center'; // 기본값은 합치기

    // Border 근처인지 확인
    if (minH < thresholdX && minH <= minV) {
      newAction = distLeft < distRight ? 'left' : 'right';
    } else if (minV < thresholdY && minV <= minH) {
      newAction = distTop < distBottom ? 'top' : 'bottom';
    }

    if (_hoverAction != newAction) {
      setState(() => _hoverAction = newAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // -------------------------------------------------------
        // 1. 탭 헤더
        // -------------------------------------------------------
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
                      index: index,
                      isSelected: selected,
                      onTap: () => widget.onSelectTab(index),
                      onDragStarted: widget.onDragStarted,
                      onDragEnded: widget.onDragEnded,
                      onReorder: (tabId) => widget.onTabReorder(tabId, index),
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
        // -------------------------------------------------------
        // 2. 컨텐츠 영역 (분할/합치기 DragTarget 적용)
        // -------------------------------------------------------
        Expanded(
          child: DragTarget<DragPayload>(
            key: _contentKey,
            onWillAccept: (data) => data != null,
            onMove: (details) {
              final RenderBox renderBox =
              _contentKey.currentContext?.findRenderObject() as RenderBox;
              final Size size = renderBox.size;

              // pointerDragAnchorStrategy
              // details.offset이 마우스 커서 좌표
              final Offset localPos = renderBox.globalToLocal(details.offset);
              _updateHoverAction(localPos, size);
            },
            onLeave: (_) => setState(() => _hoverAction = null),
            onAccept: (data) {
              // 드래그된 데이터(위젯)이 DragTarget 위젯 위에 놓였을때 호출
              if (_hoverAction != null) {
                widget.onTabDrop(data.sourceNodeId, data.tabId, _hoverAction!);
              }
              setState(() => _hoverAction = null);
            },
            builder: (context, candidateData, rejectedData) {
              bool isHovering = candidateData.isNotEmpty;

              return Stack(
                children: [
                  // (1) 실제 컨텐츠
                  Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: widget.node.tabs.isEmpty
                        ? const Text("Empty")
                        : _buildContent(widget.node.tabs[widget.node.selectedTabIndex].categoryId),
                  ),

                  // (2) 하이라이트 오버레이 (배경 및 테두리)
                  if (isHovering && _hoverAction != null)
                    Positioned.fill(
                      child: _buildDropOverlay(_hoverAction!),
                    ),

                  // (3) 중앙 셀렉터 아이콘
                  if (isHovering)
                    Center(
                      child: _DockingSelectorVisual(
                        highlightedAction: _hoverAction,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 탭 영역에 보여줄 화면 컨텐츠
  Widget _buildContent(String categoryId){
    print("_buildContent :: $categoryId");
    return Text(
        categoryId,
        style: const TextStyle(fontSize: 20, color: Colors.grey)
    );
  }

  /// 드롭 위치에 따른 오버레이 디자인 (테두리 하이라이트 등)
  Widget _buildDropOverlay(String action) {
    const double thinWidth = 2.0;
    const double thickWidth = 8.0;

    // 센터일 때는 전체적으로 은은한 파란색
    if (action == 'center') {
      return Container(
        decoration: BoxDecoration(
          color: GENIE_ACCENT_COLOR_OP10,
          border: Border.all(color: GENIE_ACCENT_COLOR, width: thinWidth),
        ),
      );
    }

    // 상하좌우일 때는 해당 방향의 테두리만 두껍게 강조
    return Container(
      decoration: BoxDecoration(
        color: GENIE_ACCENT_COLOR_OP05,
        border: Border(
          top: BorderSide(
            color: GENIE_ACCENT_COLOR,
            width: action == 'top' ? thickWidth : thinWidth,
          ),
          bottom: BorderSide(
            color: GENIE_ACCENT_COLOR,
            width: action == 'bottom' ? thickWidth : thinWidth,
          ),
          left: BorderSide(
            color: GENIE_ACCENT_COLOR,
            width: action == 'left' ? thickWidth : thinWidth,
          ),
          right: BorderSide(
            color: GENIE_ACCENT_COLOR,
            width: action == 'right' ? thickWidth : thinWidth,
          ),
        ),
      ),
    );
  }
}

/// 패널 중앙에 나타나는 분할 방향 선택 비주얼 (십자 모양 아이콘들)
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon('top', Icons.arrow_drop_up, BTN_DOCKING_SELECTOR_SIZE),
          const SizedBox(height: BTN_DOCKING_SELECOTR_GAP),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon('left', Icons.arrow_left, BTN_DOCKING_SELECTOR_SIZE),
              const SizedBox(width: BTN_DOCKING_SELECOTR_GAP),
              _buildIcon('center', Icons.stop_rounded, BTN_DOCKING_SELECTOR_SIZE, isCenter: true),
              const SizedBox(width: BTN_DOCKING_SELECOTR_GAP),
              _buildIcon('right', Icons.arrow_right, BTN_DOCKING_SELECTOR_SIZE),
            ],
          ),
          const SizedBox(height: BTN_DOCKING_SELECOTR_GAP),
          _buildIcon('bottom', Icons.arrow_drop_down, BTN_DOCKING_SELECTOR_SIZE),
        ],
      ),
    );
  }

  Widget _buildIcon(
      String action,
      IconData icon,
      double size, {
        bool isCenter = false,
      }) {
    bool isHighlighted = highlightedAction == action;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isHighlighted ? ACCENT_PURPLE : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isHighlighted ? ACCENT_PURPLE_ACTIVE : Colors.grey.shade400,
        ),
      ),
      child: Icon(
        icon,
        color: isHighlighted ? Colors.white : Colors.grey[600],
        size: isCenter ? 24 : 32,
      ),
    );
  }
}

/// 드래그 가능한 개별 탭 위젯 (드래그 소스이자 드롭 타겟)
class _DraggableTab extends StatelessWidget {
  final String nodeId;
  final TabData tab;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final Function(String tabId) onReorder;

  // 피드백 위젯의 크기 상수 (중심점 계산용)
  static const double _feedbackWidth = 100;
  static const double _feedbackHeight = 36;

  const _DraggableTab({
    required this.nodeId,
    required this.tab,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    // 1. DragTarget: 다른 탭이 이 탭 위로 드래그될 때 순서 변경 감지
    return DragTarget<DragPayload>(
      onWillAccept: (data) {
        // 같은 노드 내의 다른 탭일 경우만 수락
        return data != null &&
            data.sourceNodeId == nodeId &&
            data.tabId != tab.id;
      },
      onAccept: (data) {
        onReorder(data.tabId);
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        // 2. Draggable: 이 탭 자체를 드래그 시작
        return Draggable<DragPayload>(
          data: DragPayload(nodeId, tab.id),
          onDragStarted: onDragStarted,
          onDraggableCanceled: (_, __) => onDragEnded(),
          onDragEnd: (_) => onDragEnded(),

          // 드래그 좌표 기준 마우스 포인터로 설정
          // DragTarget의 details.offset이 마우스 커서 좌표가 됨
          dragAnchorStrategy: pointerDragAnchorStrategy,

          // 피드백 위젯 중심점 조정
          // pointerDragAnchorStrategy는 피드백의 좌상단을 마우스에 맞춤
          // 피드백 위젯을 크기의 절반만큼 이동시켜
          // 커서가 위젯 중앙에 위치하도록 조정
          feedback: Transform.translate(
            offset: const Offset(-_feedbackWidth / 2, -_feedbackHeight / 2),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: _feedbackWidth,
                height: _feedbackHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(blurRadius: 5, color: Colors.black26),
                  ],
                  border: Border.all(color: GENIE_ACCENT_COLOR),
                ),
                child: Text(
                  tab.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: TAB_TITLE_FONT_SIZE,
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildTabDesign(isHovering),
          ),
          child: GestureDetector(
            onTap: onTap,
            child: _buildTabDesign(isHovering),
          ),
        );
      },
    );
  }

  Widget _buildTabDesign(bool isHovering) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        // 드롭 가능한 상태일 때 왼쪽에 파란색 바(인디케이터) 표시
        border: isHovering
            ? const Border(left: BorderSide(color: GENIE_ACCENT_COLOR, width: 3))
            : null,
      ),
      child: Text(
        tab.title,
        style: TextStyle(
          color: isSelected ? GENIE_ACCENT_COLOR : Colors.black,
          fontSize: TAB_TITLE_FONT_SIZE,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}