import 'dart:async';
import 'package:chat_apk_socket_io/api_url.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:chat_apk_socket_io/models/messages.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late IO.Socket socket;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final Set<String> _usersTyping = {};
  final List<String> _connectedUsers = [];
  Timer? _typingTimer;
  bool _isTyping = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    connectSocket();
  }

  void connectSocket() {
    socket = IO.io(
      ApiConstants.baseUrl,
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    socket.connect();

    socket.onConnect((_) {
      socket.emit('add user', widget.username);
      setState(() {
        if (!_connectedUsers.contains(widget.username)) {
          _connectedUsers.add(widget.username);
        }
      });
    });

    socket.on('login', (data) {
      List<dynamic> users = data['users'];
      setState(() {
        _connectedUsers.clear();
        _connectedUsers.addAll(List<String>.from(users));
        if (!_connectedUsers.contains(widget.username)) {
          _connectedUsers.add(widget.username);
        }
      });
    });

    socket.on('new message', (data) {
      setState(() {
        _messages.add(ChatMessage(
          username: data['username'],
          message: data['message'],
        ));
      });
    });

    socket.on('user joined', (data) {
      setState(() {
        final username = data['username'];
        if (!_connectedUsers.contains(username)) {
          _connectedUsers.add(username);
        }
        _messages.add(ChatMessage(username: 'System', message: '$username joined.'));
      });
    });

    socket.on('user left', (data) {
      setState(() {
        final username = data['username'];
        _connectedUsers.remove(username);
        _messages.add(ChatMessage(username: 'System', message: '$username left.'));
      });
    });

    socket.on('typing', (data) {
      setState(() => _usersTyping.add(data['username']));
    });

    socket.on('stop typing', (data) {
      setState(() => _usersTyping.remove(data['username']));
    });
  }

  void sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    socket.emit('new message', message);
    setState(() {
      _messages.add(ChatMessage(username: widget.username, message: message));
      _messageController.clear();
    });

    stopTyping();
  }

  void startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      socket.emit('typing');
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), stopTyping);
  }

  void stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      socket.emit('stop typing');
    }
  }

  List<String> get sortedUsers {
    final users = [..._connectedUsers];
    users.sort((a, b) {
      if (a == widget.username) return -1;
      if (b == widget.username) return 1;
      return a.compareTo(b);
    });
    return users;
  }

  Widget buildMessageList() {
    return ListView.builder(
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (_, index) {
        final message = _messages[_messages.length - index - 1];

        if (message.username == 'System') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    message.message,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
              ],
            ),
          );
        }

        final isSelf = message.username == widget.username;
        final displayName = isSelf ? 'You' : message.username;

        return Align(
          alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelf ? Colors.grey[300] : Colors.green[500],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelf ? Colors.black87 : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelf ? Colors.black87 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTypingIndicator() {
    if (_usersTyping.isEmpty) return const SizedBox.shrink();
    final names = _usersTyping.join(', ');
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Text("$names is typing...", style: const TextStyle(fontStyle: FontStyle.italic)),
    );
  }

  Widget buildUserList() {
    final users = sortedUsers;
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelf = user.trim().toLowerCase() == widget.username.trim().toLowerCase();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          elevation: isSelf ? 4.0 : 1.0,
          color: isSelf ? Colors.blue[50] : Colors.white,
          child: ListTile(
            leading: Icon(Icons.person, color: isSelf ? Colors.blue : Colors.grey),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  user,
                  style: TextStyle(
                    fontWeight: isSelf ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                if (isSelf)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'you',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    socket.dispose();
    _messageController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Chat Screen"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 600;
              if (!isMobile) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  _scaffoldKey.currentState?.openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      endDrawer: MediaQuery.of(context).size.width < 600
          ? Drawer(
        child: Column(
          children: [
            AppBar(
              title: const Text("Connected Users"),
              automaticallyImplyLeading: false,
            ),
            Expanded(child: buildUserList()),
          ],
        ),
      )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 600;
          return Row(
            children: [
              if (isWide)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[200],
                    child: buildUserList(),
                  ),
                ),
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/bg.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: buildMessageList()),
                      buildTypingIndicator(),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: TextField(
                                controller: _messageController,
                                onChanged: (_) => startTyping(),
                                onSubmitted: (_) => sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: "Type a message...",
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white),
                                onPressed: sendMessage,
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

