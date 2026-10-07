# Sunum destesi ve sahne notları

| Dosya | |
|---|---|
| [`../SUNUM.pptx`](../SUNUM.pptx) | 11 slayt, her birinde konuşmacı notu (Keynote'ta Görünüm → Sunucu Notları) |
| [`SUNUM-NOTLARI.md`](SUNUM-NOTLARI.md) | Sahnedeki dakika dakika akış: T-10 hazırlık, Perde 1 ve 2'nin konuşma metni, kurtarma hamleleri, sık gelen sorular |
| `build-deck.js` | Desteyi üreten pptxgenjs script'i; metin ve notlar burada |
| `lib.js` | Renkler, yazı tipleri, kutu/ok/rozet gibi ortak çizim yardımcıları |

## Yapı

**6 slayt → canlı demo (~12 dk) → 5 slayt.** Deste demoyu anlatmaz, n8n'i bir SAP
geliştiricisinin gözüyle anlatır. Tez cümlesi her bölümde tekrar eder:
*SAP veriyi tutar, n8n orkestre eder, agent sadece bir arayüzdür.*

| # | Slayt | Konuşmacı notunun özü |
|---|---|---|
| 1 | Açılış | Ürün tanıtımı değil, geliştirici deneyimi: laptopta kurdum, CAP'e bağladım, üretime koymadım |
| 2 | Bir onay için kaç sisteme dokunuyoruz? | Süreç SAP'nin dışına taşıyor; neden şimdi |
| 3 | Canvas'ı olan bir Node.js süreci | ABAP çeviri tablosu: SICF, SLG1, SBWP, SM37 karşılıkları |
| 4 | Dört iş, aynı canvas | Entegrasyon, otomasyon, insan döngüde, AI agent |
| 5 | Tek arayüz HTTP | Çağrı yönü, clean core, released API; SAP tutar, n8n orkestre eder |
| 6 | Şimdi canlı görelim | İzleyiciye üç ekranı tarif et, demoya geç |
| 7 | Agent oluşturur. Onaylamaz. | Gördüğünüz iki koruma, görmediğiniz iki koruma |
| 8 | Üç araç, üç yer | SBPA / Integration Suite / n8n; SAP'nin n8n yatırımı, runtime BTP'de, editör Joule Studio'da |
| 9 | Belirsizliği çekirdeğe sokmadan değer üretmek | Bir SAP mimarının altı ilkesi ve doğru BTP kurgusu |
| 10 | Bedava kısmı lisans, bedava olmayan kısmı işletmek | Lisans, destek, güvenlik, işletme, fiyat |
| 11 | Kapanış | Karar SAP'de, kural n8n'de, dil agent'ta |

## Desteyi yeniden üretmek

```zsh
cd sunum
npm init -y >/dev/null
npm install pptxgenjs react-icons react react-dom sharp --no-audit --no-fund
node build-deck.js ../SUNUM.pptx
```

`sunum/node_modules/` `.gitignore`'dadır. Metni değiştirmek için `build-deck.js` içindeki
ilgili slaydı düzenleyip yeniden üret. Yazı tipleri Cambria / Calibri / Courier New;
Office ile gelir, Keynote'ta da aynı görünür.

Slayt 8 ve 10'daki tarih, fiyat ve "SAP'nin BTP içindeki n8n sürümü" bilgileri Eylül 2026
itibarıyladır; sunmadan önce güncelliğini kontrol et.
