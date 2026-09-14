# DocuMind — AI Document Intelligence Assistant

> **A local-first AI document intelligence application that indexes user documents on-device, performs contextual retrieval, and generates source-grounded responses through configurable AI providers.**

DocuMind is *not* "a chatbot for PDFs". It is a document workspace: your files stay on your device, get parsed → chunked → indexed (full-text + optional vector) locally, and every AI answer is grounded in retrieved passages with tappable page-level citations. The AI model is replaceable; the document intelligence system is the product.

---

## Feature highlights

| Area | What you get |
|---|---|
| **Formats** | PDF, TXT, Markdown, DOCX (full) · CSV, JSON, HTML (parsers included) · PPTX/XLSX/EPUB stubbed on the roadmap |
| **Local search** | SQLite FTS5 with BM25 ranking, snippets, document + page + section references — fully offline |
| **Semantic search / RAG** | On-device embeddings + cosine vector search fused with lexical retrieval, context-budgeted prompt construction |
| **Citations** | Every answer carries `[S1]…` markers resolved to real chunks (doc + page + snippet); fabricated markers are stripped, never shown |
| **Anti-hallucination** | Mandatory grounding rules in every prompt + post-processing that drops unverifiable citations + explicit "could not find" fallback |
| **AI providers** | Gemini (default, free tier), OpenRouter, Ollama (local) behind one `AiProvider` interface |
| **Document management** | Import, rename, favorite, delete, reprocess, collections, sort/filter, duplicate detection, processing states |
| **Scenarios** | Ask / Summarize / Study modes, multi-document Compare, résumé-vs-job-description analysis |
| **Offline** | Everything except new cloud AI answers works with zero connectivity; a persistent banner explains exactly what is available |
| **Privacy** | Documents and metadata never leave the device; only the minimal retrieved context is sent to the chosen provider |

---

## Architecture

```
lib/
├── ai/                        # Provider-agnostic AI layer
│   ├── ai_provider.dart       #   AiProvider interface, AiConfig, error mapping
│   ├── providers/             #   Gemini, OpenRouter, Ollama implementations
│   ├── embedding_service.dart #   Embeddings + cosine similarity (on-device)
│   ├── prompts.dart           #   Mode-specific prompts + grounding contract
│   ├── rag_service.dart       #   Hybrid retrieval → context → answer → citations
│   └── ai_service_factory.dart#   Config → concrete stack wiring
│
├── core/                      # Framework-free foundations
│   ├── constants/             #   Formats, tuning constants
│   ├── errors/                #   Typed, user-actionable exceptions
│   ├── services/              #   Storage paths, connectivity
│   ├── theme/                 #   Material 3 light/dark themes
│   └── utils/                 #   Chunker, text utilities
│
├── data/                      # Persistence + parsing
│   ├── datasources/           #   SQLite schema (FTS5 + embeddings), CRUD
│   ├── models/                #   Document, Chunk, Collection, Message, Citation
│   ├── parsers/               #   DocumentParser abstraction + per-format impls
│   └── repositories/          #   Library orchestration (import pipeline)
│
├── features/                  # UI, grouped by surface
│   ├── home/  library/  documents/  collections/
│   ├── search/  chat/  compare/  settings/
│   └── widgets/               #   Shared tiles, empty states, status chips
│
├── state/                     # Provider-based state management
│   ├── library_provider.dart  #   Import pipeline, filters, progress
│   ├── chat_provider.dart     #   Conversations, RAG calls, citations
│   ├── search_provider.dart   #   FTS5 queries, snippets
│   ├── home_provider.dart     #   Dashboard stats
│   └── settings_provider.dart #   Theme + AI config (SharedPreferences)
│
└── main.dart                  # DI wiring (MultiProvider) + app root
```

**Rules of the road:** widgets never touch SQLite/HTTP/parsers; state providers orchestrate; repositories coordinate filesystem + database; the AI layer depends only on its own interfaces.

---

## Processing pipeline

```
File picker
  ↓ duplicate/size/type checks
Copy into app-private storage (originals stay intact)
  ↓
Format detection → DocumentParser (registry)
  ↓ page/section-aware text extraction, [page N] markers
Chunking (paragraph-aware, ~1300 chars, overlap, heading metadata)
  ↓
SQLite chunks + FTS5 index  →  Ready (works offline forever)
  ↓ (best-effort, needs a key)
Embeddings → chunk_embeddings table
```

Progress is surfaced per document (`Queued → Extracting → Chunking → Indexing → Ready`) with a live progress bar. Failures set a typed, actionable error message — e.g. scanned PDFs report *"does not contain selectable text — OCR is planned"* instead of "something went wrong".

---

## Retrieval & citation flow

```
Question
  ↓ FTS5 (BM25, prefix-OR query) ──┐
  ↓ query embedding (optional) ────┤  merge by chunk, agreement bonus
  ↓ context budget (8 chunks / 16k chars)
Prompt = mode system prompt + [S1]…[Sn] tagged context + history
  ↓
Provider (Gemini / OpenRouter / Ollama)
  ↓
Resolve [Sn] → citations · DROP unknown markers · render source chips
```

Anti-hallucination is enforced **twice**: the prompt forbids invented sources and demands an explicit "not in your documents" answer, and post-processing only keeps citations that map to actually-retrieved chunks.

---

## AI provider configuration

Set up in **Settings → AI Provider** — no keys are compiled into the binary:

| Provider | Needs | Notes |
|---|---|---|
| **Google Gemini** (default) | Free API key from [Google AI Studio](https://aistudio.google.com/apikey) | `gemini-2.0-flash` family; embeddings via `gemini-embedding-001` |
| **OpenRouter** | API key | One key, many models (Llama, Claude, GPT-4o-mini, …) |
| **Ollama** | Server URL on the same network | Fully local inference + local embeddings (`nomic-embed-text`); no cloud, no key |

**Key storage:** the key lives in `SharedPreferences` on-device and is sent only to the provider you configured.

> **Security note for production:** shipping a fixed API key inside a distributed app binary allows extraction and abuse. For a public release, proxy provider calls through your own backend or use a server-side gateway (e.g. Firebase App Check + token-scoped proxy). This project intentionally keeps a *bring-your-own-key* model so it stays local-first and zero-cost to operate, and cleanly separates development credentials from the production architecture.

---

## Privacy & data flow

```
Document file ──► on-device copy + extraction + indexing   (never uploaded)
Question      ──► local retrieval ──► minimal context ──► AI provider
Chat history  ──► local SQLite (deletable per conversation)
```

The Settings → Privacy section explains this inside the app: where documents are stored, what leaves the device, which provider is active, and that switching to Ollama (or going offline) stops all cloud sharing.

---

## Offline behavior

Available offline: full library management, full-text search with snippets, collections, reading previous conversations, dashboards. New cloud AI answers are blocked with a clear explanation banner — never a generic network error.

---

## Running

```bash
flutter pub get
flutter run            # Android-first; also runs on Linux desktop
flutter test           # unit tests: chunker, text utils, models, RAG retrieval
flutter analyze        # zero errors / zero warnings
```

Linux desktop needs `libsqlite3` (the app auto-switches to `sqflite_common_ffi` off mobile).

---

## Roadmap

- **Parsers:** PPTX (XML text extraction, same pattern as DOCX), XLSX, EPUB
- **OCR** for scanned PDFs and images (tesseract / ML Kit), upgrading the current "no selectable text" error into a real pipeline
- **Streaming responses** and richer chat UI (markdown tables, per-citation highlight jumps)
- **Contract mode** with the fixed legal disclaimer, per-collection scope presets
- **Background indexing isolate** for very large imports
- Optional vector index acceleration if libraries grow beyond tens of thousands of chunks
# DocuMind
