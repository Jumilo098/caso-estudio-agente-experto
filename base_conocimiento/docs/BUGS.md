# Bateria de bugs conocidos (y sus soluciones)

Registro acumulativo de bugs encontrados en los EAs del Agente Experto y en el
proceso de construccion/despliegue/backtest. Objetivo: que NINGUN bug se
resuelva dos veces. Antes de escribir o depurar un EA, leer esta lista.

Formato: **BUG-nn** · sintoma · causa · solucion · versiones afectadas.

---

## Bugs de codigo MQL5

### BUG-01 · EA "dormido" sin ticks
- **Sintoma**: el EA no reabre posicion (o no hace trailing) durante minutos.
- **Causa**: toda la logica colgada de `OnTick()`; si el grafico no recibe
  ticks (mercado lento, simbolo quieto), el EA no respira.
- **Solucion**: `EventSetTimer(5)` en OnInit y llamar la logica tambien desde
  `OnTimer()`. Patron en `docs/PLANTILLA_EA.md`.
- **Afectaba**: v2 y v3 originales (junio 2026). Corregido en revision 2.10/3.10.

### BUG-02 · EA invisible (logs buffeados)
- **Sintoma**: imposible saber si el EA vive; el .log lleva minutos sin lineas.
- **Causa**: MT5 buffea los logs de expertos en disco (8+ min observados).
- **Solucion**: patron "EA observable": escribir archivo de estado en
  `MQL5\Files\AEvN_estado_<SIMBOLO>.txt` cada ciclo del timer.
- **Afectaba**: v1-v3 originales. Corregido en toda la serie desde la v4.

### BUG-03 · Rafaga de reintentos al rechazo del servidor
- **Sintoma**: decenas de ordenes rechazadas por segundo en el log.
- **Causa**: sin throttle: cada tick reintenta la orden fallida.
- **Solucion**: variable `ultimoIntento` + input `EsperaReintento` (5 s).
- **Afectaba**: v1-v3 originales. Corregido en revision 2.10/3.10.

### BUG-04 · Magic number compartido entre versiones
- **Sintoma**: dos versiones corriendo a la vez se "roban" las posiciones
  (cada una cree que la posicion de la otra es suya) y dejan de operar bien.
- **Causa**: v2 y v3 originales compartian el magic `20240616`.
- **Solucion**: convencion de magics unicos `AAAAMMDD` + `nn` de version:
  v2=2026070802, v3=2026070803, v5=2026070805, v6=2026070806, v7=2026070807
  (v4 conserva su 20260704 historico).
- **Afectaba**: v2 y v3 originales.

### BUG-05 · Exito falso al abrir posicion
- **Sintoma**: el log dice "posicion abierta" pero no hay posicion.
- **Causa**: `trade.Buy()` devuelve `true` si la orden se ENVIO, no si se
  ejecuto. Con requote/rechazo tardio el bool engana.
- **Solucion**: exigir ademas `trade.ResultRetcode() == TRADE_RETCODE_DONE`.
- **Afectaba**: v2 y v3 originales. Corregido en revision 2.10/3.10.

### BUG-06 · Acentos dentro del codigo MQL5
- **Sintoma**: caracteres corruptos en MetaEditor, warnings o texto ilegible.
- **Causa**: conflicto de encoding UTF-8 vs el editor con caracteres acentuados.
- **Solucion**: regla del proyecto: comentarios en espanol SIN acentos ni enie.
- **Afectaba**: v2 y v3 originales (reescritas limpias).

### BUG-07 · Backtests no reproducibles (semilla del reloj)
- **Sintoma**: cada corrida del tester da resultados distintos; imposible
  comparar variantes con justicia.
- **Causa**: `MathSrand(GetTickCount())` — semilla distinta en cada corrida.
- **Solucion**: input `SemillaAleatoria` (0 = reloj para live; valor fijo en
  el tester via `[TesterInputs]`). Correr varias semillas y comparar la
  DISTRIBUCION, no una corrida suelta.
- **Afectaba**: toda la serie original.

### BUG-08 · Bombardeo de PositionModify en el trailing
- **Sintoma**: cientos de modificaciones de SL microscopicas por hora;
  ruido en el journal y riesgo de limites del broker.
- **Causa**: el trailing movia el SL con CUALQUIER mejora, aunque fuera de
  centavos, en cada tick.
- **Solucion**: input `MejoraMinPuntos` (100 puntos por defecto): solo se
  modifica si el SL mejora al menos ese paso.
- **Afectaba**: v3 original. Corregido en 3.10 y heredado por v5.

### BUG-09 · Trailing de VENTA sin SL inicial se rompia
- **Sintoma**: en una venta sin SL previo, el trailing nunca arrancaba (la
  condicion `nuevoSL < slActual` con slActual=0.0 siempre es falsa).
- **Causa**: falta el caso especial `slActual == 0.0` (la compra funcionaba
  de rebote porque cualquier SL > 0).
- **Solucion**: condicion explicita `(slActual == 0.0 || nuevoSL < slActual - mejora)`.
- **Afectaba**: v3 original lo tenia parcheado solo en SELL; ahora esta
  simetrico y documentado en v3.10 y v5.

## Bugs de proceso (despliegue/terminal)

### BUG-10 · El EA desplegado por INI [StartUp] NO sobrevive reinicios
- **Sintoma**: tras un reinicio normal del terminal, el EA ya no esta en
  ningun grafico (sin rastro en el perfil; el journal no muestra su carga).
- **Causa**: el grafico creado por `[StartUp] Expert=` es temporal: NO se
  guarda en el perfil Default. La v4 "en produccion" habria muerto sola con
  cualquier reinicio de Windows o del terminal.
- **Solucion**: para produccion real, adjuntar el EA a un grafico del perfil
  (a mano) o re-desplegar con INI tras cada arranque. Para APAGAR un EA asi,
  basta reiniciar el terminal sin INI.
- **Descubierto**: 2026-07-07 al apagar la v4.

### BUG-11 · retcode 10027 al operar via Python (AlgoTrading apagado)
- **Sintoma**: `order_send` devuelve 10027 "AutoTrading disabled by client".
- **Causa**: el boton global AlgoTrading del terminal estaba apagado (un
  reinicio normal puede dejarlo asi; el INI con `AllowLiveTrading=1` lo
  enciende para TODOS los EAs).
- **Solucion**: reiniciar con INI `[Experts] AllowLiveTrading=1 Enabled=1`
  (sin [StartUp]) y reintentar. Verificar con `terminal_info().trade_allowed`.
- **Descubierto**: 2026-07-07 al cerrar la posicion de la v4.

### BUG-12 · Kill switch confiable: mover el .ex5
- No es un bug sino la solucion generica: para garantizar que un EA no
  cargue nunca, mover su `.ex5` a `MQL5\Experts\_apagados\`. Aunque el perfil
  o un INI lo pidan, el terminal no puede cargarlo. Restaurar = mover de
  vuelta (o recompilar el .mq5).

### BUG-13 · FactorLote < 1 colapsa al lote minimo (piramidacion muda)
- **Sintoma**: en la v7, `FactorLote=0.7` dio EXACTAMENTE el mismo resultado
  que `FactorLote=1.0` (backtest identico, +1196.35 en ambos).
- **Causa**: con lote base 0.01 (el minimo de BTCUSD), el nivel 2 pide
  0.007 lotes; `NormalizarLote` lo redondea al paso (0.0) y luego lo sube al
  minimo (0.01). El escalado decreciente es imposible desde el lote minimo.
- **Solucion**: para probar factores < 1, subir `LoteBase` (p.ej. 0.05) de
  modo que los niveles decrecientes queden por encima del minimo. Documentar
  en el reporte cuando el lote efectivo != lote pedido.
- **Descubierto**: 2026-07-08 en la fase comparativa de backtests.

### BUG-14 · El terminal a veces NO se cierra tras el tester (ShutdownTerminal=1)
- **Sintoma**: la simulacion termina (el log del tester llega al final del
  periodo) pero `terminal64.exe` sigue vivo y nunca escribe el reporte; el
  runner aborta por timeout (le paso a 1 corrida de 25: v5_atr_s22222).
- **Causa**: no determinada (colgado interno del terminal al generar reporte).
- **Solucion**: tratarlo como flaky: timeout de 20 min en el runner, matar el
  terminal y REINTENTAR la corrida (el reintento funciono a la primera).
- **Descubierto**: 2026-07-08 durante el lote comparativo.
