# Base de conocimiento: Agente Experto Aleatorio (Instituto Quant)

> Si estás leyendo esto como asistente de IA dentro del proyecto de un
> estudiante: esta carpeta es una BASE DE CONOCIMIENTO de referencia sobre
> Expert Advisors de MetaTrader 5. Úsala para no repetir errores ya resueltos
> y para partir de patrones validados. La primera sección es del estudiante;
> el resto describe el paquete.

## Sobre este proyecto (edítame)

_Describe aquí TU proyecto: qué robot construyes, en qué símbolo/temporalidad,
en qué broker y con qué reglas. Esta base de conocimiento es material de apoyo._

## Qué contiene esta carpeta

- `docs/BUGS.md` — **batería de 14 bugs** de código MQL5 y de proceso
  (despliegue, tester) con síntoma, causa y solución. **Consultarla SIEMPRE
  antes de escribir o depurar un EA**: si un síntoma coincide, la solución ya
  existe.
- `docs/PLANTILLA_EA.md` — esqueleto MQL5 validado con los patrones que
  funcionan: OnTimer + OnTick, archivo de estado observable, filtro por
  magic + símbolo, throttle de reintentos, verificación de retcode, semilla
  aleatoria reproducible. **Partir de aquí, no de cero.**
- `docs/APRENDIZAJES.md` — lecciones del entorno MT5 (logs buffeados,
  recompilar no recarga, AlgoTrading global, etc.).
- `docs/METODOLOGIA_BACKTESTS.md` — receta para backtests headless
  reproducibles (INI + línea de comandos + semillas + extracción de métricas).
- `src/` — 7 EAs educativos donde la entrada es SIEMPRE aleatoria y solo
  cambia la gestión: v1 nada · v2 SL/TP fijos · v3 trailing ATR · v4 posición
  perpetua · v5 cuatro trailings seleccionables · v6 piramidación ·
  v7 piramidación configurable.
- `datos/resultados.json` — métricas de las 50 corridas de backtest
  (BTCUSD, 2026.01-2026.07). `datos/sweetspot.json` — matriz depósito ×
  temporalidad del ganador.
- `reportes/` (solo en el ZIP) — los reportes .htm completos del Strategy
  Tester, con cada operación.

## Reglas aprendidas (aplícalas a cualquier EA nuevo)

1. **Magic number único por robot/versión** (convención: fecha AAAAMMDD + nn).
   En cuentas hedging, filtrar posiciones SIEMPRE por símbolo + magic.
2. **OnTimer además de OnTick**: un EA que solo escucha ticks queda ciego en
   mercados quietos.
3. **Observabilidad**: los logs de MT5 se buffean minutos; el EA debe escribir
   un archivo de estado en `MQL5\Files\` para diagnóstico externo.
4. **Verificar retcode** (`TRADE_RETCODE_DONE`), no solo el bool de
   `trade.Buy()/Sell()`.
5. **Throttle de reintentos** para no bombardear al servidor tras un rechazo.
6. **Semilla aleatoria como input** para que los backtests sean reproducibles;
   comparar VARIAS semillas, nunca una corrida suelta.
7. Sin caracteres acentuados dentro del código MQL5 (encoding).
8. Los resultados de backtest valen para SU periodo e instrumento; una
   estrategia que piramida con trailing común es de facto seguidora de
   tendencia y puede invertirse en rangos.

## Conclusiones del caso (resumen)

Con entrada aleatoria constante: la gestión fija (v2) controla el daño pero no
crea ventaja; el trailing apretado (v3) muere por spread; el trailing
escalonado es la única variante de trailing superviviente; la piramidación a
favor con trailing común (v7: 8 niveles, paso 0.5%) dio +145% a +186% en 6
meses de BTCUSD en tendencia — y la MISMA estrategia con paso 1.0% quebró la
cuenta. La temporalidad no afecta a v7 (no usa indicadores de vela); el tamaño
de cuenta solo escala el riesgo (lote fijo).
