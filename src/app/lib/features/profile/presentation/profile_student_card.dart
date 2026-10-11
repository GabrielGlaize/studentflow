part of 'profile_page.dart';

/// Carte étudiante : une simple photo, copiée dans le stockage de l'app et
/// affichée en plein écran sans quitter Swikko.
class _StudentCardSection extends StatelessWidget {
  const _StudentCardSection({
    required this.document,
    required this.onImport,
    required this.onOpen,
    required this.onDelete,
    required this.onRecrop,
  });

  final CompanyDocument? document;
  final VoidCallback onImport;
  final VoidCallback? onRecrop;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final card = document;

    if (card == null) {
      return ProtoCard(
        onTap: onImport,
        child: Row(
          children: [
            ProtoIconBox(
              icon: Icons.add_photo_alternate_outlined,
              backgroundColor: context.sfPersonalSoft,
              foregroundColor: context.sfPersonal,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajouter ma carte étudiante',
                    style: TextStyle(
                      color: context.sfText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const ProtoMutedText(
                    'Choisis une photo et cadre-la : elle reste sur ton téléphone, prête à montrer.',
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.sfChevron),
          ],
        ),
      );
    }

    return ProtoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Carte étudiante',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const ProtoVisibilityChip(shared: false),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            key: const ValueKey('student-card-thumbnail'),
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.586, // format carte bancaire
                child: _StudentCardImage(
                  storedPath: card.filePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Afficher'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                key: const ValueKey('student-card-recrop'),
                tooltip: 'Recadrer',
                onPressed: onRecrop,
                icon: const Icon(Icons.crop),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                tooltip: 'Remplacer la photo',
                onPressed: onImport,
                icon: const Icon(Icons.photo_library_outlined),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                tooltip: 'Retirer la carte',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentCardImage extends StatefulWidget {
  const _StudentCardImage({required this.storedPath, required this.fit});

  final String? storedPath;
  final BoxFit fit;

  @override
  State<_StudentCardImage> createState() => _StudentCardImageState();
}

class _StudentCardImageState extends State<_StudentCardImage> {
  late Future<File?> _file = StudentCardStore.resolve(widget.storedPath);

  @override
  void didUpdateWidget(covariant _StudentCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedPath != widget.storedPath) {
      _file = StudentCardStore.resolve(widget.storedPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return ColoredBox(
            color: context.sfSoftCard,
            child: Center(
              child: snapshot.connectionState == ConnectionState.done
                  ? const ProtoMutedText('Photo introuvable : remplace-la.')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return Image.file(file, fit: widget.fit);
      },
    );
  }
}

/// Plein écran avec zoom au pincement, pour montrer la carte à l'accueil.
class _StudentCardViewer extends StatelessWidget {
  const _StudentCardViewer({required this.storedPath});

  final String? storedPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Carte étudiante'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: _StudentCardImage(
              storedPath: storedPath,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Copie la photo choisie dans le dossier de l'app : le fichier renvoyé par le
/// sélecteur est temporaire et disparaît. On enregistre un chemin relatif, car
/// le dossier de l'app change de chemin absolu à chaque mise à jour iOS.
abstract final class StudentCardStore {
  static const _folder = 'student-card';

  /// Choisit une photo, la fait recadrer au format carte puis l'enregistre.
  /// L'original est gardé à côté pour pouvoir recadrer plus tard sans perte.
  static Future<String?> importPhoto(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    final sourcePath = result?.files.firstOrNull?.path;
    if (sourcePath == null || !context.mounted) return null;

    final original = await File(sourcePath).readAsBytes();
    if (!context.mounted) return null;
    return _cropAndStore(context, original);
  }

  /// Recadre à nouveau la carte, à partir de la photo d'origine si elle existe.
  static Future<String?> recrop(
    BuildContext context,
    String? storedPath,
  ) async {
    final source =
        await resolve(_originalPathOf(storedPath)) ?? await resolve(storedPath);
    if (source == null || !context.mounted) return null;

    final original = await source.readAsBytes();
    if (!context.mounted) return null;
    return _cropAndStore(context, original);
  }

  static Future<String?> _cropAndStore(
    BuildContext context,
    Uint8List original,
  ) async {
    final cropped = await ImageCropPage.open(
      context,
      bytes: original,
      title: 'Cadrer la carte',
    );
    if (cropped == null) return null;

    final root = (await getApplicationDocumentsDirectory()).path;
    await Directory('$root/$_folder').create(recursive: true);
    final relativePath =
        '$_folder/carte-${DateTime.now().millisecondsSinceEpoch}.png';
    await File('$root/$relativePath').writeAsBytes(cropped, flush: true);
    await File(
      '$root/${_originalPathOf(relativePath)}',
    ).writeAsBytes(original, flush: true);
    return relativePath;
  }

  /// « carte-123.png » → « carte-123-original » (format d'origine conservé).
  static String? _originalPathOf(String? storedPath) {
    final path = storedPath?.trim();
    if (path == null || path.isEmpty || !path.endsWith('.png')) return null;
    return '${path.substring(0, path.length - 4)}-original';
  }

  static Future<File?> resolve(String? storedPath) async {
    final path = storedPath?.trim();
    if (path == null || path.isEmpty) return null;

    final file = path.startsWith('/')
        ? File(path)
        : File('${(await getApplicationDocumentsDirectory()).path}/$path');
    return await file.exists() ? file : null;
  }

  static Future<void> delete(String? storedPath) async {
    for (final path in [storedPath, _originalPathOf(storedPath)]) {
      try {
        await (await resolve(path))?.delete();
      } on FileSystemException {
        // Le fichier a déjà disparu : rien à faire.
      }
    }
  }
}
