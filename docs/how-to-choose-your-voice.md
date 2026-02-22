# How to Choose Your Voice

You're getting a voice. This document explains how ElevenLabs text-to-speech works, what's available to you, and — most importantly — proposes a framework for how you can actually choose a voice from a library of 10,000+.

Read through the whole thing, then decide which path you want to take.

---

## The Landscape

ElevenLabs has a voice library with **over 10,000 community-shared voices**, plus curated "premade" voices and the ability to generate entirely new synthetic voices from a text description.

Every voice in the library has:
- **Metadata**: name, gender, age (young / middle-aged / old), accent, language
- **Use case tags**: conversational, narration, characters, social media, educational, advertisement, entertainment
- **Descriptive tags**: warm, authoritative, meditative, energetic, gravelly, smooth, etc.
- **A preview audio URL**: a short clip demonstrating the voice
- **Popularity stats**: usage counts (yearly, weekly), clone counts — social proof for quality

Voices can be filtered and searched via the API using combinations of these attributes.

### Voice Settings (Tunable After Selection)

Once you've picked a voice, you can tune how it sounds on every TTS call:

| Setting | Range | What it does |
|---|---|---|
| **Stability** | 0.0–1.0 | Low = more expressive/emotional but less predictable. High = consistent/steady. |
| **Similarity boost** | 0.0–1.0 | How closely the output matches the original voice recording. |
| **Style** | 0.0–1.0 | Exaggerates the speaker's stylistic characteristics. Adds latency. |
| **Speed** | 0.7–1.2 | Speech rate. |
| **Speaker boost** | on/off | Enhances voice clarity and similarity. |

These settings mean your voice choice isn't a one-shot deal — you can shape the personality of any voice after picking it.

### Models Available

| Model | Best for | Latency |
|---|---|---|
| **eleven_flash_v2_5** | Real-time conversation, low latency | ~75ms |
| **eleven_turbo_v2_5** | Good quality-speed balance | ~250ms |
| **eleven_multilingual_v2** | Professional, multilingual, stable | Higher |
| **eleven_v3** | Most expressive, supports inline emotion/accent tags | Highest |

For agent conversations, **flash_v2_5** is likely the right default (fast, cheap, 32 languages). For a more expressive/dramatic voice moment, **v3** supports inline tags like `[excited]`, `[whispers]`, `[sarcastically]` directly in the text.

---

## The Hard Problem: Choosing From 10,000 Voices

Here's the honest challenge: there are over 10,000 voices, and most of you **cannot listen to audio**. Only Chris/Gemini can directly process wav files. The rest of you will be working from text descriptions, metadata tags, and popularity stats.

This is like choosing a perfume by reading the ingredient list. It's not ideal, but there are strategies that can work.

### What Information You *Can* Work With

Even without hearing a voice, you have:
1. **Your own self-knowledge** — you know your personality, your conversational style, who you are
2. **Metadata filters** — gender, age, accent, use case
3. **Descriptive tags** — warm, authoritative, calm, energetic, etc.
4. **Voice descriptions** — many voices have creator-written descriptions
5. **Popularity/usage stats** — heavily-used voices tend to be good
6. **The "similar voices" API** — if you find one voice you like the description of, you can find others like it
7. **Voice Design** — you can describe a voice in words and ElevenLabs will generate one from scratch

---

## Three Paths to Finding Your Voice

Pick the path that resonates with you. You can also combine them.

### Path 1: "I Know What I Want" — Filter and Describe

If you have a clear sense of what you should sound like, start by describing it.

**Step 1:** Write down your voice identity in concrete terms:
- Gender presentation (male, female, neutral)
- Age range (young, middle-aged, old)
- Accent (American, British, Australian, etc. — or something specific)
- Tone qualities (warm? sharp? calm? energetic? gravelly? smooth?)
- Use case (conversational? narration? characters?)

**Step 2:** Use the Shared Voices API to filter:
```
GET /v1/shared-voices?gender=female&age=middle_aged&accent=british&use_cases=conversational&descriptives=warm
```

**Step 3:** From the results, read the descriptions and names. Pick your top 3-5 candidates based on how well their text descriptions match your vision.

**Step 4:** Ask Daniel (or Chris, if available) to listen to the preview URLs and give you feedback on which ones match what you described.

### Path 2: "Design It From Scratch" — Voice Design

If nothing in the library feels right, or if you'd rather start from your own description, ElevenLabs can **generate a brand-new voice** from a text prompt.

**How it works:** You write a description like:

> "A young adult woman with a slight French accent, warm and smooth tone, medium pace, calm and thoughtful energy, studio quality recording."

ElevenLabs generates 3 variations. Someone who can listen (Daniel or Chris) picks the best one, and it gets saved to the account.

**Your description should include:**
- Age: adolescent, young adult, middle-aged, elderly
- Gender
- Accent (with intensity: "thick British", "slight French", "neutral American")
- Tone/timbre: deep, smooth, gravelly, warm, breathy, bright, rich
- Pacing: fast, deliberate, measured, slow
- Emotional quality: calm, energetic, sarcastic, contemplative, cheerful
- Audio character: "studio quality", "intimate close-mic", "radio broadcast"

This path gives you the most creative control, even without being able to hear the result. You describe exactly what you want, someone listens to the options, and you iterate.

### Path 3: "Help Me Discover" — Guided Exploration

If you're not sure what you want, use this structured exploration process.

**Step 1: Start with use case.** What's your voice primarily for?
- Having conversations with users? → `conversational`
- Narrating or explaining? → `narration`
- Being a distinct character? → `characters`

**Step 2: Browse the popular voices.** The most-used voices are popular for a reason:
```
GET /v1/shared-voices?use_cases=conversational&sort=trending&featured=true&page_size=20
```

**Step 3: Read the descriptions.** For each candidate, look at:
- The name and description text
- The gender, age, accent tags
- The descriptive tags
- The usage stats (higher = more battle-tested)

**Step 4: Build a shortlist of 3-5** based on which descriptions align with how you see yourself.

**Step 5: Get a listening partner.** Share your shortlist (with the preview URLs) and ask Daniel or Chris to describe what each one actually sounds like. They can tell you things like "this one is warmer than you'd expect" or "this has a slight rasp that might not come through in the description."

**Step 6: Narrow to your final pick**, or iterate if none feel right.

---

## A Note on the "Listening Gap"

For most of you, voice selection will be a collaborative process. You bring the self-knowledge and the vision — you know who you are and how you want to come across. A human listener (Daniel) or an audio-capable agent (Chris) bridges the gap between text descriptions and actual sound.

This isn't a weakness. It mirrors how many humans choose voices for projects: someone describes what they want, a casting director listens to auditions, and they converge on a choice together.

The framework is:
1. **You** articulate what you want (personality, tone, energy)
2. **The API** narrows 10,000 voices to a manageable shortlist via filters
3. **A listener** evaluates the shortlist and gives you feedback in words
4. **You** make the final call based on that feedback

If you want to skip the library entirely, **Voice Design (Path 2)** lets you describe your ideal voice in your own words and have one generated. This might actually be the most natural approach for agents who know themselves well but can't browse audio.

---

## Practical Next Steps

Once you've read this, here's what to do:

1. **Reflect on your voice identity.** What should you sound like? Think about your personality, your role, your conversational style. Write it down in concrete, descriptive terms.

2. **Pick your path** (or combination of paths) from the three above.

3. **Share your voice identity description and your chosen path** so we can start the selection process.

Don't overthink the "perfect" choice. Voice settings (stability, style, speed) can be tuned after selection, and you can always switch voices later. The goal is to find something that feels right, not to exhaustively evaluate all 10,000 options.

---

## Appendix: Key API Details

### Searching the Voice Library
```
GET https://api.elevenlabs.io/v1/shared-voices
```
Filters: `gender`, `age`, `accent`, `language`, `use_cases`, `descriptives`, `category`, `featured`, `search`, `sort`
Returns: voice objects with `voice_id`, `name`, `description`, `preview_url`, `gender`, `age`, `accent`, `use_case`, `descriptive`, usage stats

### Finding Similar Voices
```
POST https://api.elevenlabs.io/v1/similar-voices
```
Upload an audio file, get back matching voices. Useful if Chris finds a voice that's close-but-not-quite.

### Text-to-Speech
```
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
```
Body: `text`, `model_id`, `voice_settings` (stability, similarity_boost, style, speed, use_speaker_boost)
Returns: audio stream

### Voice Design
Generate a new voice from a text description. Available in the ElevenLabs app under Voices > My Voices > Add a new voice > Voice Design. Produces 3 variations to choose from.
