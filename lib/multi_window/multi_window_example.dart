import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

class MultiWindowExample extends StatelessWidget {

  const MultiWindowExample({super.key});

  @override
  Widget build(BuildContext context) {

    int count = 0;

    return Scaffold(
      appBar: AppBar(title: Text("MultiWindow Example"),),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: [
            getNewWindowBtn(sText: "open new window", onTapFunc: () async {
              count += 1;
              final controller = await WindowController.create(
                  WindowConfiguration(
                    arguments: jsonEncode({
                      "type": "newWindow",
                      "data": {
                        "count": count
                      }
                    }),
                  )
              );
              await controller.show();
            }),
          ],
        ),
      ),
    );
  }

  Widget getNewWindowBtn({required String sText, Function()? onTapFunc}){
    return InkWell(
      onTap: onTapFunc,
      child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.blue,
          child: Text(sText)
      ),
    );
  }

}


class NewWindow extends StatefulWidget{
  int count;
  NewWindow({super.key, required this.count});

  @override
  State<StatefulWidget> createState() {
    return NewWindowState();
  }
}

class NewWindowState extends State<NewWindow>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("New Window")),
        body: Center(
            child: Text("new window count: ${widget.count}")
        ),
      floatingActionButton: FloatingActionButton(onPressed: (){
        setState(() {
          widget.count++;
        });
      }),
    );
  }
}