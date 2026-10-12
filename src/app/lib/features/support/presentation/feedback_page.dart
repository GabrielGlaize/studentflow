import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/release_notes.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/support/data/feedback_repository.dart';

/// Remonter une idée ou un bug : deux choix, un message, envoyer.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({this.initialKind = FeedbackKind.idea, super.key});

  final FeedbackKind initialKind;

  static Future<void> open(
    BuildContext context, {
    FeedbackKind kind = FeedbackKind.idea,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => FeedbackPage(initialKind: kind),
      ),
    );
  }

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  late FeedbackKind _kind = widget.initialKind;
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.length < 5) {
      setState(() => _error = 'Décris-le en quelques mots.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    final appScope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.feedbackRepository.send(
        kind: _kind,
        message: message,
        appVersion: ReleaseNotes.current.version,
        platform: _platform,
        accessToken: accessToken,
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _kind == FeedbackKind.bug
                  ? 'Merci ! Le bug est signalé.'
                  : 'Merci pour l’idée !',
            ),
          ),
        );
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBug = _kind == FeedbackKind.bug;

    return Scaffold(
      appBar: AppBar(title: const Text('Une idée, un bug ?')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SegmentedButton<FeedbackKind>(
              key: const ValueKey('feedback-kind'),
              segments: const [
                ButtonSegment(
                  value: FeedbackKind.idea,
                  icon: Icon(Icons.lightbulb_outline),
                  label: Text('Une idée'),
                ),
                ButtonSegment(
                  value: FeedbackKind.bug,
                  icon: Icon(Icons.bug_report_outlined),
                  label: Text('Un bug'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) =>
                  setState(() => _kind = value.single),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('feedback-message'),
              controller: _controller,
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: isBug ? 'Que s’est-il passé ?' : 'Ton idée',
                hintText: isBug
                    ? 'Sur quel écran, ce que tu as fait, ce qui s’est passé…'
                    : 'Ce qui te manque, ce qui serait plus pratique…',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 10),
            ProtoMutedText(
              'Ton nom, ton e-mail et la version de l’app '
              '(${ReleaseNotes.current.version}) accompagnent le message, pour '
              'pouvoir te répondre.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('feedback-send'),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Envoi…' : 'Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}
