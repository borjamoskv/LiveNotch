# 🔮 Plan: Glass Mode + Kimi API Integration — Live Notch

## Estado actual

### ✅ Ya completado (esta sesión)
- **Settings panel** — Nuevo panel con toggles para Liquid Glass, Eye Control, Haptic Feedback, Recalibrate Eyes, versión de app, y botón Quit.
- **Eye Control panel** — Mejorado con: barra de progreso de calibración, selector de sensibilidad (Sensitive/Normal/Relaxed), anillo de cooldown visual, contador de gestos, y estados condicionales (calibrando vs calibrado).
- **HapticManager** — Añadidos `isEnabled` (persistido en UserDefaults) y tipo `.subtle`.

---

## 🔹 Fase 1: Mejorar Liquid Glass Mode

### 1A. Efecto Glass más realista
**Qué hace ahora:** Simple blur + overlay negro 25% + tint del álbum al 8%.
**Qué debería hacer:**
- [ ] **Specular highlight** — Un brillo tenue en el borde superior que simule reflexión de luz, se mueve sutilmente con hover del ratón
- [ ] **Frosted edge** — Borde inferior con un gradient suave que simule profundidad del cristal  
- [ ] **Refraction shift** — Cuando el mouse se mueve sobre el notch, el blur del fondo se desplaza ligeramente en la dirección opuesta (efecto lente)
- [ ] **Intensidad adaptativa** — En modo Glass, la opacidad del overlay se ajusta según la luminosidad del wallpaper detectado

### 1B. Settings para Glass Mode
- [ ] **Glass Intensity slider** — En Settings, controlar la opacidad del blur (0.1 - 0.5)
- [ ] **Glass Tint toggle** — Activar/desactivar el tinte del álbum art sobre el glass
- [ ] **Border Glow toggle** — Activar/desactivar el glow en los bordes cuando Glass está activo

### 1C. Animación de transición Glass ↔ Opaco
- [ ] Transición suave con `matchedGeometryEffect` o interpolación custom al cambiar entre Glass ON/OFF desde Settings

---

## 🔹 Fase 2: Ideas para Kimi API (262K tokens context)

### ¿Qué puede hacer Kimi que otros no?
| Capacidad | Valor para Live Notch |
|---|---|
| **262K tokens de contexto** | Analizar archivos completos, logs largos |
| **Entrada de imagen** (`image_in`) | Procesar screenshots, OCR avanzado |
| **Entrada de vídeo** (`video_in`) | Analizar clips, screen recordings |
| **Thinking mode** | Razonamiento profundo para sugerencias |
| **100 tokens/s** | Respuestas rápidas para UI |

### 2A. 🧠 Brain Dump con AI (via Kimi)
**Concepto:** El Brain Dump actual categoriza notas manualmente con prefijos. Con Kimi:
- [ ] **Auto-categorización inteligente** — Enviar el texto de la nota a Kimi para que determine categoría y prioridad automáticamente
- [ ] **Resumen diario** — Al final del día, Kimi genera un resumen de todas las notas capturadas
- [ ] **Extracción de tareas** — Kimi detecta "action items" en texto libre y los convierte en items de Brain Dump

### 2B. 📸 Smart Screenshot (via Kimi image_in)
**Concepto:** Capturar screenshot y enviar a Kimi para análisis:
- [ ] **OCR + contexto** — No solo extraer texto de la pantalla, sino entenderlo (e.g. "es un error de compilación, el fix es X")
- [ ] **Describe lo que ves** — Pequeño widget en el notch que describe qué hay en pantalla
- [ ] **Code explain** — Hacer screenshot del IDE → Kimi explica el código en un tooltip del notch

### 2C. 🎵 Smart Music Context
**Concepto:** Usar Kimi para enriquecer la experiencia musical:
- [ ] **Mood detection** — Basado en el nombre de canción/artista, sugerir un color de tema para el notch
- [ ] **Similar songs** — Al hacer hover sobre el álbum art, mostrar sugerencias de canciones similares
- [ ] **Letras on-demand** — Pedir letra de la canción actual vía Kimi

### 2D. 💡 AI Quick Actions (lo más impactante)
**Concepto:** Un mini-prompt en el notch expanded que envía consultas rápidas a Kimi:
- [ ] **Quick Ask** — Campo de texto en el panel expandido, respuesta en tooltip/popup
- [ ] **Clipboard AI** — Botón "AI" en el Clipboard Manager que explica/traduce/resume el texto copiado
- [ ] **Code Review** — Pegar código → Kimi da feedback instantáneo

### 2E. 📊 System Insights con AI
**Concepto:** Kimi analiza los datos del System Monitor:
- [ ] **Anomaly detection** — "Tu CPU lleva 10 min al 95%, posible causa: proceso X"
- [ ] **Battery advisor** — "Con este uso, te quedan ~2h. Recomiendo cerrar Chrome"
- [ ] **Memory suggestions** — "Tienes 3 apps usando 2GB+ de RAM cada una, ¿quieres optimizar?"

---

## 🔹 Fase 3: Implementación técnica de Kimi

### Arquitectura propuesta
```
LiveNotch
├── KimiService.swift          // Singleton, maneja conexión con Kimi CLI
│   ├── query(prompt:) → String    // Via subprocess a `kimi`
│   ├── analyzeImage(NSImage) → String  // image_in via pipe
│   └── isAvailable: Bool         // Check if kimi CLI is installed
│
├── Settings panel
│   └── "AI Assistant" toggle + status (Kimi available/not)
│
└── Integration points
    ├── BrainDump → auto-categorize
    ├── Clipboard → explain/translate
    └── Quick Ask → mini prompt
```

### Limitaciones a considerar
- **Kimi CLI usa OAuth via keyring** — No requiere API key, pero el usuario debe tener `kimi` instalado y autenticado
- **Latencia** — Las llamadas a Kimi toman 1-3 segundos, necesitamos spinners y async
- **Quota** — Se renueva cada 7 días, no abusar con auto-queries frecuentes
- **Privacy** — El usuario debe opt-in a enviar datos (screenshots, clipboard) a Kimi

---

## Priorización recomendada

| # | Feature | Impacto | Esfuerzo | Prioridad |
|---|---------|---------|----------|-----------|
| 1 | Glass specular + frosted edge | ⭐⭐⭐ | Bajo | 🟢 Hacer ahora |
| 2 | Glass Intensity slider en Settings | ⭐⭐ | Bajo | 🟢 Hacer ahora |
| 3 | KimiService.swift base | ⭐⭐⭐⭐ | Medio | 🟡 Siguiente |
| 4 | Clipboard AI (explain/translate) | ⭐⭐⭐⭐⭐ | Medio | 🟡 Siguiente |
| 5 | Quick Ask mini-prompt | ⭐⭐⭐⭐ | Medio | 🟡 Siguiente |
| 6 | Brain Dump auto-categorize | ⭐⭐⭐ | Bajo | 🟡 Siguiente |
| 7 | Smart Screenshot | ⭐⭐⭐ | Alto | 🔵 Futuro |
| 8 | System Insights | ⭐⭐ | Alto | 🔵 Futuro |
| 9 | Music context | ⭐⭐ | Medio | 🔵 Futuro |

---

## Decisiones pendientes del usuario

1. **¿Empezamos con Glass visual (Fase 1) o Kimi integration (Fase 2)?**
2. **¿Qué features de Kimi te interesan más?** (Clipboard AI, Quick Ask, Brain Dump AI, Screenshots)
3. **¿Tienes `kimi` CLI instalado y autenticado?** (Necesario para la integración)
