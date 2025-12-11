import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// 드래그 드랍된 항목의 데이터 보여주기 위한 위젯
class DropItemInfoWidget extends StatelessWidget{

  final DropItem dropItem;

  DropItemInfoWidget({required this.dropItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 11.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dropItem.localData != null)
              Text.rich(TextSpan(children: [
                const TextSpan(
                  text: 'Local data: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: '${dropItem.localData}'),
              ])),
            const SizedBox(
              height: 4,
            ),
            Text.rich(TextSpan(children: [
              const TextSpan(
                text: 'Native formats: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: dropItem.platformFormats.join(', ')),
            ])),
          ],
        ),
      ),
    );
  }

}