LOADApp Documentation Overview 


LOADApp เป็นแอปพลิเคชันบนระบบปฏิบัติการ iOS 
ที่ออกแบบมาเพื่อการค้นหาเพลงและการจัดการคลังเพลงส่วนตัว 
โดยการทำงานเป็นการประสานกันระหว่าง Custom Backend 
Service (สำหรับการดึงข้อมูลแทร็ก) และ iTunes API 
(สำหรับการดึง Metadata 
และการสำรวจแค็ตตาล็อกเพลงที่ครอบคลุม) Data Sources 
แอปพลิเคชันใช้แหล่งข้อมูลหลัก 2 แหล่ง 
เพื่อมอบประสบการณ์การใช้งานที่สมบูรณ์: 1. Custom 
Server API - Base Endpoint: 
https://postauditory-unmanoeuvred-lizette.ngrok-free.dev
   > Note: ปัจจุบันใช้ Ngrok 
สำหรับสภาพแวดล้อมการพัฒนา (Development 
Environment)
   > - Role: ทำหน้าที่เป็นเอนจินหลักในการค้นหาแทร็ก 
จัดการคำขอการดาวน์โหลด และบันทึกประวัติการใช้งาน - 
Key Capabilities: - Search: 
ดำเนินการค้นหาแทร็กเพลงผ่าน Endpoint /search - 
Track Retrieval: 
ดึงข้อมูลรายละเอียดแทร็กรายบุคคลและลิงก์ดาวน์โหลดผ่าน 
/track/{key} - History Management: 
จัดเก็บและเรียกดูประวัติการค้นหาของผู้ใช้ผ่าน /history 
และ /history/{id} - Beatport Integration: 
ตรวจสอบและจับคู่แทร็ก ID จาก Beatport ผ่าน 
/beatport 2. iTunes API
 - Base Endpoint: https://itunes.apple.com - 
 Role: มอบข้อมูล Metadata ที่ครบถ้วน, ข้อมูลศิลปิน, 
 และภาพหน้าปกคุณภาพสูงเพื่อยกระดับประสบการณ์ผู้ใช้ - Key 
 Capabilities:
   - Artist Discovery: 
ค้นหาศิลปินและดึงข้อมูลโปรไฟล์โดยละเอียด
   - Discography Management: ดึงรายการอัลบั้ม, 
ซิงเกิล และ EP โดยเรียงลำดับตามวันที่วางจำหน่าย
   - Metadata Enrichment: 
เพิ่มเติมข้อมูลเพลงด้วยภาพหน้าปกความละเอียดสูง (สูงสุด 
500x500), วันที่วางจำหน่าย และข้อมูลลิขสิทธิ์
   - Audio Previews: มอบตัวอย่างเสียงความยาว 30 
วินาที สำหรับแทร็กที่ยังไม่ได้ดาวน์โหลดลงเครื่อง Key 
Features 1. Search & Download
 - Functionality: ช่วยให้ผู้ใช้สามารถค้นหาแทร็กผ่าน 
Custom Server API ได้อย่างรวดเร็ว
 - Implementation: จัดการคำขอค้นหาแบบ 
Asynchronous พร้อมแสดงสถานะการดาวน์โหลด 
(Progress Tracking) 
และระบบจัดการไฟล์ภายในเครื่องเพื่อการฟังแบบ Offline
 - User Experience: แสดงผลการค้นหาที่ชัดเจน พร้อมปุ่ม 
Action ที่เข้าใจง่ายสำหรับการดาวน์โหลดหรือจัดเก็บ 2. 
Artist Exploration
 - Functionality: 
เจาะลึกข้อมูลศิลปินและผลงานทั้งหมดผ่านฐานข้อมูลของ 
iTunes
 - Implementation: - ดึงรายละเอียดศิลปินโดยใช้ 
Search Entity musicArtist
   - ใช้ Endpoint lookup 
ในการคัดกรองอัลบั้มและซิงเกิลที่เกี่ยวข้อง
 - User Experience: หน้าโปรไฟล์ศิลปินที่สวยงาม 
แสดงรูปภาพศิลปิน, ผลงานล่าสุด 
และเพลงยอดนิยมในรูปแบบที่อ่านง่าย 3. New Releases
 - Functionality: 
แสดงรายการเพลงใหม่ล่าสุดที่คัดสรรมาเพื่อผู้ใช้
 - Implementation: ใช้ระบบ Filter จาก iTunes 
API เพื่อดึงเฉพาะประเภท "Single" หรือ "EP" 
ที่เพิ่งวางจำหน่าย
 - User Experience: แสดงผลในรูปแบบ Grid หรือ 
List ที่ทันสมัย พร้อมตัวเลือกการเรียงลำดับตามวันที่ (Sort 
by Date) 4. Metadata Enrichment & Sync
 - Functionality: 
เติมเต็มข้อมูลแทร็กโดยอัตโนมัติเพื่อให้คลังเพลงดูเป็นระเบียบ
 - Implementation: จับคู่แทร็กจาก Server 
เข้ากับฐานข้อมูล iTunes เพื่อดึงข้อมูลที่ขาดหาย เช่น 
releaseDate, copyright และ artworkURL 
ความละเอียดสูง
 - User Experience: ผู้ใช้จะได้คลังเพลงที่มีข้อมูลครบถ้วน 
พร้อมภาพหน้าปกที่สวยงามในระดับ Retina Display 5. 
Seamless Preview Playback
 - Functionality: 
ฟังตัวอย่างเพลงก่อนตัดสินใจดาวน์โหลด
 - Implementation: เชื่อมต่อกับ previewUrl จาก 
iTunes โดยมี AudioPlayerService 
ทำหน้าที่สลับการเล่นระหว่าง Streaming (ตัวอย่างเพลง) 
และ Local Files (เพลงที่ดาวน์โหลดแล้ว) อย่างราบรื่น
 - User Experience: มีตัวบ่งชี้ (Indicator) 
ที่ชัดเจนระหว่างโหมด Preview และ Full Track 
พร้อมปุ่มควบคุมการเล่นที่ตอบสนองไว Technical 
Architecture Services (Networking & Logic)
 - APIService (Singleton): 
เลเยอร์เครือข่ายส่วนกลางที่จัดการ HTTP Requests ทั้งหมด 
ใช้โครงสร้าง URLSession ร่วมกับ async/await 
เพื่อประสิทธิภาพสูงสุดและ Code ที่สะอาด
 - AudioPlayerService (ObservableObject): 
จัดการสถานะการเล่นเพลง, คิวเพลง, 
และเชื่อมต่อกับระบบควบคุมสื่อของ iOS 
(MPNowPlayingInfoCenter) รองรับทั้ง AVPlayer 
สำหรับการสตรีม และ AVAudioPlayer สำหรับไฟล์ในเครื่อง 
Models (Data Structure)
 - Track: โมเดลข้อมูลหลักที่ออกแบบมาให้รองรับ 
Response จาก Custom Server API 
และจัดเก็บสถานะภายในแอป
 - iTunesSearchResult: โมเดลที่มีความยืดหยุ่นสูง 
(Decodable) สำหรับการ Mapping ข้อมูลที่หลากหลายจาก 
iTunes ไม่ว่าจะเป็น ศิลปิน, อัลบั้ม หรือแทร็กเพลง UI 
Components & Design
 - SwiftUI Framework: ใช้ในการสร้าง Interface 
ที่ทันสมัยและรองรับการแสดงผลทุกขนาดหน้าจอ
 - Navigation: ออกแบบเป็น Tab-based Navigation 
แบ่งสัดส่วนชัดเจนระหว่าง Search, Library, และ 
Settings
 - Modular Views: แยกส่วนประกอบ UI เป็นโมดูลย่อย 
เช่น TrackRow, ArtistGridView, และ 
PlayerBackgroundView เพื่อการซ่อมบำรุงที่ง่าย 
(Maintainability)

API Endpoints

General
GET /: Service status.
GET /health: Database connection health check.

Search
GET /search?track={query}: Search for tracks (scrapes external sources).
GET /track/{track_key}: Get specific track details by key.

Beatport
GET /beatport
Description: Find a Beatport track ID by artist, title, and mix name.
Parameters:
artist (string, required): Artist name.
title (string, required): Track title.
mix (string, optional): Mix name (e.g., "Extended Mix").
Response:
{
  "track_id": 12345678,
  "track_url": "http://url.com"
}
History

GET /history: List search history.
GET /history/{search_id}: Get details of a past search.
DELETE /delete: Clear all history.
DELETE /delete/{search_id}: Delete a specific history item. 
