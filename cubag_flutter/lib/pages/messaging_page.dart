import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

class MessagingPage extends StatefulWidget {
  final String? initialUserId;
  final String? initialUserName;
  final String? initialUserCompany;

  const MessagingPage({
    super.key,
    this.initialUserId,
    this.initialUserName,
    this.initialUserCompany,
  });

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  bool _loading = true;
  bool _loadingChat = false;
  List<dynamic> _conversations = [];
  List<dynamic> _filteredConversations = [];  // F-25 fix
  String _search = '';  // F-25 fix
  Map<String, dynamic>? _activeChat;
  List<dynamic> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();  // F-25 fix

  @override
  void initState() {
    super.initState();
    _fetchConversations().then((_) {
      _checkInitialChat();
    });
  }

  @override
  void didUpdateWidget(MessagingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUserId != oldWidget.initialUserId) {
      _checkInitialChat();
    }
  }

  void _checkInitialChat() {
    if (widget.initialUserId != null && mounted) {
      // Find existing conversation or create a temporary one for the UI
      final existing = _conversations.cast<Map<String, dynamic>?>().firstWhere(
        (c) => c?['id']?.toString() == widget.initialUserId.toString(),
        orElse: () => null,
      );

      if (existing != null) {
        _openChat(Map<String, dynamic>.from(existing));
      } else if (widget.initialUserName != null) {
        // If no existing conversation, we can still start one if we have the name
        _openChat({
          'id': widget.initialUserId,
          'name': widget.initialUserName,
          'company': widget.initialUserCompany ?? 'CUBAG Member',
        });
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();  // F-25 fix
    super.dispose();
  }

  Future<void> _fetchConversations({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final res = await ApiService().get('/messages/conversations');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final all = ApiService.ensureList(res.data);
        setState(() {
          _conversations = all;
          _applySearch(_search);
        });
      }
    } catch (_) {}
    if (mounted && showLoading) setState(() => _loading = false);
  }

  // F-25 fix: filter conversations by name or company
  void _applySearch(String q) {
    _search = q;
    final lower = q.toLowerCase();
    _filteredConversations = lower.isEmpty
        ? List.from(_conversations)
        : _conversations.where((c) {
            return (c['name']?.toString().toLowerCase() ?? '').contains(lower) ||
                   (c['company']?.toString().toLowerCase() ?? '').contains(lower);
          }).toList();
  }

  Future<void> _openChat(Map<String, dynamic> target) async {
    setState(() { _activeChat = target; _messages = []; _loadingChat = true; });
    try {
      final res = await ApiService().get('/messages/${target['id']}');
      if (!mounted) return;
      if (res.statusCode == 200) setState(() => _messages = ApiService.ensureList(res.data));
    } catch (_) {}
    if (mounted) setState(() => _loadingChat = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _activeChat == null) return;
    _msgCtrl.clear();
    try {
      final res = await ApiService().post('/messages/${_activeChat!['id']}', data: {'text': text});
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _messages.add(res.data));
        _scrollToBottom();
        _fetchConversations(showLoading: false);
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _getInitials(Map<String, dynamic>? chat) {
    if (chat == null) return '?';
    if (chat['initials'] != null && chat['initials'].toString().isNotEmpty) {
      return chat['initials'].toString();
    }
    final name = chat['name']?.toString() ?? '';
    if (name.trim().isEmpty) return '?';
    return name.trim().split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return AppLayout(
      title: 'Messages',
      scrollable: false,
      child: _loading
        ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Loading conversations...', style: TextStyle(color: Colors.grey))])))
        : _activeChat == null ? _buildList(primary) : _buildChat(primary),
    );
  }

  Widget _buildList(Color primary) {
    return Column(children: [
      // F-25 fix: functional search wired to _searchCtrl and _applySearch
      TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _applySearch(v)),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search, color: Colors.grey), hintText: 'Search conversations...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).cardColor),
      ),
      const SizedBox(height: 12),

      if (_filteredConversations.isEmpty)
        Container(
          padding: const EdgeInsets.all(60),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Container(width: 60, height: 60, decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(Icons.chat_bubble_outline, color: primary, size: 28)),
            const SizedBox(height: 16),
            Text(_search.isEmpty ? 'No messages' : 'No results for "$_search"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_search.isEmpty ? 'Conversations appear here.\nConnect with members via the directory.' : 'Try a different search term.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
        )
      else
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(children: _filteredConversations.map((conv) {
                  final initials = _getInitials(Map<String, dynamic>.from(conv));
                  final unread = (conv['unread'] ?? 0) as int;
                  return Column(children: [
                    ListTile(
                      onTap: () => _openChat(Map<String, dynamic>.from(conv)),
                      leading: CircleAvatar(backgroundColor: primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Text(conv['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                      subtitle: Text(conv['lastMsg']?.toString() ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      trailing: unread > 0
                        ? CircleAvatar(radius: 10, backgroundColor: primary, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                        : Text(conv['time']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    const Divider(height: 1),
                  ]);
                }).toList()),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildChat(Color primary) {
    final initials = _getInitials(_activeChat);
    return Column(children: [
      // Chat header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => setState(() { _activeChat = null; _messages = []; })),
          CircleAvatar(backgroundColor: primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_activeChat!['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
            Text(_activeChat!['company']?.toString() ?? 'CUBAG Member', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
      const Divider(height: 1),

      // Messages list
      Expanded(child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _loadingChat
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
            ? Center(child: Text('Say hello to ${(_activeChat!['name']?.toString() ?? 'Member').split(' ').first}!', style: const TextStyle(color: Colors.grey)))
            : LayoutBuilder(
                builder: (ctx, constraints) {
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg['from'] == 'me';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.75),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? primary : Theme.of(ctx).cardColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(msg['text']?.toString() ?? '', style: TextStyle(color: isMe ? Colors.white : null, fontSize: 14, height: 1.4)),
                                if (msg['time'] != null) Text(msg['time'].toString(), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
                              ]),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              ),
      )),

      // Input bar
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _msgCtrl,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(hintText: 'Type...', contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).dividerColor))),
          )),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: primary, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send)),
        ]),
      ),
    ]);
  }
}
