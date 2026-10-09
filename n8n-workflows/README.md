# n8n workflow'ları

Dört workflow, hepsi n8n **2.x** export formatında. Üçü demonun kendisi, biri hata bildirimi.
Kurulumun tamamı için [kök README](../README.md); bu dosya workflow'ların içini anlatır.

| Dosya | n8n'deki adı | Tetikleyici | Rol |
|---|---|---|---|
| `01-order-approval.json` | 01 - Order Approval (Telegram) | Webhook `POST /webhook/order-approval` | Perde 1: eşik kuralı + Telegram onayı |
| `02-order-agent.json` | 02 - Order Agent (Chat) | Chat Trigger | Perde 2: AI Agent + 3 OData tool |
| `03-error-handler.json` | 03 - Error Handler | Error Trigger | Herhangi bir workflow hata verirse Telegram'a bildir |
| `04-order-approval-OFFLINE.json` | 04 - Order Approval (OFFLINE / Form) | Webhook `POST /webhook/order-approval-offline` | 01'in Telegram'sız kopyası; onay n8n Form ile |

## Import

**macOS, otomatik:** `./scripts/setup-mac.sh` dördünü de import eder, "CAP Webhook Key"
credential'ını oluşturup webhook node'larına bağlar. n8n kapalıyken çalıştır.

**Elle, herhangi bir platform:** n8n → Workflows → **Import from File** → JSON'u seç.
Sonra:

1. **Credentials → New → Header Auth**: adı `CAP Webhook Key`, Name `X-API-Key`,
   Value `order-demo/.env` içindeki `N8N_WEBHOOK_KEY` ile aynı (varsayılan `sit-ankara-2026`).
   01 ve 04'teki `CAP Webhook` node'unda bu credential'ı seç.
2. **Telegram API** credential'ı (`Telegram account`): @BotFather'dan aldığın bot token'ı.
   01'deki `Telegram Onay Iste`, `Ret Sebebi Sor` ve 03'teki `Telegram Hata Bildirimi` node'larında seç.
3. **Google Gemini (PaLM) API** credential'ı (`Google Gemini account`): 02'deki `Chat Model` node'unda seç.
   İsteğe bağlı; Perde 2 LLM'siz de oynanır.
4. 01 ve 03'teki Telegram node'larında **Chat ID** alanına kendi chat id'ni yaz
   (`<CHAT_ID>` yazan yerler). macOS'ta `./scripts/set-chat-id.sh 123456789` bunu her yere birden yazar.
5. 01'i (offline prova için 04'ü de) **Activate** et.

JSON'lardaki `REPLACE_WITH_YOUR_CREDENTIAL_ID` değerleri bilerek bırakılmış yer tutuculardır;
n8n credential kimlikleri kuruluma özeldir, dışa aktarılmaz.

## Production ve test webhook'u

| Adres | Ne zaman |
|---|---|
| `http://localhost:5678/webhook/order-approval` | Workflow **aktifken**, canlı demoda |
| `http://localhost:5678/webhook-test/order-approval` | Editörde **Test workflow**'a bastıktan sonra, tek seferlik |

CAP hangi adrese gideceğini `order-demo/.env` → `N8N_WEBHOOK_URL`'den alır.

> n8n 2.x **yayınlanmış** sürümü çalıştırır. Editörde değişiklik yaptıktan sonra Active
> anahtarını kapat/aç, ya da `./scripts/publish-workflows.sh`. Aksi hâlde production
> webhook eski sürümü çalıştırmaya devam eder.

---

## 01 · Order Approval (Telegram)

CAP'in `after CREATE` handler'ı buraya `{ID, customer, product, qty, amount, currency}` gönderir.

```
CAP Webhook ─► Siparis Bilgileri ─► Tutar > 10.000 mu?
                                        │ hayır ─► CAP approve (auto-rule)
                                        │ evet  ─► Telegram Onay Iste  (send-and-wait)
                                                        └► Onaylandi mi?
                                                              │ evet ─► CAP approve (Telegram)
                                                              │ hayır ─► Ret Sebebi Sor ─► CAP reject (Telegram)
```

| Node | Tip | Ne yapar |
|---|---|---|
| `CAP Webhook` | Webhook | `POST /webhook/order-approval`, **Header Auth** (`X-API-Key`). Anahtar uyuşmazsa 403. |
| `Siparis Bilgileri` | Set | Gelen gövdeyi okunaklı alanlara açar: sipariş no, müşteri, ürün, adet, tutar, para birimi. |
| `Tutar > 10.000 mu?` | IF | **Onay eşiği burada.** Değiştirmek istersen bu node'u düzenle, CAP'e dokunma. |
| `Telegram Onay Iste` | Telegram (send and wait) | Sipariş özeti + **Onayla / Reddet** butonları. Execution `waiting` durumuna geçer; saatlerce bekleyebilir. Çıktı: `data.approved` (true/false). |
| `Onaylandi mi?` | IF | `data.approved` dalını ayırır. |
| `CAP approve (Telegram)` | HTTP Request | `POST http://localhost:4004/odata/v4/order/approve` `{ID, approvedBy: "Telegram"}` |
| `Ret Sebebi Sor` | Telegram (send and wait, serbest metin) | Reddet'e basılınca Telegram'dan ret sebebini sorar; yazılan cevap `reject` çağrısına `reason` olarak gider. **Limit Wait Time 2 dakika:** cevap gelmezse node girdisini aynen geçirir ve `reject` varsayılan gerekçe "Telegram uzerinden reddedildi" ile çağrılır. |
| `CAP reject (Telegram)` | HTTP Request | `POST .../reject` `{ID, reason}`. Sebep CAP'te `note` alanına yazılır. |
| `CAP approve (auto-rule)` | HTTP Request | Eşiğin altı: `{ID, approvedBy: "auto-rule"}`; yaklaşık 1 saniyede döner. |

**Telegram butonları `localhost` ile çalışmaz.** Telegram, buton URL'i olarak loopback adresi
kabul etmez. n8n'i public bir adresle başlatman gerekir: `./scripts/start-demo.sh --tunnel`
(cloudflared). Ayrıntı: [kök README § 8](../README.md#8-onay-modları-telegram-ve-form).

Onay butonuna demo yapılan bilgisayardaki tarayıcıdan basılır; tıklayınca "Action recorded"
sayfası açılır. Sohbetteki mesaj kendini güncellemez; bu normaldir.

## 02 · Order Agent (Chat)

```
Chat Trigger ─► Siparis Agent ◄── Chat Model (Google Gemini Flash, temperature 0)
                     │        ◄── Simple Memory (buffer window)
                     ├── tool: listProducts   GET  /Products?$filter=contains(name,'…')
                     ├── tool: getCustomer    GET  /Customers?$filter=contains(name,'…')
                     └── tool: createOrder    POST /Orders  {customer, product, qty}
```

| Node | Tip | Ne yapar |
|---|---|---|
| `Chat Trigger` | Chat Trigger | Public mod. Üç giriş: editördeki **Chat** paneli; CAP'in servis ettiği yerel sayfa `http://localhost:4004/chat.html` (tünelden bağımsız, önerilen); n8n'in kendi sayfası `http://localhost:5678/webhook/b2000000-0000-4000-8000-000000000011/chat` (mesajı `WEBHOOK_URL` yani tünel üzerinden gönderir; tünel koparsa çalışmaz). |
| `Siparis Agent` | AI Agent | System prompt: *asla tahmin etme, asla uydurma; tool sonucu boş döndüyse bulunamadı demektir; sırayla ürünü, müşteriyi doğrula, sonra sipariş aç.* Onay/ret tool'u **yoktur**. |
| `Chat Model` | Google Gemini Chat Model | Repodaki JSON `models/gemini-3-flash-preview` ile gelir, temperature **0**. Ücretsiz katman bu modele **günde 20 istek** verir; bir agent turu 2-4 istek harcar. Google model kimliklerini zamanla kapatıyor; `./scripts/pick-gemini-model.sh` anahtarının kullanabildiği bir modeli bulup buraya yazar. |
| `Simple Memory` | Memory Buffer Window | Aynı sohbet içinde bağlamı tutar. |
| `listProducts` | HTTP Request Tool | Ürünü adıyla arar, birim fiyatı döner. Açıklama: "sipariş oluşturmadan ÖNCE … MUTLAKA bu tool'u kullan". |
| `getCustomer` | HTTP Request Tool | Müşteriyi adıyla arar. Açıklama: "boş liste dönerse müşteri sistemde KAYITLI DEĞİLDİR". |
| `createOrder` | HTTP Request Tool | Siparişi açar; `amount` göndermez, CAP `qty × unitPrice` hesaplar. Açıklama: "bu tool veri yazar … sadece doğruladıktan SONRA çağır". |

Örnek istem: `Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç`
→ 40 × 375,00 = 15.000,00 TRY → CAP webhook'u **01**'i tetikler → Telegram'a onay düşer.
Agent oluşturdu, onaylamadı.

Sağlayıcı değiştirmek: `Chat Model` node'unu sil, başka bir Chat Model ekle (OpenAI, Groq,
Ollama…), credential seç, agent'ın **Chat Model** portuna bağla. Geri kalan her şey aynı kalır.

LLM olmadan aynı üç çağrı: `./scripts/agent-demo.sh`.

## 03 · Error Handler

```
Error Trigger ─► Telegram Hata Bildirimi
```

01, 02 ve 04'ün `settings.errorWorkflow` alanı `demo03`'ü gösterir. `setup-mac.sh` workflow'ları `demo01`…`demo04`
sabit kimlikleriyle import ettiği için bağlantı import'ta korunur; arayüzden elle import ediyorsan
**Settings → Error workflow** alanından `03`'ü seç. Bir execution hata
verirse workflow adı, hata mesajı ve execution bağlantısı Telegram'a gider. Chat id'si 01 ile
aynıdır; `set-chat-id.sh` ikisini birden yazar.

## 04 · Order Approval (OFFLINE / Form)

01 ile aynı iskelet; Telegram node'u yerine n8n'in **Wait → Resume on form submission**
mekanizması var. İnternet, tünel ve Telegram gerektirmez.

```
CAP Webhook ─► Siparis Bilgileri ─► Tutar > 10.000 mu?
                                        │ hayır ─► CAP approve (auto-rule)
                                        │ evet  ─► Form ile Onay Bekle ─► Onaylandi mi? ─► CAP approve (Form)
                                                                                        └► CAP reject (Form)
```

| Node | Not |
|---|---|
| `CAP Webhook` | `POST /webhook/order-approval-offline`, aynı Header Auth credential'ı |
| `Siparis Bilgileri` | Ek alan **`onayFormUrl`** = `$execution.resumeFormUrl`. Onay formunun adresi budur. |
| `Form ile Onay Bekle` | Wait node, form gönderilince devam eder. Formda onaylayan adı ve Onayla / Reddet seçimi vardır. |
| `CAP approve (Form)` | `approvedBy` alanına formdaki isim yazılır. |

Kullanım:

1. `order-demo/.env` → `N8N_WEBHOOK_URL=http://localhost:5678/webhook/order-approval-offline`
2. n8n'de **04 Activate**, **01 Deactivate**; CAP'i yeniden başlat.
3. n8n'i **tünelsiz** başlat. Tünelliyken `resumeFormUrl` tünel adresini üretir, tünel kapanınca link ölür.
4. Sipariş aç → Executions → bekleyen execution → `Siparis Bilgileri` çıktısındaki `onayFormUrl`'i tarayıcıda aç → Onayla / Reddet.

Form adresini elle kurma: n8n linke tek kullanımlık bir `?signature=` ekler; elle kurulan
adres **Invalid Form Link** verir.

## Pinned data

İnternet varken bir kez başarılı çalıştır → execution'da `Telegram Onay Iste` (01) veya
`Siparis Agent` (02) node'unun çıktısını **pin'le** → Save. Sonraki **Test workflow**
çalıştırmalarında o node dış servise gitmez, son çıktıyı döner. Production webhook
çalıştırmalarında pin data devreye **girmez**; tam otomatik offline akış için 04'ü kullan.
