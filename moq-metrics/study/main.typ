#set text(
  font: "New Computer Modern",
  size: 12pt,
  lang: "hu",
)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  numbering: "1",
)

#set heading(numbering: "1.")

// cover page
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
    A féléves munka célja a Media over QUIC (MoQ) protokollhoz tartozó `moq-rs` implementáció megfigyelhetőségi (observability) lehetőségeinek feltérképezése és elemzése. A feladat magában foglalja a különböző metrikagyűjtési és vizualizációs technológiák (pl. Prometheus, OpenTelemetry) összehasonlító vizsgálatát, valamint a `moq-rs` architektúrájához leginkább illeszkedő megoldás kiválasztását. A hallgatónak meg kell vizsgálnia, hogyan gyűjthetők hatékonyan rendszerszintű és alkalmazásszintű adatok elosztott környezetben.
  ]

  #v(1fr)

  #text(size: 14pt)[
    *Tanév:* 2025/2026. tanév, I. félév
  ]
]

#pagebreak()

#set page(
  header: align(right)[
    Horváth Benedek \ `D86EP7`
  ],
)

// table of contents
#outline(title: "Tartalomjegyzék", indent: auto)

#pagebreak()

= Bevezetés

A Media over QUIC (MoQ)...

== MoQ-hálózatok
== Mérési lehetőségek
== Célkitűzés

= Háttér

== Adatgyűjtési módszerek
== A MoQ ökoszisztéma
== Használt technológiák
=== Prometheus vs. OpenTelemetry
=== Rust könyvtárak

= Architektúra és tervezés

== A `moq-metrics` komponens
== Adatgyűjtési stratégiák
=== A "QUIC Loop" dilemma
== Rendszermetrikák

= Megvalósítás

== Metrikatípusok
== Makrók
== Használat
=== Relay
=== Publisher és Subscriber
== End-to-End (E2E) Metrikák
=== Fejlesztési nehézségek

= Vizualizáció és elemzés

== Grafana dashboard tervezése
== Eredmények értelmezése

= Fejlesztési lehetőségek és összegzés

== Skálázhatóság, QUIC-dilemma
== Fejlett metrikák
== Upstreaming
== Összegzés
