import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_easy/constants.dart';

class OtpInputWidget extends StatefulWidget {
  final Function(String) onSubmit;
  // ignore: use_super_parameters
  const OtpInputWidget({Key? key, required this.onSubmit}) : super(key: key);

  @override
  State<OtpInputWidget> createState() => _OtpInputWidgetState();
}

class _OtpInputWidgetState extends State<OtpInputWidget> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }
    if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  void _submitOtp() {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      widget.onSubmit(otp);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter 6 digit OTP")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Enter your OTP here",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 45,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                maxLength: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _onChanged(value, index),
                decoration: InputDecoration(
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        //retry timer
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Login",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
