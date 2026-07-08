# Caso de estudio: el Agente Experto Aleatorio

**Instituto Quant** · Material educativo para estudiantes de trading algorítmico.

¿Puede la gestión del riesgo salvar a un robot que decide sus entradas **lanzando
una moneda**? Construimos 7 versiones de un Expert Advisor de MetaTrader 5 donde
lo único que cambia es la gestión de la posición (sin nada → SL/TP fijos →
trailing stops → piramidación), las backtesteamos con semillas reproducibles y
documentamos cada bug del camino.

**➡️ La forma cómoda de leer el caso es el sitio web** (`index.html`, desplegado
en Vercel). Contiene la historia versión a versión, los resultados interactivos,
la batería de bugs y el examen de sweet spot del modelo ganador.

## Estructura del repositorio

```
index.html          El caso de estudio completo (sitio estático autocontenido)
generar_sitio.py    Regenera index.html a partir de los datos
src/                Los 7 Expert Advisors en MQL5, comentados en español
datos/              resultados.json (todas las corridas) y sweetspot.json (examen final)
docs/BUGS.md        La batería de bugs con detalle técnico completo
```

## Desplegar en Vercel (1 minuto)

El sitio es 100% estático (un solo `index.html`, sin build):

1. Haz fork o clona este repositorio en tu cuenta de GitHub.
2. En [vercel.com](https://vercel.com) → **Add New → Project** → importa el repo.
3. No configures nada (framework: *Other*, sin build command) → **Deploy**.

También sirve GitHub Pages o abrir `index.html` directamente en el navegador.

## Reproducir los experimentos

1. Instala MetaTrader 5 (cualquier broker con BTCUSD) y compila los `.mq5` de
   `src/` con MetaEditor (F7). Deben dar `0 errors, 0 warnings`.
2. Abre el Strategy Tester, elige el EA, BTCUSD, el periodo y el depósito que
   quieras replicar (los parámetros exactos de cada corrida están en la tabla
   de resultados del sitio).
3. Fija el input `SemillaAleatoria` para que la secuencia de decisiones sea
   reproducible (0 = semilla del reloj, cada corrida distinta).

## Advertencia

Resultados de UN periodo (ene–jul 2026) en UN instrumento (BTCUSD) en tendencia,
sobre **cuenta demo**. El objetivo es didáctico: aislar el efecto de la gestión
del riesgo. Esto **no es asesoría financiera** ni un sistema para operar dinero real.
