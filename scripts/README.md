# Script'ler

Demoyu kurmak, başlatmak, kontrol etmek ve sahnede oynamak için zsh script'leri.
Hepsi repo kökünü kendi konumlarından bulur (`lib-demo.sh` → `REPO_ROOT`), bu yüzden
herhangi bir dizinden çağrılabilirler. nvm ile kurulu Node'u da kendileri PATH'e alırlar.

Gereksinimler: zsh, Node ≥ 20, `n8n` ve `cds` global kurulu, macOS'ta hazır gelen
`python3` ve `sqlite3`. Telegram onayı için ayrıca `cloudflared`.

## Günlük kullanım

| Script | Ne yapar | Seçenekler |
|---|---|---|
| `setup-mac.sh` | Tek seferlik kurulum: `order-demo` içinde `npm install`, `.env.example` → `.env`, n8n'de "CAP Webhook Key" Header Auth credential'ı, 4 workflow'un import'u (credential bağlı). Workflow'lar zaten varsa import'u atlar. | `--force` yeniden import eder; UI'da seçtiğin credential'lar ve chat id sıfırlanır |
| `start-demo.sh` | n8n (:5678) ve CAP (:4004) başlatır. Varsayılan: iki Terminal penceresi. n8n'in ayağa kalkmasını 120 sn'ye kadar bekler. | `--tunnel` cloudflared ile public URL (Telegram onayı için şart) · `--bg` arka plan, loglar `.demo-logs/` · `--cap` / `--n8n` yalnız biri |
| `stop-demo.sh` | İkisini de durdurur, 4004 ve 5678 portlarını boşaltır. | `--cap` / `--n8n` yalnız biri (dayanıklılık demosunda `--n8n`) |
| `check-demo.sh` | Sahne öncesi kontrol: portlar, workflow'lar aktif mi, hangi onay modundasın, o mod hazır mı. Bir şey kırmızıysa sıfırdan farklı çıkış kodu. | `--full` gerçek bir sipariş açıp zinciri uçtan uca dener; listeye 1 prova siparişi bırakır |

## Sahnede

| Script | Ne yapar | Örnekler |
|---|---|---|
| `create-order.sh` | CAP'te test siparişi açar, dönen ID'yi yazar. Tutar verilmezse CAP `qty × unitPrice` hesaplar. | `-a 500` otomatik onay · `-a 15000` Telegram/Form onayı · `-p "Dijital Manometre" -q 3` · `-c "Ege Teknik"` |
| `watch-order.sh` | Bir siparişi `PENDING`'den çıkana kadar izler. | `./watch-order.sh <ID> 120` |
| `agent-demo.sh` | Perde 2'yi canlı LLM olmadan oynar: `listProducts` → `getCustomer` → tutar → `createOrder`, konuşma hızında, her adımı açıklayarak. Ürün ya da müşteri bulunamazsa agent gibi **durur**. | `-c Anadolu -p Filtre -q 40` · `-p "Olmayan Urun"` · `--fast` duraklamasız |

## n8n ayarları (n8n kapalıyken)

Bu script'ler n8n'in SQLite veritabanına (`~/.n8n/database.sqlite`) yazar. n8n aktif
workflow'ları bellekte tuttuğu için **önce `stop-demo.sh`**, sonra bunlar, sonra `start-demo.sh`.

| Script | Ne yapar |
|---|---|
| `set-chat-id.sh <id>` | Telegram chat id'yi 01 ve 03'teki Telegram node'larına yazar: hem repodaki JSON'lara hem n8n'deki kopyalara. Seçili credential'lara dokunmaz. Yanlışlıkla bot token'ı yapıştırılırsa reddeder. Grup için `-100...`. |
| `set-gemini-key.sh <AIza...>` | Anahtarı Google'a karşı test eder, `Google Gemini account` credential'ı olarak kaydeder, 02'deki `Chat Model` node'una bağlar. |
| `pick-gemini-model.sh [--list] [models/xyz]` | Anahtarın **tool calling** yapabildiği bir Gemini modeli bulur ve 02'ye yazar. Google model kimliklerini zamanla kapattığı için repodaki kimlik 404 verebilir; bu script çözer. Çekirdeği `gemini_pick.py`. |
| `publish-workflows.sh [--check]` | n8n 2.x yayınlanmış sürümü çalıştırır, taslağı değil. Bu script her demo workflow'unun taslağını yayınlar ve 01/02/04'ü aktif eder; UI'da Active kapat/aç ile eşdeğer. `--check` yalnız durumu gösterir. |

## Yardımcılar

| Dosya | |
|---|---|
| `lib-demo.sh` | Ortak fonksiyonlar: renkli çıktı, `REPO_ROOT`, nvm PATH çözümü, `.env` okuma, CAP / n8n / tünel sağlık kontrolleri. Çalıştırılmaz, `source` edilir. |
| `gemini_pick.py` | `pick-gemini-model.sh`'in model listesini çekip deneyen Python kısmı. |

## Windows

`windows/start-demo.ps1` ve `windows/create-order.ps1` daha eski PowerShell sürümleridir.
CAP ve n8n'i başlatır, test siparişi açar; ama credential/workflow import otomasyonu,
tünel ve n8n veritabanı script'lerinin karşılığı yoktur. Bakımı yapılmıyor.
