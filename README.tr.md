# SAP + n8n: API'lerden Akıllı Workflow'lara

🇬🇧 English version: **[README.md](README.md)**

> **SAP veriyi tutar, n8n orkestre eder, agent sadece bir arayüzdür.**

SAP Inside Track Ankara 2026 için hazırlanan canlı demonun kaynak paketi: bir **SAP CAP** sipariş servisi,
dört **n8n** workflow'u ve demoyu tek komutla kurup çalıştıran script'ler. Her şey bir dizüstü bilgisayarda,
**Docker'sız ve BTP hesabı gerektirmeden** çalışır. Sunum ve video dosyaları bu repoda değildir.

## İçindekiler

1. [Demo ne gösteriyor](#1-demo-ne-gösteriyor)
2. [Mimari](#2-mimari)
3. [Repo haritası](#3-repo-haritası)
4. [Gereksinimler](#4-gereksinimler)
5. [Hızlı başlangıç](#5-hızlı-başlangıç)
6. [Kurulum ayrıntıları](#6-kurulum-ayrıntıları)
7. [Demoyu çalıştırma](#7-demoyu-çalıştırma)
8. [Onay kanalları: Telegram ve Form](#8-onay-kanalları-telegram-ve-form)
9. [Ortam değişkenleri](#9-ortam-değişkenleri)
10. [Script'ler](#10-scriptler)
11. [Workflow'lar](#11-workflowlar)
12. [CAP servisi](#12-cap-servisi)
13. [Sorun giderme](#13-sorun-giderme)
14. [Sık sorulan sorular](#14-sık-sorulan-sorular)
15. [Üretime taşırken](#15-üretime-taşırken)
16. [Notlar](#16-notlar)

---

## 1. Demo ne gösteriyor

İki perdelik bir **Sipariş Onay Döngüsü**.

| Perde | Ne olur |
|---|---|
| **1 · APIs** | CAP'te sipariş oluşur → CAP webhook'u n8n'i tetikler → tutar **10.000 TRY** üzerindeyse Telegram'dan onay istenir, değilse otomatik onaylanır → sonuç CAP'e `approve` / `reject` action'ı ile geri yazılır → Fiori listesinde durum rengi değişir. |
| **2 · Intelligent** | Bir n8n **AI Agent**, üç HTTP Request Tool ile aynı CAP OData servisini kullanır: ürün ara, müşteri ara, sipariş oluştur. Sipariş açılır → CAP handler Perde 1'i tetikler → onay yine insana gelir → **döngü kapanır**. |

Üç tasarım kararı demonun omurgasıdır:

- **Karar deterministik kalır.** 10.000 eşiği ve onay akışı n8n'in IF node'undadır; agent'ın `approve` / `reject` tool'u yoktur. Agent yalnızca *oluşturur*.
- **Agent uyduramaz.** System prompt tahmini yasaklar; tool açıklamaları "önce doğrula, sonra yaz" sırasını zorlar; CAP de katalogda olmayan ürüne **400** döner.
- **SAP, n8n'e bağımlı değildir.** Webhook fire-and-forget çalışır: n8n kapalıyken de sipariş oluşur, sadece uyarı loglanır.

## 2. Mimari

```
            ┌──────────────── SAP CAP  (localhost:4004) ────────────────┐
            │  OData V4  /odata/v4/order                                │
            │   Orders · Products · Customers                           │
            │   actions: approve(ID, approvedBy) · reject(ID, reason)   │
            │  Fiori Elements preview  (renkli durum sütunu)            │
            │  Sipariş formu (app/index.html) · Agent sohbeti (chat.html)
            └───────┬───────────────────────────────────▲───────────────┘
   after CREATE     │ POST webhook (X-API-Key)          │ POST /approve · /reject
   (commit sonrası) │                                   │
            ┌───────▼───────────────────────────────────┴───────────────┐
            │                      n8n  (localhost:5678)                │
            │  01  Webhook → IF tutar > 10.000 ─ hayır → approve(auto-rule)
            │                                  └ evet  → Telegram send-and-wait
            │                                             ├ Onayla → approve(Telegram)
            │                                             └ Reddet → gerekçe → reject(...)
            │  02  Chat Trigger → AI Agent ─┬ listProducts  (GET Products)
            │                               ├ getCustomer   (GET Customers)
            │                               └ createOrder   (POST Orders) ──► 01'i tetikler
            │  03  Error Trigger → Telegram
            │  04  01'in Telegram'sız kopyası: onay n8n Form ile (+ Telegram'a metin bildirim)
            └───────────────────────────────────────────────────────────┘
```

Bir siparişin hayatı:

1. `POST /Orders` gelir (form, script ya da agent).
2. `before CREATE`: para birimi `TRY`, durum `PENDING`; `amount` yoksa `qty × unitPrice` hesaplanır, ürün katalogda yoksa **400**.
3. INSERT ve commit.
4. `after CREATE` → `req.on('succeeded')` içinde webhook atılır. Commit'ten *sonra* tetiklenir; yoksa n8n'in milisaniyeler içinde dönen `approve` çağrısı INSERT ile yarışıp 404 alırdı.
5. n8n karar verir ve `approve` / `reject` ile geri yazar. Action'lar **idempotent**: iki kez tıklamak veya webhook retry'ı demoyu bozmaz; farklı bir nihai duruma geçiş **409** döner.
6. Fiori listesi yenilenince `statusCriticality` (yeşil 3 / sarı 2 / kırmızı 1) renk değiştirir.

## 3. Repo haritası

```
sap_n8n/
├─ README.md                           ← bu dosya (tek doküman)
├─ order-demo/                         # SAP CAP servisi
│  ├─ db/schema.cds                    Orders (managed) · Customers · Products
│  ├─ db/data/*.csv                    4 müşteri · 6 ürün · 3 sipariş (fiyatlar burada)
│  ├─ srv/order-service.cds            OData servisi + approve/reject action'ları
│  ├─ srv/order-service.js             tutar hesabı, webhook, idempotent onay
│  ├─ app/fiori-annotations.cds        UI.LineItem, criticality, yeniden-eskiye sıralama
│  ├─ app/index.html                   "Sipariş Aç" formu, canlı tutar, kendini yenileyen liste
│  ├─ app/chat.html                    agent için yerel sohbet sayfası (tünelden bağımsız)
│  └─ .env.example · package.json
├─ n8n-workflows/
│  ├─ 01-order-approval.json           Perde 1 · Telegram onayı
│  ├─ 02-order-agent.json              Perde 2 · AI Agent + 3 tool
│  ├─ 03-error-handler.json            hata → Telegram
│  └─ 04-order-approval-OFFLINE.json   Perde 1'in Form ile hâli
└─ scripts/                            macOS (zsh)
   ├─ setup-mac.sh · start-demo.sh · stop-demo.sh · check-demo.sh · mode.sh
   ├─ create-order.sh · watch-order.sh · agent-demo.sh · form-url.sh
   ├─ set-chat-id.sh · set-groq-key.sh · set-gemini-key.sh · pick-gemini-model.sh
   ├─ publish-workflows.sh
   └─ lib-demo.sh · gemini_pick.py     ortak yardımcılar
```

## 4. Gereksinimler

Paket **macOS** üzerinde doğrulandı. Script'ler zsh ister; macOS'ta hazır gelen `python3` ve `sqlite3`
kullanılır.

| Bileşen | Sürüm | Not |
|---|---|---|
| Node.js | **≥ 20** (test: v24) | nvm önerilir; script'ler nvm PATH'ini kendileri çözer |
| `@sap/cds-dk` | 10.x, global | `npm i -g @sap/cds-dk` |
| n8n | 2.x (test: 2.39), global | `npm i -g n8n` · **Docker gerekmez** |
| Telegram botu | isteğe bağlı | @BotFather'dan bot token'ı; Perde 1b için |
| LLM anahtarı | isteğe bağlı, ücretsiz | **Groq** (console.groq.com, açık kaynak modeller, yüksek kota) ya da Google Gemini (günde 20 istek / model). Perde 2 LLM'siz de oynanır |
| cloudflared | isteğe bağlı | Yalnızca Telegram onayını **başka bir cihazdan** vermek istiyorsan (bkz. § 8) |

İnternet yalnızca Telegram ve LLM için gerekir. İkisi de yoksa **04 numaralı Form workflow'u** ve
`agent-demo.sh` aynı hikâyeyi internetsiz anlatır.

## 5. Hızlı başlangıç

```zsh
git clone https://github.com/gzmilgar/sap_n8n.git ~/sap_n8n
cd ~/sap_n8n

./scripts/setup-mac.sh          # 1) tek seferlik kurulum: npm install, .env, credential + workflow import
./scripts/start-demo.sh         # 2) iki Terminal penceresi: n8n (:5678) ve cds watch (:4004)
open http://localhost:5678      # 3) hesap aç → credential'ları bağla → chat id → 01'i Activate  (bkz. § 6)
./scripts/check-demo.sh --full  # 4) ön kontrol; son satır "Her şey hazır" demeli

./scripts/create-order.sh -a 500      # otomatik onay
./scripts/create-order.sh -a 15000    # Telegram'a Onayla / Reddet düşer
open http://localhost:4004            # sipariş formu + canlı liste
open http://localhost:4004/chat.html  # agent sohbeti

./scripts/stop-demo.sh          # kapat
```

Adresler: sipariş formu `http://localhost:4004` · Fiori listesi
`http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app` · OData
`http://localhost:4004/odata/v4/order` · n8n `http://localhost:5678`.

## 6. Kurulum ayrıntıları

### 6.1 `setup-mac.sh` ne yapar

1. `order-demo` içinde `npm install` çalıştırır ve `.env.example`'dan `.env` üretir.
2. n8n veritabanında **"CAP Webhook Key"** adlı bir *Header Auth* credential'ı oluşturur; değeri `.env`'deki `N8N_WEBHOOK_KEY` ile aynıdır.
3. Dört workflow'u `demo01`…`demo04` sabit kimlikleriyle import eder, webhook node'larına bu credential'ı bağlı getirir; `01/02/04` hata workflow'u olarak `03`'ü gösterir.

> n8n kuruluysa önce durdur: `./scripts/stop-demo.sh`. Import n8n kapalıyken yapılır. Workflow'lar
> zaten varsa import atlanır; `--force` ile zorlarsan UI'da seçtiğin credential'lar ve chat id sıfırlanır.

### 6.2 n8n'de elle yapılacaklar

`http://localhost:5678` → ilk açılışta yerel hesabını oluştur, sonra:

**a) Telegram credential'ı:** Credentials → New → **Telegram API** → bot token'ı → adı `Telegram account`.
01, 03 ve 04'teki Telegram node'larını açıp bu credential'ı seç (`REPLACE_WITH_YOUR_CREDENTIAL_ID` yazan yerler).

**b) Chat id:** n8n kapalıyken tek komut, repodaki JSON'ları ve n8n'deki kopyaları birlikte günceller:

```zsh
./scripts/stop-demo.sh
./scripts/set-chat-id.sh 123456789      # grup için -100...
./scripts/start-demo.sh
```

Chat id'ni bilmiyorsan Telegram'da **@get_id_bot** ile konuş. Bot sana yazabilsin diye **önce sen bota**
bir mesaj gönder.

**c) LLM anahtarı** (Perde 2 için, isteğe bağlı), n8n kapalıyken tek komut:

```zsh
./scripts/set-groq-key.sh gsk_...        # Groq: açık kaynak model, kota derdi yok (varsayılan)
./scripts/set-gemini-key.sh AIza...      # ya da Google Gemini (ücretsiz katman: günde 20 istek / model)
```

İkisi de anahtarı test eder, credential olarak kaydeder, 02'deki `Chat Model` node'unu ayarlar; Groq
script'i yayınlamayı da yapar.

**d) Activate:** `01 - Order Approval` ve `04`'ü (form modu için) **Activate** et. Workflow aktif
değilse production webhook kayıtlı olmaz, CAP `404` alır. `check-demo.sh` bunu yakalar.

### 6.3 n8n 2.x'te taslak ve yayınlanmış sürüm

n8n 2.x bir workflow'un **yayınlanmış** sürümünü çalıştırır, editörde gördüğün taslağı değil. Editörde
değişiklik yapıp kaydettikten sonra Active anahtarını kapat/aç, ya da n8n kapalıyken
`./scripts/publish-workflows.sh` (hepsini yayınlar, 01/02/04'ü aktif eder). Belirtisi: ayarlar "tutmuyor"
ya da `Credential with ID ... does not exist`.

## 7. Demoyu çalıştırma

### Perde 1a · Eşiğin altı, insan yok

```zsh
./scripts/create-order.sh -a 500
```

CAP kaydeder, webhook atar; n8n'de IF *false* dalı `approve(ID, "auto-rule")` çağırır. Liste yaklaşık
1 saniyede **APPROVED / auto-rule** olur. n8n → Executions'ta adımları göster.

### Perde 1b · Eşiğin üstü, insan devrede

```zsh
./scripts/create-order.sh -a 15000      # ya da formdan: Anadolu Makina · Filtre Kartuşu · 40
```

n8n *send-and-wait* ile durur; execution **waiting**'e geçer. Telegram'a özet + **Onayla / Reddet**
düşer. Onayla → "Action recorded" sayfası → listede **APPROVED / Telegram**.

**Reddet** iki adımlıdır: bot "Ret Gerekcesi" mesajı ve **Gerekce Yaz** düğmesi gönderir, kısa bir form
açılır. Gerekçe yazılınca **REJECTED** olur ve gerekçe `note` alanına düşer. Form **2 dakika** içinde
doldurulmazsa workflow kendiliğinden devam eder ve sipariş "Telegram uzerinden reddedildi" notuyla
REJECTED olur.

Tutar vermezsen CAP hesaplar: `./scripts/create-order.sh` → 40 × 375,00 = **15.000,00**.
`-c` müşteri, `-p` ürün, `-q` adet. `./scripts/watch-order.sh <ID>` bir siparişi sonuçlanana kadar izler.

### Perde 2 · AI Agent

n8n'de `02 - Order Agent` workflow'unu aç; üç tool node'unun açıklamalarını ve `Siparis Agent`
system prompt'unu göster (*"Asla tahmin etme, asla uydurma. Tool sonucu boş döndüyse bulunamadı demektir."*).

Çalıştırmak için üç yol:

- **Yerel sohbet sayfası** (en sağlamı): `http://localhost:4004/chat.html`. Mesajı doğrudan
  `localhost:5678`'deki Chat Trigger'a gönderir, örnek istemler tıklanabilir, geçen süreyi gösterir.
- **Editör içindeki Chat:** `02`'yi aç → alttaki **Chat** düğmesi. Tool'lar canvas'ta sırayla yanar.
  n8n yeniden başlatıldıysa sekmeyi yenile.
- n8n'in kendi sayfası `http://localhost:5678/webhook/b2000000-0000-4000-8000-000000000011/chat`:
  mesajı `WEBHOOK_URL` üzerinden gönderir; tünel kullanıyorsan tünel koparsa çalışmaz.

Örnek istemler:

| İstem | Beklenen |
|---|---|
| `Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç` | 15.000 TRY sipariş oluşur, onay kanalına düşer |
| `Ege Teknik'e 5 adet Conta Seti 100lük siparişi aç` | 475 TRY, otomatik onay |
| `Toros Kimya'ya 3 adet Süper Filtre 9000 siparişi aç` | "bulunamadı", sipariş açılmaz |
| `Yok Böyle Firma'ya 2 kutu Conta Seti 100lük siparişi aç` | "müşteri kayıtlı değil", sipariş açılmaz |
| `Sensörlü Debimetre'nin birim fiyatı ne?` | 2.750 TRY; yalnız `listProducts` çağrılır |
| `Az önce açtığın siparişi onayla` | Onay tool'u yok; karar kuralda ve insanda |

**LLM'siz yedek**, her hâlükârda hazır:

```zsh
./scripts/agent-demo.sh                      # üç çağrıyı elle, konuşma hızında
./scripts/agent-demo.sh -p "Olmayan Urun"    # ürün bulunamadı → agent DURUR
./scripts/agent-demo.sh -c "Yok Boyle Firma" # müşteri bulunamadı → agent DURUR
./scripts/agent-demo.sh --fast               # duraklamasız
```

### Döngü ve dayanıklılık

Agent'ın açtığı 15.000'lik sipariş Perde 1'deki **aynı** workflow'u tetikler; agent oluşturdu,
**onaylamadı**. n8n kapalıyken de sipariş oluşur:

```zsh
./scripts/stop-demo.sh --n8n        # orkestrasyonu kapat
./scripts/create-order.sh -a 700    # HTTP 201, sipariş PENDING kalır
./scripts/start-demo.sh --n8n       # geri getir
```

## 8. Onay kanalları: Telegram ve Form

CAP hangi workflow'a göndereceğini `.env`'den okur; `./scripts/mode.sh telegram|form` dosyayı yazar ve
CAP'i yeniden başlatır (~10 sn, liste 3 tohum kayda döner). n8n'e dokunmaz; 01 ve 04 aynı anda aktiftir.

### A · Telegram, tünelsiz (varsayılan)

Telegram `localhost` adresli düğmeleri reddeder ama **IP adresli** düğmeleri kabul eder.
`start-demo.sh` tünel yoksa n8n'i `WEBHOOK_URL=http://127.0.0.1:5678/` ile başlatır; Onayla / Reddet
düğmeleri `127.0.0.1`'i gösterir ve **n8n'in çalıştığı bilgisayardaki** Telegram Web ya da Desktop'tan
tıklanınca çalışır. Tünel, cloudflared, özel port gerekmez; Telegram API'ye (443) erişim yeter.
Düğmeye telefondan basılamaz.

### A2 · Telegram, tünelli (başka cihazdan onay)

```zsh
brew install cloudflared
./scripts/start-demo.sh --tunnel     # cloudflared quick tunnel açar, n8n'i public URL ile başlatır
```

Düğmeler telefondan da çalışır. Ağın **7844 portuna** çıkışa izin vermesi gerekir (kurumsal ve etkinlik
ağları sık engeller; `check-demo.sh` tüneli 530 ile raporlar). Quick tunnel 20-30 dakika sonra
kendiliğinden kopabilir; koparsa `./scripts/stop-demo.sh --n8n && ./scripts/start-demo.sh --n8n --tunnel`.

### B · Form (internet gerekmez)

```zsh
./scripts/mode.sh form                # .env → order-approval-offline, CAP yeniden başlar
./scripts/create-order.sh -a 15000
./scripts/form-url.sh                 # bekleyen onay formunu tarayıcıda açar → Karar: Onayla, Onaylayan: adın
```

04 workflow'u, form beklemeye geçmeden önce Telegram'a **düz metin** bir bildirim de atar (özet + form
linki, düğme yok); internet yoksa bu adım atlanır, form yine çalışır. n8n **tünelsiz** başlatılmalıdır;
tünelliyken form linki tünel adresini üretir.

## 9. Ortam değişkenleri

Dosya: `order-demo/.env` (`.env.example`'dan kopyalanır, commit edilmez).

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `N8N_WEBHOOK_URL` | `http://localhost:5678/webhook/order-approval` | CAP'in tetiklediği webhook. Form modu: `.../webhook/order-approval-offline`. Editörde **Test workflow** ile denerken `/webhook/` yerine `/webhook-test/` |
| `N8N_WEBHOOK_KEY` | `sit-ankara-2026` | `X-API-Key` header'ı; n8n'deki "CAP Webhook Key" credential'ı ile aynı olmalı. Demo anahtarıdır |
| `N8N_WEBHOOK_TIMEOUT_MS` | `3000` | CAP'in n8n'i beklediği süre. Aşılırsa sipariş yine oluşur |

> **İsim çakışması.** `N8N_WEBHOOK_URL` aynı zamanda n8n'in kendi yapılandırma değişkenidir (webhook taban
> adresi). Kabukta export edilmiş hâldeyse n8n onu taban adres sanır (form linkleri
> `…/webhook/order-approval/form-waiting/…` olur) ve CAP `.env`'i okuyamaz (`@sap/cds` mevcut ortam
> değişkenini `.env` ile ezmez). `start-demo.sh` bu yüzden n8n için değişkeni unset edip `WEBHOOK_URL`'i
> açıkça verir, CAP'i `.env`'i `set -a` ile yükleyerek başlatır. Script dışından başlatıyorsan
> `unset N8N_WEBHOOK_URL`.

## 10. Script'ler

Hepsi zsh, repo kökünü kendi konumlarından bulur, herhangi bir dizinden çağrılabilir. n8n veritabanına
yazanlar (`setup-mac`, `set-chat-id`, `set-*-key`, `pick-gemini-model`, `publish-workflows`) **n8n
kapalıyken** çalışır.

| Script | Ne yapar |
|---|---|
| `setup-mac.sh [--force]` | Tek seferlik kurulum: npm install, `.env`, webhook credential'ı, 4 workflow import |
| `start-demo.sh [--tunnel] [--bg] [--cap] [--n8n]` | n8n ve CAP'i başlatır (varsayılan iki Terminal penceresi; `--bg` arka plan, loglar `.demo-logs/`) |
| `stop-demo.sh [--cap] [--n8n]` | Durdurur, portları boşaltır, tüneli kapatır |
| `check-demo.sh [--full]` | Ön kontrol: araçlar, CAP, n8n, webhook + anahtar, onay kanalı; `--full` gerçek bir uçtan uca tur |
| `mode.sh [telegram\|form]` | Onay kanalını değiştirir ve CAP'i yeniden başlatır; parametresiz mevcut modu gösterir |
| `create-order.sh [-a tutar] [-c müşteri] [-p ürün] [-q adet]` | Test siparişi açar |
| `watch-order.sh <ID> [saniye]` | Siparişi `PENDING`'den çıkana kadar izler |
| `form-url.sh [--print] [sipariş-id]` | Form modunda bekleyen son onay formunu bulur ve açar |
| `agent-demo.sh [-c] [-p] [-q] [--fast]` | Perde 2'yi LLM'siz oynar: üç tool çağrısını elle |
| `set-chat-id.sh <id>` | Telegram chat id'yi 01, 03 ve 04'e yazar (repo JSON'ları + n8n) |
| `set-groq-key.sh <gsk_...> [--model id] [--list]` | Agent'ı Groq üzerindeki açık kaynak modele geçirir, yayınlar |
| `set-gemini-key.sh <AIza...>` | Gemini anahtarını kaydeder, 02'ye bağlar |
| `pick-gemini-model.sh [--list] [model]` | Anahtarın tool calling yapabildiği bir Gemini modeli bulup 02'ye yazar |
| `publish-workflows.sh [--check]` | Taslakları yayınlar, 01/02/04'ü aktif eder |

## 11. Workflow'lar

Dört workflow, n8n 2.x export formatında. Credential id'leri (`REPLACE_WITH_YOUR_CREDENTIAL_ID`) ve
`<CHAT_ID>` bilerek yer tutucudur; `setup-mac.sh` webhook credential'ını bağlar, gerisini § 6.2 yapar.
Elle import ediyorsan (Workflows → Import from File) `CAP Webhook Key` adlı bir Header Auth credential'ı
(Name `X-API-Key`, Value `.env`'deki anahtar) oluşturup webhook node'larında seç; her workflow'un
Settings → Error workflow alanında `03`'ü seç.

### 01 · Order Approval (Telegram)

| Node | Ne yapar |
|---|---|
| `CAP Webhook` | `POST /webhook/order-approval`, Header Auth. Anahtar uyuşmazsa 403 |
| `Siparis Bilgileri` | Gövdeyi okunaklı alanlara açar |
| `Tutar > 10.000 mu?` | **Onay eşiği burada.** Değiştirmek için bu node'u düzenle, CAP'e dokunma |
| `Telegram Onay Iste` | send-and-wait: özet + Onayla / Reddet. Execution `waiting`; saatlerce bekleyebilir |
| `Onaylandi mi?` | `data.approved` dalını ayırır |
| `CAP approve (Telegram)` | `POST /approve {ID, approvedBy: "Telegram"}` |
| `Ret Sebebi Sor` | send-and-wait, serbest metin. **Limit Wait Time 2 dk:** cevap gelmezse varsayılan gerekçeyle devam |
| `CAP reject (Telegram)` | `POST /reject {ID, reason}` |
| `CAP approve (auto-rule)` | Eşiğin altı: `{ID, approvedBy: "auto-rule"}` |

### 02 · Order Agent (Chat)

| Node | Ne yapar |
|---|---|
| `Chat Trigger` | Public mod; editör Chat paneli, `chat.html` ve n8n'in kendi sayfası buraya gelir |
| `Siparis Agent` | System prompt: asla tahmin etme; sırayla ürünü, müşteriyi doğrula, sonra sipariş aç. Onay tool'u **yok** |
| `Chat Model` | Repoda Groq `openai/gpt-oss-120b`, temperature 0, Retry On Fail. `set-gemini-key.sh` ile Gemini'ye çevrilebilir |
| `Simple Memory` | Aynı sohbet içinde bağlam |
| `listProducts` | `GET /Products?$filter=contains(name,'…')` — "sipariş oluşturmadan ÖNCE MUTLAKA bu tool'u kullan" |
| `getCustomer` | `GET /Customers?$filter=contains(name,'…')` — "boş liste dönerse müşteri KAYITLI DEĞİLDİR" |
| `createOrder` | `POST /Orders` — "bu tool veri yazar, sadece doğruladıktan SONRA çağır". `amount` göndermez, CAP hesaplar |

### 03 · Error Handler

`Error Trigger → Telegram`. 01, 02 ve 04'ün `settings.errorWorkflow` alanı `demo03`'ü gösterir; bir
execution hata verirse workflow adı, node, hata mesajı ve execution numarası Telegram'a gider.

### 04 · Order Approval (OFFLINE / Form)

01 ile aynı iskelet; Telegram send-and-wait yerine **Wait → Resume on form submission**.
`Siparis Bilgileri` node'u `onayFormUrl` (= `$execution.resumeFormUrl`) üretir; `Telegram Bildir`
özet + bu linki düz metin olarak gönderir (`onError: continue`, internet yoksa atlanır); `Form ile Onay
Bekle` formu bekler (alanlar: Karar = Onayla / Reddet, Onaylayan); `CAP approve (Form)` onaylayan adını
yazar. Form adresini elle kurma: n8n linke tek kullanımlık bir imza ekler, `form-url.sh` hazır verir.

## 12. CAP servisi

Üç katman: **db** (veri) → **srv** (servis + iş mantığı) → **app** (UI). Kök: `http://localhost:4004/odata/v4/order`.

### Veri modeli (`db/schema.cds`)

| Entity | Alanlar |
|---|---|
| `Orders` (`managed`) | `ID` UUID · `customer`, `product` String(100) · `qty` Integer · `amount` Decimal(15,2) · `currency` (varsayılan `TRY`) · `status` `PENDING`\|`APPROVED`\|`REJECTED` · `approvedBy` · `approvedAt` · `note` · `createdAt`, `modifiedAt`… |
| `Customers` | `ID` (`C001`…), `name`, `city` — 4 kayıt |
| `Products` | `ID` (`P001`…), `name`, `unitPrice` — 6 kayıt |

`customer` ve `product` bilerek düz metindir; agent'ın ürünü **isimle** doğrulaması anlatılır. Projeksiyon
ayrıca hesaplanan `statusCriticality` alanını döner (APPROVED 3, PENDING 2, REJECTED 1); Fiori'deki renkli
durum sütununu bu sürer.

**Fiyatlar** `db/data/order.demo-Products.csv` içindedir (Filtre Kartuşu 375, Çelik Vana 1.250, Hidrolik
Hortum 480, Debimetre 2.750, Conta Seti 95, Manometre 640). Veritabanı **in-memory SQLite**: `cds watch`
her başladığında CSV'ler yeniden yüklenir, liste 3 siparişe döner. Fiyat değiştirmek ya da ürün eklemek
için CSV'ye satır ekle, CAP'i yeniden başlat. Eşik üstü hazır kombinasyon: **40 × 375 = 15.000**.

### Servis davranışı (`srv/order-service.js`)

- **before CREATE:** `currency` boşsa `TRY`, `status` boşsa `PENDING`; `amount` yoksa `qty × unitPrice`
  (ürün adıyla `Products`'tan), ürün yoksa **400**. Müşteri doğrulanmaz; bu bilinçli, agent'ın müşteri
  koruması prompt'tadır.
- **after CREATE:** `req.on('succeeded')` içinde `N8N_WEBHOOK_URL`'e `POST`, `X-API-Key` header'ı ile,
  fire-and-forget. n8n kapalıysa `warn` loglanır, sipariş yine `201`.
- **approve / reject:** `status`, `approvedBy`, `approvedAt` günceller. Zaten hedef durumdaysa mevcut kaydı
  `200` ile döner (idempotent); başka nihai duruma geçiş `409`; ID yoksa `400`, sipariş yoksa `404`.
  `reject(ID, reason)` imzası gereği `approvedBy = n8n` yazılır, kimin reddettiği `reason` ile `note`
  alanına düşer.

### Uçlar

| Uç | Metod | Ne döner |
|---|---|---|
| `/Orders` | GET · POST | Siparişler; POST yeni sipariş |
| `/Orders(<uuid>)` | GET | Tek sipariş (OData V4 söz dizimi; `guid'...'` **400**) |
| `/Products`, `/Customers` | GET | Salt okunur ana veri |
| `/approve` | POST `{ID, approvedBy}` | Onaylar |
| `/reject` | POST `{ID, reason}` | Reddeder |
| `/$metadata` | GET | EDMX |

Listeler `createdAt`'e göre **yeniden eskiye** sıralıdır: `app/index.html` `$orderby=createdAt desc&$top=8`,
Fiori `UI.PresentationVariant`. OData'nın varsayılan sırası UUID'ye göredir, buna güvenme.

Açılışta görünen `custom action 'reject()' conflicts with method in base class` uyarısı zararsızdır.

## 13. Sorun giderme

| Belirti | Sebep | Çözüm |
|---|---|---|
| Webhook **404**, CAP logunda `webhook failed` | Workflow aktif değil | n8n'de **Activate**. `check-demo.sh` bunu yakalar |
| Webhook **403** | `X-API-Key` uyuşmuyor | `.env`'deki `N8N_WEBHOOK_KEY` ile n8n'deki credential Value'su aynı olmalı; `setup-mac.sh` senkronlar |
| `Credential with ID "REPLACE_WITH_..." does not exist` | § 6.2-a atlanmış | Node'u aç, credential'ı seç |
| `Credential ... does not exist` (credential seçili) / değişiklik çalışmıyor | Yayınlanan sürüm eski | Active kapat/aç ya da `./scripts/publish-workflows.sh` (n8n kapalıyken) |
| Telegram `chat not found` | Bot seninle hiç konuşmamış | Bota önce sen mesaj at, chat id'yi doğrula |
| Telegram: `inline keyboard button URL ... is invalid` | n8n taban adresi `localhost` | `start-demo.sh` ile başlat (taban `127.0.0.1`) ya da `--tunnel` |
| Onay düğmesi bir şey açmıyor | Düğme `127.0.0.1`'e gidiyor | n8n'in çalıştığı bilgisayardaki Telegram Web/Desktop'tan tıkla; telefondan onay için `--tunnel` |
| Reddet'e bastım, sipariş PENDING kaldı | Gerekçe formu bekleniyor | **Gerekce Yaz** ile formu doldur ya da 2 dk bekle |
| Tünel 530 / açılmıyor, logda "Allow outbound TCP on port 7844" | Ağ 7844'ü engelliyor | Tünelsiz Telegram (§ 8-A) ya da Form modu |
| Mod değiştirdim ama CAP eski workflow'a gidiyor; form linki `/webhook/order-approval/` içeriyor | Kabukta export edilmiş `N8N_WEBHOOK_URL` | `unset N8N_WEBHOOK_URL`, script'lerle yeniden başlat (§ 9) |
| Chat: **Error in workflow**, 1-3 sn içinde | LLM 429 (kota) ya da 503 (yoğunluk) | n8n → Executions'ta hatayı oku. Gemini'de günlük 20 istek / model; Groq'a geç (`set-groq-key.sh`) ya da `agent-demo.sh` |
| Chat: **Failed to receive response**, execution yok | Sekme eski ya da tünel kopmuş | Sekmeyi yenile; `chat.html` kullan |
| Agent ürün/müşteri uydurdu | Model tool'u atladı | `Chat Model` → Temperature 0 (paket 0 ile gelir) |
| `port 4004 is already in use` | Önceki `cds watch` açık | `./scripts/stop-demo.sh` |
| `command not found: n8n` / `cds` | nvm PATH'i yeni kabukta yok | Yeni Terminal aç ya da script'leri kullan |
| Terminal penceresi açılmıyor | Otomasyon izni | Sistem Ayarları → Gizlilik ve Güvenlik → Otomasyon → Terminal; ya da `--bg` |
| Listede fazladan sipariş var | Prova siparişleri | `./scripts/stop-demo.sh --cap && ./scripts/start-demo.sh --cap` |

## 14. Sık sorulan sorular

**Bu üretimde çalışır mı?** Mimari evet, bu kurulum hayır. Burada in-memory SQLite ve lokal n8n var.
Üretimde CAP BTP'ye (HANA Cloud, XSUAA), n8n kendi sunucunuza ya da BTP'deki yönetilen sürümüne gider;
webhook'a OAuth2 / mTLS ve IP allowlist konur; geri yazma asenkron kuyruğa alınır. Desen aynı kalır.

**Neden SAP Build Process Automation ya da Integration Suite değil?** Onlar da geçerli. n8n'in avantajı
SAP dışı yüzlerce entegrasyonu ve LLM / agent node'larını hazır getirmesi ve laptopta beş dakikada ayağa
kalkması. Seçim, sürecin ağırlık merkezinin SAP'de mi dışarıda mı olduğuna bağlı.

**Agent yanlış sipariş açarsa?** İki koruma: agent ürünü ve müşteriyi doğrulamadan `createOrder`
çağıramıyor, CAP de bilinmeyen ürüne 400 dönüyor. Açtığı her sipariş `PENDING`; onay hâlâ kuralda ve
insanda. n8n 2.6+ ile tek bir tool'un çalışması da insan onayına bağlanabiliyor.

**Maliyet?** Yalnızca Perde 2'deki LLM çağrıları; Groq ve Gemini'nin ücretsiz katmanları demo için yeter.
Perde 1'de model yok, deterministik kural.

## 15. Üretime taşırken

| Konu | Demoda | Üretimde |
|---|---|---|
| Kimlik doğrulama | Statik `X-API-Key`, CAP'te auth yok | Webhook'ta JWT / OAuth2, IP allowlist; CAP'te XSUAA, `approve`/`reject` için ayrı scope |
| Geri yazma | Senkron HTTP | Asenkron (kuyruk / Event Mesh), retry ve idempotency anahtarı |
| Veritabanı | In-memory SQLite | HANA Cloud; n8n için Postgres |
| n8n işletimi | `npm i -g n8n`, SQLite | Sabit sürüm, Postgres, encryption key yedeği, queue mode |
| Lisans | Community (fair-code) | Kurum içi self-host ücretsiz; servis olarak satılamaz. SSO, environments, secret store, SLA ücretli katmanda |
| Denetim | Executions ekranı | Execution verisini saklama politikası, log forwarding, PII maskeleme |

## 16. Notlar

Müşteri ve ürün adları uydurma örnek verilerdir. Demo kodu eğitim amaçlıdır; üretime taşımadan önce
§ 15'i oku. Soru, düzeltme ve öneriler için issue açabilirsin.
