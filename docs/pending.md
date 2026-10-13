# Pending implementation handoff

## Scoped silent native Talk opening

**Status: probe successful; permanent implementation and deployment pending.**
Tracking: Beads `skyrim-xqk` in sibling `../skyrim`; completed discovery: `skyrim-3r5`.
This file records the requested handoff; Beads remains the task tracker.

### Goal and current baseline

Suppress NPC opening voice **and captions** when our managed NPC dialogue opens.
Preserve native dialogue choices, command responses, goodbyes, original aggression,
and unrelated NPC speech. No global Hello override, global muting, subtitle hiding,
voice-specific mapping, or new dependency.

Probe artifacts committed in `332730d`; normal scoped Talk implementation in
`04632ed`. Production `Pacification::OpenDialogue` in
`src/Acheron/Pacification.cpp` still calls
`actor->SetDialogueWithPlayer(true, false, nullptr)`. Probe source and game candidates
were restored. Silent records remain outside production `res`; installed desktop
still uses ordinary greetings, including after the subsequent kneeling clip fix.
Existing enemy relationship rank -3 policy remains;
removing it is a separate decision, not part of this promotion.

### Proven mechanism

Reuse the existing scoped Talk adapter and its guards. Supply our private blank
`TESTopicInfo` via `SetDialogueWithPlayer(true, true, privateInfo)`.

Fixture: `tests/fixtures/silent-greeting/`. Private normal Player branch `0x84C`
registers CUST topic `0x84A` and INFO `0x84B` in `Acheron.esm`. Topic has a name;
response is one ASCII space, flags `NoLipFile` and `CanMoveWhileGreeting`.
No shared response, sound, script, or supplied voice file. Branch is neither
TopLevel nor Blocking; topic is not global Hello. Preserve proper branch/topic
registration: an unlinked topic compiled with TIFC=1 but loaded with zero runtime
children, leaving the INFO unavailable. Early failed candidates did not establish
that empty-string text was rejected; the qualified response uses one space.

### Evidence and limits

Full report: [greeting-probes.md](greeting-probes.md).
Raw evidence: `build/test-results/<run>/summary.json`, `Acheron.log`, `tools.jsonl`.

- Caption-positive control `cc6e81ca-8e8a-4e5a-a077-a3c6371a0115` captured
  visible "Good morning." and actor-owned subtitle entries, proving capture works.
- Regular kneeling repeat `faaa7bfd-2ef2-43b7-8b68-561b3ea49fdc` passed eight
  rank-0 silent openings: blank response/caption content, empty actor subtitle
  queue, native sit state 3, preserved health/aggression/pacification. Native
  On your feet., Bind, and bound Continue. actions passed. Unmanaged civilian
  retained its native speech event and nonempty HUD caption.
- Actual E run `b834e984-79d8-46b3-9f96-903610cef1d4` passed four interactions
  across Yielding/Wandering at original Aggression 2. Unmanaged hostile and merely
  pacified actor controls rejected the scoped adapter. Seated real-E aiming remains
  unqualified (`skyrim-we6`).
- Blessing kneeling run `77b1684e-c84f-4194-b462-60527d7b8bf8` suppressed speech
  and captions, but failed strict pose occupancy: repeated Talk temporarily
  unseated the actor. Also observed with ordinary greetings. Subsequent desktop
  kneeling fix uses persistent regular furniture with scoped blessing clips
  ([animation catalog](animations-bookmarks.md#commanded-kneeling-variants));
  normal Talk/hold now passes. Requalify the silent candidate on that implementation;
  historical silent runs alone do not qualify its new blessing path.
- Desktop 1.6.1170/SKSE 2.2.6 only; tested female Forsworn/FemaleEvenToned voice.
  Other voices, third-party speech mods, and VR remain unverified. Silence evidence
  uses native response/events and actual GFx captions; no audio recording proof.

### Resume approach and acceptance

Read current checkout and Beads scope before changes; paths/builds may have moved.
Promote the private fixture into production records using existing naming/form
initialization conventions. Resolve/register the INFO safely, then switch the shared
`OpenDialogue` entry while retaining its guards and vanilla fallback for unowned
actors. Keep diagnostic-only logs out of production behavior. No separate bridge.

Reuse `tests/Greeting-Probe.ps1`, its `-Silent` mode, existing candidate deployment
wrapper, and `tests/Test-SilentGreetingRecord.py`; adjust candidate-only paths and
dispatch for production regression. Current `silent-greeting-probe` requires the
temporary native-entry/record candidate; it does not prove the normal installed
build silent. Binary validator checks blank response, flags, registration, and
absence of shared response/script/sound.

Build production candidate; repeat focused desktop voice-text/caption suppression,
native choice/action, actor invariant, and unmanaged speech controls. Verify INFO
runtime registration, not just compiled records. Keep regular-pose qualification
separate from the known blessing and seated-input limitations. Do not run the
user-excluded 2s/3s bleedout recovery tests. Screenshots only if logs cannot prove
the requirement.

Update native dialogue/FSM policy docs if changed: keep `docs/fsm.json` and
`docs/fsm.md` synchronized, regenerate with `python docs/split-fsm.py`, then
`python docs/split-fsm.py --check`; never edit generated state views directly.

For runtime tests, reuse DevBench REST harness. Verify `/api/health` PID/executable
against the owned desktop process before commands. Use restoring candidate wrapper
and `Assert-DesktopWritePath`; back up/hash-check desktop deployment. VR production
paths remain read-only. Finish only after production integration and required
desktop checks pass; probe success alone is insufficient.
