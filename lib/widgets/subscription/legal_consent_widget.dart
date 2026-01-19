import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalConsentWidget extends StatefulWidget {
  final Function(bool) onConsentChanged;

  const LegalConsentWidget({super.key, required this.onConsentChanged});

  @override
  State<LegalConsentWidget> createState() => _LegalConsentWidgetState();
}

class _LegalConsentWidgetState extends State<LegalConsentWidget> {
  bool _isChecked = false;

  void _handleChanged(bool? value) {
    setState(() {
      _isChecked = value ?? false;
    });
    widget.onConsentChanged(_isChecked);
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _isChecked,
          onChanged: _handleChanged,
          activeColor: Colors.indigoAccent,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  const TextSpan(text: 'Ödemeyi onaylayarak, '),
                  _buildLink('Mesafeli Satış Sözleşmesi', 'https://example.com/distance-sales'),
                  const TextSpan(text: ' ve '),
                  _buildLink('Ön Bilgilendirme Formu', 'https://example.com/pre-info'),
                  const TextSpan(text: '\'nu okuduğumu ve onayladığımı kabul ediyorum.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _buildLink(String text, String url) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.blueAccent,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.bold,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
    );
  }
}
