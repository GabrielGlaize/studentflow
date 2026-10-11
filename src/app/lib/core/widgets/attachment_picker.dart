import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Fichier joint à un document, copié dans le dossier de l'app.
class PickedAttachment {
  const PickedAttachment({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.isPhoto,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final bool isPhoto;
}

enum _PhotoSource { camera, gallery }

/// Choix d'un fichier (PDF, Word…) ou d'une photo (appareil ou galerie).
///
/// Les sélecteurs renvoient un fichier temporaire que le système efface : on le
/// copie dans le dossier de l'app pour que le document reste consultable.
abstract final class AttachmentPicker {
  static const _folder = 'documents';

  static Future<PickedAttachment?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    final file = result?.files.firstOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;
    return _store(path, file.name, isPhoto: false);
  }

  /// Propose l'appareil photo ou la galerie, puis renvoie la photo choisie.
  static Future<PickedAttachment?> pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('attachment-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            subtitle: const Text('Pratique pour un document papier.'),
            onTap: () => Navigator.pop(context, _PhotoSource.camera),
          ),
          ListTile(
            key: const ValueKey('attachment-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choisir dans mes photos'),
            onTap: () => Navigator.pop(context, _PhotoSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (source == null) return null;

    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: source == _PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Lisible pour un document, sans peser des dizaines de Mo.
        maxWidth: 2400,
        imageQuality: 85,
      );
    } on Exception {
      // Accès refusé ou pas d'appareil photo (simulateur).
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                source == _PhotoSource.camera
                    ? 'Appareil photo indisponible. Autorise-le dans les réglages du téléphone.'
                    : 'Photos indisponibles. Autorise l’accès dans les réglages du téléphone.',
              ),
            ),
          );
      }
      return null;
    }
    if (photo == null) return null;

    final name = source == _PhotoSource.camera
        ? 'Photo du ${_stamp(DateTime.now())}.jpg'
        : photo.name;
    return _store(photo.path, name, isPhoto: true);
  }

  /// Chemin actuel d'un fichier enregistré : sur iOS, le dossier de l'app
  /// change de chemin absolu à chaque mise à jour.
  static Future<String?> resolve(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) return null;
    if (await File(storedPath).exists()) return storedPath;

    final marker = '/$_folder/';
    final index = storedPath.lastIndexOf(marker);
    if (index < 0) return null;
    final root = (await getApplicationDocumentsDirectory()).path;
    final moved = '$root$marker${storedPath.substring(index + marker.length)}';
    return await File(moved).exists() ? moved : null;
  }

  static Future<PickedAttachment> _store(
    String sourcePath,
    String name, {
    required bool isPhoto,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/$_folder');
    await folder.create(recursive: true);

    final safeName = name.replaceAll(RegExp(r'[/\\:]'), '_');
    final target = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    final copy = await File(sourcePath).copy(target.path);
    return PickedAttachment(
      name: name,
      path: copy.path,
      sizeBytes: await copy.length(),
      isPhoto: isPhoto,
    );
  }

  static String _stamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}-${two(value.month)}-${value.year} ${two(value.hour)}h${two(value.minute)}';
  }
}

/// Deux boutons côte à côte : joindre un fichier ou une photo.
class AttachmentButtons extends StatelessWidget {
  const AttachmentButtons({
    required this.attachment,
    required this.onPicked,
    this.allowedExtensions,
    super.key,
  });

  final PickedAttachment? attachment;
  final ValueChanged<PickedAttachment> onPicked;
  final List<String>? allowedExtensions;

  @override
  Widget build(BuildContext context) {
    final picked = attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('attachment-file-button'),
                onPressed: () => _pick(
                  context,
                  AttachmentPicker.pickFile(
                    allowedExtensions: allowedExtensions,
                  ),
                ),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Fichier'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('attachment-photo-button'),
                onPressed: () =>
                    _pick(context, AttachmentPicker.pickPhoto(context)),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photo'),
              ),
            ),
          ],
        ),
        if (picked != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                picked.isPhoto ? Icons.image_outlined : Icons.attach_file,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  picked.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    Future<PickedAttachment?> picking,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final PickedAttachment? picked;
    try {
      picked = await picking;
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Impossible de joindre ce fichier.')),
          );
      }
      return;
    }
    if (picked != null) onPicked(picked);
  }
}
