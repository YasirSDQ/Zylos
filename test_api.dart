import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final body = {
    'url': 'https://www.youtube.com/watch?v=xayCR1KAg9g',
    'quality': '1080p',
    'title': 'Kal Alaya Nivi Men Nime Mar Piyaa | Ahmed Nawaz Cheena Slowed & Reverb Song Use Headphones 🤍🤍',
    'isAudioOnly': false,
    'isImage': false,
    'directUrl': '',
    'targetExt': ''
  };

  final response = await http.post(
    Uri.parse('http://127.0.0.1:7734/download'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  print('Status Code: ${response.statusCode}');
  print('Response Body: ${response.body}');
}
