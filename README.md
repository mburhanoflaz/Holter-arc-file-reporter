# Holter-arc-file-reporter

[🇹🇷 Türkçe](#-türkçe) | [🇬🇧 English](#-english)

---

## 🇹🇷 Türkçe

### Kullanım Amacı
Bu masaüstü uygulaması, Çin menşeyli Holter EKG analiz yazılımı tarafından dışa aktarılan **`.arc`** uzantılı ham hasta kayıt dosyalarını herhangi bir üçüncü parti kütüphaneye veya harici araca ihtiyaç duymadan doğrudan çözümlemek ve klinik düzeyde **Kalp Hızı Değişkenliği (HRV)** analizi yapmak amacıyla geliştirilmiştir.

Uygulama, ikili (binary) konteyner içerisindeki 3 kanallı (128 Hz, Little-Endian 16-bit) ham EKG sinyallerini ve atım işaretleyicilerini (`beats.atr`) ayrıştırır. Ektopik atımları (SVE/VE) ve rapor dışı işaretçileri otomatik filtreleyerek saf **NN (Normal-to-Normal)** aralıklarını izole eder; hem Zaman Alanı (Time-Domain) hem de Welch FFT tabanlı Frekans Alanı (Frequency-Domain) sirkadiyen otonom denge parametrelerini hesaplar.

### Temel Özellikler
* **`.arc` Konteyner Ayrıştırıcı:** Hasta dosyasındaki tüm alt dosyaları (`ecgraw.dat`, `beats.atr`, `report.rdf`, `patient.hea` vb.) okur ve tek tıkla seçilen bir klasöre dışa aktarabilir.
* **Ektopik Filtreli Gerçek NN İzolasyonu:** Cihazın R-tepe indekslerini ve atım sınıfı bayraklarını kullanarak gürültü ve ektopik (SVE/VE) atımları analiz dışı bırakır.
* **Kapsamlı HRV Metrikleri:**
  * **Zaman Alanı:** Ortalama/Min/Maks HR, SDNN, SDNN Index, SDANN, rMSSD, pNN50 ve HRV Triangular Index.
  * **Frekans Alanı & Sirkadiyen Analiz:** 24 saatlik, Gündüz (08:00–22:00) ve Gece (23:00–06:00) dilimleri için Total Power, VLF, LF, HF, LF/HF oranı, Sempatik Modülasyon (`LF nu %`), Parasempatik Aktivite (`HF nu %`) ve Sirkadiyen İndeks.
* **Görselleştirme:** 24 saatlik NN Takogramı, Saatlik Sempatik/Parasempatik denge grafiği, Poincaré (Lorenz) diyagramı ve 3 kanallı ham EKG önizleme ekranı.
* **RTF Klinik Rapor Çıktısı:** Analiz sonuçlarını düzenlenebilir zengin metin biçiminde oluşturur ve `.rtf` belgesi olarak kaydeder.

### Kullanım Yönergesi
1. **Derleme (İsteğe Bağlı):** Projeyi **Delphi 13 CE (Community Edition)** ile açıp (`ArcHrvAnalyzer.dpr`) doğrudan Windows çalıştırılabilir dosyası (`.exe`) olarak derleyin. Harici bir bileşen paketi kurulumu gerektirmez.
2. **Dosya Seçimi:** Programı açın ve **`1. .ARC Dosyası Seç...`** butonuna tıklayarak hasta kaydını (`*.arc`) yükleyin.
3. **Takılış Saati Ayarı:** Kayıt başlangıç saati `patient.hea` içinden okunamazsa varsayılan olarak **`10` (10:00 AM)** kullanılır; gerekirse üst çubuktan değiştirebilirsiniz.
4. **Analiz:** **`2. Analizi Başlat`** butonuna basın. Hesaplanan tüm zaman/frekans tabloları, grafikler ve saatlik dökümler ilgili sekmelerde görüntülenecektir.
5. **Dışa Aktarma:**
   * Klinik raporu kaydetmek için **`Raporu .RTF Kaydet...`** butonunu kullanın.
   * `.arc` paketinin içindeki ham veri dosyalarını çıkarmak için **`.ARC İçeriğini Klasöre Çıkar...`** butonunu kullanın.

---

## 🇬🇧 English

### Purpose
This Windows desktop application is designed to natively parse **`.arc`** Holter patient record files exported from China made ECG analysis software and perform clinical-grade **Heart Rate Variability (HRV)** analysis without relying on external libraries or paid third-party components.

The software decodes the 3-channel (128 Hz, Little-Endian 16-bit) raw ECG waveforms and beat annotation records (`beats.atr`) directly from the binary container. By automatically excluding ectopic beats (SVE/VE) and non-beat markers, it isolates pure **NN (Normal-to-Normal)** intervals to compute both Time-Domain and Welch FFT-based Frequency-Domain circadian autonomic balance metrics.

### Key Features
* **`.arc` Container Extractor:** Parses internal sub-files (`ecgraw.dat`, `beats.atr`, `report.rdf`, `patient.hea`, etc.) and allows extracting all embedded files into a target folder with a single click.
* **Ectopic-Filtered Pure NN Isolation:** Uses native R-peak sample indices and beat classification bitmasks to exclude ectopic beats and artifacts.
* **Comprehensive HRV Metrics:**
  * **Time-Domain:** Mean/Min/Max HR, SDNN, SDNN Index, SDANN, rMSSD, pNN50, and HRV Triangular Index.
  * **Frequency-Domain & Circadian Balance:** Total Power, VLF, LF, HF, LF/HF ratio, Sympathetic Modulation (`LF nu %`), Parasympathetic Activity (`HF nu %`), and Circadian Index across 24-hour, Daytime (08:00–22:00), and Nighttime (23:00–06:00) periods.
* **Interactive Visualization:** Custom-drawn 24-hour NN Tachogram, Hourly Sympathetic/Parasympathetic bar chart, Poincaré (Lorenz) plot, and 3-channel raw ECG waveform viewer.
* **RTF Clinical Report Export:** Generates a formatted, editable clinical report and exports it as a `.rtf` document.

### Usage Guide
1. **Build (Optional):** Open `ArcHrvAnalyzer.dpr` in **Delphi 13 CE (Community Edition)** and compile to a standalone Windows `.exe`. No third-party packages are required.
2. **Load File:** Launch the application and click **`1. .ARC Dosyası Seç...`** (*Select .ARC File*) to load a Holter recording (`*.arc`).
3. **Start Hour Configuration:** If the recording start time is not present in `patient.hea`, the application defaults to **`10` (10:00 AM)**, which can be adjusted in the top toolbar.
4. **Run Analysis:** Click **`2. Analizi Başlat`** (*Start Analysis*). View the summary tables, charts, hourly breakdowns, and 3-channel ECG preview across the tabs.
5. **Export Outputs:**
   * Click **`Raporu .RTF Kaydet...`** (*Save Report as .RTF*) to export the clinical report.
   * Click **`.ARC İçeriğini Klasöre Çıkar...`** (*Extract .ARC Contents to Folder*) to unpack all internal files.
