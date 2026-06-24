#!/usr/bin/env python3
"""
Aizen Bot - Servidor de Licencas + Recepcao de Scans
Hospedar no Replit ou VPS.

Variaveis de ambiente:
  DISCORD_TOKEN - Token do bot Discord
  ANALYST_ID    - Seu ID de usuario no Discord

Comandos:
  /gerar <dias>      - Gera licenca por N dias
  /revogar <licenca> - Revoga uma licenca
  /listar            - Lista todas as licencas
  /info <licenca>    - Info de uma licenca

Requer: pip install discord.py aiohttp
"""

import discord
from discord import app_commands
import aiohttp
from aiohttp import web
import asyncio
import json
import os
import secrets
import hashlib
import time
from datetime import datetime, timedelta

TOKEN = os.environ.get("DISCORD_TOKEN", "SEU_TOKEN_AQUI")
ANALYST_ID = int(os.environ.get("ANALYST_ID", "0"))

LICENSES_FILE = "licenses.json"
SCANS_FILE = "scans.json"

# Anti-spam: ultimo scan por licenca (timestamp)
_last_scan = {}
SCAN_COOLDOWN = 60  # segundos entre scans da mesma licenca


# ============================================================
# GERENCIADOR DE LICENCAS
# ============================================================

def load_licenses():
    if os.path.exists(LICENSES_FILE):
        try:
            with open(LICENSES_FILE) as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_licenses(licenses):
    with open(LICENSES_FILE, "w") as f:
        json.dump(licenses, f, indent=2)


def load_scans():
    if os.path.exists(SCANS_FILE):
        try:
            with open(SCANS_FILE) as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_scans(scans):
    with open(SCANS_FILE, "w") as f:
        json.dump(scans, f, indent=2)


def generate_license(days, owner_id=None):
    key = f"AIZEN-{secrets.token_hex(4).upper()}-{secrets.token_hex(4).upper()}"
    expires = (datetime.utcnow() + timedelta(days=days)).isoformat()
    return key, {
        "key": key,
        "owner_id": owner_id,
        "created": datetime.utcnow().isoformat(),
        "expires": expires,
        "active": True,
        "hwid": None,
        "uses": 0,
    }


def validate_license(licenses, key, hwid):
    lic = licenses.get(key)
    if not lic:
        return False, "Licenca inexistente"
    if not lic.get("active", False):
        return False, "Licenca revogada"
    expires = datetime.fromisoformat(lic["expires"])
    if datetime.utcnow() > expires:
        lic["active"] = False
        save_licenses(licenses)
        return False, "Licenca expirada"
    # Se ja tem HWID vinculado, verifica se e o mesmo
    if lic["hwid"] and lic["hwid"] != hwid:
        return False, f"Licenca ja vinculada a outro dispositivo ({lic['hwid'][:8]}...)"
    return True, lic


def bind_hwid(licenses, key, hwid):
    if key in licenses:
        licenses[key]["hwid"] = hwid
        licenses[key]["uses"] += 1
        save_licenses(licenses)


# ============================================================
# DISCORD BOT
# ============================================================

intents = discord.Intents.default()
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)


@client.event
async def on_ready():
    print(f"Bot online: {client.user}")
    await tree.sync()


@tree.command(name="gerar", description="Gera licenca para um usuario")
@app_commands.describe(usuario="ID do usuario no Discord", dias="Quantidade de dias de validade")
async def cmd_gerar(interaction: discord.Interaction, usuario: str, dias: int):
    if interaction.user.id != ANALYST_ID:
        await interaction.response.send_message("\u274c Sem permissao", ephemeral=True)
        return
    if dias < 1 or dias > 365:
        await interaction.response.send_message("Dias deve ser entre 1 e 365", ephemeral=True)
        return
    try:
        owner_id = int(usuario)
    except ValueError:
        await interaction.response.send_message("\u274c ID invalido. Use o ID numerico do Discord.", ephemeral=True)
        return

    licenses = load_licenses()
    key, lic = generate_license(dias, owner_id=owner_id)

    # Verifica se o usuario existe e manda DM
    user_dm = False
    try:
        target = await client.fetch_user(owner_id)
        if target:
            embed_user = discord.Embed(
                title="\U0001f511 Sua Licenca Aizen Scanner",
                description=f"Analista vinculou uma licenca para voce.",
                color=0x000000,
            )
            embed_user.add_field(name="Chave", value=f"`{key}`", inline=False)
            embed_user.add_field(name="Validade", value=f"{dias} dias", inline=True)
            embed_user.add_field(name="Expira", value=lic["expires"][:10], inline=True)
            embed_user.add_field(name="Como usar", value="Execute no Termux:\n`./aizen_scanner --license " + key + " --server URL_DO_BOT`", inline=False)
            await target.send(embed=embed_user)
            user_dm = True
    except Exception:
        pass

    licenses[key] = lic
    save_licenses(licenses)

    embed = discord.Embed(
        title="\U0001f511 Licenca Gerada",
        color=0x000000,
    )
    embed.add_field(name="Chave", value=f"`{key}`", inline=False)
    embed.add_field(name="Usuario", value=f"<@{owner_id}> (`{owner_id}`)", inline=True)
    embed.add_field(name="Validade", value=f"{dias} dias", inline=True)
    embed.add_field(name="Expira", value=lic["expires"][:10], inline=True)
    embed.add_field(name="DM enviada", value="\u2705 Sim" if user_dm else "\u26a0\ufe0f Nao (ID invalido ou DM fechada)", inline=True)

    await interaction.response.send_message(embed=embed, ephemeral=True)


@tree.command(name="revogar", description="Revoga uma licenca")
@app_commands.describe(licenca="Chave da licenca (AIZEN-XXXX-XXXX)")
async def cmd_revogar(interaction: discord.Interaction, licenca: str):
    if interaction.user.id != ANALYST_ID:
        await interaction.response.send_message("\u274c Sem permissao", ephemeral=True)
        return

    licenca = licenca.upper()
    licenses = load_licenses()
    if licenca not in licenses:
        await interaction.response.send_message("\u274c Licenca nao encontrada", ephemeral=True)
        return

    licenses[licenca]["active"] = False
    save_licenses(licenses)
    await interaction.response.send_message(
        f"\u2705 Licenca `{licenca}` revogada", ephemeral=True
    )


@tree.command(name="listar", description="Lista todas as licencas")
async def cmd_listar(interaction: discord.Interaction):
    if interaction.user.id != ANALYST_ID:
        await interaction.response.send_message("\u274c Sem permissao", ephemeral=True)
        return

    licenses = load_licenses()
    if not licenses:
        await interaction.response.send_message("Nenhuma licenca cadastrada", ephemeral=True)
        return

    active = sum(1 for l in licenses.values() if l.get("active"))
    expired = sum(1 for l in licenses.values() if not l.get("active"))

    lines = []
    for key, lic in sorted(licenses.items(), key=lambda x: x[1]["created"], reverse=True)[:20]:
        status = "\u2705" if lic.get("active") else "\u274c"
        hwid_info = f" | HWID: {lic['hwid'][:8]}..." if lic.get("hwid") else ""
        owner_info = f" | <@{lic['owner_id']}>" if lic.get("owner_id") else ""
        uses = lic.get("uses", 0)
        lines.append(f"{status} `{key}`{owner_info} | {lic['expires'][:10]} | {uses} usos{hwid_info}")

    embed = discord.Embed(
        title=f"\U0001f4cb Licencas ({len(licenses)} total, {active} ativas, {expired} inativas)",
        description="\n".join(lines[:20]) or "(nenhuma)",
        color=0x000000,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


@tree.command(name="info", description="Info de uma licenca")
@app_commands.describe(licenca="Chave da licenca")
async def cmd_info(interaction: discord.Interaction, licenca: str):
    if interaction.user.id != ANALYST_ID:
        await interaction.response.send_message("\u274c Sem permissao", ephemeral=True)
        return

    licenca = licenca.upper()
    licenses = load_licenses()
    lic = licenses.get(licenca)
    if not lic:
        await interaction.response.send_message("\u274c Licenca nao encontrada", ephemeral=True)
        return

    embed = discord.Embed(title=f"\U0001f511 Licenca {licenca}", color=0x000000)
    embed.add_field(name="Status", value="\u2705 Ativa" if lic.get("active") else "\u274c Inativa", inline=True)
    embed.add_field(name="Criada", value=lic["created"][:10], inline=True)
    embed.add_field(name="Expira", value=lic["expires"][:10], inline=True)
    embed.add_field(name="Usos", value=str(lic.get("uses", 0)), inline=True)
    embed.add_field(name="Dono", value=f"<@{lic['owner_id']}>" if lic.get("owner_id") else "N/A", inline=True)
    embed.add_field(name="HWID", value=lic.get("hwid", "Nenhum")[:20] or "Nenhum", inline=True)

    # Scan history
    scans = load_scans()
    user_scans = [s for s in scans.values() if s.get("license") == licenca]
    embed.add_field(name="Scans", value=str(len(user_scans)), inline=True)

    await interaction.response.send_message(embed=embed, ephemeral=True)


# ============================================================
# WEBHOOK SERVER (recebe dados do scanner)
# ============================================================

async def send_scan_dm(user, scan_id, license_key, hwid, data, owner_id, is_analyst):
    """Envia scan organizado em embeds."""
    # Embed 1: resumo
    flags = []
    for name, out in data.items():
        if any(kw in out for kw in ("ROOT DETECTADO", "[!]", "FLASH DESBLOQUEADO")):
            flags.append(f"\u26a0\ufe0f {name}")
        if "RESULTADO:" in out:
            lines = [l for l in out.split("\n") if "RESULTADO:" in l]
            for l in lines:
                flags.append(f"\u2705 {l.strip()}")

    title = "\U0001f4cb Scan Recebido" if is_analyst else "\U0001f4cb Resultado do Scan"
    embed = discord.Embed(title=title, color=0x000000, timestamp=datetime.utcnow())
    embed.add_field(name="Licenca", value=f"`{license_key[:16]}...`", inline=True)
    embed.add_field(name="HWID", value=f"`{hwid[:12]}...`", inline=True)
    embed.add_field(name="Sessoes", value=str(len(data)), inline=True)
    if is_analyst and owner_id:
        embed.add_field(name="Cliente", value=f"<@{owner_id}>", inline=True)
    if flags:
        embed.add_field(name="Alertas", value="\n".join(flags[:5]), inline=False)
    embed.set_footer(text=f"Scan {scan_id[:8]}")
    await user.send(embed=embed)

    # Embeds por secao
    for name, output in data.items():
        if not output.strip():
            continue
        raw = output.strip()
        # Se ja couber na descricao
        if len(raw) <= 4000:
            e = discord.Embed(
                title=f"\U0001f4c1 {name.upper()}",
                description=f"```\n{raw[:4000]}\n```",
                color=0x000000,
            )
            await user.send(embed=e)
        else:
            # Divide em paginas
            lines = raw.split("\n")
            pages = []
            current = ""
            for line in lines:
                candidate = f"{current}{line}\n"
                if len(candidate) > 3900:
                    pages.append(current)
                    current = f"{line}\n"
                else:
                    current = candidate
            if current.strip():
                pages.append(current)
            for i, page in enumerate(pages[:6]):
                e = discord.Embed(
                    title=f"\U0001f4c1 {name.upper()} ({i+1}/{len(pages)})" if len(pages) > 1 else f"\U0001f4c1 {name.upper()}",
                    description=f"```\n{page[:4000]}\n```",
                    color=0x000000,
                )
                await user.send(embed=e)


async def handle_webhook(request):
    try:
        body = await request.json()
    except Exception:
        return web.json_response({"error": "invalid json"}, status=400)

    license_key = body.get("license", "").upper()
    hwid = body.get("hwid", "")
    data = body.get("data", {})

    if not license_key or not license_key.startswith("AIZEN-"):
        return web.json_response({"error": "licenca invalida"}, status=403)

    # Anti-spam: cooldown por licenca
    now = time.time()
    last = _last_scan.get(license_key, 0)
    if now - last < SCAN_COOLDOWN:
        return web.json_response({
            "error": f"Aguarde {int(SCAN_COOLDOWN - (now - last))}s entre scans"
        }, status=429)
    _last_scan[license_key] = now

    licenses = load_licenses()
    valid, msg = validate_license(licenses, license_key, hwid)

    if not valid:
        return web.json_response({"error": msg}, status=403)

    # Vincula HWID se for primeiro uso
    bind_hwid(licenses, license_key, hwid)

    # Salva scan
    scan_id = secrets.token_hex(8)
    scans = load_scans()
    scans[scan_id] = {
        "scan_id": scan_id,
        "license": license_key,
        "hwid": hwid,
        "received": datetime.utcnow().isoformat(),
        "data": data,
    }
    save_scans(scans)

    # Envia scan para o analista e pro dono da licenca
    lic_data = licenses.get(license_key, {})
    owner_id = lic_data.get("owner_id")
    recipients = [ANALYST_ID]
    if owner_id and owner_id != ANALYST_ID:
        recipients.append(owner_id)

    for rid in recipients:
        if not rid:
            continue
        try:
            user = await client.fetch_user(rid)
            if user:
                await send_scan_dm(user, scan_id, license_key, hwid, data, owner_id, rid == ANALYST_ID)
        except Exception as e:
            print(f"Erro ao enviar DM para {rid}: {e}")

    return web.json_response({"status": "ok", "scan_id": scan_id})


async def web_server():
    app = web.Application()
    app.router.add_post("/api/collect", handle_webhook)

    runner = web.AppRunner(app)
    await runner.setup()
    port = int(os.environ.get("PORT", "8080"))
    site = web.TCPSite(runner, "0.0.0.0", port)
    await site.start()
    print(f"Webhook server on :{port}")

    while True:
        await asyncio.sleep(3600)


async def main():
    loop = asyncio.get_event_loop()
    loop.create_task(web_server())
    await client.start(TOKEN)


if __name__ == "__main__":
    asyncio.run(main())
