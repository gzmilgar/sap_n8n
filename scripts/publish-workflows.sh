#!/usr/bin/env zsh
# n8n 2.x runs the PUBLISHED version of a workflow, not the draft you see in the
# editor. Editing the draft (in the UI without saving, or via the database) leaves
# the published copy stale - which shows up as "Credential ... does not exist" or
# settings that stubbornly do not take effect.
#
# This publishes the current draft of every demo workflow and activates the ones
# the demo needs. Equivalent to toggling Active off/on for each, in the UI.
#
#   ./publish-workflows.sh              yayınla + 01,02,04'ü aktif et
#   ./publish-workflows.sh --check      sadece durumu göster
set -u
source "${0:A:h}/lib-demo.sh"

CHECK=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    -h|--help) show_usage "$0"; exit 0 ;;
  esac
done

DB="$HOME/.n8n/database.sqlite"
[[ -f "$DB" ]] || { bad "n8n veritabanı yok - önce ./scripts/setup-mac.sh"; exit 1 }

if (( ! CHECK )) && n8n_up; then
  bad "n8n çalışıyor - önce durdur:  ./scripts/stop-demo.sh --n8n"
  exit 2
fi

python3 - "$DB" "$CHECK" <<'PY'
import json, sqlite3, sys

db_path, check_only = sys.argv[1], sys.argv[2] == "1"
db = sqlite3.connect(db_path)
G, Y, R, D, X = "\033[32m", "\033[33m", "\033[31m", "\033[2m", "\033[0m"

ACTIVE = {"demo01", "demo02", "demo04"}   # 03 fires as an error workflow, no trigger
creds = {r[0] for r in db.execute("SELECT id FROM credentials_entity")}

for wid, name, nodes_json, version, active_version, active in db.execute(
        "SELECT id, name, nodes, versionId, activeVersionId, active "
        "FROM workflow_entity WHERE id LIKE 'demo0%' ORDER BY id"):

    nodes = json.loads(nodes_json)
    broken = [n["name"] for n in nodes
              for c in (n.get("credentials") or {}).values() if c["id"] not in creds]

    hist = db.execute("SELECT nodes FROM workflow_history WHERE versionId=?", (version,)).fetchone()
    stale = (hist is None) or (json.loads(hist[0]) != nodes)
    wants = wid in ACTIVE

    if check_only:
        flags = []
        if broken: flags.append("%s credential eksik: %s%s" % (R, ",".join(broken), X))
        if stale:  flags.append("%syayınlanan sürüm eski%s" % (Y, X))
        if wants and not active: flags.append("%spasif%s" % (Y, X))
        print("  %s %-36s %s" % ("✅" if not flags else "⚠️ ", name[:36], " · ".join(flags)))
        continue

    if broken:
        print("  %s❌%s %-36s credential eksik: %s" % (R, X, name[:36], ",".join(broken)))
        continue

    # Publish the draft: make the history row for this version match it exactly,
    # then point activeVersionId at it. This is what the Active toggle does.
    if hist is None:
        db.execute("INSERT INTO workflow_history (versionId, workflowId, authors, nodes, connections, createdAt, updatedAt) "
                   "SELECT versionId, id, 'demo', nodes, connections, datetime('now'), datetime('now') "
                   "FROM workflow_entity WHERE id=?", (wid,))
    else:
        db.execute("UPDATE workflow_history SET nodes=(SELECT nodes FROM workflow_entity WHERE id=?), "
                   "connections=(SELECT connections FROM workflow_entity WHERE id=?), "
                   "updatedAt=datetime('now') WHERE versionId=?", (wid, wid, version))

    db.execute("INSERT OR REPLACE INTO workflow_published_version "
               "(workflowId, publishedVersionId, createdAt, updatedAt) "
               "VALUES (?,?,datetime('now'),datetime('now'))", (wid, version))
    db.execute("UPDATE workflow_entity SET activeVersionId=versionId, active=?, triggerCount=1 WHERE id=?",
               (1 if wants else 0, wid))

    print("  %s✅%s %-36s yayınlandı%s" % (G, X, name[:36], "  · AKTİF" if wants else ""))

db.commit()
PY

(( CHECK )) || { print -r -- ""; info "Şimdi:  ./scripts/start-demo.sh --tunnel" }
