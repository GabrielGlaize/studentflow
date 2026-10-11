/// Canal Android commun aux rappels locaux et aux notifications push.
/// L'identifiant doit rester identique à celui envoyé par l'API
/// (`FcmPushNotificationSender.AndroidChannelId`).
abstract final class StudyFlowNotificationChannel {
  static const id = 'studyflow_reminders';
  static const name = 'Rappels Swikko';
  static const description =
      'Rappels de cours et de devoirs, annonces de la classe.';
}
