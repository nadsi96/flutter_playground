import 'dart:math';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

class MultiSplitViewExamplePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _MultiSplitViewExamplePage();
  }
}

class _MultiSplitViewExamplePage extends State<MultiSplitViewExamplePage> {
  final MultiSplitViewController _multiSplitViewController =
      MultiSplitViewController();

  bool _pushDividers = false;

  @override
  void initState() {
    super.initState();
    _multiSplitViewController.areas = [
      // size: 고정 픽셀 크기
      // flex: 비율
      // min: 최소 크기
      // max: 최대 크기
      // data: 해당 영역 그릴 때 전달할 데이터
      // builder: area 작성 시 위젯 빌더
      //  >> MutliSplitView에도 동적 렌더링을 위한 builder가 있는데
      //  >> Area에 builder가 있다면 Area의 빌더를 사용
      //  >> 없는 항목은 MultiSplitView의 builder로 렌더링
      Area(data: _randomColor(), size: 600, min: 100),
      Area(data: _randomColor(), flex: 1),
      Area(data: _randomColor(), size: 150, min: 100),
      Area(data: _randomColor(), size: 150, min: 100),
    ];
    _multiSplitViewController.addListener(_rebuild);
  }

  @override
  void dispose() {
    super.dispose();
    _multiSplitViewController.removeListener(_rebuild);
  }

  void _rebuild() {
    setState(() {
      // rebuild to update empty text and buttons
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget buttons = Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          ElevatedButton(
            onPressed: _onAddFlexButtonClick,
            child: const Text('Add flex'),
          ),
          ElevatedButton(
            onPressed: _onAddSizeButtonClick,
            child: const Text('Add size'),
          ),
          ElevatedButton(
            onPressed: _multiSplitViewController.areasCount != 0
                ? _onRemoveFirstButtonClick
                : null,
            child: const Text('Remove first'),
          ),
          Checkbox(
            value: _pushDividers,
            onChanged: (newValue) => setState(() {
              _pushDividers = newValue!;
            }),
          ),
          const Text("Push dividers"),
        ],
      ),
    );

    Widget? content;
    if (_multiSplitViewController.areasCount != 0) {
      MultiSplitView multiSplitView = MultiSplitView(
        // 분할 방향
        // defalut: 가로 분할
        // MultiSplitView.defaultAxis (== Axis.horizontal)
        // Axis
        axis: MultiSplitView.defaultAxis,
        // 구분선 움직일때 들어오는 이벤트
        // 움직이는동안 계속 이벤트 수신됨
        onDividerDragUpdate: _onDividerDragUpdate,
        // 구분선 클릭 이벤트
        onDividerTap: _onDividerTap,
        // 구분선 더블클릭 이벤트
        onDividerDoubleTap: _onDividerDoubleTap,

        controller: _multiSplitViewController,

        // 구분선 조작 시 다른 구분선 조작 여부
        // false: 해당 구분선만 움직임
        // true: 조작하면 옆 패널들도 밀려서 영역 비율 보존
        // false라도 영역 크기 지정이 flex인 항목은 영향있음
        pushDividers: _pushDividers,

        // 구분선 드래그 통해 사이즈 조절 가능 여부
        // default: true
        // resizable: false,

        // 스플릿 내부 컨텐츠 생성
        builder: (BuildContext context, Area area) {
          print("Area build :: ${area.index}");
          return ColorWidget(area: area, color: area.data, onRemove: _removeColor);
        }
      );

      content = Padding(
        padding: const EdgeInsets.all(16),
        child: MultiSplitViewTheme(
          data: MultiSplitViewThemeData(
            // 구분선 두께
            // default: 10
            // dividerThickness: MultiSplitViewThemeData.defaultDividerThickness,

            // 구분선 스타일
            // 색상, groove 형태, gradient, 커스텀 페인터(DividerPainter)
            dividerPainter: DividerPainters.grooved2(),

            // 드래그를 편하게 하도록 구분선에 추가적인 영역 제공
            // default: 0
            // dividerHandleBuffer: MultiSplitViewThemeData.defaultDividerHandleBuffer

          ),
          child: multiSplitView,
        ),
      );
    } else {
      content = const Center(child: Text('Empty'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Multi Split View Example')),
      body: Column(
        children: [
          buttons,
          Expanded(child: content),
        ],
      ),
      // body: horizontal,
    );
  }

  Color _randomColor() {
    Random random = Random();
    return Color.fromARGB(
      255,
      155 + random.nextInt(100),
      155 + random.nextInt(100),
      155 + random.nextInt(100),
    );
  }

  _onDividerDragUpdate(int index) {
    print('drag update: $index');
  }

  _onRemoveFirstButtonClick() {
    if (_multiSplitViewController.areasCount != 0) {
      _multiSplitViewController.removeAreaAt(0);
    }
  }

  _onDividerTap(int dividerIndex) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text("Tap on divider: $dividerIndex"),
      ),
    );
  }

  _onDividerDoubleTap(int dividerIndex) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text("Double tap on divider: $dividerIndex"),
      ),
    );
  }

  _onAddFlexButtonClick() {
    _multiSplitViewController.addArea(Area(data: _randomColor()));
  }

  _onAddSizeButtonClick() {
    _multiSplitViewController.addArea(Area(data: _randomColor(), size: 100));
  }

  void _removeColor(int index) {
    _multiSplitViewController.removeAreaAt(index);
  }
}

class ColorWidget extends StatelessWidget {
  const ColorWidget({
    Key? key,
    required this.color,
    required this.onRemove,
    required this.area,
  }) : super(key: key);

  final Color color;
  final Area area;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    TextStyle textStyle = const TextStyle(fontSize: 10);
    if (area.size != null) {
      children.add(Text('size: ${area.size!}', style: textStyle));
    }
    if (area.flex != null) {
      children.add(Text('flex: ${area.flex!}', style: textStyle));
    }
    if (area.min != null) {
      children.add(Text('min: ${area.min!}', style: textStyle));
    }
    if (area.max != null) {
      children.add(Text('max: ${area.max!}', style: textStyle));
    }
    Widget info = Center(
      child: Container(
        color: const Color.fromARGB(200, 255, 255, 255),
        padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
        child: Wrap(
          runSpacing: 5,
          spacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );

    return InkWell(
      onTap: () => onRemove(area.index),
      child: Container(
        color: color,
        child: Stack(
          children: [
            const Placeholder(color: Colors.black),
            info,
          ],
        ),
      ),
    );
  }
}
