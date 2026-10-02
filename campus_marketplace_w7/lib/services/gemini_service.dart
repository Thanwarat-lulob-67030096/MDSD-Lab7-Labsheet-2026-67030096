import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // ใช้โมเดล gemini-1.5-flash ตามมาตรฐานปัจจุบัน
  static const String _model = 'gemini-1.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // ดึงค่า API Key ผ่าน --dart-define=GEMINI_API_KEY=your_key (ไม่ต้องใส่ Key ตรง ๆ ในโค้ด)
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<String> generateText(String prompt) async {
    final uri = Uri.parse('$_baseUrl?key=$_apiKey');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 20),
          ); // กำหนด Timeout 20 วินาทีสำหรับ Generative AI

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // ตรวจสอบว่ามี candidates และมีข้อมูลตอบกลับจริงหรือไม่
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('ไม่พบข้อมูลคำตอบจาก Gemini (Candidates ว่างเปล่า)');
        }

        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          throw Exception('โครงสร้างคำตอบไม่ถูกต้อง');
        }

        return parts[0]['text'] as String? ?? 'ไม่มีข้อความตอบกลับ';
      } else {
        throw Exception(
          'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (สถานะ ${response.statusCode})',
        );
      }
    } on TimeoutException {
      throw Exception(
        'การเชื่อมต่อกับ Gemini API หมดเวลา กรุณาลองใหม่อีกครั้ง',
      );
    } on http.ClientException {
      throw Exception(
        'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ',
      );
    } catch (e) {
      rethrow;
    }
  }
}
