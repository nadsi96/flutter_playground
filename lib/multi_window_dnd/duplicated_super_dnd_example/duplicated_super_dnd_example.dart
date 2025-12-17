import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class DuplicatedSuperDndExample extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Duplicated Super D&D Example")),
      body: DuplicatedSuperDnd()
    );
  }
}

class DuplicatedSuperDnd extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return _DuplicatedSuperDnd();
  }
}
class _DuplicatedSuperDnd extends State<DuplicatedSuperDnd>{
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: getDraggableWidget()
        ),

        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: getDropRegion()
          )
        )
      ]
    );
  }

  Widget getDraggableWidget(){

    return DragItemWidget(
      allowedOperations: (){
        return [DropOperation.copy];
      },
      canAddItemToExistingSession: false,
      dragItemProvider: (req) async {
        final DragItem dragItem = DragItem(
          localData: {"data": "outer localData"}
        );
        return dragItem;
      },
      child: DraggableWidget(
        // dragItemsProvider: (req) async{
        //
        // },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.red
          ),
          child: getInnerDraggableWidget()
        )
      )
    );
  }

  Widget getInnerDraggableWidget(){
    return DragItemWidget(
      allowedOperations: (){
        return [DropOperation.copy];
      },
      canAddItemToExistingSession: false,
      dragItemProvider: (req) async {
        final DragItem dragItem = DragItem(
            localData: {"data": "inner localData"}
        );
        return dragItem;
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue
        ),
        child: Text("draggable Widget")
      )
    );
  }

  Widget getDropRegion(){
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(12)
      ),
      child: DropZone(
        tag: "first",
        color: Colors.white,
        child: Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            width: 100,
            child: DropZone(
              tag: "second",
              color: Colors.grey
            )
          )
        )
      )
    );
  }

}

class DropZone extends StatelessWidget{
  final String tag;
  final Widget? child;
  final Color color;
  DropZone({required this.tag, required this.color, this.child});

  @override
  Widget build(BuildContext context) {
    return DropRegion(
        formats: Formats.standardFormats,
        onDropOver: (DropOverEvent){
          return DropOverEvent.session.allowedOperations.firstOrNull ?? DropOperation.none;
        },
        onDropEnter: (details){
          print("$tag :: onDropEnter");
        },
        onDropLeave: (details){
          print("$tag :: onDropLeave");
        },
        onDropEnded: (details){
          print("$tag :: onDropEnded");
        },
        onPerformDrop: (PerformDropEvent ) async {
          final item = PerformDropEvent.session.items.first;
          final dataMap = item.localData as Map<String, dynamic>;
          print("$tag :: onPerformDrop :: $dataMap");

        },
        child: Stack(
            children: [
              Positioned.fill(
                  child: ColoredBox(color: color)
              ),
              if(child != null) child!
            ]
        )
    );
  }
}