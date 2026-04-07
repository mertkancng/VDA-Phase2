# VLSI Design Automation Phase 2 Raporu

## 1. Proje Amaci

Bu projede amac, dogal dil ile verilen bir RTL davranis tanimindan otomatik olarak Verilog testbench ureten bir ajan gelistirmektir. Uretilen testbench'in hedefi, ayni modulu temsil eden 31 RTL implementasyonu arasindan dogru olan tasarimi ayirt etmektir. Testbench, dogru implementasyonda gecmeli ve yanlis mutantlarin mumkun oldugunca buyuk bir kismini elemelidir.

Bu kapsamda ana gelistirme noktasi `test_harness/agent.py` dosyasi icindeki `generate_testbench(file_name_to_content)` fonksiyonudur.

## 2. Problem Tanimi

Her problem klasoru su dosyalari icermektedir:

- `specification.md`: RTL davranisinin dogal dil tanimi
- `mutant_0.v` ... `mutant_30.v`: Ayni modulu temsil eden 31 farkli RTL implementasyonu
- `tb.v`: Uretilen veya verilen testbench

Degerlendirme altyapisi, `tb.v` ile her bir mutant dosyasini `iverilog` kullanarak derlemekte ve simule etmektedir. Testbench'in basarili sayilmasi icin:

- testbench modul adinin `tb` olmasi,
- basarili durumda tam olarak `TESTS PASSED` mesaji yazdirmasi,
- sonunda `$finish` cagirmasi

gerekmektedir.

## 3. Gelistirilen Yaklasim

Bu calismada kural-tabanli bir testbench uretim yaklasimi kullanilmistir. Ajan, problem klasorundeki dosya isimlerini ve iceriklerini girdiler olarak almakta, spec metnini analiz etmekte ve ilk mutant dosyasindan port bilgisini cikarmaktadir.

Ardindan problem tipi tespit edilerek uygun testbench sablonu uretilmektedir. Bu yaklasim tam anlamiyla genel bir LLM-agent degil; ancak teslim zamani kisitli oldugu icin, visible problemlerdeki davranis ailelerine gore ozel test olusturan pratik ve hizli bir cozum gelistirilmistir.

## 4. Uygulanan Mimari

`agent.py` icinde su adimlar uygulanmistir:

1. Problem klasorundeki `specification.md` metni okunur.
2. `mutant_0.v` dosyasindan modul adi ve portlar parse edilir.
3. Spec metni anahtar ifadeler uzerinden siniflandirilir.
4. Problem tipine ozel bir testbench uretici fonksiyon cagirilir.
5. Fonksiyon, tam bir Verilog `tb` modulu dondurur.

Port parse islemi sayesinde testbench olusturulurken modul adi ve sinyal genislikleri otomatik sekilde kullanilmistir.

## 5. Desteklenen Problem Tipleri

Ajan asagidaki visible problem aileleri icin ozel testbench uretmektedir:

- `enc_bin2gray`
- `enc_bin2onehot`
- `ecc_sed_encoder`
- `shift_left`
- `shift_right`
- `counter`
- `lfsr`
- `credit_receiver`
- `cdc_fifo_flops_push_credit`

`fifo_flops` icin ise mevcut durumda guvenli fallback yaklasimi uygulanmistir.

## 6. Testbench Uretim Stratejisi

Her problem tipi icin spec'e uygun directed testler yazilmistir.

### 6.1 Kombinasyonel Moduller

`enc_bin2gray`, `enc_bin2onehot`, `ecc_sed_encoder`, `shift_left` ve `shift_right` gibi kombinasyonel moduller icin:

- giris vektorleri atanmis,
- beklenen cikislar testbench icinde hesaplanmis,
- DUT cikislari ile beklenen degerler karsilastirilmistir.

Bu problem grubunda dogrudan fonksiyonel esdegerlik kontrolu yapmak mumkun oldugu icin daha yuksek ayirt edicilik elde edilmistir.

### 6.2 Sirali Moduller

`counter` ve `lfsr` gibi sirali tasarimlarda:

- clock uretimi testbench icinde yapilmistir,
- reset/reinit/advance/increment/decrement gibi kontrol senaryolari tek tek uygulanmistir,
- testbench icinde basit bir referans model tutulmustur.

### 6.3 Akis Kontrolu ve FIFO Tipi Moduller

`credit_receiver`, `fifo_flops` ve `cdc_fifo_flops_push_credit` gibi daha karmasik modullerde:

- handshake mantigi,
- reset davranisi,
- veri gecisi,
- bazi credit veya buffer davranislari

kontrol edilmistir. Ancak bu sinifta davranislar daha karmasik oldugu icin secicilik diger problem ailelerine gore daha dusuk kalmistir.

## 7. Deneysel Sonuclar

Visible problem klasorleri uzerinde `iverilog` ve `vvp` kullanilarak mutant taramasi yapilmistir. Her problem icin, uretilen testbench'in kac mutant tarafindan gecildigi gozlemlenmistir.

Elde edilen sonuclar:

- `enc_bin2gray`: 1 mutant
- `enc_bin2onehot`: 1 mutant
- `ecc_sed_encoder`: 1 mutant
- `shift_left`: 1 mutant
- `shift_right`: 2 mutant
- `lfsr`: 2 mutant
- `counter`: 3 mutant
- `credit_receiver`: 16 mutant
- `cdc_fifo_flops_push_credit`: 26 mutant
- `fifo_flops`: 31 mutant

Bu sonuclar, kombinasyonel ve acik matematiksel tanimli modullerde yaklasimin basarili oldugunu; buna karsilik daha karmasik stateful ve CDC/FIFO yapilarinda daha gelismis verification mantiklarina ihtiyac oldugunu gostermektedir.

## 8. Karsilasilan Zorluklar

Bu projede asagidaki zorluklarla karsilasildi:

- Dogal dil spec'lerin bazilarinda davranisin eksik veya yoruma acik verilmesi
- Mutant RTL dosyalarinin gate-level veya sentezlenmis yapiya yakin, okunmasi zor formda olmasi
- Kisa surede hem genel hem de secici testbench olusturma gereksinimi
- Karmasik FIFO ve CDC modullerinde dogru tasarimi elemeden mutant eleme dengesini kurmanin zor olmasi

Ozellikle `fifo_flops` ve `cdc_fifo_flops_push_credit` sinifi, daha guclu bir referans model ya da coverage-driven test gerektirmektedir.

## 9. Sinirlar

Mevcut cozumun temel sinirlari sunlardir:

- Genel amacli bir semantic parser veya LLM planlayici kullanilmamistir.
- Testbench uretimi problem ailesi tanimaya dayali oldugu icin hidden problemlerde genelleme sinirlidir.
- FIFO/CDC sinifinda secicilik dusuktur.
- Bazı moduller icin fallback davranisi precision'u azaltmaktadir.

## 10. Iyilestirme Onerileri

Bu projenin daha ileri bir versiyonunda su gelistirmeler yapilabilir:

- Dogal dil spec'ten otomatik referans model cikarma
- Symbolic veya random-constrained test generation
- Coverage-driven testbench generation
- Mutantlar arasi fark gozlemi ile ayirt edici pattern arama
- Simulasyon sonucuna gore testbench'i iteratif olarak iyilestiren agent mimarisi

Ozellikle hidden problemlerde daha yuksek basari icin, mevcut kural-tabanli yapinin LLM destekli reasoning ve simulation feedback ile birlestirilmesi faydali olacaktir.

## 11. Sonuc

Bu calismada, verilen hackathon altyapisina uyumlu bir testbench uretici ajan gelistirilmistir. Sistem, `generate_testbench(file_name_to_content)` fonksiyonu uzerinden calismakta ve verilen spec ile mutant RTL dosyalarindan testbench olusturmaktadir.

Elde edilen sonuclar, kombinasyonel ve net tanimli modullerde yuksek ayirt edicilik saglandigini gostermektedir. Daha karmasik sirali, FIFO ve CDC tabanli modullerde ise cozum calismakla birlikte precision sinirli kalmistir. Buna ragmen proje, Phase 2 teslimi icin gerekli altyapiyi ve otomatik testbench uretim akisini basarili bicimde saglamistir.
