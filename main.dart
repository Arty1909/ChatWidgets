import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Простой чат',
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  Message? _pinnedMessage;
  Message? _replyToMessage;
  final ScrollController _scrollController = ScrollController();
  int? _editingMessageIndex;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentAudioFilePath;
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isDragging = false;

  void _sendMessage() {
    final messageText = _textController.text.trim();
    if (messageText.isNotEmpty) {
      setState(() {
        if (_editingMessageIndex != null) {
          _messages[_editingMessageIndex!].text = messageText;
        } else if (_replyToMessage != null) {
          _messages.add(Message(
              text: messageText,
              isSentByMe: true,
              replyTo: _replyToMessage));
          _replyToMessage = null;
          _scrollToBottom();
        } else {
          _messages.add(Message(text: messageText, isSentByMe: true));
          _scrollToBottom();
        }
        _textController.clear();
      });

      if (_editingMessageIndex != null) {
        Future.delayed(Duration(milliseconds: 300), () {
          _scrollToMessageIndex(_editingMessageIndex);
          setState(() {
            _editingMessageIndex = null;
          });
        });
      }
    }
  }

  void _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      String fileName = path.basename(file.path!);
      setState(() {
        _messages.add(Message(
          audioFilePath: file.path!,
          isSentByMe: true,
          audioFileName: fileName,
        ));
        _scrollToBottom();
      });
    }
  }

  void _editMessage(int index) {
    if (_messages[index].isSentByMe) {
      _textController.text = _messages[index].text ?? '';
      setState(() {
        _editingMessageIndex = index;
      });
    }
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Сообщение скопировано в буфер обмена'),
      ),
    );
  }

  void _deleteMessage(int index) {
    if (_messages[index].isSentByMe) {
      setState(() {
        if (_pinnedMessage == _messages[index]) {
          _pinnedMessage = null;
        }
        if (_replyToMessage == _messages[index]) {
          _replyToMessage = null;
        }
        _messages.removeAt(index);
      });
    }
  }

  void _pinMessage(int index) {
    setState(() {
      _pinnedMessage = _messages[index];
    });
  }

  void _setReplyToMessage(int index) {
    setState(() {
      _replyToMessage = _messages[index];
    });
  }

  void _scrollToMessage(Message message) {
    final index = _messages.indexOf(message);
    if (index != -1) {
      _scrollController.animateTo(
        index * 100.0, // Предполагаем, что высота каждого сообщения составляет 100 пикселей
        curve: Curves.easeInOut,
        duration: Duration(milliseconds: 300),
      );
    }
  }

  void _scrollToMessageIndex(int? index) {
    if (index != null && index >= 0 && index < _messages.length) {
      _scrollController.animateTo(
        index * 100.0, // Предполагаем, что высота каждого сообщения составляет 100 пикселей
        curve: Curves.easeInOut,
        duration: Duration(milliseconds: 300),
      );
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      curve: Curves.easeInOut,
      duration: Duration(milliseconds: 300),
    );
  }

  void _addReaction(int index, String reaction) {
    setState(() {
      if (_messages[index].reaction == reaction) {
        _messages[index].reaction = null;
      } else {
        _messages[index].reaction = reaction;
      }
    });
  }

  void _showMenu(BuildContext context, Offset position, int index) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final List<PopupMenuEntry<dynamic>> menuItems = [
      PopupMenuItem(
        child: ListTile(
          leading: Icon(Icons.reply),
          title: Text('Ответить'),
          onTap: () {
            _setReplyToMessage(index);
            Navigator.pop(context);
          },
        ),
      ),
      if (_messages[index].isSentByMe)
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Редактировать'),
            onTap: () {
              _editMessage(index);
              Navigator.pop(context);
            },
          ),
        ),
      PopupMenuItem(
        child: ListTile(
          leading: Icon(Icons.copy),
          title: Text('Копировать'),
          onTap: () {
            _copyMessage(_messages[index].text!);
            Navigator.pop(context);
          },
        ),
      ),
      PopupMenuItem(
        child: ListTile(
          leading: Icon(Icons.delete),
          title: Text('Удалить'),
          onTap: () {
            _deleteMessage(index);
            Navigator.pop(context);
          },
        ),
      ),
      PopupMenuItem(
        child: ListTile(
          leading: Icon(Icons.push_pin),
          title: Text('Закрепить'),
          onTap: () {
            _pinMessage(index);
            Navigator.pop(context);
          },
        ),
      ),
      PopupMenuItem(
        child: ListTile(
          leading: Icon(Icons.insert_emoticon),
          title: Text('Реакция'),
          onTap: () {
            Navigator.pop(context);
            _showReactions(context, index, position);
          },
        ),
      ),
    ];

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: menuItems,
    );
  }

  void _showReactions(BuildContext context, int index, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: IconButton(
            icon: Icon(Icons.thumb_up),
            onPressed: () {
              _addReaction(index, '👍');
              Navigator.pop(context);
            },
          ),
        ),
        PopupMenuItem(
          child: IconButton(
            icon: Icon(Icons.thumb_down),
            onPressed: () {
              _addReaction(index, '👎');
              Navigator.pop(context);
            },
          ),
        ),
        PopupMenuItem(
          child: IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              _addReaction(index, '❤️');
              Navigator.pop(context);
            },
          ),
        ),
        PopupMenuItem(
          child: IconButton(
            icon: Icon(Icons.local_fire_department),
            onPressed: () {
              _addReaction(index, '🔥');
              Navigator.pop(context);
            },
          ),
        ),
        PopupMenuItem(
          child: IconButton(
            icon: Icon(Icons.tag_faces),
            onPressed: () {
              _addReaction(index, '😊');
              Navigator.pop(context);
            },
          ),
        ),
        PopupMenuItem(
          child: IconButton(
            icon: Icon(Icons.insert_emoticon),
            onPressed: () {
              _addReaction(index, '😄');
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  void _togglePlayPauseAudio(String filePath) async {
    if (_isPlaying && _currentAudioFilePath == filePath) {
      _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      try {
        await _audioPlayer.play(DeviceFileSource(filePath));
        _audioPlayer.onDurationChanged.listen((duration) {
          setState(() {
            _audioDuration = duration;
          });
        });
      } catch (e) {
        print('Failed to play audio: $e');
      }

      setState(() {
        _currentAudioFilePath = filePath;
        _isPlaying = true;
      });

      _audioPlayer.onPositionChanged.listen((position) {
        setState(() {
          _audioPosition = position;
        });
      });
    }
  }

  void _stopAudio() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentAudioFilePath = null;
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Простой чат'),
      ),
      body: Column(
        children: [
          if (_pinnedMessage != null)
            GestureDetector(
              onTap: () => _scrollToMessage(_pinnedMessage!),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  color: Colors.grey[300],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Закрепленное сообщение:'),
                        Text(_pinnedMessage!.text ?? ''),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onLongPressStart: (details) {
                    _showMenu(context, details.globalPosition, index);
                  },
                  child: _messageBubble(_messages[index], index),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Введите сообщение',
                    prefixText: _replyToMessage != null
                        ? 'Ответ на "${_replyToMessage!.text}": '
                        : null,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: _sendMessage,
              ),
              IconButton(
                icon: Icon(Icons.attach_file),
                onPressed: _pickAudioFile,
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _messageBubble(Message message, int index) {
  if (message.audioFilePath != null) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Align(
        key: ValueKey(message),
        alignment: message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: _audioDuration.inMilliseconds > 0 && _currentAudioFilePath == message.audioFilePath
                    ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
                    : 0.0,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                backgroundColor: Colors.grey[300],
                strokeWidth: 5,
              ),
            ),
            GestureDetector(
              onTap: () => _togglePlayPauseAudio(message.audioFilePath!),
              child: Icon(
                _isPlaying && _currentAudioFilePath == message.audioFilePath
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 35,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }  else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        child: Align(
          key: ValueKey(message),
          alignment: message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Card(
              color: message.isSentByMe ? Colors.blue : Colors.grey[300],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyTo != null)
                      GestureDetector(
                        onTap: () => _scrollToMessage(message.replyTo!),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            'Ответ на: ${message.replyTo!.text}',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    if (message.text != null)
                      Text(message.text!),
                    if (message.reaction != null)
                      GestureDetector(
                        onTap: () => _addReaction(index, message.reaction!),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(message.reaction!,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

class Message {
  String? text;
  final bool isSentByMe;
  final Message? replyTo;
  String? reaction;
  final String? audioFilePath;
  final String? audioFileName;

  Message({
    this.text,
    required this.isSentByMe,
    this.replyTo,
    this.reaction,
    this.audioFilePath,
    this.audioFileName,
  });
}