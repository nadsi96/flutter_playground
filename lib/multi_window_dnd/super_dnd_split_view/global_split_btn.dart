import 'package:flutter/material.dart';
import 'package:flutter_playground/multi_window_dnd/super_dnd_split_view/split_view_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class GlobalSplitBtn extends ConsumerWidget {

  final double GLOBAL_BORDER_HIGHLIGHT_WIDTH = 5;
  final double GLOBAL_SPLIT_BTN_SIZE = 40;


  final Function(String nodeId, String tabId) onGlobalSplit;
  final Alignment align;
  final IconData icon;


  GlobalSplitBtn({required this.onGlobalSplit, required this.align, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
        alignment: align,
        child: SizedBox(
          width: GLOBAL_SPLIT_BTN_SIZE,
          height: GLOBAL_SPLIT_BTN_SIZE,
          child: DropRegion(
            formats: Formats.standardFormats,
            onDropOver: (event) {
              return DropOperation.copy;
            },
            onDropEnter: (event) {
              // 해당 방향으로 highlight
              ref.read(globalSplitBtnProvider.notifier).setGlobalSplitAlign(
                  align: align);
            },
            onDropLeave: (event) {
              ref.read(globalSplitBtnProvider.notifier).setGlobalSplitAlign(
                  align: null);
            },
            onPerformDrop: (event) async {

            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                setHighlight(align, MediaQuery
                    .of(context)
                    .size),
                splitBtn(align)
              ],
            ),
          ),
        )
    );
  }

  Widget splitBtn(Alignment align){
    return Consumer(
      builder: (context, ref, widget) {
        final _globalSplitBtnProvider = ref.watch(globalSplitBtnProvider);
        bool bHovering = align == _globalSplitBtnProvider.align;
        bool bVisible = _globalSplitBtnProvider.bVisibility;

        return Opacity(
          opacity: bVisible ? 1 : 0.1,
          child: Container(
            width: GLOBAL_SPLIT_BTN_SIZE,
            height: GLOBAL_SPLIT_BTN_SIZE,
            decoration: BoxDecoration(
              color: bHovering ? Colors.blue : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: bHovering ? Colors.black : Colors.grey,
              ),
            ),
            child: Icon(
                icon,
                color: bHovering ? Colors.black : Colors.grey
            ),
          ),
        );
      }
    );
  }

  Widget setHighlight(Alignment align, Size parentSize){
    double sizeBtnHalf = GLOBAL_SPLIT_BTN_SIZE / 2;

    return Consumer(
        builder: (context, ref, widget) {
          final _globalSplitBtnProvider = ref.watch(globalSplitBtnProvider);
          final globalSplitAlignment = _globalSplitBtnProvider.align;

          if(globalSplitAlignment == Alignment.topCenter){
            return Positioned(
              top: 0,
              left: -parentSize.width/2 + sizeBtnHalf,
              width: parentSize.width,
              height: GLOBAL_BORDER_HIGHLIGHT_WIDTH,
              child: ColoredBox(color: Colors.blueAccent)
            );
          }
          else if(globalSplitAlignment == Alignment.centerRight){
            return Positioned(
                top: -parentSize.height/2 + sizeBtnHalf,
                right: 0,
                width: parentSize.width,
                height: GLOBAL_BORDER_HIGHLIGHT_WIDTH,
                child: ColoredBox(color: Colors.blueAccent)
            );
          }
          else if(globalSplitAlignment == Alignment.bottomCenter){
            return Positioned(
                bottom: 0,
                left: -parentSize.width/2 + sizeBtnHalf,
                width: parentSize.width,
                height: GLOBAL_BORDER_HIGHLIGHT_WIDTH,
                child: ColoredBox(color: Colors.blueAccent)
            );
          }
          else if(globalSplitAlignment == Alignment.centerLeft){
            return Positioned(
                top: -parentSize.height/2 + sizeBtnHalf,
                left: 0,
                width: parentSize.width,
                height: GLOBAL_BORDER_HIGHLIGHT_WIDTH,
                child: ColoredBox(color: Colors.blueAccent)
            );
          }

          return SizedBox.shrink();
        }
    );
  }


}