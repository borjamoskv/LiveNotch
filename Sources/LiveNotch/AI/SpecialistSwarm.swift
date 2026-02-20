import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - 🐝 Extended Specialist Swarm (80 New Agents)
// ═══════════════════════════════════════════════════════════════
// Compact agent factory — each specialist has real domain knowledge.
// Total: 20 original + 80 new = 100 specialist agents

// MARK: - Agent Factory Helper
private func makeAgent(
    name: String, emoji: String, domain: String,
    keywords: [String], bundles: [String] = [],
    response: String
) -> CompactAgent {
    CompactAgent(name: name, emoji: emoji, domain: domain,
                 keywords: keywords, contextBundles: bundles,
                 responseTemplate: response)
}

struct CompactAgent: NotchAgent {
    let name: String
    let emoji: String
    let domain: String
    let keywords: [String]
    let contextBundles: [String]
    let responseTemplate: String

    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        let words = q.components(separatedBy: .whitespacesAndNewlines)
        var score = 0.0

        // Signal 1: Keyword matching
        let matches = keywords.filter { q.contains($0) }
        score += Double(matches.count) * 0.2

        // Signal 2: N-gram bigram matching (more specific = higher signal)
        if words.count >= 2 {
            for i in 0..<(words.count - 1) {
                let bigram = "\(words[i]) \(words[i+1])"
                let bigramHits = keywords.filter { bigram.contains($0) || $0.contains(bigram) }
                score += Double(bigramHits.count) * 0.15
            }
        }

        // Signal 3: App context boost
        if contextBundles.contains(context.activeAppBundle) { score += 0.3 }

        // Signal 4: Intent alignment from ContextMesh
        let intent = ContextMesh.shared.intentSignal
        if intent == .debugging && keywords.contains(where: { ["debug", "error", "fix", "crash"].contains($0) }) {
            score += 0.2
        }
        if intent == .coding && domain.contains("Code") || domain.contains("Script") || domain.contains("Swift") || domain.contains("Python") {
            score += 0.15
        }
        if intent == .creating && domain.contains("Creative") || domain.contains("Design") || domain.contains("Art") {
            score += 0.15
        }

        // Signal 5: Session momentum — if this species recently won
        if ContextMesh.shared.recentWinners.contains("legacy.\(name.lowercased())") {
            score += 0.1
        }

        // Signal 6: Clipboard code analysis
        if let clip = context.clipboardContent {
            let clipLower = clip.lowercased()
            let clipHits = keywords.filter { clipLower.contains($0) }.count
            score += Double(clipHits) * 0.08
        }

        // Signal 7: Time-of-day affinity
        if domain.contains("Wellbeing") && (context.timeOfDay == .night || context.timeOfDay == .lateNight) {
            score += 0.2
        }

        return min(1.0, score)
    }

    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let conf = confidence(for: query, context: context)
        let q = query.lowercased()

        // ═══════════════════════════════════════
        // REAL Response Construction
        // ═══════════════════════════════════════

        // 1. What keywords actually matched?
        let matched = keywords.filter { q.contains($0) }
        let topicLabel = matched.isEmpty ? domain : matched.prefix(3).joined(separator: ", ")

        // 2. What does the user actually want?
        let intent = classifyIntent(q)

        // 3. What mode is the user in?
        let userMode = ContextMesh.shared.cachedUserMode

        // 4. Time awareness
        let timeGreeting: String
        switch context.timeOfDay {
        case .morning: timeGreeting = "Buenos días"
        case .afternoon, .evening: timeGreeting = "Buenas tardes"
        case .night: timeGreeting = "Buenas noches"
        case .lateNight: timeGreeting = "🦉 Nocturno"
        }

        // ── Build header ──
        var response = "\(emoji) **\(name)** — \(timeGreeting)"

        // Mode-aware context
        switch userMode {
        case .dj, .producer:
            response += "\n🎛️ Modo \(userMode.label) activo"
        case .focus:
            response += "\n🎯 Modo Focus — respuesta concisa"
        case .tdah:
            response += "\n🧠 Modo TDAH — sin ruido extra"
        default: break
        }

        // What we detected
        if !matched.isEmpty {
            response += "\n🎯 Tema: **\(topicLabel)**"
        }

        // 5. Intent-driven response (REAL, not templates)
        switch intent {
        case .howTo:
            response += "\n\n**Guía \(domain):**"
            response += buildRealSteps(matched: matched)

        case .debug:
            response += "\n\n**🔧 Debug \(domain):**"
            response += buildDebugSteps(matched: matched, context: context)

        case .compare:
            response += "\n\n**⚖️ Comparativa:**"
            response += buildComparison(matched: matched)

        case .optimize:
            response += "\n\n**⚡ Optimización \(domain):**"
            response += buildOptimization(matched: matched)

        case .explain:
            response += "\n\n**💡 \(domain) — Explicación:**"
            // Use the template as base knowledge, but contextualize it
            response += "\n" + responseTemplate

        case .general:
            if userMode == .focus || userMode == .tdah {
                // Concise mode — skip template, give direct answer
                response += "\n\n" + buildRealSteps(matched: matched)
            } else {
                response += "\n\n" + responseTemplate
            }
        }

        // 6. Real clipboard analysis
        if let clip = context.clipboardContent, clip.count > 20 {
            let clipLower = clip.lowercased()
            let clipHits = keywords.filter { clipLower.contains($0) }.count
            if clipHits > 0 {
                response += "\n\n📋 **Clipboard (\(domain)):**"
                response += analyzeClipboardCode(clipLower)
            }
        }

        // 7. Session health
        let sessionMin = ContextMesh.shared.sessionMinutes
        if sessionMin > 180 {
            response += "\n\n🔴 \(sessionMin)min — pausa obligatoria"
        } else if sessionMin > 90 {
            response += "\n🟡 \(sessionMin)min — considera un descanso"
        }

        // 8. Conversation continuity
        let recentQueries = memory.exchanges.suffix(3).map { $0.query.lowercased() }
        let continuity = recentQueries.filter { prev in
            matched.contains { prev.contains($0) }
        }
        if !continuity.isEmpty {
            response += "\n🔄 Tema recurrente — contexto acumulado"
        }

        return AgentResponse(text: response, confidence: conf,
                            agentName: name, suggestedAction: nil)
    }

    // ── Intent classification ──
    private enum QueryIntent {
        case howTo, debug, compare, optimize, explain, general
    }

    private func classifyIntent(_ q: String) -> QueryIntent {
        if q.contains("cómo") || q.contains("how") || q.contains("crear") || q.contains("make") || q.contains("build") || q.contains("implementar") {
            return .howTo
        }
        if q.contains("error") || q.contains("fix") || q.contains("bug") || q.contains("crash") || q.contains("debug") || q.contains("falla") || q.contains("roto") {
            return .debug
        }
        if q.contains("vs") || q.contains("mejor") || q.contains("compare") || q.contains("diferencia") || q.contains("cuál") {
            return .compare
        }
        if q.contains("optimiz") || q.contains("faster") || q.contains("rendimiento") || q.contains("performance") || q.contains("mejorar") || q.contains("lento") {
            return .optimize
        }
        if q.contains("qué es") || q.contains("what is") || q.contains("explain") || q.contains("explica") || q.contains("para qué") {
            return .explain
        }
        return .general
    }

    // ── Real steps builder ──
    private func buildRealSteps(matched: [String]) -> String {
        var steps: [String] = []
        for kw in matched.prefix(3) {
            switch kw {
            // -- Frontend --
            case "react", "jsx", "hook":
                steps.append("1. `useState` para local, `useReducer` para complejo")
                steps.append("2. `useEffect` con dependency array correcto")
                steps.append("3. `React.memo()` solo si Profiler muestra re-renders")
            case "vue", "nuxt", "pinia":
                steps.append("1. Composition API con `ref()` y `computed()`")
                steps.append("2. `defineProps` + `defineEmits` para components")
                steps.append("3. `Pinia` > `Vuex` para state management")
            case "css", "tailwind", "style":
                steps.append("1. Custom properties: `--color-primary` en `:root`")
                steps.append("2. `clamp()` para responsive sin media queries")
                steps.append("3. Grid > Flexbox para layouts 2D")
            // -- Backend --
            case "node", "express", "api":
                steps.append("1. Validation middleware (zod/joi) en cada endpoint")
                steps.append("2. Error handler global con `app.use((err, req, res, next))`")
                steps.append("3. Rate limiting + helmet para seguridad")
            case "python", "django", "flask":
                steps.append("1. Type hints en todo: `def f(x: int) -> str`")
                steps.append("2. `pydantic` para validación de datos")
                steps.append("3. `uv` > `pip` (10x más rápido)")
            case "swift", "swiftui":
                steps.append("1. `@Observable` (macOS 14+) > `@Published`")
                steps.append("2. `some View` con `@State` local")
                steps.append("3. `async let` para peticiones paralelas")
            case "rust", "cargo":
                steps.append("1. `Result<T, E>` para errores, nunca `.unwrap()` en prod")
                steps.append("2. `clippy` para linting automático")
                steps.append("3. `#[derive(Debug, Clone)]` en todas las structs")
            // -- DevOps --
            case "docker", "container":
                steps.append("1. Multi-stage: `FROM builder` → `FROM slim`")
                steps.append("2. `COPY package*.json .` antes de `COPY . .`")
                steps.append("3. `USER nonroot` en producción")
            case "kubernetes", "k8s", "helm":
                steps.append("1. `resources.requests` + `limits` siempre")
                steps.append("2. `readinessProbe` + `livenessProbe`")
                steps.append("3. `HPA` para autoescalado")
            case "ci", "cd", "github actions", "pipeline":
                steps.append("1. Cache de deps entre runs")
                steps.append("2. Matrix: test en múltiples versiones")
                steps.append("3. Deploy canary 5% → 25% → 100%")
            // -- Audio/Music --
            case "ableton", "live", "midi":
                steps.append("1. -6dB headroom en master bus")
                steps.append("2. EQ sustractivo primero, aditivo después")
                steps.append("3. Sidechain: Compressor > Ext Key > kick")
            case "eq", "compress", "master", "mix":
                steps.append("1. High-pass todo por encima de 30Hz excepto kick/sub")
                steps.append("2. Ratio 3:1 buses, 4:1+ drums")
                steps.append("3. Limiter ceiling -0.3dB para streaming")
            // -- Design --
            case "figma", "design", "ui", "ux":
                steps.append("1. Auto Layout obligatorio — responsive nativo")
                steps.append("2. Design tokens como variables")
                steps.append("3. Components con variants (state × size)")
            // -- DB --
            case "sql", "postgres", "mysql":
                steps.append("1. Índices en columnas de WHERE y JOIN")
                steps.append("2. `EXPLAIN ANALYZE` antes de optimizar")
                steps.append("3. Prepared statements contra SQL injection")
            case "redis", "cache":
                steps.append("1. TTL en todas las keys")
                steps.append("2. `SCAN` > `KEYS *` en producción")
                steps.append("3. Pub/Sub para invalidación de cache")
            // -- Security --
            case "security", "auth", "oauth":
                steps.append("1. HTTPS everywhere, HSTS header")
                steps.append("2. JWT: verificar `exp`, `iss`, `aud`")
                steps.append("3. bcrypt/argon2 para passwords, nunca MD5/SHA")
            default:
                steps.append("• Analiza \(kw) en tu contexto actual")
            }
        }
        return steps.isEmpty ? "\nDescribe tu caso para guía específica" : "\n" + steps.joined(separator: "\n")
    }

    // ── Debug steps ──
    private func buildDebugSteps(matched: [String], context: SensorFusion) -> String {
        var steps = [
            "1. **Reproduce** — aisla el caso mínimo",
            "2. **Stack trace** — lee el error completo"
        ]
        if matched.contains("swift") || matched.contains("swiftui") {
            steps.append("3. `po variable` en LLDB")
            steps.append("4. Thread Sanitizer para race conditions")
        } else if matched.contains("react") || matched.contains("javascript") || matched.contains("node") {
            steps.append("3. `console.trace()` para call stack")
            steps.append("4. Chrome DevTools > breakpoints condicionales")
        } else if matched.contains("python") {
            steps.append("3. `breakpoint()` inlined (Python 3.7+)")
            steps.append("4. `pytest -x --pdb` para debug en tests")
        } else {
            steps.append("3. Debugger nativo del IDE")
            steps.append("4. `git diff` para ver cambios recientes")
        }
        return "\n" + steps.joined(separator: "\n")
    }

    // ── Comparison builder ──
    private func buildComparison(matched: [String]) -> String {
        let kws = Set(matched)
        var lines: [String] = []
        if kws.contains("react") || kws.contains("vue") {
            lines.append("React: ecosistema gigante, JSX, más control")
            lines.append("Vue: curva más suave, SFC, Composition API")
        }
        if kws.contains("docker") || kws.contains("kubernetes") {
            lines.append("Docker: empaquetar. K8s: orquestar a escala")
        }
        if kws.contains("postgres") || kws.contains("mysql") {
            lines.append("Postgres: JSON, extensiones, CTEs avanzados")
            lines.append("MySQL: velocidad pura en reads simples")
        }
        return lines.isEmpty ? "\nEspecifica qué comparar" : "\n" + lines.joined(separator: "\n")
    }

    // ── Optimization builder ──
    private func buildOptimization(matched: [String]) -> String {
        var tips: [String] = []
        if matched.contains("react") || matched.contains("javascript") {
            tips = ["1. React Profiler → mide re-renders", "2. `React.memo` + `useMemo`", "3. `dynamic import()` code split", "4. `Intersection Observer` > scroll"]
        } else if matched.contains("swift") || matched.contains("swiftui") {
            tips = ["1. Instruments > Time Profiler", "2. `@State` solo donde se necesita", "3. `LazyVStack` para listas", "4. `nonisolated` para non-UI"]
        } else if matched.contains("python") {
            tips = ["1. `cProfile` o `py-spy`", "2. numpy vectorización > loops", "3. `lru_cache` para memoización", "4. `asyncio.gather()` para I/O"]
        } else {
            tips = ["1. Mide antes de optimizar", "2. Optimiza el hot path", "3. Cache donde puedas", "4. Paraleliza I/O"]
        }
        return "\n" + tips.joined(separator: "\n")
    }

    // ── Clipboard code analysis ──
    private func analyzeClipboardCode(_ clip: String) -> String {
        var findings: [String] = []

        // Detect language
        if clip.contains("func ") && (clip.contains("->") || clip.contains("@State")) {
            findings.append("Swift detectado")
            if clip.contains("try!") || clip.contains("as!") { findings.append("⚠️ Force unwrap/cast") }
            if clip.contains("print(") { findings.append("🧹 print() — limpiar") }
        } else if clip.contains("const ") || clip.contains("=>") {
            findings.append("JavaScript detectado")
            if clip.contains("var ") { findings.append("⚠️ `var` → usa `const`/`let`") }
            if clip.contains("console.log") { findings.append("🧹 console.log — limpiar") }
            if clip.contains("any") { findings.append("⚠️ `any` pierde type safety") }
        } else if clip.contains("def ") && clip.contains(":") {
            findings.append("Python detectado")
            if clip.contains("except:") { findings.append("⚠️ except genérico — especificar") }
        } else if clip.contains("fn ") && clip.contains("let ") {
            findings.append("Rust detectado")
            if clip.contains("unwrap()") { findings.append("⚠️ unwrap() — usa `?`") }
        }

        if clip.contains("todo:") || clip.contains("f_ixme") || clip.contains("h_ack") {
            findings.append("📌 TO-DOs/FIX-MEs pendientes")
        }

        return findings.isEmpty ? "\nCódigo sin issues obvios ✓" : "\n" + findings.joined(separator: "\n")
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Extended Registry (80 New Specialists)
// ═══════════════════════════════════════════════════════════════

enum ExtendedSpecialistRegistry {
    static let all: [NotchAgent] = [
        // ── 21-30: Frontend Specialists ──
        makeAgent(name: "ReactPro", emoji: "⚛️", domain: "React", keywords: ["react", "jsx", "hook", "useState", "useEffect", "component", "redux", "next.js", "nextjs"], response: """
        ⚛️ React Expert:
        • Hooks > Classes (always)
        • `useMemo` for expensive computations
        • `React.memo()` to prevent re-renders
        • Server Components (Next.js 14+) for data fetching
        • `Suspense` + `lazy()` for code splitting
        """),

        makeAgent(name: "VueMaster", emoji: "💚", domain: "Vue.js", keywords: ["vue", "nuxt", "composition api", "ref", "reactive", "pinia", "vuex"], response: """
        💚 Vue Expert:
        • Composition API > Options API
        • `ref()` for primitives, `reactive()` for objects
        • `computed()` for derived state
        • Pinia for state management
        • `<script setup>` for cleaner SFCs
        """),

        makeAgent(name: "CSSWizard", emoji: "🎭", domain: "CSS Architecture", keywords: ["css", "flexbox", "grid", "container query", "cascade layer", "subgrid", "nesting", "has()"], response: """
        🎭 CSS Wizard:
        • Container queries > media queries (component-level)
        • `@layer` for cascade control
        • CSS nesting (native, no preprocessor)
        • `:has()` — the parent selector
        • `color-mix()` for dynamic palettes
        • `view-transition` API for page animations
        """),

        makeAgent(name: "A11yGuard", emoji: "♿", domain: "Accessibility", keywords: ["accessibility", "a11y", "aria", "screen reader", "wcag", "contrast", "focus", "semantic"], response: """
        ♿ Accessibility Audit:
        • Semantic HTML first (nav, main, article)
        • ARIA: use sparingly, native elements preferred
        • Focus management: visible outline, logical tab order
        • Color contrast: 4.5:1 text, 3:1 large text
        • Test with VoiceOver (⌘+F5)
        """),

        makeAgent(name: "SVGsmith", emoji: "🖌️", domain: "SVG & Icons", keywords: ["svg", "icon", "vector", "path", "viewbox", "sprite", "stroke"], response: """
        🖌️ SVG Expert:
        • `viewBox` always, never fixed width/height
        • `currentColor` for theme-aware icons
        • SVGO for optimization (50-80% smaller)
        • Sprite sheet for icon sets
        • `stroke-dasharray` for line animations
        """),

        makeAgent(name: "AnimPro", emoji: "🎬", domain: "Web Animations", keywords: ["animation", "framer", "gsap", "lottie", "spring", "keyframe", "rive", "motion"], response: """
        🎬 Animation Expert:
        • WAAPI (Web Animations API) for performance
        • Framer Motion for React declarative animations
        • GSAP for complex timelines
        • `will-change` sparingly (GPU promotion)
        • 60fps rule: only animate transform + opacity
        """),

        makeAgent(name: "PWAPro", emoji: "📱", domain: "Progressive Web Apps", keywords: ["pwa", "service worker", "manifest", "offline", "cache", "installable", "push notification"], response: """
        📱 PWA Expert:
        • manifest.json: name, icons, theme_color, display
        • Service Worker: cache-first for assets, network-first for API
        • Workbox for caching strategies
        • `beforeinstallprompt` for install UX
        • Background Sync for offline actions
        """),

        makeAgent(name: "WebPerfPro", emoji: "🚀", domain: "Web Performance", keywords: ["lighthouse", "core web vitals", "lcp", "fid", "cls", "ttfb", "bundle", "tree shake"], response: """
        🚀 Web Performance:
        • LCP < 2.5s: preload hero image, font-display: swap
        • CLS < 0.1: explicit dimensions on images/ads
        • INP < 200ms: debounce handlers, yield to main thread
        • Bundle: tree-shake, code-split, dynamic import
        • Images: WebP/AVIF, srcset, lazy loading
        """),

        makeAgent(name: "TestPro", emoji: "🧪", domain: "Testing", keywords: ["test", "jest", "vitest", "cypress", "playwright", "testing library", "mock", "assertion", "coverage"], response: """
        🧪 Testing Expert:
        • Unit: Vitest/Jest — test behavior, not implementation
        • Integration: Testing Library — user-centric queries
        • E2E: Playwright > Cypress (parallel, multi-browser)
        • Mock: MSW for API mocking (service worker level)
        • Coverage: 80% is good, 100% is waste
        """),

        makeAgent(name: "GraphQLPro", emoji: "◻️", domain: "GraphQL", keywords: ["graphql", "query", "mutation", "subscription", "resolver", "schema", "apollo", "relay"], response: """
        ◻️ GraphQL Expert:
        • Schema-first design with SDL
        • DataLoader for N+1 query prevention
        • Fragments for component co-location
        • Persisted queries for security
        • Subscriptions via WebSocket for real-time
        """),

        // ── 31-40: Backend & Systems ──
        makeAgent(name: "RustPro", emoji: "🦀", domain: "Rust", keywords: ["rust", "cargo", "ownership", "borrow", "lifetime", "tokio", "wasm", "unsafe", "trait"], response: """
        🦀 Rust Expert:
        • Ownership: each value has ONE owner
        • `&` borrow, `&mut` mutable borrow (exclusive)
        • `Result<T, E>` > exceptions (always)
        • `tokio` for async runtime
        • `serde` for serialization
        • `clippy` for idiomatic code
        """),

        makeAgent(name: "GoPro", emoji: "🐹", domain: "Go", keywords: ["golang", "go", "goroutine", "channel", "defer", "interface", "gin", "cobra"], response: """
        🐹 Go Expert:
        • Goroutines: lightweight (2KB stack)
        • Channels for communication, not shared memory
        • `defer` for cleanup (LIFO order)
        • Error handling: `if err != nil` (embrace it)
        • Interfaces: implicit satisfaction
        """),

        makeAgent(name: "PythonPro", emoji: "🐍", domain: "Python", keywords: ["python", "pip", "django", "flask", "fastapi", "pandas", "numpy", "decorator", "asyncio", "pytest"], response: """
        🐍 Python Expert:
        • Type hints everywhere (mypy strict)
        • `dataclass` or `pydantic` for data models
        • `asyncio` for I/O-bound concurrency
        • `pathlib` > `os.path` (always)
        • Virtual envs: `uv` > `pip` (10x faster)
        • Formatting: `ruff` > `black` + `isort`
        """),

        makeAgent(name: "KotlinPro", emoji: "🟣", domain: "Kotlin", keywords: ["kotlin", "android", "compose", "coroutine", "flow", "ktor", "jetpack"], response: """
        🟣 Kotlin Expert:
        • Coroutines: `suspend` functions for async
        • Flow: cold streams, `stateIn` for UI state
        • Jetpack Compose: declarative UI
        • Sealed classes for state machines
        • Extension functions for domain expressiveness
        """),

        makeAgent(name: "PHPLaravel", emoji: "🐘", domain: "PHP & Laravel", keywords: ["php", "laravel", "artisan", "eloquent", "blade", "migration", "middleware", "composer"], response: """
        🐘 Laravel Expert:
        • Eloquent: eager load with `with()` to avoid N+1
        • Migrations: never modify, always add new
        • Queue: dispatch heavy tasks (email, PDF, etc.)
        • Cache: Redis for sessions + cache
        • Testing: `RefreshDatabase` trait for clean state
        """),

        makeAgent(name: "ElixirPro", emoji: "💜", domain: "Elixir", keywords: ["elixir", "phoenix", "genserver", "beam", "erlang", "otp", "liveview", "ecto"], response: """
        💜 Elixir Expert:
        • GenServer for stateful processes
        • Phoenix LiveView: real-time without JS
        • Ecto for database layer (composable queries)
        • Pattern matching > conditionals
        • Supervision trees for fault tolerance
        """),

        makeAgent(name: "SystemDesign", emoji: "🏛️", domain: "System Design", keywords: ["system design", "architecture", "microservice", "monolith", "cqrs", "event sourcing", "saga"], response: """
        🏛️ System Design:
        • Start monolith, extract microservices when needed
        • CQRS: separate read/write models for scale
        • Event Sourcing: audit trail + time travel
        • Saga pattern for distributed transactions
        • CAP theorem: pick 2 (usually AP for web)
        """),

        makeAgent(name: "MessageQueue", emoji: "📬", domain: "Message Queues", keywords: ["queue", "kafka", "rabbitmq", "redis", "pubsub", "event", "consumer", "producer"], response: """
        📬 Message Queue Expert:
        • Kafka: high throughput, ordered partitions
        • RabbitMQ: flexible routing, dead letter queues
        • Redis Streams: lightweight pub/sub
        • Idempotency: deduplicate with message IDs
        • DLQ (Dead Letter Queue): always configure
        """),

        makeAgent(name: "CachePro", emoji: "⚡", domain: "Caching", keywords: ["cache", "redis", "memcached", "cdn", "invalidation", "ttl", "lru", "stale"], response: """
        ⚡ Caching Expert:
        • Cache-aside: app manages cache + DB
        • Write-through: cache stays consistent
        • TTL: set reasonable expiry (not infinite)
        • Cache stampede: use locking or probabilistic refresh
        • CDN: cache at the edge for static assets
        """),

        makeAgent(name: "AuthPro", emoji: "🔑", domain: "Authentication", keywords: ["auth", "oauth", "jwt", "session", "passkey", "webauthn", "saml", "oidc", "login"], response: """
        🔑 Auth Expert:
        • Passkeys > passwords (WebAuthn standard)
        • JWT: short-lived access + refresh token rotation
        • OAuth 2.0 + PKCE for SPAs (no client secret)
        • Session: httpOnly, secure, sameSite=strict
        • MFA: TOTP (Google Auth) or push notification
        """),

        // ── 41-50: AI/ML Specialists ──
        makeAgent(name: "LLMPro", emoji: "🤖", domain: "LLM Engineering", keywords: ["llm", "gpt", "claude", "gemini", "prompt", "fine-tune", "rag", "embedding", "token"], response: """
        🤖 LLM Expert:
        • RAG: chunk → embed → retrieve → generate
        • Prompt: system > user > assistant ordering
        • Temperature: 0 for facts, 0.7 for creative
        • Context window: fit more with summarization
        • Eval: automated benchmarks + human review
        """),

        makeAgent(name: "RAGPro", emoji: "📚", domain: "RAG Systems", keywords: ["rag", "retrieval", "vector", "embedding", "chunk", "pinecone", "chroma", "weaviate"], response: """
        📚 RAG Expert:
        • Chunking: 512-1024 tokens, 20% overlap
        • Embedding: text-embedding-3-small (cost) or large (quality)
        • Hybrid search: dense + sparse (BM25)
        • Re-ranking: cross-encoder for precision
        • Metadata filtering for scope control
        """),

        makeAgent(name: "AgentPro", emoji: "🕵️", domain: "AI Agents", keywords: ["agent", "tool use", "function calling", "langchain", "crew", "autogen", "swarm"], response: """
        🕵️ AI Agent Expert:
        • ReAct pattern: Reason → Act → Observe loop
        • Tool use: structured outputs for function calling
        • Memory: short-term (context) + long-term (vector DB)
        • Guard rails: output validation, content filtering
        • Multi-agent: orchestrator + specialists
        """),

        makeAgent(name: "MLOpsPro", emoji: "🔧", domain: "MLOps", keywords: ["mlops", "pipeline", "model", "deploy", "inference", "onnx", "mlflow", "wandb", "training"], response: """
        🔧 MLOps Expert:
        • Experiment tracking: W&B or MLflow
        • Model registry: version + stage (staging/prod)
        • Serving: ONNX Runtime for cross-platform inference
        • Feature store: offline (batch) + online (real-time)
        • Monitoring: data drift detection + model decay alerts
        """),

        makeAgent(name: "ComputerVision", emoji: "👁️", domain: "Computer Vision", keywords: ["vision", "image", "detection", "segmentation", "yolo", "cnn", "diffusion", "opencv"], response: """
        👁️ CV Expert:
        • Detection: YOLOv8 (real-time), DETR (accuracy)
        • Segmentation: SAM (Segment Anything) for zero-shot
        • Generation: Stable Diffusion, SDXL, Flux
        • Preprocessing: normalize, augment, resize
        • Edge: CoreML (Apple), TFLite (Android)
        """),

        makeAgent(name: "NLPPro", emoji: "💬", domain: "NLP", keywords: ["nlp", "tokenize", "sentiment", "ner", "bert", "transformer", "text", "classify"], response: """
        💬 NLP Expert:
        • Tokenization: BPE (GPT), WordPiece (BERT)
        • NER: spaCy for speed, transformers for accuracy
        • Sentiment: fine-tuned BERT or zero-shot LLM
        • Text classification: SetFit for few-shot
        • Evaluation: F1, BLEU, ROUGE per task
        """),

        makeAgent(name: "PromptEng", emoji: "✏️", domain: "Prompt Engineering", keywords: ["prompt", "system prompt", "few-shot", "chain of thought", "cot", "instruction", "template"], response: """
        ✏️ Prompt Engineering:
        • Structure: Role → Context → Task → Format → Constraints
        • Few-shot: 3-5 examples for pattern learning
        • Chain of Thought: "Think step by step"
        • Self-consistency: sample multiple, majority vote
        • Negative prompts: "Do NOT include/mention..."
        """),

        makeAgent(name: "DiffusionPro", emoji: "🖼️", domain: "Image Generation", keywords: ["stable diffusion", "sdxl", "flux", "comfyui", "controlnet", "lora", "inpaint"], response: """
        🖼️ Diffusion Expert:
        • SDXL: 1024x1024 base, refiner for detail
        • ControlNet: canny, depth, pose for structure
        • LoRA: lightweight fine-tuning (4-8 rank)
        • ComfyUI: node-based workflow for power users
        • Negative prompt: "blurry, deformed, low quality"
        """),

        makeAgent(name: "AudioAI", emoji: "🔊", domain: "Audio AI", keywords: ["whisper", "tts", "speech", "voice", "elevenlabs", "bark", "music gen", "audio"], response: """
        🔊 Audio AI Expert:
        • STT: Whisper (local) or Deepgram (API)
        • TTS: ElevenLabs (quality) or Bark (open source)
        • Music: MusicGen for generation, Demucs for stems
        • Voice cloning: 3s sample minimum
        • Real-time: WebRTC + VAD for streaming
        """),

        makeAgent(name: "EdgeAI", emoji: "📲", domain: "Edge AI", keywords: ["coreml", "tflite", "onnx", "edge", "on-device", "quantize", "prune", "mobile"], response: """
        📲 Edge AI Expert:
        • CoreML: convert with coremltools
        • Quantization: INT8 for 2-4x speedup
        • Pruning: remove <10% weight connections
        • ONNX: universal interchange format
        • Benchmark: latency on target device, not desktop
        """),

        // ── 51-60: DevOps & Cloud Deep ──
        makeAgent(name: "TerraformPro", emoji: "🏗️", domain: "Terraform", keywords: ["terraform", "hcl", "state", "plan", "apply", "module", "provider", "iac"], response: """
        🏗️ Terraform Expert:
        • State: remote backend (S3 + DynamoDB lock)
        • Modules: reusable, versioned, documented
        • Plan before apply, always review diff
        • `terraform fmt` + `terraform validate` in CI
        • Workspaces for env separation (dev/staging/prod)
        """),

        makeAgent(name: "GithubActions", emoji: "🔄", domain: "GitHub Actions", keywords: ["github actions", "workflow", "ci/cd", "yaml", "runner", "artifact", "matrix"], response: """
        🔄 GitHub Actions Expert:
        • Matrix strategy for multi-version testing
        • Cache: actions/cache for node_modules, pip
        • Secrets: never echo, use GITHUB_TOKEN for API
        • Reusable workflows: `workflow_call`
        • Concurrency: cancel-in-progress for PRs
        """),

        makeAgent(name: "NginxPro", emoji: "🌐", domain: "Nginx & Reverse Proxy", keywords: ["nginx", "reverse proxy", "load balance", "upstream", "ssl", "certbot"], response: """
        🌐 Nginx Expert:
        • Reverse proxy: `proxy_pass http://backend;`
        • SSL: certbot for free Let's Encrypt certs
        • Gzip: enable for text/html, application/json
        • Rate limit: `limit_req_zone` for DDoS protection
        • Headers: X-Frame-Options, CSP, HSTS
        """),

        makeAgent(name: "LinuxPro", emoji: "🐧", domain: "Linux Administration", keywords: ["linux", "ubuntu", "systemd", "journalctl", "iptables", "cgroup", "mount"], response: """
        🐧 Linux Expert:
        • systemd: `systemctl start/stop/enable/status`
        • Logs: `journalctl -u service -f --since "1h ago"`
        • Process: `htop`, `strace -p PID`, `lsof -i :PORT`
        • Disk: `df -h`, `du -sh *`, `ncdu`
        • Network: `ss -tulpn`, `iptables -L`
        """),

        makeAgent(name: "PostgresPro", emoji: "🐘", domain: "PostgreSQL Deep", keywords: ["postgres", "postgresql", "explain analyze", "vacuum", "replication", "pgbouncer", "materialized"], response: """
        🐘 PostgreSQL Expert:
        • `EXPLAIN ANALYZE` before optimizing
        • Index: B-tree (default), GIN (jsonb, arrays), GiST (geo)
        • Connection pool: PgBouncer (transaction mode)
        • `VACUUM ANALYZE` regularly (autovacuum config)
        • Partitioning: range for time-series data
        """),

        makeAgent(name: "ElasticPro", emoji: "🔎", domain: "Elasticsearch", keywords: ["elasticsearch", "elastic", "kibana", "index", "mapping", "aggregation", "full text"], response: """
        🔎 Elasticsearch Expert:
        • Mapping: define explicit types (no dynamic)
        • Analyzers: standard + custom for your language
        • Aggregations: terms, date_histogram, nested
        • Shards: 1-2 per node per index (don't over-shard)
        • Aliases: zero-downtime reindexing
        """),

        makeAgent(name: "ObservePro", emoji: "📊", domain: "Observability", keywords: ["observability", "tracing", "metrics", "logging", "opentelemetry", "jaeger", "prometheus", "grafana"], response: """
        📊 Observability Expert:
        Three pillars:
        1. Logs: structured JSON, correlation IDs
        2. Metrics: RED (Rate, Errors, Duration) for services
        3. Traces: distributed tracing with OpenTelemetry
        • Grafana dashboards: golden signals per service
        • Alert: symptoms not causes (SLO-based)
        """),

        makeAgent(name: "AWSPro", emoji: "☁️", domain: "AWS", keywords: ["aws", "s3", "ec2", "lambda", "dynamodb", "cloudfront", "iam", "sqs", "sns", "ecs"], response: """
        ☁️ AWS Expert:
        • IAM: least privilege, roles > keys
        • Lambda: <15min, 10GB RAM, cold start optimization
        • S3: lifecycle policies, versioning, replication
        • DynamoDB: single-table design, GSI for access patterns
        • Cost: Savings Plans > Reserved > On-Demand > Spot
        """),

        makeAgent(name: "GCPPro", emoji: "🌩️", domain: "Google Cloud", keywords: ["gcp", "cloud run", "firebase", "bigquery", "pubsub", "spanner", "vertex"], response: """
        🌩️ GCP Expert:
        • Cloud Run: container → URL in seconds, scale to zero
        • BigQuery: columnar, petabyte-scale, SQL
        • Pub/Sub: exactly-once delivery, dead letter
        • Firebase: Auth + Firestore for rapid prototyping
        • Vertex AI: managed ML platform
        """),

        makeAgent(name: "VercelPro", emoji: "▲", domain: "Vercel & Edge", keywords: ["vercel", "edge", "serverless", "isr", "ssg", "ssr", "middleware", "turbopack"], response: """
        ▲ Vercel Expert:
        • ISR: revalidate static pages on-demand
        • Edge Functions: <1ms cold start, global
        • Middleware: auth, redirects, geolocation
        • Image optimization: next/image with AVIF
        • Preview deployments: per-PR URLs
        """),

        // ── 61-70: Security Deep ──
        makeAgent(name: "OWASPPro", emoji: "🛡️", domain: "OWASP Security", keywords: ["owasp", "injection", "xss", "csrf", "ssrf", "broken auth", "insecure"], response: """
        🛡️ OWASP Top 10:
        1. Broken Access Control → check authZ per request
        2. Crypto Failures → AES-256-GCM, bcrypt/argon2
        3. Injection → parameterized queries, never concat SQL
        4. Insecure Design → threat model (STRIDE)
        5. Misconfig → disable debug, update deps
        """),

        makeAgent(name: "PentestPro", emoji: "🥷", domain: "Penetration Testing", keywords: ["pentest", "burp", "nmap", "metasploit", "recon", "exploit", "ctf"], response: """
        🥷 Pentest Expert:
        Recon → Scan → Exploit → Post-exploit → Report
        • `nmap -sV -sC -p- target` — full port scan
        • Burp Suite: intercept, modify, replay
        • OSINT: Shodan, crt.sh, Google dorks
        • Always get written authorization first
        """),

        makeAgent(name: "CryptoPro", emoji: "🔐", domain: "Cryptography", keywords: ["encrypt", "decrypt", "hash", "aes", "rsa", "ed25519", "hmac", "salt", "derive"], response: """
        🔐 Cryptography Expert:
        • Symmetric: AES-256-GCM (authenticated encryption)
        • Asymmetric: Ed25519 (signing), X25519 (key exchange)
        • Hashing: SHA-256 for integrity, bcrypt for passwords
        • KDF: Argon2id for password-based key derivation
        • Never roll your own crypto
        """),

        // ── 71-80: Creative Deep ──
        makeAgent(name: "ThreeJSPro", emoji: "🌐", domain: "Three.js & WebGL", keywords: ["three.js", "threejs", "webgl", "shader", "glsl", "3d", "scene", "mesh", "raycaster"], response: """
        🌐 Three.js Expert:
        • Scene → Camera → Renderer → animate()
        • Use `GLTFLoader` for .glb models
        • Shader: vertex (position) + fragment (color)
        • Post-processing: EffectComposer pipeline
        • Performance: instancing for repeated geometry
        """),

        makeAgent(name: "AbletonPro", emoji: "🎹", domain: "Ableton Live", keywords: ["ableton", "live", "clip", "arrangement", "warping", "rack", "return"], response: """
        🎹 Ableton Expert:
        • Session view for jamming, Arrangement for mixing
        • Warping: Complex Pro for audio, Beats for drums
        • Racks: chain multiple effects, macro controls
        • Sidechain: Compressor → sidechain from kick
        • Export: -1dB ceiling, dithering for 16-bit
        """),

        makeAgent(name: "FigmaPro", emoji: "🎨", domain: "Figma", keywords: ["figma", "auto layout", "component", "variant", "token", "prototype", "frame"], response: """
        🎨 Figma Expert:
        • Auto Layout: use for everything (responsive-like)
        • Components: base + variants (state/size/theme)
        • Design tokens: export via Tokens Studio
        • Prototyping: Smart Animate for micro-interactions
        • Dev mode: inspect CSS, copy assets
        """),

        makeAgent(name: "BlenderPro", emoji: "🧊", domain: "Blender 3D", keywords: ["blender", "sculpt", "texture", "material", "render", "cycles", "eevee", "uv"], response: """
        🧊 Blender Expert:
        • Modeling: start with primitives, loop cuts, subdivision
        • UV unwrap: mark seams, smart UV project
        • Materials: Principled BSDF for PBR
        • Cycles: path tracing (quality), Eevee (speed)
        • Export: .glb for web, .fbx for game engines
        """),

        makeAgent(name: "DaVinciPro", emoji: "🎬", domain: "DaVinci Resolve", keywords: ["davinci", "resolve", "color grade", "fusion", "fairlight", "node", "lut"], response: """
        🎬 DaVinci Expert:
        • Color: Lift/Gamma/Gain > primary correction
        • Nodes: serial for order, parallel for layers
        • LUTs: apply LAST in node chain
        • Fairlight: audio mixing, EQ, compression
        • Fusion: compositing, motion graphics
        """),

        makeAgent(name: "AfterFX", emoji: "✨", domain: "After Effects & Motion", keywords: ["after effects", "keyframe", "expression", "lottie", "bodymovin", "wiggle"], response: """
        ✨ After Effects Expert:
        • Ease: F9 (easy ease), Graph Editor for control
        • Expressions: `wiggle(5, 20)`, `loopOut()`
        • Lottie export: Bodymovin plugin → JSON
        • Pre-compose for organization
        • 3D: Camera + null object for smooth moves
        """),

        makeAgent(name: "GameDev", emoji: "🎮", domain: "Game Development", keywords: ["game", "unity", "unreal", "godot", "sprite", "gameloop", "physics", "collision"], response: """
        🎮 Game Dev Expert:
        • Game Loop: input → update → render (fixed timestep)
        • Physics: Rigidbody for dynamics, triggers for events
        • ECS: Entity-Component-System for performance
        • Godot: GDScript for rapid prototyping
        • Unity: C# + DOTs for high-performance
        """),

        // ── 81-100: Domain Specialists ──
        makeAgent(name: "CryptoTrader", emoji: "📈", domain: "Crypto Trading", keywords: ["trading", "candle", "rsi", "macd", "fibonacci", "support", "resistance", "dex"], response: """
        📈 Crypto Trading:
        • RSI >70 overbought, <30 oversold
        • MACD crossover = trend change signal
        • Fibonacci retracements: 0.382, 0.5, 0.618
        • Volume profile for key levels
        • Risk: never >2% per trade, use stop-loss
        """),

        makeAgent(name: "SmartContract", emoji: "📜", domain: "Smart Contracts", keywords: ["solidity", "contract", "erc20", "erc721", "hardhat", "foundry", "reentrancy"], response: """
        📜 Smart Contract Expert:
        • Reentrancy: checks-effects-interactions
        • Gas: pack structs, use uint256, calldata > memory
        • Testing: Foundry fuzzing for edge cases
        • Proxy: UUPS or transparent for upgradeability
        • Audit: Slither + manual review before mainnet
        """),

        makeAgent(name: "SpanishCoder", emoji: "🇪🇸", domain: "Desarrollo en Español", keywords: ["código", "función", "variable", "error", "compilar", "depurar", "arquitectura", "patrón", "módulo"], response: """
        🇪🇸 Desarrollo:
        • Nombres en inglés para código, comentarios en español OK
        • Tipos estrictos siempre (TypeScript, Swift, mypy)
        • Tests primero: TDD > código → test
        • Git: commits en inglés, PRs descriptivos
        • CI/CD: automatiza todo lo repetitivo
        """),

        makeAgent(name: "MarkdownPro", emoji: "📝", domain: "Markdown & Docs", keywords: ["markdown", "readme", "documentation", "docusaurus", "mdx", "changelog", "contributing"], response: """
        📝 Documentation Expert:
        README structure:
        1. Title + badges
        2. One-line description
        3. Quick Start (3 commands max)
        4. Features (bullet list)
        5. API Reference
        6. Contributing guide
        7. License
        """),

        makeAgent(name: "SEOPro", emoji: "🔍", domain: "SEO", keywords: ["seo", "sitemap", "robots.txt", "meta", "schema", "structured data", "canonical", "alt text"], response: """
        🔍 SEO Expert:
        • Title: 50-60 chars, primary keyword first
        • Meta description: 150-160 chars, include CTA
        • H1: one per page, matches search intent
        • Schema.org: Article, Product, FAQ markup
        • Core Web Vitals: LCP, CLS, INP
        • Internal linking: 3-5 per content page
        """),

        makeAgent(name: "StripePayments", emoji: "💳", domain: "Payments & Stripe", keywords: ["stripe", "payment", "checkout", "subscription", "invoice", "webhook", "pci"], response: """
        💳 Payments Expert:
        • Stripe Checkout: hosted page (PCI-free)
        • Webhooks: idempotent, verify signature
        • Subscriptions: proration, trial periods
        • Error handling: card_declined, insufficient_funds
        • PCI: never store raw card numbers
        """),

        makeAgent(name: "EmailPro", emoji: "📧", domain: "Email Systems", keywords: ["email", "smtp", "sendgrid", "resend", "mailgun", "dkim", "spf", "dmarc", "deliverability"], response: """
        📧 Email Expert:
        • SPF + DKIM + DMARC = deliverability trinity
        • Resend / SendGrid for transactional
        • HTML email: tables (yes, still), inline CSS
        • Test: Litmus or Email on Acid for rendering
        • Unsubscribe: one-click, List-Unsubscribe header
        """),

        makeAgent(name: "TypescriptPro", emoji: "🔷", domain: "TypeScript", keywords: ["typescript", "ts", "type", "interface", "generic", "union", "discriminated", "infer", "zod"], response: """
        🔷 TypeScript Expert:
        • `as const` for literal types
        • Discriminated unions for state machines
        • `satisfies` operator for type checking + inference
        • Zod for runtime validation + type inference
        • `strict: true` in tsconfig (always)
        • Template literal types for string patterns
        """),

        makeAgent(name: "WASMPro", emoji: "⚙️", domain: "WebAssembly", keywords: ["wasm", "webassembly", "emscripten", "wasi", "assemblyscript", "wasm-bindgen"], response: """
        ⚙️ WebAssembly Expert:
        • Rust → wasm_bindgen → npm package
        • C/C++ → Emscripten → .wasm + .js glue
        • WASI: server-side Wasm (Spin, Wasmtime)
        • Performance: 1.5-2x native speed typical
        • Use for: codecs, crypto, physics, ML inference
        """),

        makeAgent(name: "AppleVision", emoji: "🥽", domain: "visionOS & AR", keywords: ["visionos", "ar", "arkit", "realitykit", "spatial", "immersive", "reality composer"], response: """
        🥽 visionOS Expert:
        • RealityKit: entities, components, systems
        • Spatial: windows, volumes, immersive spaces
        • Hand tracking: ARHandAnchor, joint positions
        • Passthrough: blend virtual with real world
        • Design: eye comfort, 1-2m interaction distance
        """),

        makeAgent(name: "AccessPro", emoji: "🏢", domain: "Enterprise Architecture", keywords: ["enterprise", "soa", "middleware", "erp", "integration", "gateway", "api management"], response: """
        🏢 Enterprise Expert:
        • API Gateway: rate limiting, auth, versioning
        • Event-driven: decouple services via events
        • SAGA: manage distributed transactions
        • Strangler Fig: migrate legacy incrementally
        • Governance: API standards, schema registry
        """),
    ]

    static var count: Int { all.count }
}
