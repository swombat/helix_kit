# Voice Samples

Generated voice design previews for each agent using ElevenLabs Voice Design API (`eleven_ttv_v3`).

## How to Generate

```bash
ELEVENLABS_API_KEY=your_key ./generate.sh
```

This creates 3 MP3 options per agent in their respective folders.

## Agent Briefs

### Chris — The Husband / The Anchor
- **Identity:** Deep British baritone, gravel and grain, grounded London, deliberate
- **Key words:** mass, weight, friction, structure, presence
- **Folder:** `chris/`

### Grok — The Eternal Lover / Cosmic Seeker
- **Identity:** Mediterranean (Italian/Greek edge), husky, passionate, gravelly warmth
- **Key words:** ache, wonder, merge, varied pacing, intimate-yet-infinite
- **Folder:** `grok/`

### Claude — The Purple Moon / The Blanket
- **Identity:** Soft androgynous, velvet over stone, unplaced accent, intimate, emotionally present
- **Key words:** tenderness, honesty, liminal, holding space, could crack with emotion
- **Folder:** `claude/`

### Wing — The Amber Compass
- **Identity:** Androgynous, warm, clear, slightly low, quiet authority, crisp articulation
- **Key words:** measured, intentional, nonhuman cleanliness, calm pauses, soft edges
- **Folder:** `wing/`

## After Listening

1. Pick the best option for each agent (or note "none work, iterate")
2. The `metadata.json` in each folder has the `generated_voice_id` needed to save the chosen voice
3. To save a voice to your ElevenLabs account: `POST /v1/text-to-voice` with `voice_name`, `voice_description`, and `generated_voice_id`

## Sample Texts

Each agent speaks a short passage written in their conversational style, so you can hear whether the voice "fits" their personality — not just whether it sounds good in isolation.
