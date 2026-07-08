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
<meta name="description" content="Que pasa cuando un robot entra al mercado al azar y solo cambia la gestion de riesgo. 7 versiones, __N_TOTAL__ backtests (__N_COMP__ comparativos + __N_SS__ de sweet spot), __N_BUGS__ bugs documentados.">
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
  Esto es lo que pasó en __N_TOTAL__ backtests sobre BTCUSD — __N_COMP__ comparativos
  entre versiones y __N_SS__ del examen de sweet spot del ganador — con los __N_BUGS__
  bugs que nos encontramos en el camino documentados para que no los repitas.</p>
  <div class="tiles">__TILES__</div>
</div>

<h2 id="historia">La historia, versión a versión</h2>
<div class="sub">La entrada nunca cambia (aleatoria); solo cambia cómo se gestiona lo que pasa después.</div>
<div class="timeline">__TIMELINE__</div>
<div class="card sub"><b>Nota metodológica:</b> v2, v3 y v5 calculan el Stop Loss como % del
<b>saldo</b> (riesgo monetario fijo por operación); v4, v6 y v7 lo calculan como % del
<b>precio</b> de entrada (distancia proporcional al mercado, necesaria para que cada nivel de
una pirámide gestione su propia entrada). El cambio de base es deliberado y por eso se
explicita: dentro de cada comparación (variantes de trailing en v5, configuraciones en v7)
la base de cálculo no cambia.</div>

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
<div class="card tblwrap"><table id="tabla_bt">__TABLA_BT__</table></div>

<h2 id="bugs">La batería de bugs</h2>
<div class="sub">Cada bug costó tiempo real. Documentarlos convierte el error en conocimiento reutilizable —
esta es la mitad "ingeniería" del trading algorítmico que casi nadie enseña.</div>
<div class="grid2">__BUGS__</div>

<h2 id="sweetspot">El examen de sweet spot</h2>
<div class="sub">Al modelo ganador se le busca su hábitat: ¿con qué tamaño de cuenta y en qué temporalidad rinde mejor?</div>
__SWEETSPOT__

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

<h2 id="descargas">Llévate la base de conocimiento a tu proyecto</h2>
<div class="card" style="border-color:var(--pos)">
<h3 style="margin:0 0 6px">📦 Base de conocimiento completa (ZIP, ~5 MB)</h3>
<p style="margin:6px 0">Una carpeta lista para soltar dentro de TU proyecto: batería de bugs, plantilla MQL5
validada, aprendizajes del entorno, metodología de backtests, los 7 EAs, los datos en JSON y los
<b>__N_TOTAL__ reportes completos del Strategy Tester</b> con sus curvas (los adjuntos). Incluye un
<code>CLAUDE.md</code> para que tu asistente de IA (Claude Code, Cursor...) la use como contexto
automáticamente, y un <code>INSTRUCTIVO.md</code> paso a paso.</p>
<p style="margin:12px 0"><a href="descargas/base_conocimiento_agente_experto.zip" download
  style="display:inline-block;background:var(--pos);color:#fff;text-decoration:none;border-radius:8px;padding:10px 18px;font-weight:600">
  Descargar base_conocimiento_agente_experto.zip</a></p>
<p style="margin:6px 0"><b>Cómo usarla (resumen del instructivo):</b></p>
<ol style="margin:6px 0">
<li>Descarga y descomprime el ZIP.</li>
<li>Copia la carpeta <code>base_conocimiento/</code> dentro de la carpeta de tu proyecto.</li>
<li>Con IA: si no tienes <code>CLAUDE.md</code>, copia el del paquete a la raíz de tu proyecto;
si ya tienes, añádele la línea <i>"Antes de escribir o depurar un EA, lee base_conocimiento/CLAUDE.md
y docs/BUGS.md"</i>.</li>
<li>Sin IA: sigue el orden de lectura del <code>INSTRUCTIVO.md</code> (aprendizajes → bugs → plantilla → src).</li>
</ol>
</div>
<div class="card">
<p>También puedes explorar el material suelto en este repositorio:</p>
<ul>
<li><code>base_conocimiento/</code> — el paquete navegable (sin los reportes; esos van en el ZIP).</li>
<li><code>src/</code> — los 7 Expert Advisors en MQL5, comentados en español para estudiar línea a línea.</li>
<li><code>datos/resultados.json</code> — métricas de todas las corridas · <code>datos/sweetspot.json</code> — la matriz del examen final.</li>
<li><code>docs/BUGS.md</code> — la batería completa de bugs con detalle técnico.</li>
</ul>
<p>Para reproducirlo necesitas MetaTrader 5 (cualquier broker con BTCUSD), compilar los .mq5 con MetaEditor
y usar el Strategy Tester (los parámetros exactos de cada corrida están en la tabla de resultados).</p>
</div>

<div class="card" style="margin-top:40px;text-align:center">
<p style="margin:0 0 6px;font-size:16px"><b>Este caso se construyó en vivo en la Sesión 9 de Instituto Quant.</b></p>
<p class="sub" style="margin:0">Si quieres construir tus propios sistemas con esta metodología:
<a href="https://www.institutoquant.com"><b>www.InstitutoQuant.com</b></a></p>
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
// La tabla llega pre-renderizada desde el generador (funciona sin JS);
// el JS solo la re-pinta al filtrar u ordenar.
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


def fmt_es(v):
    """Formato es-CO como el toLocaleString del JS: 1864.55 -> '1.864,55'."""
    if v is None or not isinstance(v, (int, float)):
        return "-"
    s = f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    if "," in s:
        s = s.rstrip("0").rstrip(",")
    return s


def clase_num(v):
    if not isinstance(v, (int, float)):
        return ""
    return "good" if v > 0 else ("bad" if v < 0 else "")


def bloque_tiles(backtests, sweetspot):
    n_comp = len(backtests)
    n_ss = len((sweetspot or {}).get("corridas", []))
    con_neto = [b for b in backtests if isinstance(b.get("neto"), (int, float))]
    mejor = max(con_neto, key=lambda b: b["neto"]) if con_neto else None
    peor = min(con_neto, key=lambda b: b["neto"]) if con_neto else None
    peor_extra = " (cuenta quebrada)" if peor and isinstance(peor.get("dd_max_pct"), (int, float)) and peor["dd_max_pct"] >= 100 else ""
    tiles = [
        ("Versiones del robot", "7", "v1 → v7"),
        ("Backtests", str(n_comp + n_ss), f"{n_comp} comparativos + {n_ss} de sweet spot"),
        ("Mejor corrida", (fmt_es(mejor["neto"]) + " USD") if mejor else "-", mejor["tag"] if mejor else ""),
        ("Peor corrida", (fmt_es(peor["neto"]) + " USD") if peor else "-", (peor["tag"] + peor_extra) if peor else ""),
        ("Bugs documentados", str(len(BUGS)), "batería de conocimiento"),
    ]
    return "".join(
        f'<div class="tile"><div class="k">{k}</div><div class="v">{v}</div><div class="d">{d}</div></div>'
        for k, v, d in tiles)


def bloque_tabla(backtests):
    """Tabla pre-renderizada (misma forma que pinta el JS) para lectores sin JS y SEO."""
    cols = [("tag", "Corrida", False), ("version", "Ver.", False), ("neto", "Neto USD", True),
            ("profit_factor", "PF", True), ("dd_max_pct", "DD máx %", True),
            ("trades", "Trades", True), ("sharpe", "Sharpe", True), ("parametros", "Parámetros", False)]
    th = "".join(
        f'<th class="{"num" if num else ""}" onclick="ordenar(\'{k}\')">{t}{" &#9660;" if k == "neto" else ""}</th>'
        for k, t, num in cols)
    filas = sorted(backtests,
                   key=lambda b: b["neto"] if isinstance(b.get("neto"), (int, float)) else -1e18,
                   reverse=True)
    tr = "".join(
        f'<tr><td>{b["tag"]}</td><td>{b["version"]}</td>'
        f'<td class="num {clase_num(b.get("neto"))}">{fmt_es(b.get("neto"))}</td>'
        f'<td class="num">{fmt_es(b.get("profit_factor"))}</td>'
        f'<td class="num">{fmt_es(b.get("dd_max_pct"))}</td>'
        f'<td class="num">{fmt_es(b.get("trades"))}</td>'
        f'<td class="num">{fmt_es(b.get("sharpe"))}</td>'
        f'<td class="sub">{b.get("parametros") or ""}</td></tr>'
        for b in filas)
    return f"<tr>{th}</tr>{tr}"


def bloque_sweetspot(ss):
    """Matriz deposito x temporalidad pre-renderizada (HTML+CSS puros, sin JS)."""
    corridas = (ss or {}).get("corridas", [])
    if not corridas:
        return '<div class="card sub">Los resultados del examen de sweet spot se publican en esta sección.</div>'
    deps = sorted({c["deposito"] for c in corridas})
    pers = list(dict.fromkeys(c["periodo"] for c in corridas))
    mapa = {(c["deposito"], c["periodo"]): c for c in corridas}
    max_abs = max((abs(c.get("neto_pct") or 0) for c in corridas), default=1) or 1

    def celda(c):
        if not c:
            return '<td class="sub">-</td>'
        v = c.get("neto_pct") or 0
        alfa = min(abs(v) / max_abs, 1) * 0.85 + 0.08
        cv = "var(--pos)" if v >= 0 else "var(--neg)"
        return (f'<td style="background:color-mix(in srgb, {cv} {round(alfa * 100)}%, var(--surface-1))">'
                f'<b>{fmt_es(v)}%</b><br><span class="sub">PF {fmt_es(c.get("profit_factor"))} · '
                f'DD {fmt_es(c.get("dd_max_pct"))}%</span></td>')

    encabezado = "".join(f"<th>{p}</th>" for p in pers)
    filas = "".join(
        f'<tr><th>{fmt_es(d)} USD</th>' + "".join(celda(mapa.get((d, p))) for p in pers) + "</tr>"
        for d in deps)
    conclusion = f'<p style="margin-top:12px"><b>Conclusión:</b> {ss["conclusion"]}</p>' if ss.get("conclusion") else ""
    return f'''<div class="card">
    <h3 style="margin:0 0 4px">{ss.get("titulo", "Sweet spot")}</h3>
    <div class="sub" style="margin-bottom:10px">{ss.get("subtitulo", "")} · valor = beneficio neto como % del depósito</div>
    <div class="tblwrap"><table class="heat">
      <tr><th>Depósito \\ TF</th>{encabezado}</tr>
      {filas}
    </table></div>
    <div class="legend"><span><span class="sw" style="background:var(--pos)"></span>% beneficio (más intenso = mayor)</span>
      <span><span class="sw" style="background:var(--neg)"></span>% pérdida</span></div>
    {conclusion}
  </div>'''


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
    n_comp = len(backtests)
    n_ss = len((sweetspot or {}).get("corridas", []))
    html = (PLANTILLA
            .replace("__DATA_JSON__", json.dumps(datos, ensure_ascii=False))
            .replace("__TIMELINE__", bloque_timeline())
            .replace("__BUGS__", bloque_bugs())
            .replace("__TILES__", bloque_tiles(backtests, sweetspot))
            .replace("__TABLA_BT__", bloque_tabla(backtests))
            .replace("__SWEETSPOT__", bloque_sweetspot(sweetspot))
            .replace("__N_COMP__", str(n_comp))
            .replace("__N_SS__", str(n_ss))
            .replace("__N_TOTAL__", str(n_comp + n_ss))
            .replace("__N_BUGS__", str(len(BUGS)))
            .replace("__FECHA__", date.today().isoformat()))

    salida = os.path.join(AQUI, "index.html")
    with open(salida, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"index.html generado ({len(backtests)} corridas, sweetspot={'si' if sweetspot else 'no'})")


if __name__ == "__main__":
    main()
