
# Sincronizacion con GitHub (obligatorio)

- Al EMPEZAR a trabajar aqui: `git fetch` + `git pull --ff-only` — este proyecto se usa desde varios dispositivos/sesiones y la version buena puede estar en el remoto. Si el pull falla por divergencia, avisar antes de tocar nada.
- Con CADA cambio terminado: commit y push. Nada queda solo en esta maquina.
- OJO deploy: si este repo tiene auto-deploy (Vercel/Lovable/Render/Cloudflare), un push a la rama de produccion PUBLICA. El trabajo que no deba salir aun va en una rama, pero siempre subida al remoto.
