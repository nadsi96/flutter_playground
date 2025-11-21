import 'package:flutter/material.dart';
import 'package:flutter_playground/docking_layout/docking_layout_example.dart';
import 'package:flutter_playground/multi_split_view/multi_split_view_example.dart';
import 'package:flutter_playground/riverpod/riverpod_counter_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/home',
      routes: routes
    );
  }
}

final routes = {
  '/home': (context) => Home(),
  '/riverpod_test': (context) => RiverpodCounterPage(),
  '/multi_split_view_example': (context) => MultiSplitViewExamplePage(),
  '/docking_layout_example': (context) => DockingExamplePage()
};
class Home extends StatelessWidget{

  Widget menuButton(context, sRoute){
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, sRoute);
      },
      child: Container(
        width: 200,
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
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              menuButton(context, "/riverpod_test"),
              menuButton(context, "/multi_split_view_example"),
              menuButton(context, "/docking_layout_example"),
            ],
          ),
        )
      )
    );
  }

}