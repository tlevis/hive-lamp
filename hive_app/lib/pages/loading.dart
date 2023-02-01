import 'dart:convert';
import 'dart:ffi';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hiveapp/services/transition.dart';
import 'package:hiveapp/pages/home.dart';
import 'package:hiveapp/pages/connectToDevice.dart';

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
      Navigator.pushReplacementNamed(context, '/connect');//, arguments: connection);
    }
    else
    {
//      Navigator.of(context)
//          .pushReplacement(Transition.getFadeTransition(LoginScreen()));
    }
  }

  loadingDone() async {
     var duration = new Duration(seconds: 1);
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
