#!/usr/bin/env zsh
# Onay kanalını değiştirir ve CAP'i yeniden başlatır (liste 3 tohum kayda döner, ~10 sn).
#
#   ./mode.sh telegram   01: Telegram'da Onayla / Reddet DÜĞMELERİ  (n8n tabanı 127.0.0.1 ise tünel gerekmez;
#                            düğmeye n8n'in çalıştığı bilgisayardaki Telegram Web'den basılır)
#   ./mode.sh form       04: n8n onay FORMU + Telegram'a düz metin bildirim (düğme yok; internet yoksa
#                            bildirim atlanır, form yine çalışır)  →  ./scripts/form-url.sh
#   ./mode.sh            mevcut modu göster
#
# n8n'in yeniden başlamasına gerek yok: 01 ve 04 aynı anda aktiftir, CAP hangisine POST atacağını .env'den okur.
set -euo pipefail
source "${0:A:h}/lib-demo.sh"
ENV_FILE="$CAP_DIR/.env"
show() {
  local cur; cur=$(env_value N8N_WEBHOOK_URL || true)
  if [[ "$cur" == *offline* ]]; then ok "mod: FORM (04) - onay n8n formundan, Telegram'a metin bildirim"
  else ok "mod: TELEGRAM (01) - Onayla / Reddet düğmeleri Telegram'da"; fi
  info "N8N_WEBHOOK_URL=$cur"
}
case "${1:-}" in
  "")          head1 "Onay kanalı"; show; exit 0 ;;
  telegram|01) NEW="http://localhost:5678/webhook/order-approval" ;;
  form|04)     NEW="http://localhost:5678/webhook/order-approval-offline" ;;
  -h|--help)   sed -n '2,10p' "$0"; exit 0 ;;
  *)           bad "Kullanım: ./mode.sh telegram | form"; exit 1 ;;
esac
head1 "Onay kanalı değiştiriliyor"
sed -i '' -e "s#^N8N_WEBHOOK_URL=.*#N8N_WEBHOOK_URL=$NEW#" "$ENV_FILE"
info ".env → $NEW"
"${0:A:h}/stop-demo.sh" --cap >/dev/null 2>&1 || true
"${0:A:h}/start-demo.sh" --cap 2>&1 | grep -E '✅ CAP|❌' || true
show
warn "CAP yeniden başladı: liste 3 tohum kayda döndü, Fiori'yi yenile (⌘R)."
