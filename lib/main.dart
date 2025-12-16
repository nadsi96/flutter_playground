import 'dart:convert';
import 'dart:io';

// import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_playground/docking_layout/docking_layout_example.dart';
import 'package:flutter_playground/drag_boundary_example/drag_boundary_example.dart';
import 'package:flutter_playground/multi_split_view/dynamic_split_view_example.dart';
import 'package:flutter_playground/multi_split_view/multi_split_view_example.dart';
import 'package:flutter_playground/multi_window/multi_window_example.dart';
import 'package:flutter_playground/multi_window/multi_window_position.dart' as multiWindowPosition;
import 'package:flutter_playground/reorderble_tab_layout/reorderble_tab_layout_example.dart';
import 'package:flutter_playground/riverpod/riverpod_counter_page.dart';
import 'package:window_manager/window_manager.dart';

import 'multi_split_view/dynamic_split_view_docking_example.dart';
import 'multi_split_view/dynamic_split_view_docking_example2.dart';
import 'multi_window_dnd/multi_window_dnd_example.dart' as multiWindowDndExample;
import 'multi_window_dnd/multi_window_dnd_example2.dart' as multiWindowDndExample2;
import 'multi_window_dnd/super_dnd_example/super_dnd_example.dart';

void main(List<String> args) async{

  print("args: $args");
  WidgetsFlutterBinding.ensureInitialized();

  // /// 타이틀바 커스텀
  // /// bitsdojo_window
  // /// 사용 위한 네이티브 코드 확인
  // ///  windows
  // ///  windows\runner\main.cpp
  // ///  macos
  // ///  macos\runner\MainFlutterWindow.swift
  // ///  해당 파일 주석 참조 ( // bitsdojo)
  // ///
  // /// BDW_CUSTOM_FRAME: 커스텀 윈도 타이틀바, 버튼 사용 시 추가
  // /// BDW_HIDE_ON_STARTUP: 시작 시 윈도 숨김
  // ///                     아래 코드에서 show 되기 전까지 노출되지 않음
  // if(Platform.isWindows || Platform.isMacOS){
  //   doWhenWindowReady(() {
  //     appWindow.minSize = const Size(400, 300);
  //     appWindow.size = const Size(600, 450);
  //     appWindow.alignment = Alignment.center;
  //     appWindow.show();
  //   });
  // }

  String? windowId;
  Map<String, dynamic>? arguments;
  /// multi window test
  /// arguments에 데이터를 jsonEncode로 전송
  /// jsonDecode로 풀어서 값 확인
  /// multi_window_example.dart open new window 확인
  print("kIsWeb: $kIsWeb");
  if(!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
    final windowController = await WindowController.fromCurrentEngine();

    // 최초 실행이거나 새창을 열 때 arguments가 없다면 arguments는 빈 문자열
    // 최초 실행이면 args = 빈 배열
    // 새로운 윈도우라면 args[0]: "multi_window"
    //               args[1]: windowId
    //               args[2]: == arguments
    if(args.isNotEmpty && args.first == "multi_window"){
      // arguments = jsonDecode(windowController.arguments);
      windowId = args[1];
    }
    if(windowController.arguments.isNotEmpty) {
      arguments = jsonDecode(windowController.arguments);
    }

    /// window_manager로 변경 >>
    await windowManager.ensureInitialized();


    WindowOptions windowOptions = WindowOptions(
      size: Size(600, 450),
      minimumSize: Size(400, 300),
      center: windowController.arguments.isEmpty,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if(arguments != null && arguments["position"] != null) {
        Offset position = Offset(arguments["position"]["x"], arguments["position"]["y"]);
        windowManager.setPosition(position);
      }
      // windowManager.setPosition(position: );

    });
    /// << window_manager로 변경
  }

  runApp(MyApp(windowId: windowId, arguments: arguments));
}

class MyApp extends StatelessWidget {
  String? windowId;
  Map<String, dynamic>? arguments;
  MyApp({super.key, this.windowId, this.arguments});

  @override
  Widget build(BuildContext context) {
    Widget? home;
    print("arguments: $arguments");
    if(arguments != null){
      if(arguments!["type"] == "newWindow"){
        final targetScreen = arguments!["targetScreen"];
        if(targetScreen == "multi_window_example"){
          final data = arguments!["data"];
          home = NewWindow(windowId: windowId!, count: data["count"] ?? -1);
          return MaterialApp(
            home: home
          );
        } else if(targetScreen == "multi_window_dnd_example") {
          final data = arguments!["data"];
          final tabData = data["tabData"];
          home = multiWindowDndExample.MultiWindowDndExample(
            windowId: windowId!,
            tabData: multiWindowDndExample.TabData(
              id: tabData["id"],
              title: tabData["title"],
              content: tabData["content"],
              count: tabData["count"] ?? 0,
            ),
          );
        } else if(targetScreen == multiWindowDndExample2.TARGET_SCREEN) {
          final data = arguments!["data"];
          final tabData = data["tabData"];
          home = multiWindowDndExample2.MultiWindowDndExample_newWindow(
            windowId: windowId!,
            tabData: multiWindowDndExample2.TabData(
              id: tabData["id"],
              title: tabData["title"],
              content: tabData["content"],
              count: tabData["count"] ?? 0,
            )
          );
        } else if(targetScreen == "multi_window_position") {
          home = multiWindowPosition.NewWindow(windowId: windowId!);
        }
      }
    }
    if(home == null) {
      return MaterialApp(
          initialRoute: '/home',
          routes: routes
      );
    } else{
      return MaterialApp(
        home: home,
        routes: routes
      );
    }

  }
}

final routes = {
  '/home': (context) => Home(),
  '/riverpod_test': (context) => RiverpodCounterPage(),
  '/multi_split_view_example': (context) => MultiSplitViewExamplePage(),
  '/dynamic_split_view_example': (context) => DynamicSplitViewExample(),
  '/dynamic_multi_split_view_docking_example': (context) => DockingLayoutExample(),
  '/dynamic_multi_split_view_docking_example2': (context) => DockingLayoutExample2(),
  '/docking_layout_example': (context) => DockingExamplePage(),
  '/reorderable_tab_layout_example': (context) => ReorderableTabLayoutExample(),
  '/multi_window_example': (context) => MultiWindowExample(),
  '/super_dnd_example': (context) => SuperDndExample(),
  '/multi_window_dnd_example': (context) => multiWindowDndExample.MultiWindowDndExample(windowId: "main"),
  '/multi_window_dnd_example2': (context) => multiWindowDndExample2.MultiWindowDndExample(windowId: "main"),
  '/drag_boundary_example': (context) => DragBoundaryExample(),
  '/multi_window_position': (context) => multiWindowPosition.MultiWindowPositionExample(),

};
class Home extends StatelessWidget{

  Widget menuButton(context, sRoute){
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, sRoute);
      },
      child: Container(
        width: 250,
        height: 50,
        color: Colors.blue,
        child: Center(
          child: Text("$sRoute")
        )
      )
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                menuButton(context, "/riverpod_test"),
                menuButton(context, "/multi_split_view_example"),
                menuButton(context, "/dynamic_split_view_example"),
                menuButton(context, "/dynamic_multi_split_view_docking_example"),
                menuButton(context, "/dynamic_multi_split_view_docking_example2"),
                menuButton(context, "/docking_layout_example"),
                menuButton(context, "/reorderable_tab_layout_example"),
                menuButton(context, "/multi_window_example"),
                menuButton(context, "/super_dnd_example"),
                menuButton(context, "/multi_window_dnd_example"),
                menuButton(context, "/multi_window_dnd_example2"),
                menuButton(context, "/drag_boundary_example"),
                menuButton(context, "/multi_window_position"),

              ],
            ),
          )
        ),
      ),
    );
  }

}