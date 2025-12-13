import 'package:flutter/material.dart';


/// 마우스 클릭한 상태에서 화면 영역 밖으로 이동 여부 확인
class DragBoundaryExample extends StatefulWidget {

  final GlobalKey appKey = GlobalKey();

  @override
  State<StatefulWidget> createState() {
    return _DragBoundaryState();
  }
}

class _DragBoundaryState extends State<DragBoundaryExample> {

  bool bOutSide = false; // 커서 화면 밖으로 나갔는감?

  void checkBoundary(Offset globalPos){
    // print("appKey.currentContext == null? ${widget.appKey.currentContext == null}");
    if(widget.appKey.currentContext != null){
      final RenderBox box = widget.appKey.currentContext!.findRenderObject() as RenderBox;
      final Offset topLeft = box.localToGlobal(Offset.zero);
      final Offset btmRight = box.localToGlobal(box.size.bottomRight(Offset.zero));

      final Rect windowRect = Rect.fromPoints(topLeft, btmRight);
      print("cotains: ${windowRect.contains(globalPos)}");
      print("windowRect: $windowRect");
      print("globalPos: $globalPos");
      setState(() {
        bOutSide = !windowRect.contains(globalPos);
      });
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget.appKey,
      appBar: AppBar(title: Text("drag_boundary_test")),
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerMove: (event) {
          checkBoundary(event.position);
        },
        child: ColoredBox(
          color: Colors.grey,
          child: Center(
              child: Text(bOutSide ? "exterior" : "interior")
          ),
        ),
      ),
    );
  }

}
