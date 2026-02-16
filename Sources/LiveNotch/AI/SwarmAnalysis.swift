import Foundation

// MARK: - Swarm Analysis & Logic
// Encapsulates the analysis and response generation logic for the swarm
struct SwarmAnalysis {

    /// Classify what the user actually wants
    enum QueryIntent {
        case howTo, debugging, comparison, optimization, general
    }

    /// Classify query intent based on keywords
    static func classifyQueryIntent(_ q: String) -> QueryIntent {
        if q.contains("cómo") || q.contains("how") || q.contains("crear") || q.contains("create") || q.contains("hacer") || q.contains("build") || q.contains("implementar") {
            return .howTo
        }
        if q.contains("error") || q.contains("fix") || q.contains("bug") || q.contains("crash") || q.contains("falla") || q.contains("problema") || q.contains("no funciona") || q.contains("debug") {
            return .debugging
        }
        if q.contains("vs") || q.contains("mejor") || q.contains("diferencia") || q.contains("compare") || q.contains("which") || q.contains("cuál") {
            return .comparison
        }
        if q.contains("optimiz") || q.contains("rápido") || q.contains("faster") || q.contains("performance") || q.contains("rendimiento") || q.contains("mejorar") || q.contains("improve") {
            return .optimization
        }
        return .general
    }

    /// Parse real clipboard content — detect language, patterns, issues
    static func analyzeClipboard(_ content: String?, domain: String, keywords: [String]) -> String? {
        guard let clip = content, clip.count > 15 else { return nil }
        let clipLower = clip.lowercased()

        // Only analyze if clipboard is relevant to this agent's domain
        let relevantHits = keywords.filter { clipLower.contains($0) }.count
        guard relevantHits > 0 else { return nil }

        var analysis: [String] = []
        let lines = clip.components(separatedBy: .newlines)
        let lineCount = lines.count

        // Detect language from actual code patterns
        if clipLower.contains("func ") && clipLower.contains("->") || clipLower.contains("@State") || clipLower.contains("var body") {
            analysis.append("Lenguaje detectado: **Swift**")
            if clipLower.contains("@State") || clipLower.contains("@Published") {
                analysis.append("• SwiftUI state management detectado")
            }
            if clipLower.contains("Task {") || clipLower.contains("async ") {
                analysis.append("• Código async/await detectado")
            }
            if clipLower.contains("try") && !clipLower.contains("catch") && !clipLower.contains("try?") && !clipLower.contains("try!") {
                analysis.append("⚠️ `try` sin `catch` — posible crash")
            }
        } else if clipLower.contains("def ") || (clipLower.contains("import ") && clipLower.contains(":")) {
            analysis.append("Lenguaje detectado: **Python**")
            if clipLower.contains("except:") || clipLower.contains("except Exception") {
                analysis.append("⚠️ Catch genérico — mejor especificar excepción")
            }
        } else if clipLower.contains("const ") || clipLower.contains("=>") || clipLower.contains("require(") {
            analysis.append("Lenguaje detectado: **JavaScript/TypeScript**")
            if clipLower.contains("var ") {
                analysis.append("⚠️ `var` detectado — usa `const` o `let`")
            }
            if clipLower.contains("any") {
                analysis.append("⚠️ `any` detectado — perdida de type safety")
            }
        } else if clipLower.contains("fn ") && clipLower.contains("let ") {
            analysis.append("Lenguaje detectado: **Rust**")
            if clipLower.contains("unwrap()") {
                analysis.append("⚠️ `.unwrap()` detectado — usa `?` o `match` en producción")
            }
        }

        // Generic code quality signals
        if lineCount > 50 {
            analysis.append("📏 \(lineCount) líneas — considera dividir en funciones más pequeñas")
        }
        if clipLower.contains("todo") || clipLower.contains("fixme") || clipLower.contains("hack") {
            analysis.append("📌 TODOs/FIXMEs encontrados en el código")
        }
        if clipLower.contains("print(") || clipLower.contains("console.log") || clipLower.contains("NSLog") {
            analysis.append("🧹 Debug prints detectados — limpiar antes de producción")
        }
        if clipLower.contains("force") || clipLower.contains("!") && clipLower.contains("as!") {
            analysis.append("⚠️ Force unwrap/cast detectado — riesgo de crash")
        }

        return analysis.isEmpty ? nil : analysis.joined(separator: "\n")
    }

    /// Generate REAL step-by-step guidance based on matched keywords
    static func generateRealGuidance(for keywords: [String], domain: String, species: String) -> String {
        var steps: [String] = []

        // Code domain — real patterns per language/framework
        if species.hasPrefix("code.") {
            for kw in keywords {
                switch kw {
                case "swift", "swiftui":
                    steps.append("1. Estructura: `@Observable` class (macOS 14+) > `@Published`")
                    steps.append("2. Views: `some View` con `@State` local, `@Binding` para child")
                    steps.append("3. Networking: `async let` para paralelo, `URLSession.shared.data(from:)`")
                    steps.append("4. Errores: `do/catch` con tipos específicos, nunca `try!` en prod")
                case "react", "jsx", "hook":
                    steps.append("1. `useState` para estado local, `useReducer` para estado complejo")
                    steps.append("2. `useEffect` con deps array correcto — evitar arrays vacíos si hay deps")
                    steps.append("3. `useMemo`/`useCallback` solo cuando hay re-renders medidos")
                    steps.append("4. Server Components (Next.js 14+) para datos, Client para interactividad")
                case "python", "django", "flask":
                    steps.append("1. Type hints: `def func(x: int) -> str:` — siempre")
                    steps.append("2. `dataclass` o `pydantic.BaseModel` para estructuras de datos")
                    steps.append("3. `pathlib.Path` > `os.path` — más expresivo y seguro")
                    steps.append("4. `uv` > `pip` para gestión de dependencias (10x más rápido)")
                case "docker", "container":
                    steps.append("1. Multi-stage build: `FROM node:20 AS builder` → `FROM node:20-slim`")
                    steps.append("2. `.dockerignore`: `node_modules`, `.git`, `*.md`")
                    steps.append("3. `COPY package*.json .` ANTES de `COPY . .` (cache de deps)")
                    steps.append("4. `USER nonroot` — nunca correr como root en producción")
                case "kubernetes", "k8s":
                    steps.append("1. `resources.requests` y `limits` siempre definidos")
                    steps.append("2. `livenessProbe` + `readinessProbe` para health checks")
                    steps.append("3. `HPA` para autoescalado basado en CPU/memoria")
                    steps.append("4. `NetworkPolicy` para segmentar tráfico entre pods")
                case "git":
                    steps.append("1. Commits: tipo(scope): mensaje — `feat(auth): add OAuth2 flow`")
                    steps.append("2. Branches: `feature/`, `fix/`, `chore/` prefijos")
                    steps.append("3. `git rebase -i` para limpiar historial antes de PR")
                    steps.append("4. Pre-commit hooks: lint + format automático")
                default:
                    steps.append("• Analiza el contexto de \(kw) en tu proyecto actual")
                    steps.append("• Revisa patrones idiomáticos del ecosistema")
                }
            }
        } else if species.hasPrefix("creative.") {
            for kw in keywords {
                switch kw {
                case "ableton", "live", "audio":
                    steps.append("1. Ganancia de staging: -6dB headroom en master")
                    steps.append("2. EQ sustractivo primero, aditivo después")
                    steps.append("3. Compresión: ratio 3:1 para bus, 4:1+ para drums")
                    steps.append("4. Sidechain: Compressor > External Key > kick track")
                case "figma", "design":
                    steps.append("1. Auto Layout para todo — responsive desde el principio")
                    steps.append("2. Design tokens: colores, tipografía, espaciado como variables")
                    steps.append("3. Components con variants (state × size × theme)")
                    steps.append("4. Prototype: Smart Animate entre components para micro-interactions")
                case "midjourney", "stable diffusion", "prompt":
                    steps.append("1. Estructura: sujeto + estilo + iluminación + cámara + calidad")
                    steps.append("2. `--ar 16:9` para panorámico, `--ar 1:1` para cuadrado")
                    steps.append("3. `--style raw` para menos procesamiento de Midjourney")
                    steps.append("4. Negative: `blurry, deformed, low quality, watermark`")
                default:
                    steps.append("• Aplica principios de \(kw) a tu flujo creativo")
                }
            }
        } else if species.hasPrefix("infra.") {
            for kw in keywords {
                switch kw {
                case "ci", "cd", "pipeline":
                    steps.append("1. Build → Test → Lint → Security Scan → Deploy")
                    steps.append("2. Cache de dependencias entre runs (ahorra 60% tiempo)")
                    steps.append("3. Matrix testing: múltiples versiones en paralelo")
                    steps.append("4. Deploy: canary 5% → 25% → 100% (nunca 0 → 100)")
                case "monitoring", "observability":
                    steps.append("1. RED metrics: Rate, Errors, Duration por servicio")
                    steps.append("2. Logs estructurados JSON con correlation IDs")
                    steps.append("3. Distributed tracing con OpenTelemetry")
                    steps.append("4. Alertas por SLOs, no por síntomas individuales")
                case "terraform", "iac":
                    steps.append("1. Remote state: S3 + DynamoDB lock")
                    steps.append("2. Modules: reutilizables, versionados, documentados")
                    steps.append("3. `plan` SIEMPRE antes de `apply`")
                    steps.append("4. Workspaces para separar dev/staging/prod")
                default:
                    steps.append("• Revisa tu setup de \(kw) contra best practices actuales")
                }
            }
        } else if species.hasPrefix("well.") {
            steps.append("1. 🫁 Respiración 4-7-8: Inhala 4s → Mantén 7s → Exhala 8s")
            steps.append("2. 🧊 Agua fría en muñecas → alerta instantánea")
            steps.append("3. 🚶 5 min caminando → 2 horas más de foco")
            steps.append("4. 👁️ Regla 20-20-20: cada 20min, mira 20s a 20 metros")
        }

        if steps.isEmpty {
            steps.append("Describe tu caso específico para guía detallada")
        }

        return "\n" + steps.prefix(5).joined(separator: "\n")
    }

    /// Generate REAL debugging advice
    static func generateDebuggingAdvice(for keywords: [String], domain: String, clipboard: String?) -> String {
        var advice: [String] = []

        advice.append("1. **Reproduce** — aisla el caso mínimo que produce el error")
        advice.append("2. **Lee** el error completo — stack trace, línea, contexto")

        if keywords.contains("swift") || keywords.contains("swiftui") {
            advice.append("3. `po variable` en LLDB para inspeccionar estado")
            advice.append("4. `Thread Sanitizer` para race conditions")
            advice.append("5. `Instruments > Time Profiler` para performance")
        } else if keywords.contains("javascript") || keywords.contains("react") || keywords.contains("node") {
            advice.append("3. `console.trace()` para ver call stack completo")
            advice.append("4. Chrome DevTools > Sources > breakpoints condicionales")
            advice.append("5. `node --inspect` + Chrome DevTools para Node.js")
        } else if keywords.contains("python") {
            advice.append("3. `import pdb; pdb.set_trace()` o `breakpoint()` (3.7+)")
            advice.append("4. `python -m pytest -x --pdb` para debuggear en tests")
            advice.append("5. `traceback.format_exc()` para logs detallados")
        } else {
            advice.append("3. Usa el debugger nativo de tu IDE")
            advice.append("4. Añade logging temporal para trazar el flujo")
            advice.append("5. Revisa cambios recientes con `git diff`")
        }

        if clipboard != nil {
            advice.append("\n📋 El clipboard contiene información relevante — revisa el análisis abajo")
        }

        return "\n" + advice.joined(separator: "\n")
    }

    /// Generate REAL comparison advice
    static func generateComparisonAdvice(for keywords: [String], domain: String) -> String {
        var analysis: [String] = []

        // Find pairs to compare from keywords
        let kwSet = Set(keywords)
        if kwSet.contains("react") || kwSet.contains("vue") {
            analysis.append("**React vs Vue:**")
            analysis.append("• React: ecosistema mayor, más control, JSX")
            analysis.append("• Vue: curva más suave, SFC, template syntax")
            analysis.append("• Para equipos nuevos: Vue. Para scale: React.")
        }
        if kwSet.contains("docker") || kwSet.contains("kubernetes") {
            analysis.append("**Docker vs Kubernetes:**")
            analysis.append("• Docker: empaquetar. K8s: orquestar.")
            analysis.append("• <5 contenedores: Docker Compose basta")
            analysis.append("• >10 servicios con autoescalado: K8s")
        }
        if kwSet.contains("rest") || kwSet.contains("graphql") {
            analysis.append("**REST vs GraphQL:**")
            analysis.append("• REST: simple, cacheable, estándar")
            analysis.append("• GraphQL: flexible, menos over-fetching")
            analysis.append("• CRUD simple: REST. Datos complejos/nested: GraphQL")
        }

        if analysis.isEmpty {
            analysis.append("Especifica qué tecnologías quieres comparar para un análisis detallado de \(domain)")
        }

        return "\n" + analysis.joined(separator: "\n")
    }

    /// Generate REAL optimization advice
    static func generateOptimizationAdvice(for keywords: [String], domain: String) -> String {
        var tips: [String] = []

        if keywords.contains("swift") || keywords.contains("swiftui") {
            tips.append("1. `Instruments > Time Profiler` — mide antes de optimizar")
            tips.append("2. `@State` solo en la view que lo necesita — evita re-renders")
            tips.append("3. `EquatableView` o `.equatable()` para skip de render")
            tips.append("4. `LazyVStack/LazyHStack` para listas largas")
            tips.append("5. `nonisolated` para métodos que no tocan UI")
        } else if keywords.contains("react") || keywords.contains("javascript") {
            tips.append("1. React DevTools Profiler — identifica re-renders innecesarios")
            tips.append("2. `React.memo()` + `useMemo` para computaciones caras")
            tips.append("3. `dynamic import()` para code splitting")
            tips.append("4. `Intersection Observer` > scroll events")
            tips.append("5. `requestIdleCallback` para tareas no urgentes")
        } else if keywords.contains("python") {
            tips.append("1. `cProfile` o `py-spy` para profiling")
            tips.append("2. `numpy`/`pandas` vectorización > loops")
            tips.append("3. `functools.lru_cache` para memoización")
            tips.append("4. `asyncio.gather()` para I/O paralelo")
            tips.append("5. `__slots__` en clases para reducir memoria")
        } else if keywords.contains("docker") || keywords.contains("kubernetes") {
            tips.append("1. Multi-stage builds (imagen 60-80% más pequeña)")
            tips.append("2. `--no-cache` solo cuando necesario")
            tips.append("3. Alpine/Distroless como base image")
            tips.append("4. Health checks para restart automático")
            tips.append("5. Resource limits para evitar noisy neighbors")
        } else {
            tips.append("1. **Mide primero** — nunca optimices sin datos")
            tips.append("2. Identifica el cuello de botella real")
            tips.append("3. Optimiza el hot path, no todo")
            tips.append("4. Cache donde sea posible")
            tips.append("5. Paraleliza I/O, no CPU")
        }

        return "\n" + tips.joined(separator: "\n")
    }
}
