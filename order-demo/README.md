# order-demo — CAP servisi

`SAP + n8n: From APIs to Intelligent Workflows` demosunun backend'i.
Tamamen lokal çalışır: SQLite (in-memory), HANA/XSUAA/MTA yok.

| Ne arıyorsun | Dosya |
|---|---|
| **Bu uygulama nasıl çalışıyor, fiyat nerede, tutar nasıl hesaplanıyor** | **[MIMARI.md](MIMARI.md)** ← detaylı anlatım |
| Kurulum, credential'lar, sorun giderme | [README.md](../README.md) |
| Sahnedeki dakika dakika akış | [SUNUM-NOTLARI.md](../sunum/SUNUM-NOTLARI.md) |

## Çalıştırma

```zsh
npm install
cp .env.example .env
cds watch
```

Ya da kök dizinden tek komutla: `./scripts/start-demo.sh`

- Servis: <http://localhost:4004/odata/v4/order>
- Fiori preview: <http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app>

## Veri modeli

| Entity | Alanlar |
|---|---|
| `Orders` | `ID` (UUID), `customer`, `product`, `qty`, `amount` (Decimal 15,2), `currency` (default `TRY`), `status` (`PENDING`\|`APPROVED`\|`REJECTED`), `approvedBy`, `approvedAt`, `note` |
| `Customers` | `ID`, `name`, `city` — 4 kayıt |
| `Products` | `ID`, `name`, `unitPrice` — 6 kayıt |

`Orders` projeksiyonu ayrıca **`statusCriticality`** hesaplanan alanını döner
(APPROVED→3 yeşil, PENDING→2 sarı, REJECTED→1 kırmızı). Fiori'deki renkli
durum sütununu bu alan sürer; UI dışında kullanılmaz.

## Servis davranışı (`srv/order-service.js`)

**before CREATE**
- `currency` boşsa `TRY`, `status` boşsa `PENDING`.
- `amount` gönderilmediyse `qty × Products.unitPrice` ile hesaplanır.
  Ürün katalogda yoksa **400** döner — AI agent'ın uydurma ürünle sipariş açmasını bu engeller.

**after CREATE**
- `N8N_WEBHOOK_URL`'e `POST` atar, `X-API-Key` header'ı ile.
- **`req.on('succeeded')` içinde çalışır**: kayıt commit edildikten sonra tetiklenir.
  Aksi halde n8n'in geri dönen `approve` çağrısı INSERT ile yarışır ve 404 alırdı.
- Fire-and-forget: n8n kapalıysa sipariş yine oluşur, sadece `warn` loglanır (kabul testi 5).

**approve / reject** (unbound action'lar)
- `status`, `approvedBy`, `approvedAt` günceller.
- **Idempotent**: kayıt zaten hedef durumdaysa mevcut kaydı `200` ile döner
  (Telegram'da iki kez tıklanması veya webhook retry'ı demoyu bozmaz).
- Farklı bir nihai duruma geçiş denenirse `409` döner.

### Not: `reject` ve `approvedBy`

Spec'teki imza `reject(ID, reason)` olduğu için `reject` bir `approvedBy` parametresi
almaz; `approvedBy` alanına `n8n` yazılır ve **kimin reddettiği `reason` metniyle
`note` alanına düşer** (Fiori'de "Not" sütunu). `approve(ID, approvedBy)` ise
`Telegram` / `auto-rule` / form'daki isim gibi değerleri doğrudan yazar.

## Hızlı doğrulama

```bash
# 3 kayıt
curl -s 'http://localhost:4004/odata/v4/order/Orders/$count'

# tutar hesaplama: 40 × 375,00 = 15.000,00
curl -s -X POST http://localhost:4004/odata/v4/order/Orders \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Anadolu Makina A.Ş.","product":"Endüstriyel Filtre Kartuşu","qty":40}'

# onay
curl -s -X POST http://localhost:4004/odata/v4/order/approve \
  -H 'Content-Type: application/json' \
  -d '{"ID":"<ID>","approvedBy":"Telegram"}'
```

> OData **V4** anahtar söz dizimi: `/Orders(<uuid>)`.
> V2'deki `/Orders(guid'<uuid>')` biçimi **400** döner.

## Bilinen uyarı

Açılışta şu satır görünür ve zararsızdır:

```
WARNING: custom action 'reject()' conflicts with method in base class.
```

CAP yalnızca `srv.reject(...)` tipli kısayol metodunu üretmediğini söylüyor.
`this.on('reject', ...)` handler'ı normal çalışır — testlerle doğrulandı.
