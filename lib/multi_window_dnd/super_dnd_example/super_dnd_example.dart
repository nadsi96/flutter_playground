import 'package:flutter/material.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_example/draggable_widget.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_example/drop_zone.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class SuperDndExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Super D&D")),
      body: SuperDnd()
    );
  }
}

class SuperDnd extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return SuperDndState();
  }

}
class SuperDndState extends State<SuperDnd> {

  late final List<Widget> draggable;

  @override
  void initState() {
    super.initState();
    draggable = [
      DraggableItemWidget(
          name: "Text",
          color: Colors.red,
          dragItemProvider: textDragItem
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: IntrinsicWidth(
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: draggable,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: DropZone()
          )
        )
      ],
    );
  }

  Future<DragItem?> textDragItem(DragItemRequest rq) async {
    final item = DragItem(
      localData: "text-item",
      suggestedName: "PlainText.txt"
    );
    item.add(Formats.plainText("Plain Text Value"));
    return item;
  }

}

