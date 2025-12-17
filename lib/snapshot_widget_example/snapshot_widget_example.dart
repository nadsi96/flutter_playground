import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 탭 헤더를 드래그하면 컨텐츠 내용을 스냅샷으로 만들어서 끌고 다님
/// >> flutter 앱 외부로 노출되진 못함
/// super drag and drop에 builder로 RawImage로 넘겨줘야 가능할듯
class SnapShotWidgetExample extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SnapShot Widget Example")),
      body:TabContainer()
    );
  }
}

class TabContainer extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return _TabContainer();
  }

}
class _TabContainer extends State<TabContainer>{

  bool bDragging = false;
  final SnapshotController snapshotController = SnapshotController();

  final contentKey = GlobalKey();
  OverlayEntry? overlayEntry;
  Offset dragPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        getTabHeader(),
        Expanded(
          child: getTabContent()
        )
      ]
    );
  }

  void onDragStarted(Offset globalPosition) async{
    snapshotController.allowSnapshotting = true;

    // 다음 프레임에서 스냅샷 생성
    await WidgetsBinding.instance.endOfFrame;

  }

  Widget getTabHeader() {
    return GestureDetector(
      onPanStart: (details) async {
        dragPosition = details.globalPosition;
        final image = await captureContent();
        showOverlay(image);
      },
      onPanUpdate: (details){
        dragPosition = details.globalPosition;
        overlayEntry?.markNeedsBuild();
      },
      onPanEnd: (details) {
        removeOverlay();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        color: Colors.blue,
        child: Text("Tab Item")
      )
    );
  }

  Widget getTabContent(){
    return RepaintBoundary(
      key: contentKey,
      child: Container(
        color: Colors.grey,
        alignment: Alignment.center,
        child: Text("Tab Content")
      )
    );
  }

  Future<ui.Image> captureContent() async {
    final boundary = contentKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final capture = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio
    );
    return capture;
  }

  void showOverlay(ui.Image image) {
    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Transform.translate(
                offset: dragPosition - Offset(150, 150),
                child: Opacity(
                  opacity: 0.7,
                  child: RawImage(
                    image: image
                  )
                )
              )
            )
          )
        );
      }
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void removeOverlay(){
    overlayEntry?.remove();
    overlayEntry = null;
  }
}

class TabItem extends StatelessWidget{
  final int idx;
  final bool bDragging;
  TabItem({required this.idx, this.bDragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        color: Colors.blue,
        child: Text("tabItem_$idx")
    );
  }
}