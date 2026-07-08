# Instructivo: cómo usar esta base de conocimiento en TU proyecto

Este paquete contiene todo el conocimiento del caso de estudio del **Agente
Experto Aleatorio** (Instituto Quant), listo para que lo metas en la carpeta de
tu propio proyecto de trading algorítmico y lo uses como base de conocimiento.

## 1. Descarga

**Opción A (recomendada):** descarga el ZIP desde el sitio del caso:
https://caso-agente-experto.vercel.app → sección "Descargas" → *Base de
conocimiento completa*. Descomprímelo.

**Opción B:** clona el repositorio y copia la carpeta:
```
git clone https://github.com/Jumilo098/caso-estudio-agente-experto.git
```
La carpeta que te interesa es `base_conocimiento/` (el ZIP añade además los 50
reportes de backtest en `reportes/`).

## 2. Dónde ponerla

Copia la carpeta completa dentro de tu proyecto, así:

```
MiProyectoDeTrading/
├── base_conocimiento/        ←  este paquete, tal cual
│   ├── INSTRUCTIVO.md        ←  este archivo
│   ├── CLAUDE.md             ←  contexto para asistentes de IA
│   ├── docs/                 ←  bugs, aprendizajes, plantilla, metodología
│   ├── src/                  ←  los 7 EAs en MQL5
│   ├── datos/                ←  resultados.json y sweetspot.json
│   └── reportes/             ←  (solo en el ZIP) los 50 reportes del tester
└── ... (tus archivos)
```

## 3. Cómo usarla CON un asistente de IA (Claude Code, Cursor, etc.)

El paquete incluye un `CLAUDE.md` pensado para que un agente de IA entienda
todo el contenido sin que tengas que explicárselo:

- **Si tu proyecto NO tiene `CLAUDE.md`**: copia
  `base_conocimiento/CLAUDE.md` a la raíz de tu proyecto y ajusta la primera
  sección con la descripción de TU proyecto.
- **Si tu proyecto YA tiene `CLAUDE.md`**: añádele esta línea:

  > Antes de escribir o depurar un Expert Advisor, lee
  > `base_conocimiento/CLAUDE.md` y la batería de bugs en
  > `base_conocimiento/docs/BUGS.md`.

Con eso, el asistente consultará la batería de bugs antes de repetir errores ya
resueltos, usará la plantilla validada como punto de partida y podrá comparar
tus resultados con los del caso.

## 4. Cómo usarla SIN asistente de IA

Orden de lectura sugerido:

1. `docs/APRENDIZAJES.md` — las lecciones del entorno MT5 que cuestan tiempo real.
2. `docs/BUGS.md` — los 14 bugs con síntoma, causa y solución. Léelo ANTES de depurar.
3. `docs/PLANTILLA_EA.md` — el esqueleto MQL5 con los patrones validados; parte de aquí.
4. `src/` — los 7 EAs en orden (v1 → v7): cada uno añade UNA idea de gestión.
5. `docs/METODOLOGIA_BACKTESTS.md` — cómo correr backtests reproducibles por línea de comandos.
6. `datos/` y `reportes/` — los resultados crudos para tu propio análisis.

## 5. Los datos

- `datos/resultados.json` — las 50 corridas con sus métricas (beneficio neto,
  profit factor, drawdown máximo, trades, Sharpe, parámetros exactos). Ideal
  para cargar en Python/Excel y hacer tu propio análisis.
- `datos/sweetspot.json` — la matriz depósito × temporalidad del modelo ganador.
- `reportes/bt_<corrida>.htm` — el reporte COMPLETO del Strategy Tester de cada
  corrida (con la lista de todas las operaciones). Ábrelos en el navegador; los
  `.png` del mismo nombre son las curvas del reporte.

Ejemplo en Python:
```python
import json
with open("base_conocimiento/datos/resultados.json", encoding="utf-8") as f:
    corridas = json.load(f)
for tag, r in corridas.items():
    print(tag, r.get("beneficio_neto"), r.get("profit_factor"))
```

## 6. Verificación rápida

Tras copiarla, comprueba que tienes: `CLAUDE.md`, `INSTRUCTIVO.md`,
4 archivos en `docs/`, 7 `.mq5` en `src/`, 2 `.json` en `datos/`
(y, si bajaste el ZIP, 50 `.htm` en `reportes/`).

---
Instituto Quant · Material educativo sobre cuenta demo · No es asesoría financiera.
