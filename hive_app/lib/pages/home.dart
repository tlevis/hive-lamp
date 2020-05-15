import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hiveapp/services/wsHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  TabController _tabController;

  bool _lampIsConnected = false;
  String _lampFirmware = "";
  Color _programColor1 = Colors.limeAccent;
  Color _programColor2 = Colors.yellow;
  double  _lampOpacity = 1.0;
  Timer _lampFadeTime;
  String _selectedProgram = 'Solid';

  void changeColor(Color color) => setState(() => _programColor1 = color);

  int _selectedIndex = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _tabController.animateTo(index);
  }

  void _onMessageReceived(serverMessage){
    Map message = json.decode(serverMessage);
    print(" ---------- NEW MESSAGE ---------- ");
    print(message);

    if (message.containsKey("FIRMWARE")) {
      setState(() {
        _lampFirmware = message["FIRMWARE"];
      });
      print("Firmware version: ${message["FIRMWARE"]}");
    }
    print(" ---------- NEW MESSAGE ---------- ");
  }

  void fadeLamp(duration) {
    _lampFadeTime = Timer.periodic(duration, (Timer t) => {
      if (_lampOpacity > 0.0) {
        setState((){
          _lampOpacity = 0.0;
        })
      }
      else
        {
          setState((){
            _lampOpacity = 1.0;
          })
        }
    });
  }

  initAsync() async {
    final SharedPreferences sPref = await SharedPreferences.getInstance();
    if (sPref.getString("lamp-ip").isNotEmpty) {
      try
      {
        sockets.initCommunication(sPref.getString("lamp-ip"), 5656);
        sockets.addListener(_onMessageReceived);
        setState(() {
          _lampIsConnected = true;
        });
      }
      catch (err)
      {
        print("Cannot connect to device ws server");
      }

    }


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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey[800],
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible (
                child: Row (
                  children: <Widget>[],
                ),
                fit: FlexFit.tight,
                flex: 1,
              ),
              Flexible (
                //padding: EdgeInsets.fromLTRB(32, 0, 0, 0),
                flex: 2,
                fit: FlexFit.tight,
                child: Image.asset('assets/images/logo.png',
                  fit: BoxFit.fitHeight, height: 32),
              ),
              Flexible (
                child: Row (
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[],
                ),
                fit: FlexFit.tight,
                flex: 1,
              ),
            ],
          ),
        ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        iconSize: 40,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage('assets/images/sliders.png')),
            title: Text('Control'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            title: Text('Settings'),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),

        body: SafeArea(
            child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  new Container(
                    color: Colors.white24,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(10, 40, 0, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                                      child: Text("Program:"),
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
                                        });
                                      },
                                    )
                                  ],
                                ),
                                Visibility(
                                  visible:  _selectedProgram == "Solid"  || _selectedProgram == "Breathing" ||  _selectedProgram == "Cylon" ,
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
                                              enableAlpha: true,
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
                                Expanded(
                                  child: Container(),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                                  child: RaisedButton(
                                    onPressed: (){
                                      if (_lampFadeTime != null && _lampFadeTime.isActive) {
                                        _lampFadeTime.cancel();
                                        setState(() {
                                          _lampOpacity = 1.0;
                                        });
                                      } else {
                                        fadeLamp(Duration(seconds: 1));
                                      }

                                      },
                                    child: Text(
                                        'Apply',
                                        style: TextStyle(fontSize: 20)
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ),
                        Expanded(
                          child: Container(
                            height: 550,
                            child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
                                    child: AnimatedOpacity(
                                      opacity: _lampOpacity,
                                      duration: Duration(seconds: 1),
                                      child: Container(
                                        height: 510,
                                        width: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _selectedProgram == "Rainbow" ? Colors.white : _programColor1,
                                              blurRadius: 40.0,
                                              spreadRadius: -5.0,
                                              offset: Offset(0.0, 0)
                                          )],
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(5.0),
                                          ),
                                          color: _selectedProgram == "Solid"  || _selectedProgram == "Breathing" ? _programColor1 : null,
                                          gradient: _selectedProgram == "Rainbow" ? LinearGradient (
                                            colors: [
                                              Colors.red,
                                              Colors.yellow,
                                              Colors.green,
                                              Colors.blue,
                                            ],
                                            //stops: [0.1, 0.8, 0.1],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter
                                          ) : null
                                        ),
                                      ),
                                    ),
                                  ),
                                  Image(
                                    image: AssetImage('assets/images/lamp-transparent.png'),
                                    //fit: BoxFit,
                                  ),
                                ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  new Container(
                    color: Colors.red,
                  ),
                ]
            )
        )
    );}
}