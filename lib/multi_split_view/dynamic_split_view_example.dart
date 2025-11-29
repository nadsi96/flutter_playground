import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// 각 개별 분할 영역에 대한 정보를 담는 클래스입니다.
/// 이 영역은 리프(leaf) 영역(실제 콘텐츠를 가짐)이거나,
/// 다른 MultiSplitView를 포함하는 컨테이너(내부 노드)일 수 있습니다.
class PaneData {
  String id;
  Color color; // 리프 영역일 경우 배경 색상
  MultiSplitViewConfig? splitConfig; // 이 영역이 중첩된 MultiSplitView를 포함하는 경우

  PaneData({required this.id, this.color = Colors.grey, this.splitConfig});
}

/// MultiSplitView의 구성을 정의하는 클래스입니다.
/// 분할 방향과 해당 분할 뷰가 포함하는 자식 영역들의 ID 목록을 가집니다.
class MultiSplitViewConfig {
  Axis axis; // 분할 방향 (가로 또는 세로)
  List<String> paneIds; // 이 MultiSplitView의 자식으로 들어갈 PaneData의 ID 목록

  MultiSplitViewConfig({required this.axis, required this.paneIds});
}

class DynamicSplitViewExample extends StatefulWidget {
  const DynamicSplitViewExample({super.key});

  @override
  _DynamicSplitViewExample createState() => _DynamicSplitViewExample();
}

class _DynamicSplitViewExample extends State<DynamicSplitViewExample> {
  // 모든 PaneData 객체들을 ID로 매핑하여 저장하는 맵
  final Map<String, PaneData> _allPanes = {};

  // 최상위 MultiSplitView의 구성
  late MultiSplitViewConfig _rootSplitConfig;

  // 현재 선택된 영역의 ID
  String? _selectedPaneId;
  // 새로운 영역 ID 생성을 위한 인덱스
  int _nextPaneIndex = 3; // 'pane1', 'pane2' 다음부터 시작

  @override
  void initState() {
    super.initState();
    // 초기 두 개의 영역 생성
    _allPanes['pane1'] = PaneData(id: 'pane1', color: Colors.red[100]!);
    _allPanes['pane2'] = PaneData(id: 'pane2', color: Colors.blue[100]!);

    // 최상위 뷰는 가로로 분할된 두 개의 초기 영역을 가집니다.
    _rootSplitConfig = MultiSplitViewConfig(
      axis: Axis.horizontal,
      paneIds: ['pane1', 'pane2'],
    );
  }

  /// 주어진 PaneData 객체를 사용하여 해당 영역의 콘텐츠 위젯을 빌드합니다.
  Widget _createPaneContentWidget(PaneData paneData) {
    Widget content;

    if (paneData.splitConfig != null) {
      // 이 PaneData가 중첩된 MultiSplitView를 포함하는 경우
      // 해당 splitConfig로 새로운 MultiSplitView를 재귀적으로 빌드합니다.
      content = _buildMultiSplitView(paneData.splitConfig!);
    } else {
      // 이 PaneData가 리프 영역인 경우 (더 이상 분할되지 않은 최종 콘텐츠)
      // 실제 콘텐츠와 분할 버튼을 표시합니다.
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pane ID: ${paneData.id}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // 선택된 영역일 경우에만 분할 버튼을 표시합니다.
            if (_selectedPaneId == paneData.id) ...[
              ElevatedButton(
                onPressed: () => _splitPane(paneData.id, Axis.horizontal),
                child: const Text('가로로 분할'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _splitPane(paneData.id, Axis.vertical),
                child: const Text('세로로 분할'),
              ),
            ]
          ],
        ),
      );
    }

    // 모든 분할 가능한 영역을 GestureDetector로 감싸 탭 이벤트를 처리합니다.
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaneId = paneData.id;
          debugPrint('Selected pane: $_selectedPaneId');
        });
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: paneData.color, // 리프 영역의 배경색
          border: Border.all(
            color: _selectedPaneId == paneData.id ? Colors.blue : Colors.transparent, // 선택 시 파란색 테두리
            width: _selectedPaneId == paneData.id ? 3 : 0, // 선택 시 테두리 두께
          ),
        ),
        child: content,
      ),
    );
  }

  /// 주어진 MultiSplitViewConfig를 사용하여 MultiSplitView 위젯을 빌드합니다.
  Widget _buildMultiSplitView(MultiSplitViewConfig config) {
    // config에 정의된 paneIds를 기반으로 Area 객체 목록을 생성합니다.
    final List<Area> areas = config.paneIds.map((id) {
      final paneData = _allPanes[id]!;
      // 각 Area는 PaneData 객체를 data로 가집니다.
      // // 여기서는 모든 영역에 동일한 flex: 1을 부여하여 공간을 균등하게 나눕니다.
      return Area(id: id, data: paneData, flex: 1);
      // return Area(id: id, data: paneData, size: 100);
    }).toList();

    MultiSplitViewController controller = MultiSplitViewController(areas: areas);
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 5,
        dividerPainter: DividerPainter(backgroundColor: Colors.red,
          highlightedBackgroundColor: Colors.blue,),
      ),
      child: MultiSplitView(
        axis: config.axis, // 분할 방향 설정
        initialAreas: areas, // 초기 영역 구성
        // controller: controller,
        // pushDividers: false,
        // 구분선 조작 시 영역 유지 방향
        // webull mac처럼
        sizeUnderflowPolicy: SizeUnderflowPolicy.stretchFirst,
        onDividerDragStart: (index) {
          // area를 처음 생성할 때는 영역을 반으로 나눠주어야함
          // >> Area(flex: 1)
          // 구분선 조작할 때는 size로 지정되어야 webull처럼 동작함
          // >>> 가로로 4개 분할 되어 있을 때, flex로 크기 지정하면
          //     첫번째와 마지막 구분선을 조작할때는 괜찮으나, 가운데 구분선을 조작하면
          //     전체 영역의 크기가 조정됨
          // for(Area area in areas){
          //   // area.size = area.;
          //   area.flex = null;
          // }
        },
        builder: (context, area) {
          // Area의 data에 저장된 PaneData를 가져와서 위젯을 빌드합니다.
          final paneData = area.data as PaneData;
          return _createPaneContentWidget(paneData);
        },
        // 필요에 따라 dividerBuilder 또는 controller 등을 추가할 수 있습니다.
        // controller: MultiSplitViewController(areas: areas),
        // dividerBuilder: (axis, index, resizable, dragging, highlighted, themeData) {
        //   return Container(color: dragging ? Colors.grey[300] : Colors.grey[100]);
        // },
      ),
    );
  }

  /// 특정 영역을 지정된 방향으로 분할하는 함수입니다.
  void _splitPane(String targetPaneId, Axis splitAxis) {
    setState(() {
      final targetPaneData = _allPanes[targetPaneId]!;

      // 새로운 두 개의 자식 영역을 위한 고유한 ID를 생성합니다.
      final newPaneId1 = 'pane$_nextPaneIndex';
      _nextPaneIndex++;
      final newPaneId2 = 'pane$_nextPaneIndex';
      _nextPaneIndex++;

      // 새로운 두 자식 영역의 PaneData를 생성합니다. 초기에는 리프 영역입니다.
      _allPanes[newPaneId1] = PaneData(id: newPaneId1, color: Colors.green[100]!);
      _allPanes[newPaneId2] = PaneData(id: newPaneId2, color: Colors.orange[100]!);

      // 기존의 targetPaneData를 이제 MultiSplitView를 포함하는 컨테이너로 변경합니다.
      // 즉, 해당 영역의 '콘텐츠'가 새로운 분할 뷰가 됩니다.
      targetPaneData.splitConfig = MultiSplitViewConfig(
        axis: splitAxis, // 분할할 방향
        paneIds: [newPaneId1, newPaneId2], // 새로운 자식 영역들의 ID
      );
      // targetPaneData의 기존 color는 splitConfig가 설정되면서 더 이상 직접 표시되지 않습니다.

      // 분할 후에는 선택된 영역을 해제합니다.
      _selectedPaneId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic MultiSplitView Example'),
      ),
      body: _buildMultiSplitView(_rootSplitConfig), // 최상위 MultiSplitView 렌더링
    );
  }
}