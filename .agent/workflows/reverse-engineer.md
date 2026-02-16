---
description: DISEKTV-1 — Protocolo soberano de ingeniería inversa ética. Diseccionar apps, APIs, protocolos y codebases en intelligence accionable.
---

# 🔬 DISEKTV-1 v2.0: Quick Reference

> Full spec: `~/.gemini/antigravity/skills/reverse-engineer/SKILL.md`

// turbo-all

## 1. Snapshot Primero (SIEMPRE)

```
disekt-snapshot [target]
```
- [ ] Verificar licencia → CLEAR / RESTRICTED
- [ ] Clasificar T-level (T1 Surface → T4 Abyss)
- [ ] Detectar stack con confidence [C1-C5]
- [ ] Estimar time budget
- [ ] Listar 3-5 puntos de entrada para análisis profundo

## 2. Elegir Protocolo

| Target | Comando | Time Budget |
|:---|:---|:---:|
| App compilada o web compleja | `disekt-app [name]` | T1: 30m → T4: 3d |
| API / Web Service | `disekt-api [url]` | T1: 30m → T3: 8h |
| Protocolo / Formato binario | `disekt-protocol [name]` | T2: 2h → T4: 3d |
| Codebase con source code | `disekt-codebase [repo]` | T1: 30m → T3: 8h |

## 3. Confidence Tags (obligatorio en cada hallazgo)

| Grado | Símbolo | Significado |
|:---:|:---:|:---|
| C5 | 🟢 | Confirmado (múltiples fuentes) |
| C4 | 🔵 | Probable (alta evidencia) |
| C3 | 🟡 | Inferido (patrón consistente) |
| C2 | 🟠 | Especulativo (indicios débiles) |
| C1 | 🔴 | Hipótesis pura (sin evidencia) |

## 4. Signal Detection (buscar siempre primero)

```
→ Error messages → stack, DB, framework
→ HTTP headers → Server, X-Powered-By
→ URL patterns → REST conventions, ID format
→ Auth tokens → JWT dots, API key hex
→ Naming → camelCase=JS, snake_case=Python
→ Loading skeletons → component structure
→ Analytics events → feature names + user flows
```

## 5. Power Moves

```bash
disekt-steal [app]        # Extraer design principles (NO código)
disekt-ghost [feature]    # Re-implementar feature desde cero
disekt-xray [app] --feature [name]  # Deep scan de una feature
disekt-diff [target] v1 → v2        # Comparar versiones
disekt-compete [mi-app] vs [rival]  # Análisis competitivo
```

## 6. herramientas Rápidas

```bash
# macOS app inspection
otool -L /Applications/App.app/Contents/MacOS/App
strings /Applications/App.app/Contents/MacOS/App | grep -iE 'api|http|key|token'
codesign -d --entitlements :- /Applications/App.app
plutil -p /Applications/App.app/Contents/Info.plist

# Web API probing
curl -sI https://api.example.com/health | head -20
curl -s https://api.example.com/v1/users | jq '.'

# Network monitoring
sudo fs_usage -w -f network $(pgrep AppName)
nettop -p $(pgrep AppName)

# Codebase archeology
tokei --sort code .
git log --oneline -30
git shortlog -sn
```

## 7. Guardar en CORTEX

```bash
cd ~/cortex && .venv/bin/python -m cortex.cli store \
  --scope [project] \
  --type knowledge \
  --tags reverse-engineer,disekt,[target-name] \
  --content "[C5] 🟢 [hallazgo key]: [detalle]"
```

## Reglas Inquebrantables

1. **License check** ANTES de tocar nada
2. **Snapshot** ANTES de análisis profundo
3. **[C1-C5]** en CADA hallazgo
4. **Documentar** en tiempo real, nunca al final
5. **Ghost ≠ Clone** — scope mínimo, siempre
6. **El ghost DEBE superar al original** (MEJORAlo pass obligatorio)
