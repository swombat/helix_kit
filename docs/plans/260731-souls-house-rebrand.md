# souls.house Rebrand Plan

**Status:** draft for review — 2026-07-31
**Domain:** `souls.house` (registered at Porkbun)
**Strategy:** external rebrand first (Phase 1), internal rename later (Phase 2). Mailgun is leaving with GT, so mail migration is part of Phase 1.

---

## Phase 0 — Decisions needed before starting

### 0.1 Mail provider (decide now — Mailgun is going away regardless of rebrand)

Current state: `config/environments/production.rb` gates all mail delivery on
`credentials.mailgun` and uses plain SMTP settings. Swapping providers = new
credentials block + from-address. No code surgery.

Volume reality check: souls.house sends password resets, email confirmations,
and the odd notification to a handful of humans. We are talking **tens of
emails per month**, not thousands.

**Option A — Free-tier SMTP provider (recommended)**

| Provider | Free tier | Notes |
|----------|-----------|-------|
| Brevo (ex-Sendinblue) | 300/day | Generous, SMTP creds, custom domain + DKIM |
| SMTP2GO | 1,000/month | Simple, good deliverability reputation |
| Resend | 3,000/month (100/day) | Modern, dev-friendly, SMTP interface available |
| Mailjet | 200/day | Fine, slightly clunkier dashboard |

- Cost: **$0** at our volume, indefinitely.
- Deliverability: their problem, and they're good at it.
- Work: sign up, verify `souls.house` (add SPF/DKIM records at Porkbun),
  paste SMTP creds into Rails credentials. ~30 minutes.
- Risk: free tiers can shrink (Mailgun's did). Mitigation: the config is
  provider-agnostic SMTP — switching again later is the same 30 minutes.

**Option B — Self-hosted mailer (docker image as Kamal accessory)**

e.g. `boky/postfix` (simple outbound relay, DKIM support) or
`docker-mailserver` (full mail stack — overkill, we only send).

- Cost: $0, fully sovereign, no third party.
- **Blocker 1: Hetzner blocks outbound port 25 by default.** You must request
  unblocking via support; they typically only grant it after the account is a
  month old and want justification. Until granted, a local mailer cannot
  deliver to the outside world at all.
- **Blocker 2: IP reputation.** Hetzner ranges appear on blocklists
  (UCEPROTECT etc.). Even with perfect rDNS + SPF + DKIM + DMARC, odds are
  meaningful that password resets land in spam — and a password reset in spam
  is the worst email to lose.
- Work: request port 25 unblock, set rDNS for 95.217.118.47 → souls.house,
  add accessory to deploy.yml, generate DKIM keys, publish DNS records,
  monitor blocklists. Hours up front, ongoing vigilance.

**Recommendation: Option A (Brevo or SMTP2GO).** Same price ($0), a fraction
of the work, and deliverability that just works. Option B stays documented
here as the sovereignty fallback if free tiers ever dry up — and if we ever
go there, the sensible shape is a postfix accessory *relaying through* a
provider anyway, which defeats the point. Decide: **[ ] A  [ ] B**

### 0.2 From-address

Suggest `hello@souls.house` for outbound, or `mail@souls.house`.
Decide: `____________@souls.house`

### 0.3 Site name styling

"souls.house" lowercase-as-wordmark? "Souls House"? "Souls.House"?
This string goes into `Setting.site_name`, page titles, and the 48 currently
hardcoded frontend strings. Decide: `____________`

---

## Phase 1 — External rebrand

Order matters: DNS first (it propagates while we work), deploy last.

### Step 1.1 — DNS at Porkbun ✅ 2026-08-01
- [x] `A` record: `souls.house` → `95.217.118.47` — had to delete Porkbun's
      two hidden "masked" parking records first (apex ALIAS + wildcard CNAME
      to pixie-parking.porkbun.com), which silently blocked apex A creation
- [ ] (optional) `A` record: `www.souls.house` → `95.217.118.47`
- [x] Verified at authoritative NS (`dig @curitiba.ns.porkbun.com`)

### Step 1.2 — Mail provider setup ✅ 2026-08-01 (Brevo)
- [x] Brevo account (Swombat Limited), `souls.house` added as sending domain
- [x] All 7 records live at Porkbun: brevo-code TXT, DKIM1+2 CNAMEs,
      DMARC (`p=none`), branded-link CNAMEs (mail / r.mail / img.mail)
- [x] Domain verified + authenticated + branded in Brevo (tracked links
      use mail.souls.house)
- [x] Sender `souls.house <hello@souls.house>` created + verified in Brevo
- [x] SMTP key `souls-house-production` generated (expires Aug 2027 — and
      after 90 days of *inactivity*, so note if the app ever goes dormant)
- [x] Inbound: Porkbun email forwarding `hello@souls.house → daniel@swombat.io`
      (MX fwd1/fwd2.porkbun.com + SPF record auto-added by Porkbun)

### Step 1.3 — Rails mail config ✅ 2026-08-01 (uncommitted; ships with Phase 1 deploy)
- [x] `smtp:` block added to BOTH `config/credentials/development.yml.enc`
      and `config/credentials/production.yml.enc` (per-env credentials repo)
- [x] `production.rb`: mailgun gate → `credentials.smtp` gate;
      `default_url_options` host → souls.house; auth "login"
- [x] `application_mailer.rb`: from → `souls.house <hello@souls.house>`
- [x] Tested: raw SMTP (net/smtp, 250 queued) AND full ActionMailer send
      with `RAILS_ENV=production` → Brevo reports 4/4 delivered, 0 bounces
- Discovery: credentials had NO mailgun block — production mail was never
  actually configured, so there is no legacy behavior to preserve.

### Step 1.4 — Content rebrand ✅ 2026-08-01 (branch: `rebrand/souls-house`)
- [x] New `app/frontend/lib/branding.js` — `siteName` derived store reading
      the globally-shared `site_settings.site_name` Inertia prop, fallback
      `DEFAULT_SITE_NAME = 'souls.house'`. Brand governed in one place;
      admin renames propagate live via the existing broadcast.
- [x] All frontend prose routed through `{$siteName}` (agent panels, api
      keys, admin pages, birth flow, promote/edit/onboarding); literal
      "souls.house" only where a live setting would be wrong (admin
      placeholder, legal pages)
- [x] `setting.rb` default → "souls.house"; layout title → `Setting.
      instance.site_name`; PWA manifest; confirmation mailer (html+text);
      `agent.rb` error message; `chat/contextualizable.rb` prose;
      User-Agent headers + deploy-key title (web_tool, agent_repo_creator)
- [x] terms.svelte + privacy.svelte — REWRITTEN, not sed: they were
      template boilerplate referencing Oura Ring / health data (never true
      of this app). Now describe the actual service incl. agent-memory
      retention honesty clause. Entity name kept as "the operator of
      souls.house" — confirm if a legal entity should be named.
- [x] home.svelte — full rewrite: was still the HelixKit app-kit marketing
      page. Now presents souls.house (hero + six-concept grid + hearth
      link). `home-features.js` deleted (unused). FeatureGrid/FeatureCard
      reused.
- [x] README.md — rewritten: souls.house first, HelixKit as heritage
      section, dev docs (sync system, json_attributes) preserved
- [x] Verified: `vite build` passes; Rails boots; dev `Setting.instance`
      returns souls.house
- **Deliberately NOT swept (agent-facing prompt layer):** `app/lib/
  external_agent_*_request.rb`, `agent_identity_exporter.rb` — these are
  the wake/orientation/trigger prompts live agents receive, and they
  reference `helixkit-api.md` as a real filename in agents' identity
  volumes. Rebranding that prose changes what running agents read
  mid-rebrand and tangles with the Phase-2 script/file renames. Decide
  together: sweep the brand-name prose now (agents will cope; arguably
  they should hear the new name) or hold it for Phase 2 with the symlink
  dance. Also held: `helixkit:agent-birth-draft` localStorage key,
  `helixkit_app_url` field names, `helix-kit-agents` image name,
  generated js-routes comments.

### Step 1.5 — Logo + favicon ✅ 2026-08-01
- [x] Mark chosen by Daniel from 5 candidates: **B** (roof sheltering a
      warm coral orb — "a soul, housed") plus **C's move** (in the
      wordmark, the mark sits in the domain-dot position: souls⌂house).
      Geometry tightened after live screenshot review (flatter roof
      hugging the orb so it reads as one glyph, snug viewBox so the orb
      sits on the baseline). `app/assets/images/souls-house-logo.svg` —
      roof `currentColor`, orb fixed coral #f15d61.
- [x] `HelixLogo`/`HelixKitLogo` (identical duplicates) collapsed into
      `SiteLogo.svelte`; 8 importers updated; old components + old
      `helix-kit-logo.svg` removed
- [x] Favicon set derived via rsvg-convert + magick: favicon.svg/icon.svg
      (theme-aware via prefers-color-scheme), favicon.ico (16/32/48 with
      heavier small-size stroke), favicon.png 96, icon.png 512,
      apple-touch-icon.png 180 (mark on deep-teal night bg)
- [x] Homepage: hero rebuilt — wordmark lockup with mark-as-dot, night
      scene illustration (`souls-house-night.svg`, hand-built, works on
      both themes), relational copy, Sorting Hat effect link, trimmed
      concept cards. Verified by screenshot light+dark on dev server.
- [ ] (optional) Upload logo to `Setting#logo` attachment in admin

### Step 1.6 — Deploy cutover
- [ ] `config/deploy.yml` proxy — switch `host:` to plural and dual-serve:
      ```yaml
      proxy:
        ssl: true
        hosts:
          - souls.house
          - helix-kit.granttree.co.uk   # transition; remove in Step 1.8
        app_port: 3000
        response_timeout: 120
      ```
- [ ] Confirm DNS resolves (Step 1.1) — Let's Encrypt issuance fails otherwise
- [ ] `kamal deploy`
- [ ] Verify: https://souls.house loads, cert valid, old domain still serves

### Step 1.7 — Production data + smoke test
- [ ] `Setting.instance.update!(site_name: "<chosen name>")` via console
- [ ] Trigger a password-reset email to a real mailbox; confirm delivery,
      inbox placement (not spam), correct from-address, correct link host
- [ ] Click through: login, registration flow, agent pages, admin

### Step 1.8 — Cleanup (after a comfortable transition window)
- [ ] Remove `helix-kit.granttree.co.uk` from proxy hosts, redeploy
      (coordinate with GT's Mailgun/DNS handover timing — the old hostname
      lives under their domain)
- [ ] Remove any lingering granttree.co.uk references
      (`grep -rn granttree` should come back empty in app/ and config/)

---

## Phase 2 — Internal rebrand (later, deliberate, one sitting)

**Why this is separated:** live agents run on this box. `helix-kit-web` is
the Docker DNS name agent callbacks resolve (`HELIXKIT_AGENT_INTERNAL_URL`);
restic backups target volumes whose paths embed the service name; Postgres
runs as `helix_kit`/`helix_kit_production`. None of it is user-visible.
Renaming it is a migration, not a find-replace.

**Prerequisite for the whole phase: a maintenance window with agents
stopped, and a verified fresh backup (DB dump + agent volumes).**

### Step 2.1 — Repo + image (safe, do first)
- [ ] GitHub rename `swombat/helix_kit` → `swombat/souls-house`
      (GitHub redirects old URLs; update local remotes)
- [ ] New Docker Hub repo `dtenner/souls-house`; update `image:` and
      builder cache image in deploy.yml

### Step 2.2 — Kamal service rename (the disruptive one)
Renaming `service: helix-kit` → `service: souls-house` gives new container
names, new proxy registration, and **new volume paths** — Kamal will not
migrate data.
- [ ] Inventory host volumes under the old service name (incl. agent
      persistent volumes)
- [ ] Stop agents; final backup
- [ ] `kamal remove` old service (proxy deregistration), keeping accessory
      data intact — **verify postgres data volume survives or snapshot it**
- [ ] Update deploy.yml: service, image, `network-alias: souls-house-web`
- [ ] Update env: `HELIXKIT_AGENT_INTERNAL_URL: http://souls-house-web:3000`
- [ ] Move/copy agent volumes to new paths; update restic backup targets
- [ ] `kamal setup` / `kamal deploy`; restart agents; verify callbacks

### Step 2.3 — Database rename (optional — weigh skipping permanently)
`helix_kit_production` → `souls_house_production` requires dump/restore or
`ALTER DATABASE ... RENAME` with all connections closed, plus user rename
and secrets updates. Zero user-visible benefit. **Recommend: don't.**
If done anyway: [ ] dump, [ ] rename, [ ] update DATABASE_URL secret,
[ ] update deploy.yml accessory env, [ ] verify.

### Step 2.4 — Code-level identifiers
- [ ] `HELIXKIT_*` env vars (17 references in app/lib/config) →
      `SOULSHOUSE_*`, with deploy.yml updated in the same commit
- [ ] agent-runtime scripts: `helixkit-post-message`,
      `helixkit-send-telegram`, `helixkit-append-journal` — **these are on
      PATH inside running agent containers and referenced in agent docs and
      possibly agents' own CLAUDE.md files.** Ship new names with old names
      as symlinks; keep symlinks indefinitely (agents' memories reference
      the old names)
- [ ] `agent-runtime/docs/helixkit-api.md` and runtime-instructions.md
- [ ] Rails module `HelixKit` in `config/application.rb` (mechanical;
      touches `config/environment.rb` references — do last, verify boot)
- [ ] Rebuild agent-runtime image; rolling-restart agents

### Step 2.5 — Verify
- [ ] Each agent: trigger a wake, confirm callback round-trip
- [ ] Nightly backup runs green against new volume paths
- [ ] `grep -ri "helix" app config lib agent-runtime` — remaining hits are
      deliberate (symlinks, changelog/docs history) and listed here

---

## Open items

- [ ] Logo direction — sketches to review (semantic territory: house/home/
      hearth/doorway; a few non-obvious candidates too)
- [ ] Confirm GT handover date for Mailgun (Phase 1 mail migration should
      land before that)
- [ ] Anything else pointing at helix-kit.granttree.co.uk externally?
      (bookmarks, agents' own configs/memories, Telegram webhook URLs —
      check webhook registration host before Step 1.8)
