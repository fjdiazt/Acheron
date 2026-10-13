# Kneeling interaction greetings: desktop probes

Observed spoken NPC lines, not player dialogue choices. Diagnostic engine
`TESTopicInfoEvent` start/end logs identify the actual speaker/INFO/topic/subtype.
Native `MenuTopicManager` selected responses supply text and voice paths.
No screenshots or audio transcription used. Desktop 1.6.1170, disposable female
Forsworn, FemaleEvenToned voice, original Aggression 2. VR untouched.

## Baseline

Run `630dfc5a-90f3-4faa-b070-f773cb39a6d7`, eight activations at each relationship rank:

| Rank | Triggered lines |
| --- | --- |
| -3 | Good morning. (3); Need something? (2); Hmm? (1); Yes? (1); I hope the wilds claim you, one of these days. (1) |
| 0 | Good morning. (3); Need something? (3); Hmm? (1); Yes? (1) |

All 16 interactions began with actual native furniture occupancy; sit state remained
3 when choices became ready. On your feet., Bind, and bound Continue. selected real
native INFOs. Health, aggression and pacification remained intact; no combat.
Rank controls apply only to the disposable actor, deleted during cleanup.

An earlier fixture run failed on natural health regeneration. Regen was disabled
on the disposable fixture. Another run observed sit state 0 during rapid repeated
interaction. The completed probe waits for real kneeling occupancy before each
activation and records sit state during dialogue; it does not treat an FSM label
alone as proof of kneeling or discard failed runs.

## Source findings

Local Skyrim.esm records explain why rank changes are insufficient:

- `DialogueGenericHello` topic `000142B5`: Hello subtype 79. INFO `00087947`
  (`Need something?`) and `000142C0` (`Hmm?`) are Random and have no INFO-level
  relationship condition. `DialogueGeneric` quest `00013EB3` excludes commanded
  actors and restricts voice types; it does not require friendly relationship rank.
- Relationship Hello INFO `00020BA0` has `GetRelationshipRank(Player) <= -1` and
  FemaleEvenToned voice conditions. It adds a resentful line to eligible greetings;
  it does not remove the generic pool.
- `AcheronPeacefulKneel`/`AcheronPeacefulKneelBound` packages permit
  `HellosToPlayer`. Native package interrupt permission is separate from the Hello
  selected when the player deliberately opens Talk.
- CommonLib exposes native `SetDialogueWithPlayer(bool, bool forceGreet,
  TESTopicInfo*)`. Local 1.6.1170 disassembly shows the explicit INFO used in the
  force-greet path; the ordinary path obtains greeting selection itself.
- No greeting Papyrus fragments are attached to sampled generic/resentful INFOs.
  Existing Acheron action dispatch remains separate in `EventSink.cpp`.

Creation Kit wiki pages were requested but returned HTTP 403. Probe decisions use
local native headers, disassembly, scripts and actual plugin records, rather than
unverified documentation claims. Further documentation references:
[Topic Info](https://ck.uesp.net/wiki/Topic_Info),
[Misc Tab](https://ck.uesp.net/wiki/Misc_Tab),
[CommonLib actor declaration](../lib/CommonLibSSE-NG/include/RE/A/Actor.h).

## Explicit native greeting candidate

Run `370396ab-2173-4d29-a028-433336be95d5`. Temporarily changed the existing scoped
Talk entry to `SetDialogueWithPlayer(true, true, INFO 00020BA0)`.

16/16 activations selected the same antagonistic vanilla line, including all eight
rank-0 cases. Native choices, On your feet., Bind, bound Continue., sit state 3,
unchanged health/aggression and pacification all passed. Candidate restored by the
deployment wrapper; no permanent greeting policy applied.

This proves a native mechanism independent of relationship edits for this voice.
It is not a universal production fix: hardcoded INFO bypasses its authored
relationship/reset eligibility and is unsuitable for other voices or civilians.
The repeated baseline and explicit-entry runs used the regular kneeling family;
other pose/voice combinations need separate qualification.

## Package Hello permission control

Run `c41b13da-13c7-4c30-b6e6-1fb5daff82fe`. Temporary candidate clears
`PACKAGE_DATA::InterruptFlag::kHellosToPlayer` on only our kneeling/bound package
records in memory, then uses the original ordinary native Talk entry. Logs confirm
the flag-clear path executed. No global/native NPC package or disk record changed.

All 16 native interactions and action controls completed, but Hello still selected
Good morning., Hmm?, Need something?, What do you need?, Yes?, and one resentful
line. Thus clearing ambient package permission does not solve deliberate Talk
greetings. Two samples recorded sit state 0 during dialogue, returning to native
kneeling before the next interaction. This candidate is not qualified as a pose
fix. Earlier unmodified greeting sampling also observed temporary unseating in the
blessing family; the completed regular-family baseline/explicit runs stayed at 3.
All candidates were restored; no package policy change is retained.

Recommended follow-up: owned greeting INFOs with voice-appropriate vanilla shared
responses, selected through the existing scoped Talk adapter. Scope antagonistic
greetings to enemies captured before pacification; preserve civilian/quest dialogue.
Use dedicated INFO IDs without action handlers, so opening Talk cannot execute a
command. Validate supported voices and action/pose controls. A silent greeting is
another policy option, but was not qualified in these probes. Keep relationship
policy unchanged until that production route is implemented and tested.

## Reproduction and evidence

```powershell
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test greeting-probe
```

Diagnostic observation case outside the routine suite. PASS means collection and
native controls passed, not that greetings are appropriately antagonistic.
`build/test-results/<run>/summary.json`, `Acheron.log`, and `tools.jsonl` contain
raw responses, voice paths, INFO events, actions and cleanup evidence. Temporary
candidate code is excluded from committed production behavior. No FSM transitions
changed; master/generated views remain synchronized.
