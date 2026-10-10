# SAP + n8n: From APIs to Intelligent Workflows

> **SAP keeps the data, n8n orchestrates, the agent is only an interface.**

🇹🇷 Türkçe sürüm: **[README.tr.md](README.tr.md)**

Source package of the live demo given at SAP Inside Track Ankara 2026: a **SAP CAP** order service, four
**n8n** workflows and the scripts that install and run the whole thing with one command. Everything runs
on a laptop, **without Docker and without a BTP account**. Slides and the recording are not part of this
repository.

## Contents

1. [What the demo shows](#1-what-the-demo-shows)
2. [Architecture](#2-architecture)
3. [Repository map](#3-repository-map)
4. [Prerequisites](#4-prerequisites)
5. [Quick start](#5-quick-start)
6. [Setup details](#6-setup-details)
7. [Running the demo](#7-running-the-demo)
8. [Approval channels: Telegram and Form](#8-approval-channels-telegram-and-form)
9. [Environment variables](#9-environment-variables)
10. [Scripts](#10-scripts)
11. [Workflows](#11-workflows)
12. [CAP service](#12-cap-service)
13. [Troubleshooting](#13-troubleshooting)
14. [FAQ](#14-faq)
15. [Taking it to production](#15-taking-it-to-production)
16. [Notes](#16-notes)

---

## 1. What the demo shows

A two-act **order approval loop**.

| Act | What happens |
|---|---|
| **1 · APIs** | An order is created in CAP → CAP's webhook triggers n8n → above **10,000 TRY** a human is asked on Telegram, otherwise the order is auto-approved → the decision is written back through CAP's `approve` / `reject` actions → the status colour changes in the Fiori list. |
| **2 · Intelligent** | An n8n **AI Agent** uses the same CAP OData service through three HTTP Request tools: look up a product, look up a customer, create an order. The order is created → CAP's handler triggers Act 1 → the approval lands with a human again → **the loop closes**. |

Three design decisions are the backbone of the demo:

- **The decision stays deterministic.** The 10,000 threshold and the approval flow live in n8n's IF node; the agent has no `approve` / `reject` tool. The agent only *creates*.
- **The agent cannot make things up.** The system prompt forbids guessing; the tool descriptions enforce "verify first, then write"; CAP returns **400** for a product that is not in the catalogue.
- **SAP does not depend on n8n.** The webhook is fire-and-forget: with n8n down the order is still created, only a warning is logged.

## 2. Architecture

```
            ┌──────────────── SAP CAP  (localhost:4004) ────────────────┐
            │  OData V4  /odata/v4/order                                │
            │   Orders · Products · Customers                           │
            │   actions: approve(ID, approvedBy) · reject(ID, reason)   │
            │  Fiori Elements preview  (coloured status column)         │
            │  Order form (app/index.html) · Agent chat (chat.html)     │
            └───────┬───────────────────────────────────▲───────────────┘
   after CREATE     │ POST webhook (X-API-Key)          │ POST /approve · /reject
   (after commit)   │                                   │
            ┌───────▼───────────────────────────────────┴───────────────┐
            │                      n8n  (localhost:5678)                │
            │  01  Webhook → IF amount > 10,000 ─ no  → approve(auto-rule)
            │                                   └ yes → Telegram send-and-wait
            │                                             ├ Approve → approve(Telegram)
            │                                             └ Reject  → reason → reject(...)
            │  02  Chat Trigger → AI Agent ─┬ listProducts  (GET Products)
            │                               ├ getCustomer   (GET Customers)
            │                               └ createOrder   (POST Orders) ──► triggers 01
            │  03  Error Trigger → Telegram
            │  04  01 without Telegram: approval via n8n Form (+ plain-text Telegram notice)
            └───────────────────────────────────────────────────────────┘
```

The life of an order:

1. `POST /Orders` arrives (form, script or agent).
2. `before CREATE`: currency defaults to `TRY`, status to `PENDING`; if `amount` is missing it is computed as `qty × unitPrice`, unknown product → **400**.
3. INSERT and commit.
4. `after CREATE` → the webhook is sent inside `req.on('succeeded')`, i.e. *after* the commit. Otherwise n8n's `approve` call, which comes back within milliseconds, would race the INSERT and get a 404.
5. n8n decides and writes back via `approve` / `reject`. The actions are **idempotent**: double clicks and webhook retries do not break the demo; switching to a different final state returns **409**.
6. On refresh the Fiori list recolours via `statusCriticality` (green 3 / yellow 2 / red 1).

## 3. Repository map

```
sap_n8n/
├─ README.md · README.tr.md             ← this document (EN / TR)
├─ order-demo/                          # SAP CAP service
│  ├─ db/schema.cds                     Orders (managed) · Customers · Products
│  ├─ db/data/*.csv                     4 customers · 6 products · 3 orders (prices live here)
│  ├─ srv/order-service.cds             OData service + approve/reject actions
│  ├─ srv/order-service.js              amount calculation, webhook, idempotent approval
│  ├─ app/fiori-annotations.cds         UI.LineItem, criticality, newest-first sort
│  ├─ app/index.html                    "New order" form, live total, self-refreshing list
│  ├─ app/chat.html                     local chat page for the agent (tunnel-independent)
│  └─ .env.example · package.json
├─ n8n-workflows/
│  ├─ 01-order-approval.json            Act 1 · Telegram approval
│  ├─ 02-order-agent.json               Act 2 · AI Agent + 3 tools
│  ├─ 03-error-handler.json             error → Telegram
│  └─ 04-order-approval-OFFLINE.json    Act 1 with an n8n Form instead of Telegram
└─ scripts/                             macOS (zsh)
   ├─ setup-mac.sh · start-demo.sh · stop-demo.sh · check-demo.sh · mode.sh
   ├─ create-order.sh · watch-order.sh · agent-demo.sh · form-url.sh
   ├─ set-chat-id.sh · set-groq-key.sh · set-gemini-key.sh · pick-gemini-model.sh
   ├─ publish-workflows.sh
   └─ lib-demo.sh · gemini_pick.py      shared helpers
```

Script output and the UI texts are in Turkish (the demo was built for a Turkish-speaking audience); the
code, workflow JSONs and this README are the reference.

## 4. Prerequisites

Verified on **macOS**. The scripts need zsh and use the `python3` and `sqlite3` that ship with macOS.

| Component | Version | Note |
|---|---|---|
| Node.js | **≥ 20** (tested: v24) | nvm recommended; the scripts resolve the nvm PATH themselves |
| `@sap/cds-dk` | 10.x, global | `npm i -g @sap/cds-dk` |
| n8n | 2.x (tested: 2.39), global | `npm i -g n8n` · **no Docker** |
| Telegram bot | optional | a bot token from @BotFather; for Act 1b |
| LLM key | optional, free | **Groq** (console.groq.com, open-source models, generous quota) or Google Gemini (free tier: 20 requests/day/model). Act 2 also works without any LLM |
| cloudflared | optional | only if the Telegram approval must be clickable **from another device** (see § 8) |

Internet is needed only for Telegram and the LLM. Without either, **workflow 04 (Form)** and
`agent-demo.sh` tell the same story fully offline.

## 5. Quick start

```zsh
git clone https://github.com/gzmilgar/sap_n8n.git ~/sap_n8n
cd ~/sap_n8n

./scripts/setup-mac.sh          # 1) one-time setup: npm install, .env, credential + workflow import
./scripts/start-demo.sh         # 2) two Terminal windows: n8n (:5678) and cds watch (:4004)
open http://localhost:5678      # 3) create the owner account → bind credentials → chat id → activate 01 (see § 6)
./scripts/check-demo.sh --full  # 4) pre-flight; the last line must say "Her şey hazır" (all good)

./scripts/create-order.sh -a 500      # auto-approved
./scripts/create-order.sh -a 15000    # Approve / Reject buttons land on Telegram
open http://localhost:4004            # order form + live list
open http://localhost:4004/chat.html  # agent chat

./scripts/stop-demo.sh          # shut down
```

Addresses: order form `http://localhost:4004` · Fiori list
`http://localhost:4004/$fiori-preview/OrderService/Orders#preview-app` · OData
`http://localhost:4004/odata/v4/order` · n8n `http://localhost:5678`.

## 6. Setup details

### 6.1 What `setup-mac.sh` does

1. Runs `npm install` in `order-demo` and creates `.env` from `.env.example`.
2. Creates a *Header Auth* credential named **"CAP Webhook Key"** in n8n's database with the same value as `N8N_WEBHOOK_KEY` in `.env`.
3. Imports the four workflows with the fixed ids `demo01`…`demo04`, with that credential already bound to the webhook nodes and `03` set as the error workflow of `01/02/04`.

> If n8n is running, stop it first: `./scripts/stop-demo.sh`. Importing happens with n8n down. If the
> workflows already exist the import is skipped; `--force` re-imports and resets the credentials and
> chat id you picked in the UI.

### 6.2 Manual steps in n8n

`http://localhost:5678` → create the local owner account on first launch, then:

**a) Telegram credential:** Credentials → New → **Telegram API** → bot token → name it `Telegram account`.
Open the Telegram nodes in 01, 03 and 04 and select it (the places that say `REPLACE_WITH_YOUR_CREDENTIAL_ID`).

**b) Chat id:** with n8n stopped, one command updates both the repo JSONs and the copies inside n8n:

```zsh
./scripts/stop-demo.sh
./scripts/set-chat-id.sh 123456789      # groups: -100...
./scripts/start-demo.sh
```

Do not know your chat id? Talk to **@get_id_bot** on Telegram. Send your bot a message **first** so it is
allowed to write to you.

**c) LLM key** (for Act 2, optional), with n8n stopped:

```zsh
./scripts/set-groq-key.sh gsk_...        # Groq: open-source model, no daily cap (default)
./scripts/set-gemini-key.sh AIza...      # or Google Gemini (free tier: 20 requests/day/model)
```

Both test the key, store it as a credential and configure the `Chat Model` node of 02; the Groq script
also publishes.

**d) Activate:** activate `01 - Order Approval` and `04` (for Form mode). If a workflow is not active its
production webhook is not registered and CAP gets `404`. `check-demo.sh` catches this.

### 6.3 Draft vs. published in n8n 2.x

n8n 2.x runs the **published** version of a workflow, not the draft you see in the editor. After saving a
change in the editor toggle Active off/on, or run `./scripts/publish-workflows.sh` with n8n stopped (it
publishes all four and activates 01/02/04). Symptoms of a stale published version: settings that "do not
take effect" or `Credential with ID ... does not exist`.

## 7. Running the demo

### Act 1a · Below the threshold, no human

```zsh
./scripts/create-order.sh -a 500
```

CAP stores the order and fires the webhook; in n8n the *false* branch of the IF calls
`approve(ID, "auto-rule")`. The list shows **APPROVED / auto-rule** after about a second. Show the steps in
n8n → Executions.

### Act 1b · Above the threshold, human in the loop

```zsh
./scripts/create-order.sh -a 15000      # or in the form: Anadolu Makina · Filtre Kartuşu · 40
```

n8n pauses with *send-and-wait*; the execution goes to **waiting**. Telegram receives a summary with
**Onayla / Reddet** (Approve / Reject) buttons. Approve → an "Action recorded" page → the list shows
**APPROVED / Telegram**.

**Reject** is two steps: the bot sends a "Ret Gerekcesi" (rejection reason) message with a **Gerekce Yaz**
button that opens a short form. When the reason is submitted the order becomes **REJECTED** and the reason
lands in the `note` field. If the form is not filled within **2 minutes** the workflow continues on its own
and rejects with the default note "Telegram uzerinden reddedildi".

Without `-a` CAP computes the amount: `./scripts/create-order.sh` → 40 × 375.00 = **15,000.00**.
`-c` customer, `-p` product, `-q` quantity. `./scripts/watch-order.sh <ID>` polls an order until it leaves
`PENDING`.

### Act 2 · AI Agent

Open `02 - Order Agent` in n8n; show the descriptions of the three tool nodes and the system prompt of
`Siparis Agent` (*"Never guess, never invent. An empty tool result means not found."*).

Three ways to run it:

- **Local chat page** (most robust): `http://localhost:4004/chat.html`. It posts straight to the Chat
  Trigger on `localhost:5678`, has clickable example prompts and shows elapsed time.
- **Chat panel in the editor:** open `02` → **Chat** button at the bottom. The tools light up on the canvas
  one after another. Reload the tab after an n8n restart.
- n8n's own hosted page `http://localhost:5678/webhook/b2000000-0000-4000-8000-000000000011/chat`: it
  posts via `WEBHOOK_URL`; if you use a tunnel and the tunnel dies, this page stops working.

Example prompts (Turkish, as the agent is prompted in Turkish):

| Prompt | Expected |
|---|---|
| `Anadolu Makina'ya 40 kutu Endüstriyel Filtre Kartuşu siparişi aç` | 15,000 TRY order created, lands in the approval channel |
| `Ege Teknik'e 5 adet Conta Seti 100lük siparişi aç` | 475 TRY, auto-approved |
| `Toros Kimya'ya 3 adet Süper Filtre 9000 siparişi aç` | "not found", no order created |
| `Yok Böyle Firma'ya 2 kutu Conta Seti 100lük siparişi aç` | "customer not registered", no order created |
| `Sensörlü Debimetre'nin birim fiyatı ne?` | 2,750 TRY; only `listProducts` is called |
| `Az önce açtığın siparişi onayla` | No approval tool; the decision stays with the rule and the human |

**LLM-free fallback**, always available:

```zsh
./scripts/agent-demo.sh                      # the three calls by hand, at speaking pace
./scripts/agent-demo.sh -p "Olmayan Urun"    # product not found → the agent STOPS
./scripts/agent-demo.sh -c "Yok Boyle Firma" # customer not found → the agent STOPS
./scripts/agent-demo.sh --fast               # no pauses
```

### Closing the loop, resilience

The 15,000 TRY order created by the agent triggers **the same** workflow as Act 1; the agent created, it
did **not** approve. Orders are created even with n8n down:

```zsh
./scripts/stop-demo.sh --n8n        # stop the orchestration
./scripts/create-order.sh -a 700    # HTTP 201, the order stays PENDING
./scripts/start-demo.sh --n8n       # bring it back
```

## 8. Approval channels: Telegram and Form

CAP reads the target workflow from `.env`; `./scripts/mode.sh telegram|form` writes the file and restarts
CAP (~10 s, the list returns to the 3 seed rows). n8n is untouched; 01 and 04 are active at the same time.

### A · Telegram without a tunnel (default)

Telegram rejects inline buttons that point to `localhost` but accepts **IP addresses**. When no tunnel is
used, `start-demo.sh` starts n8n with `WEBHOOK_URL=http://127.0.0.1:5678/`; the Approve / Reject buttons
point to `127.0.0.1` and work when clicked from Telegram Web or Desktop **on the machine running n8n**. No
tunnel, no cloudflared, no special port; reaching the Telegram API (443) is enough. The buttons cannot be
clicked from a phone.

### A2 · Telegram with a tunnel (approve from another device)

```zsh
brew install cloudflared
./scripts/start-demo.sh --tunnel     # opens a cloudflared quick tunnel and starts n8n with the public URL
```

The buttons then work from a phone too. The network must allow outbound traffic on **port 7844** (corporate
and event networks often block it; `check-demo.sh` reports the tunnel as 530). Quick tunnels may die after
20–30 minutes; if so: `./scripts/stop-demo.sh --n8n && ./scripts/start-demo.sh --n8n --tunnel`.

### B · Form (no internet needed)

```zsh
./scripts/mode.sh form                # .env → order-approval-offline, CAP restarts
./scripts/create-order.sh -a 15000
./scripts/form-url.sh                 # opens the pending approval form → Karar: Onayla, Onaylayan: your name
```

Before waiting on the form, workflow 04 also sends a **plain-text** Telegram notice (summary + form link,
no buttons); without internet that step is skipped and the form still works. Start n8n **without** a
tunnel in this mode; with a tunnel the form link would point at the tunnel.

## 9. Environment variables

File: `order-demo/.env` (copied from `.env.example`, not committed).

| Variable | Default | Description |
|---|---|---|
| `N8N_WEBHOOK_URL` | `http://localhost:5678/webhook/order-approval` | Webhook CAP calls. Form mode: `.../webhook/order-approval-offline`. While testing in the editor with **Test workflow** use `/webhook-test/` instead of `/webhook/` |
| `N8N_WEBHOOK_KEY` | `sit-ankara-2026` | `X-API-Key` header; must equal the "CAP Webhook Key" credential in n8n. Demo value |
| `N8N_WEBHOOK_TIMEOUT_MS` | `3000` | How long CAP waits for n8n; the order is created either way |

> **Name clash.** `N8N_WEBHOOK_URL` is also an n8n configuration variable (its webhook base URL). If it is
> exported in the shell, n8n treats it as its base URL (form links come out as
> `…/webhook/order-approval/form-waiting/…`) and CAP cannot read `.env` (`@sap/cds` never overrides an
> existing environment variable). `start-demo.sh` therefore unsets it for n8n and passes `WEBHOOK_URL`
> explicitly, and starts CAP with `.env` loaded via `set -a`. If you start things by hand, run
> `unset N8N_WEBHOOK_URL` first.

## 10. Scripts

All zsh, all locate the repo root from their own path and can be run from anywhere. The ones that write to
n8n's database (`setup-mac`, `set-chat-id`, `set-*-key`, `pick-gemini-model`, `publish-workflows`) require
n8n to be **stopped**.

| Script | What it does |
|---|---|
| `setup-mac.sh [--force]` | One-time setup: npm install, `.env`, webhook credential, import of the 4 workflows |
| `start-demo.sh [--tunnel] [--bg] [--cap] [--n8n]` | Starts n8n and CAP (two Terminal windows by default; `--bg` background with logs in `.demo-logs/`) |
| `stop-demo.sh [--cap] [--n8n]` | Stops them, frees the ports, closes the tunnel |
| `check-demo.sh [--full]` | Pre-flight: tools, CAP, n8n, webhook + key, approval channel; `--full` runs a real end-to-end order |
| `mode.sh [telegram\|form]` | Switches the approval channel and restarts CAP; without an argument shows the current mode |
| `create-order.sh [-a amount] [-c customer] [-p product] [-q qty]` | Creates a test order |
| `watch-order.sh <ID> [seconds]` | Polls an order until it leaves `PENDING` |
| `form-url.sh [--print] [order-id]` | In Form mode, finds the latest pending approval form and opens it |
| `agent-demo.sh [-c] [-p] [-q] [--fast]` | Plays Act 2 without an LLM: the three tool calls by hand |
| `set-chat-id.sh <id>` | Writes the Telegram chat id into 01, 03 and 04 (repo JSONs + n8n) |
| `set-groq-key.sh <gsk_...> [--model id] [--list]` | Moves the agent to an open-source model on Groq and publishes |
| `set-gemini-key.sh <AIza...>` | Stores a Gemini key and binds it to 02 |
| `pick-gemini-model.sh [--list] [model]` | Finds a Gemini model the key can use for tool calling and writes it into 02 |
| `publish-workflows.sh [--check]` | Publishes the drafts and activates 01/02/04 |

## 11. Workflows

Four workflows in n8n 2.x export format. Credential ids (`REPLACE_WITH_YOUR_CREDENTIAL_ID`) and `<CHAT_ID>`
are deliberate placeholders; `setup-mac.sh` binds the webhook credential, § 6.2 does the rest. If you import
manually (Workflows → Import from File), create a Header Auth credential named `CAP Webhook Key` (Name
`X-API-Key`, Value = the key in `.env`), select it in the webhook nodes, and set `03` as the error workflow
in each workflow's Settings.

### 01 · Order Approval (Telegram)

| Node | What it does |
|---|---|
| `CAP Webhook` | `POST /webhook/order-approval`, Header Auth. Wrong key → 403 |
| `Siparis Bilgileri` | Unpacks the body into readable fields |
| `Tutar > 10.000 mu?` | **The approval threshold lives here.** Edit this node, not CAP |
| `Telegram Onay Iste` | send-and-wait: summary + Approve / Reject. The execution is `waiting`; it can wait for hours |
| `Onaylandi mi?` | Branches on `data.approved` |
| `CAP approve (Telegram)` | `POST /approve {ID, approvedBy: "Telegram"}` |
| `Ret Sebebi Sor` | send-and-wait, free text. **Limit Wait Time 2 min:** without an answer it continues with the default reason |
| `CAP reject (Telegram)` | `POST /reject {ID, reason}` |
| `CAP approve (auto-rule)` | Below the threshold: `{ID, approvedBy: "auto-rule"}` |

### 02 · Order Agent (Chat)

| Node | What it does |
|---|---|
| `Chat Trigger` | Public mode; the editor chat panel, `chat.html` and n8n's hosted page all arrive here |
| `Siparis Agent` | System prompt: never guess; verify product, then customer, then create. **No** approval tool |
| `Chat Model` | Ships as Groq `openai/gpt-oss-120b`, temperature 0, Retry On Fail. `set-gemini-key.sh` switches it to Gemini |
| `Simple Memory` | Context within one chat session |
| `listProducts` | `GET /Products?$filter=contains(name,'…')` — "ALWAYS use this tool BEFORE creating an order" |
| `getCustomer` | `GET /Customers?$filter=contains(name,'…')` — "an empty list means the customer is NOT registered" |
| `createOrder` | `POST /Orders` — "this tool writes data, call it only AFTER verifying". Sends no `amount`; CAP computes it |

### 03 · Error Handler

`Error Trigger → Telegram`. `settings.errorWorkflow` of 01, 02 and 04 points to `demo03`; when an
execution fails, the workflow name, node, error message and execution number are sent to Telegram.

### 04 · Order Approval (OFFLINE / Form)

Same skeleton as 01, with **Wait → Resume on form submission** instead of Telegram send-and-wait.
`Siparis Bilgileri` produces `onayFormUrl` (= `$execution.resumeFormUrl`); `Telegram Bildir` sends the
summary plus that link as plain text (`onError: continue`, skipped without internet); `Form ile Onay Bekle`
waits for the form (fields: Karar = Onayla / Reddet, Onaylayan = approver name); `CAP approve (Form)`
writes the approver's name. Never build the form URL by hand: n8n appends a one-time signature,
`form-url.sh` prints the ready URL.

## 12. CAP service

Three layers: **db** (data) → **srv** (service + business logic) → **app** (UI). Root:
`http://localhost:4004/odata/v4/order`.

### Data model (`db/schema.cds`)

| Entity | Fields |
|---|---|
| `Orders` (`managed`) | `ID` UUID · `customer`, `product` String(100) · `qty` Integer · `amount` Decimal(15,2) · `currency` (default `TRY`) · `status` `PENDING`\|`APPROVED`\|`REJECTED` · `approvedBy` · `approvedAt` · `note` · `createdAt`, `modifiedAt`… |
| `Customers` | `ID` (`C001`…), `name`, `city` — 4 rows |
| `Products` | `ID` (`P001`…), `name`, `unitPrice` — 6 rows |

`customer` and `product` are plain text on purpose: the story is the agent verifying the product **by
name**. The projection also returns the computed `statusCriticality` (APPROVED 3, PENDING 2, REJECTED 1)
that drives the coloured status column in Fiori.

**Prices** live in `db/data/order.demo-Products.csv` (Filtre Kartuşu 375, Çelik Vana 1,250, Hidrolik
Hortum 480, Debimetre 2,750, Conta Seti 95, Manometre 640). The database is **in-memory SQLite**: every
`cds watch` start reloads the CSVs and the list returns to 3 orders. To change prices or add products,
edit the CSV and restart CAP. Ready-made above-threshold combination: **40 × 375 = 15,000**.

### Service behaviour (`srv/order-service.js`)

- **before CREATE:** `currency` defaults to `TRY`, `status` to `PENDING`; without `amount` it computes
  `qty × unitPrice` (product looked up by name in `Products`), unknown product → **400**. The customer is
  not validated; this is deliberate, the customer guard lives in the agent prompt.
- **after CREATE:** inside `req.on('succeeded')` a `POST` to `N8N_WEBHOOK_URL` with the `X-API-Key` header,
  fire-and-forget. With n8n down a `warn` is logged and the order still returns `201`.
- **approve / reject:** update `status`, `approvedBy`, `approvedAt`. Already in the target state → the
  existing record with `200` (idempotent); switching to another final state → `409`; missing ID → `400`,
  unknown order → `404`. Because the signature is `reject(ID, reason)`, `approvedBy` is set to `n8n` and
  who rejected goes into `note` via `reason`.

### Endpoints

| Endpoint | Method | Returns |
|---|---|---|
| `/Orders` | GET · POST | Orders; POST creates one |
| `/Orders(<uuid>)` | GET | Single order (OData V4 key syntax; `guid'...'` → **400**) |
| `/Products`, `/Customers` | GET | Read-only master data |
| `/approve` | POST `{ID, approvedBy}` | Approves |
| `/reject` | POST `{ID, reason}` | Rejects |
| `/$metadata` | GET | EDMX |

Lists are sorted **newest first** by `createdAt`: `app/index.html` uses `$orderby=createdAt desc&$top=8`,
Fiori a `UI.PresentationVariant`. OData's default order is by UUID; do not rely on it.

The startup warning `custom action 'reject()' conflicts with method in base class` is harmless.

## 13. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Webhook **404**, CAP logs `webhook failed` | Workflow not active | **Activate** it in n8n. `check-demo.sh` catches this |
| Webhook **403** | `X-API-Key` mismatch | `N8N_WEBHOOK_KEY` in `.env` must equal the credential value in n8n; `setup-mac.sh` syncs them |
| `Credential with ID "REPLACE_WITH_..." does not exist` | § 6.2-a skipped | Open the node, select the credential |
| `Credential ... does not exist` (credential selected) / changes do not take effect | Stale published version | Toggle Active off/on or `./scripts/publish-workflows.sh` (n8n stopped) |
| Telegram `chat not found` | The bot has never talked to you | Message the bot first, verify the chat id |
| Telegram: `inline keyboard button URL ... is invalid` | n8n base URL is `localhost` | Start with `start-demo.sh` (base `127.0.0.1`) or `--tunnel` |
| The approval button opens nothing | Button points to `127.0.0.1` | Click from Telegram Web/Desktop on the machine running n8n; use `--tunnel` for phones |
| Pressed Reject, order stays PENDING | The reason form is pending | Fill it via **Gerekce Yaz** or wait 2 minutes |
| Tunnel 530 / does not start, log says "Allow outbound TCP on port 7844" | Network blocks 7844 | Telegram without tunnel (§ 8-A) or Form mode |
| Switched mode but CAP still calls the old workflow; form link contains `/webhook/order-approval/` | `N8N_WEBHOOK_URL` exported in the shell | `unset N8N_WEBHOOK_URL`, restart with the scripts (§ 9) |
| Chat: **Error in workflow** within 1–3 s | LLM 429 (quota) or 503 (overload) | Read the error in n8n → Executions. Gemini free tier: 20 requests/day/model; switch to Groq (`set-groq-key.sh`) or use `agent-demo.sh` |
| Chat: **Failed to receive response**, no execution | Stale tab or dead tunnel | Reload the tab; use `chat.html` |
| The agent invented a product/customer | The model skipped the tool | `Chat Model` → Temperature 0 (shipped as 0) |
| `port 4004 is already in use` | Previous `cds watch` still running | `./scripts/stop-demo.sh` |
| `command not found: n8n` / `cds` | nvm PATH missing in a new shell | Open a new Terminal or use the scripts |
| Terminal windows do not open | Automation permission | System Settings → Privacy & Security → Automation → Terminal; or `--bg` |
| Extra orders in the list | Rehearsal orders | `./scripts/stop-demo.sh --cap && ./scripts/start-demo.sh --cap` |

## 14. FAQ

**Would this run in production?** The architecture yes, this setup no. Here you have in-memory SQLite and a
local n8n. In production CAP goes to BTP (HANA Cloud, XSUAA), n8n to your own server or the managed
version inside BTP; the webhook gets OAuth2 / mTLS and an IP allowlist; the write-back goes through a
queue. The pattern stays the same.

**Why not SAP Build Process Automation or Integration Suite?** Both are valid. n8n's advantage is hundreds
of non-SAP integrations and ready-made LLM / agent nodes, and it runs on a laptop in five minutes. The
choice depends on whether the centre of gravity of the process is inside SAP or outside.

**What if the agent creates a wrong order?** Two guards: the agent cannot call `createOrder` before
verifying product and customer, and CAP returns 400 for unknown products. Every order it creates is
`PENDING`; the approval stays with the rule and the human. From n8n 2.6 a single tool call can also be
gated by human approval.

**Cost?** Only the LLM calls in Act 2; the free tiers of Groq and Gemini are enough for the demo. Act 1 has
no model, just a deterministic rule.

## 15. Taking it to production

| Topic | In the demo | In production |
|---|---|---|
| Authentication | Static `X-API-Key`, no auth in CAP | JWT / OAuth2 on the webhook, IP allowlist; XSUAA in CAP, separate scope for `approve`/`reject` |
| Write-back | Synchronous HTTP | Asynchronous (queue / Event Mesh), retries and idempotency keys |
| Database | In-memory SQLite | HANA Cloud; Postgres for n8n |
| Running n8n | `npm i -g n8n`, SQLite | Pinned version, Postgres, encryption-key backup, queue mode |
| Licence | Community (fair-code) | Internal self-hosting is free; cannot be sold as a service. SSO, environments, secret store, SLA are paid tiers |
| Audit | Executions screen | Retention policy for execution data, log forwarding, PII masking |

## 16. Notes

Customer and product names are fictional sample data. The code is for teaching purposes; read § 15 before
taking it to production. Questions, corrections and suggestions are welcome as issues.
