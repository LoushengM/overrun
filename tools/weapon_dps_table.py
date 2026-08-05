#!/usr/bin/env python3
"""Print base sustained-DPS per weapon straight from game_config.gd.

The balance question for the four newer weapons is whether their opening
numbers sit in the same band as the stock four. Hardcoding the values here
would drift the moment someone edits the config, so parse the constants
instead and apply the same uptime factors _estimated_sustained_dps uses.
"""
import re
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src" / "game_config.gd"


def load_constants() -> dict[str, float]:
    text = CONFIG.read_text()
    out: dict[str, float] = {}
    for name, value in re.findall(r"^const ([A-Z0-9_]+) := (-?[\d.]+)$", text, re.M):
        out[name] = float(value)
    return out


def main() -> int:
    c = load_constants()
    missing = []

    def get(key: str) -> float:
        if key not in c:
            missing.append(key)
            return 0.0
        return c[key]

    rows: list[tuple[str, float, str]] = []

    rows.append((
        "Needle",
        get("NEEDLE_DAMAGE") / get("NEEDLE_COOLDOWN"),
        "single target",
    ))
    rows.append((
        "Longshot",
        get("SNIPER_DAMAGE") / get("SNIPER_COOLDOWN"),
        "single target, long range",
    ))
    rows.append((
        "Aura Pulse",
        get("AURA_DAMAGE") / get("AURA_COOLDOWN") * get("AURA_DPS_UPTIME_FACTOR"),
        "melee ring, all targets",
    ))
    field_equivalents = min(
        get("FIELD_DPS_MAX_EQUIVALENTS"),
        get("FIELD_DURATION") / get("FIELD_COOLDOWN") * get("FIELD_DPS_OVERLAP_FACTOR"),
    )
    rows.append((
        "Mire Field",
        get("FIELD_DAMAGE") / get("FIELD_TICK_INTERVAL") * field_equivalents,
        "zone, all targets, slows",
    ))

    chain_multiplier = 1.0
    jump_scale = 1.0
    for _ in range(int(get("CHAIN_JUMPS"))):
        jump_scale *= get("CHAIN_FALLOFF")
        chain_multiplier += jump_scale
    rows.append((
        "Arc Chain",
        get("CHAIN_DAMAGE") * chain_multiplier / get("CHAIN_COOLDOWN") * get("CHAIN_DPS_UPTIME_FACTOR"),
        "multi target, %.2fx chain" % chain_multiplier,
    ))
    rows.append((
        "Flak Burst",
        get("FLAK_DAMAGE") * get("FLAK_PELLETS") / get("FLAK_COOLDOWN") * get("FLAK_DPS_UPTIME_FACTOR"),
        "cone, close range only",
    ))
    rows.append((
        "Orbital",
        get("ORBITAL_DAMAGE") * get("ORBITAL_COUNT") / get("ORBITAL_HIT_INTERVAL") * get("ORBITAL_DPS_UPTIME_FACTOR"),
        "passive, no aiming",
    ))
    rows.append((
        "Detonator",
        get("DETONATOR_DAMAGE") / get("DETONATOR_COOLDOWN") * get("DETONATOR_DPS_UPTIME_FACTOR"),
        "blast, all targets in radius",
    ))

    if missing:
        print("missing constants: %s" % ", ".join(sorted(set(missing))), file=sys.stderr)
        return 1

    rows.sort(key=lambda row: row[1], reverse=True)
    width = max(len(row[0]) for row in rows)
    print("%-*s  %8s  %s" % (width, "weapon", "base dps", "shape"))
    for name, dps, shape in rows:
        print("%-*s  %8.1f  %s" % (width, name, dps, shape))

    best = rows[0][1]
    worst = rows[-1][1]
    print()
    print("spread: %.1f to %.1f (%.2fx)" % (worst, best, best / max(0.01, worst)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
