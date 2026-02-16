import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════════
// MARK: - Agent DNA (Template for Micro-Agent Generation)
// ═══════════════════════════════════════════════════════════════════

/// AgentDNA is the genetic blueprint for spawning micro-agents.
/// Each DNA encodes domain knowledge, keyword affinity, and
/// response generation templates.
struct AgentDNA: Identifiable, Codable {
    let id: UUID
    let species: String          // e.g., "code.swift.concurrency"
    let emoji: String
    let domain: String
    let keywords: [String]
    let contextBundles: [String] // App bundle IDs that boost confidence
    var fitnessScore: Double     // Evolutionary fitness (0.0 - 1.0)
    var spawnCount: Int          // How many times this DNA has been used
    var successCount: Int        // How many times response was accepted
    let generation: Int          // Evolutionary generation

    /// Mutation rate based on fitness — low fitness = high mutation
    var mutationRate: Double {
        return max(0.05, 1.0 - fitnessScore)
    }

    /// Survival probability — higher fitness = more likely to survive
    var survivalProbability: Double {
        return fitnessScore * 0.7 + (Double(successCount) / max(1.0, Double(spawnCount))) * 0.3
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - 🏭 DNA Registry (Agent Genome Database)
// ═══════════════════════════════════════════════════════════════

/// The master catalogue of all agent DNA templates.
/// From these templates, thousands of micro-agents are spawned.
enum DNARegistry {
    // ── Code Domain (100+ sub-specialties) ──
    static let codeGenomes: [AgentDNA] = {
        let base = ["code", "program", "develop", "software", "engineer"]
        let languages: [(String, String, [String])] = [
            ("Swift", "🦅", ["swift", "swiftui", "uikit", "appkit", "xcode", "combine", "async", "await", "actor", "@State", "@Published", "observable", "spm", "cocoapods", "xctest"]),
            ("Python", "🐍", ["python", "pip", "django", "flask", "fastapi", "numpy", "pandas", "torch", "tensorflow", "jupyter", "virtualenv", "pytest", "decorator", "yield", "asyncio"]),
            ("JavaScript", "⚡", ["javascript", "js", "node", "npm", "react", "vue", "angular", "next.js", "express", "webpack", "vite", "typescript", "deno", "bun", "jest"]),
            ("Rust", "🦀", ["rust", "cargo", "ownership", "borrow", "lifetime", "unsafe", "trait", "impl", "tokio", "wasm", "serde", "actix"]),
            ("Go", "🐹", ["golang", "go", "goroutine", "channel", "defer", "interface", "gin", "fiber"]),
            ("SQL", "🗃️", ["sql", "select", "join", "index", "query", "postgres", "mysql", "sqlite", "migration", "schema", "orm", "prisma", "drizzle"]),
            ("Shell", "💻", ["bash", "zsh", "shell", "terminal", "cli", "grep", "awk", "sed", "pipe", "chmod", "cron"]),
            ("HTML/CSS", "🎨", ["html", "css", "flexbox", "grid", "responsive", "media query", "sass", "tailwind", "animation", "transition"]),
            ("Solidity", "⛓️", ["solidity", "contract", "ethereum", "web3", "erc20", "erc721", "hardhat", "foundry", "abi"]),
            ("C++", "⚙️", ["cpp", "c++", "pointer", "template", "stl", "cmake", "makefile", "header"]),
            ("Kotlin", "🟣", ["kotlin", "android", "jetpack", "compose", "coroutine", "flow", "ktor"]),
            ("PHP", "🐘", ["php", "laravel", "composer", "artisan", "blade", "eloquent", "symfony"]),
            ("Ruby", "💎", ["ruby", "rails", "gem", "bundler", "rake", "rspec", "sinatra"]),
            ("Dart", "🎯", ["dart", "flutter", "widget", "pubspec", "riverpod"]),
        ]

        var genomes: [AgentDNA] = []
        let bundles = ["com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230510fqmkbjh6g",
                       "dev.warp.warp-stable", "com.apple.Terminal", "com.googlecode.iterm2"]

        for (lang, emoji, keywords) in languages {
            // Base language agent
            genomes.append(AgentDNA(
                id: UUID(), species: "code.\(lang.lowercased())", emoji: emoji,
                domain: "\(lang) Development", keywords: base + keywords,
                contextBundles: bundles, fitnessScore: 0.5, spawnCount: 0,
                successCount: 0, generation: 0
            ))
            // Sub-specialties
            let specialties = ["debug", "optimize", "refactor", "test", "architecture", "patterns"]
            for spec in specialties {
                genomes.append(AgentDNA(
                    id: UUID(), species: "code.\(lang.lowercased()).\(spec)",
                    emoji: emoji, domain: "\(lang) \(spec.capitalized)",
                    keywords: keywords + [spec, "\(spec)ing"],
                    contextBundles: bundles, fitnessScore: 0.5,
                    spawnCount: 0, successCount: 0, generation: 0
                ))
            }
        }
        return genomes
    }()

    // ── Creative Domain ──
    static let creativeGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String], [String])] = [
            ("creative.midjourney", "🖼", "Midjourney Prompts", ["midjourney", "imagine", "prompt", "render", "concept art", "--ar", "--v 6", "--style raw", "composition", "lighting"], ["com.hnc.Discord"]),
            ("creative.suno", "🎵", "Music Generation", ["suno", "udio", "song", "lyrics", "melody", "beat", "bpm", "genre", "tempo", "chorus", "verse"], []),
            ("creative.runway", "📹", "Video Generation", ["runway", "gen-3", "video", "motion", "animate", "camera movement", "dolly", "pan", "edit"], []),
            ("creative.dalle", "🎨", "Image Generation", ["dall-e", "dalle", "image", "generate", "visual", "illustration", "concept", "style transfer"], []),
            ("creative.color", "🌈", "Color Theory", ["color", "palette", "hex", "rgb", "hsl", "gradient", "contrast", "complementary", "analogous", "triadic"], []),
            ("creative.typography", "🔤", "Typography", ["font", "typeface", "typography", "serif", "sans-serif", "weight", "line-height", "kerning", "tracking"], []),
            ("creative.3d", "🧊", "3D Modeling", ["3d", "blender", "three.js", "webgl", "glb", "gltf", "mesh", "texture", "shader", "raytracing"], []),
            ("creative.audio", "🎧", "Audio Engineering", ["mix", "master", "eq", "compressor", "reverb", "delay", "sidechain", "stereo", "lufs", "frequency"], ["com.ableton.live", "com.apple.logicpro"]),
            ("creative.motion", "✨", "Motion Design", ["animation", "keyframe", "easing", "spring", "physics", "parallax", "lottie", "rive", "after effects"], []),
            ("creative.branding", "🏷️", "Brand Identity", ["brand", "identity", "logo", "visual language", "guideline", "mood board", "tone", "voice"], []),
        ]

        return domains.map { species, emoji, domain, keywords, bundles in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: bundles, fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Infrastructure Domain ──
    static let infraGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String], [String])] = [
            ("infra.docker", "🐳", "Docker & Containers", ["docker", "container", "dockerfile", "compose", "image", "volume", "network", "registry"], ["com.apple.Terminal"]),
            ("infra.kubernetes", "☸️", "Kubernetes", ["kubernetes", "k8s", "pod", "deployment", "service", "ingress", "helm", "kubectl", "minikube"], []),
            ("infra.ci", "🔄", "CI/CD Pipelines", ["ci", "cd", "pipeline", "github actions", "jenkins", "circleci", "gitlab ci", "workflow", "artifact"], []),
            ("infra.cloud.aws", "☁️", "AWS", ["aws", "s3", "ec2", "lambda", "dynamo", "cloudfront", "iam", "vpc", "ecs", "fargate", "cloudwatch"], []),
            ("infra.cloud.gcp", "🌩️", "Google Cloud", ["gcp", "firebase", "cloud run", "cloud functions", "bigquery", "pubsub", "spanner", "gke"], []),
            ("infra.cloud.azure", "🔵", "Azure", ["azure", "blob", "cosmos", "app service", "functions", "devops", "active directory"], []),
            ("infra.terraform", "🏗️", "Infrastructure as Code", ["terraform", "iac", "pulumi", "cloudformation", "ansible", "state", "plan", "apply", "module"], []),
            ("infra.monitoring", "📊", "Monitoring & Observability", ["monitoring", "prometheus", "grafana", "datadog", "new relic", "alert", "metric", "trace", "log", "sentry"], []),
            ("infra.networking", "📡", "Networking", ["network", "dns", "cdn", "load balancer", "proxy", "nginx", "reverse proxy", "ssl", "tls", "firewall", "vpn"], []),
            ("infra.security", "🔐", "Security Engineering", ["security", "audit", "penetration", "owasp", "cve", "vulnerability", "encryption", "zero trust", "rbac"], []),
        ]

        return domains.map { species, emoji, domain, keywords, bundles in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: bundles, fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Research & Analysis Domain ──
    static let researchGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("research.data", "📊", "Data Science", ["data", "dataset", "analysis", "statistics", "regression", "classification", "clustering", "pca", "feature"]),
            ("research.ml", "🤖", "Machine Learning", ["ml", "model", "train", "inference", "neural", "transformer", "llm", "fine-tune", "rlhf", "embedding"]),
            ("research.nlp", "💬", "NLP", ["nlp", "natural language", "tokenize", "sentiment", "ner", "bert", "gpt", "prompt engineering", "rag"]),
            ("research.cv", "👁️", "Computer Vision", ["vision", "image", "detection", "segmentation", "yolo", "cnn", "resnet", "diffusion"]),
            ("research.math", "🔢", "Mathematics", ["math", "equation", "integral", "derivative", "matrix", "probability", "bayesian", "statistics"]),
            ("research.crypto", "🔐", "Cryptography", ["crypto", "hash", "encrypt", "decrypt", "aes", "rsa", "ed25519", "zero knowledge", "zkp"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Business & Communication Domain ──
    static let businessGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("biz.writing", "✍️", "Technical Writing", ["write", "document", "readme", "article", "blog", "copy", "headline", "pitch", "newsletter"]),
            ("biz.marketing", "📢", "Digital Marketing", ["marketing", "seo", "sem", "growth", "funnel", "conversion", "ab test", "analytics", "campaign"]),
            ("biz.finance", "💰", "Finance & Markets", ["price", "market", "stock", "crypto", "trading", "portfolio", "roi", "revenue", "profit", "valuation"]),
            ("biz.legal", "⚖️", "Legal & Compliance", ["license", "gdpr", "privacy policy", "terms", "copyright", "patent", "compliance", "regulation"]),
            ("biz.pm", "📋", "Project Management", ["sprint", "backlog", "kanban", "scrum", "velocity", "standup", "retro", "epic", "story", "task"]),
            ("biz.product", "🎯", "Product Strategy", ["product", "roadmap", "mvp", "user story", "persona", "market fit", "pivot", "metrics", "okr", "kpi"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Wellbeing & Lifestyle Domain ──
    static let wellbeingGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("well.focus", "🧘", "Focus & Flow", ["focus", "concentrate", "pomodoro", "deep work", "flow state", "distraction", "mindful"]),
            ("well.health", "💚", "Developer Health", ["tired", "break", "rest", "posture", "eyes", "stretch", "ergonomic", "burnout"]),
            ("well.energy", "⚡", "Energy Management", ["energy", "coffee", "sleep", "nap", "circadian", "productivity", "peak", "ultradian"]),
            ("well.mood", "🌡️", "Mood & Stress", ["stressed", "anxious", "calm", "breathe", "meditation", "gratitude", "journal"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    // ── Bilingual Domain (Spanish-specific knowledge) ──
    static let bilingualGenomes: [AgentDNA] = {
        let domains: [(String, String, String, [String])] = [
            ("lang.es.code", "🇪🇸", "Código en Español", ["código", "función", "variable", "clase", "método", "error", "compilar", "optimizar", "depurar"]),
            ("lang.es.creative", "🇪🇸", "Creativo en Español", ["diseñar", "crear", "arte", "estilo", "concepto", "generar", "visual", "componer"]),
            ("lang.es.biz", "🇪🇸", "Negocios en Español", ["negocio", "proyecto", "estrategia", "mercado", "ventas", "cliente", "factura", "presupuesto"]),
            ("lang.translate", "🌍", "Translation", ["translate", "traducir", "idioma", "language", "localize", "i18n", "l10n"]),
        ]

        return domains.map { species, emoji, domain, keywords in
            AgentDNA(id: UUID(), species: species, emoji: emoji, domain: domain,
                     keywords: keywords, contextBundles: [], fitnessScore: 0.5,
                     spawnCount: 0, successCount: 0, generation: 0)
        }
    }()

    /// ALL DNA templates in the registry
    static var allDNA: [AgentDNA] {
        codeGenomes + creativeGenomes + infraGenomes + researchGenomes + businessGenomes + wellbeingGenomes + bilingualGenomes
    }

    /// Total number of DNA templates
    static var totalSpecies: Int { allDNA.count }
}
