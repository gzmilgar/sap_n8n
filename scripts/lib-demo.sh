#!/usr/bin/env zsh
# Shared helpers for the demo scripts. Sourced, never run directly.

CAP_URL="${CAP_URL:-http://localhost:4004}"
ODATA="$CAP_URL/odata/v4/order"
N8N_URL="${N8N_URL:-http://localhost:5678}"

REPO_ROOT="${0:A:h:h}"          # scripts/ -> repo root
CAP_DIR="$REPO_ROOT/order-demo"
WF_DIR="$REPO_ROOT/n8n-workflows"

# Colours (disabled when not a terminal, e.g. piped into a log)
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_DIM=$'\e[2m'; C_RED=$'\e[31m'
  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_CYAN=$'\e[36m'; C_BOLD=$'\e[1m'
else
  C_RESET=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""; C_BOLD=""
fi

ok()    { print -r -- "  ${C_GREEN}✅${C_RESET} $*" }
bad()   { print -r -- "  ${C_RED}❌${C_RESET} $*" }
warn()  { print -r -- "  ${C_YELLOW}⚠️${C_RESET}  $*" }
info()  { print -r -- "  ${C_DIM}$*${C_RESET}" }
head1() { print -r -- ""; print -r -- "${C_BOLD}${C_CYAN}$*${C_RESET}" }

# Print a script's leading comment block as its help text, so the usage stays
# next to the code and no line numbers can drift out of sync.
show_usage() {
  awk 'NR>1 { if ($0 ~ /^#/) { sub(/^# ?/, ""); print } else exit }' "$1"
}

# nvm installs node outside /usr/bin, and a non-interactive shell does not read
# .zshrc - so resolve the node bin dir explicitly and prepend it.
ensure_node_on_path() {
  if command -v node >/dev/null 2>&1; then return 0; fi
  local candidate
  for candidate in "$HOME/.nvm/versions/node"/*/bin(N); do
    if [[ -x "$candidate/node" ]]; then export PATH="$candidate:$PATH"; fi
  done
  command -v node >/dev/null 2>&1
}

# The directory holding node/npm/cds/n8n, so Terminal windows we spawn inherit it.
node_bin_dir() { command -v node >/dev/null 2>&1 && print -r -- "${$(command -v node):A:h}" }


# --- tunnel ---------------------------------------------------------------
# Telegram refuses inline-keyboard buttons that point at localhost, and the
# "Approve Within Chat" mode calls setWebhook, which also rejects loopback.
# So Act 1's Telegram approval only works when n8n has a public URL.
# n8n 2.x removed its own `--tunnel` flag, hence cloudflared.
TUNNEL_URL_FILE="${TUNNEL_URL_FILE:-$REPO_ROOT/.demo-logs/tunnel-url.txt}"

tunnel_url() { [[ -f "$TUNNEL_URL_FILE" ]] && cat "$TUNNEL_URL_FILE" 2>/dev/null }

tunnel_running() {
  local u=$(tunnel_url)
  [[ -n "$u" ]] && pgrep -f "cloudflared tunnel" >/dev/null 2>&1
}

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time "${2:-4}" "$1" 2>/dev/null || print -r -- "000" }

cap_up()  { [[ "$(http_code "$ODATA/Orders")" == "200" ]] }
n8n_up()  { [[ "$(http_code "$N8N_URL/healthz")" == "200" ]] }

# Read a key out of order-demo/.env without sourcing the file.
env_value() {
  [[ -f "$CAP_DIR/.env" ]] || return 1
  sed -n "s/^$1=//p" "$CAP_DIR/.env" | head -1 | tr -d '\r'
}
