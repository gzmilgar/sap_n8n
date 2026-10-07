const L = require('./lib.js');
const { pptxgen, badge, pill, eyebrow, arrow,
  NAVY, INK, MUTED, SAP, SAP_SOFT, N8N, N8N_SOFT, PANEL, LINE, WHITE, ICE, OK, OKBG, WAIT, WAITBG, H, B, M } = L;

const RED = 'AF3C36', RED_BG = 'F8E7E5', DARK2 = '1B2A40', DARK3 = '243652', GREY = 'B8C2CE';

function title(s, text, { x = 0.6, y = 0.85, w = 8.8, size = 26, color = INK, h = 0.95 } = {}) {
  s.addText(text, { x, y, w, h, fontFace: H, fontSize: size, bold: true, color, margin: 0, isTextBox: true, valign: 'top' });
}
function txt(s, text, o) {
  s.addText(text, Object.assign({ fontFace: B, fontSize: 12.5, color: INK, margin: 0, isTextBox: true, valign: 'top' }, o));
}
function box(s, x, y, w, h, fill, label, fg, { size = 12, line, bold = true, r = 0.08 } = {}) {
  s.addShape('roundRect', { x, y, w, h, fill: { color: fill }, line: { color: line || fill, width: 1 }, rectRadius: r });
  if (label) s.addText(label, { x, y, w, h, fontFace: B, fontSize: size, bold, color: fg, align: 'center', valign: 'middle', margin: 0.05, isTextBox: true });
}
function dashed(s, x1, y1, x2, y2, color) {
  s.addShape('line', { x: x1, y: y1, w: x2 - x1, h: y2 - y1, line: { color, width: 1.25, dashType: 'dash', endArrowType: 'triangle' } });
}
function notes(s, t) { s.addNotes(t); }

(async () => {
  const pres = new pptxgen();
  pres.layout = 'LAYOUT_16x9';
  pres.author = 'Gizem İlgar';
  pres.title = 'SAP + n8n: API\'lerden Akıllı Workflow\'lara';

  const THESIS = 'SAP veriyi tutar, n8n orkestre eder, agent sadece bir arayüzdür.';

  // ======================================================= 1 · TITLE (dark)
  {
    const s = pres.addSlide(); s.background = { color: NAVY };
    // split SAP | n8n joined by HTTP
    box(s, 0.6, 1.25, 1.7, 0.75, SAP, 'SAP', WHITE, { size: 22 });
    arrow(s, 2.3, 1.62, 3.1, 1.62, ICE);
    txt(s, 'HTTP', { x: 2.3, y: 1.2, w: 0.8, h: 0.3, fontFace: M, fontSize: 10, color: ICE, align: 'center' });
    box(s, 3.1, 1.25, 1.7, 0.75, N8N, 'n8n', WHITE, { size: 22 });
    eyebrow(s, 'SAP Inside Track Ankara · Ekim 2026', 0.6, 0.62, ICE);
    s.addText('API\'lerden Akıllı Workflow\'lara', { x: 0.6, y: 2.25, w: 8.8, h: 0.8, fontFace: H, fontSize: 32, bold: true, color: WHITE, margin: 0, isTextBox: true });
    txt(s, THESIS, { x: 0.6, y: 3.2, w: 8.8, h: 0.45, fontFace: H, fontSize: 17, italic: true, color: ICE });
    // timeline bar: 6 slides | demo | 4 slides
    const ty = 4.35;
    box(s, 0.6, ty, 1.6, 0.34, DARK3, '6 slayt', ICE, { size: 11, r: 0.05 });
    box(s, 2.3, ty, 4.9, 0.34, N8N, 'canlı demo · ~12 dk', WHITE, { size: 11, r: 0.05 });
    box(s, 7.3, ty, 1.6, 0.34, DARK3, '5 slayt', ICE, { size: 11, r: 0.05 });
    txt(s, 'Gizem İlgar', { x: 0.6, y: 4.9, w: 5, h: 0.3, fontSize: 13, bold: true, color: WHITE });
    notes(s, 'n8n\'i bir ürün olarak değil, bir SAP geliştiricisinin gözüyle anlatacağım: laptopta kurdum, bir CAP servisine bağladım, üretime koymadım; nerede ne gerekir onu da açıkça söyleyeceğim. Ortası canlı demo; altı slayt zihinsel modeli verir, demodan sonra beş slayt çerçeveyi: korumalar, BTP\'deki yeri, bir SAP mimarının ilkeleri, üretim, kapanış. Şu cümleyi üç kez duyacaksınız: ' + THESIS);
  }

  // ======================================================= 2 · HOOK + WHY NOW (light)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'Neden', 0.6, 0.55, SAP);
    title(s, 'Bir sipariş onayı için bugün kaç sisteme dokunuyoruz?', { size: 24 });

    // LEFT: SAP block leaking to four grey tiles
    const lx = 0.6, ly = 1.95;
    box(s, lx, ly + 0.55, 1.5, 0.9, SAP, 'SAP\nsipariş', WHITE, { size: 12 });
    const tiles = ['e-posta', 'WhatsApp / Telegram', 'Excel', 'telefon'];
    tiles.forEach((t, i) => {
      const ty = ly + i * 0.47;
      box(s, lx + 2.35, ty, 1.55, 0.36, PANEL, t, MUTED, { size: 10.5, bold: false, line: LINE, r: 0.05 });
      dashed(s, lx + 1.5, ly + 1.0, lx + 2.35, ty + 0.18, GREY);
    });
    txt(s, 'bugün', { x: lx, y: ly + 1.9, w: 3.3, h: 0.25, fontSize: 11, italic: true, color: MUTED });
    txt(s, 'Karar dışarıda veriliyor, SAP\'ye elle geri giriliyor.', { x: lx, y: ly + 2.17, w: 3.4, h: 0.45, fontSize: 11.5, color: INK });

    // RIGHT: SAP with one API door ↔ coral "?"
    const rx = 5.4, ry = 1.95;
    box(s, rx, ry + 0.55, 1.5, 0.9, SAP, 'SAP', WHITE, { size: 14 });
    s.addShape('rect', { x: rx + 1.5, y: ry + 0.78, w: 0.1, h: 0.44, fill: { color: WHITE }, line: { color: SAP, width: 1 } });
    txt(s, 'released API', { x: rx + 1.1, y: ry + 0.25, w: 1.1, h: 0.3, fontFace: M, fontSize: 9, color: SAP, align: 'center' });
    arrow(s, rx + 1.62, ry + 0.82, rx + 2.55, ry + 0.82, INK);
    arrow(s, rx + 2.55, ry + 1.18, rx + 1.62, ry + 1.18, N8N);
    box(s, rx + 2.55, ry + 0.55, 1.4, 0.9, N8N_SOFT, '?', N8N, { size: 28, line: N8N });
    txt(s, 'bugünkü oturum', { x: rx, y: ry + 1.9, w: 3.9, h: 0.25, fontSize: 11, italic: true, color: MUTED });
    txt(s, 'Kararı SAP\'nin dışına çıkarıp sonucu geri yazacağız. Sonra aynı API\'yi bir agent\'a vereceğiz — agent sipariş açar, onay yine kuralda ve insanda kalır.', { x: rx, y: ry + 2.17, w: 3.95, h: 0.62, fontSize: 11, color: INK });

    // WHY NOW strip
    const wy = 4.82;
    s.addShape('line', { x: 0.6, y: wy - 0.12, w: 8.8, h: 0, line: { color: LINE, width: 1 } });
    const why = [['Clean core', 'dışarıdaki her şey için released API tek kapı'], ['LLM = HTTP', 'tool calling: JSON\'la dönen bir fonksiyon çağrısı'], ['n8n', 'AI Agent node\'u hazır — Python yazmadan']];
    why.forEach(([h, d], i) => {
      const x = 0.6 + i * 2.98;
      txt(s, h, { x, y: wy, w: 2.8, h: 0.25, fontSize: 11.5, bold: true, color: i === 2 ? N8N : SAP });
      txt(s, d, { x, y: wy + 0.25, w: 2.8, h: 0.4, fontSize: 10.5, color: MUTED });
    });
    notes(s, 'Bu tabloyu hepimiz biliyoruz: onay SAP\'de değil bir chat grubunda veriliyor, sonra biri sisteme elle giriyor. Neden şimdi? AI hype\'ı değil: clean core ile SAP\'nin dışında çalışan her şey için released API tek kapı oldu; LLM çağrısı sıradan bir HTTP isteğine döndü; n8n de agent node\'unu hazır getiriyor. Soru işaretinin cevabı sonraki slayt.');
  }

  // ======================================================= 3 · n8n NEDİR + çeviri tablosu (light)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'n8n nedir', 0.6, 0.55, N8N);
    title(s, 'Canvas\'ı olan bir Node.js süreci — analoji değil, çeviri tablosu', { size: 22 });

    // left column
    const lx = 0.6, lw = 3.0;
    const lines = [
      ['Şu an', 'bu laptopta bir Node süreci, :5678', M],
      ['Üç kelime', 'trigger · node · execution', B],
      ['AI Agent', 'senin OData\'nı çağırmayı seçen bir döngüdeki LLM', B],
    ];
    let y = 1.95;
    lines.forEach(([h, d, f]) => {
      txt(s, h.toUpperCase(), { x: lx, y, w: lw, h: 0.25, fontSize: 10, bold: true, color: N8N, charSpacing: 2 });
      txt(s, d, { x: lx, y: y + 0.25, w: lw, h: 0.55, fontFace: f, fontSize: f === M ? 12 : 13.5, color: INK });
      y += 0.92;
    });
    s.addShape('roundRect', { x: lx, y: 4.62, w: lw, h: 0.55, fill: { color: PANEL }, line: { color: PANEL }, rectRadius: 0.08 });
    txt(s, 'fair-code · self-host ya da Cloud · 2019, Berlin', { x: lx + 0.15, y: 4.62, w: lw - 0.3, h: 0.55, fontSize: 11, color: MUTED, valign: 'middle' });

    // right: translation table
    const tx = 3.95, tw = 5.45, rowH = 0.355;
    const rows = [
      ['Workflow', 'program', false],
      ['Node', 'method / function çağrısı', false],
      ['Webhook trigger', 'SICF servis + IF_HTTP_EXTENSION handler', true],
      ['HTTP Request node', 'cl_http_client · if_web_http_client', false],
      ['Credentials', 'SM59 destination\'ın auth yarısı + STRUST', false],
      ['IF node', 'IF / ELSE', false],
      ['Executions', 'o programın SLG1\'i + ST22\'si', true],
      ['Send and Wait', 'SBWP\'de bekleyen work item — inbox: Telegram', true],
    ];
    const header = (x, w, t) => txt(s, t, { x, y: 1.92, w, h: 0.28, fontSize: 10, bold: true, color: MUTED, charSpacing: 2 });
    header(tx, 2.0, 'N8N'); header(tx + 2.1, 3.3, 'ABAP KARŞILIĞI');
    rows.forEach(([a, b, hot], i) => {
      const ry = 2.22 + i * rowH;
      if (hot) s.addShape('rect', { x: tx - 0.1, y: ry - 0.02, w: tw + 0.2, h: rowH, fill: { color: N8N_SOFT }, line: { color: N8N_SOFT } });
      s.addShape('line', { x: tx, y: ry + rowH - 0.02, w: tw, h: 0, line: { color: LINE, width: 0.75 } });
      txt(s, a, { x: tx, y: ry, w: 2.0, h: rowH, fontFace: M, fontSize: 10.5, color: hot ? N8N : INK, bold: hot, valign: 'middle' });
      txt(s, b, { x: tx + 2.1, y: ry, w: 3.3, h: rowH, fontSize: 11, color: INK, valign: 'middle' });
    });
    txt(s, 'CAP\'çılar için: srv/ handler zincirini kutulara ayırmak; tool = dışarı açtığın bir function.', { x: tx, y: 5.1, w: tw, h: 0.4, fontSize: 9.5, italic: true, color: MUTED });
    notes(s, 'Analoji yapmayacağım, çeviri tablosu vereceğim; üç satır yeter: webhook trigger bir SICF handler, Executions ekranı o programın SLG1\'i artı ST22\'si, send-and-wait SBWP\'de bekleyen bir work item, sadece inbox Telegram. Agent de sihir değil: sizin OData\'nızı çağırmayı seçen bir döngü içindeki LLM; hangi tool\'u ne sırayla çağıracağına o karar veriyor, gerisi yine HTTP. Şu an bu laptopta bir Node süreci olarak çalışıyor, port 5678.');
  }

  // ======================================================= 4 · NELER YAPILIR (light)  ← user asked for this
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'Neler yapılır', 0.6, 0.55, N8N);
    title(s, 'Dört iş, hepsi aynı canvas\'ta', { size: 26 });
    const cards = [
      ['FiLink', 'Entegrasyon', 'SAP-dışı SaaS yapıştırıcısı', ['Jira · Teams · GitHub · Google Sheets ↔ SAP OData', 'Olmayan servis için HTTP Request + Code node', 'MCP: n8n hem sunucu hem istemci'], SAP_SOFT, SAP],
      ['FiClock', 'Otomasyon', 'tetikle, dallan, tekrar dene', ['Webhook · zamanlayıcı · uygulama olayı · chat', 'IF/Switch, döngü, alt-workflow', 'Error workflow, retry, her adımın kaydı'], SAP_SOFT, SAP],
      ['FiUser', 'İnsan döngüde', 'Send and Wait for Response', ['Onay butonu · serbest metin · form', 'Telegram, Slack, Teams, Gmail, Outlook, WhatsApp…', 'Süre sınırı: zaman aşımında devam et'], N8N_SOFT, N8N],
      ['FiCpu', 'AI Agent', 'tool\'lar = senin API\'lerin', ['Chat model: OpenAI, Anthropic, Gemini, Ollama…', 'Tool: HTTP Request, alt-workflow, MCP', 'Tek bir tool\'a insan onayı kapısı (2.6+)'], N8N_SOFT, N8N],
    ];
    const pos = [[0.6, 1.9], [5.1, 1.9], [0.6, 3.5], [5.1, 3.5]];
    for (let i = 0; i < 4; i++) {
      const [ic, h, sub, items, bg, fg] = cards[i]; const [x, y] = pos[i];
      s.addShape('roundRect', { x, y, w: 4.3, h: 1.5, fill: { color: WHITE }, line: { color: LINE, width: 1 }, rectRadius: 0.08 });
      await badge(s, ic, x + 0.18, y + 0.18, 0.5, bg, fg);
      txt(s, h, { x: x + 0.82, y: y + 0.16, w: 3.3, h: 0.28, fontSize: 15, bold: true, color: INK });
      txt(s, sub, { x: x + 0.82, y: y + 0.44, w: 3.3, h: 0.25, fontSize: 10.5, italic: true, color: fg });
      s.addText(items.map((t, k) => ({ text: t, options: { bullet: { indent: 10 }, breakLine: k < items.length - 1 } })),
        { x: x + 0.78, y: y + 0.7, w: 3.4, h: 0.78, fontFace: B, fontSize: 10, color: MUTED, margin: 0, isTextBox: true, valign: 'top', paraSpaceAfter: 2 });
    }
    txt(s, 'Entegrasyon dizini 2.000+ (community node\'lar dahil) · sayı sürüme göre değişir, HTTP Request node geri kalanı kapatır', { x: 0.6, y: 5.12, w: 8.8, h: 0.3, fontSize: 9.5, italic: true, color: MUTED });
    notes(s, 'Dört iş: SAP-dışı SaaS\'ları SAP\'ye yapıştırmak; zamanlanmış ve olay tabanlı otomasyon; insanı döngüye almak — send-and-wait, bir chat mesajında onay butonu; ve agent — chat model artı tool\'lar, tool\'lar da sizin API\'leriniz. Demoda üçüncü ve dördüncüyü göreceksiniz. Sayıya takılmayın, n8n\'in kendi sayfaları bile farklı rakam veriyor; önemli olan HTTP Request node\'unun olmayan her şeyi kapatması.');
  }

  // ======================================================= 5 · SAP İLE NASIL KONUŞUR (light)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'SAP ile ilişkisi', 0.6, 0.55, SAP);
    title(s, 'Tek arayüz HTTP: SAP tutar, n8n orkestre eder', { size: 22, h: 0.6 });

    // dotted clean-core boundary
    s.addShape('roundRect', { x: 0.6, y: 1.95, w: 3.5, h: 2.2, fill: { color: WHITE }, line: { color: SAP, width: 1, dashType: 'dash' }, rectRadius: 0.1 });
    txt(s, 'clean core sınırı', { x: 0.75, y: 2.02, w: 2, h: 0.25, fontSize: 9.5, italic: true, color: SAP });
    box(s, 0.85, 2.38, 3.0, 1.45, SAP, 'CAP  /  RAP\n\nreleased OData (V2/V4)\n+ bir action', WHITE, { size: 12 });
    // gate
    s.addShape('rect', { x: 4.05, y: 2.72, w: 0.12, h: 0.7, fill: { color: WHITE }, line: { color: SAP, width: 1 } });
    txt(s, 'released API', { x: 3.65, y: 3.47, w: 1.1, h: 0.25, fontFace: M, fontSize: 9, color: SAP, align: 'center' });

    // n8n box
    box(s, 6.3, 1.95, 3.1, 2.2, N8N_SOFT, '', N8N, { line: N8N });
    txt(s, 'n8n', { x: 6.45, y: 2.03, w: 1, h: 0.3, fontSize: 14, bold: true, color: N8N });
    const strip = (y, t) => { s.addShape('roundRect', { x: 6.45, y, w: 2.8, h: 0.42, fill: { color: WHITE }, line: { color: LINE }, rectRadius: 0.05 });
      txt(s, t, { x: 6.55, y, w: 2.65, h: 0.42, fontFace: M, fontSize: 9.5, color: INK, valign: 'middle' }); };
    strip(2.42, 'Webhook → IF → Telegram → HTTP');
    strip(2.95, 'Chat → AI Agent → 3 tool (OData)');
    txt(s, 'ikisi de aynı webhook\'a düşer', { x: 6.45, y: 3.47, w: 2.8, h: 0.3, fontSize: 10, italic: true, color: MUTED });

    // arrows
    arrow(s, 4.2, 2.5, 6.3, 2.5, INK);
    txt(s, 'webhook · header key / JWT', { x: 4.25, y: 2.62, w: 2.0, h: 0.28, fontFace: M, fontSize: 9, color: INK, align: 'center' });
    arrow(s, 6.3, 3.55, 4.2, 3.55, N8N);
    txt(s, 'OData action · OAuth2', { x: 4.25, y: 3.6, w: 2.0, h: 0.28, fontFace: M, fontSize: 9, color: N8N, align: 'center' });
    // production alt path
    box(s, 4.55, 1.5, 1.4, 0.38, PANEL, 'Event Mesh · üretim', MUTED, { size: 9.5, bold: false, line: LINE, r: 0.05 });
    dashed(s, 4.15, 2.35, 4.55, 1.72, GREY);
    dashed(s, 5.95, 1.72, 6.35, 2.35, GREY);
    txt(s, '', { x: 5.9, y: 1.58, w: 1.3, h: 0.3, fontSize: 9, italic: true, color: MUTED });

    const pts = [
      'CAP ya da RAP fark etmez: released OData servisi + bir action, ötesi yok',
      'Clean core ile aynı yön: side-by-side, yalnız released API ve event — çekirdeğe dokunan yok',
      'Demo kısayolu: after-CREATE → senkron webhook · Üretim: emit → Event Mesh → n8n, LUW dışı',
    ];
    s.addText(pts.map((t, k) => ({ text: t, options: { bullet: { indent: 12 }, breakLine: k < pts.length - 1 } })),
      { x: 0.6, y: 4.3, w: 8.8, h: 1.1, fontFace: B, fontSize: 11.5, color: INK, margin: 0, isTextBox: true, valign: 'top', paraSpaceAfter: 4 });
    notes(s, 'Yön önemli: SAP dışarı doğru bir webhook atıyor, n8n kimlik doğrulamalı bir action ile geri yazıyor; çekirdeğe dokunan bir şey yok. RAP\'ta desen aynı: released bir Web API artı bir action. Demoda after-CREATE handler\'ı senkron webhook atıyor — ABAP\'çı gözüyle LUW içinde bir yan etki, farkındayım, demo kısayolu; üretimde çıkış olay tabanlı olur. Standalone n8n\'de yerleşik SAP node\'u yok, HTTP Request node\'u yetiyor; SAP\'nin yaptığı node\'lar Joule Studio sürümünde — ona geleceğim.');
  }

  // ======================================================= 6 · ŞİMDİ CANLI (light, hand-off)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'Canlı demo', 0.6, 0.55, N8N);
    title(s, 'Şimdi canlı görelim — üç yere bakın', { size: 28 });
    const watch = [
      ['Execution\'ı açınca IF node\'un kararı', 'liste yalnız durumu gösterir; içeri girince dal görünür'],
      ['"Waiting" durumundaki execution', 'Telegram\'da bir insan bekleniyor — saatlerce de bekleyebilir'],
      ['Agent canvas\'ında üç tool\'un sırayla yanması', 'listProducts → getCustomer → createOrder'],
    ];
    let y = 1.95;
    watch.forEach(([h, d], i) => {
      s.addShape('ellipse', { x: 0.6, y: y + 0.03, w: 0.5, h: 0.5, fill: { color: N8N }, line: { color: N8N } });
      s.addText(String(i + 1), { x: 0.6, y: y + 0.03, w: 0.5, h: 0.5, fontFace: B, fontSize: 16, bold: true, color: WHITE, align: 'center', valign: 'middle', margin: 0, isTextBox: true });
      txt(s, h, { x: 1.3, y, w: 7.9, h: 0.35, fontSize: 17, bold: true, color: INK });
      txt(s, d, { x: 1.3, y: y + 0.36, w: 7.9, h: 0.35, fontSize: 12.5, color: MUTED });
      y += 0.85;
    });
    s.addShape('roundRect', { x: 0.6, y: 4.6, w: 8.8, h: 0.6, fill: { color: PANEL }, line: { color: PANEL }, rectRadius: 0.08 });
    s.addText([
      { text: 'Kural: ', options: { bold: true, color: INK } },
      { text: 'agent siparişi oluşturur, onay kararını vermez — denetleyin.   ', options: { color: INK } },
      { text: 'Ters giderse aynı üç çağrıyı elle atarım.', options: { italic: true, color: MUTED } },
    ], { x: 0.8, y: 4.6, w: 8.4, h: 0.6, fontFace: B, fontSize: 12.5, margin: 0, isTextBox: true, valign: 'middle' });
    notes(s, 'Ekranı demoya geçiriyorum. Üç yere bakın: execution\'ı açınca IF node\'un hangi dala gittiği; Telegram\'da beni bekleyen "waiting" execution; agent canvas\'ında tool\'ların sırayla yanması. Tek kural: agent siparişi oluşturur, onaylamaz — bunu denetleyin. Canlı LLM, canlı demo; ters giderse aynı üç çağrıyı elle atarım, anlatım değişmez.');
  }

  // ======================================================= 7 · AGENT OLUŞTURUR, ONAYLAMAZ (dark)
  {
    const s = pres.addSlide(); s.background = { color: NAVY };
    eyebrow(s, 'Demodan sonra', 0.6, 0.55, ICE);
    s.addText('Agent oluşturur. Onaylamaz.', { x: 0.6, y: 0.85, w: 8.8, h: 0.75, fontFace: H, fontSize: 34, bold: true, color: WHITE, margin: 0, isTextBox: true });

    // two lanes converging on one gate
    const ly = 1.72;
    box(s, 0.6, ly, 4.0, 0.52, N8N, 'Agent:  listProducts → getCustomer → createOrder', WHITE, { size: 10.5, r: 0.06 });
    box(s, 0.6, ly + 0.72, 4.0, 0.52, SAP, 'Kural:  IF tutar > eşik', WHITE, { size: 10.5, r: 0.06 });
    arrow(s, 4.6, ly + 0.26, 5.3, ly + 0.55, ICE);
    arrow(s, 4.6, ly + 0.98, 5.3, ly + 0.7, ICE);
    s.addShape('diamond', { x: 5.3, y: ly + 0.1, w: 1.5, h: 1.05, fill: { color: WAITBG }, line: { color: WAIT, width: 1 } });
    s.addText('İnsan onayı\nsend-and-wait', { x: 5.3, y: ly + 0.1, w: 1.5, h: 1.05, fontFace: B, fontSize: 9.5, bold: true, color: WAIT, align: 'center', valign: 'middle', margin: 0, isTextBox: true });
    arrow(s, 6.8, ly + 0.62, 7.5, ly + 0.62, ICE);
    box(s, 7.5, ly + 0.36, 1.9, 0.52, DARK3, 'SAP: approve action', ICE, { size: 10.5, r: 0.06 });
    s.addShape('rect', { x: 0.6, y: ly + 1.4, w: 8.8, h: 0.22, fill: { color: DARK2 }, line: { color: DARK2 } });
    txt(s, 'her adım Executions\'ta — denetim izi hazır', { x: 0.7, y: ly + 1.4, w: 8.6, h: 0.22, fontFace: M, fontSize: 8.5, color: GREY, valign: 'middle' });

    const seen = [
      ['Gördünüz', 'agent yalnızca createOrder çağırdı — onay/ret tool\'u yok'],
      ['Gördünüz', 'kararı deterministik IF verdi; eşik üstünü bir insan onayladı'],
      ['Görmediniz', 'system prompt tahmini yasaklıyor; tool açıklamaları "doğrula, sonra yaz"ı zorluyor'],
      ['Görmediniz', 'n8n 2.6+ (Oca 2026): tek bir tool\'un çalışması insan onayına bağlanabiliyor'],
    ];
    let y = 3.42;
    seen.forEach(([k, v], i) => {
      const x = i % 2 === 0 ? 0.6 : 5.1, yy = y + Math.floor(i / 2) * 0.68;
      txt(s, k.toUpperCase(), { x, y: yy, w: 1.1, h: 0.25, fontSize: 9, bold: true, color: i < 2 ? OK : WAIT, charSpacing: 1.5 });
      txt(s, v, { x, y: yy + 0.27, w: 4.2, h: 0.38, fontSize: 10.5, color: ICE });
    });
    txt(s, THESIS, { x: 0.6, y: 4.92, w: 8.8, h: 0.35, fontFace: H, fontSize: 14, italic: true, color: WHITE });
    notes(s, 'Demoda iki koruma gördünüz: agent yalnızca oluşturdu, onay kararını IF verdi, eşik üstünü de bir insan onayladı. İki tane daha var: system prompt tahmini yasaklıyor, tool açıklamaları önce doğrula sonra yaz diyor; ve 2.6 ile gelen, tek bir tool\'un çalışmasını insan onayına bağlama özelliği — yazan her tool\'a böyle bir kapı koyabiliyorsunuz. Tek doğru sonuç varsa deterministik workflow, yargı gerekiyorsa agent; ikisi de aynı onay kapısından geçti. ' + THESIS);
  }

  // ======================================================= 8 · YERLEŞİM + SAP×n8n (light)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'SAP ve BTP\'deki yeri', 0.6, 0.55, SAP);
    title(s, 'Üç araç, üç yer — n8n artık BTP\'de', { size: 23, h: 0.6 });

    const cols = [
      ['Integration Suite', 'hacim · garantili teslim · B2B/EDI · API Management · merkezi izleme', 'onay: —', 'destek: SAP', SAP_SOFT, SAP],
      ['Build Process Automation', 'merkezde insan: form · karar tablosu · RPA · My Inbox / Task Center', 'onay: Inbox / Task Center', 'destek: SAP', SAP_SOFT, SAP],
      ['n8n', 'SAP-dışı SaaS yapıştırıcısı · chat\'te onay · AI agent · PoC', 'onay: Telegram / Teams / mail', 'destek: forum · SLA yalnız Enterprise', N8N_SOFT, N8N],
    ];
    cols.forEach(([h, d, a, sup, bg, fg], i) => {
      const x = 0.6 + i * 2.98, y = 1.62, w = 2.8;
      s.addShape('roundRect', { x, y, w, h: 1.75, fill: { color: WHITE }, line: { color: LINE }, rectRadius: 0.08 });
      s.addShape('roundRect', { x, y, w, h: 0.42, fill: { color: bg }, line: { color: bg }, rectRadius: 0.08 });
      txt(s, h, { x: x + 0.15, y, w: w - 0.3, h: 0.42, fontSize: 12.5, bold: true, color: fg, valign: 'middle' });
      txt(s, d, { x: x + 0.15, y: y + 0.5, w: w - 0.3, h: 0.62, fontSize: 10.5, color: INK });
      txt(s, a, { x: x + 0.15, y: y + 1.12, w: w - 0.3, h: 0.25, fontSize: 10, color: MUTED });
      txt(s, sup, { x: x + 0.15, y: y + 1.38, w: w - 0.3, h: 0.32, fontSize: 9.5, color: MUTED });
    });
    // "don't give n8n" strip
    s.addShape('roundRect', { x: 0.6, y: 3.46, w: 8.8, h: 0.38, fill: { color: RED_BG }, line: { color: RED_BG }, rectRadius: 0.06 });
    s.addText([
      { text: 'n8n\'e verme:  ', options: { bold: true, color: RED } },
      { text: 'B2B/EDI   ·   mapping tasarımcısı   ·   SLA\'lı yüksek hacim   ·   "SAP-supported tooling" şartı', options: { color: RED } },
    ], { x: 0.8, y: 3.46, w: 8.5, h: 0.38, fontFace: B, fontSize: 10.5, margin: 0, isTextBox: true, valign: 'middle' });

    // the headline fact
    s.addShape('roundRect', { x: 0.6, y: 3.95, w: 8.8, h: 1.42, fill: { color: NAVY }, line: { color: NAVY }, rectRadius: 0.08 });
    txt(s, 'MAYIS 2026 → BUGÜN', { x: 0.85, y: 4.02, w: 2.5, h: 0.22, fontSize: 10, bold: true, color: ICE, charSpacing: 2 });
    s.addText([
      { text: 'SAP, n8n\'e stratejik azınlık yatırımı yaptı (5,2 mlr $ değerleme) — satın alma değil, ortaklık', options: { bold: true, color: WHITE, breakLine: true } },
      { text: 'Runtime: SAP Business AI Platform / BTP — akış SAP bulutunda koşar, veri müşterinin SAP ortamında kalır', options: { color: ICE, breakLine: true } },
      { text: 'Editör: Joule Studio 2.0 içinde · SAP işletir (kimlik, erişim, operasyon) · tüketim BTP kredisinden', options: { color: ICE, breakLine: true } },
      { text: 'SAP-yapımı node\'lar: HANA · Task Center · Integration Suite · MCP · SAP Agent — ilk müşteriler Haz 2026\'dan beri, GA yayılıyor; bağımsız n8n\'de SAP node\'u yok', options: { color: GREY } },
    ], { x: 0.85, y: 4.26, w: 8.35, h: 1.08, fontFace: B, fontSize: 9.5, margin: 0, isTextBox: true, valign: 'top', paraSpaceAfter: 1 });
    notes(s, 'SAP salonunda SAP ürününü kötülemeyeceğim, gerek de yok: Inbox ve governance istiyorsanız SBPA, hacim ve EDI için Integration Suite doğru cevap. n8n\'in yeri uzun kuyruk: Jira, Teams, Telegram adımı için kimsenin platform lisansı almayacağı yerler, PoC, ve LLM tool-calling\'in hazır gelmesi. EDI, mapping tasarımcısı, merkezi mesaj izleme n8n\'de yok; satın alma "SAP-supported" şartı koyuyorsa bağımsız n8n yanlış araç. Asıl haber alttaki kutu: SAP Mayıs\'ta n8n\'e azınlık yatırımı yaptı — satın almadı — ve n8n\'i BTP\'ye alıyor. Mimari olarak ne demek: runtime SAP Business AI Platform\'da, yani akış SAP bulutunda koşuyor ve veri sizin SAP ortamınızdan çıkmıyor; editör Joule Studio 2.0\'ın içinde; kimlik, erişim ve operasyonu SAP yönetiyor; tüketim BTP kredisinden düşüyor. SAP kendi node\'larını yazdı — Task Center node\'u demodaki Telegram onayının kurumsal karşılığı. İlk müşteriler Haziran\'dan beri kullanıyor, GA yayılıyor; "yayında, herkese açık" demeyin, "geliyor, kademeli" deyin. Bugün gösterdiğim bağımsız n8n; aynı canvas, aynı JSON, yarın Joule Studio\'da.');
  }

  // ======================================================= 8b · TASARIM İLKELERİ (light)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'Bir SAP mimarının ilkeleri', 0.6, 0.55, N8N);
    title(s, 'Belirsizliği çekirdek sürece sokmadan değer üretmek', { size: 20, h: 0.55 });
    txt(s, 'SAP Devtoberfest 2026 · "n8n for Agentic Integrations" (Shebang Software) — garanti talebi eklerini LLM\'le değerlendiren bir Fiori + n8n demosundan', { x: 0.6, y: 1.42, w: 8.8, h: 0.42, fontSize: 10, italic: true, color: MUTED });

    const rules = [
      ['FiCrosshair', 'Edge case\'lere göre tasarla', 'mutlu yol değil, uyumsuz fatura ve yanlış fotoğraf test edildi'],
      ['FiRepeat', 'Küçük, tekrarlanabilir işle başla', 'tek bir soru: "bu ek bu talebe uyuyor mu?"'],
      ['FiMinimize2', 'Çıktıyı sınırla', 'serbest metin değil — sabit JSON şeması, skor, evet/hayır'],
      ['FiUser', 'Human-in-the-loop ile başla', 'agent karar vermiyor, insanın işini hızlandırıyor; güven arttıkça genişler'],
      ['FiDollarSign', 'Maliyeti ölç', 'bir PDF\'in OCR + değerlendirmesi ≈ 0,8 ¢ — klasik OCR\'dan ucuz ve isabetli'],
      ['FiShield', 'Yönetişimi baştan kur', '"çok PoC, az üretim" — kimlik, denetim ve bağlam toplama CAP\'te, LLM erişimi Generative AI Hub\'dan'],
    ];
    const pos = [[0.6, 1.95], [5.1, 1.95], [0.6, 2.92], [5.1, 2.92], [0.6, 3.89], [5.1, 3.89]];
    for (let i = 0; i < rules.length; i++) {
      const [ic, h, d] = rules[i]; const [x, y] = pos[i];
      await badge(s, ic, x, y + 0.02, 0.52, N8N_SOFT, N8N);
      txt(s, h, { x: x + 0.7, y, w: 3.6, h: 0.3, fontSize: 13.5, bold: true, color: INK });
      txt(s, d, { x: x + 0.7, y: y + 0.3, w: 3.6, h: 0.56, fontSize: 10, color: MUTED });
    }
    s.addShape('roundRect', { x: 0.6, y: 4.95, w: 8.8, h: 0.36, fill: { color: PANEL }, line: { color: PANEL }, rectRadius: 0.06 });
    s.addText([
      { text: 'Doğru kurgu: ', options: { bold: true, color: INK } },
      { text: 'Fiori → CAP (auth, audit, bağlam) → n8n (Joule Studio\'da managed) → LLM.  ', options: { color: INK } },
      { text: 'UI\'dan doğrudan webhook\'a gitmek demo kısayoludur.', options: { italic: true, color: MUTED } },
    ], { x: 0.8, y: 4.95, w: 8.5, h: 0.36, fontFace: B, fontSize: 10, margin: 0, isTextBox: true, valign: 'middle' });
    notes(s, 'Bunlar benim ilkelerim değil, SAP Devtoberfest\'te bir SAP cloud mimarının anlattığı demodan: garanti taleplerinin eklerini — fatura, fotoğraf — LLM\'e talebin tüm bağlamıyla verip "bu ek bu talebe uyuyor mu" diye skorlatıyorlar. Agent karar vermiyor, değerlendiriciye hangi eke dikkatle bakacağını söylüyor. Aynı ilkeler bizim demoda da var: agent yalnızca oluşturur, çıktı dar — evet/hayır, onay insanda. Maliyet şaşırtıcı: bir PDF yaklaşık bir sentin altı. Ve mimarın uyarısı: UI\'dan doğrudan webhook\'a gitmek demo kısayolu — benimki de öyle — üretimde CAP araya girer, kimliği ve denetimi o üstlenir, n8n Joule Studio\'da managed koşar.');
  }

  // ======================================================= 9 · ÜRETİME TAŞIRKEN (light)
  {
    const s = pres.addSlide(); s.background = { color: WHITE };
    eyebrow(s, 'Üretime taşırken', 0.6, 0.55, SAP);
    title(s, 'Bedava kısmı lisans, bedava olmayan kısmı işletmek', { size: 24 });
    const q = [
      ['Lisansı ne?', OKBG, OK, 'çözüldü', 'Sustainable Use License (fair-code): kurum içi kullanım self-host ücretsiz · servis olarak sunmak / satmak yasak · danışman müşteri adına işletiyorsa lisansı oku'],
      ['SAP destekliyor mu?', WAITBG, WAIT, 'senin işin', 'Bağımsız n8n: hayır — Postman\'i de desteklemiyor; desteklenen şey senin released API\'n · Joule Studio içinde: SAP işletiyor, BTP kredisinden düşüyor'],
      ['Güvenli mi?', OKBG, OK, 'çözüldü', 'Webhook: header key / JWT + IP allowlist · geri yazma: OAuth2 client credentials (XSUAA / IAS) · SAP\'den çıkış asenkron · demoda geri yazma açıktı — bilerek'],
      ['Kim işletecek?', WAITBG, WAIT, 'senin işin', 'Postgres · encryption key yedeği (kaybedersen tüm credential\'lar gider) · sabit sürüm, :latest değil · Docker / K8s / BTP Kyma ya da n8n Cloud'],
    ];
    const pos = [[0.6, 1.88], [5.1, 1.88], [0.6, 3.36], [5.1, 3.36]];
    q.forEach(([h, bg, fg, chip, d], i) => {
      const [x, y] = pos[i];
      s.addShape('roundRect', { x, y, w: 4.3, h: 1.38, fill: { color: WHITE }, line: { color: LINE }, rectRadius: 0.08 });
      txt(s, h, { x: x + 0.18, y: y + 0.14, w: 2.8, h: 0.3, fontSize: 14, bold: true, color: INK });
      pill(s, chip, x + 3.1, y + 0.16, bg, fg, 1.0);
      txt(s, d, { x: x + 0.18, y: y + 0.48, w: 3.95, h: 0.86, fontSize: 10, color: MUTED });
    });
    s.addShape('line', { x: 0.6, y: 4.88, w: 8.8, h: 0, line: { color: LINE } });
    s.addText([
      { text: 'Self-host: ', options: { bold: true } }, { text: 'Community ücretsiz · Business €667/ay      ' },
      { text: 'Cloud: ', options: { bold: true } }, { text: 'Starter €20 · Pro €50/ay (yıllık)      ' },
      { text: 'SLA: ', options: { bold: true } }, { text: 'yalnız Enterprise      ' },
      { text: 'n8n.io/pricing · Eyl 2026', options: { italic: true, color: MUTED } },
    ], { x: 0.6, y: 4.95, w: 8.8, h: 0.35, fontFace: B, fontSize: 10, color: INK, margin: 0, isTextBox: true, valign: 'middle' });
    notes(s, 'Dört sessiz soru. Lisans fair-code: kendi sunucunuzda kurum içi kullanım ücretsiz, servis olarak satamazsınız, ayrıntı lisans metninde, ben avukat değilim. SAP destekliyor mu: bağımsız n8n\'i hayır — Postman\'i de desteklemiyor ama kullanıyoruz; Joule Studio içindeki sürümü SAP işletiyor. Güvenlik: demoda header key ve açık geri yazma — bilerek, localhost; üretimde JWT, IP allowlist, OAuth2, asenkron çıkış. İşletme: Postgres, encryption key yedeği, sabit sürüm — 2.0 kırıcı değişikliklerle geldi. Fiyatlar Eylül itibarıyla; SSO, environments, secret store, SLA ücretli katmanda. Yani bedava kısmı lisans, bedava olmayan kısmı işletmek.');
  }

  // ======================================================= 10 · CLOSE (dark)
  {
    const s = pres.addSlide(); s.background = { color: NAVY };
    s.addText([
      { text: 'Karar SAP\'de', options: { color: '6BA5DC' } }, { text: ',  ', options: { color: GREY } },
      { text: 'kural n8n\'de', options: { color: 'F08BA3' } }, { text: ',  ', options: { color: GREY } },
      { text: 'dil agent\'ta', options: { color: GREY } }, { text: '.', options: { color: GREY } },
    ], { x: 0.6, y: 1.4, w: 8.8, h: 0.75, fontFace: H, fontSize: 24, bold: true, margin: 0, isTextBox: true });
    txt(s, THESIS, { x: 0.6, y: 2.45, w: 8.8, h: 0.45, fontFace: H, fontSize: 17, italic: true, color: ICE });
    const pts = ['Sırayı karıştırmadığınız sürece bu iş çalışıyor', 'Tek ihtiyacınız: dışarı açılmış bir servis ve bir webhook', 'Repo + workflow JSON\'ları + bu deste → QR'];
    s.addText(pts.map((t, k) => ({ text: t, options: { bullet: { indent: 12 }, breakLine: k < pts.length - 1 } })),
      { x: 0.6, y: 3.15, w: 8.8, h: 1.1, fontFace: B, fontSize: 14, color: WHITE, margin: 0, isTextBox: true, valign: 'top', paraSpaceAfter: 5 });
    s.addText([
      { text: 'Gizem İlgar', options: { bold: true, color: WHITE, breakLine: true } },
      { text: 'SAP CAP · n8n · Telegram · Google Gemini — hepsi bu laptopta çalışıyor', options: { color: MUTED } },
    ], { x: 0.6, y: 4.6, w: 8.8, h: 0.6, fontFace: B, fontSize: 13, margin: 0, isTextBox: true });
    notes(s, 'Özet: karar SAP\'de kalıyor, kural n8n\'de, dil agent\'ta. Sırayı karıştırmadığınız sürece — agent\'ı onaylatmaya başlamadığınız sürece — bu iş çalışıyor. Tek ihtiyacınız dışarı açılmış bir servis ve bir webhook. Repo ve workflow JSON\'ları QR\'da. Sorular?');
  }

  await pres.writeFile({ fileName: process.argv[2] || 'SUNUM.pptx' });
  console.log('  ✅ yazıldı:', process.argv[2] || 'SUNUM.pptx');
})().catch(e => { console.error('  ❌', e.message); process.exit(1); });
