import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const AaradhanaDownloaderApp());
}

class AaradhanaDownloaderApp extends StatelessWidget {
  const AaradhanaDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'આરાધના Downloader VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFFF2A4B),
      ),
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusMessage = "";
  bool _isSuccess = false;

  final String _apiKey = "2a2d800e5cmsh0798dd20ef51d17p1d9715jsn2c69b2d0f7d3";
  final String _apiHost = "youtube-mp4-mp3-downloader.p.rapidapi.com";

  String _extractVideoId(String url) {
    if (url.contains("youtu.be/")) {
      return url.split("youtu.be/")[1].split("?")[0].trim();
    } else if (url.contains("v=")) {
      return url.split("v=")[1].split("&")[0].trim();
    } else if (url.contains("embed/")) {
      return url.split("embed/")[1].split("?")[0].trim();
    }
    return url.trim();
  }

  Future<Directory?> _prepareStorageFolder() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final dir = Directory('/storage/emulated/0/RajuBhai');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }
    return null;
  }

  Future<void> _saveFile(List<int> bytes, String prefix, String extension) async {
    final folder = await _prepareStorageFolder();
    if (folder == null) throw Exception("સ્ટોરેજ પરમિશન નથી મળી!");
    
    final fileName = "${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension";
    final file = File("${folder.path}/$fileName");
    await file.writeAsBytes(bytes);
  }

  Future<void> _playSuccessAudio() async {
    try {
      await _audioPlayer.play(AssetSource('raju_bhai.mp3'));
    } catch (e) {
      debugPrint("ઓડિયો પ્લે કરવામાં એરર: $e");
    }
  }

  Future<void> _startDownloadProcess(bool isAudio) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _statusMessage = "❌ કૃપા કરીને પહેલા યુટ્યુબ લિંક નાખો!");
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _statusMessage = "🚀 સર્વર સાથે કનેક્ટ થઈ રહ્યું છે...";
      _isSuccess = false;
    });

    final videoId = _extractVideoId(rawUrl);
    
    try {
      final response = await http.get(
        Uri.parse("https://$_apiHost/api/v1/download?format=720&id=$videoId&audioQuality=128&addInfo=false&allowExtendedDuration=false"),
        headers: {
          "x-rapidapi-key": _apiKey,
          "x-rapidapi-host": _apiHost
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? dlUrl;
        
        if (isAudio) {
          dlUrl = data['audioUrls']?[0];
        } else {
          dlUrl = data['videoUrls']?[0]?['url'];
        }
        
        if (dlUrl != null) {
          bool success = await _downloadBinaryWithProgress(dlUrl, isAudio ? "MP3" : "MP4");
          setState(() {
            _isLoading = false;
            if (success) {
              _progress = 1.0;
              _isSuccess = true;
              _statusMessage = "✅ 'RajuBhai' ફોલ્ડરમાં સફળતાપૂર્વક સેવ થઈ ગયું!";
              _playSuccessAudio();
            } else {
              _statusMessage = "❌ ડાઉનલોડ ફેલ થયું! વીઆઈપી લિમિટ તપાસો.";
            }
          });
        } else {
          setState(() {
            _isLoading = false;
            _statusMessage = "❌ લિંક મેળવવામાં સમસ્યા આવી અથવા લિમિટ પૂરી થઈ ગઈ છે!";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = "❌ સર્વર એરર: તમારી મંથલી લિમિટ પૂરી થઈ ગઈ લાગે છે!";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "❌ કોઈ ભૂલ આવી: $e";
      });
    }
  }

  Future<bool> _downloadBinaryWithProgress(String url, String type) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) return false;

      final totalBytes = response.contentLength ?? 0;
      List<int> bytes = [];
      num lastProgress = -1;

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        if (totalBytes > 0) {
          double currentProgress = bytes.length / totalBytes;
          int percent = (currentProgress * 100).toInt();
          if (percent != lastProgress) {
            lastProgress = percent;
            setState(() {
              _progress = currentProgress;
              _statusMessage = "📥 ડાઉનલોડ થઈ રહ્યું છે: $percent%";
            });
          }
        }
      }

      await _saveFile(bytes, "RajuBhai", type.toLowerCase());
      return true;
    } catch (_) { return false; }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFFF2A4B),
            ),
            child: const Center(
              child: Text(
                "Welcome to Raju Bhai",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF2A4B), width: 3),
                      image: const DecorationImage(
                        image: AssetImage('assets/profile.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "આરાધના Downloader VIP",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 35),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'અહીં યુટ્યુબ લિંક પેસ્ટ કરો...',
                      hintStyle: const TextStyle(color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFF2A4B), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _startDownloadProcess(true),
                    icon: const Icon(Icons.music_note, color: Colors.white),
                    label: const Text("🎵 Download MP3 (ઓડિયો)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2A4B),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _startDownloadProcess(false),
                    icon: const Icon(Icons.movie, color: Colors.white),
                    label: const Text("🎥 Download Video (વિડિયો)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_isLoading || _statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    if (_isLoading)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2A4B)),
                          minHeight: 6,
                        ),
                      ),
                    const SizedBox(height: 15),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green[700] : (_statusMessage.startsWith("❌") ? Colors.red[700] : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
