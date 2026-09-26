# tg-reader — Lector de Telegram para MT5

Lee el canal de senales (Telethon, userbot) y escribe cada evento como JSON
en `MQL5/Files/tg_signals.txt` para que el EA `TG_Bridge_Executor.mq5` opere.

## Instalacion
```bash
cd tg-reader
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# editar .env si hace falta (api_id/hash, canal, ruta MQL5/Files)
python tg_reader.py
```
La primera vez pide el telefono + el codigo de Telegram (login del userbot).

## Formato de salida (`tg_signals.txt`, una linea JSON por evento)
- `{"type":"entry","symbol":"BOOM900","direction":"compra","entry":X,"tp1":Y,"tp2":Z}`
- `{"type":"close","symbol":"BOOM900","reason":"profit|tp|gold","price":W}`
- `{"type":"no_operar","symbol":"BOOM900"}`
- `{"type":"habilitar","symbol":"BOOM900","direction":"compra|venta"}`

## Notas
- Solo LEE el canal; nunca envia mensajes.
- El simbolo se obtiene del TEMA (foro) de cada mensaje.
