import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationExample extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Geolocation Example")),
      body: GeolocationWidget()
    );
  }
}

class GeolocationWidget extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return _GeolocationWidget();
  }

}

class _GeolocationWidget extends State<GeolocationWidget>{

  String sResult = "";

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Text(sResult),
        ),
        Positioned(
          bottom: 20,
            right: 20,
            child: FloatingActionButton(
                onPressed: () async {
                  if(await getServiceEnabled()){
                    if(await checkLocationPermission()){
                      print("getPosition");
                      getPosition();
                    } else{
                      setState(() {
                        sResult = "location permission denied";
                      });
                      print("location permission denied");
                    }
                  } else{
                    setState(() {
                      sResult = "need to enable location service";
                    });
                    print("need to enable location service");
                  }
                },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Text("get location info")
              )
            )
        ),
      ],
    );
  }

  /// 위치 기능 활성화 여부
  Future<bool> getServiceEnabled() async {
    bool bServiceEnabled = await Geolocator.isLocationServiceEnabled();
    print("isLocationServiceEnabled: $bServiceEnabled");
    return bServiceEnabled;
  }

  /// 권한 확인
  /// 거부인 경우, 허용 요청
  /// 요청에서도 거부 찍으면 false 반환
  Future<bool> checkLocationPermission() async {
    print("checkLocationPermission");
    LocationPermission permission = await Geolocator.checkPermission();
    print(permission);
    if(permission == LocationPermission.denied || permission == LocationPermission.deniedForever){
      permission = await Geolocator.requestPermission();
      print(permission);
      return (permission != LocationPermission.denied || permission != LocationPermission.deniedForever);
    } else{
      return true;
    }
  }

  Future<void> getPosition() async {

    // LocationAccuracy
    // Lowest - iOS: ~3000m, AOS: ~ 500m
    // Low - iOS: ~ 1000m, AOS: ~500m,
    // Medium - iOS: ~100m, AOS: 100 ~ 500m
    // High - iOS: ~10m, AOS: ~100m
    // Best - iOS: ~0m, AOS: ~100m
    print("getCurrentPosition");
    try{
      Geolocator.getCurrentPosition().timeout(
          Duration(seconds: 3),
        onTimeout: () {
            throw TimeoutException("Location request timed out");
        }
      ).then((position) {
        setState(() {
          sResult = position.toString();
        });
      });

    } catch(e){
      print(e);
      setState(() {
        sResult = e.toString();
      });
    }

  }
}