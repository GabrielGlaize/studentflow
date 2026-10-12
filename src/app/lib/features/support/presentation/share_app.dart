import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:studyflow_app/core/app_scope.dart';

/// Lien envoyé aux camarades (page publique de Swikko).
const swikkoShareUrl = String.fromEnvironment(
  'SWIKKO_SHARE_URL',
  defaultValue: 'https://studyflow-dev.duckdns.org/',
);

/// Ouvre le partage du téléphone avec un message prêt à envoyer : le lien et,
/// si on le connaît, le code pour rejoindre la classe.
Future<void> shareSwikko(BuildContext context) async {
  final appScope = AppScope.of(context);
  final box = context.findRenderObject() as RenderBox?;
  String? classCode;
  String? className;
  try {
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final currentClass = await appScope.classManagementRepository
        .getCurrentClass(accessToken: accessToken);
    classCode = currentClass?.accessCode;
    className = currentClass?.name;
  } on Exception {
    // Sans réseau : on partage quand même le lien.
  }

  final invitation = classCode == null
      ? ''
      : '\nPour rejoindre ${className ?? 'notre classe'}, le code est $classCode.';
  final text =
      'Je m’organise avec Swikko : planning de la classe, devoirs, notes '
      'rapides et alternance au même endroit.$invitation\n$swikkoShareUrl';

  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'Swikko, l’app de la classe',
      // iPad : le panneau de partage s'ancre sur le bouton touché.
      sharePositionOrigin: box == null || !Platform.isIOS
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}
