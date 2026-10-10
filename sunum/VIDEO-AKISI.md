# Video çekim akışı · sırayla

Her sahne: **nerede** → **ne yap** → **ne görünmeli**. Toplam ~12 dakika. Başlamadan: `./scripts/check-demo.sh --full` → "Her şey hazır".
Mod: `./scripts/mode.sh` → TELEGRAM (01). Temiz liste: `./scripts/stop-demo.sh --cap && ./scripts/start-demo.sh --cap`

| # | Sahne | Nerede | Ne yap | Ne görünmeli |
|---|---|---|---|---|
| 0 | Açılış | http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app | Listeyi göster | 3 sipariş: PENDING / APPROVED / REJECTED renkli |
| 1 | Eşik altı, insan yok | Terminal | `./scripts/create-order.sh -a 500` | 1 sn sonra form sayfasında (http://localhost:4004) APPROVED · auto-rule |
| 2 | n8n'de karar | http://localhost:5678/home/executions | En üstteki 01 execution'ı aç | IF node'u *false* dalı → CAP approve (auto-rule) |
| 3 | Eşik üstü, Telegram'a düşer | http://localhost:4004 (form) | Anadolu Makina · Endüstriyel Filtre Kartuşu · 40 → **Siparişi Aç** | Tutar 15.000, "onay istenecek" |
| 4 | Telegram'da düğmeler | https://web.telegram.org/a/ (bot sohbeti) | Mesajı göster, **Onayla**'ya bas (bu Mac'ten) | "Action recorded" sayfası; listede APPROVED · Telegram |
| 5 | Executions'ta waiting | http://localhost:5678/home/executions | 4. sahneden önce ya da sonra göster | Execution "waiting" → "success" |
| 6 | Reddet + gerekçe | Terminal + Telegram | `./scripts/create-order.sh -a 12000` → Telegram'da **Reddet** → "Gerekce Yaz" → kısa gerekçe | Listede REJECTED, not alanında gerekçe (Fiori detayında "Not") |
| 7 | Butonsuz varyant (isteğe bağlı) | Terminal | `./scripts/mode.sh form` → `./scripts/create-order.sh -a 15000` → `./scripts/form-url.sh` | Telegram'a metin bildirim + linki; form açılır → Onayla · adın |
| 8 | Agent mimarisi | http://localhost:5678/workflow/demo02 | Üç tool node'una çift tıkla, açıklamaları göster; Siparis Agent → system prompt | "önce doğrula, sonra yaz", "asla uydurma" |
| 9 | Agent canlı | http://localhost:4004/chat.html | `Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç` | 5-20 sn; "sipariş oluşturuldu"; Telegram'a (ya da forma) onay düşer |
| 10 | Agent koruması | http://localhost:4004/chat.html | `Toros Kimya'ya 3 adet Süper Filtre 9000 siparişi aç` | "bulunamadı", sipariş açılmaz |
| 11 | Agent yetkisi yok | http://localhost:4004/chat.html | `Az önce açtığın siparişi onayla` | Onay tool'u yok; karar kuralda ve insanda |
| 12 | Döngü kapanır | Telegram | 9. sahnenin siparişini **Onayla** | APPROVED · Telegram |
| 13 | Dayanıklılık | Terminal | `./scripts/stop-demo.sh --n8n` → `./scripts/create-order.sh -a 700` → `./scripts/start-demo.sh --n8n` | HTTP 201, sipariş PENDING kalır; CAP logunda "webhook failed … order was still created" |
| 14 | Hata bildirimi (03) | Telegram | 13. sahnede ya da herhangi bir hatada otomatik gelir | "Workflow hata verdi …" mesajı |
| 15 | Kapanış | https://github.com/gzmilgar/sap_n8n | Repo + README | QR / link |

LLM'siz yedek (9-11 yerine): `./scripts/agent-demo.sh` · `-p "Olmayan Urun"` · `-c "Yok Boyle Firma"`

Sahneler arası: Telegram düğmesine **Mac'teki** Telegram Web'den basılır. Chat istemleri arasında 30-60 sn bırak (ücretsiz LLM katmanı).
