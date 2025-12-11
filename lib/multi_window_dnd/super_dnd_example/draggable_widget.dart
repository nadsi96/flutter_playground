import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// 드래그될 위젯
class DraggableItemWidget extends StatefulWidget {
  final String name;
  final Color color;
  final DragItemProvider dragItemProvider;

  const DraggableItemWidget({
    super.key,
    required this.name,
    required this.color,
    required this.dragItemProvider
  });
  @override
  State<StatefulWidget> createState() {
    return DraggableItemWidgetState();
  }

}

class DraggableItemWidgetState extends State<DraggableItemWidget> {

  bool dragging = false;

  @override
  Widget build(BuildContext context) {
    return DragItemWidget(
      allowedOperations: () => [DropOperation.copy],
      canAddItemToExistingSession: true,
      dragItemProvider: provideDragItem,
      // dragBuilder: 위젯을 드래그할 때, 커서를 따라다니는 snapshot 위젯
      // 지정하지 않으면 child 내용
      // dragBuilder: (context, child) {
      //   return Container(
      //     padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      //     color: Colors.blue,
      //     child: Text("dragging")
      //   );
      // },
      child: DraggableWidget(
        child: AnimatedOpacity(
          opacity: dragging ? 0.5 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              widget.name,
              style: const TextStyle(fontSize: 20, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<DragItem?> provideDragItem(DragItemRequest request) async {
    final item = await widget.dragItemProvider(request);
    if (item != null) {
      void updateDraggingState() {
        setState(() {
          dragging = request.session.dragging.value;
        });
      }

      request.session.dragging.addListener(updateDraggingState);
      updateDraggingState();
    }
    return item;
  }

}