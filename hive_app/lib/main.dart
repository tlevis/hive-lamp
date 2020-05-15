import 'package:flutter/material.dart';
import 'package:flutter/services.dart' ;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hiveapp/pages/home.dart';
import 'package:hiveapp/pages/loading.dart';
import 'package:hiveapp/pages/connect.dart';

void main() {
  //final config = await AppConfig.forEnvironment('prod');
  runApp(MyApp()); // config: config
}

class MyApp extends StatelessWidget {
  //final AppConfig config;

  //MyApp({Key key, this.config}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.dark(),
          accentColor: Colors.green,
          fontFamily: 'Hind',
          textTheme: TextTheme(
            body1: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        darkTheme: ThemeData.dark(),
        routes: {
          '/': (context) => Loading(), //FindDevicesScreen(),
          '/home': (context) => Home(),
        },
        localizationsDelegates: [
          // ... app-specific localization delegate[s] here
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('en'),
          // English
          const Locale('he'),
          // Hebrew
          const Locale.fromSubtags(languageCode: 'zh'),
          // Chinese *See Advanced Locales below*
          // ... other locales the app supports
        ],
      ),
    );
  }
}





