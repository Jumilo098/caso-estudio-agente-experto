# Aprendizajes del entorno MetaTrader 5 (leer antes de desplegar)

Lecciones reales, cada una costó tiempo. Los bugs puntuales están en `BUGS.md`;
esto es lo estructural del entorno. Versión genérica para cualquier instalación
de MT5 (rutas: `<datos>` = carpeta de datos del terminal, se abre desde
MT5 → Archivo → Abrir carpeta de datos).

## 1. Los logs de MT5 se buffean minutos — el silencio no es diagnóstico
El log de expertos (`<datos>\MQL5\Logs\`) puede estar 8+ minutos sin escribirse
con el terminal funcionando perfectamente. Jamás diagnosticar "el EA no hace
nada" leyendo el log. Fuentes de verdad, en orden: posiciones vía API
(paquete Python `MetaTrader5`) → archivo de estado del EA → journal → log.

## 2. Recompilar NO recarga el EA en el gráfico
Compilar un `.ex5` nuevo con el terminal abierto no reinicializa el EA del
gráfico (no vuelve a correr OnInit). Despliegue confiable = reiniciar el
terminal.

## 3. El EA lanzado por INI de arranque NO sobrevive reinicios
`terminal64.exe /config:<ini>` con `[StartUp] Expert=` crea un gráfico
TEMPORAL que no se guarda en el perfil. Tras el siguiente reinicio el EA ya no
está. Para producción: adjuntarlo a un gráfico del perfil a mano.

## 4. AllowLiveTrading / AlgoTrading es GLOBAL
El botón enciende o apaga TODOS los EAs de todos los gráficos. Un reinicio
puede dejarlo apagado (las órdenes por API devuelven retcode 10027). Revisar
`terminal_info().trade_allowed` antes de buscar bugs en el código.

## 5. Patrón "EA observable": archivo de estado
Un EA que solo hace `Print()` es invisible (punto 1). Escribir cada ciclo un
TXT en `<datos>\MQL5\Files\` con hora del servidor, permisos de trading, si
hay posición propia y el último retcode. Costo nulo, observabilidad total.

## 6. OnTimer además de OnTick
La lógica debe latir también con `EventSetTimer(5)`: un EA que solo depende de
OnTick queda ciego si el gráfico no recibe ticks.

## 7. Cuenta hedging → filtrar SIEMPRE por magic + símbolo
`PositionsTotal()` a secas mezcla los robots de todos los gráficos. El filtro
magic+símbolo es lo que permite que varios EAs convivan sin pisarse.

## 8. `order_check` para descartar problemas de mercado sin operar
`mt5.order_check(request)` vía Python valida margen, filling y permisos del
lado servidor SIN ejecutar.

## 9. Backtests headless: automatizables y reproducibles
Ver `METODOLOGIA_BACKTESTS.md`. Claves: INI por corrida, semilla fija por
input, varias semillas por configuración, reporte .htm (UTF-16) parseado a
JSON. El terminal a veces no se cierra al terminar (flaky): timeout y
reintento.

## 10. Detalles menores que ahorran horas
- Logs y reportes de MT5 en UTF-16: leerlos con esa codificación
  (PowerShell: `-Encoding Unicode`).
- Los INI de arranque también en UTF-16.
- `taskkill /IM terminal64.exe` SIN `/F` = cierre amable (guarda el perfil).
- Sin acentos dentro del código MQL5.
- La hora del servidor del broker suele ir horas por delante de la local.
- `MathSrand(GetTickCount()+TimeLocal())` para semillas distintas por carga
  (o el input `SemillaAleatoria` para reproducibilidad).
