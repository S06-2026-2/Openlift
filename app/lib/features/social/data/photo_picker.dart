// Escolha de foto na galeria (image_picker), na web e no APK.
//
// O app não lê nem manda localização: a API recodifica a foto e descarta o
// EXIF, inclusive o GPS (ADR-0012, RNF-12). Já pedimos a foto reduzida para
// subir menos dados.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class PhotoPicker {
  const PhotoPicker();

  /// A foto escolhida, ou `null` se a pessoa cancelou.
  Future<PickedPhoto?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
  }
}

/// Override nos testes (sem plugin de plataforma).
final photoPickerProvider = Provider<PhotoPicker>((ref) => const PhotoPicker());
