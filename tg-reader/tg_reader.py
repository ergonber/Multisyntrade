#!/usr/bin/env python3
"""
TG Reader -> archivo para MT5.
Lee un canal/grupo de Telegram (userbot con Telethon) y escribe cada senal
como una linea JSON en MQL5/Files/tg_signals.txt para que un EA de MT5 la lea.

NO envia mensajes al canal. Solo lee.
"""
import os
import re
import json
import time
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from telethon import TelegramClient, events, functions

load_dotenv()

API_ID = int(os.environ["TELEGRAM_API_ID"])
API_HASH = os.environ["TELEGRAM_API_HASH"]
SESSION = os.environ.get("TELEGRAM_SESSION", "tg_reader")
CHANNEL = os.environ.get("TELEGRAM_CHANNEL", "DERIV INDEX PRO")
MT5_FILES = os.environ["MT5_FILES_DIR"]
OUT = os.path.join(MT5_FILES, "tg_signals.txt")

_TOPICS = {}  # topic_id -> "Boom 900"


def log(*a):
    print(datetime.now().strftime("%H:%M:%S"), *a, flush=True)


def sym_key(title: str):
    """'Boom 900' -> 'BOOM900'"""
    t = (title or "").upper().replace(" ", "")
    return t


def write_event(ev: dict):
    ev["ts"] = int(time.time() * 1000)
    line = json.dumps(ev, ensure_ascii=False)
    with open(OUT, "a", encoding="utf-8") as f:
        f.write(line + "\n")
        f.flush()
    log("->", line)


def parse_and_write(symbol, text):
    if not symbol:
        log("(sin simbolo) mensaje:", text[:80])
        return
    sym = sym_key(symbol)

    if "No operar" in text:
        write_event({"type": "no_operar", "symbol": sym})
        return
    if "Se puede operar" in text:
        write_event({"type": "habilitar", "symbol": sym,
                     "direction": "compra" if "COMPRA" in text.upper() else "venta"})
        return
    if "Cierre de Entrada" in text:
        write_event({"type": "close", "symbol": sym, "reason": "gold"})
        return
    m = re.search(r"Profittt\s*\(([\d.]+)\)", text)
    if m:
        write_event({"type": "close", "symbol": sym, "reason": "profit", "price": float(m.group(1))})
        return
    m = re.search(r"TP[12]\s*Alcanzado\s*\(([\d.]+)\)", text)
    if m:
        write_event({"type": "close", "symbol": sym, "reason": "tp", "price": float(m.group(1))})
        return
    # entrada
    e = re.search(r"Entrada:\s*([\d.]+)", text)
    t1 = re.search(r"TP1:\s*([\d.]+)", text)
    t2 = re.search(r"TP2:\s*([\d.]+)", text)
    if e and t1:
        direction = "compra" if "Compra" in text else "venta"
        write_event({
            "type": "entry", "symbol": sym, "direction": direction,
            "entry": float(e.group(1)),
            "tp1": float(t1.group(1)),
            "tp2": float(t2.group(1)) if t2 else None,
        })
        return
    log("(ignorado)", text[:80])


async def find_channel(client, name):
    try:
        return await client.get_entity(name)
    except Exception:
        pass
    async for d in client.iter_dialogs():
        if name.lower() in (d.name or "").lower():
            return d.entity
    raise RuntimeError(f"Canal no encontrado: {name}")


async def load_topics(client, entity):
    try:
        res = await client(functions.channels.GetForumTopicsRequest(
            channel=entity, offset_date=None, offset_id=0, offset_topic=0, limit=100))
        for t in res.topics:
            _TOPICS[t.id] = t.title
        log("Temas:", list(_TOPICS.values()))
    except Exception as ex:
        log("Sin temas (o no es foro):", ex)


async def main():
    os.makedirs(MT5_FILES, exist_ok=True)
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.start()
    log("Conectado. Buscando canal:", CHANNEL)
    entity = await find_channel(client, CHANNEL)
    log("Canal:", getattr(entity, "title", entity))
    await load_topics(client, entity)

    @client.on(events.NewMessage(chats=entity))
    async def handler(event):
        msg = event.message
        topic_id = None
        rt = getattr(msg, "reply_to", None)
        if rt is not None:
            topic_id = getattr(rt, "reply_to_top_id", None) or getattr(rt, "reply_to_msg_id", None)
        symbol = _TOPICS.get(topic_id)
        parse_and_write(symbol, msg.message or "")

    log("Escuchando mensajes...")
    await client.run_until_disconnected()


if __name__ == "__main__":
    asyncio.run(main())
