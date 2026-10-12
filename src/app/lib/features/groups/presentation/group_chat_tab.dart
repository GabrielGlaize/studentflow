import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/groups/data/group_realtime.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';

/// Discussion du groupe. Les messages arrivent à l'instant par le temps réel ;
/// sans lui (réseau, proxy), l'onglet relit le fil toutes les 10 secondes.
class GroupChatTab extends StatefulWidget {
  const GroupChatTab({required this.group, super.key});

  final StudyGroupDetail group;

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab>
    with AutomaticKeepAliveClientMixin {
  static const _pollEvery = Duration(seconds: 10);
  static const _typingShownFor = Duration(seconds: 4);
  static const _typingSentEvery = Duration(seconds: 3);

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<GroupMessage> _messages = [];
  final Map<String, Timer> _typing = {};
  StreamSubscription<GroupRealtimeEvent>? _subscription;
  Timer? _poll;
  Timer? _readDebounce;
  DateTime? _lastTypingSent;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasOlder = true;
  bool _sending = false;
  String? _error;

  String get _groupId => widget.group.summary.id;

  String? get _myId => widget.group.me?.userId;

  bool get _archived => widget.group.summary.isArchived;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscription != null) return;
    final realtime = AppScope.of(context).groupRealtime;
    _subscription = realtime.events
        .where((x) => x.groupId == _groupId)
        .listen(_onEvent);
    _poll = Timer.periodic(_pollEvery, (_) {
      if (!realtime.connected.value) unawaited(_fetchNew());
    });
    unawaited(_loadLatest());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _poll?.cancel();
    _readDebounce?.cancel();
    for (final timer in _typing.values) {
      timer.cancel();
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<String?> _token() =>
      AppScope.of(context).sessionController.accessTokenForApi();

  Future<void> _loadLatest() async {
    final repository = AppScope.of(context).groupRepository;
    try {
      final messages = await repository.listMessages(
        groupId: _groupId,
        accessToken: await _token(),
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _hasOlder = messages.length >= 50;
        _loading = false;
        _error = null;
      });
      _markRead();
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  /// Rattrape les messages manqués (temps réel coupé, retour dans l'app).
  Future<void> _fetchNew() async {
    if (!mounted || _loading) return;
    final repository = AppScope.of(context).groupRepository;
    final last = _messages.where((x) => !x.isPending).lastOrNull;
    try {
      final messages = await repository.listMessages(
        groupId: _groupId,
        after: last?.createdAt,
        accessToken: await _token(),
      );
      if (!mounted || messages.isEmpty) return;
      setState(() {
        for (final message in messages) {
          _upsert(message);
        }
      });
      _markRead();
    } on Exception {
      // Hors connexion : on réessaiera au prochain tour.
    }
  }

  Future<void> _loadOlder() async {
    final first = _messages.firstOrNull;
    if (first == null || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    final repository = AppScope.of(context).groupRepository;
    try {
      final older = await repository.listMessages(
        groupId: _groupId,
        before: first.createdAt,
        accessToken: await _token(),
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older.where((x) => _indexOf(x.id) < 0));
        _hasOlder = older.length >= 50;
        _loadingOlder = false;
      });
    } on Exception {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onEvent(GroupRealtimeEvent event) {
    switch (event) {
      case GroupMessageEvent(:final message):
        setState(() {
          _upsert(message.asSeenBy(_myId));
          final authorId = message.authorId;
          if (authorId != null) _typing.remove(authorId)?.cancel();
        });
        _markRead();
      case GroupMessageDeletedEvent(:final messageId):
        final index = _indexOf(messageId);
        if (index >= 0) {
          setState(() => _messages[index] = _messages[index].deleted());
        }
      case GroupTypingEvent(:final userId):
        _typing.remove(userId)?.cancel();
        setState(() {
          _typing[userId] = Timer(_typingShownFor, () {
            if (mounted) setState(() => _typing.remove(userId));
          });
        });
      case GroupChangedEvent(area: 'reconnected'):
        unawaited(_fetchNew());
      default:
        break;
    }
  }

  int _indexOf(String id) => _messages.indexWhere((x) => x.id == id);

  /// Ajoute ou remplace un message, en gardant l'ordre chronologique.
  void _upsert(GroupMessage message) {
    final index = _indexOf(message.id);
    if (index >= 0) {
      _messages[index] = message;
      return;
    }
    // Mon propre message déjà affiché en « envoi… » : on remplace le brouillon.
    final pending = _messages.indexWhere(
      (x) => x.isPending && message.isMine && x.text == message.text,
    );
    if (pending >= 0) {
      _messages[pending] = message;
      return;
    }
    _messages.add(message);
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _markRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final repository = AppScope.of(context).groupRepository;
      try {
        await repository.markRead(
          groupId: _groupId,
          accessToken: await _token(),
        );
      } on Exception {
        // Le compteur de non-lus se mettra à jour à la prochaine ouverture.
      }
    });
  }

  void _onTyping(String value) {
    if (value.trim().isEmpty) return;
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last != null && now.difference(last) < _typingSentEvery) return;
    _lastTypingSent = now;
    AppScope.of(context).groupRealtime.typing(_groupId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final repository = AppScope.of(context).groupRepository;
    final messenger = ScaffoldMessenger.of(context);
    final draft = GroupMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      groupId: _groupId,
      authorId: _myId,
      authorName: widget.group.me?.name,
      text: text,
      isMine: true,
      isDeleted: false,
      createdAt: DateTime.now(),
      isPending: true,
    );
    setState(() {
      _sending = true;
      _messages.add(draft);
      _controller.clear();
      _lastTypingSent = null;
    });

    try {
      final sent = await repository.sendMessage(
        groupId: _groupId,
        text: text,
        accessToken: await _token(),
      );
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((x) => x.id == draft.id);
        _upsert(sent);
        _sending = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((x) => x.id == draft.id);
        _controller.text = text;
        _sending = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Message non envoyé : $error')),
      );
    }
  }

  Future<void> _delete(GroupMessage message) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: AppColors.danger),
          title: const Text('Supprimer ce message'),
          subtitle: const Text('Il sera remplacé par « message supprimé ».'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final repository = AppScope.of(context).groupRepository;
    try {
      await repository.deleteMessage(
        messageId: message.id,
        accessToken: await _token(),
      );
      final index = _indexOf(message.id);
      if (mounted && index >= 0) {
        setState(() => _messages[index] = _messages[index].deleted());
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) {
      return ProtoStateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Discussion indisponible',
        message: _error!,
        actionLabel: 'Réessayer',
        onAction: _loadLatest,
      );
    }

    final reversed = _messages.reversed.toList();
    final typingNames = _typing.keys
        .map(
          (id) => widget.group.members
              .where((x) => x.userId == id)
              .firstOrNull
              ?.name,
        )
        .whereType<String>()
        .map((name) => name.split(' ').first)
        .toList();
    final seenBy = _seenByOnMyLastMessage();

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const _EmptyChat()
              : ListView.builder(
                  key: const ValueKey('group-chat-list'),
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: reversed.length + (_hasOlder ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == reversed.length) {
                      return Center(
                        child: TextButton(
                          onPressed: _loadingOlder ? null : _loadOlder,
                          child: Text(
                            _loadingOlder
                                ? 'Chargement…'
                                : 'Messages précédents',
                          ),
                        ),
                      );
                    }
                    final message = reversed[index];
                    final previous = index + 1 < reversed.length
                        ? reversed[index + 1]
                        : null;
                    final showDay =
                        previous == null ||
                        !DateUtils.isSameDay(
                          previous.createdAt,
                          message.createdAt,
                        );
                    final grouped =
                        previous != null &&
                        !showDay &&
                        !previous.isSystem &&
                        previous.authorId == message.authorId &&
                        message.createdAt
                                .difference(previous.createdAt)
                                .inMinutes <
                            5;
                    final isLastMine =
                        index ==
                        reversed.indexWhere((x) => x.isMine && !x.isSystem);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDay) _DaySeparator(day: message.createdAt),
                        _MessageBubble(
                          message: message,
                          showAuthor: !grouped,
                          onLongPress:
                              message.isMine &&
                                  !message.isDeleted &&
                                  !message.isPending
                              ? () => _delete(message)
                              : null,
                        ),
                        if (isLastMine && seenBy != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 2,
                              right: 4,
                              bottom: 4,
                            ),
                            child: Text(
                              seenBy,
                              key: const ValueKey('group-chat-seen'),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: context.sfMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (typingNames.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                typingNames.length == 1
                    ? '${typingNames.first} écrit…'
                    : '${typingNames.join(', ')} écrivent…',
                key: const ValueKey('group-chat-typing'),
                style: TextStyle(
                  color: context.sfGroup,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        if (_archived)
          const Padding(
            padding: EdgeInsets.all(16),
            child: ProtoMutedText(
              'Groupe archivé : la discussion est en lecture seule.',
            ),
          )
        else
          _Composer(
            controller: _controller,
            sending: _sending,
            onChanged: _onTyping,
            onSend: _send,
          ),
      ],
    );
  }

  /// « Vu par Léa, Liam » sous mon dernier message.
  String? _seenByOnMyLastMessage() {
    final mine = _messages
        .where((x) => x.isMine && !x.isPending && !x.isSystem)
        .lastOrNull;
    if (mine == null) return null;
    final readers = widget.group.activeMembers
        .where(
          (x) =>
              !x.isMe &&
              (x.lastReadAt?.isAfter(
                    mine.createdAt.subtract(const Duration(seconds: 1)),
                  ) ??
                  false),
        )
        .map((x) => x.name.split(' ').first)
        .toList();
    if (readers.isEmpty) return null;
    final others = widget.group.activeMembers.where((x) => !x.isMe).length;
    return readers.length == others && others > 1
        ? 'Vu par tout le monde'
        : 'Vu par ${readers.join(', ')}';
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: ProtoStateCard(
        icon: Icons.forum_outlined,
        title: 'Lancez la discussion',
        message: 'Ce que vous écrivez ici reste entre les membres du groupe.',
        compact: true,
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = DateUtils.isSameDay(day, now)
        ? 'Aujourd’hui'
        : DateUtils.isSameDay(day, now.subtract(const Duration(days: 1)))
        ? 'Hier'
        : StudyFlowFormat.longDay(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ProtoChip(
          label: label,
          backgroundColor: context.sfSoftCard,
          foregroundColor: context.sfMuted,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showAuthor,
    this.onLongPress,
  });

  final GroupMessage message;
  final bool showAuthor;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sfMuted, fontSize: 12, height: 1.35),
        ),
      );
    }

    final mine = message.isMine;
    final background = mine ? context.sfGroup : context.sfCard;
    final foreground = mine ? context.sfCard : context.sfText;

    return Padding(
      padding: EdgeInsets.only(top: showAuthor ? 8 : 2),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (showAuthor && !mine)
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 2),
                  child: Text(
                    message.authorName ?? 'Ancien élève',
                    style: TextStyle(
                      color: context.sfGroup,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              GestureDetector(
                onLongPress: onLongPress,
                child: Opacity(
                  opacity: message.isPending ? 0.6 : 1,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    decoration: BoxDecoration(
                      color: message.isDeleted
                          ? context.sfSoftCard
                          : background,
                      borderRadius: BorderRadius.circular(16),
                      border: mine ? null : Border.all(color: context.sfLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message.isDeleted ? 'Message supprimé' : message.text,
                          style: TextStyle(
                            color: message.isDeleted
                                ? context.sfMuted
                                : foreground,
                            fontSize: 15,
                            height: 1.35,
                            fontStyle: message.isDeleted
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message.isPending
                              ? 'Envoi…'
                              : StudyFlowFormat.timeOf(message.createdAt),
                          style: TextStyle(
                            color:
                                (message.isDeleted
                                        ? context.sfMuted
                                        : foreground)
                                    .withValues(alpha: 0.7),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: context.sfCard,
          border: Border(top: BorderSide(color: context.sfLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('group-chat-input'),
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  hintText: 'Message au groupe',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: const ValueKey('group-chat-send'),
              style: IconButton.styleFrom(
                backgroundColor: context.sfGroup,
                foregroundColor: context.sfCard,
              ),
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
