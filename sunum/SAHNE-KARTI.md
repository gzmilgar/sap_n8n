# Sahne kartı · SIT Ankara · 10 Ekim 2026

Tek sayfa: linkler, dört demo varyantı, kurtarma. Ayrıntı: [SUNUM-NOTLARI.md](SUNUM-NOTLARI.md) · [README](../README.md)

## Linkler

| Ekran | Adres |
|---|---|
| Sipariş Aç formu | http://localhost:4004 |
| Fiori listesi (⌘R ile yenile) | http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app |
| Agent sohbeti (tünelsiz) | http://localhost:4004/chat.html |
| n8n · 01 Telegram onayı | http://localhost:5678/workflow/demo01 |
| n8n · 02 Agent (Chat düğmesi) | http://localhost:5678/workflow/demo02 |
| n8n · 04 Form onayı | http://localhost:5678/workflow/demo04 |
| n8n · Executions (waiting'i göster) | http://localhost:5678/home/executions |
| Telegram Web (bot sohbeti açık) | https://web.telegram.org/a/ |
| Kapanış / QR | https://github.com/gzmilgar/sap_n8n |
| Sunum destesi (HTML, 8 slayt; internet ister) | `open ~/sap_n8n/sunum/SAP-n8n-Sunum.html` |

## Sahne öncesi (T-10)

```zsh
cd ~/sap_n8n
./scripts/check-demo.sh --full        # son satır "Her şey hazır"; "tünel yok, 127.0.0.1" uyarısı normal
./scripts/mode.sh                      # TELEGRAM (01) olmalı
./scripts/stop-demo.sh --cap && ./scripts/start-demo.sh --cap   # temiz 3 satır
```

## Dört varyant

| Varyant | Mod | Komut | Sahnede ne olur |
|---|---|---|---|
| **Butonlu** (asıl plan) | `./scripts/mode.sh telegram` | `./scripts/create-order.sh -a 15000` | Telegram'a özet + **Onayla / Reddet** düğmeleri düşer. Düğmeye **bu Mac'teki** Telegram Web'den bas → "Action recorded" → Fiori ⌘R → APPROVED / Telegram |
| **Butonsuz, metinli** | `./scripts/mode.sh form` | `./scripts/create-order.sh -a 15000` | Telegram'a özet + form linki (metin) düşer. Linke Mac'ten tıkla ya da `./scripts/form-url.sh` → Karar: Onayla, Onaylayan: adın |
| **Metinsiz** (internet yok) | `./scripts/mode.sh form` | aynı | Telegram'a bir şey gitmez (node atlanır), `./scripts/form-url.sh` formu açar; akış aynı |
| **Eşik altı** (her modda) | — | `./scripts/create-order.sh -a 500` | 1 sn'de APPROVED / auto-rule, insan yok |

Mod değişimi CAP'i yeniden başlatır (~10 sn), liste 3 satıra döner. n8n'e dokunmaz.

## Perde 2 · Agent

| Yol | Nasıl |
|---|---|
| Canlı (Groq · `openai/gpt-oss-120b`, açık kaynak; kota derdi yok, 1-3 sn) | `chat.html` → `Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç` → 3-15 sn → sipariş eşik üstü → Perde 1b kanalına düşer |
| Koruma | `Toros Kimya'ya 3 adet Süper Filtre 9000 siparişi aç` → "bulunamadı", sipariş yok |
| LLM'siz yedek | `./scripts/agent-demo.sh` · `-p "Olmayan Urun"` · `-c "Yok Boyle Firma"` |

## Kurtarma

| Olursa | Yap |
|---|---|
| Telegram mesajı gelmiyor | `./scripts/mode.sh form` → `form-url.sh` ile devam |
| Düğme bir şey açmıyor | Mac'teki Telegram Web'den tıkla (telefondan değil); olmazsa `./scripts/form-url.sh` |
| Reddet'e bastım, PENDING kaldı | Gerekçe formu bekliyor: linke tıkla ya da 2 dk bekle (varsayılan gerekçeyle REJECTED) |
| Chat "Error in workflow" | Gemini kotası/yoğunluk → `./scripts/agent-demo.sh` |
| Chat "Failed to receive response" | Sekmeyi yenile; `chat.html` kullan |
| Her şey karıştı | `./scripts/stop-demo.sh && ./scripts/start-demo.sh` (tünelsiz) · 1 dk |
