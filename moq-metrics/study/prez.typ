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
  font: "Liberation Sans",
  size: 20pt,
  lang: "hu",
)

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
  #text(size: 32pt, weight: "bold")[Médiaátvitel QUIC felett]

  #v(1em)

  #text(size: 24pt)[Metrikagyűjtési módszerek]

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

#slide(title: "A feladat")[
  A Media over QUIC (MoQ) protokollhoz tartozó `moq-rs` implementáció megfigyelhetőségi (observability) lehetőségeinek feltérképezése és elemzése.

  #v(1em)
  *Célkitűzések:*
  - Mérési pontok azonosítása.
  - Technológiák összehasonlítása (Prometheus vs. OpenTelemetry).
  - Moduláris mérési rendszer implementálása.
  - Vizualizáció (Grafana).
]

#slide(title: "A MoQ-ökoszisztéma")[
  Az architektúra három fő szereplőre épül:

  - *Publisher:* A tartalom előállítója.
  - *Relay:* Közvetítő és gyorsítótárazó csomópont (CDN).
  - *Subscriber:* A tartalom fogyasztója.

  #v(1em)
  #align(center)[
    #rect(width: 80%, height: 6em, fill: luma(240), stroke: (dash: "dashed"), radius: 0.5em, align(center + horizon)[
      *Kép helye: Architektúra diagram*
    ])
  ]
]

#slide(title: "A probléma")[
  A `moq-rs` egy komplex, elosztott rendszer.

  #v(1em)
  *Miért nehéz a hibakeresés?*
  - *Elosztott működés:* Több független komponens kommunikál.
  - *Titkosítás:* A QUIC forgalom titkosított, nehéz "belehallgatni".
  - *Dinamika:* A kapcsolatok és streamek folyamatosan változnak.

  #v(1em)
  Megfelelő eszközök nélkül nehéz megérteni a rendszer viselkedését és teljesítményét.
]

#slide(title: "Tervezés")[
  Hogyan gyűjtsük az adatokat?

  #v(1em)
  *Pull vs. Push modell:*
  - *Választás:* Prometheus (Pull).
  - *Okok:*
    - Széleskörű ipari támogatás.
    - Egyszerű integráció (HTTP endpoint).
    - Kisebb erőforrásigény.

  *Alternatíva:* OpenTelemetry (Push) - komplexebb, de rugalmasabb backend választást tesz lehetővé.
]

#slide(title: "Architektúra")[
  A mérési rendszer felépítése:

  - *`moq-metrics` crate:* Különálló, moduláris könyvtár.
  - *Integráció:* A `moq-transport`, `moq-relay`, `moq-pub` és `moq-sub` komponensek használják.
  - *Exponálás:* Minden komponens saját HTTP szervert indít a `/metrics` végponton.

  #v(1em)
  #align(center)[
    #rect(width: 80%, height: 5em, fill: luma(240), stroke: (dash: "dashed"), radius: 0.5em, align(center + horizon)[
      *Kép helye: Komponens diagram*
    ])
  ]
]

#slide(title: "Implementáció")[
  Rust specifikus megoldások a hatékonyságért.

  #grid(
    columns: (1fr, 1fr),
    column-gutter: 2em,
    [
      *Tervezési minták:*
      - *Singleton:* Globális hozzáférés (`GLOBAL_METRICS`).
      - *RAII:* Automatikus erőforrás-felszabadítás és számláló csökkentés.
    ],
    [
      *Kódgenerálás:*
      - *Makrók:* Deklaratív metrika definíció (`define_metrics!`) a boilerplate kód csökkentésére.
    ],
  )

  #v(1em)
  #align(center)[
    #rect(fill: luma(240), inset: 0.5em, radius: 0.5em)[
      _Kód részlet helye_
    ]
  ]
]

#slide(title: "Metrikák")[
  Három fő kategória a teljes lefedettséghez:

  1. **Forgalom:**
    - Átvitt bájtok és objektumok száma.
    - Publikálók és feliratkozók aktivitása.

  2. **Hálózat:**
    - QUIC RTT (késleltetés).
    - Csomagvesztés és aktív kapcsolatok száma.

  3. **Erőforrás:**
    - CPU és memória használat (folyamat és rendszer szinten).
]

#slide(title: "Eredmények")[
  A Grafana dashboard átfogó képet ad a rendszerről.

  #v(0.5em)
  #align(center)[
    #rect(width: 90%, height: 8em, fill: luma(240), stroke: (dash: "dashed"), radius: 0.5em, align(center + horizon)[
      *Kép helye: Grafana Dashboard screenshot*
    ])
  ]

  Valós időben követhető a sávszélesség, a kapcsolatok száma és a rendszer terhelése.
]

#slide(title: "Eredmények")[
  Konkrét megfigyelések a mérések alapján:

  - *Memóriahasználat:* Korrelációt mutat az aktív kapcsolatok számával.
  - *Hálózati viselkedés:* A terhelés növekedésével hogyan változik az RTT.
  - *Hibakeresés:* Sikerült azonosítani "szivárgó" feliratkozásokat (adatküldés feliratkozó nélkül).

  #v(1em)
  #align(center)[
    #rect(width: 60%, height: 4em, fill: luma(240), stroke: (dash: "dashed"), radius: 0.5em, align(center + horizon)[
      *Kép helye: Részletes grafikon*
    ])
  ]
]

#slide(title: "Összegzés")[
  *Elért eredmények:*
  - Működő, moduláris mérési rendszer a `moq-rs`-hez.
  - Integrált Prometheus és Grafana támogatás.
  - Valós idejű betekintés a rendszer működésébe.

  *Jövőbeli tervek:*
  - Visszavezetés (Pull Request) az eredeti projektbe.
  - E2E késleltetés mérése.
  - További metrikák (pl. puffer telítettség).
]

#slide(title: none)[
  #align(center + horizon)[
    #text(size: 32pt, weight: "bold")[Köszönöm a figyelmet!]
  ]
]
