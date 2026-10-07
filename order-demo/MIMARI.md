# CAP uygulaması — nerede, ne var, nasıl çalışıyor

Bu dosya `order-demo` klasörünün **tamamını** açıklar: hangi dosya ne yapıyor,
sipariş/ürün/fiyat verisi nerede duruyor, tutar nasıl hesaplanıyor, bir siparişin
doğuşundan onaylanmasına kadar kod satır satır ne yapıyor.

Kurulum ve sahne akışı ayrı dosyalarda:
[README.md](../README.md) · [SUNUM-NOTLARI.md](../sunum/SUNUM-NOTLARI.md)

---

## 1. Uygulama nerede?

```
~/sap_n8n/order-demo        (repoyu nereye klonladıysan orası)
```

Açmak için:

```zsh
cd ~/sap_n8n/order-demo
code .                 # VS Code
cds watch              # servisi başlat
```

Çalışınca üç adres açılır:

| Ne | Adres |
|---|---|
| OData servisi | <http://localhost:4004/odata/v4/order> |
| Servis tanımı (metadata) | <http://localhost:4004/odata/v4/order/$metadata> |
| Fiori listesi | <http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app> |

---

## 2. Klasörde ne var?

```
order-demo/
├─ db/                          ← VERİ KATMANI (ne saklanıyor)
│  ├─ schema.cds                   tablo tanımları
│  └─ data/                        başlangıç verisi (CSV)
│     ├─ order.demo-Products.csv     ← ÜRÜNLER VE FİYATLAR BURADA
│     ├─ order.demo-Customers.csv    müşteriler
│     └─ order.demo-Orders.csv       örnek 3 sipariş
│
├─ srv/                         ← SERVİS KATMANI (dışarıya ne açılıyor)
│  ├─ order-service.cds            hangi tablolar OData'da görünecek + action'lar
│  └─ order-service.js             iş mantığı (fiyat hesabı, webhook, onay)
│
├─ app/                         ← UI KATMANI
│  └─ fiori-annotations.cds        Fiori'deki kolonlar, etiketler, renkler
│
├─ .env                         gizli ayarlar (n8n adresi + anahtar)
├─ .env.example                 .env şablonu (bu commit'lenir, .env edilmez)
├─ package.json                 bağımlılıklar
├─ README.md                    kısa özet
└─ MIMARI.md                    bu dosya
```

CAP'in mantığı bu üç katman: **db** (veri) → **srv** (servis + iş mantığı) → **app** (UI).

---

## 3. Veri modeli — üç tablo

Tanımların yeri: [`db/schema.cds`](db/schema.cds)

### Orders (siparişler) — `db/schema.cds:7`

| Alan | Tip | Ne işe yarıyor |
|---|---|---|
| `ID` | UUID | Sipariş numarası. CAP otomatik üretir. |
| `customer` | String(100) | Müşteri adı (metin olarak; ilişki değil) |
| `product` | String(100) | Ürün adı (metin olarak) |
| `qty` | Integer | Adet |
| `amount` | Decimal(15,2) | **Tutar.** Gönderilmezse CAP hesaplar → bkz. §5 |
| `currency` | String(3) | Para birimi, varsayılan `TRY` |
| `status` | enum | `PENDING` \| `APPROVED` \| `REJECTED`, varsayılan `PENDING` |
| `approvedBy` | String(100) | Kim onayladı: `Telegram`, `auto-rule`, form'daki isim… |
| `approvedAt` | Timestamp | Onay/ret zamanı |
| `note` | String(500) | Serbest not; ret sebebi buraya yazılır |
| `createdAt`, `modifiedAt`, `createdBy`, `modifiedBy` | `managed` aspect | CAP otomatik doldurur. `createdAt` listelerin **yeniden eskiye** sıralama anahtarı; OData'nın varsayılan sırası UUID'ye göredir |

> `customer` ve `product` neden ilişki (association) değil de düz metin?
> Demo basit kalsın diye. Gerçek bir projede bunlar `Customers`/`Products`'a
> foreign key olurdu. Burada agent'ın ürünü **isimle** doğrulaması anlatılıyor.

### Products (ürünler + fiyat) — `db/schema.cds:35`

| Alan | Tip |
|---|---|
| `ID` | String(10) — `P001`, `P002`… |
| `name` | String(100) |
| `unitPrice` | Decimal(15,2) — **birim fiyat** |

### Customers (müşteriler) — `db/schema.cds:28`

| Alan | Tip |
|---|---|
| `ID` | String(10) — `C001`… |
| `name` | String(100) |
| `city` | String(60) |

---

## 4. Fiyatlar tam olarak nerede?

**Dosya:** [`db/data/order.demo-Products.csv`](db/data/order.demo-Products.csv)

```csv
ID,name,unitPrice
P001,Endüstriyel Filtre Kartuşu,375.00
P002,Paslanmaz Çelik Vana,1250.00
P003,Hidrolik Hortum 6m,480.00
P004,Sensörlü Debimetre,2750.00
P005,Conta Seti 100lük,95.00
P006,Dijital Manometre,640.00
```

**Müşteriler:** [`db/data/order.demo-Customers.csv`](db/data/order.demo-Customers.csv)

```csv
ID,name,city
C001,Anadolu Makina A.Ş.,Ankara
C002,Ege Teknik Sanayi Ltd.,İzmir
C003,Marmara Enerji A.Ş.,Kocaeli
C004,Toros Kimya San. Tic.,Adana
```

### Bu CSV'ler veritabanına nasıl giriyor?

`cds watch` her başladığında:

1. `db/schema.cds`'ten SQL tablolarını üretir
2. **Bellekte** bir SQLite veritabanı açar (`package.json` → `cds.requires.db.credentials.url: ":memory:"`)
3. `db/data/*.csv` dosyalarını o tablolara yükler

Log'da şunu görürsün:

```
> init from db/data/order.demo-Products.csv
> init from db/data/order.demo-Orders.csv
> init from db/data/order.demo-Customers.csv
/> successfully deployed to in-memory database.
```

> **Önemli:** Veritabanı **bellekte**. CAP'i kapatıp açınca demoda oluşturduğun
> tüm siparişler silinir, CSV'ler yeniden yüklenir, liste tekrar 3 satıra döner.
> Bu bilerek böyle — demoyu tekrar tekrar aynı temiz durumdan oynayabilirsin.

### Fiyat değiştirmek / ürün eklemek

CSV'ye satır ekle, CAP'i yeniden başlat. Hepsi bu.

```csv
P007,Basınç Sensörü,1890.00
```

> Eşiği (10.000) aşan bir demo siparişi için `qty × unitPrice > 10000` olmalı.
> Hazır kombinasyon: **40 × 375,00 = 15.000,00** (Endüstriyel Filtre Kartuşu).

---

## 5. Tutar nasıl hesaplanıyor?

**Dosya:** [`srv/order-service.js`](srv/order-service.js) → `before CREATE` handler, satır 88

Sipariş oluşturulmadan **önce** çalışır:

```js
this.before('CREATE', Orders, async (req) => {
  const d = req.data

  if (!d.currency) d.currency = 'TRY'      // para birimi boşsa TRY
  if (!d.status)   d.status   = 'PENDING'  // durum boşsa PENDING

  // amount gönderilmediyse fiyat listesinden hesapla
  if (d.amount === undefined || d.amount === null || d.amount === '') {
    const qty = Number(d.qty || 0)
    if (!qty) return req.reject(400, 'qty is required when amount is not supplied')

    // ürünü ADIYLA Products tablosunda ara
    const product = await SELECT.one.from(Products).where({ name: d.product })
    if (!product) {
      return req.reject(400, `Unknown product '${d.product}' - amount cannot be calculated`)
    }

    d.amount = Number((qty * Number(product.unitPrice)).toFixed(2))
  }
})
```

Yani:

| Gönderdiğin | Olan |
|---|---|
| `{customer, product, qty}` | CAP `Products`'tan fiyatı bulur, `qty × unitPrice` yazar |
| `{customer, product, qty, amount}` | Gönderdiğin `amount` aynen kullanılır, hesap yapılmaz |
| Ürün katalogda yoksa | **HTTP 400** — sipariş oluşmaz |

Son satır demonun can damarı: **agent uydurma bir ürünle sipariş açamaz**,
çünkü CAP fiyatı bulamayınca 400 döner.

Denemek için:

```zsh
# hesaplanan tutar
curl -s -X POST http://localhost:4004/odata/v4/order/Orders \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Anadolu Makina A.Ş.","product":"Endüstriyel Filtre Kartuşu","qty":40}'
#   -> amount: "15000.00"

# olmayan ürün
curl -s -X POST http://localhost:4004/odata/v4/order/Orders \
  -H 'Content-Type: application/json' \
  -d '{"customer":"X","product":"Süper Filtre 9000","qty":5}'
#   -> 400 Unknown product 'Süper Filtre 9000'
```

---

## 6. Bir siparişin hayatı — adım adım

```
  [1] POST /Orders                    ./scripts/create-order.sh  ya da  agent
        │
        ▼
  [2] before CREATE                   srv/order-service.js:88
        │  currency = TRY
        │  status   = PENDING
        │  amount   = qty × unitPrice   (Products'tan okur)
        ▼
  [3] INSERT + COMMIT                 CAP'in kendi jenerik handler'ı
        │
        ▼
  [4] after CREATE → req.on('succeeded')   srv/order-service.js:114
        │  commit'ten SONRA tetiklenir
        ▼
  [5] POST  N8N_WEBHOOK_URL           header: X-API-Key
        │  {ID, customer, product, qty, amount, currency}
        │  fire-and-forget: n8n kapalıysa sipariş yine oluşur
        ▼
  [6] n8n: tutar > 10.000 mu?
        ├── hayır → approve(ID, "auto-rule")
        └── evet  → Telegram'a Onayla/Reddet  →  insan karar verir
                      ├── Onayla → approve(ID, "Telegram")
                      └── Reddet → reject(ID, "…reddedildi")
        │
        ▼
  [7] CAP action çalışır              srv/order-service.js:127 / 133
        │  status, approvedBy, approvedAt güncellenir
        ▼
  [8] Fiori listesi yenilenince renk değişir
```

### `after CREATE` neden `req.on('succeeded')` içinde?

```js
this.after('CREATE', Orders, (result, req) => {
  const head = Array.isArray(result) ? result[0] : result
  const created = { ...head, ...req.data }

  req.on('succeeded', () => notifyN8n(created))   // <— commit'ten SONRA
})
```

Doğrudan çağırsaydık webhook, INSERT commit edilmeden n8n'e giderdi. n8n de
milisaniyeler içinde `approve` ile geri döndüğü için **siparişi bulamayıp 404**
alırdı. `succeeded` olayı bu yarışı ortadan kaldırır.

> İkinci incelik: CDS 10'da `after CREATE` sadece **anahtarı** veriyor (üstelik
> dizi içinde), tam veri `req.data`'da. İkisi birleştiriliyor — yoksa webhook'a
> `ID: undefined` gidiyordu.

---

## 7. n8n'e giden webhook

**Fonksiyon:** `notifyN8n()` — `srv/order-service.js:13`

```js
const res = await fetch(url, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-API-Key': process.env.N8N_WEBHOOK_KEY },
  body: JSON.stringify({ ID, customer, product, qty, amount, currency }),
  signal: AbortSignal.timeout(WEBHOOK_TIMEOUT_MS)
})
```

Ayarlar `.env` dosyasından gelir (şablon: [`.env.example`](.env.example)):

| Değişken | Varsayılan | Ne işe yarar |
|---|---|---|
| `N8N_WEBHOOK_URL` | `http://localhost:5678/webhook/order-approval` | Hangi workflow tetiklenecek |
| `N8N_WEBHOOK_KEY` | `sit-ankara-2026` | `X-API-Key` header'ı; n8n'deki credential ile aynı olmalı |
| `N8N_WEBHOOK_TIMEOUT_MS` | `3000` | Kaç ms beklenecek |

**Hata yönetimi — demonun dayanıklılık mesajı:**

```js
} catch (e) {
  LOG.warn(`n8n webhook failed for order ${order.ID}: ${e.message} - order was still created`)
}
```

n8n kapalıysa, yanlış porttaysa, ağ yoksa — hiçbiri siparişi engellemez.
`try/catch` hatayı yutar, sadece uyarı loglanır. Sipariş yine `HTTP 201` döner.

---

## 8. approve / reject action'ları

**Tanım:** `srv/order-service.cds:30-33` · **Kod:** `srv/order-service.js:55-84`

```
POST /odata/v4/order/approve   {"ID": "...", "approvedBy": "Telegram"}
POST /odata/v4/order/reject    {"ID": "...", "reason": "Bütçe dışı"}
```

Ortak `decide()` fonksiyonu şunları yapar:

1. `ID` yoksa → **400**
2. Sipariş yoksa → **404**
3. **Zaten hedef durumdaysa** → mevcut kaydı **200** ile döner *(idempotent)*
4. Başka bir nihai durumdaysa → **409**
5. Değilse: `status`, `approvedBy`, `approvedAt` güncellenir

3. madde önemli: Telegram'da iki kez tıklanması veya webhook'un tekrar denemesi
demoyu bozmaz.

> **`reject` neden `approvedBy` almıyor?**
> İmzası spec'te `reject(ID, reason)` olarak belirlenmişti. Bu yüzden `approvedBy`
> alanına `n8n` yazılır, **kimin reddettiği `reason` metniyle `note` alanına** düşer
> (Fiori'de "Not" sütunu).

---

## 9. Fiori listesindeki kolonlar ve renkler nereden geliyor?

**Dosya:** [`app/fiori-annotations.cds`](app/fiori-annotations.cds)

Tek satır kod yazmadan, sadece annotation ile:

| Annotation | Ne yapar |
|---|---|
| `UI.LineItem` | Liste kolonları ve sırası |
| `UI.SelectionFields` | Üstteki filtre alanları |
| `UI.HeaderInfo` | Detay sayfası başlığı |
| `UI.Facets` + `UI.FieldGroup` | Detay sayfasındaki bölümler |
| `@title` | Türkçe kolon etiketleri |
| `@Measures.ISOCurrency` | Tutarın yanına para birimi |

### Durum sütunundaki renk

`srv/order-service.cds:16` — projeksiyonda **hesaplanan alan**:

```cds
case status
  when 'APPROVED' then 3      -- yeşil
  when 'REJECTED' then 1      -- kırmızı
  else                 2      -- sarı (PENDING)
end as statusCriticality : Integer
```

Sonra annotation bu alanı kolona bağlar:

```cds
{ $Type: 'UI.DataField', Value: status, Criticality: statusCriticality, Label: 'Durum' }
```

`statusCriticality` **veritabanında saklanmaz** — her okumada hesaplanır ve
sadece UI için vardır (`@UI.Hidden` ile listede ayrı kolon olarak görünmez).

---

## 10. Servisin tüm uçları

Kök: `http://localhost:4004/odata/v4/order`

| Uç | Metod | Ne döner |
|---|---|---|
| `/Orders` | GET | Tüm siparişler |
| `/Orders/$count` | GET | Sipariş sayısı |
| `/Orders(<uuid>)` | GET | Tek sipariş |
| `/Orders` | POST | Yeni sipariş oluşturur |
| `/Products` | GET | Fiyat listesi *(salt okunur)* |
| `/Customers` | GET | Müşteriler *(salt okunur)* |
| `/approve` | POST | Siparişi onaylar |
| `/reject` | POST | Siparişi reddeder |
| `/$metadata` | GET | Servis tanımı (EDMX) |

### Agent'ın kullandığı üç sorgu

```zsh
# 1 · ürünü ve fiyatını bul
curl -s "http://localhost:4004/odata/v4/order/Products?\$filter=contains(name,'Filtre')"

# 2 · müşteriyi doğrula
curl -s "http://localhost:4004/odata/v4/order/Customers?\$filter=contains(name,'Anadolu')"

# 3 · siparişi aç
curl -s -X POST http://localhost:4004/odata/v4/order/Orders \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Anadolu Makina A.Ş.","product":"Endüstriyel Filtre Kartuşu","qty":40}'
```

`./scripts/agent-demo.sh` tam olarak bu üçünü sırayla çalıştırır.

> **OData V4 anahtar söz dizimi:** `/Orders(<uuid>)` — tırnaksız, `guid` öneki yok.
> V2'deki `/Orders(guid'...')` biçimi **400** döner.

---

## 11. Sık yapılan değişiklikler

| İstediğin | Nerede | Sonra |
|---|---|---|
| Fiyat değiştir / ürün ekle | `db/data/order.demo-Products.csv` | CAP'i yeniden başlat |
| Müşteri ekle | `db/data/order.demo-Customers.csv` | CAP'i yeniden başlat |
| Başlangıç siparişlerini değiştir | `db/data/order.demo-Orders.csv` | CAP'i yeniden başlat |
| **Onay eşiğini değiştir (10.000)** | CAP'te **değil** → n8n'de `01` workflow'u, `Tutar > 10.000 mu?` node'u | Workflow'u kaydet + Activate kapat/aç |
| Yeni alan ekle | `db/schema.cds` + `app/fiori-annotations.cds` | `cds watch` otomatik yeniler |
| n8n adresi / anahtarı | `.env` | CAP'i yeniden başlat |
| Türkçe etiket değiştir | `app/fiori-annotations.cds` | Otomatik yenilenir |

> **Eşik CAP'te değil, n8n'de.** Bu bilinçli bir tasarım: iş kuralı orkestrasyon
> katmanında duruyor, SAP servisi sadece veri ve doğrulama yapıyor. Sahnede
> vurgulamaya değer bir nokta.

---

## 12. Açılışta görünen zararsız uyarı

```
WARNING: custom action 'reject()' conflicts with method in base class.
```

CAP yalnızca `srv.reject(...)` tipli kısayol metodunu **üretmediğini** söylüyor.
`this.on('reject', ...)` handler'ı normal çalışır — testlerle doğrulandı.
Görmezden gelebilirsin.

---

## 13. Hızlı doğrulama

```zsh
cd ~/sap_n8n/order-demo
cds watch
```

Başka bir terminalde:

```zsh
B=http://localhost:4004/odata/v4/order

curl -s "$B/Orders/\$count"            # -> 3
curl -s "$B/Products" | python3 -m json.tool | head -20

# hesaplanan tutar
curl -s -X POST "$B/Orders" -H 'Content-Type: application/json' \
  -d '{"customer":"Anadolu Makina A.Ş.","product":"Endüstriyel Filtre Kartuşu","qty":40}'

# onayla (ID'yi yukarıdaki cevaptan al)
curl -s -X POST "$B/approve" -H 'Content-Type: application/json' \
  -d '{"ID":"<ID>","approvedBy":"Telegram"}'
```
