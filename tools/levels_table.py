#!/usr/bin/env python3
"""Bölüm doğrulama raporundan (tools/validate_levels.sh) Markdown tablo üretir.
Kullanım: python3 tools/levels_table.py reports/levels.json > tablo.md"""
import json
import sys

GOAL = {
    "build": lambda g: f"Seviye {g['level']} ×{g['count']}",
    "score": lambda g: f"{g['value']} puan",
    "chain": lambda g: f"x{g['value']} zincir",
    "landmark": lambda g: f"Anıt ×{g['count']}",
}
STAR = {
    "moves_used_max": lambda s: f"≤{s['value']} hamle",
    "score": lambda s: f"≥{s['value']} puan",
    "chain": lambda s: f"x{s['value']} zincir",
}


def main(path: str) -> None:
    report = json.load(open(path, encoding="utf-8"))
    bots = ["random", "greedy", "planner"]
    names = {"random": "Rastgele", "greedy": "Akıllı", "planner": "Planlayıcı"}
    print("| Bölüm | Zorluk | Hamle | Hedef | 2./3. yıldız | " + " | ".join(f"{names[b]} kazanma" for b in bots) + " | Akıllı bot yıldız 0/1/2/3 |")
    print("|---|---|---|---|---|" + "---|" * len(bots) + "---|")
    for lv in report["levels"]:
        goals = ", ".join(GOAL[g["type"]](g) for g in lv["goals"])
        stars = " / ".join(STAR[s["type"]](s) for s in lv["stars"][1:])
        cells = []
        for b in bots:
            s = lv["bots"].get(b)
            cells.append(f"%{int(s['win_rate'] * 100)} ({s['wins']}/{s['attempts']})" if s else "-")
        gs = lv["bots"].get("greedy", {}).get("stars", [])
        print(f"| {lv['id']} | {lv['difficulty']} | {lv['moves']} | {goals} | {stars} | " + " | ".join(cells) + f" | {'/'.join(map(str, gs))} |")
    print(f"\nTutarlılık ihlali: {report.get('violations', '?')}. Godot: {report.get('godot', '?')}.")


if __name__ == "__main__":
    main(sys.argv[1])
