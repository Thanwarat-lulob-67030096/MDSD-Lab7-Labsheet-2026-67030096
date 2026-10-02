import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/listing_draft.dart';

class GeminiVisionService {
  // อ่านค่า API Key จาก --dart-define=GEMINI_API_KEY=your_key
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // ชื่อโมเดลตามรายชื่อที่ ai.google.dev/gemini-api/docs/models
  static const String _model = 'gemini-3.8-flash';

  // Prompt เดียวกับที่ทดลองใน AI Studio ส่วนที่ 1
  // (ส่วนที่ 6: แก้ข้อความระหว่าง ''' กับ ''' ตรงนี้ชั่วคราวเพื่อทดสอบ แล้วอย่าลืมเปลี่ยนกลับ)
  static const String _prompt = '''
คุณคือผู้ช่วยเขียนประกาศขายของมือสองในตลาดนัดออนไลน์สำหรับนักศึกษามหาวิทยาลัย
จากรูปภาพสินค้าที่แนบมา ให้วิเคราะห์แล้วตอบกลับเป็น JSON เท่านั้น ตามโครงสร้างนี้:
{
  "title": "ชื่อประกาศสั้นกระชับ ไม่เกิน 40 ตัวอักษร",
  "category": "หมวดหมู่ที่เหมาะสมที่สุด เลือกจาก: หนังสือเรียน, อุปกรณ์อิเล็กทรอนิกส์, ของแต่งหอพัก, เสื้อผ้า, อื่นๆ",
  "description": "คำบรรยายสินค้า 2-3 ประโยค ที่ดึงดูดผู้ซื้อและบอกสภาพของสินค้าตามที่เห็นในภาพ"
}
ห้ามตอบข้อความอื่นนอกเหนือจาก JSON ดังกล่าว
''';

  Future<ListingDraft> analyzeProductImage(File imageFile) async {
    // 1) อ่านไฟล์ภาพเป็นไบต์ แล้วเข้ารหัส Base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // 2) เดา mime type จากนามสกุลไฟล์
    final path = imageFile.path.toLowerCase();
    String mimeType = 'image/jpeg';
    if (path.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (path.endsWith('.webp')) {
      mimeType = 'image/webp';
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );

    try {
      // 3) ส่ง Prompt และรูปภาพใน parts เดียวกัน พร้อม responseSchema
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Image,
                      },
                    },
                  ],
                },
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'responseSchema': {
                  'type': 'OBJECT',
                  'properties': {
                    'title': {'type': 'STRING'},
                    'category': {'type': 'STRING'},
                    'description': {'type': 'STRING'},
                  },
                  'required': ['title', 'category', 'description'],
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      // 4) ตรวจ Status Code
      if (response.statusCode != 200) {
        throw Exception(
          'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (สถานะ ${response.statusCode})',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // 5) ตรวจว่า candidates มีข้อมูลจริง
      final candidates = body['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception(
          'AI ไม่สามารถวิเคราะห์ภาพนี้ได้ อาจเข้าข่ายเนื้อหาที่ไม่เหมาะสม ลองใช้ภาพอื่น',
        );
      }

      final candidate = candidates[0] as Map<String, dynamic>;

      if (candidate['finishReason'] == 'SAFETY') {
        throw Exception(
          'เนื้อหาที่วิเคราะห์เข้าข่ายไม่ปลอดภัยตามนโยบายของ Gemini กรุณาใช้ภาพอื่น',
        );
      }

      final parts = (candidate['content']?['parts']) as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('AI ไม่ได้ส่งผลลัพธ์กลับมา กรุณาลองใหม่อีกครั้ง');
      }

      // 6) jsonDecode ชั้นที่สอง: text ที่ได้เป็น JSON string อีกชั้น
      final text = parts[0]['text'] as String;
      final json = jsonDecode(text) as Map<String, dynamic>;
      return ListingDraft.fromJson(json);
    } on TimeoutException {
      throw Exception('การเชื่อมต่อหมดเวลา กรุณาลองใหม่อีกครั้ง');
    } on SocketException {
      throw Exception(
        'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ',
      );
    } on FormatException {
      throw Exception('ข้อมูลที่ได้รับจาก AI ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง');
    }
  }
}
