#import "figures.typ"

#set page(
  paper: "presentation-16-9",
  margin: 2cm,
  header: context {
    // Empty header
  },
  footer: context {
    let page_num = counter(page).get().first()
    let last_page = counter(page).final().first()

    if page_num > 1 and page_num < last_page {
      let current_slide = page_num - 1
      let total_slides = last_page - 2

      set text(size: 10pt)

      // Progress bar container
      box(width: 100%, height: 4pt, fill: gray.lighten(50%), radius: 2pt)[
        // Progress fill
        #align(left)[
          #box(
            width: (current_slide / total_slides) * 100%,
            height: 100%,
            fill: rgb("#006CC5"),
            radius: 2pt,
          )
        ]
      ]
      v(8pt)

      grid(
        columns: (1fr, auto, 1fr),
        align: (left, center, right),
        text(fill: gray)[Horváth Benedek],
        text(fill: gray)[#current_slide / #total_slides],
        text(fill: gray)[MoQ: Metrikagyűjtési módszerek],
      )
    }
  },
)

#set text(
  font: "Times New Roman",
  size: 20pt,
  lang: "hu",
)

#set figure(numbering: none)
#show figure.caption: it => text(size: 17pt, style: "italic", it)

// Custom slide function
#let slide(title: none, body) = {
  pagebreak()
  if title != none {
    heading(level: 1, title)
    v(1em)
  }
  body
}

// Title Slide
#align(center + horizon)[
  #text(size: 32pt, weight: "bold")[Metrikagyűjtés Media over QUIC hálózatokban]

  #v(1em)

  #text(size: 24pt)[Önálló laboratórium beszámoló]

  #v(2em)

  #grid(
    columns: (1fr, 1fr),
    column-gutter: 2em,
    align(right)[
      *Készítette:*\
      Horváth Benedek\
      `D86EP7`
    ],
    align(left)[
      *Konzulensek:*\
      Németh Felicián\
      Lévai Tamás
    ],
  )

  #v(1.5em)

  #text(size: 16pt, style: "italic")[
    2025/2026. tanév, I. félév
  ]

  #v(1fr)
  #image("bme_logo.svg", width: 20%)
]

// Content Slides

// #slide(title: "A feladat")[
//   Metrikagyűjtési módszerek vizsgálata és implementálása MoQ-környezetben, a hivatalos `cloudflare/moq-rs` implementáció bővítésével.

//   #v(1em)
//   *Kérdések, célok:*
//   - A kód melyik pontján érdemes mérni? Mit?
//   - Mit lehet hozzá használni? (Prometheus vs. OpenTelemetry)
//   - Metrikagyűjtési rendszer implementálása
//   - Vizualizáció Grafanával
// ]

#slide(title: "A Media over QUIC (MoQ) ökoszisztéma")[
  #grid(
    columns: (2fr, 2.1fr),
    column-gutter: 2em,
    align(horizon)[
      Az architektúra három fő szereplőre épül:

      - *Publisher:* Forrás
      - *Relay:* Közvetítő, puffer
      - *Subscriber:* Fogyasztó

      #v(0.5em)
      A MoQ-adatmodell:

      - *Namespace:* Streamek csoportja
      - *Stream:* Trackek csoportja
      - *Track:* Sáv, adatfolyam (pl. videó)
      - *Group / Object:* Átviteli egységek (pl. videódarab)
    ],
    align(center)[
      #figure(
        box(width: 100%, figures.moq_arch_diagram()),
        caption: "Egy egyszerűsített MoQ-hálózat",
      )
    ],
  )
]

#slide(title: "Kiindulási alap")[

  #grid(
    columns: (1.0fr, 0.45fr),
    column-gutter: 0.2em,
    [
      A mérések alapjául szolgáló technológiák és implementációk:

      #v(1em)
      *QUIC Protokoll:*
      - UDP-alapú szállítási réteg
      - Beépített titkosítás (TLS 1.3)
      - TCP helyett
    ],
    align(left)[
      #figure(
        figures.moq_modules_diagram(),
        caption: "moq-rs komponensek egy részlete",
      )
    ],
  )

  #v(1em)
  *`moq-rs`:*
  - A Media over QUIC (MoQ) specifikáció *Rust* nyelvű implementációja
  - Jelenleg a Cloudflare kezelésében
]

#slide(title: "A probléma")[
  A `moq-rs` egy komplex, elosztott rendszer, rengeteg független komponenssel.

  #v(1em)
  Miért nehéz leírni a hálózat minőségét?
  - *Elosztott működés:* Több független komponens kommunikál
  - *Változó hálózat:* A kapcsolatok és streamek folyamatosan változnak
  - *Titkosítás:* A QUIC forgalom titkosított, nehéz "belehallgatni"

  #v(1em)
  Erre lehet megoldás egy metrikagyűjtési megoldás implementálása.
]

#slide(title: "Miért mérjünk?")[
  Szeretnénk a felhasználónak a lehető legjobb élményt nyújtani.

  #v(1em)
  - *Felhasználói élmény javítása:* Akadozásmentes lejátszás, alacsony késleltetés
  - *Erőforrás-gazdálkodás optimalizálása:* Terheléselosztás, hirtelen kiugrások észlelése
  - *Hibakeresés:* Hol vesznek el a csomagok? Van-e memóriaszivárgás?

  #v(1em)
  A fentiekhez szükséges adatokat mérésekkel kaphatjuk meg.
]

#slide(title: "A kiválasztott metrikák")[
  A fenti célok eléréséhez a gyűjtött adatokat így kategorizálhatjuk:

  - *Hálózati metrikák (QUIC-ből)*
    - RTT, csomagvesztés
    - Pl. ha magas az RTT, akkor késik az adás

  - *Forgalmi metrikák (MoQ-hálózat)*
    - Objektumok száma, aktív feliratkozók
    - Pl. a folyamok népszerűsége alapján lehet optimalizálni a terheléselosztást

  - *Rendszermetrikák*
    - CPU használat, Memóriafoglalás
    - Pl. folyamatosan növő *memóriahasználat* szivárgásra utal.
]

#slide(title: "Tervezés")[
  Hogyan gyűjtsük az adatokat?

  #v(1em)
  *Prometheus:*
  - Pull modell
  - Széleskörű használat
  - Egyszerű integráció (HTTP endpoint)
  - Kisebb erőforrásigény
  - Egyszerűbb használat

  *Alternatíva:* OpenTelemetry (push modell) - rugalmasabb backend szempontból (pl. Prometheus is lehet), de komplexebb
]

#slide(title: "Architektúra")[

  #grid(
    columns: (1fr, 1.5fr),
    column-gutter: 2em,
    align(horizon)[
      - *`moq-metrics` komponens:* Különálló, lazán illeszkedő könyvtár.
      - A `moq-rs`-en belül bármelyik komponens egyszerűen hozzáadhatja
      - Minden komponensen HTTP szervert indít a `/metrics` végponton
      - A Prometheus erről gyűjti be az adatokat
    ],
    align(center + horizon)[
      #figure(
        figures.moq_metrics_arch_diagram(),
        caption: "A mérőrendszer integrációja",
      )
    ],
  )
]

#slide(title: "Implementáció")[

  #grid(
    columns: (1fr, 1fr),
    column-gutter: 2em,
    [
      - Rust nyelv
      - Globális hozzáférés (`GLOBAL_METRICS`) Singleton segítségével
      - automatikus erőforrás-felszabadítás és számlálócsökkentés (RAII-elv)
      - Rust makrók `define_metrics!` a boilerplate kód csökkentésére
    ],
    [
      #figure(
        block(stroke: 1pt, inset: 10pt, radius: 0.4em)[
          #text(size: 18pt)[
            ```rust
            define_metrics! {
              // ...
              objects_sent:
                Counter<u64>,
                "moq_relay_objects_sent",
                "Total objects sent",
              // ...
            }
            ```
          ]
        ],
        caption: "Egy metrika definíciója makróval",
      )
    ],
  )
]

#slide(title: "Kiértékelés")[
  #align(center)[
    #figure(
      image("grafana_dash.png", height: 70%),
      caption: "A megvalósított Grafana dashboard egy részlete",
    )
  ]
]

#slide(title: "Kiértékelés")[
  #align(center)[
    #figure(
      image("namespace_pop.png", width: 80%),
      caption: "A különböző streamek feliratkozóinak eloszlása a hálózatban",
    )
  ]
]

#let summary_content = [
  - Lazán illeszkedő metrikagyűjtési könyvtár a `moq-rs`-hez
  - Prometheus és Grafana használata
  - Valós idejű betekintés a rendszer működésébe

  *Jövőbeli lehetőségek:*
  - Minimális PR az eredeti `moq-rs` projektbe
  - E2E késleltetés mérése időbélyegek hozzáfűzésével
  - További metrikák (pl. cachelés mérése, puffertelítettség).
]

#slide(title: "Összegzés")[
  #summary_content
]

#slide(title: "Összegzés")[
  #summary_content
  #align(center + horizon)[
    #text(size: 32pt, weight: "bold")[Köszönöm a figyelmet!]
  ]
]
