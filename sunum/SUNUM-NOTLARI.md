# Sunum notları — "SAP + n8n: From APIs to Intelligent Workflows"
### SIT Ankara · 20 dakika · macOS

> Bu dosya sahnede takip etmen için.
> Kurulum ve sorun giderme: [README.md](../README.md)
> · CAP'in içi: [order-demo/MIMARI.md](../order-demo/MIMARI.md) · Workflow'lar: [n8n-workflows/README.md](../n8n-workflows/README.md)

---

## T-10 dk · Sahne hazırlığı

**Telegram modunda** (internet var):
```zsh
cd ~/sap_n8n
./scripts/start-demo.sh --tunnel
./scripts/check-demo.sh --full
```

> Cloudflare quick tunnel 20-30 dakika sonra kendiliğinden kopabiliyor. Perde 1b'den ve Perde 2'den
> hemen önce `./scripts/check-demo.sh` çalıştır; "tünel yanıt vermiyor" derse n8n'i `--tunnel` ile
> yeniden başlat (1 dakika).

**Form modunda** (internet yok, 7844 kapalı ya da riskli):
```zsh
# order-demo/.env -> N8N_WEBHOOK_URL=http://localhost:5678/webhook/order-approval-offline
./scripts/start-demo.sh          # --tunnel OLMADAN
./scripts/check-demo.sh --full   # "FORM modu" ve "Her şey hazır" demeli
```
Perde 1b'de onay: `./scripts/create-order.sh -a 15000` → **`./scripts/form-url.sh`** formu tarayıcıda açar →
Karar: Onayla / Reddet, Onaylayan: adın → Fiori'yi yenile. Formu açmadan önce n8n'de Executions'taki
**waiting** execution'ı gösterebilirsin; "send-and-wait burada da aynı, kanal Telegram yerine n8n formu" de.

> `--tunnel` unutursan Telegram butonları **hiç gönderilmez** (Telegram localhost
> adreslerini reddeder). `check-demo.sh` bunu yakalar.

Hepsi yeşil olmalı. Son satır **"Her şey hazır"** demiyorsa sahneye çıkma, kırmızıyı düzelt.

> `--full` listeye 1 prova siparişi bırakır. Temiz liste istiyorsan CAP penceresinde
> `Ctrl+C` → `cds watch` (veritabanı in-memory, CSV'ler yeniden yüklenir).

### Ekranda açık olacaklar

| Sekme/Pencere | Adres | Ne için |
|---|---|---|
| Tarayıcı 1 | `http://localhost:4004` | **Sipariş Aç formu** — ana çalışma ekranın |
| Tarayıcı 2 | `http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app` | Fiori listesi — "gerçek SAP" görüntüsü |
| Tarayıcı 2 | `http://localhost:5678` | n8n editörü |
| Tarayıcı 3 | `web.telegram.org` → bot sohbeti | Onay butonu **buradan** tıklanacak |
| Terminal | repo kökü | Komutları yazacağın yer |
| Terminal | `n8n :5678` | (arkada dursun) |
| Terminal | `CAP :4004` | Log göstermek istersen |

**Yazı tipini büyüt** (Terminal: `Cmd +`, tarayıcı: `Cmd +`).

> ⚠️ Onay butonuna **bu Mac'teki tarayıcıdan** bas. Telegram Web sekmesini
> önceden aç ve bot sohbetine gir. Tıklayınca tarayıcıda "Action recorded"
> sayfası açılır — onay budur. Sohbetteki butonlar yerinde kalır, mesaj
> kendini güncellemez; bu normal, endişelenme.

---

## Slaytlar ve konuşma — nasıl örtüşüyor

Deste (`../SUNUM.pptx`) demoyu anlatmaz, n8n'i anlatır. Konuşmanın akışı:

| Dakika | Ne | Slayt |
|---|---|---|
| 0:00 | Açılış, tez cümlesi | 1 |
| 0:30 | "Onay için kaç sisteme dokunuyoruz?" · neden şimdi | 2 |
| 1:30 | n8n nedir — çeviri tablosundan 3 satır oku | 3 |
| 3:00 | Neler yapılır — dört iş | 4 |
| 4:00 | SAP ile nasıl konuşur — yön, clean core | 5 |
| 5:00 | "Şimdi canlı görelim — üç yere bakın" | 6 |
| 5:30 | **DEMO** (aşağıdaki Perde 1 ve 2) | — |
| 17:30 | Agent oluşturur, onaylamaz | 7 |
| 18:00 | n8n'in SAP ve BTP'deki yeri | 8 |
| 18:40 | Bir SAP mimarının ilkeleri | 9 |
| 19:10 | Üretime taşırken | 10 |
| 19:40 | Kapanış | 11 |

Her slaydın konuşmacı notu var — ne söyleyeceğin orada. Aşağısı demonun kendisi.

## Perde 0 · Çerçeve (2 dk) — *konuşma, tıklama yok*

> "SAP tarafında iş mantığı var, ama süreç SAP'nin dışına taşıyor: onay, bildirim,
> insan kararı. Bunu SAP'nin içine gömmek yerine, API'yi dışarı açıp orkestrasyonu
> n8n'e bırakıyoruz. İki perde göstereceğim: önce klasik API entegrasyonu,
> sonra aynı API'yi bir AI agent'ın kullanması."

Fiori listesini göster: 3 sipariş, **renkli durum sütunu** (yeşil/sarı/kırmızı).

> "Bu bir SAP CAP servisi. OData V4, Fiori Elements. Şu an tamamen standart."

---

## Perde 1 · APIs (7 dk)

### 1a — Eşiğin altı: insan yok (2 dk)

```zsh
./scripts/create-order.sh -a 500
```

> "500 liralık bir sipariş açtım. CAP bunu kaydetti ve n8n'e bir webhook attı."

n8n sekmesine geç → **Executions** → en üstteki → IF node'unu göster.

> "n8n tutara baktı, 10.000'in altında, kuralı uyguladı ve SAP'ye geri yazdı.
> Karar n8n'de ama deterministik — burada yapay zekâ yok."

Fiori'yi yenile → **APPROVED**, onaylayan **auto-rule**.

*(İstersen: `./scripts/watch-order.sh <ID>` ile canlı durum değişimini göster.)*

### 1b — Eşiğin üstü: insan devrede (5 dk)

```zsh
./scripts/create-order.sh -a 15000
```

> "Aynı akış, ama bu sefer 15.000 lira. Eşiği aştı."

**Telegram Web sekmesine geç** → gelen mesajı göster: sipariş özeti + **Onayla / Reddet**.

> "n8n 'send and wait' ile akışı durdurdu. Şu an execution canlı olarak bekliyor —
> saatlerce de bekleyebilir."

n8n sekmesinde execution'ın **waiting** durumunu göster (güzel bir an).

Telegram'a dön → **Onayla**'ya bas → Fiori'yi yenile.

> **APPROVED**, onaylayan **Telegram**. Tek satır kod yazmadan bir onay süreci kurduk."

---

## Perde 2 · Intelligent (7 dk)

> Agent **Google Gemini**'nin ücretsiz katmanıyla canlı çalışır. API takılırsa
> `./scripts/agent-demo.sh` ile aynı üç çağrıyı elle gösterirsin — kurtarma
> hamlen hazır ve test edilmiş durumda (bkz. 2b-alt).

### 2a — Mimariyi göster (3 dk) · *tıklama yok, anlatım*

n8n → `02 - Order Agent` workflow'unu aç. **Canvas'ı göster.**

> "Aynı CAP servisi. Ama bu sefer önünde bir agent var. Agent'a üç tool verdim:
> ürün ara, müşteri ara, sipariş oluştur. Üçü de düz HTTP Request — SAP'nin OData'sı.
> Agent'ın SAP'ye özel hiçbir bilgisi yok, sadece bu üç kapı var."

Sırayla bu üç node'a çift tıkla ve **tool description**'larını göster:

| Node | Vurgulanacak cümle |
|---|---|
| `listProducts` | *"Bir siparis olusturmadan ONCE urunun var oldugunu dogrulamak ve birim fiyatini ogrenmek icin MUTLAKA bu tool'u kullan"* |
| `getCustomer` | *"Bos liste donerse musteri sistemde KAYITLI DEGILDIR"* |
| `createOrder` | *"Bu tool veri yazar, bu yuzden sadece ... dogruladiktan SONRA cagir"* |

Sonra **Siparis Agent** node'unu aç, **system prompt**'u göster:

> "Kritik kısım burası: 'Asla tahmin etme, asla uydurma. Tool sonucu boş
> döndüyse bulunamadı demektir.' Agent'ın fiyat uydurmasını engelleyen şey bu."

### Perde 2 nereden tetiklenir? — iki seçenek

| Yol | Nasıl | Ne zaman |
|---|---|---|
| **n8n editörü içindeki Chat** | `02`'yi aç → alttaki **Chat** düğmesi | Agent çalışırken canvas'ta tool'lar sırayla yanar — mimariyi göstermenin en iyi yolu. Sekmeyi sahneden önce bir kez yenile |
| **Yerel chat sayfası** | `http://localhost:4004/chat.html` | n8n arayüzü görünmesin istersen. Tünelden bağımsız, en sağlam yol; örnek istemler tıklanabilir |
| n8n'in kendi chat sayfası | `http://localhost:5678/webhook/b2…11/chat` | Kullanma: mesajı tünel üzerinden gönderir, tünel koparsa ya da yanıt 60 sn'yi aşarsa hata verir |

> **Kota uyarısı.** Gemini ücretsiz katmanı bu modele günde **20 istek** verir; bir agent turu 2-4 istek
> yakar. Sahne günü canlı agent'ı en fazla 1-2 kez çalıştır, provayı `agent-demo.sh` ile yap.
> Yanıt süresi 5 ile 60 saniye arasında değişebilir; beklerken tool'ların yanışını anlat.

Sahne için **editör içindeki Chat** daha güçlü: izleyici agent'ın üç tool'u
sırayla çağırdığını canlı görüyor. Ayrı sayfa temiz ama kutu içinde kalıyor.

### 2b — Agent'ı çalıştır (3 dk)

`02` workflow'unda alttaki **Chat** düğmesine bas ve yaz:

```
Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç
```

Agent çalışırken **tool çağrılarını tek tek göster** — canvas'ta sırayla yanarlar.

#### 2b-alt · Agent takılırsa (kota, internet, API)

Chat'i kapat, terminale geç:

```zsh
./scripts/agent-demo.sh
```

Ekranda sırayla akar — her adımda durup anlat:

```
1 · listProducts  → Endüstriyel Filtre Kartuşu, birim fiyat 375,00
2 · getCustomer   → Anadolu Makina A.Ş.
3 · Tutar         → 40 × 375,00 = 15.000,00 TRY
4 · createOrder   → Siparis No: …
5 · Döngü kapanıyor
```

> "Dikkat edin: fiyatı ben vermedim, **SAP söyledi**. Agent da tam olarak bunu yapıyor —
> uydurmuyor, soruyor."

### 2c — Korumaları göster (1 dk) · *en güçlü an*

```zsh
./scripts/agent-demo.sh -p "Olmayan Urun"
```

Ekranda: **"Ürün bulunamadı — agent burada DURUR ve sipariş açmaz"**

> "İki koruma var: agent ürünü doğrulamadan `createOrder`'ı çağıramıyor,
> CAP de bilinmeyen ürüne 400 dönüyor. Yani agent 'Süper Filtre 9000'
> diye bir şey uydurup sipariş açamaz."

### 2d — Döngü kapanıyor (1 dk)

Telegram sekmesine geç.

> "Ve işte kapanan döngü: sipariş açıldı, CAP webhook'u attı, Perde 1'deki
> **aynı** workflow devreye girdi, onay yine bana geldi. Agent oluşturdu —
> **onaylamadı**. Karar hâlâ deterministik kuralda ve insanda."

Onayla → Fiori'yi yenile → **APPROVED**.

---

> **Soru gelirse — "agent'ı canlı çalıştırabilir miydiniz?"**
> "Evet, `Chat Model` node'u bağlı; tek eksik API kredisi. Zaten göstermek
> istediğim şey modelin kendisi değil, **tool sınırları** — asıl mühendislik orada."

### Sağlamlık vurgusu (30 sn)

> "Bir şey daha: n8n kapalıyken de sipariş oluşur. Webhook fire-and-forget —
> orkestrasyon çökerse SAP'deki iş durmaz."

```zsh
./scripts/stop-demo.sh --n8n        # orkestrasyonu öldür
./scripts/create-order.sh -a 700    # sipariş yine oluşur (HTTP 201)
```

CAP penceresinde uyarıyı göster: `n8n webhook failed ... - order was still created`
Sonra geri getir: `./scripts/start-demo.sh --n8n`

---

## Kapanış (2 dk)

> "Özet: SAP iş mantığını ve veriyi tutuyor. n8n süreci, insanı ve entegrasyonu
> orkestre ediyor. AI agent ise yalnızca **arayüz** — API'yi doğal dille kullanılabilir
> yapıyor, ama kararı almıyor. Bu ayrım önemli: agent'ı onaylatmaya başlarsan
> denetlenebilirliği kaybedersin."

Vaktin kalırsa: `03 - Error Handler` workflow'unu göster (1 node, hata → Telegram).

---

## Kurtarma hamleleri

| Olursa | Hemen yap |
|---|---|
| **İnternet yok / tünel açılmıyor (7844 kapalı)** | `.env` → `order-approval-offline` · `./scripts/stop-demo.sh && ./scripts/start-demo.sh` (**tünelsiz**, CAP dahil) · onayı `./scripts/form-url.sh` ile ver |
| **Telegram mesajı hiç gitmiyor** | Tünel kapanmıştır. `./scripts/stop-demo.sh --n8n && ./scripts/start-demo.sh --tunnel --n8n` |
| **Chat "Failed to receive response"** | Tünel kopmuş ya da sekme eski. `http://localhost:4004/chat.html`'e geç; Telegram için tüneli yeniden başlat |
| **Chat "Error in workflow"** | Gemini kotası (günde 20). `./scripts/agent-demo.sh` ile devam et, anlatım aynı |
| **Telegram mesajı gelmiyor** | Perde 1b'yi atla, doğrudan Perde 2'ye geç. Dönerken 1b'yi offline formla göster. |
| **agent-demo.sh hata veriyor** | CAP kapalıdır. `./scripts/start-demo.sh --cap` |
| **Agent "credential does not exist" diyor** | Yayınlanmış sürüm eski. `./scripts/stop-demo.sh --n8n && ./scripts/publish-workflows.sh && ./scripts/start-demo.sh --tunnel` |
| **Gemini 404 / model yok** | `./scripts/stop-demo.sh --n8n && ./scripts/pick-gemini-model.sh && ./scripts/start-demo.sh --tunnel` |
| **Webhook 404** | Workflow aktif değil. n8n'de Activate. |
| **CAP takıldı** | CAP penceresinde `Ctrl+C` → `cds watch`. 10 saniye, veri temiz gelir. |
| **Her şey karıştı** | `./scripts/stop-demo.sh && ./scripts/start-demo.sh` — 1 dakika. |

---

## Cepte dursun: sık gelen sorular

**"Bu üretimde çalışır mı?"**
> Mimari evet; bu kurulum hayır. Burada SQLite ve lokal n8n var. Üretimde CAP'i BTP'ye,
> n8n'i kendi sunucunuza alırsınız; webhook'a mTLS/OAuth koyarsınız. Desen aynı kalır.

**"Neden SAP Build Process Automation değil?"**
> O da geçerli. n8n'in avantajı SAP dışı yüzlerce entegrasyonu ve LLM node'larını
> hazır getirmesi. Seçim, sürecin ağırlık merkezi SAP'de mi dışarıda mı olduğuna bağlı.

**"Agent yanlış sipariş açarsa?"**
> İki koruma var: agent ürünü ve müşteriyi doğrulamadan `createOrder` çağıramıyor,
> CAP de bilinmeyen ürüne `400` dönüyor. Üstelik açtığı her sipariş `PENDING` —
> onay hâlâ kuralda ve insanda.

**"Maliyet?"**
> Sadece Perde 2'deki LLM çağrıları (Gemini Flash, ücretsiz katman; birkaç tool çağrısı).
> Perde 1'de model yok; deterministik kural.
