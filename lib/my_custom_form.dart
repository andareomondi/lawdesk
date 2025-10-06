import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';

class MyCustomForm extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  
  const MyCustomForm({super.key, required this.onLoginSuccess}); 

  @override
  MyCustomFormState createState() {
    return MyCustomFormState();
  }
}

class MyCustomFormState extends State<MyCustomForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailcontroller = TextEditingController();
  String get _textValue => _emailcontroller.text;

  final TextEditingController _passwordcontroller = TextEditingController();
  String get _passwordValue => _passwordcontroller.text;

  @override 
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _emailcontroller,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Enter your email',
              prefixIcon: const Icon(Icons.email),
              suffixIcon: IconButton(
                onPressed: () {
                  _emailcontroller.clear();
                }, 
                icon: const Icon(Icons.clear)
              )
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some text';
              } else if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _passwordcontroller,
            decoration: InputDecoration(
              labelText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                onPressed: () {
                  _passwordcontroller.clear();
                }, 
                icon: const Icon(Icons.clear)
              )
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some text';
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Processing Data')),
                  );
                  print("Your name is $_textValue and password is $_passwordValue");
                  widget.onLoginSuccess();
                }
              },
              child: const Text('Submit'),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset coming soon!')),
              );
            },
            child: const Text('Forgot Password?'),
          ),
        ],
      ),
    );
  }
}
