# Metodología: backtests headless reproducibles en MT5

Cómo se corrieron las 50 corridas del caso, para que puedas replicarlo con tu
propio EA sin tocar la interfaz del Strategy Tester.

## 1. Un INI por corrida

Guardar como **UTF-16** (en PowerShell: `Out-File -Encoding Unicode`):

```ini
[Tester]
Expert=NombreDelEA_sin_extension
Symbol=BTCUSD
Period=M15
Model=1
FromDate=2026.01.01
ToDate=2026.07.07
Deposit=1000
Currency=USD
Leverage=200
Optimization=0
Report=bt_mi_corrida
ReplaceReport=1
ShutdownTerminal=1

[TesterInputs]
SemillaAleatoria=11111
```

- `Model=1` = OHLC de 1 minuto (equilibrio velocidad/fidelidad). `0` = todos
  los ticks (lento), `4` = ticks reales (requiere historial de ticks).
- `[TesterInputs]` fija cualquier input del EA: así se fijan la semilla y los
  parámetros de cada configuración.
- `ShutdownTerminal=1` cierra el terminal al terminar → automatizable en lote.

## 2. Lanzar y esperar

```powershell
& "C:\Program Files\MetaTrader 5\terminal64.exe" /config:"C:\ruta\mi_corrida.ini"
# esperar a que el proceso terminal64 muera (timeout prudente: 20 min)
```

El reporte `bt_mi_corrida.htm` (UTF-16, con sus .png) aparece en la **raíz de
la carpeta de datos** del terminal.

Trampa conocida (BUG-14): ~1 de cada 25 corridas el terminal termina la
simulación pero nunca se cierra ni escribe el reporte. Solución: timeout,
matar el proceso y reintentar la corrida.

## 3. Extraer las métricas

El reporte es HTML en español con etiquetas estables ("Beneficio Neto:",
"Factor de Beneficio:", "Reducción máxima del balance:", ...). Se parsea
quitando las etiquetas HTML y aplicando expresiones regulares — así se generó
`datos/resultados.json`. Campos que vale la pena extraer: beneficio neto,
bruto, pérdidas, profit factor, beneficio esperado, factor de recuperación,
Sharpe, DD máximo de balance y equidad (valor y %), total de operaciones,
% ganadoras y los parámetros de entrada.

## 4. Reglas de oro con EAs aleatorios (o con cualquier EA)

1. **Semilla fija por input**, jamás solo el reloj: sin reproducibilidad no
   hay comparación honesta.
2. **Varias semillas por configuración** (aquí: 2-3): se compara la
   distribución, no la anécdota.
3. **Un solo cambio por versión**: si cambias dos cosas no sabes cuál actuó.
4. **Mismo periodo, símbolo y depósito** en toda la fase comparativa.
5. El ganador se somete después a la **matriz de sweet spot** (depósito ×
   temporalidad) para ubicar dónde operarlo.
6. Desconfía de resultados espectaculares: pregunta primero qué tendencia
   tenía el mercado en el periodo y si la estrategia solo la montó.
