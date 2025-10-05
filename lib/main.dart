import 'package:flutter/material.dart';
import 'package:lawdesk/my_custom_form.dart';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LawDesk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar:  AppBar(
          title: Text('Login'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: MyCustomForm(), // TODO: Implemntt a general home screen that checks if user is logged in or not
        ),
      ),
    );
  }
}

