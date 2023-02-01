import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:hiveapp/connectWidget.dart';
import 'package:hiveapp/pages/home.dart';

class ConnectToDevice extends StatefulWidget {
  @override
  _ConnectToDeviceState createState() => _ConnectToDeviceState();
}

class _ConnectToDeviceState extends State<ConnectToDevice> {
  @override
  void initState() {
    super.initState();
    FlutterBlue.instance.startScan(timeout: Duration(seconds: 2));
  }

  @override
  void dispose() {
    super.dispose();
  }


  TextEditingController wifiNameController = TextEditingController();
  TextEditingController wifiPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detected Hive Lamps"),
      ),

      body: RefreshIndicator(
      onRefresh: () =>
          FlutterBlue.instance.startScan(timeout: Duration(seconds: 2)),
      child: ListView(
          children: <Widget>[
            StreamBuilder<List<ScanResult>>(
              stream: FlutterBlue.instance.scanResults,
              initialData: [],
              builder: (c, snapshot) => Column(
              children: snapshot.data.where((r) => (r.device.name.contains("Hive-") || r.device.name.contains("Hive_Nano")))
                .map((r) => ScanResultTile(
                    result: r,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                      r.device.connect();
                      return Home(device: r.device);
                    })),
                  ),
                ).toList(),
              ),
            )],
    )
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.refresh),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}