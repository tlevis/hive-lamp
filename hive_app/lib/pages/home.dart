import 'dart:convert' as convert;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:hexcolor/hexcolor.dart';
import 'package:polygon_clipper/polygon_clipper.dart';
import 'package:polygon_clipper/polygon_border.dart';




class ExpandedSection extends StatefulWidget {

  final Widget child;
  final bool expand;
  ExpandedSection({this.expand = false, this.child});

  @override
  _ExpandedSectionState createState() => _ExpandedSectionState();
}

class _ExpandedSectionState extends State<ExpandedSection> with SingleTickerProviderStateMixin {
  AnimationController expandController;
  Animation<double> animation;

  @override
  void initState() {
    super.initState();
    prepareAnimations();
    runExpandCheck();
  }

  ///Setting up the animation
  void prepareAnimations() {
    expandController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500)
    );
    animation = CurvedAnimation(
      parent: expandController,
      curve: Curves.fastOutSlowIn,
    );
  }

  void runExpandCheck() {
    if(widget.expand) {
      expandController.forward();
    }
    else {
      expandController.reverse();
    }
  }

  @override
  void didUpdateWidget(ExpandedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    runExpandCheck();
  }

  @override
  void dispose() {
    expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
        axisAlignment: 1.0,
        sizeFactor: animation,
        child: widget.child
    );
  }
}


class Home extends StatefulWidget {
  final BluetoothDevice device;
  Home({Key key, @required this.device}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {

  TabController _tabController;

  Color _programColor1 = Colors.limeAccent;
  String _selectedProgram = 'Solid';

  var _program = {
    "Solid": {
      "Name": "Solid",
      "Color": "FF0000",
      "Executed": false
    },
    "Cylon": {
      "Name": "Cylon",
      "Color": "F00FF0",
      "Delay": 50,
      "Duration": 0,
      "Position": 0,
      "Direction": 1,
      "Brightness": 0,
      "MaxBrightness": 127
    },
    "Breathing": {
      "Name": "Breathing",
      "Color": "00420e",
      "Delay": 10,
      "Duration": 0,
      "Direction": 1,
      "Brightness": 0,
      "MaxBrightness": 250
    },
    "Rainbow": {
      "Name": "Rainbow",
      "Delay": 20,
      "Duration": 0,
      "Position": 255,
      "Brightness": 0,
      "MaxBrightness": 127
    }
  };

  // Check firmware for complete UUIDs list
  final String controllerHiveServiceUUID = "02675cf9-f599-4720-840d-6c0ecc607112";
  final String controllerHiveNanoServiceUUID = "9df5a533-9cce-4f9f-8469-b9eab92b1992";
  final String programCharacteristicUUID = "ec65a4a3-761b-432c-af88-2cee26319b47";
  final String firmwareCharacteristicUUID = "fa8f59be-4546-4f26-ba4d-1b9206ddf222";
  final String wifiSetterCharacteristicUUID = "96c7f61b-770a-4e49-b7df-41e838b7c63f";
  final String wifiInfoCharacteristicUUID = "7bbf95cc-3972-4914-9709-055bd28b930e";

  final String batteryServiceUUID = "0000180f-0000-1000-8000-00805f9b34fb";
  final String batteryCharacteristicUUID = "00002a19-0000-1000-8000-00805f9b34fb";

  BluetoothDevice _hiveDevice;
  BluetoothCharacteristic _programCharacteristic;
  BluetoothCharacteristic _batteryCharacteristic;
  BluetoothCharacteristic _firmwareCharacteristic;
  BluetoothCharacteristic _wifiSetterCharacteristic;
  BluetoothCharacteristic _wifiInfoCharacteristic;

  StreamSubscription<List<int>> _notifyBatterySubscription;

  int _breathingSpeed = 2;
  int _rainbowSpeed = 2;
  int _cylonSpeed = 50;
  int _batteryLevel = 0;

  String _firmwareVersion = "";
  String _latestVersion = "";
  String _versionText = "";
  bool _checkingForFirmware = false;

  bool _isNano = false;
  bool _initiatedBack = false;
  bool _deviceConnected = false;

  TextEditingController _wifiSSIDController = TextEditingController();
  TextEditingController _wifiPasswordController = TextEditingController();
  String _deviceIp = "";

  void checkForUpdate() async {
    setState(() {
      _checkingForFirmware = true;
    });
    http.get("https://hive.tovilevis.com/latest.txt").then((response) => {
      if (response.statusCode == 200) {
          setState(() {
            _latestVersion = response.body;
            _checkingForFirmware = false;
            _versionText = ((_latestVersion == _firmwareVersion) && (_latestVersion.isNotEmpty)) ? 'Your firmware is up to date' : 'New firmware is available: ' + _latestVersion ;
          })
      }
    }).catchError((e) {
      setState(() {
        _checkingForFirmware = false;
        _versionText = "Error: Cannot get latest version from cloud";
      });
    });
  }

  void saveWiFiInfo() {
    String wifi = convert.jsonEncode({ "Command": "NETWORK", "Value": { "SSID": _wifiSSIDController.text, "PASSWORD": _wifiPasswordController.text} });
    writeData(_wifiSetterCharacteristic, wifi);

  }

  @override
  void setState(fn) {
    if(mounted) {
      super.setState(fn);
    }
  }

  void changeColor(Color color) {
    String stringColor = color.toString().split('(0x')[1].split(')')[0].substring(2);
    if (_selectedProgram != "Rainbow") {
      _program[_selectedProgram]["Color"] = stringColor;
    }
    setState(() => _programColor1 = color);
  }

  discoverServices() async {
    if (_hiveDevice == null) {
      return;
    }

    List<BluetoothService> services = await _hiveDevice.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString() == controllerHiveServiceUUID) {
        setState(() {
          _isNano = false;
        });
        service.characteristics.forEach((characteristics) {
          if (characteristics.uuid.toString() == programCharacteristicUUID) {
            _programCharacteristic = characteristics;
          }
        });
      } else if (service.uuid.toString() == controllerHiveNanoServiceUUID) {
        setState(() {
          _isNano = true;
        });
        service.characteristics.forEach((characteristics) {
          if (characteristics.uuid.toString() == programCharacteristicUUID) {
            _programCharacteristic = characteristics;
            _programCharacteristic.read().then((value) => setState(() {
              applyRemoteProgramSettings(value);
            }));
          } else if (characteristics.uuid.toString() == firmwareCharacteristicUUID) {
            _firmwareCharacteristic = characteristics;
            _firmwareCharacteristic.read().then((value) => setState(() { _firmwareVersion = String.fromCharCodes(value); }));
          } else if (characteristics.uuid.toString() == wifiSetterCharacteristicUUID) {
            _wifiSetterCharacteristic = characteristics;
          } else if (characteristics.uuid.toString() == wifiInfoCharacteristicUUID) {
            _wifiInfoCharacteristic = characteristics;
            _wifiInfoCharacteristic.read().then((value) => setState(() {
              String val = String.fromCharCodes(value);
              var info = val.split(',');
              _deviceIp = info[0];
              _wifiSSIDController.text = info[1];
              _wifiPasswordController.text = info[2];
            }));
          }
        });
      } else if (service.uuid.toString() == batteryServiceUUID) {
        service.characteristics.forEach((characteristics) async {
          if (characteristics.uuid.toString() == batteryCharacteristicUUID) {
            _batteryCharacteristic = characteristics;
            await _batteryCharacteristic.setNotifyValue(true);
            _notifyBatterySubscription = _batteryCharacteristic.value.listen((value) {
              if (value.isNotEmpty) {
                setState(() {
                  _batteryLevel = value[0];
                });
              }
            });
          }
        });
      }
    });
  }

  disconnectFromDeivce() async {
    if (_hiveDevice == null) {
      return;
    }

    setState(() {
      _initiatedBack = true;
    });

    _programCharacteristic = null;

    _notifyBatterySubscription?.cancel();
    _notifyBatterySubscription = null;
    _batteryCharacteristic = null;
    _hiveDevice.disconnect();
  }

  writeData(BluetoothCharacteristic btChar, String data) async {
    if (btChar == null) return;
    List<int> bytes = convert.utf8.encode(data);
    print("Sending: $data");
    await btChar.write(bytes);
  }


  int _selectedIndex = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _tabController.animateTo(index);
  }

  void _showAlert(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: Text("Lamp was disconnected"),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the alert
                Navigator.of(context).pop(); // Go to connection screen
              },
            )],
        )
    );
  }

  initAsync() async {

    _initiatedBack = false;
    _hiveDevice = widget.device;
    _hiveDevice.state.listen((event) {
      if (!_initiatedBack && event == BluetoothDeviceState.disconnected) {
        _showAlert(context);
        //doBack();
      }
    });
    Future.delayed(const Duration(seconds: 1), () {
      discoverServices();
    });
  }

  @override
  void initState() {
    super.initState();
    initAsync();
    _tabController = new TabController(vsync: this, length: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deviceConnected = false;
    super.dispose();
  }

  Future<bool> doBack() {
    disconnectFromDeivce();
    Navigator.of(context).pop(true);
    return Future<bool>.value(true);
  }

  void applyRemoteProgramSettings(value) {
    String prog = String.fromCharCodes(value);
    setState(() {
      var jsonProg = convert.jsonDecode(prog);
      _program[jsonProg["Name"]] = jsonProg;
      _selectedProgram = jsonProg["Name"];
      if (jsonProg["Name"] != "Rainbow")
        _programColor1 = Hexcolor("#" + jsonProg["Color"]);

      if (_selectedProgram == "Rainbow") {
        _rainbowSpeed = _program["Rainbow"]["Delay"];
      } else if (_selectedProgram == "Breathing") {
        _breathingSpeed = _program["Breathing"]["Delay"];
      } else if (_selectedProgram == "Cylon") {
        _cylonSpeed = _program["Cylon"]["Delay"];
      }
      _deviceConnected = true;
    });
  }

  void applyProgramSettings() {
    if (_selectedProgram == "Rainbow") {
      _program["Rainbow"]["Delay"] = _rainbowSpeed;
    } else if (_selectedProgram == "Breathing") {
      _program["Breathing"]["Delay"] = _breathingSpeed;
    } else if (_selectedProgram == "Cylon") {
      _program["Cylon"]["Delay"] = _cylonSpeed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(


      onWillPop: doBack,
      child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.black,
            title: Image.asset('assets/images/logo.png',
                fit: BoxFit.fitHeight, height: 32),
          ),

        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          iconSize: 40,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: ImageIcon(AssetImage('assets/images/sliders.png')),
              label: 'Control',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.green,
          onTap: _onItemTapped,
        ),

          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(new FocusNode());
            },
            child: SafeArea(
                child: TabBarView(
                    physics: NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      new Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/images/background.png"),
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                        //color: Colors.white24,
                        child: Row(
                          children: <Widget>[
                            Visibility(
                              visible: !_deviceConnected,
                              child: Expanded(
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                    CircularProgressIndicator(),
                                    Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Text("Connecting, please wait...", style: TextStyle(fontSize: 16),),
                                    )
                                  ]),
                              ),
                            ),
                            Visibility(
                              visible: _deviceConnected,
                              child: Expanded(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(10, 40, 0, 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Row(
                                        children: [
                                          Text("Select active program for the lamp:", style: TextStyle(fontSize: 16))
                                        ],
                                      ),
                                      Row(
                                        children: <Widget>[
                                          Padding(
                                            padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                                            child: Text("Program:", style: TextStyle(fontSize: 16)),
                                          ),
                                          DropdownButton<String>(
                                            value: _selectedProgram,
                                            items: <String>['Solid', 'Cylon', 'Breathing', 'Rainbow'].map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value),
                                              );
                                            }).toList(),
                                            onChanged: (p) {
                                              setState(() {
                                                _selectedProgram = p;
                                                _programColor1 = Hexcolor("#" +_program[p]["Color"]);
                                              });
                                            },
                                          )
                                        ],
                                      ),
                                      Visibility(
                                        visible:  _selectedProgram != "Rainbow",
                                        child: GestureDetector(
                                          onTap:  () {
                                            showDialog (
                                              context: context,
                                              builder: (BuildContext context) {
                                              return AlertDialog(
                                                titlePadding: const EdgeInsets.all(0.0),
                                                contentPadding: const EdgeInsets.all(0.0),
                                                content: SingleChildScrollView(
                                                  child: ColorPicker(

                                                    pickerColor: _programColor1,
                                                    onColorChanged: changeColor,
                                                    colorPickerWidth: 300.0,
                                                    pickerAreaHeightPercent: 0.7,
                                                    enableAlpha: false,
                                                    displayThumbColor: true,
                                                    showLabel: true,
                                                    paletteType: PaletteType.hsv,
                                                    pickerAreaBorderRadius: const BorderRadius.only(
                                                      topLeft: const Radius.circular(2.0),
                                                      topRight: const Radius.circular(2.0),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );},
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.all(
                                                Radius.circular(10.0),
                                              ),
                                              color: _programColor1,
                                            ),
                                            height: 50,
                                            width: 50,
                                          ),
                                        ),
                                      ),
                                      Visibility(
                                          visible: _selectedProgram == "Rainbow",
                                          child: Text("Pattern Speed:", style: TextStyle(fontSize: 16))
                                      ),
                                      Visibility(
                                        visible: _selectedProgram == "Rainbow",
                                        child: Row(
                                            mainAxisAlignment: MainAxisAlignment.start,

                                            children: [
                                              Flexible(flex: 1, child: Text("Fast")),
                                              Flexible(
                                                fit: FlexFit.tight,
                                                flex: 10,
                                                child: CupertinoSlider(
                                                    value: min(30, max(1, _rainbowSpeed.toDouble())),
                                                    min: 1,
                                                    max: 30,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _rainbowSpeed = value.toInt();
                                                      });
                                                    }
                                                ),
                                              ),
                                              Flexible(flex: 1, child: Text("Slow")),
                                            ],
                                        ),
                                      ),
                                      Visibility(
                                          visible: _selectedProgram == "Breathing",
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                                            child: Text("Breathing Speed:", style: TextStyle(fontSize: 16)),
                                          )
                                      ),
                                      Visibility(
                                        visible: _selectedProgram == "Breathing",
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,

                                          children: [
                                            Flexible(flex: 1, child: Text("Fast")),
                                            Flexible(
                                              fit: FlexFit.tight,
                                              flex: 10,
                                              child: CupertinoSlider(
                                                  value: min(20, max(1, _breathingSpeed.toDouble())),
                                                  min: 1,
                                                  max: 20,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _breathingSpeed = value.toInt();
                                                    });
                                                  }
                                              ),
                                            ),
                                            Flexible(flex: 1, child: Text("Slow")),
                                          ],
                                        ),
                                      ),
                                      Visibility(
                                          visible: _selectedProgram == "Cylon",
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                                            child: Text("Cylon Speed:", style: TextStyle(fontSize: 16)),
                                          )
                                      ),
                                      Visibility(
                                        visible: _selectedProgram == "Cylon",
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,

                                          children: [
                                            Flexible(flex: 1, child: Text("Fast")),
                                            Flexible(
                                              fit: FlexFit.tight,
                                              flex: 10,
                                              child: CupertinoSlider(
                                                  value: min(100, max(1, _cylonSpeed.toDouble())),
                                                  min: 1,
                                                  max: 100,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _cylonSpeed = value.toInt();
                                                    });
                                                  }
                                              ),
                                            ),
                                            Flexible(flex: 1, child: Text("Slow")),
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        child: Container(),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                                        child: ButtonTheme(
                                          height: 120,
                                          buttonColor: Colors.green,
                                          child: RaisedButton(
                                            shape: PolygonBorder(
                                              sides: 6,
                                              borderRadius: 0.0, // Default 0.0 degrees
                                              rotate: 90.0, // Default 0.0 degrees
                                              border: BorderSide.none, // Default BorderSide.none
                                            ),
                                            onPressed: (){
                                              applyProgramSettings();
                                              String prog = convert.jsonEncode({ "Command": "PROGRAM", "Value": _program[_selectedProgram]});
                                              writeData(_programCharacteristic, prog);
                                              },
                                            child: Text(
                                                'Apply',
                                                style: TextStyle(fontSize: 20)
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ),
                            ),
                          ],
                        ),
                      ),
                      new Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("assets/images/background.png"),
                              fit: BoxFit.fitHeight,
                            ),
                          ),
                          //color: Colors.white24,
                          child:
                            Padding(
                              padding: EdgeInsets.fromLTRB(10, 10, 0, 0),
                              child: Column (
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text("Battery percentage: $_batteryLevel%", style: TextStyle(fontSize: 16)),
                                        )
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text("Firmware Version: $_firmwareVersion (Hive${_isNano ? ' Nano' : ''})", style: TextStyle(fontSize: 16)),
                                        )
                                      ],
                                    ),
                                    Row(

                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(_versionText, style: TextStyle(fontSize: 16)),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          RaisedButton(
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10.0),
                                            ),
                                            onPressed: (_deviceIp != "" && _deviceIp != "0.0.0.0") ? (_checkingForFirmware ? null : ()=> checkForUpdate()) : null,
                                            child: Text(
                                                _checkingForFirmware ? 'Checking...' : 'Check for Update',
                                                style: TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Visibility(
                                      visible: (_deviceIp == "" || _deviceIp == "0.0.0.0"),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(8.0, 0.0, 0, 2.0),
                                        child: Text("Notice: Device must be connected to Wi-Fi network",
                                          style: TextStyle(color: Colors.orange)),
                                      ),
                                    ),
                                    Divider(),
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text("Connect Lamp To Wi-Fi Network:"),
                                        )
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            flex: 2,
                                            child: TextField(
                                              obscureText: false,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                labelText: 'SSID',
                                              ),
                                              controller: _wifiSSIDController,
                                              style: Theme.of(context).textTheme.bodyText2,
                                            ),
                                          ),
                                          Flexible(
                                            flex: 0,
                                            child: Text(" ")
                                          ),
                                          Flexible(
                                            flex: 2,
                                            child: TextField(
                                              obscureText: true,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                labelText: 'Password',
                                              ),
                                              controller: _wifiPasswordController,
                                              style: Theme.of(context).textTheme.bodyText2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text("Device ip: $_deviceIp", style: TextStyle(fontSize: 16)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          RaisedButton(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10.0),
                                            ),
                                            onPressed: saveWiFiInfo,
                                            child: Text("Save",style: TextStyle(fontSize: 20),
                                            ),
                                          ),

                                        ],
                                      ),
                                    )

                              ]
                          ),
                            )
                      ),
                    ]
                )
            ),
          )
      ),
    );}
}