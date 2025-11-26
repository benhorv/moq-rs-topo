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
#align(center + horizon)[
  #text(size: 24pt, weight: "bold")[
    Metrikagyűjtési lehetőségek vizsgálata Media over QUIC környezetben
  ]

  #v(2cm)

  #text(size: 16pt)[
    Önálló laboratórium 2. - Beszámoló
  ]

  #v(4cm)

  #text(size: 14pt)[
    Horváth Benedek \
    `D86EP7`
  ]

  #v(1cm)

  #text(size: 14pt)[
    #datetime.today().display("[year]. [month]. [day].")
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
