import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math'; // Untuk min()

class BertanyaScreen extends StatefulWidget {
  @override
  _BertanyaScreenState createState() => _BertanyaScreenState();
}

class _BertanyaScreenState extends State<BertanyaScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = []; // Pesan untuk sesi chat saat ini
  final String _apiKey =
      "AIzaSyAAyTipEdCsDEQWWlxQw9aLyvzm3H4G7T0"; // GANTI DENGAN API KEY BARU ANDA
  // Mengubah dari List<String> menjadi List<Map<String, String>>
  // Setiap Map akan berisi: {'id': 'sessionId', 'name': 'Session Display Name'}
  List<Map<String, String>> _chatSessionsData = [];
  String? _currentChatSessionId;
  late SharedPreferences _prefs;

  // Kunci baru untuk SharedPreferences dengan struktur data sesi yang diperbarui
  // Menambahkan _v2 atau _v3 untuk menghindari konflik dengan data lama jika ada saat pengujian
  static const String _chatSessionsDataKey = "chat_sessions_data_list_v3";
  static const String _currentChatIdKey = "current_chat_session_id_v3";
  static const String _chatHistoryPrefix = "chat_history_v3_";

  @override
  void initState() {
    super.initState();
    debugPrint("initState: Memulai inisialisasi chat...");
    _initChat();
  }

  Future<void> _initChat() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadChatSessionsData(); // Memuat list Map sesi (id dan nama)
    _currentChatSessionId = _prefs.getString(_currentChatIdKey);
    debugPrint(
      "initState: _chatSessionsData dimuat: ${_chatSessionsData.length} sesi.",
    );
    debugPrint(
      "initState: _currentChatSessionId dari prefs: $_currentChatSessionId",
    );

    if (_chatSessionsData.isEmpty) {
      debugPrint("initState: Tidak ada sesi. Memulai sesi baru...");
      await _startNewChatSession(isInitial: true);
    } else {
      // Verifikasi apakah _currentChatSessionId yang tersimpan masih valid
      bool currentIdIsValid =
          _currentChatSessionId != null &&
          _chatSessionsData.any(
            (session) => session['id'] == _currentChatSessionId,
          );

      if (!currentIdIsValid) {
        debugPrint(
          "initState: _currentChatSessionId tidak valid atau tidak ditemukan. Menggunakan sesi pertama.",
        );
        _currentChatSessionId =
            _chatSessionsData
                .first['id']; // Ambil ID dari sesi pertama yang ada
        await _saveCurrentChatId();
      } else {
        debugPrint(
          "initState: _currentChatSessionId valid: $_currentChatSessionId",
        );
      }
      // Muat pesan untuk sesi yang sekarang aktif (baik yang baru diset atau dari prefs)
      await _loadMessagesForCurrentChat();
    }

    // Panggil setState di akhir setelah semua operasi async selesai dan widget sudah mounted
    if (mounted) {
      debugPrint("initState: Inisialisasi selesai. Memanggil setState.");
      setState(() {});
    }
  }

  Future<void> _loadChatSessionsData() async {
    final String? jsonString = _prefs.getString(_chatSessionsDataKey);
    if (jsonString != null) {
      try {
        // Pastikan jsonString adalah list, bukan string tunggal yang merepresentasikan list
        final List<dynamic> decodedList = jsonDecode(jsonString);
        _chatSessionsData =
            decodedList
                .map((item) {
                  // Pastikan setiap item adalah Map sebelum konversi
                  if (item is Map) {
                    return Map<String, String>.from(
                      item.map(
                        (key, value) =>
                            MapEntry(key.toString(), value.toString()),
                      ),
                    );
                  }
                  return <
                    String,
                    String
                  >{}; // Kembalikan map kosong jika item bukan map
                })
                .where(
                  (map) =>
                      map.isNotEmpty &&
                      map.containsKey('id') &&
                      map.containsKey('name'),
                )
                .toList(); // Filter map yang tidak valid
        debugPrint(
          "_loadChatSessionsData: Berhasil memuat ${_chatSessionsData.length} sesi.",
        );
      } catch (e) {
        debugPrint(
          "_loadChatSessionsData: Error decoding chat sessions data: $e. Hapus data korup.",
        );
        _chatSessionsData = []; // Fallback ke list kosong
        await _prefs.remove(
          _chatSessionsDataKey,
        ); // Hapus data korup agar tidak error lagi
      }
    } else {
      _chatSessionsData = [];
      debugPrint(
        "_loadChatSessionsData: Tidak ada data sesi ditemukan (_chatSessionsDataKey null).",
      );
    }
  }

  Future<void> _saveChatSessionsData() async {
    final String jsonString = jsonEncode(_chatSessionsData);
    await _prefs.setString(_chatSessionsDataKey, jsonString);
    debugPrint(
      "_saveChatSessionsData: Menyimpan ${_chatSessionsData.length} sesi.",
    );
  }

  Future<void> _saveCurrentChatId() async {
    if (_currentChatSessionId != null) {
      await _prefs.setString(_currentChatIdKey, _currentChatSessionId!);
      debugPrint(
        "_saveCurrentChatId: Menyimpan ID sesi saat ini: $_currentChatSessionId",
      );
    }
  }

  Future<void> _loadMessagesForCurrentChat() async {
    if (_currentChatSessionId == null) {
      debugPrint(
        "_loadMessagesForCurrentChat: _currentChatSessionId null, tidak memuat pesan.",
      );
      if (mounted) {
        // Hanya panggil setState jika widget masih ada di tree
        setState(() {
          _messages = [];
        });
      }
      return;
    }
    debugPrint(
      "_loadMessagesForCurrentChat: Memuat pesan untuk sesi: $_currentChatSessionId",
    );
    String? chatData = _prefs.getString(
      "$_chatHistoryPrefix$_currentChatSessionId",
    );
    List<Map<String, String>> loadedMessages = [];
    if (chatData != null) {
      try {
        final List<dynamic> decodedMessages = jsonDecode(chatData);
        // Pastikan setiap item adalah Map<String, String>
        loadedMessages =
            decodedMessages
                .map((item) {
                  if (item is Map) {
                    return Map<String, String>.from(
                      item.map(
                        (key, value) =>
                            MapEntry(key.toString(), value.toString()),
                      ),
                    );
                  }
                  return <String, String>{};
                })
                .where(
                  (map) =>
                      map.isNotEmpty &&
                      map.containsKey('sender') &&
                      map.containsKey('text'),
                )
                .toList();
        debugPrint(
          "_loadMessagesForCurrentChat: ${loadedMessages.length} pesan dimuat.",
        );
      } catch (e) {
        debugPrint(
          "_loadMessagesForCurrentChat: Error decoding messages for session $_currentChatSessionId: $e. Hapus data korup.",
        );
        loadedMessages = [];
        await _prefs.remove(
          "$_chatHistoryPrefix$_currentChatSessionId",
        ); // Hapus data korup
      }
    } else {
      debugPrint(
        "_loadMessagesForCurrentChat: Tidak ada riwayat pesan ditemukan untuk sesi $_currentChatSessionId.",
      );
    }

    if (mounted) {
      // Hanya panggil setState jika widget masih ada di tree
      setState(() {
        _messages = loadedMessages;
      });
    }
  }

  Future<void> _saveMessagesForCurrentChat() async {
    if (_currentChatSessionId == null) {
      debugPrint(
        "_saveMessagesForCurrentChat: _currentChatSessionId null, tidak menyimpan pesan.",
      );
      return;
    }
    await _prefs.setString(
      "$_chatHistoryPrefix$_currentChatSessionId",
      jsonEncode(_messages),
    );
    debugPrint(
      "_saveMessagesForCurrentChat: Menyimpan ${_messages.length} pesan untuk sesi: $_currentChatSessionId",
    );
  }

  Future<void> _startNewChatSession({bool isInitial = false}) async {
    String newSessionId = "chat_${DateTime.now().millisecondsSinceEpoch}";
    // Nama awal bisa lebih generik, akan diupdate setelah pesan pertama
    String initialChatName =
        "Chat Baru (${DateFormat('HH:mm').format(DateTime.now())})";

    Map<String, String> newSessionData = {
      'id': newSessionId,
      'name': initialChatName,
    };
    _chatSessionsData.insert(
      0,
      newSessionData,
    ); // Tambah sesi baru di awal list
    _currentChatSessionId =
        newSessionId; // Jadikan sesi baru sebagai sesi aktif

    // Reset pesan untuk sesi baru
    _messages = [];

    await _saveChatSessionsData(); // Simpan list sesi yang sudah diupdate
    await _saveCurrentChatId(); // Simpan ID sesi aktif yang baru
    await _saveMessagesForCurrentChat(); // Simpan riwayat pesan kosong untuk sesi baru

    debugPrint(
      "_startNewChatSession: Sesi baru dimulai dengan ID: $newSessionId, Nama Awal: $initialChatName",
    );

    if (mounted) {
      setState(() {}); // Update UI untuk menampilkan sesi baru dan chat kosong
      if (!isInitial && Navigator.canPop(context)) {
        Navigator.pop(
          context,
        ); // Tutup drawer jika sedang terbuka dan ini bukan panggilan inisial
      }
    }
  }

  Future<void> _updateChatSessionName(String sessionId, String newName) async {
    int sessionIndex = _chatSessionsData.indexWhere(
      (session) => session['id'] == sessionId,
    );
    if (sessionIndex != -1) {
      // Pastikan nama tidak terlalu panjang untuk disimpan atau ditampilkan
      String finalNewName =
          newName.length > 50 ? newName.substring(0, 50) + "..." : newName;
      _chatSessionsData[sessionIndex]['name'] = finalNewName;
      await _saveChatSessionsData();
      debugPrint(
        "_updateChatSessionName: Nama sesi $sessionId diubah menjadi '$finalNewName'",
      );
      if (mounted) {
        setState(
          () {},
        ); // Refresh UI untuk AppBar dan Drawer agar nama baru tampil
      }
    } else {
      debugPrint(
        "_updateChatSessionName: Sesi dengan ID $sessionId tidak ditemukan untuk update nama.",
      );
    }
  }

  Future<void> _switchChatSession(String sessionId) async {
    debugPrint("_switchChatSession: Mencoba beralih ke sesi: $sessionId");
    if (_currentChatSessionId == sessionId && mounted) {
      debugPrint(
        "_switchChatSession: Sudah di sesi $sessionId. Menutup drawer.",
      );
      if (Navigator.canPop(context)) Navigator.pop(context);
      return;
    }

    _currentChatSessionId = sessionId;
    await _saveCurrentChatId(); // Simpan ID sesi yang baru dipilih
    await _loadMessagesForCurrentChat(); // Muat pesan untuk sesi tersebut (ini sudah ada setState di dalamnya)

    // Meskipun _loadMessagesForCurrentChat sudah setState, kita mungkin perlu setState lagi di sini
    // untuk memastikan AppBar title terupdate jika nama sesi yang dipilih berbeda dari yang ditampilkan sebelumnya.
    if (mounted) {
      setState(
        () {},
      ); // Pastikan UI (terutama AppBar) refresh dengan info sesi baru
      if (Navigator.canPop(context)) Navigator.pop(context); // Tutup drawer
      debugPrint("_switchChatSession: Berhasil beralih ke sesi: $sessionId");
    }
  }

  Future<void> _confirmDeleteChatSession(String sessionId) async {
    // Tutup drawer dulu agar dialog terlihat jelas
    if (Navigator.canPop(context)) {
      // Cek apakah drawer yang mau ditutup, atau modal lain.
      // Untuk simpel, kita pop saja. Jika ada modal lain, ini bisa jadi masalah.
      // Cara lebih aman adalah menggunakan GlobalKey untuk Drawer atau mengelola state drawer.
      // Navigator.pop(context);
    }

    final sessionNameToDelete = _getChatDisplayName(sessionId);

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Hapus Sesi Chat Ini?"),
          content: Text(
            "Apakah Anda yakin ingin menghapus sesi chat '$sessionNameToDelete' beserta seluruh riwayatnya? Tindakan ini tidak dapat diurungkan.",
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Tidak"),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text("Ya, Hapus", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      debugPrint(
        "_confirmDeleteChatSession: Konfirmasi hapus untuk sesi $sessionId.",
      );
      await _deleteChatSession(sessionId);
    }
  }

  Future<void> _deleteChatSession(String sessionId) async {
    _chatSessionsData.removeWhere((session) => session['id'] == sessionId);
    await _prefs.remove("$_chatHistoryPrefix$sessionId"); // Hapus riwayat pesan
    await _saveChatSessionsData(); // Simpan daftar sesi yang sudah diupdate
    debugPrint("_deleteChatSession: Sesi $sessionId dan riwayatnya dihapus.");

    // Jika sesi yang aktif saat ini adalah yang dihapus
    if (_currentChatSessionId == sessionId) {
      debugPrint("_deleteChatSession: Sesi yang aktif dihapus.");
      if (_chatSessionsData.isNotEmpty) {
        // Jika masih ada sesi lain, pindah ke sesi pertama dalam daftar
        _currentChatSessionId = _chatSessionsData.first['id'];
        debugPrint(
          "_deleteChatSession: Beralih ke sesi pertama yang tersisa: $_currentChatSessionId",
        );
        await _saveCurrentChatId();
        await _loadMessagesForCurrentChat(); // Muat pesan untuk sesi baru yang aktif
      } else {
        // Jika tidak ada sesi tersisa, buat sesi baru
        debugPrint(
          "_deleteChatSession: Tidak ada sesi tersisa. Memulai sesi baru.",
        );
        await _startNewChatSession(
          isInitial: false,
        ); // isInitial false agar setState dan pop drawer (jika ada) bekerja
      }
    }
    // Pastikan UI (terutama drawer) terupdate setelah penghapusan
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    if (_currentChatSessionId == null) {
      // Ini seharusnya tidak terjadi jika _initChat atau _startNewChatSession berjalan benar
      debugPrint(
        "_sendMessage: _currentChatSessionId null. Mencoba membuat sesi baru dulu.",
      );
      await _startNewChatSession(isInitial: false);
      if (_currentChatSessionId == null) {
        // Cek lagi setelah attempt membuat sesi baru
        debugPrint(
          "_sendMessage: Gagal membuat sesi baru. Pesan tidak terkirim.",
        );
        // Mungkin tampilkan pesan error ke pengguna
        return;
      }
    }

    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    // Cek apakah ini pesan pertama dari pengguna di sesi ini (untuk update nama sesi)
    final bool isFirstUserMessageInThisSession =
        _messages.where((m) => m['sender'] == 'user').isEmpty;

    // Tambahkan pesan pengguna ke UI dan list _messages
    final userMsgMap = {"sender": "user", "text": userMessage};
    if (mounted) {
      setState(() {
        _messages.add(userMsgMap);
        _controller.clear();
      });
    }
    await _saveMessagesForCurrentChat(); // Simpan setelah pesan pengguna ditambahkan

    // Update nama sesi jika ini adalah pesan pengguna pertama
    if (isFirstUserMessageInThisSession && _currentChatSessionId != null) {
      String newChatName = userMessage.substring(
        0,
        min(userMessage.length, 30),
      );
      if (userMessage.length > 30) newChatName += "...";
      await _updateChatSessionName(_currentChatSessionId!, newChatName.trim());
    }

    debugPrint(
      "_sendMessage: Mengirim pesan pengguna: '$userMessage'. Meminta respons bot.",
    );
    String botResponse = await _getResponseFromGemini(userMessage);
    final botMsgMap = {"sender": "bot", "text": botResponse};
    if (mounted) {
      setState(() {
        _messages.add(botMsgMap);
      });
    }
    await _saveMessagesForCurrentChat(); // Simpan setelah respons bot diterima
    debugPrint(
      "_sendMessage: Respons bot diterima ('$botResponse') dan disimpan.",
    );
  }

  Future<String> _getResponseFromGemini(String message) async {
    // Pastikan Anda menggunakan model yang valid dan Anda memiliki akses.
    // 'gemini-1.5-flash-latest' biasanya pilihan yang baik dan cepat.
    const String apiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";

    if (_apiKey == "" || _apiKey.isEmpty) {
      return "Error: API Key belum disetting.";
    }

    try {
      final response = await http.post(
        Uri.parse("$apiUrl?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                // Anda bisa menyesuaikan prompt ini jika perlu
                {
                  "text":
                      "Anda adalah asisten keuangan AI. Tanggapi pertanyaan pengguna seputar keuangan Investasi Dan keuangan lain nya. Pertanyaan: $message",
                },
              ],
            },
          ],
          // Tambahkan safety settings jika diperlukan
         "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
             {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
             {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"}
          ]
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        // Pemeriksaan yang lebih robust untuk struktur respons Gemini
        if (jsonResponse["candidates"] != null &&
            jsonResponse["candidates"] is List &&
            jsonResponse["candidates"].isNotEmpty &&
            jsonResponse["candidates"][0]["content"] != null &&
            jsonResponse["candidates"][0]["content"]["parts"] != null &&
            jsonResponse["candidates"][0]["content"]["parts"] is List &&
            jsonResponse["candidates"][0]["content"]["parts"].isNotEmpty &&
            jsonResponse["candidates"][0]["content"]["parts"][0]["text"] !=
                null) {
          return jsonResponse["candidates"][0]["content"]["parts"][0]["text"];
        } else if (jsonResponse["promptFeedback"] != null &&
            jsonResponse["promptFeedback"]["blockReason"] != null) {
          // Jika ada block reason dari safety settings
          String reason = jsonResponse["promptFeedback"]["blockReason"];
          String safetyRatingsInfo = "";
          if (jsonResponse["promptFeedback"]["safetyRatings"] != null) {
            safetyRatingsInfo =
                jsonResponse["promptFeedback"]["safetyRatings"].toString();
          }
          debugPrint(
            "_getResponseFromGemini: Respons diblokir oleh API karena: $reason. Safety ratings: $safetyRatingsInfo. Full response: ${response.body}",
          );
          return "Maaf, permintaan Anda tidak dapat diproses saat ini karena alasan keamanan ($reason).";
        } else {
          debugPrint(
            "_getResponseFromGemini: Struktur respons tidak sesuai atau kosong. Respons: ${response.body}",
          );
          if (jsonResponse["error"] != null &&
              jsonResponse["error"]["message"] != null) {
            return "Error dari API: ${jsonResponse["error"]["message"]}";
          }
          return "Maaf, saya tidak mendapatkan jawaban yang valid atau format respons tidak sesuai.";
        }
      } else {
        debugPrint(
          "_getResponseFromGemini: Kesalahan API: ${response.statusCode} - ${response.body}",
        );
        // Coba parse body error jika ada
        try {
          var errorJson = jsonDecode(response.body);
          if (errorJson["error"] != null &&
              errorJson["error"]["message"] != null) {
            return "Kesalahan API (${response.statusCode}): ${errorJson["error"]["message"]}";
          }
        } catch (e) {
          // Gagal parse body error, kembalikan body mentah
        }
        return "Kesalahan API: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint(
        "_getResponseFromGemini: Terjadi kesalahan (network atau lainnya): $e",
      );
      return "Terjadi kesalahan koneksi atau lainnya. Silakan coba lagi. ($e)";
    }
  }

  Future<void> _clearCurrentChatHistory() async {
    if (_messages.isEmpty || _currentChatSessionId == null) return;

    final sessionName = _getChatDisplayName(_currentChatSessionId!);
    bool confirmClear =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Hapus Riwayat Chat Ini?"),
              content: Text(
                "Apakah Anda yakin ingin menghapus seluruh riwayat chat untuk sesi '$sessionName'?",
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Tidak"),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text("Ya", style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false; // Default ke false jika dialog ditutup tanpa pilihan

    if (confirmClear) {
      if (mounted) {
        setState(() {
          _messages.clear();
        });
      }
      await _saveMessagesForCurrentChat(); // Simpan list pesan yang sudah kosong
      debugPrint(
        "_clearCurrentChatHistory: Riwayat untuk sesi $sessionName ($_currentChatSessionId) dihapus.",
      );
    }
  }

  void _editMessage(int index) {
    if (index < 0 ||
        index >= _messages.length ||
        _messages[index]["sender"] != "user") {
      debugPrint(
        "_editMessage: Index tidak valid ($index) atau bukan pesan pengguna.",
      );
      return;
    }
    final messageToEdit = _messages[index];
    if (messageToEdit['text'] == null) {
      debugPrint("_editMessage: Teks pesan pada index $index null.");
      return;
    }

    TextEditingController editController = TextEditingController(
      text: messageToEdit["text"],
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Edit Pesan"),
            content: TextField(
              controller: editController,
              decoration: InputDecoration(hintText: "Edit pesan Anda"),
              autofocus: true,
              maxLines: null, // Memungkinkan input multi-baris
            ),
            actions: [
              TextButton(
                child: Text("Batal"),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text("Simpan"),
                onPressed: () async {
                  String editedText = editController.text.trim();
                  if (editedText.isNotEmpty &&
                      editedText != messageToEdit["text"]) {
                    // Simpan pesan user yang diedit
                    if (mounted) {
                      setState(() {
                        _messages[index]["text"] = editedText;
                      });
                    }

                    // Hapus respons bot lama (jika ada) yang terkait dengan pesan user ini
                    // Respons bot biasanya berada di index + 1
                    if (index + 1 < _messages.length &&
                        _messages[index + 1]["sender"] == "bot") {
                      if (mounted) {
                        setState(() {
                          _messages.removeAt(index + 1);
                        });
                      }
                    }

                    // Dapatkan respons bot baru untuk teks yang diedit
                    debugPrint(
                      "_editMessage: Mendapatkan respons bot baru untuk teks yang diedit: '$editedText'",
                    );
                    String newBotResponse = await _getResponseFromGemini(
                      editedText,
                    );
                    if (mounted) {
                      setState(() {
                        // Sisipkan respons bot baru setelah pesan user yang diedit
                        _messages.insert(index + 1, {
                          "sender": "bot",
                          "text": newBotResponse,
                        });
                      });
                    }
                    await _saveMessagesForCurrentChat(); // Simpan semua perubahan
                    debugPrint(
                      "_editMessage: Pesan di index $index diedit menjadi '$editedText', respons bot diperbarui.",
                    );
                  }
                  Navigator.pop(context); // Tutup dialog edit
                },
              ),
            ],
          ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(int index) async {
    if (index < 0 || index >= _messages.length) {
      debugPrint("_showDeleteConfirmationDialog: Index tidak valid: $index");
      return;
    }

    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Konfirmasi Hapus"),
          content: Text("Apakah Anda yakin ingin menghapus pesan ini?"),
          actions: <Widget>[
            TextButton(
              child: Text("Tidak"),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text("Ya", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      bool isUserMessage = _messages[index]["sender"] == "user";
      List<Map<String, String>> messagesToRemove = [_messages[index]];

      // Jika pesan pengguna dihapus, dan ada respons bot tepat setelahnya, tandai juga untuk dihapus
      if (isUserMessage &&
          index + 1 < _messages.length &&
          _messages[index + 1]["sender"] == "bot") {
        messagesToRemove.add(_messages[index + 1]);
      }

      if (mounted) {
        setState(() {
          for (var msgToRemove in messagesToRemove.reversed) {
            // Hapus dari belakang agar index tetap valid
            _messages.remove(msgToRemove);
          }
        });
      }
      await _saveMessagesForCurrentChat();
      debugPrint(
        "_showDeleteConfirmationDialog: ${messagesToRemove.length} pesan dihapus.",
      );
    }
  }

  void _showMessageOptions(int index) {
    if (index < 0 || index >= _messages.length) {
      debugPrint("_showMessageOptions: Index tidak valid: $index");
      return;
    }

    showModalBottomSheet(
      context: context,
      builder:
          (bottomSheetContext) => Wrap(
            children: [
              if (_messages[index]["sender"] ==
                  "user") // Opsi edit hanya untuk pesan pengguna
                ListTile(
                  leading: Icon(Icons.edit_note_outlined, color: Colors.blue),
                  title: Text("Edit Pesan"),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    ); // Tutup bottom sheet dulu
                    _editMessage(index);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text("Hapus Pesan"),
                onTap: () {
                  Navigator.pop(bottomSheetContext); // Tutup bottom sheet dulu
                  _showDeleteConfirmationDialog(index);
                },
              ),
            ],
          ),
    );
  }

  String _getChatDisplayName(String? sessionId) {
    if (sessionId == null) return "Memuat..."; // Atau nama default jika ID null
    final session = _chatSessionsData.firstWhere(
      (s) => s['id'] == sessionId,
      // orElse: () => {'id': sessionId, 'name': 'Sesi Tidak Ditemukan'} // Fallback jika ID tidak ada di data
      orElse: () {
        // Ini seharusnya tidak terjadi jika logika benar, tapi sebagai fallback
        debugPrint(
          "_getChatDisplayName: Sesi dengan ID '$sessionId' tidak ditemukan di _chatSessionsData. Menggunakan ID sebagai nama.",
        );
        return {'id': sessionId, 'name': "Chat ($sessionId)"};
      },
    );
    return session['name'] ??
        sessionId; // Fallback jika nama null (seharusnya juga tidak terjadi)
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: <Widget>[
          // Header untuk drawer
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Riwayat Chat",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.add_comment_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Text(
              "Mulai Chat Baru",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () async {
              // Navigator.pop(context); // Akan ditutup oleh _startNewChatSession jika berhasil
              await _startNewChatSession(isInitial: false);
            },
          ),
          Divider(),
          Expanded(
            child:
                _chatSessionsData.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Belum ada riwayat chat tersimpan.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _chatSessionsData.length,
                      itemBuilder: (context, index) {
                        final sessionData = _chatSessionsData[index];
                        // Pastikan 'id' dan 'name' tidak null sebelum digunakan
                        final sessionId =
                            sessionData['id'] ?? 'error_id_${index}';
                        final sessionName =
                            sessionData['name'] ?? 'Tanpa Judul';

                        return ListTile(
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            color:
                                (sessionId == _currentChatSessionId)
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[700],
                          ),
                          title: Text(
                            sessionName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  (sessionId == _currentChatSessionId)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          selected: sessionId == _currentChatSessionId,
                          selectedTileColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          onTap: () => _switchChatSession(sessionId),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_forever_outlined,
                              color: Colors.redAccent[100],
                            ),
                            tooltip: "Hapus sesi chat ini",
                            onPressed:
                                () => _confirmDeleteChatSession(sessionId),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Judul AppBar akan diambil dari nama sesi yang sedang aktif
    String appBarTitle =
        _currentChatSessionId != null
            ? _getChatDisplayName(_currentChatSessionId!)
            : "Chat Keuangan";
    if (_currentChatSessionId == null &&
        _chatSessionsData.isEmpty &&
        _messages.isEmpty) {
      appBarTitle =
          "Mulai Chat Keuangan"; // Judul saat pertama kali buka dan belum ada apa2
    }

    debugPrint(
      "build: Membangun UI. Sesi aktif: $_currentChatSessionId ('$appBarTitle'), Jumlah pesan: ${_messages.length}",
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: TextStyle(fontSize: 18)),
        elevation: 1.0, // Sedikit shadow untuk AppBar
        actions: [
          // Tombol hapus riwayat untuk sesi chat yang aktif
          if (_messages.isNotEmpty && _currentChatSessionId != null)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined),
              tooltip: "Hapus semua pesan di chat ini",
              onPressed: _clearCurrentChatHistory,
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child:
                _messages.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          _currentChatSessionId == null &&
                                  _chatSessionsData.isEmpty
                              ? "Selamat datang! Mulai percakapan atau buka riwayat dari menu."
                              : "Tidak ada pesan dalam chat ini.\nKetik pesan Anda di bawah untuk memulai.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.5,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                    : ListView.builder(
                      reverse: false, // Pesan baru di bawah (default)
                      // Untuk scroll otomatis ke pesan terbaru, Anda perlu ScrollController
                      // dan panggil _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      // setiap kali pesan baru ditambahkan.
                      itemCount: _messages.length,
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        bool isUser = msg["sender"] == "user";
                        return GestureDetector(
                          onLongPress: () => _showMessageOptions(index),
                          child: Align(
                            alignment:
                                isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ), // Lebar bubble chat
                              padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              margin: EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isUser
                                        ? Theme.of(
                                          context,
                                        ).primaryColor.withAlpha(
                                          220,
                                        ) // Warna bubble pengguna
                                        : Colors.grey[300], // Warna bubble bot
                                borderRadius: BorderRadius.circular(
                                  16,
                                ), // Bubble lebih bulat
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg["text"] ?? "[Pesan kosong]",
                                style: TextStyle(
                                  fontSize: 15.5,
                                  color: isUser ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Divider(height: 1.0, thickness: 0.5),
          Container(
            // Container untuk input field agar bisa diberi style/padding
            color:
                Theme.of(context).cardColor, // Warna latar belakang area input
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ketik pertanyaan Anda...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          25.0,
                        ), // Input field lebih bulat
                        borderSide: BorderSide.none, // Hilangkan border default
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[200]
                              : Colors.grey[700], // Warna fill input
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ), // Padding dalam input field
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(width: 8),
                Material(
                  // Memberi efek ripple pada IconButton
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: _sendMessage,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
