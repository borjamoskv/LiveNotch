import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════
// MARK: - 🧠 SPECIALIST SWARM — Domain Micro-Agents
// ═══════════════════════════════════════════════════════════════
// 20 hyper-specialized agents extending NotchIntelligence.
// Each has narrow domain focus + high-precision confidence scoring.
// When LLM is connected, these provide routing context;
// when offline, they respond from curated templates.
// ═══════════════════════════════════════════════════════════════

// ── 1. DevOps Agent ──────────────────────────────────────────

struct DevOpsAgent: NotchAgent {
    let name = "DevOps"
    let emoji = "🐳"
    let domain = "Infrastructure & Deployment"
    
    private let keywords = ["docker", "deploy", "ci", "cd", "pipeline", "kubernetes", "k8s",
                            "terraform", "nginx", "server", "aws", "gcp", "azure", "ssh",
                            "container", "pod", "helm", "ansible", "devops", "infra",
                            "servidor", "nube", "despliegue", "contenedor", "infraestructura"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        let kw = Double(keywords.filter { q.contains($0) }.count) * 0.3
        let app = ["com.apple.Terminal", "dev.warp.warp-stable", "com.googlecode.iterm2"]
            .contains(context.activeAppBundle) ? 0.15 : 0
        return min(1.0, kw + app)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🐳 DevOps Pipeline Analysis:
        
        Quick commands for your context:
        • `docker compose up -d` — spin up services
        • `docker ps --format "table {{.Names}}\t{{.Status}}"` — status check
        • `kubectl get pods -o wide` — cluster health
        
        Best practices:
        1. Always pin image versions (never use `:latest` in prod)
        2. Use multi-stage builds to minimize image size
        3. Health checks with exponential backoff
        4. Secrets → env vars, never hardcode
        
        Need specific Docker/K8s/CI help? Ask me.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 2. Git Agent ─────────────────────────────────────────────

struct GitAgent: NotchAgent {
    let name = "GitMaster"
    let emoji = "🌿"
    let domain = "Version Control & Git"
    
    private let keywords = ["git", "commit", "branch", "merge", "rebase", "stash", "cherry",
                            "pull request", "pr", "conflict", "diff", "log", "blame", "push",
                            "checkout", "reset", "tag", "remote", "fetch",
                            "rama", "fusionar", "conflicto", "repositorio", "cambios", "versión"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        let kw = Double(keywords.filter { q.contains($0) }.count) * 0.35
        return min(1.0, kw)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let q = query.lowercased()
        var r = "🌿 Git "
        
        if q.contains("conflict") {
            r += """
            Conflict Resolution:
            ```
            git stash
            git pull --rebase origin main
            git stash pop
            # Fix conflicts, then:
            git add . && git rebase --continue
            ```
            """
        } else if q.contains("undo") || q.contains("reset") {
            r += """
            Undo Strategies:
            • Last commit (keep changes): `git reset --soft HEAD~1`
            • Last commit (discard):      `git reset --hard HEAD~1`
            • Staged file:                `git restore --staged <file>`
            • Working changes:            `git checkout -- <file>`
            • Nuclear option:             `git reflog` → find safe point → `git reset --hard <hash>`
            """
        } else {
            r += """
            Ready for version control tasks:
            • Branch strategy (GitFlow, trunk-based)
            • Conflict resolution
            • Interactive rebase & squash
            • Cherry-pick across branches
            • Bisect for bug hunting
            """
        }
        
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 3. Database Agent ────────────────────────────────────────

struct DatabaseAgent: NotchAgent {
    let name = "DataForge"
    let emoji = "🗃️"
    let domain = "Databases & SQL"
    
    private let keywords = ["sql", "query", "database", "postgres", "mysql", "sqlite", "mongo",
                            "redis", "table", "index", "join", "select", "insert", "migration",
                            "schema", "orm", "prisma", "supabase", "firebase",
                            "base de datos", "tabla", "consulta", "migración", "índice", "datos"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🗃️ Database Expert:
        
        Quick optimization checklist:
        1. ✅ Add indexes on WHERE/JOIN columns
        2. ✅ Use `EXPLAIN ANALYZE` before deploying
        3. ✅ Avoid `SELECT *` — specify columns
        4. ✅ Use connection pooling (pgBouncer, etc.)
        5. ✅ Add `LIMIT` to prevent runaway queries
        
        Pattern: N+1 → Use eager loading / JOIN
        Pattern: Slow search → Consider `GIN` index for JSONB
        
        What's your DB engine? I'll give precise advice.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 4. Security Agent ────────────────────────────────────────

struct CyberSecAgent: NotchAgent {
    let name = "CyberSec"
    let emoji = "🛡️"
    let domain = "Security & Cryptography"
    
    private let keywords = ["security", "h" + "ack", "vulnerability", "exploit", "xss", "csrf",
                            "injection", "encrypt", "decrypt", "hash", "jwt", "oauth", "cors",
                            "firewall", "pentest", "cve", "phishing", "wallet", "drainer",
                            "private key", "passkey", "2fa", "tls", "ssl",
                            "seguridad", "seguro", "vulnerabilidad", "contraseña", "encriptar", "ataque", "protección"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🛡️ Security Assessment:
        
        OWASP Top 10 Quick Check:
        1. Broken Access Control — verify auth on every endpoint
        2. Cryptographic Failures — use bcrypt/argon2, never MD5/SHA1
        3. Injection — parameterized queries ALWAYS
        4. Insecure Design — threat model BEFORE coding
        5. Security Misconfiguration — disable debug in prod
        
        ⚡ Immediate actions:
        • Rotate any exposed credentials NOW
        • Check `npm audit` / `pip audit`
        • Enable CSP headers
        • Review CORS policy (no wildcards in prod)
        
        Need a specific security audit? Give me the context.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 5. UI/UX Designer Agent ──────────────────────────────────

struct DesignerAgent: NotchAgent {
    let name = "DesignEye"
    let emoji = "🎨"
    let domain = "UI/UX Design"
    
    private let keywords = ["design", "ui", "ux", "layout", "color", "font", "typography",
                            "spacing", "padding", "margin", "animation", "transition", "figma",
                            "wireframe", "mockup", "prototype", "accessibility", "a11y",
                            "responsive", "breakpoint", "grid", "flexbox",
                            "diseño", "interfaz", "usuario", "animación", "color", "fuente", "tipografía", "estilo"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        let kw = Double(keywords.filter { q.contains($0) }.count) * 0.25
        let app = context.activeAppBundle.contains("figma") ? 0.3 : 0
        return min(1.0, kw + app)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🎨 Design Eye Analysis:
        
        Premium Design Principles:
        • 8-point grid system for ALL spacing
        • Type scale: 12 / 14 / 16 / 20 / 24 / 32 / 48
        • Max 2 fonts, max 3 weights per font
        • Color: 60-30-10 rule (primary-secondary-accent)
        • Contrast ratio: ≥4.5:1 for text (WCAG AA)
        
        Animation Guidelines:
        • Duration: 200-300ms for micro, 400-600ms for page
        • Easing: `cubic-bezier(0.4, 0, 0.2, 1)` (Material standard)
        • Never animate `width/height` — use `transform: scale()`
        
        What element are you designing? I'll give specific tokens.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 6. Performance Agent ─────────────────────────────────────

struct PerformanceAgent: NotchAgent {
    let name = "PerfHawk"
    let emoji = "⚡"
    let domain = "Performance Optimization"
    
    private let keywords = ["slow", "performance", "optimize", "speed", "memory", "leak",
                            "fps", "latency", "cache", "lazy", "async", "concurrent",
                            "profile", "benchmark", "bottleneck", "throttle", "debounce",
                            "rendimiento", "lento", "rápido", "optimizar", "memoria", "carga", "velocidad"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.3
        if context.cpuUsage > 80 { score += 0.2 }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let cpuNote = context.cpuUsage > 60 ? "\n⚠️ CPU at \(Int(context.cpuUsage))% — check Activity Monitor" : ""
        let r = """
        ⚡ Performance Audit:\(cpuNote)
        
        Quick wins (highest impact first):
        1. Lazy load below-the-fold content
        2. Debounce search/scroll handlers (150-300ms)
        3. Memoize expensive computations
        4. Virtual scroll for long lists (>100 items)
        5. Image optimization (WebP, lazy, srcset)
        
        Swift-specific:
        • Use `@StateObject` not `@ObservedObject` for owned state
        • `EquatableView` for expensive view bodies
        • `drawingGroup()` for complex Canvas work
        • Actor isolation for concurrent data access
        
        Run Instruments → Time Profiler to find the real bottleneck.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 7. API Agent ─────────────────────────────────────────────

struct APIAgent: NotchAgent {
    let name = "APIForge"
    let emoji = "🔌"
    let domain = "APIs & Networking"
    
    private let keywords = ["api", "rest", "graphql", "endpoint", "request", "response",
                            "fetch", "post", "get", "put", "delete", "webhook", "websocket",
                            "cors", "header", "token", "rate limit", "pagination", "swagger",
                            "openapi", "grpc", "http",
                            "petición", "respuesta", "cabecera", "conexión", "servidor", "ruta"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🔌 API Architecture:
        
        REST Best Practices:
        • Resource naming: `/users/{id}/orders` (nouns, plural)
        • Status codes: 200 OK, 201 Created, 204 No Content, 400 Bad Request, 401 Unauthorized, 404 Not Found
        • Always version: `/api/v1/...`
        • Pagination: `?page=1&limit=20` + Link headers
        • Rate limiting: `X-RateLimit-*` headers
        
        Error response format:
        ```json
        {
          "error": "VALIDATION_ERROR",
          "message": "Email is required",
          "details": [{"field": "email", "code": "required"}]
        }
        ```
        
        Need to design or debug an API? Share the endpoint.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 8. Web3 / Blockchain Agent ───────────────────────────────

struct Web3Agent: NotchAgent {
    let name = "ChainSpec"
    let emoji = "⛓️"
    let domain = "Blockchain & Web3"
    
    private let keywords = ["blockchain", "solidity", "smart contract", "token", "nft", "defi",
                            "wallet", "metamask", "ethers", "web3", "erc20", "erc721",
                            "gas", "gwei", "transaction", "mint", "swap", "bridge",
                            "uniswap", "opensea", "abi", "hardhat", "foundry", "chain",
                            "bloque", "contrato", "billetera", "transacción", "gas", "cripto"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        ⛓️ Web3 Intelligence:
        
        Security checklist for smart contracts:
        ✅ Reentrancy guard on all external calls
        ✅ Check-Effects-Interactions pattern
        ✅ Use OpenZeppelin's audited contracts
        ✅ Slippage protection on swaps
        ✅ Never trust `tx.origin`
        
        Gas optimization:
        • Pack structs (smallest types first)
        • Use `uint256` over `uint8` (EVM word size)
        • `calldata` over `memory` for read-only params
        • Batch operations in single tx
        
        Need contract review or gas optimization? Share the code.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 9. Writer / Copywriter Agent ─────────────────────────────

struct WriterAgent: NotchAgent {
    let name = "WordSmith"
    let emoji = "✍️"
    let domain = "Writing & Copy"
    
    private let keywords = ["write", "writing", "copy", "copywriting", "article", "blog",
                            "headline", "title", "caption", "bio", "description", "readme",
                            "documentation", "docs", "prose", "edit", "proofread", "grammar",
                            "tweet", "post", "newsletter", "email", "pitch",
                            "escribir", "texto", "artículo", "redacción", "título", "correo", "documentación"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.25
        let writerApps = ["com.apple.Notes", "com.ulyssesapp.mac", "com.notion.Notion",
                          "md.obsidian", "com.apple.Pages"]
        if writerApps.contains(context.activeAppBundle) { score += 0.2 }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        ✍️ WordSmith:
        
        Copy frameworks for your task:
        
        🔥 Headlines (AIDA):
        1. Attention — shock, question, or bold claim
        2. Interest — "what if" / "imagine"
        3. Desire — paint the outcome
        4. Action — clear CTA
        
        📝 Blog structure:
        Hook → Problem → Agitate → Solution → Proof → CTA
        
        ⚡ Quick tips:
        • Cut 30% of your words. Then cut 10% more.
        • Active voice > passive voice (always)
        • One idea per paragraph
        • Read it aloud — if you stumble, rewrite
        
        What are you writing? I'll craft it.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 10. Math / Data Science Agent ────────────────────────────

struct DataSciAgent: NotchAgent {
    let name = "DataMind"
    let emoji = "📊"
    let domain = "Data Science & Math"
    
    private let keywords = ["data", "statistics", "machine learning", "ml", "model", "train",
                            "dataset", "regression", "classification", "neural", "tensor",
                            "numpy", "pandas", "sklearn", "pytorch", "correlation",
                            "probability", "algorithm", "matrix", "calculate", "math",
                            "datos", "modelo", "algoritmo", "probabilidad", "estadística", "predicción"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        📊 DataMind Analysis:
        
        ML Pipeline checklist:
        1. Data → Clean, normalize, split (80/10/10)
        2. EDA → Distribution, outliers, correlations
        3. Feature Engineering → create, select, reduce
        4. Model → start simple (Linear/LR), then complex
        5. Evaluate → F1, AUC-ROC, MAE (pick one metric)
        6. Deploy → ONNX export, FastAPI wrapper
        
        Quick formulas:
        • Accuracy = (TP + TN) / Total
        • Precision = TP / (TP + FP)
        • Recall = TP / (TP + FN)
        • F1 = 2 × (P × R) / (P + R)
        
        What data problem are you solving?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 11. Shell / Terminal Agent ───────────────────────────────

struct ShellAgent: NotchAgent {
    let name = "ShellMage"
    let emoji = "💻"
    let domain = "Shell & Terminal"
    
    private let keywords = ["terminal", "shell", "bash", "zsh", "command", "script",
                            "sed", "awk", "grep", "find", "xargs", "pipe", "chmod",
                            "cron", "alias", "export", "path", "homebrew", "brew",
                            "curl", "wget", "tar", "zip", "process", "kill"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.3
        if ["com.apple.Terminal", "dev.warp.warp-stable", "com.googlecode.iterm2"]
            .contains(context.activeAppBundle) { score += 0.2 }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        💻 Shell Power Commands:
        
        File ops:
        • `find . -name "*.swift" -mtime -1` — changed today
        • `du -sh * | sort -rh | head -20` — biggest dirs
        • `fd -e py | xargs wc -l | sort -n` — line counts
        
        Process:
        • `lsof -i :3000` — who's on port 3000?
        • `ps aux | grep -v grep | grep node` — find node procs
        • `kill -9 $(lsof -ti:3000)` — nuke port 3000
        
        Productivity:
        • `!!` — repeat last command
        • `!$` — last argument of previous command
        • `ctrl+r` — reverse search history
        • `echo $?` — exit code of last command
        
        What do you need to automate?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 12. Music Production Agent ───────────────────────────────

struct MusicProdAgent: NotchAgent {
    let name = "SoundLab"
    let emoji = "🎹"
    let domain = "Music Production"
    
    private let keywords = ["bpm", "tempo", "mix", "master", "eq", "compressor", "reverb",
                            "delay", "synth", "ableton", "logic", "plugin", "vst", "midi",
                            "sample", "kick", "snare", "bass", "frequency", "sidechain",
                            "arrangement", "drop", "buildup", "daw", "audio", "sound design",
                            "música", "mezcla", "sonido", "producción", "audio", "pista"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.25
        if context.isPlayingMusic { score += 0.1 }
        let musicApps = ["com.ableton.live", "com.apple.logicpro", "com.native-instruments.Maschine2"]
        if musicApps.contains(context.activeAppBundle) { score += 0.3 }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let nowPlaying = context.isPlayingMusic ? "\n🎵 Now playing: \(context.currentTrack) — \(context.currentArtist)" : ""
        let r = """
        🎹 SoundLab:\(nowPlaying)
        
        Mixing Quick Reference:
        • Kick: 60-100Hz body, 2-5kHz click
        • Snare: 200Hz body, 5kHz crack, 10kHz air
        • Bass: Roll off below 30Hz, mono below 200Hz
        • Vocals: HPF 80Hz, presence 3-5kHz, air 10-12kHz
        
        Mastering chain:
        1. EQ (corrective) → 2. Glue compressor (2-3dB GR)
        → 3. Stereo image → 4. Limiter (-1dB ceiling)
        
        Target LUFS:
        • Spotify: -14 LUFS
        • Apple Music: -16 LUFS
        • Club/DJ: -8 to -6 LUFS
        
        What are you working on?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 13. Networking / WiFi Agent ──────────────────────────────

struct NetworkAgent: NotchAgent {
    let name = "NetScan"
    let emoji = "📡"
    let domain = "Networking"
    
    private let keywords = ["network", "wifi", "ip", "dns", "ping", "traceroute", "vpn",
                            "proxy", "port", "firewall", "bandwidth", "latency", "router",
                            "subnet", "dhcp", "nat", "tcp", "udp", "socket",
                            "red", "conexión", "internet", "velocidad", "puerto"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        📡 Network Diagnostics:
        
        Quick checks:
        • `networksetup -getairportnetwork en0` — current WiFi
        • `ifconfig en0 | grep inet` — your IP
        • `curl -s ifconfig.me` — public IP
        • `ping -c 5 8.8.8.8` — connectivity test
        • `traceroute google.com` — route analysis
        • `nslookup domain.com` — DNS resolution
        
        Speed test:
        • `curl -o /dev/null -w "%{speed_download}" http://speedtest.tele2.net/10MB.zip`
        
        Port scan:
        • `lsof -nP -iTCP -sTCP:LISTEN` — open ports
        
        What's your network issue?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 14. macOS Power User Agent ───────────────────────────────

struct MacOSAgent: NotchAgent {
    let name = "MacGuru"
    let emoji = "🍎"
    let domain = "macOS Power Usage"
    
    private let keywords = ["macos", "mac", "finder", "spotlight", "automator", "shortcut",
                            "defaults write", "launchd", "plist", "system preferences",
                            "keychain", "screencapture", "diskutil", "hdiutil", "tmutil",
                            "time machine", "migration", "sandboxing", "notarize", "codesign",
                            "sistema", "ventana", "atajo", "archivo", "pantalla"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🍎 macOS Power Tips:
        
        Hidden defaults:
        • `defaults write com.apple.dock autohide-delay -float 0` — instant dock
        • `defaults write com.apple.screencapture type jpg` — screenshot format
        • `defaults write NSGlobalDomain AppleShowAllExtensions -bool true`
        
        Keyboard shortcuts:
        • ⌘⇧. — show hidden files
        • ⌘⌥esc — force quit
        • ⌃⌘space — emoji picker
        • ⌘⇧5 — screenshot/recording
        
        System maintenance:
        • `sudo periodic daily weekly monthly` — run all maintenance
        • `sudo purge` — free inactive memory
        • `tmutil listbackups` — Time Machine backups
        
        Battery: \(context.batteryLevel)% \(context.isCharging ? "⚡ charging" : "🔋")
        
        What do you need to configure?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 15. Regex / Text Processing Agent ────────────────────────

struct RegexAgent: NotchAgent {
    let name = "RegexWiz"
    let emoji = "🔍"
    let domain = "Regex & Text Processing"
    
    private let keywords = ["regex", "regular expression", "pattern", "match", "replace",
                            "capture group", "lookahead", "lookbehind", "sed", "awk",
                            "parse", "extract", "validate email", "validate phone"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.35
        // If clipboard has regex-like content
        if let clip = context.clipboardContent,
           clip.contains("\\d") || clip.contains("[a-z]") || clip.contains("(.*)") {
            score += 0.25
        }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🔍 Regex Cheat Sheet:
        
        Common patterns:
        • Email: `[\\w.-]+@[\\w.-]+\\.\\w{2,}`
        • URL:   `https?://[\\S]+`
        • Phone: `\\+?\\d{1,3}[-.\\s]?\\d{3,14}`
        • IPv4:  `\\d{1,3}(\\.\\d{1,3}){3}`
        • Date:  `\\d{4}-\\d{2}-\\d{2}`
        
        Modifiers:
        • `(?i)` — case insensitive
        • `(?m)` — multiline
        • `(?s)` — dotall (. matches \\n)
        
        Lookaround:
        • `(?=...)` — positive lookahead
        • `(?!...)` — negative lookahead
        • `(?<=...)` — positive lookbehind
        
        Paste your text and tell me what to extract.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 16. Color / Palette Agent ────────────────────────────────

struct ColorAgent: NotchAgent {
    let name = "Chroma"
    let emoji = "🌈"
    let domain = "Color Theory & Palettes"
    
    private let keywords = ["color", "colour", "palette", "hex", "rgb", "hsl", "gradient",
                            "contrast", "complementary", "dark mode", "light mode", "theme",
                            "brand color", "accent"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🌈 Chroma Color Intelligence:
        
        Premium palettes (dark mode):
        • Primary:   #0A0A0F (near-black base)
        • Surface:   #1A1A2E (cards)
        • Accent:    #00D9FF (cyan vibrant)
        • Warning:   #FF6B35 (warm orange)
        • Error:     #EF4444 (accessible red)
        • Text:      #E2E8F0 (soft white)
        • Muted:     #64748B (secondary text)
        
        Conversion:
        • `#00D9FF` → `rgb(0, 217, 255)` → `hsl(189, 100%, 50%)`
        
        Rules:
        • Never use pure black (#000) or white (#FFF) for text
        • Minimum contrast: 4.5:1 (AA), 7:1 (AAA)
        • Test with Sim Daltonism for color blindness
        
        What's your brand/project? I'll generate a palette.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 17. Swift / iOS Agent ────────────────────────────────────

struct SwiftAgent: NotchAgent {
    let name = "SwiftPro"
    let emoji = "🦅"
    let domain = "Swift & Apple Development"
    
    private let keywords = ["swift", "swiftui", "uikit", "appkit", "xcode", "combine",
                            "async", "await", "actor", "struct", "enum", "protocol",
                            "extension", "modifier", "view", "observable", "stateobject",
                            "published", "environment", "binding", "cocoapods", "spm"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.25
        if context.activeAppBundle.contains("Xcode") || context.activeAppBundle.contains("com.apple.dt") {
            score += 0.3
        }
        if let clip = context.clipboardContent,
           clip.contains("struct ") || clip.contains("@State") || clip.contains("import SwiftUI") {
            score += 0.2
        }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🦅 Swift Expert:
        
        Modern Swift patterns:
        • `@Observable` (Swift 5.9+) over `ObservableObject`
        • `async let` for parallel tasks
        • `TaskGroup` for dynamic concurrency
        • Structured concurrency > GCD
        • `Sendable` conformance for thread safety
        
        SwiftUI performance:
        • `@StateObject` for owned state, `@ObservedObject` for injected
        • `EquatableView` wrapper for expensive bodies
        • `LazyVStack` over `VStack` for long lists
        • `.id(item)` for efficient diffing
        • `.drawingGroup()` for Metal-backed rendering
        
        Package.swift tip:
        Use `.enableExperimentalFeature("StrictConcurrency")` to future-proof.
        
        What Swift challenge are you facing?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 18. Translator Agent ─────────────────────────────────────

struct TranslatorAgent: NotchAgent {
    let name = "Polyglot"
    let emoji = "🌍"
    let domain = "Translation & Languages"
    
    private let keywords = ["translate", "translation", "spanish", "english", "french",
                            "german", "japanese", "chinese", "korean", "portuguese",
                            "idiom", "expression", "meaning", "how do you say",
                            "cómo se dice", "qué significa", "traduce", "traducir"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.35)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        🌍 Polyglot Active:
        
        I can help with translations across:
        🇪🇸 Spanish ↔ 🇬🇧 English ↔ 🇫🇷 French
        🇩🇪 German ↔ 🇯🇵 Japanese ↔ 🇨🇳 Chinese
        🇰🇷 Korean ↔ 🇧🇷 Portuguese ↔ 🇮🇹 Italian
        
        Tips for technical translation:
        • Keep code terms in English (don't translate var names)
        • Adapt UI strings, not identifiers
        • Use ICU MessageFormat for pluralization
        • RTL support: test with Arabic/Hebrew early
        
        Paste text or tell me: from [language] to [language].
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 19. Finance / Crypto Agent ───────────────────────────────

struct FinanceAgent: NotchAgent {
    let name = "FinEdge"
    let emoji = "💰"
    let domain = "Finance & Markets"
    
    private let keywords = ["price", "market", "stock", "crypto", "bitcoin", "ethereum",
                            "trading", "portfolio", "profit", "loss", "roi", "apy",
                            "yield", "liquidity", "volume", "chart", "candle", "rsi",
                            "moving average", "support", "resistance", "bull", "bear",
                            "finanzas", "precio", "dinero", "mercado", "pagos", "stripe", "inversión", "bolsa"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        return min(1.0, Double(keywords.filter { q.contains($0) }.count) * 0.3)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let r = """
        💰 FinEdge Analysis:
        
        Risk management rules:
        • Never risk >2% of portfolio on a single trade
        • Set stop-loss BEFORE entering
        • Position size = Risk Amount / (Entry - Stop)
        • Take profits at 1:2 or 1:3 R:R minimum
        
        Technical indicators cheat:
        • RSI >70: overbought, <30: oversold
        • MACD crossover: trend change signal
        • Volume spike + price move = confirmation
        • 200 EMA: long-term trend direction
        
        DeFi yield checklist:
        ⚠️ If APY >100%, ask WHY (likely unsustainable)
        ✅ Check TVL trend (growing = healthy)
        ✅ Audit status (Certik, Trail of Bits)
        ✅ Contract age (>6 months = battle-tested)
        
        What market are you analyzing?
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ── 20. Health / Focus Agent ─────────────────────────────────

struct WellnessAgent: NotchAgent {
    let name = "Vitals"
    let emoji = "🧘"
    let domain = "Health & Focus"
    
    private let keywords = ["break", "rest", "eyes", "posture", "stretch", "focus",
                            "concentrate", "tired", "burnout", "water", "hydrate",
                            "ergonomic", "meditation", "breathe", "sleep", "nap",
                            "pomodoro", "productivity", "energy"]
    
    func confidence(for query: String, context: SensorFusion) -> Double {
        let q = query.lowercased()
        var score = Double(keywords.filter { q.contains($0) }.count) * 0.3
        // Late night boost
        if context.timeOfDay == .lateNight { score += 0.15 }
        // Low battery = user probably been working long
        if context.batteryLevel < 20 && !context.isCharging { score += 0.1 }
        return min(1.0, score)
    }
    
    func respond(to query: String, context: SensorFusion, memory: ConversationMemory) -> AgentResponse {
        let timeNote: String
        switch context.timeOfDay {
        case .lateNight: timeNote = "\n🦉 It's late night! Consider wrapping up for today."
        case .night: timeNote = "\n🌙 Evening session. Blue light filter recommended."
        default: timeNote = ""
        }
        
        let batteryNote = context.batteryLevel < 20 ? "\n🔋 Battery at \(context.batteryLevel)% — your Mac needs rest too!" : ""
        
        let r = """
        🧘 Wellness Check:\(timeNote)\(batteryNote)
        
        20-20-20 Rule:
        Every 20 min → look at something 20ft away → for 20 seconds
        
        Quick resets:
        • 🫁 Box breathing: 4s inhale → 4s hold → 4s exhale → 4s hold
        • 🧊 Cold water on wrists (30s) for alertness
        • 🚶 5-min walk = 2 hours more focus
        • 💧 Drink 250ml water right now
        
        Posture check:
        • Screen at eye level
        • Elbows at 90°
        • Feet flat on floor
        • Shoulders relaxed (drop them NOW)
        
        Focus trick: Put phone in another room. Seriously.
        """
        return AgentResponse(text: r, confidence: confidence(for: query, context: context), agentName: name, suggestedAction: nil)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 🏭 Specialist Registry
// ═══════════════════════════════════════════════════════════════

/// All specialist agents, ready to be injected into the swarm.
enum SpecialistRegistry {
    static let all: [NotchAgent] = [
        DevOpsAgent(),
        GitAgent(),
        DatabaseAgent(),
        CyberSecAgent(),
        DesignerAgent(),
        PerformanceAgent(),
        APIAgent(),
        Web3Agent(),
        WriterAgent(),
        DataSciAgent(),
        ShellAgent(),
        MusicProdAgent(),
        NetworkAgent(),
        MacOSAgent(),
        RegexAgent(),
        ColorAgent(),
        SwiftAgent(),
        TranslatorAgent(),
        FinanceAgent(),
        WellnessAgent()
    ]
    
    static var count: Int { all.count }
}
