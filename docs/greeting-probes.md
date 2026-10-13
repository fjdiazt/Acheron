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
another policy option; follow-up probe evidence below. Keep relationship
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

## Silent opening and captions: follow-up

Probe records live only in `tests/fixtures/silent-greeting`; they are not production
`res` records. Private normal Player branch 0x84C registers custom topic 0x84A and
INFO 0x84B. Response is one ASCII space, NoLipFile/CanMoveWhileGreeting flags,
no shared response, sound or script. Topic is not TopLevel/Blocking or a global
Hello topic. Existing scoped native entry temporarily calls
`SetDialogueWithPlayer(true, true, privateInfo)`; original guards remain intact.
No voice mapping, audio replacement, global muting or subtitle hiding.

Normal-caption control `cc6e81ca-8e8a-4e5a-a077-a3c6371a0115` passed: native
Good morning. appeared in the visible dialogue caption and actor-owned subtitle
queue. Subtitle settings enabled in memory; original INI files restored.

Initial candidates `4fdfd21f-31c0-495f-9489-bd0607249208`,
`dff1e171-8f09-4f3b-9068-c0cbc7a4a6cc`, and
`31145eb2-8618-4ac2-9b37-c52cced8e84b` failed before playback. Compiled TIFC
was one, but unlinked custom topic had zero runtime children; INFO lookup failed.
Adding normal branch registration produced a runtime INFO. Those failures do not
establish that the engine rejects empty-string responses.

`77b1684e-c84f-4194-b462-60527d7b8bf8`: silent INFO selected; spoken/caption text
blank and actor subtitle queue empty. Strict pose check failed because blessing
kneeling temporarily unseated on repeated Talk, also observed in earlier ordinary
greeting probes. Failure retained; no pose assertion relaxed.

Regular-family control `fbab0141-56e7-40a8-8092-65f329ea20ae` passed eight rank-0
openings: blank spoken text, no visible caption content, empty actor subtitle queue,
native sit state 3, preserved rank/health/aggression/pacification. Actual native
On your feet., Bind and bound Continue. INFO selections passed. Regular pose was
selected through the existing native Test submenu; this does not qualify blessing.

Expanded repeat `faaa7bfd-2ef2-43b7-8b68-561b3ea49fdc` passed the same eight
silent rank-0 openings and command controls. Unmanaged civilian retained native
Hello INFO `000A8643` and its nonempty HUD caption; no scoped adapter acceptance
logged for that actor. Vanilla can say a greeting without opening choice UI.
Earlier `98e1ab84-b806-4a9a-a74c-d8e63b5b53fd` had incorrectly required that
window; its log already contained the ordinary civilian caption. Corrected control
requires actual unmanaged speech event and actor-owned caption, retaining failure
evidence rather than calling it a gameplay regression.

Actual E control `b834e984-79d8-46b3-9f96-903610cef1d4` passed four choices
across Yielding/Wandering at original Aggression 2, including unmanaged hostile
and merely pacified actor rejection. Snapshots/events select the private blank
INFO. This qualifies E input in those sources; seated E aiming remains separate.

All game candidates restored; installed qualified baseline hashes and original
staging ESM verified. Source returned to ordinary native entry and rebuilt. Only
diagnostic caption/speech capture, candidate-only checks and fixture records remain
in Git. No silent opening or relationship policy is deployed permanently.

Probe commands, requiring the temporary private-record/native-entry candidate:

```powershell
python tests/Test-SilentGreetingRecord.py build/silent-greeting-probe/Acheron.esm
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test silent-greeting-probe
```

Merge fixture files into a disposable copy of `res`, deserialize with existing
Spriggit, and use the restoring candidate wrapper. Production staging/source are
restored afterward. Silent mode verifies text/actual caption fields and rank 0;
ordinary greeting mode remains observational. Replies and goodbyes remain native.
Other managed voices, blessing pose, VR and third-party speech hooks need separate
qualification before promotion. No FSM behavior change is retained by this probe.
