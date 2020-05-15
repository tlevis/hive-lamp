import 'dart:convert';
import 'dart:ffi';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hiveapp/services/transition.dart';
import 'package:hiveapp/pages/home.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';



class Loading extends StatefulWidget {
  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {

  void route() async {
    bool checkSomething = true;
    if (checkSomething)
    {
      Map<String, dynamic> connection;
      try {
        SharedPreferences sPref = await SharedPreferences.getInstance();
        String connectionString = sPref.getString('connectionObject');
        connection = jsonDecode(connectionString);
      }
      catch(e) {
        print(e);
      }
      Navigator.pushReplacementNamed(context, '/home', arguments: connection);
    }
    else
    {
//      Navigator.of(context)
//          .pushReplacement(Transition.getFadeTransition(LoginScreen()));
    }
  }

  loadingDone() async {
    final _secureStorage = new FlutterSecureStorage();
    SharedPreferences sPref = await SharedPreferences.getInstance();

    bool performBLEScan = true;
    try
    {
      String lampIp = await _secureStorage.read(key: 'lamp-ip');
      sPref.setString('lamp-ip', lampIp);
      if (lampIp != null && lampIp.isNotEmpty)
        {
          print("Found device in memory $lampIp");
          final socket = await Socket.connect(lampIp, 5656);
          await socket.close();
          socket.destroy();
          print("############## Device is ok");
          performBLEScan = false;
        }
    }
    catch(err)
    {
      performBLEScan = true;
      print(err);
      print("############## Cannot find device!");
    }

    print("############## After device check");

    if (performBLEScan)
    {
      FlutterBlue flutterBlue = FlutterBlue.instance;
      await flutterBlue.startScan(scanMode: ScanMode.lowLatency, timeout: Duration(seconds: 4));
      bool found = false;
      flutterBlue.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (found)
            break;

          if (r.device.name.contains("Hive-")) {
            try {
              await r.device.connect();
              List<BluetoothService> services = await r.device.discoverServices();
              services.forEach((service) async {
                var characteristics = service.characteristics;
                for (BluetoothCharacteristic c in characteristics) {
                  try {
                    if (c.uuid.toString() == "00005555-ead2-11e7-80c1-9a214cf093ae")
                    {
                      List<int> value = await c.read();
                      print("<<----------------->>");
                      String s = new String.fromCharCodes(value);
                      if (s.isNotEmpty)
                      {
                        found = true;
                        _secureStorage.write(key: "lamp-ip", value: s);
                        sPref.setString('lamp-ip', s);
                        r.device.disconnect();
                      }
                      print(s);
                      print("<<----------------->>");
                    }
                  } catch (err) {

                  }
                  if (found)
                    break;
                }
              });
            } catch (err) {

            }
          }
        }
      });

      // Stop scanning
      flutterBlue.stopScan();
    }

    var duration = new Duration(seconds: 3);
    return new Timer(duration, route);
  }


  @override
  void initState() {
    super.initState();
    loadingDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset('assets/images/logo.png', height: 100),
                Text("Please wait...",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.normal))
              ],
            )),
      ),
    );
  }
}
