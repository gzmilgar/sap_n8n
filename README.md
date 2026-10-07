# SAP + n8n: API'lerden Akıllı Workflow'lara

> **SAP veriyi tutar, n8n orkestre eder, agent sadece bir arayüzdür.**

SAP Inside Track Ankara (Ekim 2026) için hazırlanan **20 dakikalık canlı demo**nun tam paketi:
SAP CAP servisi, dört n8n workflow'u, sahne script'leri ve sunum destesi.
Her şey bir dizüstü bilgisayarda, **Docker'sız ve BTP hesabı gerektirmeden** çalışır.

| Ne arıyorsun | Nereye bak |
|---|---|
| Kurup çalıştırmak | Bu dosya: [Hızlı başlangıç](#5-hızlı-başlangıç) → [Demoyu çalıştırma](#7-demoyu-çalıştırma) |
| CAP uygulaması içeriden (veri modeli, fiyat, webhook, action'lar) | [order-demo/MIMARI.md](order-demo/MIMARI.md) |
| Workflow'lar node node | [n8n-workflows/README.md](n8n-workflows/README.md) |
| Script'ler | [scripts/README.md](scripts/README.md) |
| Sunum destesi ve sahnedeki dakika dakika akış | [sunum/README.md](sunum/README.md) · [sunum/SUNUM-NOTLARI.md](sunum/SUNUM-NOTLARI.md) |

<details>
<summary><b>English summary</b></summary>

A two-act live demo of an order-approval loop built with **SAP CAP** (OData V4, Fiori Elements)
and **n8n**. Act 1: CAP fires a webhook on order creation; n8n auto-approves orders under a
threshold and asks a human on Telegram above it, then writes the decision back through CAP
`approve`/`reject` actions. Act 2: an n8n AI Agent (Google Gemini free tier) uses the same
OData service through three HTTP Request tools (look up product, look up customer, create order).
The agent only *creates*; the approval decision stays in a deterministic IF node and a human.
Everything runs locally (in-memory SQLite, no Docker). Docs are in Turkish; the code, workflow
JSONs and scripts are self-explanatory.
</details>

---

## İçindekiler

1. [Demo ne gösteriyor](#1-demo-ne-gösteriyor)
2. [Mimari](#2-mimari)
3. [Repo haritası](#3-repo-haritası)
4. [Gereksinimler](#4-gereksinimler)
5. [Hızlı başlangıç](#5-hızlı-başlangıç)
6. [Kurulum ayrıntıları](#6-kurulum-ayrıntıları)
7. [Demoyu çalıştırma](#7-demoyu-çalıştırma)
8. [Onay modları: Telegram ve Form](#8-onay-modları-telegram-ve-form)
9. [Ortam değişkenleri](#9-ortam-değişkenleri)
10. [Script'ler](#10-scriptler)
11. [Workflow'lar](#11-workflowlar)
12. [CAP servisi](#12-cap-servisi)
13. [Sorun giderme](#13-sorun-giderme)
14. [Sık sorulan sorular](#14-sık-sorulan-sorular)
15. [Üretime taşırken](#15-üretime-taşırken)
16. [Sunum destesi](#16-sunum-destesi)
17. [Windows notu](#17-windows-notu)
18. [Lisans ve katkı](#18-lisans-ve-katkı)

---

## 1. Demo ne gösteriyor

İki perdelik bir **Sipariş Onay Döngüsü**.

| Perde | Ne olur |
|---|---|
| **1 · APIs** | CAP'te sipariş oluşur → CAP webhook'u n8n'i tetikler → tutar **10.000 TRY** üzerindeyse Telegram'dan onay istenir, değilse otomatik onaylanır → sonuç CAP'e `approve` / `reject` action'ı ile geri yazılır → Fiori listesinde durum rengi değişir. |
| **2 · Intelligent** | Bir n8n **AI Agent**, üç HTTP Request Tool ile aynı CAP OData servisini kullanır: ürün ara, müşteri ara, sipariş oluştur. Sipariş açılır → CAP handler Perde 1'i tetikler → Telegram yine öter → **döngü kapanır**. |

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
            │  Sipariş formu  (app/index.html)                          │
            └───────┬───────────────────────────────────▲───────────────┘
   after CREATE     │ POST webhook (X-API-Key)          │ POST /approve · /reject
   (commit sonrası) │                                   │
            ┌───────▼───────────────────────────────────┴───────────────┐
            │                      n8n  (localhost:5678)                │
            │  01  Webhook → IF tutar > 10.000 ─ hayır → approve(auto-rule)
            │                                  └ evet  → Telegram send-and-wait
            │                                             ├ Onayla → approve(Telegram)
            │                                             └ Reddet → reject(...)
            │  02  Chat Trigger → AI Agent (Gemini) ─┬ listProducts  (GET Products)
            │                                        ├ getCustomer   (GET Customers)
            │                                        └ createOrder   (POST Orders) ──► 01'i tetikler
            │  03  Error Trigger → Telegram
            │  04  01'in Telegram'sız kopyası: onay n8n Form ile (internetsiz yedek)
            └───────────────────────────────────────────────────────────┘
```

Bir siparişin hayatı (ayrıntı: [order-demo/MIMARI.md § 6](order-demo/MIMARI.md#6-bir-siparişin-hayatı--adım-adım)):

1. `POST /Orders` gelir (script, form ya da agent).
2. `before CREATE`: para birimi `TRY`, durum `PENDING`; `amount` yoksa `qty × unitPrice` hesaplanır, ürün yoksa **400**.
3. INSERT ve commit.
4. `after CREATE` → `req.on('succeeded')` içinde webhook atılır. Commit'ten *sonra* tetiklenir; yoksa n8n'in milisaniyeler içinde dönen `approve` çağrısı INSERT ile yarışıp 404 alırdı.
5. n8n karar verir ve `approve` / `reject` ile geri yazar. Action'lar **idempotent**: iki kez tıklamak veya webhook retry'ı demoyu bozmaz.
6. Fiori listesi yenilenince `statusCriticality` (yeşil 3 / sarı 2 / kırmızı 1) renk değiştirir.

## 3. Repo haritası

```
sap_n8n/
├─ README.md                           ← bu dosya
├─ SUNUM.pptx                          ← 11 slayt, konuşmacı notlu
├─ sunum/
│  ├─ README.md                        desteyi yeniden üretme
│  ├─ SUNUM-NOTLARI.md                 sahnedeki dakika dakika akış, kurtarma hamleleri, SSS
│  ├─ build-deck.js · lib.js           pptxgenjs ile deste üretimi
├─ order-demo/                         # SAP CAP servisi
│  ├─ MIMARI.md                        uygulamanın satır satır anlatımı
│  ├─ README.md                        kısa özet + hızlı doğrulama
│  ├─ db/schema.cds                    Orders · Customers · Products
│  ├─ db/data/*.csv                    4 müşteri · 6 ürün · 3 sipariş (fiyatlar burada)
│  ├─ srv/order-service.cds            OData servisi + approve/reject action'ları
│  ├─ srv/order-service.js             tutar hesabı, webhook, idempotent onay
│  ├─ app/fiori-annotations.cds        UI.LineItem, criticality, Türkçe etiketler
│  ├─ app/index.html                   "Sipariş Aç" formu, canlı tutar, kendini yenileyen liste
│  └─ .env.example · package.json
├─ n8n-workflows/
│  ├─ README.md                        her workflow node node
│  ├─ 01-order-approval.json           Perde 1 · Telegram onayı            (9 node)
│  ├─ 02-order-agent.json              Perde 2 · AI Agent + 3 tool          (7 node)
│  ├─ 03-error-handler.json            hata → Telegram                     (2 node)
│  └─ 04-order-approval-OFFLINE.json   Perde 1'in Form ile internetsiz hâli (8 node)
└─ scripts/
   ├─ README.md
   ├─ setup-mac.sh · start-demo.sh · stop-demo.sh · check-demo.sh
   ├─ create-order.sh · watch-order.sh · agent-demo.sh
   ├─ set-chat-id.sh · set-gemini-key.sh · pick-gemini-model.sh · publish-workflows.sh
   ├─ lib-demo.sh · gemini_pick.py     ortak yardımcılar
   └─ windows/                         PowerShell sürümleri (bakımı yapılmıyor)
```

## 4. Gereksinimler

Paket **macOS** üzerinde uçtan uca doğrulandı. Script'ler zsh ister; macOS'ta hazır gelen
`python3` ve `sqlite3` da kullanılır.

| Bileşen | Sürüm | Not |
|---|---|---|
| macOS | Apple Silicon üzerinde test edildi | Intel'de de çalışması beklenir |
| Node.js | **≥ 20** (`package.json` → `engines`), test: v24 | nvm önerilir; script'ler nvm PATH'ini kendileri çözer |
| `@sap/cds-dk` | 10.x, global | `npm i -g @sap/cds-dk` |
| n8n | 2.x (test: 2.39), global | `npm i -g n8n` · **Docker gerekmez** |
| cloudflared | isteğe bağlı | Telegram onayı için şart, bkz. [§ 8](#8-onay-modları-telegram-ve-form) · `brew install cloudflared` |
| Telegram botu | isteğe bağlı | @BotFather'dan bir bot token'ı; Perde 1b için |
| Google Gemini anahtarı | isteğe bağlı, ücretsiz | Perde 2'yi canlı LLM ile oynamak için; LLM'siz yedek de var |

İnternet yalnızca Telegram ve LLM için gerekir. İkisi de yoksa **04 numaralı offline
workflow** ve `agent-demo.sh` aynı hikâyeyi internetsiz anlatır.

## 5. Hızlı başlangıç

```zsh
git clone https://github.com/gzmilgar/sap_n8n.git ~/sap_n8n
cd ~/sap_n8n

./scripts/setup-mac.sh          # 1) tek seferlik kurulum: npm install, .env, credential + workflow import
./scripts/start-demo.sh         # 2) iki Terminal penceresi: n8n (:5678) ve cds watch (:4004)
open http://localhost:5678      # 3) hesap aç → credential'ları bağla → chat id → 01'i Activate  (bkz. § 6)
./scripts/check-demo.sh --full  # 4) sahne öncesi kontrol; son satır "Her şey hazır" demeli

./scripts/create-order.sh -a 500      # otomatik onay
./scripts/create-order.sh -a 15000    # Telegram onayı  (--tunnel ile başlatılmış olmalı)
open "http://localhost:4004/\$fiori-preview/OrderService/Orders#preview-app"

./scripts/stop-demo.sh          # kapat
```

Telegram onayını gerçekten görmek için n8n'i `./scripts/start-demo.sh --tunnel` ile
başlat; nedenini [§ 8](#8-onay-modları-telegram-ve-form) anlatıyor.

## 6. Kurulum ayrıntıları

### 6.1 `setup-mac.sh` ne yapar

1. `order-demo` içinde `npm install` çalıştırır ve `.env.example`'dan `.env` üretir.
2. n8n veritabanında **"CAP Webhook Key"** adlı bir *Header Auth* credential'ı oluşturur; değeri `.env`'deki `N8N_WEBHOOK_KEY` ile aynıdır. Böylece CAP'in gönderdiği `X-API-Key` header'ı ile n8n'in beklediği anahtar baştan senkron olur.
3. Dört workflow'u n8n'e import eder ve webhook node'larına bu credential'ı **bağlı** hâlde getirir.

> n8n kuruluysa önce durdur: `./scripts/stop-demo.sh`. Import, n8n kapalıyken yapılır.

> Script, demo workflow'ları n8n'de zaten varsa import'u **atlar**. `--force` ile zorlarsan
> arayüzde seçtiğin Telegram / Gemini credential'ları ve chat id sıfırlanır, workflow'lar
> pasife düşer; § 6.2'yi baştan yaparsın.

### 6.2 n8n'de elle yapılacak dört şey

`http://localhost:5678` → ilk açılışta yerel hesabını oluştur, sonra:

**a) İki credential oluştur** (secret içerdikleri için script yapamaz):

| Credential adı | Tip | Hangi node'lar | Zorunlu mu |
|---|---|---|---|
| `Telegram account` | Telegram API (bot token) | 01 ve 03'teki Telegram node'ları | Evet, Perde 1b için |
| `Google Gemini account` | Google Gemini (PaLM) API | 02'deki `Chat Model` | Hayır, Perde 2 LLM'siz de oynanır |

Gemini anahtarı için tek komut da var: `./scripts/set-gemini-key.sh AIza...` anahtarı test eder,
credential olarak kaydeder ve `Chat Model` node'una bağlar. Ücretsiz anahtar: <https://aistudio.google.com/apikey>.

**b) Node'larda credential'ı seç.** `REPLACE_WITH_YOUR_CREDENTIAL_ID` yazan her node'u açıp kendi credential'ını seç ve kaydet.

**c) Telegram chat id'ni yaz.** En kolayı, n8n kapalıyken:

```zsh
./scripts/stop-demo.sh
./scripts/set-chat-id.sh 123456789      # grup için -100...
./scripts/start-demo.sh
```

Hem repodaki JSON'ları hem n8n'deki kopyaları günceller, seçtiğin credential'lara dokunmaz.
Chat id'ni bilmiyorsan Telegram'da **@get_id_bot** ile konuş. Botun sana mesaj atabilmesi için
**önce sen bota** bir mesaj göndermiş olmalısın.

**d) `01 - Order Approval` workflow'unu Activate et.** Offline provası için `04`'ü de aktif et.

> **En sık yapılan hata.** Workflow aktif değilse production webhook kayıtlı olmaz ve CAP
> `404` alır. `n8n update:workflow --active=true` CLI komutu n8n 2.x'te yayınlanmış sürüm
> üretmediği için **işe yaramaz**; UI'daki Activate anahtarını kullan.

### 6.3 n8n 2.x'te "taslak" ve "yayınlanmış" sürüm

n8n 2.x, bir workflow'un **yayınlanmış** sürümünü çalıştırır, editörde gördüğün taslağı değil.
Editörde bir şey değiştirip kaydettiğinde production webhook hâlâ eski sürümü çalıştırıyor
olabilir. Belirtisi: ayarlar "tutmuyor", ya da `Credential with ID ... does not exist`.

Çözüm: workflow'un **Active** anahtarını kapat/aç. Toplu çözüm: `./scripts/publish-workflows.sh`
(taslakları yayınlar, 01/02/04'ü aktif eder; `--check` ile sadece durumu gösterir).

### 6.4 Kontrol

```zsh
./scripts/check-demo.sh          # hızlı: portlar, workflow'lar aktif mi, hangi onay modundasın
./scripts/check-demo.sh --full   # + gerçek bir sipariş açıp tüm zinciri dener (listeye 1 prova siparişi bırakır)
```

## 7. Demoyu çalıştırma

Sahnedeki tam senaryo, konuşma metni ve dakika planı [sunum/SUNUM-NOTLARI.md](sunum/SUNUM-NOTLARI.md)'de.
Burada teknik akış var.

### Açık olacak ekranlar

| Ekran | Adres |
|---|---|
| Sipariş Aç formu | `http://localhost:4004` |
| Fiori listesi | `http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app` |
| n8n editörü | `http://localhost:5678` |
| Telegram Web | `web.telegram.org` → bot sohbeti (onay butonuna **buradan** basılır) |

### Perde 1a · Eşiğin altı, insan yok

```zsh
./scripts/create-order.sh -a 500
```

CAP kaydeder, webhook atar; n8n'de IF *false* dalı `approve(ID, "auto-rule")` çağırır. Fiori'de
sipariş yaklaşık 1 saniyede **APPROVED / auto-rule** olur. n8n → Executions'ta adımları göster.

### Perde 1b · Eşiğin üstü, insan devrede

```zsh
./scripts/create-order.sh -a 15000
```

n8n *send-and-wait* ile durur; execution **waiting** durumuna geçer ve saatlerce bekleyebilir.
Telegram'a sipariş özeti ile **Onayla / Reddet** butonları düşer. Onayla → tarayıcıda
"Action recorded" sayfası açılır (onay budur; sohbetteki mesaj kendini güncellemez, normaldir)
→ Fiori'de **APPROVED / Telegram**. Reddet → **REJECTED**, sebep `note` alanına yazılır.

Tutar vermezsen CAP hesaplar: `./scripts/create-order.sh` → 40 × 375,00 = **15.000,00**
(Endüstriyel Filtre Kartuşu). Diğer seçenekler: `-c` müşteri, `-p` ürün, `-q` adet.
`./scripts/watch-order.sh <ID>` bir siparişi sonuçlanana kadar izler.

### Perde 2 · AI Agent

n8n'de `02 - Order Agent` workflow'unu aç. Üç tool node'una çift tıklayıp açıklamalarını göster:

| Tool | Yaptığı çağrı | Açıklamadaki kritik cümle |
|---|---|---|
| `listProducts` | `GET /Products?$filter=contains(name,'…')` | "sipariş oluşturmadan ÖNCE ürünün var olduğunu doğrulamak ve birim fiyatını öğrenmek için MUTLAKA bu tool'u kullan" |
| `getCustomer` | `GET /Customers?$filter=contains(name,'…')` | "boş liste dönerse müşteri sistemde KAYITLI DEĞİLDİR" |
| `createOrder` | `POST /Orders` | "bu tool veri yazar, bu yüzden sadece … doğruladıktan SONRA çağır" |

`Siparis Agent` node'unun system prompt'u: *"Asla tahmin etme, asla uydurma. Tool sonucu boş
döndüyse bulunamadı demektir."* `Chat Model` Google Gemini Flash, **temperature 0**.

**Canlı çalıştırma**, iki yol:

- **Editör içindeki Chat** (önerilen): `02`'yi aç → alttaki **Chat** düğmesi → yaz:
  `Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç`
  Agent sırayla `listProducts` → `getCustomer` → `createOrder` çağırır; tool'lar canvas'ta sırayla yanar.
- **Ayrı chat sayfası**: `http://localhost:5678/webhook/b2000000-0000-4000-8000-000000000011/chat`
  (02 aktifken yayında; temiz ekran ama canvas'ı göremezsin).

**LLM'siz yedek**, her hâlükârda hazır:

```zsh
./scripts/agent-demo.sh                      # üç çağrıyı elle, konuşma hızında
./scripts/agent-demo.sh -p "Olmayan Urun"    # ürün bulunamadı → agent DURUR, sipariş açılmaz
./scripts/agent-demo.sh -c "Yok Boyle Firma" # müşteri bulunamadı → agent DURUR
./scripts/agent-demo.sh --fast               # duraklamasız (prova için)
```

Mimari mesaj aynı kalır: "agent'ın yaptığı tam olarak bu üç çağrı". Fiyatı kullanıcı vermez,
**SAP söyler**.

### Döngü kapanıyor

Agent'ın açtığı sipariş 15.000 TRY olduğu için CAP webhook'u Perde 1'deki **aynı** workflow'u
tetikler ve Telegram'a onay düşer. Agent oluşturdu, **onaylamadı**.

### Dayanıklılık vurgusu

```zsh
./scripts/stop-demo.sh --n8n        # orkestrasyonu kapat
./scripts/create-order.sh -a 700    # sipariş yine oluşur: HTTP 201
./scripts/start-demo.sh --n8n       # geri getir
```

CAP logunda yalnızca `n8n webhook failed ... - order was still created` uyarısı görünür.

## 8. Onay modları: Telegram ve Form

Demonun en kritik operasyonel ayrıntısı.

### Telegram onayı `localhost` ile çalışmaz

n8n onay butonlarını Telegram sunucusuna gönderir; Telegram `localhost` adresli butonları reddeder:

```
Bad Request: inline keyboard button URL 'http://localhost:5678/...' is invalid: Wrong HTTP URL
```

Node'daki "Approve Within Chat" seçeneği de kurtarmaz (o da `setWebhook` çağırır, loopback
reddedilir). n8n 2.x'te eski `--tunnel` bayrağı kaldırılmıştır. Çözüm: n8n'e public bir adres
vermek.

### Mod A · Telegram (tünelli)

```zsh
brew install cloudflared            # bir kerelik, hesap gerektirmez
./scripts/start-demo.sh --tunnel    # cloudflared açar, n8n'i public URL ile başlatır
```

`.env` → `N8N_WEBHOOK_URL=http://localhost:5678/webhook/order-approval`

- Sahnedeki en etkileyici an: Telegram'a **Onayla / Reddet** düşer.
- İnternet şart. Tünel URL'i her başlatmada değişir; script halleder.
- Butona **demo yapılan bilgisayardaki tarayıcıdan** bas (Telegram Web sekmesi açık olsun). Telefondan çalışmaz.

### Mod B · Form (tamamen lokal)

```zsh
# order-demo/.env içinde:
N8N_WEBHOOK_URL=http://localhost:5678/webhook/order-approval-offline
```

n8n'de `04`'ü **Activate**, `01`'i **Deactivate** et, sonra:

```zsh
./scripts/stop-demo.sh && ./scripts/start-demo.sh     # --tunnel OLMADAN
```

- İnternet, tünel, Telegram gerektirmez. En güvenli mod.
- n8n **mutlaka tünelsiz** başlamalı; tünelliyken form linki tünel adresini üretir, tünel kapanınca ölür.
- Onay adresi: çalışan execution'daki `Siparis Bilgileri` node'unun **`onayFormUrl`** alanı. Adresi elle kurma; n8n linke tek kullanımlık bir `?signature=` ekler, `onayFormUrl` bunu hazır verir.

`check-demo.sh` hangi modda olduğunu ve o modun hazır olup olmadığını söyler.

### Pinned data (üçüncü yol, yalnızca manuel çalıştırmada)

İnternet varken workflow'u bir kez çalıştır → execution'da Telegram / LLM node'unun çıktısını
**pin'le** → Save. Sonraki *Test workflow* çalıştırmalarında o node dış servise gitmez.
Pin data production webhook çalıştırmalarında **devreye girmez**; tam otomatik offline akış
için `04`'ü kullan.

## 9. Ortam değişkenleri

Dosya: `order-demo/.env` (`.env.example`'dan kopyalanır, commit edilmez).

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `N8N_WEBHOOK_URL` | `http://localhost:5678/webhook/order-approval` | CAP'in tetiklediği webhook. Form modu için `.../webhook/order-approval-offline`. n8n editöründe **Test workflow** ile denerken `/webhook/` yerine `/webhook-test/`. |
| `N8N_WEBHOOK_KEY` | `sit-ankara-2026` | `X-API-Key` header'ı. n8n'deki "CAP Webhook Key" credential'ı ile aynı olmalı; `setup-mac.sh` senkron kurar. Demo anahtarıdır, üretimde değiştir. |
| `N8N_WEBHOOK_TIMEOUT_MS` | `3000` | CAP'in n8n'i beklediği süre. Aşılırsa sipariş yine oluşur, uyarı loglanır. |

## 10. Script'ler

Hepsi zsh, hepsi repo kökünü kendi konumlarından bulur; herhangi bir dizinden çağrılabilirler.
Ayrıntı: [scripts/README.md](scripts/README.md).

| Script | Ne yapar |
|---|---|
| `setup-mac.sh [--force]` | Tek seferlik kurulum: npm install, `.env`, webhook credential'ı, 4 workflow import |
| `start-demo.sh [--tunnel] [--bg] [--cap] [--n8n]` | n8n ve CAP'i başlatır. `--tunnel` cloudflared açar, `--bg` arka planda loglarla (`.demo-logs/`) |
| `stop-demo.sh [--cap] [--n8n]` | Durdurur, 4004 / 5678 portlarını boşaltır |
| `check-demo.sh [--full]` | Sahne öncesi kontrol; `--full` gerçek bir uçtan uca tur atar |
| `create-order.sh [-a tutar] [-c müşteri] [-p ürün] [-q adet]` | Test siparişi açar |
| `watch-order.sh <ID> [saniye]` | Siparişi `PENDING`'den çıkana kadar izler |
| `agent-demo.sh [-c] [-p] [-q] [--fast]` | Perde 2'yi LLM'siz oynar: üç tool çağrısını elle, konuşma hızında |
| `set-chat-id.sh <id>` | Telegram chat id'yi 01 ve 03'e yazar (repo JSON'ları + n8n DB) |
| `set-gemini-key.sh <AIza...>` | Gemini anahtarını test eder, credential olarak kaydeder, 02'ye bağlar |
| `pick-gemini-model.sh [--list] [model]` | Anahtarın tool calling yapabildiği bir Gemini modeli bulup 02'ye yazar |
| `publish-workflows.sh [--check]` | Taslakları yayınlar, 01/02/04'ü aktif eder |
| `windows/*.ps1` | Eski PowerShell sürümleri; bakımı yapılmıyor |

n8n veritabanına dokunan script'ler (`setup-mac`, `set-chat-id`, `set-gemini-key`,
`pick-gemini-model`, `publish-workflows`) **n8n kapalıyken** çalıştırılmalıdır.

## 11. Workflow'lar

Node node anlatım ve import seçenekleri: [n8n-workflows/README.md](n8n-workflows/README.md).

| Dosya | Tetikleyici | Ne yapar |
|---|---|---|
| `01-order-approval.json` | Webhook `/webhook/order-approval` (Header Auth) | IF tutar > 10.000 → Telegram send-and-wait → `approve` / `reject`; değilse `approve(auto-rule)` |
| `02-order-agent.json` | Chat Trigger | AI Agent (Gemini, Simple Memory) + 3 HTTP Request Tool: `listProducts`, `getCustomer`, `createOrder` |
| `03-error-handler.json` | Error Trigger | Herhangi bir workflow hata verirse Telegram'a bildirim (her workflow'un Settings → Error workflow alanında seçilir) |
| `04-order-approval-OFFLINE.json` | Webhook `/webhook/order-approval-offline` | 01'in aynısı, Telegram yerine n8n **Form** ile onay; internetsiz çalışır |

Değiştirmek istediğin kural **onay eşiği (10.000)** ise CAP'te değil, `01` ve `04`'teki
`Tutar > 10.000 mu?` node'undadır. Bilinçli bir tasarım: iş kuralı orkestrasyon katmanında,
SAP servisi veri ve doğrulama yapıyor.

## 12. CAP servisi

Kök: `http://localhost:4004/odata/v4/order`. Tam anlatım: [order-demo/MIMARI.md](order-demo/MIMARI.md).

| Uç | Metod | Ne döner |
|---|---|---|
| `/Orders` | GET · POST | Siparişler; POST yeni sipariş |
| `/Orders(<uuid>)` | GET | Tek sipariş (OData V4 söz dizimi, `guid'...'` yok) |
| `/Products`, `/Customers` | GET | Salt okunur ana veri |
| `/approve` | POST `{ID, approvedBy}` | Onaylar; idempotent |
| `/reject` | POST `{ID, reason}` | Reddeder; sebep `note` alanına yazılır; idempotent |
| `/$metadata` | GET | EDMX |

Veritabanı **in-memory SQLite**: `cds watch` her başladığında CSV'ler yeniden yüklenir, liste
3 siparişe döner. Demo tekrar tekrar aynı temiz durumdan oynanabilir. Fiyat değiştirmek ya da
ürün eklemek için `db/data/order.demo-Products.csv`'ye satır ekleyip CAP'i yeniden başlat.

## 13. Sorun giderme

| Belirti | Sebep | Çözüm |
|---|---|---|
| Webhook **404**, CAP logunda `webhook failed` | Workflow aktif değil | n8n'de workflow → **Activate**. `check-demo.sh` bunu yakalar. |
| Webhook **403** | `X-API-Key` uyuşmuyor | `.env`'deki `N8N_WEBHOOK_KEY` ile n8n'deki Header Auth credential Value'su aynı olmalı. `setup-mac.sh` yeniden çalıştırınca senkronlar. |
| `Credential with ID "REPLACE_WITH_..." does not exist` | § 6.2-b atlanmış | Node'u aç, kendi credential'ını seç |
| `Credential with ID ... does not exist` (credential seçili olduğu hâlde) | Yayınlanan sürüm eski | `./scripts/stop-demo.sh --n8n && ./scripts/publish-workflows.sh` |
| n8n'de yaptığın değişiklik çalışmıyor | Taslak kaydedildi, yayınlanmadı | Active anahtarını kapat/aç ya da `publish-workflows.sh` |
| Telegram `chat not found` | Bot seninle hiç konuşmamış | Bota önce sen mesaj at, sonra chat id'yi doğrula |
| Telegram `inline keyboard button URL ... Wrong HTTP URL` | n8n localhost'ta, tünel yok | `./scripts/start-demo.sh --tunnel` |
| Onay butonu bir şey açmıyor | Link bu makinedeki n8n'e gidiyor | Aynı bilgisayardaki tarayıcıdan tıkla (Telegram Web / Desktop) |
| Telegram mesajı hiç gitmiyor | Tünel kapanmış | `./scripts/stop-demo.sh --n8n && ./scripts/start-demo.sh --tunnel --n8n` |
| Form: **Invalid Form Link** | URL elle kurulmuş | `onayFormUrl` alanındaki hazır adresi kullan |
| Form linki `trycloudflare.com`'a gidiyor | n8n tünelli başlatılmış | Form modunda n8n'i tünelsiz başlat |
| Gemini `no longer available to new users` / model 404 | Google model kimliğini kapatmış | `./scripts/pick-gemini-model.sh` |
| Gemini kota / yetki hatası | Ücretsiz kota dolmuş ya da anahtar yanlış | Yeni anahtar al, ya da Perde 2'yi `agent-demo.sh` ile oyna |
| Agent ürün/müşteri uydurdu | Model tool'u atladı | `Chat Model` → **Temperature = 0** (paket 0 ile gelir) |
| `⌘S` workflow'u kaydetmiyor | Tarayıcı kısayolu yutuyor | Node panelini kapat, canvas'ın sağ üstündeki **Save**'e tıkla |
| `command not found: n8n` / `cds` | nvm PATH'i yeni kabukta yok | Yeni Terminal aç ya da script'leri kullan |
| `port 4004 is already in use` | Önceki `cds watch` açık | `./scripts/stop-demo.sh` |
| n8n açılmıyor, uzun sürüyor | İlk açılışta DB migration | Normal, 1-2 dk. `start-demo.sh` 120 sn bekler. |
| Terminal penceresi açılmıyor | Otomasyon izni | Sistem Ayarları → Gizlilik ve Güvenlik → Otomasyon → Terminal'e izin ver. Ya da `--bg` |
| Listede fazladan sipariş var | Prova siparişleri | CAP'i yeniden başlat; veritabanı in-memory |
| Açılışta `custom action 'reject()' conflicts with method in base class` | CAP yalnızca `srv.reject()` kısayolunu üretmediğini söylüyor | Zararsız; `this.on('reject')` handler'ı normal çalışır |

### Model / sağlayıcı değiştirme

Agent Google Gemini ile kurulu (`Chat Model` node'u). Başka sağlayıcıya geçmek: `Chat Model`
node'unu sil → **+** → istediğin Chat Model'i ekle → credential seç → agent'ın **Chat Model**
portuna bağla. Agent, tool'lar, memory ve system prompt aynı kalır. Diğer ücretsiz seçenekler:
**Groq** (hızlı, bedava kota), **Ollama** (tamamen lokal, internet gerekmez).

## 14. Sık sorulan sorular

**Bu üretimde çalışır mı?**
Mimari evet, bu kurulum hayır. Burada in-memory SQLite ve lokal n8n var. Üretimde CAP BTP'ye
(HANA Cloud, XSUAA), n8n kendi sunucunuza ya da BTP'deki yönetilen sürümüne gider; webhook'a
OAuth2 / mTLS ve IP allowlist konur; geri yazma asenkron kuyruğa alınır. Desen aynı kalır.

**Neden SAP Build Process Automation ya da Integration Suite değil?**
Onlar da geçerli. n8n'in avantajı SAP dışı yüzlerce entegrasyonu ve LLM / agent node'larını
hazır getirmesi ve laptopta beş dakikada ayağa kalkması. Seçim, sürecin ağırlık merkezinin
SAP'de mi dışarıda mı olduğuna bağlı. Destede slayt 8 bu üçünü yan yana koyuyor.

**Agent yanlış sipariş açarsa?**
İki koruma var: agent ürünü ve müşteriyi doğrulamadan `createOrder` çağıramıyor (system prompt
+ tool açıklamaları), CAP de bilinmeyen ürüne `400` dönüyor. Üstelik açtığı her sipariş
`PENDING`; onay hâlâ kuralda ve insanda. n8n 2.6+ ile tek bir tool'un çalışması da insan
onayına bağlanabiliyor.

**Maliyet?**
Yalnızca Perde 2'deki LLM çağrıları; Gemini Flash'ın ücretsiz katmanı demo için fazlasıyla
yeterli. Perde 1'de model yok, deterministik kural.

**Agent'ı canlı çalıştırabilir miydiniz?**
Evet, `Chat Model` bağlı. Göstermek istenen şey modelin kendisi değil, **tool sınırları**;
asıl mühendislik orada.

## 15. Üretime taşırken

Destenin 10. slaydının özeti. Demo bilerek bunları atlar; üretimde atlanmaz.

| Konu | Demoda | Üretimde |
|---|---|---|
| Kimlik doğrulama | Statik `X-API-Key`, CAP'te auth yok | Webhook'ta JWT / OAuth2, IP allowlist; CAP'te XSUAA, `approve`/`reject` için ayrı scope |
| Geri yazma | Senkron HTTP, hemen | Asenkron (kuyruk / Event Mesh), retry ve idempotency anahtarı |
| Veritabanı | In-memory SQLite | HANA Cloud; n8n için Postgres |
| n8n işletimi | `npm i -g n8n`, SQLite | Sabit sürüm, Postgres, **encryption key yedeği**, queue mode; 2.0 kırıcı değişikliklerle geldi |
| Lisans | Community (fair-code) | Kurum içi self-host ücretsiz; servis olarak satılamaz. SSO, environments, secret store, SLA ücretli katmanda |
| Destek | Yok | Bağımsız n8n'i SAP desteklemez. SAP'nin BTP içindeki n8n sürümü (Joule Studio içinde) SAP tarafından işletilir; GA kademeli, güncel durumu kontrol et |
| Denetim | Executions ekranı | Execution verisini saklama politikası, log forwarding, PII maskeleme |

Fiyatlar ve lisans ayrıntıları için <https://n8n.io/pricing> (deste Eylül 2026 değerlerini kullanır).

## 16. Sunum destesi

`SUNUM.pptx`: 11 slayt, her birinde konuşmacı notu. Yapı: **6 slayt → canlı demo (~12 dk) → 5 slayt.**
Deste demoyu anlatmaz, n8n'i bir SAP geliştiricisinin gözüyle anlatır.

| # | Slayt |
|---|---|
| 1 | Açılış: tez cümlesi + zaman çizgisi |
| 2 | Bir sipariş onayı için bugün kaç sisteme dokunuyoruz? Neden şimdi |
| 3 | n8n nedir: canvas'ı olan bir Node.js süreci; ABAP çeviri tablosu (SICF, SLG1, SBWP…) |
| 4 | Dört iş, hepsi aynı canvas'ta: entegrasyon, otomasyon, insan döngüde, AI agent |
| 5 | Tek arayüz HTTP: SAP tutar, n8n orkestre eder; çağrı yönü, clean core, released API |
| 6 | Şimdi canlı görelim, üç yere bakın |
| — | **Canlı demo** |
| 7 | Agent oluşturur. Onaylamaz. Korumalar |
| 8 | Üç araç, üç yer: SBPA / Integration Suite / n8n; n8n artık BTP'de |
| 9 | Belirsizliği çekirdek sürece sokmadan değer üretmek: bir SAP mimarının ilkeleri |
| 10 | Bedava kısmı lisans, bedava olmayan kısmı işletmek |
| 11 | Kapanış: karar SAP'de, kural n8n'de, dil agent'ta |

Desteyi yeniden üretmek: [sunum/README.md](sunum/README.md). Sahne akışı: [sunum/SUNUM-NOTLARI.md](sunum/SUNUM-NOTLARI.md).

## 17. Windows notu

Paket macOS'ta doğrulandı. `scripts/windows/` altındaki `start-demo.ps1` ve `create-order.ps1`
daha eski PowerShell sürümleridir; CAP ve n8n'i başlatır ve test siparişi açar, ama
`setup-mac.sh` ile gelen credential / workflow import otomasyonu ve `--tunnel` desteği yoktur.
Windows'ta workflow'ları n8n arayüzünden import edip "CAP Webhook Key" credential'ını elle
oluşturman gerekir (bkz. [n8n-workflows/README.md](n8n-workflows/README.md)).

## 18. Lisans ve katkı

Müşteri ve ürün adları uydurma, Türkçe örnek verilerdir. Demo kodu eğitim amaçlıdır; üretime
taşımadan önce [§ 15](#15-üretime-taşırken)'i oku.

Soru, düzeltme ve öneriler için issue açabilirsin.
