#!/usr/bin/env bash
# Demo script: scaffold a "job-hunt" world, generate 3 short vignettes,
# adapt one into a 4-panel comic script.
#
# Usage:
#   ./scripts/demo_job_hunt.sh            # fresh run (fails if world exists)
#   FORCE=1 ./scripts/demo_job_hunt.sh    # wipe the world dir first
#
# Requires OPENROUTER_API_KEY or OPENAI_API_KEY in the environment
# (the default world template uses openrouter + google/gemini-3-flash-preview).
#
# Outputs land at $WORLD:
#   content/pieces/vignette/*.md
#   content/pieces/comic-script/*.md
#   data/canon_deltas/*.yml
#   data/story_bible/characters.yml (seed + delta-applied)

set -euo pipefail

WORLD="${WORLD:-$HOME/worlds/job-hunt}"
EIDOS="${EIDOS:-/home/cutalion/code/one-review-man/eidos/exe/eidos}"

PREMISE="A 40-year-old programmer with 20+ years of experience quits his
stable job, convinced that landing a new one will be quick. Instead he
wakes up in the middle of the AI revolution: recruiters have been
replaced by spam funnels, take-home coding tests are graded by
hallucinating LLMs, every job post demands 7 years of a framework that's
3 years old, and his carefully crafted resume gets rewritten by an AI
that adds blockchain to his skill list. Deadpan, dry, quietly miserable
tone — observational humor, not slapstick."

if [[ -d "$WORLD" ]]; then
  if [[ "${FORCE:-0}" == "1" ]]; then
    echo "==> Wiping existing world at $WORLD"
    rm -rf "$WORLD"
  else
    echo "ERROR: $WORLD already exists. Re-run with FORCE=1 to wipe it." >&2
    exit 1
  fi
fi

echo "==> Scaffolding world at $WORLD"
# `eidos world new --quick` prompts for 4 answers in order:
#   1. World title
#   2. Author name
#   3. Short description (used as premise)
#   4. Languages (comma-separated)
# Pipe them via here-doc, one per line.
"$EIDOS" world new --quick -w "$WORLD" <<EOF
Job Hunt
Demo
$PREMISE
en
EOF

echo
echo "==> World status:"
"$EIDOS" world status -w "$WORLD"

# --- Short funny vignettes (3-4 sentences each) ---
# Vignette form defaults to ~400 words; --length 60 plus an explicit
# brevity constraint in the prompt keeps each piece tight.
echo
echo "==> Generating 3 short vignettes..."

"$EIDOS" produce vignette -w "$WORLD" --length 60 \
  --prompt "Micro-scene (3-4 sentences, hard cap): he applies to a senior
role at a company that laid him off six years ago. The posting is a
'fresh opportunity' from a recruiter whose last email to him was a
rejection. Dry deadpan tone."

"$EIDOS" produce vignette -w "$WORLD" --length 60 \
  --prompt "Micro-scene (3-4 sentences, hard cap): 3am take-home coding
test, an AI grades his solution and marks it wrong for a reason that is
itself wrong. He considers arguing with a bot for the rest of his
natural life. Dry deadpan tone."

"$EIDOS" produce vignette -w "$WORLD" --length 60 \
  --prompt "Micro-scene (3-4 sentences, hard cap): LinkedIn thinks he's
'open to work' as a blockchain developer because an AI helpfully
rewrote his profile overnight. A recruiter is already in his inbox.
Dry deadpan tone."

echo
echo "==> Pieces generated:"
"$EIDOS" piece list -w "$WORLD"

# Pick the most recent vignette to adapt into a comic.
LATEST_VIGNETTE=$(ls -t "$WORLD"/content/pieces/vignette/*.md | head -1)
VIG_ID=$(grep '^id:' "$LATEST_VIGNETTE" | head -1 | awk '{print $2}')

echo
echo "==> Latest vignette ($VIG_ID):"
cat "$LATEST_VIGNETTE"

echo
echo "==> Adapting $VIG_ID into a 4-panel comic script..."
# comic-script form gets all_characters + recent_events canon context
# automatically, so the model already knows about the protagonist the
# vignette introduced.
VIG_BODY=$(awk '/^---$/{c++; next} c==2' "$LATEST_VIGNETTE")
"$EIDOS" produce comic-script -w "$WORLD" \
  --prompt "Adapt this vignette into a 4-panel comic. Keep the deadpan.
Each panel: scene_description, characters, dialogue. Punchline lands in
panel 4.

VIGNETTE:
$VIG_BODY"

echo
echo "==> Final piece list:"
"$EIDOS" piece list -w "$WORLD"

echo
echo "==> Canon review (any findings this run produced):"
"$EIDOS" canon review -w "$WORLD" || true

echo
echo "==> Done. World at: $WORLD"
