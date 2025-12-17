import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'drop_item_info_widget.dart';

/// 드래그된 위젯이 드랍될 영역
class DropZone extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return DropZoneState();
  }
}

class DropZoneState extends State<DropZone> {
  bool bDragOver = false;

  Widget preview = SizedBox();
  Widget content = Center(child: Text("drop here"));

  DropOperation onDropOver(DropOverEvent event) {
    // print("onDropOver");

    setState(() {
      bDragOver = true;
      preview = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.black.withOpacity(0.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: event.session.items.length,
                  itemBuilder: (context, idx) {
                    return DropItemInfoWidget(
                      dropItem: event.session.items[idx],
                    );
                  },
                  separatorBuilder: (context, idx) {
                    return Container(
                      height: 2,
                      color: Colors.white.withOpacity(0.7),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });

    return event.session.allowedOperations.firstOrNull ?? DropOperation.none;
  }

  Future<void> onPerformDrop(PerformDropEvent event) async {
    print("onPerformDrop");

    if (mounted) {}
  }

  void onDropEnter(DropEvent event) {
    print("onDropEnter");
  }

  void onDropLeave(DropEvent event) {
    print("onDropLeave");
    setState(() {
      bDragOver = false;
    });
  }
  void onDropEnd(DropEvent event) {
    print("onDropEnd");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropRegion(
        formats: [...Formats.standardFormats],
        // default: HitTestBehavior.deferToChild
        // deferToChild: 하위 위젯 중 hitTest 걸려야 이벤트 발생
        //            단순 SizedBox, Container로는 hitTest 발생하지 않고, 실제 픽셀이 그려져야함
        //            ColoredBox(color: Colors.transparent) >> 투명이랑 투명 색 픽셀 렌더로 hitTest 발생
        // opaque: DropRegion이 이벤트 가로챔
        // translucent: DropRegion, 하위 위젯 모두 이벤트 수신
        hitTestBehavior: HitTestBehavior.deferToChild,
        onDropOver: onDropOver,
        onPerformDrop: onPerformDrop,
        onDropEnter: onDropEnter,
        onDropEnded: onDropEnd,
        onDropLeave: onDropLeave,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Colors.transparent, child: content)),
            // Positioned.fill(child: content),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: bDragOver ? 1 : 0,
                  duration: Duration(milliseconds: 200),
                  child: preview,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: DropRegion(
                  formats: Formats.standardFormats,
                  onDropOver: (DropOverEvent) {
                    return DropOverEvent.session.allowedOperations.firstOrNull ?? DropOperation.none;
                  },
                onDropEnter: (details){
                    print("onDropEnter :: second");
                },
                onDropLeave: (details){
                    print("onDropLeave :: second");
                },
                onDropEnded: (details){
                    print("onDropEnded :: second");
                },
                onPerformDrop: (PerformDropEvent ) async {
                    print("onPerformDrop :: second");
                },
                  child: Container(
                    width: 50,
                    color: Colors.grey,
                  ),

              ),

            )
          ],
        ),
      )
    );
  }
}
