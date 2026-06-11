# MODUL_FORMULLERI.md — Parça, Kesim ve Bantlama Formülleri (Tek Doğruluk Kaynağı)

> **BU DOSYA ÜRETİM KRİTİĞİDİR.** Kesim listesi, bantlama listesi ve malzeme/maliyet hesabı
> YALNIZCA buradaki formüllerden üretilir. Her formül `test/modules/` altında birim testiyle
> doğrulanmadan koda alınmaz. Buradaki bir hata ustaya plaka/işçilik kaybı olarak döner.

---

## 0. Global Parametreler ve Sözleşmeler

Tüm ölçüler **mm**. Tüm parça ölçüleri `EN × BOY` formatında; BOY = damar/desen yönü.

| Sembol | Anlam | Varsayılan | Ayarlanabilir mi |
|---|---|---|---|
| `t` | Gövde plaka kalınlığı | 18 | Evet (16/18) |
| `ta` | Arkalık kalınlığı | 8 | Evet (3/8) |
| `G` | Modül dış genişliği | — | Modül başına |
| `Y` | Gövde yüksekliği (baza hariç) | Alt: 740 · Üst: 720 · Boy: 2080 | Evet |
| `D` | Gövde derinliği | Alt: 560 · Üst: 320 · Boy: 560 | Evet |
| `bz` | Baza yüksekliği | 100 | Evet |
| `g` | Kapaklar arası boşluk | 3 | Evet |
| `r` | Modül kenarı kapak payı (reveal) | 2 (her yan) | Evet |
| `rf` | Raf ön geri çekme | 30 | Evet |
| `kayıt_h` | Üst kayıt eni | 100 | Evet |
| `ray_payı` | Çekmece ray boşluğu (her yan) | Teleskopik: 13 · Tandem: 12.5 | Ray tipine göre |
| `arka_tip` | Arkalık montajı | `cakma` (üstten çakma) | `kanal` seçilebilir |
| `k` | Kanal derinliği (arka_tip=kanal) | 8 | Evet |

### 0.1 Kapak/Çekmece Önü Genel Formülü (tam bindirme — full overlay)
```
Kullanılabilir genişlik:  W_kul = G − 2r
n adet yan yana ön:       her ön genişliği = (W_kul − (n−1)·g) / n
Ön yüksekliği (tek sıra): H_on = Y − 2r
m adet üst üste ön:       her ön yüksekliği = (H_on − (m−1)·g) / m
```

### 0.2 ⚠️ BANT DÜŞÜMÜ KURALI (kesim listesi doğruluğunun 1. şartı)
Parça tablolarındaki ölçüler **NET (bitmiş) ölçüdür**. Kesim ölçüsü, bantlanan her kenardan
bant kalınlığı düşülerek bulunur:
```
KESİM_EN  = NET_EN  − (sol bant kalınlığı + sağ bant kalınlığı)
KESİM_BOY = NET_BOY − (üst bant kalınlığı + alt bant kalınlığı)
```
- Bant kalınlığı < 1 mm (0.4 mm) ise düşüm **yapılmaz** (tolerans içinde, ayarla açılabilir).
- Bant kalınlığı ≥ 1 mm (1 / 2 mm PVC) ise düşüm **zorunludur**.
- Örnek: 2 mm bantlı 4 kenarı bantlı kapak, NET 497×736 → KESİM 493×732.
- Testere payı (kerf) parça listesine **eklenmez**; optimizasyon motoru plaka yerleşiminde uygular.

### 0.3 Bant Kenar Gösterimi
Her parçada bant `[Ö,A,S,Sğ]` = [Ön, Arka, Sol, Sağ] kenar; değer = bant kalınlığı mm (0 = bantsız).
Gövde parçaları **gövde rengi** bandı, ön yüzler (kapak/çekmece önü) **kapak rengi** bandı alır.
Bant genişliği satın alma kuralı: plaka kalınlığı + 4 mm (18 mm plaka → 22 mm bant).
**Bant metrajı** = Σ(bantlı kenar uzunlukları) × 1.10 (fire %10), renk+kalınlık bazında gruplanır.

### 0.4 Donanım Kuralları (otomatik adet)
```
MENTEŞE (kapak yüksekliğine göre):  ≤900→2 · 901–1600→3 · 1601–2000→4 · >2000→5
   Cam kapakta cam menteşesi kullanılır (ayrı kalem).
RAY: çekmece başına 1 çift. Boy = D − 60, aşağı yuvarla standart: {250,300,350,400,450,500}.
   (D=560 → 500 mm ray)
KULP: ön yüz (kapak + çekmece önü) başına 1.
BAZA AYAĞI: alt hat boyunca her 500 mm'de 1 çift köşe mantığıyla → adet = max(4, ceil(G/500)×2) modül başına;
   hat bazında birleşik hesaplanır (komşu modüller ayak paylaşır): adet_hat = (ΣG/500 yukarı yuvarla +1) × 2.
ASKI (üst dolap): modül başına 2 + askı rayı G uzunluğunda (hat bazında birleştirilir).
KAVELA: gövde birleşim kenarı başına 3 · MİNİFİKS: birleşim başına 2 set (ayardan biri seçilir).
VİDA 3.5×16 (arkalık çakma): çevre/150 mm başına 1.
```

### 0.5 Üretim Güvenlik Kontrolleri (kod bunları ZORUNLU uygular)
1. `KESİM_EN > plaka_en − 2·traş` veya `KESİM_BOY > plaka_boy − 2·traş` → **HATA, listeye alma**, ustayı uyar.
2. Σ(modül G) + dolgu çıtaları = duvar ölçüsü ±2 mm değilse → otomatik **dolgu çıtası** parçası üret (bkz. D1) veya uyar.
3. Modül G < 200 veya G > 1200 → uyarı (köşe/dolgu hariç).
4. Çekmece önü yüksekliği < 90 → hata (ray sığmaz).
5. Damar yönlü malzemede kapak BOY ekseni = dikey zorunlu; optimizasyonda döndürme kilitli.
6. Aynı projede gövde ve kapak farklı kalınlıktaysa formüller ilgili `t` ile ayrı ayrı çalışır.

---

## 1. ALT MODÜLLER

### A1 — Alt Dolap, Tek Kapak (G ≤ 600)
Parametre: G, Y=740, D=560, raf sayısı n_raf (vars. 1)

| # | Parça | Adet | NET EN | NET BOY | Bant [Ö,A,S,Sğ] | Malzeme |
|---|---|---|---|---|---|---|
| 1 | Yan | 2 | D | Y | [1,0,0,0]* | Gövde |
| 2 | Alt tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 3 | Ön üst kayıt | 1 | G−2t | kayıt_h | [1,0,0,0] | Gövde |
| 4 | Arka üst kayıt | 1 | G−2t | kayıt_h | [0,0,0,0] | Gövde |
| 5 | Raf | n_raf | G−2t−2 | D−rf | [1,0,0,0] | Gövde |
| 6 | Arkalık (çakma) | 1 | G−4 | Y−4 | [0,0,0,0] | Arkalık 8mm |
| 6' | Arkalık (kanal) | 1 | G−2t+2k | Y−2t+2k | [0,0,0,0] | Arkalık 8mm |
| 7 | Kapak | 1 | G−2r | Y−2r | [2,2,2,2]** | Kapak |

\* Yan panelde bantlı kenar = ÖN dikey kenar (boy yönü kenarı). Hat sonundaki (görünür) yan panel ayrıca dış yüz görünür → ayar `görünür_yan=true` ise o yan **kapak malzemesinden** kesilir ve [1,0,1,1] bantlanır.
\** Kapak bandı kapak rengi, kalınlık ayardan (vars. 2 mm → bant düşümü uygulanır: KESİM = (G−2r−4)×(Y−2r−4)).
Donanım: menteşe(0.4 kuralı: kapak 736 → 2), kulp 1, kavela/minifix birleşim: 4 birleşim kenarı.

### A2 — Alt Dolap, Çift Kapak (600 < G ≤ 1200)
A1 ile aynı gövde (satır 1–6). Fark:

| 7 | Kapak | 2 | (G−2r−g)/2 | Y−2r | [2,2,2,2] | Kapak |

Donanım: menteşe 2×2=4, kulp 2.
Opsiyon `orta_dikme=true` (G>900 önerilir): Orta dikme ×1 = (Y−t) BOY × (D−ta) EN, bant [1,0,0,0]; raflar ikiye bölünür: her raf EN = (G−3t−2)/2.

### A3 — Alt Çekmeceli (n_cek = 2/3/4)
Gövde: A1 satır 1–4 + 6 (raf YOK).
Çekmece önleri (eşit bölüm; `ilk_kucuk=true` ise üst ön 140 sabit, kalan eşit):

| 7 | Çekmece önü | n_cek | G−2r | (Y−2r−(n_cek−1)·g)/n_cek | [2,2,2,2] | Kapak |

Çekmece kutusu (gövde malzemesinden, kutu yüksekliği h_k = ön yüksekliği − 30, min 90, max 180; derin çekmecede 180 sabit + iç bölme yok):
```
box_dış_en  = G − 2t − 2·ray_payı        (teleskopik: G − 62)
ray_boy L_r = D − 60 → standart yuvarla   (560 → 500)
```
| 8 | Kutu yanı | 2·n_cek | L_r | h_k | [üst kenar 0.4] | Gövde |
| 9 | Kutu ön/arka | 2·n_cek | box_dış_en − 2t | h_k | [üst 0.4] | Gövde |
| 10 | Kutu dibi (çakma) | n_cek | box_dış_en | L_r | [0,0,0,0] | Arkalık 8mm |

Donanım: ray n_cek çift (L_r), kulp n_cek. Menteşe yok.

### A4 — Evye Dolabı (G = 600–1000, çift kapak)
A2'den farklar:
- Arkalık **YOK** (tesisat). Yerine: Arka bağlantı kaydı ×1 = (G−2t)×kayıt_h, bantsız.
- Raf default 0 (sifon).
- Alt tabla 4 kenar 1 mm bant önerilir (su koruması): [1,1,1,1].
- Ön üst kayıt evye gövdesine göre yerinde kesilebilir → nota düşülür, ölçü aynı.
Donanım: A2 ile aynı.

### A5 — Ankastre Fırın Modülü (G = 600)
Fırın boşluğu yüksekliği `fb = 595` (sabit, ankastre standardı). Üstte kalan (Y − fb − t) çekmece/sabit ön olur.

| 1 | Yan | 2 | D | Y | [1,0,0,0] | Gövde |
| 2 | Alt tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 3 | Fırın üstü tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 4 | Arka üst kayıt | 1 | G−2t | kayıt_h | [0,0,0,0] | Gövde |
| 5 | Arkalık (yalnız üst bölge) | 1 | G−4 | Y−fb−t−4 | [0,0,0,0] | Arkalık |
| 6 | Üst ön (çekmece/sabit) | 1 | G−2r | Y−fb−t−2r | [2,2,2,2] | Kapak |

Üst ön çekmeceyse A3 kutu formülleri (n=1, h_k=ön−30) eklenir. Donanım: çekmeceyse ray 1 çift + kulp 1.
Kontrol: Y−fb−t ≥ 110 değilse sabit panel yapılır (çekmece sığmaz).

### A6 — Bulaşık Makinesi Boşluğu (G = 450/600)
Yalnız yapısal parçalar (makine ankastre):

| 1 | Yan* | 0–2 | D | Y | [1,0,0,0] | Gövde |
| 2 | Üst bağlantı kaydı | 1 | G−(komşu yan sayısı)·t | kayıt_h | [1,0,0,0] | Gövde |

\* Komşu modülün yanı varsa paylaşılır → adet 0; hat sonundaysa 1 görünür yan (kapak malzemesi, [1,0,1,1]).
Donanım: yok. Baza önü hat hesabında bu genişliği atlar (makine bazası kendi panelidir → opsiyon `baza_devam=false`).

### A7 — Alt Köşe Dolap L (G1 × G2, vars. 900×900, tek kör kapak)
Kör dolgu `kd = 80` (komşu kapağın açılma payı).

| 1 | Yan (duvar tarafı) | 2 | D | Y | [1,0,0,0] | Gövde |
| 2 | Alt tabla parça-1 | 1 | G1−t | D | [1,0,0,0] | Gövde |
| 3 | Alt tabla parça-2 | 1 | G2−D−t | D | [1,0,0,0] | Gövde |
| 4 | Ön üst kayıt ×2 | 2 | (ilgili açıklık) | kayıt_h | [1,0,0,0] | Gövde |
| 5 | Kör dolgu paneli | 1 | kd | Y | [1,0,0,0] | Kapak |
| 6 | Arkalık ×2 | 2 | (G1−4) ve (G2−D−4) | Y−4 | [0,0,0,0] | Arkalık |
| 7 | Kapak | 1 | G1−D−kd−2r | Y−2r | [2,2,2,2] | Kapak |

Raf: L-raf yerine 2 parça düz raf (üretim kolaylığı). Donanım: menteşe 2 (175° geniş açı menteşe kalemi), kulp 1.

---

## 2. ÜST MODÜLLER (D = 320, Y = 720 vars.)

### U1 — Üst Dolap, Tek Kapak (G ≤ 600)
| 1 | Yan | 2 | D | Y | [1,0,0,0] | Gövde |
| 2 | Alt tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 3 | Üst tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 4 | Raf | n_raf (vars. 2) | G−2t−2 | D−rf | [1,0,0,0] | Gövde |
| 5 | Arkalık (çakma) | 1 | G−4 | Y−4 | [0,0,0,0] | Arkalık |
| 6 | Kapak | 1 | G−2r | Y−2r | [2,2,2,2] | Kapak |

Donanım: menteşe (716→2), kulp 1, askı 2 + askı rayı (hat bazında ΣG).
Not: Üst dolapta alt VE üst tabla tamdır (alt görünür → ön bant şart). Hat sonu görünür yan kuralı A1 ile aynı.

### U2 — Üst Çift Kapak: U1 gövdesi + Kapak ×2 = ((G−2r−g)/2)×(Y−2r). Menteşe 4, kulp 2.

### U3 — Üst Camlı Kapak
U1/U2 gövdesi aynı. Kapak satırı yerine:
- **Alüminyum profil cam kapak (hazır alım kalemi):** adet = kapak sayısı, ölçü = kapak NET ölçüsü → maliyette `cam_kapak_m2 = EN×BOY/10⁶` + profil çerçeve kalemi.
- VEYA **MDF çerçeveli:** Çerçeve dikme ×2 = 60×(Y−2r) [2,2,2,2] + başlık ×2 = 60×(G−2r−120); Cam = (G−2r−90)×(Y−2r−90), m² kalemi.
Donanım: cam menteşesi (adet menteşe kuralıyla), kulp.

### U4 — Davlumbaz Modülü (G = 600, Y = 350–400)
| 1 | Yan | 2 | D | Y | [1,0,0,0] | Gövde |
| 2 | Üst tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 3 | Ön panel/kapak | 1 | G−2r | Y−2r | [2,2,2,2] | Kapak |
Alt tabla ve arkalık YOK (baca/cihaz). Donanım: menteşe 2 (gazlı amortisör opsiyon kalemi), askı 2.
Kontrol: ankastre/sürgülü davlumbaz tipi seçimine göre iç boşluk ≥ cihaz ölçüsü.

### U5 — Üst Köşe (G1×G2, 600×600 vars.)
A7 mantığının üst versiyonu: yan ×2 (D×Y), alt+üst tabla 2'şer parça (G1−t ve G2−D−t genişliklerinde), kör dolgu 50, arkalık ×2, kapak 1 = (G1−D−50−2r)×(Y−2r). Menteşe geniş açı 2, askı 2.

---

## 3. BOY MODÜLLER

### B1 — Kiler/Boy Dolap (G=600, Y=2080, D=560)
| 1 | Yan | 2 | D | Y | [1,0,0,0] | Gövde |
| 2 | Alt tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 3 | Üst tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 4 | Sabit ara tabla | 1 | G−2t | D | [1,0,0,0] | Gövde |
| 5 | Raf | 4 | G−2t−2 | D−rf | [1,0,0,0] | Gövde |
| 6 | Arkalık | 1 | G−4 | Y−4 | [0,0,0,0] | Arkalık |
| 7 | Alt kapak | k* | (G−2r−(k−1)g)/k | 1400−r−g/2 | [2,2,2,2] | Kapak |
| 8 | Üst kapak | k | (G−2r−(k−1)g)/k | Y−1400−r−g/2 | [2,2,2,2] | Kapak |

\* k = G ≤ 600 → 1, değilse 2. Ara tabla 1400 hizasında (alt/üst kapak ayrımı).
Donanım: alt kapak ~1396 → menteşe 3/kapak; üst ~676 → 2/kapak; kulp kapak başına 1; baza A-serisiyle ortak hatta.
Arkalık 2080−4=2076 > 1830 plaka eni → **kontrol 0.5/1 devreye girer:** arkalık 2 parçaya bölünür (ek kayıt arkasına), motor bunu otomatik yapar.

### B2 — Buzdolabı Boşluğu (G = 700–900)
| 1 | Boy yan panel* | 1–2 | 600 | 2080 | [1,0,0,0]** | Kapak |
| 2 | Üst kutu (U1 ölçülerinde, Y=350–400) | set | U1 formülü (G aynı) | | | |
| 3 | Üst bağlantı kaydı | 1 | G−(yan adedi)·t | kayıt_h | [0,0,0,0] | Gövde |
\* Komşu boy dolap yanı varsa paylaşılır. \** Görünür panel → kapak malzemesi, görünür kenarlar bantlı [1,0,1,1].

---

## 4. HAT (RUN) SEVİYESİ PARÇALAR — modüller birleşince otomatik üretilir

| Kod | Parça | Formül | Bant | Malzeme |
|---|---|---|---|---|
| D1 | Dolgu çıtası | duvar_ölçüsü − ΣG (kalan ≥10 ise), EN=kalan, BOY=Y (alt) / Y (üst) | [1,0,0,0] | Kapak |
| D2 | Baza önü | hat uzunluğu (bulaşık boşluğu hariç opsiyonel), parça başı maks 2400 → böl | [1,0,0,0]*** | Kapak |
| D3 | Tezgah | mtül kalemi = alt hat uzunluğu/1000 (L köşede iç ölçü düşülür) | — | Satın alma |
| D4 | Tezgah üstü alın (süpürgelik) | mtül = tezgah mtül | — | Satın alma |
| D5 | Kornij/ışık bandı (üst hat) | mtül = üst hat uzunluğu (opsiyon) | — | Satın alma |
\*** Baza alt kenarı zeminle temas: 1 mm bant alt kenara da önerilir → [1,1,0,0].

---

## 5. ÇIKTI ÜRETİMİ

### 5.1 Kesim Listesi (Excel/PDF kolonları)
`Sıra · Modül · Parça adı · Adet · KESİM EN · KESİM BOY · Kalınlık · Malzeme/Renk · Damar kilidi · Bant özeti (Ö/A/S/Sğ mm) · Etiket no`
Sıralama: malzeme+kalınlık grubu → BOY azalan. Her parçaya benzersiz etiket (örn. `P-A2.3-07`) → plaka şemasındaki etiketle birebir.

### 5.2 Bantlama Listesi
`Etiket · Parça · Kenar (Ö/A/S/Sğ) · Uzunluk · Bant kalınlığı · Bant rengi` + özet tablo: renk+kalınlık → toplam metre ×1.10.

### 5.3 Malzeme/Maliyet Listesi
Plaka: optimizasyon sonucu adet (malzeme+renk+kalınlık bazında) · Bant: 5.2 özeti · Donanım: 0.4 kuralları toplamları · Satın alma kalemleri: tezgah/alın/cam/kornij mtül-m² · Her satır × fiyat DB → toplam; + kâr marjı → müşteri fiyatı.

### 5.4 Referans Doğrulama Seti (birim test zorunluluğu)
`test/fixtures/` altında 3 referans proje: (1) 240 cm düz mutfak (A4+A3+A5+A6 / U1+U2+U4), (2) L mutfak köşeli, (3) boy dolaplı U mutfak. Her biri için elle hesaplanmış beklenen kesim+bant+donanım listeleri JSON olarak tutulur; motor çıktısı birebir eşleşmek zorunda. **Formüllerde herhangi bir değişiklik bu 3 fixtures'ı güncellemeden merge edilemez.**
