#import "@preview/diagraph:0.3.0": *
#set text(
  font: "Liberation Serif",
  size: 12pt,
  lang: "hu",
)

#set par(justify: true)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
)

#set heading(numbering: "1.")

#set figure(numbering: "1.")
#show figure: it => align(center)[
  #it.body
  #v(8pt)
  #if it.has("caption") {
    context {
      let num = counter(figure.where(kind: it.kind)).display(it.numbering)
      text(size: 11pt)[#num #lower(it.supplement): #it.caption.body]
    }
  }
]

#show ref: it => {
  let el = it.element
  if el != none and el.func() == figure {
    let num = numbering(el.numbering, ..counter(figure.where(kind: el.kind)).at(el.location()))
    link(el.location())[#num #lower(el.supplement)]
  } else {
    it
  }
}

// cover page
#align(center)[
  #image("bme_logo.svg", width: 60%)

  #v(1cm)

  #text(size: 22pt, weight: "bold")[
    Önálló laboratórium beszámoló
  ]

  #v(0.5cm)

  #text(size: 14pt)[
    Távközlési és Mesterséges Intelligencia Tanszék
  ]

  #v(1cm)

  #grid(
    columns: (1fr, 2fr),
    align: (right, left),
    column-gutter: 1em,
    row-gutter: 0.8em,

    [*Készítette:*], [Horváth Benedek],
    [], [#link("mailto:benedekhorvath@edu.bme.hu")[benedekhorvath\@edu.bme.hu]],
    [*Neptun-kód:*], [`D86EP7`],
    [*Ágazat:*], [mérnökinformatikus szak],
    [*Konzulens:*], [Németh Felicián],
    [], [#link("mailto:nemethf@tmit.bme.hu")[nemethf\@tmit.bme.hu]],
    [*Konzulens:*], [Lévai Tamás],
    [], [#link("mailto:levait@tmit.bme.hu")[levait\@tmit.bme.hu]],
  )

  #v(1cm)

  #align(left)[
    #text(size: 14pt, weight: "bold")[Téma címe: Médiaátvitel QUIC felett]

    #v(0.5cm)

    *Feladat:* \
    A féléves munka célja a Media over QUIC (MoQ) protokollhoz tartozó `moq-rs` implementáció megfigyelhetőségi (observability) lehetőségeinek feltérképezése és elemzése. A feladat magában foglalja a különböző metrikagyűjtési és vizualizációs technológiák (pl. Prometheus, OpenTelemetry) összehasonlító vizsgálatát, valamint a `moq-rs` architektúrájához leginkább illeszkedő megoldás kiválasztását. A hallgatónak meg kell vizsgálnia, hogyan gyűjthetők hatékonyan rendszerszintű és alkalmazásszintű adatok elosztott környezetben. Az eredményeket mutassa be egy implementációval, vizualizálja, és értékelje a látható eredményeket.
  ]

  #v(1fr)

  #text(size: 14pt)[
    *Tanév:* 2025/2026. tanév, I. félév
  ]
]

#pagebreak()

#set page(
  header: align(left)[
    #text(style: "italic")[Horváth Benedek (D86EP7)]
  ],
)

// table of contents
// #outline(title: "Tartalomjegyzék", indent: auto)

//#pagebreak()

#set page(numbering: "1")
#counter(page).update(1)

= Bevezetés

A modern videóstreaming felhasználói egyre magasabb elvárásokat támasztanak a tartalom minőségével és valós idejű elérhetőségével szemben. Az olyan interaktív alkalmazásoknál, mint az élő közvetítések, a hagyományos protokollok késleltetése már zavaró lehet – például amikor a szomszéd előbb ünnepli a gólt, mint ahogy mi látjuk. Erre kínál megoldást a Media over QUIC (MoQ) @moq, amely a QUIC protokoll @quic gyorsaságát és rugalmasságát használja ki a médiaátvitelre, felváltva az elavult TCP-alapú megoldásokat.

A Media over QUIC nem csupán egy új szállítási protokoll, hanem egy teljesen új hálózati architektúrát is feltételez, amely a publikáló-feliratkozó modellre épül. Ebben az architektúrában három fő szereplőt különböztetünk meg: a tartalom előállítóját (publisher), a fogyasztót (subscriber) és a közvetítő hálózatot alkotó relay csomópontokat.
A relayek feladata a tartalom továbbítása és gyorsítótárazása, hasonlóan a hagyományos CDN (Content Delivery Network) topológiákhoz.

Egy ilyen elosztott rendszerben a hálózat állapotának és teljesítményének nyomon követése nem egyszerű. Ez köszönhető részben a QUIC titkosításának TLS-sel, ami miatt nem tudunk belehallgatni az adatfolyamokba, részben pedig annak, hogy a hálózat résztvevői mind külön-külön QUIC-kapcsolatot tartanak fent, ezzel is bonyolítva a megfigyelést. A rendszer komplexitása miatt nehéz átfogó képet kapni a működésről, ezért érdemes lehet megvizsgálni a megfigyelhetőség (observability) kialakítását. Jelenleg a MoQ implementációk megfigyelhetősége korlátozott, ami nehezíti, hogy jól felhasználható statisztikákat készítsünk.
A feladat célja a `moq-rs` @moq_rs_repo implementáció mérési lehetőségeinek vizsgálata. A munka során:
- Feltérképezésre kerülnek a lehetséges mérési pontok a `moq-rs` architektúrájában.
- Összehasonlításra kerülnek a különböző telemetriagyűjtési technológiák.
- Tervezésre és implementálásra kerül egy moduláris mérési rendszer.
- Az eredmények vizualizációja is megtörténik, hogy azok az üzemeltetők számára is értelmezhetők legyenek.
- A mérési eredmények helyességének ellenőrzése és a rendszer működésének validálása is megtörténik.

= Háttér

== A MoQ-ökoszisztéma
A Media over QUIC (MoQ) architektúra (@fig:moq_arch) alapvetően három szereplőt különböztet meg: a *publisher*-t, aki a tartalom előállítója (stream forrása, kamera stb.), a *relay*-t, ami a közvetítő szerver, amely gyorsítótárazza és továbbítja az adatokat, alkotva a CDN (Content Delivery Network) gerincét, valamint a *subscriber*-t, ami a fogyasztó (pl. videólejátszó).

A szereplőkön kívül fontos megemlíteni a MoQ adatmodelljének elemeit is. A *namespace* (névtér) a streamek logikai csoportosítását szolgálja, segítve a tartalmak rendszerezésében (pl. `bbb` vagy `ccc`). A *stream* egy önálló tartalomfolyam (pl. egy videóadás), amelyet mindig egy névtér azonosít. A streamen belüli logikai egység a *track*, amely lehet például külön kép- és hangsáv, vagy különböző felbontás. A legkisebb átviteli egységek a *group* és az *object*. A trackek csoportokra (group), azok pedig objektumokra (object) vannak bontva. Egy objektum lehet például egy részlete a képnek (pár képkocka) vagy a hangsávnak, és a hálózati átvitel ezen a szinten történik.

A feladat alapjául szolgáló `moq-rs` projekt ezt az architektúrát valósítja meg Rust nyelven. A projekt több, egymásra épülő komponensből áll: a rendszer magját a *`moq-transport`* adja, amely a MoQ protokoll alapvető alkotóelemeit valósítja meg QUIC felett. A hálózat gerincét a *`moq-relay`*, a központi médiatovábbító szerver biztosítja, míg a *`moq-pub`* és *`moq-sub`* a referencia kliensimplementációk (publisher és subscriber).

#figure(
  raw-render(
    ```dot
    digraph {
      rankdir=LR;
      node [shape=rect, style="filled", fillcolor="#f0f0f0", fontname="Liberation Sans"];
      edge [fontname="Liberation Sans", fontsize=10];

      subgraph cluster_publishers {
        label = "Publishers";
        style = dashed;
        color = gray;
        Pub1 [label="Publisher 1\n(stream: bbb)"];
        Pub2 [label="Publisher 2\n(stream: ccc)"];
      }

      Relay [label="MoQ Relay", fillcolor="#e0e0ff", style="filled,bold"];

      subgraph cluster_subscribers {
        label = "Subscribers";
        style = dashed;
        color = gray;
        Sub1 [label="Subscriber 1\n(watch: bbb)"];
        Sub2 [label="Subscriber 2\n(watch: bbb)"];
        Sub3 [label="Subscriber 3\n(watch: ccc)"];
      }

      Pub1 -> Relay [label="bbb", color="blue", fontcolor="blue", penwidth=2];
      Pub2 -> Relay [label="ccc", color="green", fontcolor="green", penwidth=2];

      Relay -> Sub1 [label="bbb", color="blue", fontcolor="blue", penwidth=2];
      Relay -> Sub2 [label="bbb", color="blue", fontcolor="blue", penwidth=2];
      Relay -> Sub3 [label="ccc", color="green", fontcolor="green", penwidth=2];
    }
    ```,
    labels: (:),
  ),
  caption: [A Media over QUIC (MoQ) architektúra logikai felépítése több stream esetén.],
) <fig:moq_arch>

== Megfigyelhetőség és mérés
A megfigyelhetőségnek három elterjedt módját ismerjük. A *logging* (naplózás) konkrét események rögzítését jelenti, ami leírja egy program működését, és elsődleges célja a hibakeresés és az auditálás. A *tracing* (nyomkövetés) jellemzően egy kérés, hívás, vagy egy csomag útjának nyomon követése a rendszer különböző komponensein keresztül. A *metrics* (metrikák) pedig számszerű adatok gyűjtése idősoros formában globálisan.

Ezek közül a jelenlegi feladat szempontjából a metrikák a legfontosabbak, mivel ezek adnak átfogó képet a rendszer globális állapotáról és teljesítményéről anélkül, hogy elvesznénk az egyedi csomagok részleteiben. A metrikáknak három fő típusát különböztetjük meg: a *counter*-t, amely csak növelhető (pl. összes fogadott bájt) és újraindításkor nullázódik, a *gauge*-t, amely egy fel-le változó érték és egy pillanatnyi állapotot tükröz (pl. aktív kapcsolatok száma), valamint a *histogram*-ot, amely eloszlások mérésére szolgál (pl. válaszidők).

A metrikák gyűjtésére két alapvető architektúrális minta létezik. A *pull modell* (pl. Prometheus @prometheus) esetében a monitorozó szerver periodikusan lekérdezi ("scrape") az alkalmazás végpontját. Ennek előnye a központi vezérlés, hátránya a hálózati elérés nehézségei lehetnek. A *push modell* (pl. Graphite, OpenTelemetry OTLP @opentelemetry) esetében az alkalmazás küldi el az adatokat, ami egyszerűbb hálózati szempontból, de nehezebben skálázható a terhelés.

Bár a hálózat dinamikus felépítése indokolhatná a push modellt, a Prometheus elterjedtsége és egyszerűsége miatt a fejlesztés során mégis a pull modell került kiválasztásra.

== Használt technológiák

Mivel a `moq-rs` teljes egészében Rust nyelven íródott, a választott technológiának rendelkeznie kell megfelelőRust támogatással.

A *Prometheus* jelenleg az ipari standard a metrikák tárolására és lekérdezésére. Nagyon elterjedt, nagy ökoszisztémával rendelkezik, amit egy erős lekérdezési nyelv, a PromQL támogat.

Az *OpenTelemetry (OTel)* egy újabb szabvány, amely egyesíti a trace-ek, logok és metrikák gyűjtését, azonban használata bonyolult és körülményes. Előnye, hogy a backend (ami akár Prometheus is lehet) könnyen cserélhető.

Ezek miatt a Prometheus lett használva közvetlenül, mert egyrészt egyszerűbb a használata, másrészt kevesebb erőforrást is igényel, valamint most kifejezetten a metrikákon van a hangsúly.

A két technológia összehasonlítását az @tab:prom_vs_otel tartalmazza.

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    inset: 10pt,
    align: horizon,
    [*Tulajdonság*], [*Prometheus*], [*OpenTelemetry*],
    [Modell], [Pull (alapértelmezett)], [Push (OTLP)],
    [Adattípusok], [Metrika], [Trace, Log, Metrika],
    [Integráció komplexitása], [Alacsony], [Magas],
    [Rust támogatás], [Stabil], [Fejlesztés alatt],
  ),
  caption: [A Prometheus és az OpenTelemetry összehasonlítása.],
) <tab:prom_vs_otel>

A fejlesztéshez kellett választani egy Prometheus könyvtárat. A Rust ökoszisztémában a mérésre több megoldás létezik:
- *`prometheus-client`:* A Prometheus projekt hivatalos Rust klienskönyvtára @prometheus_client_crate. Ez nem egy generikus facade, hanem egy típusbiztos, közvetlen implementáció, amely saját regisztert (Registry) kezel. Előnye a szoros integráció a Prometheus adatmodellel és a nagy teljesítmény.
- *`metrics`:* Egy népszerű, generikus könyvtár @metrics_crate. Bár rugalmas, a `prometheus-client` közvetlenebb kontrollt biztosít a metrikák felett.
- *`opentelemetry`:* Az OTel teljes implementációja @opentelemetry. Bár nagy tudású, nehézkesebb a használata és nagyobb overheaddel jár.

A `moq-rs` fejlesztése során a `prometheus-client` cratet használtam, mivel ennek használata a leghatékonyabb és legegyszerűbb Prometheus formátumú adatok kezelésére.

A vizualizációhoz a Grafanat @grafana választotta, amely egy nyílt forráskódú vizualizációs platform, amely lehetővé teszi a metrikák lekérdezését, megjelenítését és vizualizációját. Képes számos adatforráshoz, köztük a Prometheushoz is kapcsolódni, így ideális választás a gyűjtött adatok megjelenítésére. A segítségével létrehozhatunk dinamikus dashboardokat, amelyek valós időben mutatják a rendszer állapotát, például a sávszélesség-használatot vagy a kapcsolatok számát.

= Metrikagyűjtés beépítése a `moq-rs`-be

A rendszer tervezésekor az elsődleges szempont, hogy az architektúra minél függetlenebb legyen az eredeti `moq-rs` kódtól, elősegítve ezzel a későbbi integrációt a hivatalos kódbázisba egy egyszerűsített pull request (PR) formájában. Ezen kívül nagy hangsúlyt fektettem a modularitásra is, hogy könnyen használható legyen a változtatás. A méréseket végző kód ezért egy különálló könyvtárba, a `moq-metrics`-be került kiszervezésre.

Ez a komponens felelős a metrikák regisztrálásáért és az exporterek kezeléséért. Gyakorlatilag a Prometheus backendet köti össze az alkalmazás többi részével.
Főbb feladatai:
- a `prometheus-client` használata,
- a Prometheus exporter elindítása egy konfigurálható HTTP porton,
- hálózati metrikák gyűjtése,
- rendszermetrikák (CPU, memória) periodikus gyűjtése.

A tervezés fontos lépése volt a releváns metrikák meghatározása. Nem az volt a cél, hogy "minden legyen mérve", hanem hogy olyan mutatókat lehessen mérni, amelyekből következtetni lehet a hálózat minőségére és a rendszer korlátaira. A `lib.rs`-ben definiált metrikák négy fő kategóriába sorolhatók:

1. *Forgalmi adatok:* A átvitt adatmennyiség (bájtok) és objektumok száma, mind a publikálók, mind a feliratkozók irányába. Ez ad képet a rendszer tényleges terheléséről.
2. *Kapcsolatok állapota:* Az aktív QUIC kapcsolatok, publikálók és feliratkozók száma, valamint a hálózati minőség mutatói (pl. RTT, csomagvesztés).
3. *MoQ specifikus metrikák:* A protokoll szintű entitások, mint a meghirdetett és feliratkozott sávok követése.
4. *Rendszererőforrások:* A CPU és memória felhasználása mind folyamat, mind rendszerszinten, ami kritikus a skálázódás és a hardveres korlátok felismerése szempontjából.

A projektben a *pull modell* került kiválasztásra a Prometheus széleskörű támogatottsága miatt. Minden `moq-rs` komponens (relay, publisher, subscriber) elindít egy HTTP szervert, ahonnan a Prometheus szerver begyűjtheti az aktuális metrikákat.





#pagebreak()

= Megvalósítás

A megvalósítás során a `prometheus-client` crate API-ja került felhasználásra a megfelelő mérési pontokon a `moq-rs` kódbázisában.


A `lib.rs` számos metrikát definiál, amelyek közül a teljesség igénye nélkül néhány fontosabb példa:
- *`moq_relay_bytes_received_from_publisher` (Counter):* A publikálóktól fogadott adatmennyiség bájtokban.
- *`moq_relay_quic_connections_active` (Gauge):* Az éppen élő QUIC kapcsolatok száma.
- *`moq_relay_active_subscribed_tracks` (Gauge):* Az aktív feliratkozások száma névtér (namespace) szerint bontva.
- *`moq_relay_quic_rtt_milliseconds` (Gauge):* A QUIC kapcsolatok körkörös késleltetése (RTT) milliszekundumban.
- *`process_cpu_usage_percent` (Gauge):* A folyamat CPU használata százalékban.

A @tab:metrics_list tartalmazza az összes eddig implementált metrikát.
#figure(
  text(size: 12pt)[
    #table(
      columns: (3fr, 1fr, 1fr),
      inset: 5pt,
      align: left + horizon,
      [*Metrika*], [*Típus*], [*Mérési pont*],
      [`moq_relay_announced_tracks`], [Counter], [Relay],
      [`moq_relay_announced_tracks_current`], [Gauge], [Relay],
      [`moq_relay_active_subscribed_tracks`], [Gauge], [Relay],
      [`moq_relay_objects_sent`], [Counter], [Relay],
      [`moq_relay_bytes_received_from_publisher`], [Counter], [Relay],
      [`moq_relay_bytes_sent_to_subscriber`], [Counter], [Relay],
      [`moq_relay_active_publishers`], [Gauge], [Relay],
      [`moq_relay_quic_rtt_milliseconds`], [Gauge], [Relay],
      [`moq_relay_quic_connections_active`], [Gauge], [Relay],
      [`moq_relay_quic_lost_packets`], [Gauge], [Relay],
      [`moq_relay_quic_sent_packets`], [Gauge], [Relay],
      [`process_cpu_usage_percent`], [Gauge], [Minden],
      [`process_memory_bytes`], [Gauge], [Minden],
      [`system_cpu_usage_percent`], [Gauge], [Minden],
      [`system_memory_bytes`], [Gauge], [Minden],
      [`system_memory_available_bytes`], [Gauge], [Minden],
      [`subscriber_objects_received`], [Counter], [Subscriber],
      [`subscriber_bytes_received`], [Counter], [Subscriber],
      [`subscriber_active_tracks`], [Gauge], [Subscriber],
      [`publisher_objects_sent`], [Counter], [Publisher],
      [`publisher_bytes_sent`], [Counter], [Publisher],
      [`publisher_active_tracks`], [Gauge], [Publisher],
    )
  ],
  caption: [A `lib.rs`-ben implementált metrikák összefoglalása.],
) <tab:metrics_list>

A `moq-metrics` könyvtárat egyszerűen hozzá lehet adni a többi `moq-rs` komponenshez, és a korábban említett singleton mintának köszönhetően csak egy-egy sort függvényhívást kell betűzni a metrikák növeléséhez. Fontos persze, hogy a HTTP szervereket a komponens felfutásakor elindítsuk, de erre is van globálisan elérhető, publikus függvény.

== Implementációs részletek
A fejlesztés során több érdekes implementációs kérdés is felmerült, amelyek közül a legfontosabbak:

=== Címkézés
A metrikák nem csupán egyszerű számlálók, címkékkel is el lehet őket látni. Például a sávszélesség mérésekor a `namespace` címke jelöli, hogy melyik streamhez tartozik az adat. Ez teszi lehetővé a Grafanában a későbbi szűrést és a részletes bontást (pl. melyik stream "eszi" a legtöbb sávszélességet, vagy melyik relay van földrajzilag leterhelve), ami sokat segít a mutatók összeállításában. Persze a jelenleg implementált címkéken kívül igény szerint lehetne még implementálni, pl. track ID, IP, port stb., ami hasznos lehet.

=== Frissítési stratégiák
A fejlesztés egyik központi kérdése az volt, hogy mikor és hogyan frissüljenek a metrikák értékei. Két eltérő megközelítés is alkalmazásra került a metrikák természetétől függően:

A *QUIC metrikák* esetében a kapcsolatok állapota (pl. aktív kapcsolatok száma, RTT) a `moq-transport` belső memóriájában folyamatosan rendelkezésre áll. Felesleges lenne egy külön szálon, másodpercenként lekérdezni és másolni ezeket az adatokat, ha a Prometheus csak 15 másodpercenként kéri le őket. Ezért itt a "lazy" kiértékelés történik: a metrikák frissítése csak akkor történik meg, amikor beérkezik a HTTP GET kérés a `/metrics` végpontra. Ezt a HTTP szerver handlerében lett megvalósítva, amely közvetlenül a válaszadás előtt olvassa ki az aktuális állapotot, minimalizálva a CPU terhelést és a kontextusváltásokat.

Ezzel szemben a *rendszermetrikák*, különösen a CPU terhelés, gyorsan változnak. Ha itt is igény szerint történne a lekérés, és csak a begyűjtés pillanatában (pl. 5 másodpercenként) lenne mérve a terhelés, könnyen lemaradhatna egy-egy kicsúcsosodás. Ezért a `sysinfo` @sysinfo_crate alapú méréshez egy dedikált, háttérben futó `tokio::task` indul (`tokio::spawn` @tokio_crate). Ez a ciklus sűrűbben mintavételez, és egy belső állapotban tárolja az aggregált értékeket. Amikor a Prometheus lekérdez, már ezt a pontosabb, simított értéket kapja meg. Bár ez némi plusz erőforrást igényel, elengedhetetlen a valós teljesítményképhez.

Ez a hibrid megoldás biztosítja az egyensúlyt, a lassabban változó hálózati metrikák és a gyorsabban változó rendszermetrikák így optimálisan kerülnek kiértékelésre.



=== Tervezési minták
A fejlesztés során két fontos tervezési minta is alkalmazásra került. Az egyik a *Singleton* minta: bár a globális változók használata általában kerülendő, ebben az esetben a `GLOBAL_METRICS` singleton (a `once_cell::sync::Lazy` @once_cell_crate segítségével) jelentősen egyszerűsítette a hívásokat. Így nem kellett minden függvénynek paraméterként átadni a metrika registryt, hanem bárhonnan elérhetővé váltak a számlálók (pl. `moq_metrics::increment_active_connections()`).

A másik fontos minta a *RAII* (Resource Acquisition Is Initialization). A kapcsolatok és trackek számának mérésekor fontos, hogy a számlálók értéke csökkenjen, amikor az erőforrás felszabadul. A manuális `dec()` hívások helyett RAII guardokat implementáltam. Ezek olyan struktúrák, amelyek `Drop` implementációja automatikusan csökkenti a metrikát, amikor a változó kikerül a scopeból.

=== Makrók használata

Példa a `moq-metrics/src/lib.rs`-ből (@code:macro_usage), ahol egy Rust makró segítségével kerültek definiálásra a metrikák. Ez a megoldás jelentősen csökkenti a kódismétlést és egyszerűsíti új metrikák felvételét:

#figure(
  block(stroke: 0.5pt, inset: 10pt, width: 100%)[

    ```rust
    // A makró használata: itt soroljuk fel az összes metrikát
    define_metrics! {
        objects_sent:
            Counter<u64>,
            "moq_relay_objects_sent",
            "Total objects sent",
        // ... további metrikák ...
    }
    ```
  ],
  caption: [A metrikákat definiáló makró használata.],
  supplement: "kódrészlet",
) <code:macro_usage>

A fenti makróhívás a fordítási időben a következő (egyszerűsített) kódra bomlik ki (@code:macro_expansion), ami jól szemlélteti, mennyi "boilerplate" kódot spóroltunk meg:

#figure(
  block(stroke: 0.5pt, inset: 10pt, width: 100%)[

    ```rust
    // A generált kód (kibontva)
    #[derive(Clone)]
    pub struct MoqMetrics {
        pub objects_sent: Counter<u64>,
        // ... többi mező
    }

    impl MoqMetrics {
        pub fn new(registry: &mut Registry) -> Self {
            let objects_sent = <Counter<u64>>::default();
            registry.register(
                "moq_relay_objects_sent",
                "Total objects sent",
                objects_sent.clone()
            );
            // ... többi regisztráció

            Self {
                objects_sent,
                // ... többi mező
            }
        }
    }
    ```
  ],
  caption: [A makró által generált kód egyszerűsített változata.],
  supplement: "kódrészlet",
) <code:macro_expansion>

A metrikák növelése pedig a kód megfelelő pontjain történik (@code:metric_increment), például a `moq-transport/src/session/subscriber.rs`-ben, amikor adat érkezik:

#figure(
  block(stroke: 0.5pt, inset: 10pt, width: 100%)[

    ```rust
    // Példa a számláló növelésére (subscriber.rs)
    pub fn add_bytes_received(count: u64) {
        GLOBAL_METRICS
        .metrics
        .bytes_received_from_publisher
        .inc_by(count);
    }

    // ...
    // A fogadott adat méretének hozzáadása a metrikához
    moq_metrics::add_bytes_received(data.len() as u64);
    ```
  ],
  caption: [Példa a metrikák növelésére a kódban.],
  supplement: "kódrészlet",
) <code:metric_increment>

== Fejlesztési nehézségek és tapasztalatok
A fejlesztés során több kihívás is felmerült:

A *mérési pontok helyes kiválasztása* során a leggyakoribb hiba a "dupla számolás" volt. Mivel bizonyos függvények a kód több pontjáról vagy többször is meghívódhatnak egy esemény bekövetkezetekor, nehéz volt megtalálni azt az egyetlen pontot, ahol a metrikát biztonságosan lehet növelni. Emiatt például az aktív feliratkozott trackekre vonatkozó metrika eleve a feliratkozókra vonatkozott, de kiderült, hogy mindig trackenként lehet csak növelni, és egy streamhez alapértelmezetten nem is egy, hanem több is tartozik, mert mindig van egy "init" track a rendes médiafolyam mellett.

A korábban említett *"on-demand" QUIC-mérésnek* kezdetben volt egy technikai akadálya. A `quinn` könyvtárban @quinn_crate a kapcsolatok statisztikáinak lekérdezése (`conn.stats()`) belső zárolással (lock) jár. Ez azt jelentené, hogy nagy számú QUIC kapcsolat esetén a Prometheus lekérdezés (scrape) ideje alatt a rendszernek egyszerre kellene iterálnia az összes kapcsolaton, ami blokkolhatta volna az új kapcsolatok fogadását. Ezt végül sikerült kiküszöbölni: a metrikák lekérdezésekor a kapcsolatok listája lemásolásra kerül (`Arc` segítségével) a zárolás alatt, így a QUIC-kapcsolatok lekérése már nem blokkol. Ennek ellenére ez a dilemma figyelmet igényel, ugyanis nem minden esetben egyértelmű, hogy pontosan mit történik több ezer QUIC kapcsolat esetén.

A metrikák bevezetése segített beazonosítani *rejtett hibákat* is. A `moq_relay_bytes_received_from_publisher` számláló növekedéséből látszott, hogy a relay akkor is fogadott adatot a publishertől, amikor már nem volt aktív feliratkozó. Ez egy olyan hibát jelzett, ami valószínűleg olyan helyzetben történik, ahol a `DROP` esemény nem került megfelelően átadásra a publisher felé. Ez az eset is mutatja, hogy a metrikagyűjtés valóban hasznosnak bizonyul.

#pagebreak()

= Vizualizáció és elemzés

A begyűjtött metrikák megjelenítésére a Grafana került kiválasztásra, mivel natívan támogatja a Prometheust és rugalmasan testreszabható.

A dashboard úgy lett kialakítva, hogy a legfontosabb mutatókat és a belőlük származtatott értékeket jelenítse meg, átfogó képet adva a rendszer működéséről. A vizualizáció segítségével valós időben követhető nyomon a publikálók és feliratkozók általi kommunikáció, valamint a hálózati sávszélességigény. Látható a a forgalom megoszlása a különböző streamek között, ami segít azonosítani a legnépszerűbb tartalmakat vagy a szűk keresztmetszeteket. Emellett a dashboardon megjelenik a relay folyamat és a rendszer erőforrás-használata (CPU, memória) is, ami hasznos lehet a teljesítménybeli problémák diagnosztizálásához. A közzétett és feliratkozott sávok (tracks) számának összevetése pedig segít a "szivárgó" feliratkozások vagy inkonzisztens állapotok felfedezésében. Az implementált metrikák segítségével számos további panel megvalósítható igényeknek megfelelően.

#figure(
  image("grafana_dash.png", width: 100%),
  caption: [A megvalósított Grafana dashboard egy részlete.],
) <fig:grafana_dashboard>

== Eredmények értelmezése
A mérések során a rendszer erőforrásigényét és a hálózati stabilitást vizsgáltuk. Látszódik, ha változik a feliratkozók vagy a publisherek száma, új streammel bővül a médiafolyam, és az is látszódik, hogy hogyan változik a terhelés ezek függvényében. Jól látszódik az is, ha valamelyik stream a szokásosnál több erőforrást használ, megnő a sávszélesség, hirtelen változás esetén a késleltetés is növekedik.

A @fig:grafana_dashboard pár fontosabb panelt tartalmaz. A felső kettő azt mutatja, hogy mekkora az egyes streamek (`bbb` és `ccc`) által használt sávszélesség a hálózatban. A bal alsó panelen ezek összesítése látható. Az képernyőkép készítése előtt szándékosan változtattam a feliratkozók számát, ez sávszélességbeli ingadozást okoz, ami a grafikonokon is megjelenik. A jobb alsó panelen egy egyszerűbb metrika látható, a relay által használt memória méretét. Ezen az látszódik, hogy az események számának növekedésével (új feliratkozó, új publisher) a memóriafogyasztás is növekedik, bár kis mértékben.

#figure(
  image("namespace_pop.png", width: 80%),
  caption: [A különböző streamek használatának megoszlása.],
) <fig:namespace_pop>

A @fig:namespace_pop mutat egy komplexebb panelt, amin látható, hogy valós időben hogyan változott a feliratkozók száma névterekre lebontva.

= Fejlesztési lehetőségek és összegzés

A féléves munka során sikeresen implementálásra került egy alapvető mérési modul a `moq-rs`-ben, de számos területen van még lehetőség a fejlődésre.

A jelenlegi metrikapalettát még lehet bővíteni igény szerint, például a puffer és cache megfigyelésével, egyéb, lokáció alapú metrikákkal, stb.

A fejlesztett `moq-metrics` könyvtár jelenleg a saját forkban él. A hosszú távú cél, hogy a tapasztalatok alapján egy letisztult, egyszerűsített demó változat készüljön, amely Pull Request formájában visszakerülhet az eredeti `moq-rs` projektbe. Ezáltal a közösség számára is elérhetővé válna egy alapvető, de bővíthető megfigyelhetőségi réteg.

Vannak olyan mérendő adatok, amik nem nyerhetők ki ezzel az egyszerű, tiszta Prometheus implementációval. Érdemes lehet megvizsgálni a lehetőségét annak, hogy az egyes objektumokhoz időbélyeget fűzzünk hozzá, amivel mérhetővé válna az E2E késleltetés mérése. Erre létezik is már formátum a MoQ draftjában, amit lehetne használni, de még nincs implementálva.

A laboratóriumi munka során áttekintésre kerültek a Media over QUIC technológia kihívásai és a modern megfigyelhetőségi eszközök. Tervezésre és megvalósításra került egy moduláris mérési könyvtár, amely képes valós időben információt szolgáltatni a rendszer működéséről. A mérések eredményei igazolták, hogy lehetséges és hasznos a metrikák gyűjtése MoQ-környezetben is. A hasznosságot a korábban említett megtalált implementációs hiba is alátámasztja.

#pagebreak()
#bibliography("bibliography.bib", title: "Irodalomjegyzék")
