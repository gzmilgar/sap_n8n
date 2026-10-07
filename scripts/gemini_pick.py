#!/usr/bin/env python3
"""Find a Gemini model that this key can actually use for tool calling.

Google retires model ids for new accounts, so the id baked into the workflow can
404 even with a perfectly valid key. This asks the key what it can use, probes
the candidates with a real function declaration, and writes the winner into
workflow 02 - both the copy inside n8n and the file in this repo.

Usage:  gemini_pick.py <key-json> <n8n-db> <workflow-json> [--list] [models/xxx]
"""
import collections
import json
import sys
import urllib.error
import urllib.request

API = "https://generativelanguage.googleapis.com/v1beta"
TIMEOUT = 45

G, Y, R, D, X = "\033[32m", "\033[33m", "\033[31m", "\033[2m", "\033[0m"


def call(url, body=None):
    """Returns (parsed_json, error_string). Never raises."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"},
        method="POST" if data else "GET")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return json.loads(r.read().decode()), None
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            msg = json.loads(raw)["error"].get("message", raw)
        except Exception:
            msg = raw[:160]
        return None, "%d %s" % (e.code, msg[:110])
    except Exception as e:
        return None, str(e)[:110]


# A real tool declaration: the agent needs function calling, not just text.
PROBE = {
    "contents": [{"role": "user", "parts": [{"text": "Filtre adli urunu ara."}]}],
    "tools": [{"functionDeclarations": [{
        "name": "listProducts",
        "description": "Urun katalogunda isimle arama yapar",
        "parameters": {"type": "object",
                       "properties": {"q": {"type": "string", "description": "aranacak metin"}},
                       "required": ["q"]},
    }]}],
}


def probe(model, key):
    d, err = call("%s/%s:generateContent?key=%s" % (API, model, key), PROBE)
    if err:
        soft = err.startswith(("429", "503"))
        return ("busy" if soft else "bad"), err
    parts = (d.get("candidates") or [{}])[0].get("content", {}).get("parts", [])
    if any("functionCall" in p for p in parts):
        return "ok", None
    return "bad", "tool cagirmadi"


def main():
    key_json, db_path, wf_file = sys.argv[1:4]
    flags = sys.argv[4:]
    list_only = "--list" in flags
    forced = next((a for a in flags if a.startswith("models/")), None)

    cred = json.load(open(key_json))
    cred = cred[0] if isinstance(cred, list) else cred
    key = cred.get("data", {}).get("apiKey", "")
    if not key:
        print("  %s❌%s anahtar okunamadi" % (R, X)); return 1

    print("\n%sHesabindaki modeller%s" % (Y, X))
    d, err = call("%s/models?key=%s" % (API, key))
    if err:
        print("  %s❌%s Google: %s" % (R, X, err)); return 1
    usable = [m["name"] for m in d.get("models", [])
              if "generateContent" in m.get("supportedGenerationMethods", [])]
    print("  %s%d model generateContent destekliyor%s" % (D, len(usable), X))
    if list_only:
        for n in usable:
            print("    " + n)
        return 0

    # Prefer a stable alias so a retired version number cannot break this again,
    # then the newest flash models, then anything usable.
    preferred = ["models/gemini-flash-latest", "models/gemini-3-flash-preview",
                 "models/gemini-3-flash", "models/gemini-2.5-flash",
                 "models/gemini-pro-latest", "models/gemini-2.5-pro"]
    order = ([forced] if forced else []) + [m for m in preferred if m in usable]
    order += [m for m in usable
              if "flash" in m and "lite" not in m and "image" not in m
              and "tts" not in m and m not in order]

    print("\n%sTool calling denemesi%s" % (Y, X))
    chosen, busy = None, []
    for m in order[:8]:
        state, err = probe(m, key)
        if state == "ok":
            print("  %s✅%s %-34s tool cagirdi" % (G, X, m)); chosen = m; break
        if state == "busy":
            print("  %s⏳%s %-34s %s" % (Y, X, m, err)); busy.append(m)
        else:
            print("  %s❌%s %-34s %s" % (R, X, m, err))

    if not chosen:
        print("\n  %s❌%s Hicbiri tool calling yapamadi" % (R, X))
        if busy:
            print("  %sYogunluk gecici olabilir - birkac dakika sonra tekrar dene%s" % (D, X))
        return 1

    # --- write the winner in both places ------------------------------------
    import sqlite3
    db = sqlite3.connect(db_path)
    nodes = json.loads(db.execute(
        "SELECT nodes FROM workflow_entity WHERE id='demo02'").fetchone()[0])
    for n in nodes:
        if n.get("name") == "Chat Model":
            n["parameters"]["modelName"] = chosen
    db.execute("UPDATE workflow_entity SET nodes=?, updatedAt=datetime('now') WHERE id='demo02'",
               (json.dumps(nodes),))
    db.commit()

    wf = json.load(open(wf_file), object_pairs_hook=collections.OrderedDict)
    for n in wf["nodes"]:
        if n["name"] == "Chat Model":
            n["parameters"]["modelName"] = chosen
    json.dump(wf, open(wf_file, "w"), indent=2, ensure_ascii=False)
    open(wf_file, "a").write("\n")

    print("\n  %s✅%s n8n ve repo dosyasi guncellendi" % (G, X))
    print("  %sModel: %s%s" % (D, chosen, X))
    return 0


if __name__ == "__main__":
    sys.exit(main())
