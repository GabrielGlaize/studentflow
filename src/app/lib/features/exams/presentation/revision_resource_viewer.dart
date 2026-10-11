import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Icône, couleur et libellé d'une ressource selon son type.
class RevisionResourceLook {
  const RevisionResourceLook._(this.icon, this.label, this._light, this._dark);

  final IconData icon;
  final String label;
  final Color _light;
  final Color _dark;

  Color color(BuildContext context) => context.sfIsDark ? _dark : _light;

  static RevisionResourceLook of(RevisionResource resource) {
    if (resource.isLink) {
      final kind = resource.linkKind;
      return RevisionResourceLook._(
        linkIcon(kind),
        kind.label,
        kind == RevisionLinkKind.claude
            ? const Color(0xFFB2603F)
            : AppColors.shared,
        kind == RevisionLinkKind.claude
            ? const Color(0xFFE8A487)
            : AppColors.sky,
      );
    }

    return switch (resource.fileType) {
      'pdf' => const RevisionResourceLook._(
        Icons.picture_as_pdf_outlined,
        'PDF',
        Color(0xFFB4485A),
        Color(0xFFE5B9C3),
      ),
      'image' => const RevisionResourceLook._(
        Icons.image_outlined,
        'Image',
        AppColors.green,
        AppColors.mint,
      ),
      'html' => const RevisionResourceLook._(
        Icons.web_outlined,
        'Page web',
        Color(0xFF6F5A8E),
        Color(0xFFCDB8E6),
      ),
      _ => const RevisionResourceLook._(
        Icons.article_outlined,
        'Texte',
        Color(0xFF55698A),
        Color(0xFFBCCCE0),
      ),
    };
  }

  static IconData linkIcon(RevisionLinkKind kind) => switch (kind) {
    RevisionLinkKind.claude => Icons.auto_awesome,
    RevisionLinkKind.drive => Icons.description_outlined,
    RevisionLinkKind.video => Icons.play_circle_outline,
    RevisionLinkKind.github => Icons.code,
    RevisionLinkKind.notion => Icons.notes,
    RevisionLinkKind.quizlet => Icons.style_outlined,
    RevisionLinkKind.web => Icons.public,
  };
}

/// Ouvre une ressource : confirmation pour un lien externe, affichage dans
/// l'app pour un fichier (la page HTML tourne dans une vue isolée).
Future<void> openRevisionResource(
  BuildContext context,
  RevisionResource resource,
) async {
  if (resource.isLink) {
    final uri = Uri.tryParse(resource.url ?? '');
    if (uri == null) return;
    await confirmAndOpenLink(context, uri, sharedBy: resource.authorName);
    return;
  }

  final appScope = AppScope.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text('Ouverture du fichier…'),
        duration: Duration(seconds: 20),
      ),
    );

  try {
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final bytes = await appScope.examRepository.downloadFile(
      resourceId: resource.id,
      accessToken: accessToken,
    );
    messenger.hideCurrentSnackBar();

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) =>
            RevisionFileViewer(resource: resource, bytes: bytes),
      ),
    );
  } on Exception catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Ouverture impossible : $error')));
  }
}

/// Affiche le site avant d'ouvrir un lien hors de l'app.
Future<void> confirmAndOpenLink(
  BuildContext context,
  Uri uri, {
  String? sharedBy,
}) async {
  final kind = RevisionLinkKind.of(uri.toString());
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProtoIconBox(
                  icon: RevisionResourceLook.linkIcon(kind),
                  backgroundColor: context.sfSharedSoft,
                  foregroundColor: context.sfShared,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProtoOverline(kind.label),
                      Text(
                        uri.host,
                        style: TextStyle(
                          color: context.sfText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              uri.toString(),
              style: TextStyle(color: context.sfMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ProtoMutedText(
              [
                if (sharedBy != null) 'Partagé par $sharedBy.',
                'Ce site s’ouvre hors de Swikko : vérifie l’adresse avant d’y saisir un mot de passe.',
              ].join(' '),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('open-link-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ouvrir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed != true) return;
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d’ouvrir ce lien.')),
    );
  }
}

class RevisionFileViewer extends StatelessWidget {
  const RevisionFileViewer({
    required this.resource,
    required this.bytes,
    super.key,
  });

  final RevisionResource resource;
  final Uint8List bytes;

  static bool get _webViewAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// WKWebView affiche les PDF ; la WebView Android, non.
  static bool get _pdfAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    return switch (resource.fileType) {
      'image' => _ImageViewer(title: resource.title, bytes: bytes),
      'html' when _webViewAvailable => _IsolatedWebViewer(
        title: resource.title,
        html: utf8.decode(bytes, allowMalformed: true),
      ),
      'pdf' when _pdfAvailable => _IsolatedWebViewer(
        title: resource.title,
        pdf: bytes,
      ),
      'html' || 'pdf' => _Unavailable(title: resource.title),
      _ => _TextViewer(
        title: resource.title,
        text: utf8.decode(bytes, allowMalformed: true),
      ),
    };
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
      ),
    );
  }
}

class _TextViewer extends StatelessWidget {
  const _TextViewer({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: SelectableText(
          text,
          style: TextStyle(color: context.sfText, fontSize: 15, height: 1.5),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const ProtoStateCard(
        icon: Icons.phone_iphone_outlined,
        title: 'Aperçu indisponible ici',
        message:
            'Ce fichier s’affiche dans l’application iPhone. Sur cet appareil, demande un lien à la place.',
      ),
    );
  }
}

/// Page HTML ou PDF d'un élève, affichée sans accès au compte Swikko :
/// contenu chargé localement (origine vide), aucune session ni jeton partagé,
/// et tout lien qui voudrait quitter la page passe par une confirmation.
class _IsolatedWebViewer extends StatefulWidget {
  const _IsolatedWebViewer({required this.title, this.html, this.pdf});

  final String title;
  final String? html;
  final Uint8List? pdf;

  @override
  State<_IsolatedWebViewer> createState() => _IsolatedWebViewerState();
}

class _IsolatedWebViewerState extends State<_IsolatedWebViewer> {
  late final WebViewController _controller;
  bool _loading = true;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(
        widget.html != null
            ? JavaScriptMode.unrestricted
            : JavaScriptMode.disabled,
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    if (widget.html case final html?) {
      await _controller.loadHtmlString(html);
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/revision-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(widget.pdf!, flush: true);
    _tempFile = file;
    await _controller.loadFile(file.path);
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final scheme = uri?.scheme ?? '';
    // Contenu local : la page elle-même, ses ancres et ses images intégrées.
    if (scheme == 'about' || scheme == 'data' || scheme == 'blob') {
      return NavigationDecision.navigate;
    }
    if (scheme == 'file' && request.url == _tempFile?.uri.toString()) {
      return NavigationDecision.navigate;
    }
    // Une vidéo intégrée (iframe) peut se charger ; la page, elle, ne part pas.
    if (!request.isMainFrame && scheme == 'https') {
      return NavigationDecision.navigate;
    }
    if (uri != null && (scheme == 'https' || scheme == 'http') && mounted) {
      confirmAndOpenLink(context, uri);
    }
    return NavigationDecision.prevent;
  }

  @override
  void dispose() {
    _tempFile?.delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.sfSharedSoft,
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: context.sfShared),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fichier partagé par un élève, affiché dans un espace isolé.',
                    style: TextStyle(color: context.sfText, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const LinearProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
