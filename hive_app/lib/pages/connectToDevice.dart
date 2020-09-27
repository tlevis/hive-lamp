import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:hiveapp/connectWidget.dart';
import 'package:hiveapp/pages/home.dart';

class WifiSetter extends StatefulWidget {
  @override
  _WifiSetterState createState() => _WifiSetterState();
}

class _WifiSetterState extends State<WifiSetter> {
  final String SERVICE_UUID = "0000aaaa-ead2-11e7-80c1-9a214cf093ae";
  final String CHARACTERISTIC_UUID = "00005555-ead2-11e7-80c1-9a214cf093ae";

  FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubscription;

  List<BluetoothDevice> detectedDevices;

  BluetoothDevice targetDevice;
  BluetoothCharacteristic targetCharacteristic;

  String connectionText = "";

  @override
  void initState() {
    super.initState();
    FlutterBlue.instance.startScan(timeout: Duration(seconds: 2));
    //startScan();
  }

   startScan() {
    setState(() {
      connectionText = "Start Scanning";
    });


    flutterBlue.startScan(timeout: Duration(seconds: 4));
    scanSubscription = flutterBlue.scan().listen((scanResult) {
      print(scanResult.device.name);
      if (scanResult.device.name.contains("Hive-") || scanResult.device.name.contains("Hive_Nano")) {
        detectedDevices.add(scanResult.device);
/*        stopScan();

        setState(() {
          connectionText = "Found Target Device";
        });

        targetDevice = scanResult.device;
        connectToDevice();*/
      }
    }, onDone: () => stopScan());
  }

  stopScan() {
    scanSubscription?.cancel();
    scanSubscription = null;
  }

  connectToDevice() async {
    if (targetDevice == null) {
      return;
    }

    setState(() {
      connectionText = "Device Connecting";
    });

    await targetDevice.connect();

    setState(() {
      connectionText = "Device Connected";
    });

    discoverServices();
  }

  disconnectFromDeivce() {
    if (targetDevice == null) {
      return;
    }

    targetDevice.disconnect();

    setState(() {
      connectionText = "Device Disconnected";
    });
  }

  discoverServices() async {
    if (targetDevice == null) {
      return;
    }

    List<BluetoothService> services = await targetDevice.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString() == SERVICE_UUID) {
        service.characteristics.forEach((characteristics) {
          if (characteristics.uuid.toString() == CHARACTERISTIC_UUID) {
            targetCharacteristic = characteristics;
            setState(() {
              connectionText = "All Ready with ${targetDevice.name}";
            });
          }
        });
      }
    });
  }

  writeData(String data) async {
    if (targetCharacteristic == null) return;

    List<int> bytes = utf8.encode(data);
    await targetCharacteristic.write(bytes);
  }

  @override
  void dispose() {
    super.dispose();
    stopScan();
  }

  submitAction() {
    var wifiData = '${wifiNameController.text},${wifiPasswordController.text}';
    writeData(wifiData);
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