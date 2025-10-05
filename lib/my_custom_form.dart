import 'package:flutter/material.dart';

class MyCustomForm extends StatefulWidget{
  const MyCustomForm({super.key}); 

  @override
  MyCustomFormState createState() {
    return MyCustomFormState();
  }
}

class MyCustomFormState extends State<MyCustomForm>{
  final _formKey = GlobalKey<FormState>();
  // get the value from the TextFormField
  final TextEditingController _emailcontroller = TextEditingController();
  // getting the value from the TextFormField
  String get _textValue => _emailcontroller.text;

  final TextEditingController _passwordcontroller = TextEditingController();

  String get _passwordValue => _passwordcontroller.text;

  @override 
  Widget build(BuildContext context){
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _emailcontroller,
            decoration: InputDecoration(
            labelText: 'Enter your email',
            prefixIcon: Icon(Icons.email),
            suffixIcon: IconButton(onPressed: (){
              _emailcontroller.clear();
              }, icon: Icon(Icons.clear))
            ),
            validator: (value){
              if(value == null || value.isEmpty){
                return 'Please enter some text';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _passwordcontroller,
            decoration: InputDecoration(
            labelText: 'Enter your password',
            prefixIcon: Icon(Icons.lock),
            suffixIcon: IconButton(onPressed: (){
              _passwordcontroller.clear();
              }, icon: Icon(Icons.clear))
            ),
            obscureText: true,
            validator: (value){
              if(value == null || value.isEmpty){
                return 'Please enter some text';
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: (){
                if(_formKey.currentState!.validate()){
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Processing Data')),
                  );
                  print("Your name is $_textValue and password is $_passwordValue");
                }
              },
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
