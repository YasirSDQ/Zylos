import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final title = "Kal Alaya Nivi Men Nime Mar Piyaa | Ahmed Nawaz Cheena Slowed & Reverb Song Use Headphones 🤍🤍";
  final safeTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim().replaceAll(RegExp(r'_+'), '_');
  
  print('safeTitle: "$safeTitle"');
  
  final asciiSafeTitle = safeTitle.replaceAll(RegExp(r'[^\x00-\x7F]'), '').replaceAll('?', '').trim();
  print('asciiSafeTitle: "$asciiSafeTitle"');
  
  final fileOnDisk = "Kal Alaya Nivi Men Nime Mar Piyaa _ Ahmed Nawaz Cheena Slowed & Reverb Song Use Headphones 🤍🤍.mp4";
  final baseName = p.basenameWithoutExtension(fileOnDisk);
  print('baseName: "$baseName"');
  
  final asciiBaseName = baseName.replaceAll(RegExp(r'[^\x00-\x7F]'), '').replaceAll('?', '').trim();
  print('asciiBaseName: "$asciiBaseName"');
  
  print('Exact Match: ${baseName == safeTitle}');
  print('ASCII Match: ${asciiBaseName == asciiSafeTitle}');
}
