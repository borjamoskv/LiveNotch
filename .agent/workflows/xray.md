---
description: Deep X-Ray scan of Notch Live codebase — architecture, complexity, and tech debt
---

# 🔬 X-Ray Scan — Notch Live

// turbo-all

## 1. File Count & Structure

```bash
echo "=== FILES BY MODULE ===" && find /Users/borjafernandezangulo/notch-live/Sources/LiveNotch -name "*.swift" | sed 's|.*/Sources/LiveNotch/||' | cut -d'/' -f1 | sort | uniq -c | sort -rn
```

## 2. Lines of Code per Module

```bash
echo "=== LOC PER MODULE ===" && for dir in AI App Core Features Services Views Utilities; do echo -n "$dir: "; find /Users/borjafernandezangulo/notch-live/Sources/LiveNotch/$dir -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'; done
```

## 3. Largest Files (complexity indicators)

```bash
echo "=== TOP 15 LARGEST FILES ===" && find /Users/borjafernandezangulo/notch-live/Sources/LiveNotch -name "*.swift" -exec wc -l {} + | sort -rn | head -16
```

## 4. TODO/FIXME/HACK scan

```bash
echo "=== TECH DEBT MARKERS ===" && grep -rn "TODO\|FIXME\|HACK\|XXX\|WORKAROUND" /Users/borjafernandezangulo/notch-live/Sources/LiveNotch --include="*.swift" | head -30
```

## 5. Force unwrap audit

```bash
echo "=== FORCE UNWRAPS ===" && grep -rn '!\.' /Users/borjafernandezangulo/notch-live/Sources/LiveNotch --include="*.swift" | grep -v '//' | head -20
```
