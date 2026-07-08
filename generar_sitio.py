# -*- coding: utf-8 -*-
"""
Genera index.html del caso de estudio "Agente Experto Aleatorio" (Instituto Quant).
Lee datos/resultados.json y datos/sweetspot.json (opcional) y produce una pagina
estatica autocontenida lista para Vercel.

Uso: python generar_sitio.py
"""
import json
import os
from datetime import date

AQUI = os.path.dirname(os.path.abspath(__file__))

VERSIONES = [
    {"version": "v1", "rasgo": "Aleatorio puro", "archivo": "AgenteExperto_Aleatorio_v1.mq5",
     "que": "Abre compra o venta al azar. Sin stop loss, sin take profit, sin nada.",
     "leccion": "Es la linea base: un robot sin gestion de riesgo es una moneda al aire con comisiones en contra."},
    {"version": "v2", "rasgo": "SL/TP fijos", "archivo": "AgenteExperto_Aleatorio_v2_SLTP.mq5",
     "que": "Misma entrada aleatoria + Stop Loss del 1% del saldo y Take Profit del 2% del saldo (riesgo:beneficio 1:2).",
     "leccion": "Con RB 1:2 solo gana ~34% de las veces y el neto oscila alrededor de cero: la gestion fija controla el dano pero no crea ventaja."},
    {"version": "v3", "rasgo": "Trailing ATR", "archivo": "AgenteExperto_Aleatorio_v3_ATRTrailing.mq5",
     "que": "El SL persigue al precio a distancia ATR(14) x 2. La salida se vuelve dinamica.",
     "leccion": "En M15 el trailing corto multiplica los trades (~2.400 en 6 meses) y el spread se come la cuenta: morir por mil cortes."},
    {"version": "v4", "rasgo": "Una posicion perpetua", "archivo": "AgenteExperto_Aleatorio_v4_UnaPosicion.mq5",
     "que": "Siempre hay UNA posicion abierta (SL 1% del precio, sin TP); al saltar el SL reabre con direccion aleatoria.",
     "leccion": "Version de laboratorio para estudiar observabilidad y despliegue; corrio en demo y se apago para dar paso a v5-v7."},
    {"version": "v5", "rasgo": "4 variantes de trailing", "archivo": "AgenteExperto_Aleatorio_v5_TrailingVariantes.mq5",
     "que": "Un input elige el trailing: ATR, % fijo, minimo/maximo de N velas (Donchian) o escalonado (breakeven + tramos).",
     "leccion": "Tres variantes pierden; solo el trailing ESCALONADO sobrevive (+142/+179 USD): asegurar por tramos deja correr sin regalar todo al ruido."},
    {"version": "v6", "rasgo": "Piramidacion", "archivo": "AgenteExperto_Aleatorio_v6_Piramidacion.mq5",
     "que": "Posicion base aleatoria y suma otra igual cada vez que el precio avanza 0.5% a favor (hasta 3 niveles).",
     "leccion": "Pocos trades (12-27), profit factor alto (2.8-7.1): los ciclos perdedores mueren rapido y los ganadores se apilan."},
    {"version": "v7", "rasgo": "Piramidacion configurable", "archivo": "AgenteExperto_Aleatorio_v7_PiramidacionNiveles.mq5",
     "que": "Niveles, paso, escalado de lote y trailing comun configurables para barrer configuraciones en el tester.",
     "leccion": "8 niveles + paso 0.5% + trailing comun gano (+1.446 a +1.865 USD en 3 semillas). El MISMO robot con paso 1.0% QUEBRO la cuenta: en piramidacion, el paso es vida o muerte."},
]

BUGS = [
    {"id": "BUG-01", "titulo": "EA dormido sin ticks",
     "detalle": "Toda la logica colgada de OnTick; sin ticks el robot no respira. Solucion: EventSetTimer(5) y correr la logica tambien en OnTimer."},
    {"id": "BUG-02", "titulo": "EA invisible (logs buffeados)",
     "detalle": "MT5 buffea el log de expertos 8+ minutos: el silencio no es diagnostico. Solucion: el EA escribe un archivo de estado en MQL5\\Files cada ciclo."},
    {"id": "BUG-03", "titulo": "Rafaga de reintentos al rechazo",
     "detalle": "Sin throttle, cada tick reintenta la orden rechazada. Solucion: guardar la hora del ultimo intento y esperar N segundos."},
    {"id": "BUG-04", "titulo": "Magic number compartido",
     "detalle": "Dos versiones con el mismo magic se roban las posiciones en una cuenta hedging. Solucion: magic unico por version (fecha AAAAMMDD + numero)."},
    {"id": "BUG-05", "titulo": "Exito falso al abrir posicion",
     "detalle": "trade.Buy() devuelve true si la orden se ENVIO, no si se ejecuto. Solucion: verificar ademas ResultRetcode()==TRADE_RETCODE_DONE."},
    {"id": "BUG-06", "titulo": "Acentos dentro del codigo MQL5",
     "detalle": "Los caracteres acentuados se corrompen entre encodings del editor. Regla: comentarios en espanol sin acentos."},
    {"id": "BUG-07", "titulo": "Backtests no reproducibles",
     "detalle": "MathSrand(GetTickCount()) hace cada corrida distinta. Solucion: input SemillaAleatoria (0=reloj en vivo; fija en el tester) y comparar VARIAS semillas."},
    {"id": "BUG-08", "titulo": "Bombardeo de PositionModify",
     "detalle": "El trailing movia el SL por mejoras de centavos en cada tick. Solucion: paso minimo de mejora (input MejoraMinPuntos)."},
    {"id": "BUG-09", "titulo": "Trailing de venta sin SL previo",
     "detalle": "La condicion nuevoSL < slActual con slActual=0 nunca es cierta: el trailing jamas arrancaba. Solucion: tratar slActual==0 explicitamente y simetrico."},
    {"id": "BUG-10", "titulo": "El despliegue por INI no sobrevive reinicios",
     "detalle": "El grafico que crea [StartUp] Expert= es temporal: no queda en el perfil del terminal. Un reinicio 'apaga' el robot en silencio."},
    {"id": "BUG-11", "titulo": "retcode 10027 al operar via API",
     "detalle": "El boton global AlgoTrading apagado bloquea ordenes externas. Verificar terminal_info().trade_allowed antes de diagnosticar otra cosa."},
    {"id": "BUG-12", "titulo": "Kill switch confiable",
     "detalle": "Para garantizar que un EA no cargue: mover su .ex5 a una carpeta _apagados. Ni el perfil ni un INI pueden revivirlo."},
    {"id": "BUG-13", "titulo": "FactorLote<1 colapsa al lote minimo",
     "detalle": "Con lote base 0.01 (el minimo), el escalado decreciente pide 0.007 y la normalizacion lo devuelve a 0.01: la piramide decreciente resulta identica a la plana."},
    {"id": "BUG-14", "titulo": "El terminal a veces no cierra tras el tester",
     "detalle": "Con ShutdownTerminal=1 la simulacion termina pero el terminal queda vivo sin escribir el reporte (flaky, 1 de 25). Mitigacion: timeout + reintento."},
]


def num(x, campo=None):
    if isinstance(x, dict):
        return x.get("pct" if campo == "pct" else "valor")
    return x


def cargar(nombre):
    ruta = os.path.join(AQUI, "datos", nombre)
    if os.path.exists(ruta):
        with open(ruta, encoding="utf-8") as f:
            return json.load(f)
    return {}


def filas_backtests(resultados):
    filas = []
    for tag, r in sorted(resultados.items()):
        filas.append({
            "tag": tag,
            "version": tag.split("_", 1)[0],
            "parametros": r.get("parametros", ""),
            "neto": num(r.get("beneficio_neto")),
            "profit_factor": num(r.get("profit_factor")),
            "dd_max_pct": num(r.get("dd_max_balance"), "pct"),
            "trades": num(r.get("trades")),
            "sharpe": num(r.get("sharpe")),
        })
    return filas


PLANTILLA = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Caso de estudio: el Agente Experto Aleatorio — Instituto Quant</title>
<meta name="description" content="Que pasa cuando un robot entra al mercado al azar y solo cambia la gestion de riesgo. 7 versiones, 50 backtests, 14 bugs documentados.">
<style>
:root {
  --surface-1:#fcfcfb; --plane:#f9f9f7; --ink-1:#0b0b0b; --ink-2:#52514e;
  --muted:#898781; --grid:#e1e0d9; --axis:#c3c2b7; --border:rgba(11,11,11,.10);
  --pos:#2a78d6; --neg:#e34948; --good-text:#006300; --bad-text:#a02c2c; --chip:#f0efec;
}
@media (prefers-color-scheme: dark) { :root {
  --surface-1:#1a1a19; --plane:#0d0d0d; --ink-1:#fff; --ink-2:#c3c2b7;
  --muted:#898781; --grid:#2c2c2a; --axis:#383835; --border:rgba(255,255,255,.10);
  --pos:#3987e5; --neg:#e66767; --good-text:#0ca30c; --bad-text:#e66767; --chip:#383835; } }
:root[data-theme="light"] {
  --surface-1:#fcfcfb; --plane:#f9f9f7; --ink-1:#0b0b0b; --ink-2:#52514e;
  --muted:#898781; --grid:#e1e0d9; --axis:#c3c2b7; --border:rgba(11,11,11,.10);
  --pos:#2a78d6; --neg:#e34948; --good-text:#006300; --bad-text:#a02c2c; --chip:#f0efec; }
:root[data-theme="dark"] {
  --surface-1:#1a1a19; --plane:#0d0d0d; --ink-1:#fff; --ink-2:#c3c2b7;
  --muted:#898781; --grid:#2c2c2a; --axis:#383835; --border:rgba(255,255,255,.10);
  --pos:#3987e5; --neg:#e66767; --good-text:#0ca30c; --bad-text:#e66767; --chip:#383835; }
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body { margin:0; background:var(--plane); color:var(--ink-1);
  font-family:system-ui,-apple-system,"Segoe UI",sans-serif; font-size:15px; line-height:1.55; }
.wrap { max-width:1080px; margin:0 auto; padding:0 20px 80px; }
.topnav { position:sticky; top:0; z-index:5; background:var(--plane); border-bottom:1px solid var(--grid);
  display:flex; gap:2px; overflow-x:auto; padding:0 8px; }
.topnav a { color:var(--ink-2); text-decoration:none; padding:12px 12px; font-size:13.5px; white-space:nowrap; }
.topnav a:hover { color:var(--ink-1); }
.topnav .spacer { flex:1; }
button.theme { background:none; color:var(--ink-2); border:1px solid var(--border);
  border-radius:8px; margin:8px 4px; padding:2px 12px; cursor:pointer; font-size:12.5px; }
.hero { padding:56px 0 28px; }
.hero .kicker { color:var(--pos); font-weight:650; font-size:13px; letter-spacing:.06em; text-transform:uppercase; }
h1 { font-size:34px; line-height:1.15; margin:10px 0 14px; max-width:820px; }
.hero p.lede { font-size:17px; color:var(--ink-2); max-width:760px; margin:0 0 18px; }
h2 { font-size:23px; margin:48px 0 6px; }
h2 + .sub { margin-bottom:18px; }
.sub { color:var(--ink-2); font-size:13.5px; }
.card { background:var(--surface-1); border:1px solid var(--border); border-radius:12px;
  padding:18px 20px; margin:14px 0; }
.tiles { display:grid; grid-template-columns:repeat(auto-fit,minmax(160px,1fr)); gap:12px; margin:18px 0; }
.tile { background:var(--surface-1); border:1px solid var(--border); border-radius:12px; padding:14px 16px; }
.tile .k { color:var(--ink-2); font-size:12px; }
.tile .v { font-size:23px; font-weight:650; margin-top:2px; }
.tile .d { color:var(--muted); font-size:12px; margin-top:2px; }
.timeline { border-left:2px solid var(--grid); margin-left:8px; padding-left:24px; }
.tl { position:relative; margin-bottom:22px; }
.tl::before { content:""; position:absolute; left:-31px; top:6px; width:12px; height:12px;
  border-radius:50%; background:var(--pos); border:2px solid var(--plane); }
.tl h3 { margin:0 0 2px; font-size:16.5px; }
.tl .files { margin:4px 0; }
.tl code { background:var(--chip); border-radius:6px; padding:1px 7px; font-size:12.5px; }
.tl p { margin:6px 0; }
.tl .leccion { color:var(--ink-2); border-left:3px solid var(--pos); padding-left:10px; font-size:14px; }
.tblwrap { overflow-x:auto; }
table { border-collapse:collapse; width:100%; }
th,td { text-align:left; padding:7px 10px; border-bottom:1px solid var(--grid); vertical-align:top; font-size:13.5px; }
th { color:var(--ink-2); font-weight:600; font-size:12.5px; cursor:pointer; white-space:nowrap; user-select:none; }
td.num,th.num { text-align:right; font-variant-numeric:tabular-nums; white-space:nowrap; }
tr:hover td { background:color-mix(in srgb, var(--pos) 6%, transparent); }
.chip { background:var(--chip); border-radius:999px; padding:1px 9px; font-size:12px; color:var(--ink-2); white-space:nowrap; }
.good { color:var(--good-text); } .bad { color:var(--bad-text); }
input.filtro { width:100%; max-width:340px; margin:6px 0 12px; padding:8px 12px;
  background:var(--surface-1); color:var(--ink-1); border:1px solid var(--border); border-radius:8px; font-size:14px; }
.chart { padding:6px 0; }
.row { display:grid; grid-template-columns:190px 1fr 90px; align-items:center; gap:10px; padding:3px 0; }
.row .lbl { color:var(--ink-2); font-size:12.5px; text-align:right; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.row .val { font-variant-numeric:tabular-nums; font-size:12.5px; }
.barbox { position:relative; height:16px; }
.zero { position:absolute; top:-2px; bottom:-2px; width:1px; background:var(--axis); left:35%; }
.bar { position:absolute; top:2px; height:12px; border-radius:0 4px 4px 0; }
.bar.neg { border-radius:4px 0 0 4px; }
.tooltip { position:fixed; pointer-events:none; z-index:10; display:none; background:var(--surface-1);
  color:var(--ink-1); border:1px solid var(--border); border-radius:8px; padding:8px 10px;
  font-size:12.5px; box-shadow:0 4px 14px rgba(0,0,0,.18); max-width:280px; }
.heat { border-collapse:collapse; }
.heat td,.heat th { border:2px solid var(--surface-1); text-align:center; padding:10px 14px; font-variant-numeric:tabular-nums; }
.legend { display:flex; gap:16px; align-items:center; color:var(--ink-2); font-size:12.5px; margin-top:8px; flex-wrap:wrap; }
.sw { display:inline-block; width:12px; height:12px; border-radius:3px; margin-right:5px; vertical-align:-1px; }
.grid2 { display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:12px; }
.bugcard h4 { margin:0 0 4px; font-size:14.5px; }
.bugcard p { margin:0; color:var(--ink-2); font-size:13.5px; }
ol.metodo li { margin-bottom:8px; }
.warn { border-left:3px solid #ec835a; padding:10px 14px; background:var(--surface-1);
  border-radius:0 10px 10px 0; margin:16px 0; }
footer { margin-top:56px; color:var(--muted); font-size:12.5px; border-top:1px solid var(--grid); padding-top:16px; }
a { color:var(--pos); }
</style>
</head>
<body>
<div class="topnav">
  <a href="#historia">La historia</a>
  <a href="#resultados">Resultados</a>
  <a href="#bugs">Bugs</a>
  <a href="#sweetspot">Sweet spot</a>
  <a href="#metodologia">Metodología</a>
  <a href="#descargas">Descargas</a>
  <span class="spacer"></span>
  <button class="theme" onclick="cambiarTema()">Claro / Oscuro</button>
</div>
<div class="wrap">

<div class="hero">
  <div class="kicker">Instituto Quant · Caso de estudio</div>
  <h1>El robot que entra al azar: ¿puede la gestión del riesgo salvarlo?</h1>
  <p class="lede">Construimos un Expert Advisor de MetaTrader 5 que decide compra o venta
  <b>lanzando una moneda</b>. Después le cambiamos únicamente la <b>gestión de la posición</b>
  a lo largo de 7 versiones: sin nada, SL/TP fijos, trailing stops, piramidación.
  Esto es lo que pasó en __N_RUNS__ backtests sobre BTCUSD, con los __N_BUGS__ bugs
  que nos encontramos en el camino documentados para que no los repitas.</p>
  <div class="tiles" id="tiles"></div>
</div>

<h2 id="historia">La historia, versión a versión</h2>
<div class="sub">La entrada nunca cambia (aleatoria); solo cambia cómo se gestiona lo que pasa después.</div>
<div class="timeline">__TIMELINE__</div>

<h2 id="resultados">Resultados comparativos</h2>
<div class="sub">BTCUSD · depósito 1.000 USD · 2026.01.01 → 2026.07.07 · M15 · modelo OHLC de 1 minuto ·
varias semillas por versión (la semilla fija la secuencia de decisiones aleatorias).</div>
<div class="card">
  <h3 style="margin:0 0 4px">Beneficio neto por corrida (USD)</h3>
  <div class="sub" style="margin-bottom:10px">Pasa el cursor sobre una barra para el detalle.</div>
  <div class="chart" id="chart"></div>
  <div class="legend"><span><span class="sw" style="background:var(--pos)"></span>Beneficio</span>
  <span><span class="sw" style="background:var(--neg)"></span>Pérdida</span></div>
</div>
<input class="filtro" id="filtro_bt" placeholder="Filtrar corridas (v2, v7, esc, semilla...)" oninput="pintarBacktests()">
<div class="card tblwrap"><table id="tabla_bt"></table></div>

<h2 id="bugs">La batería de bugs</h2>
<div class="sub">Cada bug costó tiempo real. Documentarlos convierte el error en conocimiento reutilizable —
esta es la mitad "ingeniería" del trading algorítmico que casi nadie enseña.</div>
<div class="grid2">__BUGS__</div>

<h2 id="sweetspot">El examen de sweet spot</h2>
<div class="sub">Al modelo ganador se le busca su hábitat: ¿con qué tamaño de cuenta y en qué temporalidad rinde mejor?</div>
<div id="ss_body"></div>

<h2 id="metodologia">Metodología</h2>
<div class="card"><ol class="metodo">
<li><b>Un solo cambio por versión.</b> La entrada aleatoria se mantiene constante como grupo de control; solo se toca la gestión.</li>
<li><b>Backtests headless reproducibles.</b> El Strategy Tester de MT5 se lanza por línea de comandos con un archivo INI por corrida (símbolo, periodo, fechas, depósito, reporte) y la semilla del generador aleatorio se fija con un input (<code>SemillaAleatoria</code>).</li>
<li><b>Varias semillas por configuración.</b> Con entrada aleatoria, una corrida es una anécdota; comparamos la distribución de 2-3 semillas.</li>
<li><b>Métricas extraídas automáticamente</b> de los reportes (beneficio neto, profit factor, drawdown máximo, trades, Sharpe) a <code>datos/resultados.json</code>, que alimenta esta página.</li>
<li><b>Bugs registrados en el momento</b> en la batería (docs/BUGS.md) con síntoma, causa y solución.</li>
<li><b>Sweet spot al final:</b> el ganador se somete a la matriz depósito × temporalidad para ubicar dónde operarlo.</li>
</ol></div>
<div class="warn"><b>Advertencia honesta (léela dos veces):</b> estos resultados corresponden a UN periodo
(ene-jul 2026) en UN instrumento (BTCUSD) que estuvo en tendencia. Una estrategia de entrada aleatoria con
piramidación y trailing común es, en la práctica, un seguidor de tendencia: en mercados laterales largos su
resultado puede invertirse. El objetivo del caso es didáctico —aislar el efecto de la GESTIÓN—, no venderte
un sistema rentable. Todo se corrió en cuenta demo. Nada de esto es asesoría financiera.</div>

<h2 id="descargas">Código fuente y datos</h2>
<div class="card">
<p>Todo el material está en este mismo repositorio:</p>
<ul>
<li><code>src/</code> — los 7 Expert Advisors en MQL5, comentados en español para estudiar línea a línea.</li>
<li><code>datos/resultados.json</code> — métricas de todas las corridas · <code>datos/sweetspot.json</code> — la matriz del examen final.</li>
<li><code>docs/BUGS.md</code> — la batería completa de bugs con detalle técnico.</li>
</ul>
<p>Para reproducirlo necesitas MetaTrader 5 (cualquier broker con BTCUSD), compilar los .mq5 con MetaEditor
y usar el Strategy Tester (los parámetros exactos de cada corrida están en la tabla de resultados).</p>
</div>

<footer>Instituto Quant · Caso de estudio generado el __FECHA__ · Cuenta demo · Material educativo, no es asesoría financiera.</footer>
</div>
<div class="tooltip" id="tt"></div>

<script>
const DATOS = __DATA_JSON__;

function cambiarTema() {
  const r = document.documentElement;
  const oscuro = (r.dataset.theme === 'dark') ||
    (!r.dataset.theme && matchMedia('(prefers-color-scheme: dark)').matches);
  r.dataset.theme = oscuro ? 'light' : 'dark';
}
const fmt = n => (n === null || n === undefined || isNaN(n)) ? '-' :
  Number(n).toLocaleString('es-CO', {maximumFractionDigits: 2});
const clase = n => n > 0 ? 'good' : (n < 0 ? 'bad' : '');

// tiles del hero
(function() {
  const bts = DATOS.backtests;
  const netos = bts.map(b => b.neto).filter(n => n !== null && !isNaN(n));
  const mejor = bts.reduce((a, b) => (b.neto ?? -1e9) > (a?.neto ?? -1e9) ? b : a, null);
  const peor = bts.reduce((a, b) => (b.neto ?? 1e9) < (a?.neto ?? 1e9) ? b : a, null);
  const t = [
    {k: 'Versiones del robot', v: '7', d: 'v1 → v7'},
    {k: 'Backtests', v: bts.length, d: 'BTCUSD, 6 meses'},
    {k: 'Mejor corrida', v: fmt(mejor?.neto) + ' USD', d: mejor?.tag || ''},
    {k: 'Peor corrida', v: fmt(peor?.neto) + ' USD', d: (peor?.tag || '') + ' (cuenta quebrada)'},
    {k: 'Bugs documentados', v: DATOS.bugs.length, d: 'batería de conocimiento'},
  ];
  document.getElementById('tiles').innerHTML = t.map(x =>
    `<div class="tile"><div class="k">${x.k}</div><div class="v">${x.v}</div><div class="d">${x.d}</div></div>`).join('');
})();

// grafico de barras divergente (cero al 35% del ancho: hay mas rango positivo)
(function() {
  const bts = [...DATOS.backtests].filter(b => b.neto !== null && !isNaN(b.neto))
    .sort((a, b) => b.neto - a.neto);
  const maxPos = Math.max(...bts.map(b => b.neto), 1);
  const maxNeg = Math.max(...bts.map(b => -b.neto), 1);
  const tt = document.getElementById('tt');
  document.getElementById('chart').innerHTML = bts.map((b, i) => {
    const pos = b.neto >= 0;
    const w = pos ? (b.neto / maxPos * 63) : (-b.neto / maxNeg * 33);
    const style = pos ? `left:35%;width:${w}%` : `left:${35 - w}%;width:${w}%`;
    return `<div class="row" data-i="${i}">
      <div class="lbl">${b.tag}</div>
      <div class="barbox"><div class="zero"></div>
        <div class="bar ${pos ? '' : 'neg'}" style="${style};background:var(--${pos ? 'pos' : 'neg'})"></div></div>
      <div class="val ${clase(b.neto)}">${fmt(b.neto)}</div>
    </div>`;
  }).join('');
  const lista = bts;
  document.querySelectorAll('.row').forEach(r => {
    const b = lista[+r.dataset.i];
    r.onmousemove = e => {
      tt.style.display = 'block';
      tt.style.left = Math.min(e.clientX + 14, innerWidth - 300) + 'px';
      tt.style.top = (e.clientY + 14) + 'px';
      tt.innerHTML = `<b>${b.tag}</b><br>Neto: ${fmt(b.neto)} USD · PF: ${fmt(b.profit_factor)}<br>` +
        `DD máx: ${fmt(b.dd_max_pct)}% · Trades: ${fmt(b.trades)}<br>` +
        `<span style="color:var(--muted)">${(b.parametros || '').slice(0, 110)}</span>`;
    };
    r.onmouseleave = () => tt.style.display = 'none';
  });
})();

// tabla de backtests
let ordenCol = 'neto', ordenAsc = false;
function pintarBacktests() {
  const q = (document.getElementById('filtro_bt').value || '').toLowerCase();
  const cols = [
    ['tag', 'Corrida', false], ['version', 'Ver.', false], ['neto', 'Neto USD', true],
    ['profit_factor', 'PF', true], ['dd_max_pct', 'DD máx %', true],
    ['trades', 'Trades', true], ['sharpe', 'Sharpe', true], ['parametros', 'Parámetros', false],
  ];
  let filas = DATOS.backtests.filter(b =>
    !q || (b.tag + ' ' + b.version + ' ' + (b.parametros || '')).toLowerCase().includes(q));
  filas.sort((a, b) => {
    const x = a[ordenCol], y = b[ordenCol];
    if (x === y) return 0;
    if (x === null || x === undefined) return 1;
    if (y === null || y === undefined) return -1;
    return (x < y ? -1 : 1) * (ordenAsc ? 1 : -1);
  });
  const th = cols.map(([k, t, num]) =>
    `<th class="${num ? 'num' : ''}" onclick="ordenar('${k}')">${t}${ordenCol === k ? (ordenAsc ? ' &#9650;' : ' &#9660;') : ''}</th>`).join('');
  const tr = filas.map(b => `<tr>
    <td>${b.tag}</td><td>${b.version}</td>
    <td class="num ${clase(b.neto)}">${fmt(b.neto)}</td>
    <td class="num">${fmt(b.profit_factor)}</td>
    <td class="num">${fmt(b.dd_max_pct)}</td>
    <td class="num">${fmt(b.trades)}</td>
    <td class="num">${fmt(b.sharpe)}</td>
    <td class="sub">${b.parametros || ''}</td>
  </tr>`).join('');
  document.getElementById('tabla_bt').innerHTML = `<tr>${th}</tr>${tr}`;
}
function ordenar(k) { if (ordenCol === k) ordenAsc = !ordenAsc; else { ordenCol = k; ordenAsc = false; } pintarBacktests(); }
pintarBacktests();

// sweet spot
(function() {
  const ss = DATOS.sweetspot;
  const cont = document.getElementById('ss_body');
  if (!ss || !ss.corridas || !ss.corridas.length) {
    cont.innerHTML = '<div class="card sub">Los resultados del examen de sweet spot se publican en esta sección.</div>';
    return;
  }
  const deps = [...new Set(ss.corridas.map(c => c.deposito))].sort((a, b) => a - b);
  const pers = [...new Set(ss.corridas.map(c => c.periodo))];
  const mapa = {};
  ss.corridas.forEach(c => mapa[c.deposito + '|' + c.periodo] = c);
  const maxAbs = Math.max(...ss.corridas.map(c => Math.abs(c.neto_pct ?? 0)), 1);
  const celda = c => {
    if (!c) return '<td class="sub">-</td>';
    const v = c.neto_pct ?? 0;
    const alfa = Math.min(Math.abs(v) / maxAbs, 1) * 0.85 + 0.08;
    const cv = v >= 0 ? 'var(--pos)' : 'var(--neg)';
    return `<td style="background:color-mix(in srgb, ${cv} ${Math.round(alfa * 100)}%, var(--surface-1))">` +
      `<b>${fmt(v)}%</b><br><span class="sub">PF ${fmt(c.profit_factor)} · DD ${fmt(c.dd_max_pct)}%</span></td>`;
  };
  cont.innerHTML = `<div class="card">
    <h3 style="margin:0 0 4px">${ss.titulo || 'Sweet spot'}</h3>
    <div class="sub" style="margin-bottom:10px">${ss.subtitulo || ''} · valor = beneficio neto como % del depósito</div>
    <div class="tblwrap"><table class="heat">
      <tr><th>Depósito \\ TF</th>${pers.map(p => `<th>${p}</th>`).join('')}</tr>
      ${deps.map(d => `<tr><th>${fmt(d)} USD</th>${pers.map(p => celda(mapa[d + '|' + p])).join('')}</tr>`).join('')}
    </table></div>
    <div class="legend"><span><span class="sw" style="background:var(--pos)"></span>% beneficio (más intenso = mayor)</span>
      <span><span class="sw" style="background:var(--neg)"></span>% pérdida</span></div>
    ${ss.conclusion ? `<p style="margin-top:12px"><b>Conclusión:</b> ${ss.conclusion}</p>` : ''}
  </div>`;
})();
</script>
</body>
</html>
"""


def bloque_timeline():
    partes = []
    for v in VERSIONES:
        partes.append(
            f'<div class="tl"><h3>{v["version"]} · {v["rasgo"]}</h3>'
            f'<div class="files"><code>src/{v["archivo"]}</code></div>'
            f'<p>{v["que"]}</p>'
            f'<p class="leccion">{v["leccion"]}</p></div>'
        )
    return "\n".join(partes)


def bloque_bugs():
    partes = []
    for b in BUGS:
        partes.append(
            f'<div class="card bugcard"><h4><span class="chip">{b["id"]}</span> {b["titulo"]}</h4>'
            f'<p>{b["detalle"]}</p></div>'
        )
    return "\n".join(partes)


def main():
    resultados = cargar("resultados.json")
    sweetspot = cargar("sweetspot.json")
    backtests = [b for b in filas_backtests(resultados) if not b["tag"].startswith("ss_")]

    datos = {"backtests": backtests, "bugs": BUGS, "sweetspot": sweetspot or None}
    html = (PLANTILLA
            .replace("__DATA_JSON__", json.dumps(datos, ensure_ascii=False))
            .replace("__TIMELINE__", bloque_timeline())
            .replace("__BUGS__", bloque_bugs())
            .replace("__N_RUNS__", str(len(backtests)))
            .replace("__N_BUGS__", str(len(BUGS)))
            .replace("__FECHA__", date.today().isoformat()))

    salida = os.path.join(AQUI, "index.html")
    with open(salida, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"index.html generado ({len(backtests)} corridas, sweetspot={'si' if sweetspot else 'no'})")


if __name__ == "__main__":
    main()
