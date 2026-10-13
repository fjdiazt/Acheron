# NPC finite-state machine

Diagram: [fsm.json](fsm.json), renamed from `fms.json`. Documentation only;
event labels contain readable guards and actions describe effects, not registered
runtime callbacks. JSON keeps states, edges, guards, actions and compact status/catalog
metadata. Explanations, timer policies and implementation gaps belong here. `planned`
metadata distinguishes proposals from current code; removing a note does not change
whether its behavior is implemented.
The FSM describes intended gameplay contracts at a high level. Existing edges can
have adapter implementation gaps; those are labeled separately below. Engine
callbacks, package installation and animation choreography do not need extra states.

### Per-state views

`fsm.json` remains the authoritative master. Generated `fsm-STATE.json` files show
one complete state and its outgoing transitions, with lightweight destination
placeholders instead of the whole diagram. Actions, guards, status and entry/exit
content of the focused state are preserved. Destination placeholders retain final
type/current-or-planned status, but their outgoing behavior is only in their own
view or master. These subsets are documentation views, not executable controllers.

From the repository root, regenerate after every master edit and check synchronization:

```powershell
python docs/split-fsm.py
python docs/split-fsm.py --check
```

Do not edit generated files directly. Regeneration adds new states, updates changed
views and removes obsolete generated views. The check command reports missing,
stale or obsolete views without writing files. Generator leaves master untouched.

Examples: [Yielding](fsm-Yielding.json), [Kneeling](fsm-Kneeling.json),
[Sitting](fsm-Sitting.json), [KneelingBound](fsm-KneelingBound.json).

Combat, Yielding, Normal and Dead describe engine/defeat behavior. The implemented
owned peaceful phases are AvoidingCombat, Wandering, Kneeling and KneelingBound;
their adapter is desktop-only. Sitting, StandingBound, FollowingBound and Resting are planned
owned phases. Planned Fleeing follows release or an automatic yield outcome and
retains temporary flight effects without prisoner
ownership. Normal means no peaceful-controller ownership; ordinary Skyrim AI resumes
as part of cleanup, without needing another event.

## States, events, guards, actions

| Element | Meaning | Example |
| --- | --- | --- |
| State | NPC condition between events | Yielding, KneelingBound, Dead |
| Event | Something happened | Hit, Death, yield timer expiry |
| Guard | Condition allowing an edge | Nearby combat active, recorded outcome is unconscious |
| Action | Work done while handling an event | Heal, select outcome, remove overrides |

`Observe` is periodic re-evaluation. Its guarded edges detect renewed defeat or
lost eligibility; the check itself is not another NPC state. No random rolls on
ordinary observation ticks.

`Rescued` is a peaceful status spanning AvoidingCombat, Wandering and planned
Resting; it does not imply healing. Combat ending changes phase, not pacification.
The shared peaceful budget counts during Wandering or planned Resting and pauses
during avoidance and command holds.
Kneeling, planned Sitting and bound states use a separate 1800-real-second hold.
Accepted Bind restarts it immediately; Kneeling -> KneelingBound exit and entry
consume the restarted hold. See the implemented-flow contracts below.
Current Kneeling/KneelingBound expiry returns to avoidance/wandering, or ends
ownership when no combat and no wander budget remain. Planned StandingBound and
FollowingBound expiry unbinds and starts fleeing. Automatic expiry waits for
dialogue to close.

Yielding -> Kneeling exits bleedout, then initializes the owned Kneeling state,
native kneeling marker and hold directly. No intermediate AvoidingCombat or
Wandering package. Existing peaceful -> Kneeling transitions also apply only
the target package. Kneeling -> KneelingBound retains the required furniture
exit before starting the bound pose.

Native `SitTarget` still approaches the kneeling marker's Behind entry point.
Direct phase initialization does not guarantee in-place animation entry.
The new motion regression remains failing: a level marker at the command-time
NPC position still produced about 80 units of travel before the pose settled.
The scoped instant-furniture flag probe failed and was removed. In-place entry
needs qualification before deployment; marker alignment changes remain candidates.

Desktop enemies hostile to the player before defeat or direct peaceful entry
receive personal relationship rank -3 (Enemy). Combat suppression remains separate.
Rank is deliberately retained after release/expiry; factions remain unchanged.
Player teammates, commanded actors and non-hostile civilians are excluded.
Native templated-actor save/load persistence and quest effects remain unqualified.

## Lifecycle and timer details

Death, renewed defeat, invalid state and lost eligibility remove peaceful ownership
before ordinary phase decisions. Release removes ownership even while paused. Fatal
damage/Death takes priority over timer refresh and movement commands. Cleanup removes
our overrides and preserves quest-owned AI; it does not undo the retained Enemy rank.

AvoidingCombat has no separate expiry. The peaceful budget freezes there and during
command holds, unloading and game pause. Loaded, unpaused Wandering and planned
Resting consume it, including Resting pose entry. Dialogue delays automatic exit,
not budget countdown. At no-combat routing with zero budget and closed dialogue,
end ownership instead of resolving a new surrender choice.

Current Kneeling/KneelingBound holds account for elapsed real time on observation;
expiry routing requires a loaded, unpaused actor and closed dialogue. Bind and Resume
preserve the frozen wander budget. Refresh changes that budget without restarting
the hold. Current held phases ignore Kneel: repeating it neither resets the hold
nor unbinds KneelingBound. Planned bound posture commands and unbound Sitting/Kneeling
posture switches are explicit exceptions.

## Implemented-flow contracts

These contracts concern existing states and transitions. The adapter enforces them;
source/build evidence and desktop qualification remain separate from VR qualification.

| Concern | Intended contract | Current implementation |
| --- | --- | --- |
| Command guards | Revalidate living, eligible actor and ownership; phase changes require loading and unpaused execution. Read actual dialogue state for zero-budget/expiry routing. | Shared live facts cover Observe, Refresh and Resume; Kneel/Bind and Test also check pause/loading. Refresh may update the budget while paused, without changing phase or invalidating pending package callbacks. |
| Bind timer | Restart the shared 1800-real-second hold on accepted Bind; preserve peaceful budget. Exit/entry animation consumes that new hold; completion never restarts it. | Bind restarts before requesting native exit. Real elapsed time consumes the hold during exit and entry; completion retains its remainder. |
| Held-pose exit | Finish native pose exit before nonurgent movement/binding destination packages. Death, renewed defeat, ownership loss and explicit Release prioritize cleanup. Exit failure must have bounded safe cleanup. | Resume, Bind, Test, automatic hold expiry and Refresh wait for native normal posture before destination packages. Automatic exits recheck combat/dialogue/budget after exit. Existing 15-second loaded/unpaused setup deadline cleans up failed held exits. |
| Setup failure | If no safe pose/package fallback remains for a living, non-defeated managed actor, remove our temporary ownership and return to Normal. | Implemented through `End`; now drawn as Setup failure. A blessing entry can first fall back once to regular kneeling. Death/renewed-defeat cleanup retains its own destination. |

Source: [command adapters](../src/Acheron/Pacification.cpp),
[pure decision rules](../src/Acheron/PacificationState.h). The diagram models the
behavioral destination and ordering; pending animation work stays transition data,
not a new lasting FSM state. Diagnostics can shorten an owned hold through
`ProbeCommandHold`; production duration remains 1800 real seconds. Desktop checks
cover paused commands, acceptance-time Bind and dialogue-delayed automatic expiry.
Desktop regression `6e36fee3-eae6-4d81-b3b6-252cfb6de161` passed with native animation
logs and package ordering; matching candidate retained on desktop.
Unloaded command races and forced exit-timeout cleanup still need runtime qualification.

### Other planned effects on current edges

Additional **planned effects** on otherwise current edges remain proposals:

- Rescue/healing, Yielding -> Kneeling and Yielding's Death cleanup cancel pending
  yield-expiry resolution once that resolver exists.
- Explicit Kneel, planned Sit or Bind from peaceful movement supersedes automatic resting:
  set `peacefulChoice` to wander and clear `selectedPose`.
- AvoidingCombat's current no-combat/Refresh destination is Wandering. Planned
  choice guards route surrendered resting episodes to Resting instead; Refresh
  updates the budget while preserving the recorded choice.

The bound-damage implementation needs runtime checks for visible pose/following
retention, ordinary damage, hold restart to 1800 seconds, unchanged wander budget,
near-expiry hits and eligible lethal-hit death. Unbound states receive no hit-driven
timer restart. Externally forced renewed defeat retains its Observe cleanup edge;
ordinary bound hits must not create that renewed defeat once the planned policy exists.

## Yielding: Surrender command

| Source | Event / guard | Destination |
| --- | --- | --- |
| Yielding | Surrender, nearby combat active | AvoidingCombat |
| Yielding | Surrender, no nearby combat, recorded choice = wander | Wandering |
| Yielding | Surrender, no nearby combat, recorded choice = rest | Resting |
| AvoidingCombat | Nearby combat ends, surrendered, recorded choice = rest | Resting |
| AvoidingCombat | Nearby combat ends, recorded choice = wander or not surrendered | Wandering |

This NPC command is **planned**; current native dialogue has Rescue and On your
knees., not Surrender. Rescue already reaches these movement states through its
healing path. Surrender is a separate command without potion consumption or added
healing: end defeat/bleedout protection, exit yielding and begin temporary peaceful
movement. Keep the NPC unbound and talkable; use the configured rescued wandering
budget (1-600 seconds, default 60), not a commanded 1800-second hold. Once no combat
remains nearby, select resting or standing wandering as described below. Rescue
retains its existing Wandering destination.

A successful Surrender cancels the pending yield-expiry resolution/deadline;
do not apply or roll a delayed death/knockout result after leaving Yielding.
Preserve normal eligibility and essential protections. This supersedes the older
withdrawal of a stand-up-without-Rescue NPC action; player surrender stays disabled.
On your knees. remains a separate command into Kneeling.

## Surrender: random resting or standing wandering

This behavior is **planned**. Record Surrender as the peaceful episode's origin.
At the first eligible no-combat routing, choose once between `Resting` and
`Wandering`. If Surrender occurs during combat, stay in AvoidingCombat and defer
the choice until combat ends. Set `pRest` in `(0, 1)` so both outcomes are possible;
the exact percentage remains undecided. One draw `r` in `[0, 1)` selects:

```text
r < pRest  -> rest
r >= pRest -> wander
```

Persist `peacefulChoice` before routing. Event guards read that recorded value;
they do not each draw randomness. Ordinary Observe ticks, Refresh, combat
interruptions and save/load reuse the recorded choice. A valid Refresh that first
exits AvoidingCombat after combat ends must use the same resolver, not force a
resting NPC into Wandering. Rescue episodes default to wandering and never enter
this lottery. This choice is separate from yield-expiry death/knockout resolution.

`Resting` is unbound, stationary, pacified and talkable. On first entry, randomly
select one compatible, verified **entry -> idle/loop -> exit** pose family and
store `selectedPose` as state data. Sitting/kneeling clips are actions/data, not
separate FSM states. Keep that family through combat interruption and save/load;
do not restart or reroll the pose every tick. Re-entry may replay the selected
entry, while a saved actor already settled in its loop must not restart it blindly.

The [Resting variants catalog](animations-bookmarks.md#resting-variants) covers
**any compatible bookmarked sitting family**, including cross-legged sitting and
compatible variants within Take a Seat 3 or other bookmarked groups/folders.
Previously agreed unbound kneeling/crouched families remain candidates. Resting
uses this broader pool; commanded Kneeling has its three-family catalog below.
Verify events/forms, matching entry/idle/exit and actor compatibility before a
candidate enters the enabled pool. Bound kneeling, sleeping and unrelated poses
are outside this unbound resting pool. No eligible family or a
failed/timed-out pose entry falls back to standing Wandering, preserving the
remaining budget and recording that fallback; do not retry/reroll every tick.

On nearby combat starting, exit the chosen pose and enter AvoidingCombat; retain
choice/pose and freeze the peaceful budget. When combat ends, resume Resting or
Wandering using the saved choice. The shared budget counts in loaded, unpaused
Resting as in Wandering; dialogue defers expiry, not countdown. Expiry exits the
pose and restores Normal AI. No extra 1800-second hold or hit-driven timer reset.

On your knees. from Resting exits the automatic pose and enters commanded,
unbound Kneeling with its existing 1800-second hold; that explicit command
supersedes the automatic resting choice. Bind then remains available from Kneeling.
Release, death, renewed defeat and eligibility loss cancel pose callbacks and
clear our rest data/overrides. Late callbacks must never restart a released/dead
NPC's pose. A new surrender episode gets a new permitted choice.

## Commanded Kneeling: three random variants

Keep one `Kneeling` state. Desktop chooses regular kneeling or
blessing uniformly on each new entry and saves `selectedKneelingVariant` as data.
Child sit/kneel remains a candidate, excluded until adult compatibility qualifies.
The clip triples belong to the
[Commanded Kneeling variants catalog](animations-bookmarks.md#commanded-kneeling-variants),
not three extra states or random guards on every update.

Choose uniformly among the verified actor-compatible variants on each new
commanded Kneeling entry; with all three available, each has a 1/3 chance. Play
that family's enter, then idle/loop; use its matching exit when leaving, including
before Bind. Observations, Refresh and save/load preserve the selection. Existing
commands ignored while already in the held phase must not trigger another draw.
Keep the existing 1800-second commanded hold and frozen peaceful budget.

Bound KneelingBound uses its own bound pose, including StandingBound's Kneel path;
it never draws from this unbound pool. Automatic Resting keeps its separate pose
policy. Native regular/blessing furniture keywords select matching enter/loop/exit;
desktop female Forsworn playback qualified in run `186bdc37-d88e-46cf-a7c1-37150419d1f1`.
Interruptions and broader actor compatibility remain unverified;
the child-family filename alone does not prove suitability for adult enemies.
No suitable variant or failed entry uses the existing native kneeling fallback,
without repeated random retries or timer resets. A blessing entry timeout exits
its interaction first, then attempts regular kneeling once with the existing
hold budget. Cosave version 3 saves the selection; versions 1/2 default to regular.
This does not fix the native furniture approach/walking detour.
The desktop probe also saved/loaded non-default blessing without rerolling,
checked matching exits before Resume/Bind, both Resume destinations, unchanged
health/pacification and Bind's hold restart. Forced timeout fallback and old-cosave
migration remain runtime-unverified. Version-2 binaries do not read version-3
peaceful records; rollback needs a matching older development save.

### On your feet.

Unbound Kneeling exposes **On your feet.** in native dialogue. It invokes the
existing `Resume` event: finish the selected family's native exit, then enter
AvoidingCombat if nearby combat exists, otherwise Wandering. Preserve health,
pacification and the frozen peaceful budget; clear the command hold without
restarting it. A zero peaceful budget follows normal expiry rules.
The unbound command is hidden from KneelingBound; its planned bound posture
command below remains separate.

## Binding destinations

| Source | Event | Destination |
| --- | --- | --- |
| Kneeling | Bind | KneelingBound (current) |
| Sitting | Bind | KneelingBound (planned) |
| Wandering | Bind | StandingBound (planned) |
| AvoidingCombat | Bind | StandingBound (planned) |

Standing binding applies to eligible owned rescued enemies. Keep standing, pacified
and talkable without healing. The planned standing dialogue topic is **You're my
prisoner now.**; JSON uses `Bind` for the event. Civilian eligibility remains open.

`StandingBound` shares KneelingBound's 1800-real-second hold and frozen wander
budget. Nearby combat does not pause or reset the hold. Standing animation/form
selection remains pending. Its latest agreed expiry destination is Fleeing below,
replacing the earlier avoidance/wandering proposal for this planned phase.
Current code has no StandingBound phase and accepts Bind only from Kneeling.

## Commanded Sitting

**Agreed, implementation planned.** Add an owned, unbound `Sitting` phase. The
dialogue label is **On the ground.**; logical event is `Sit`. Use a sitting pose,
not prone lying. This is an explicit command with a hold, separate from automatic
Surrender `Resting` and its random choice/pose policy.

| Source | Command / event | Destination |
| --- | --- | --- |
| Yielding, AvoidingCombat, Wandering, Resting | On the ground. / Sit | Sitting |
| Kneeling | On the ground. / Sit | Sitting |
| Sitting | On your knees. / Kneel | Kneeling |
| Sitting | On your feet. / Resume | AvoidingCombat or Wandering, subject to normal budget cleanup |
| Sitting | Bind | KneelingBound |

Use the same actor eligibility as commanded Kneeling. Yielding -> Sitting ends
defeat/bleedout protection without healing, cancels pending yield resolution and
enters sitting directly; no intermediate avoidance/wandering package. From Resting
or a retained automatic-rest episode, exit its pose and clear the automatic choice:
set `peacefulChoice` to wander and clear `selectedPose`.

Sitting remains stationary, pacified and talkable. Initialize the separate
1800-real-second commanded hold on accepted entry, preserving the peaceful budget.
Kneeling -> Sitting and Sitting -> Kneeling are new posture entries: start the
destination's 1800-second hold on acceptance, not again on animation completion.
Repeating Sit while already Sitting or Kneel while already Kneeling remains ignored;
it must not refresh the hold. Combat does not pause the hold; Refresh changes only
the peaceful budget. No hit-driven timer reset applies to this unbound state.

On your feet. finishes sitting exit, clears the hold and resumes nearby-combat
avoidance or wandering, preserving health and the peaceful budget. Hold expiry uses
the same loaded/unpaused/dialogue and zero-budget routing as Kneeling. Death,
renewed defeat, invalidity, loss of eligibility and Release use existing cleanup;
persist the sitting phase, selected pose and remaining hold across save/load.

**Bind from Sitting ends in KneelingBound, not SittingBound.** Exit sitting, enter
the required kneeling interaction, then apply the native bound-kneeling pose.
Treat that choreography as transition actions, not an intermediate owned Kneeling
phase. Retain pacification, restart the bound hold at 1800 seconds on accepted Bind,
and preserve the peaceful budget. Death/release/expiry/ownership loss invalidates
pending pose callbacks; completion must not restart the timer or rebind a released
actor. Qualify ordered playback and failure/timeout handling before implementation.
The existing Kneeling -> KneelingBound furniture-exit sequence remains unchanged.

Use a verified actor-compatible sitting enter -> idle/loop -> exit family from the
[bookmarks](animations-bookmarks.md#resting-variants). Exact seating family, native
form/event mappings and failure fallback remain unqualified; this agreement adds
no new random sitting-selection weights. No Sit command from bound states is added.
Current code has no Sitting phase, Sit event or On the ground. dialogue topic.

## Bound posture commands

| Source | Command / event | Destination | Animation order |
| --- | --- | --- | --- |
| KneelingBound | On your feet. / Stand | StandingBound | Kneeling exit/stand-up, then standing bound entry and idle |
| StandingBound | On your knees. / Kneel | KneelingBound | Kneeling entry, then kneeling bound entry and idle |

These posture commands are **planned**. Binding and pacification remain owned
throughout the sequence; neither command heals or recruits the NPC. Restart the
hold at **1800 real seconds** when either posture command is accepted; preserve
the frozen wander budget. The new hold keeps counting during animation; completion
does not reset it again. Existing nonfatal-hit reset remains applicable.

`On your knees.` is context-sensitive: Yielding, AvoidingCombat, Wandering, Resting and Sitting enter
unbound Kneeling; StandingBound enters KneelingBound. The bound path must never
route through unbound Kneeling. The planned bound **On your feet.** retains binding
and enters StandingBound. The implemented unbound command above resumes peaceful
movement; neither is Surrender from Yielding.

Treat stand-up/kneeling-entry clips as ordered transition actions; destination
states describe the settled bound posture. Wait for posture-animation completion
before starting the destination bound entry/idle. Keep only a pending animation
sequence/token, not a new lasting state for each clip. Death, release, hold expiry
or ownership loss cancels the sequence; late animation callbacks must not rebind
or apply a stale pose. Failure/timeout must cancel safely rather than wait forever.
Actual clips, completion events and failure timeout remain to be qualified.
Current Kneel ignores held phases; code needs explicit bound posture handling.

## Bound following, staying and release

| Source | Event | Destination | Effect |
| --- | --- | --- | --- |
| StandingBound | Follow | FollowingBound | Follow player while bound and pacified |
| FollowingBound | Stay | StandingBound | Stop following; remain standing and bound |
| StandingBound / FollowingBound / KneelingBound | Let go | Fleeing | Remove binding and prisoner controls; flee |
| StandingBound / FollowingBound | Hold Timer Expires | Fleeing | Automatically unbind and flee |
| Fleeing | Flee ends | Normal | Remove temporary flee AI/effects; ordinary Skyrim AI resumes |

These commands and Fleeing are **planned**. FollowingBound means persistent bound
following behavior, not follower recruitment. Use temporary follow AI targeting
the player; do not change follower factions, follower count or recruitment state.
StandingBound uses a stationary standing pose; FollowingBound needs movement that
retains visible binding. Animation selection remains pending.

**Forgotten-NPC safeguard:** Follow and Stay preserve the same remaining
1800-real-second hold; neither creates a new timer or restarts it. This applies
while following as well as waiting. Bound posture commands and nonfatal bound
hits restart the hold at 1800 real seconds. Combat does not pause it. Preserve remaining time across
save/load and account for paused elapsed time when processing resumes. Expiry
tracking must not depend on the NPC being loaded: record release when due even
while unloaded; defer physical pose cleanup/flee movement until loaded. Re-entry
processes pending release before any bound/Stay pose. Time with the game closed
does not count. Automatic expiry waits for dialogue to close, as existing holds do.

Let go acts immediately. Fleeing is unbound and has no prisoner hold, Stay or
Follow order. Retain only temporary flee AI/pacification until flight ends; then
remove those overrides. Flight must finish at a safe-distance condition or finite
timeout; exact distance/duration remain open. Preserve quest-owned AI when our
overrides end. Internal Release/Resume from planned standing/following binding
use the same unbind-and-flee destination; current KneelingBound cleanup APIs
remain separately documented in JSON. Death cancels following, waiting and flight.
The automatic yield-expiry flee outcome below uses the same finite Fleeing state,
without creating binding or a prisoner hold.

## Bound NPC damage

Agreed behavior from `KneelingBound`, `StandingBound` and `FollowingBound`:

- Hits apply ordinary damage. While post-damage health remains above zero, retain
  binding, pacification and held pose. Restart `CommandHoldDurationSeconds` at
  1800 real seconds on each nonfatal hit. Preserve the frozen wander budget.
- A hit must not return the bound NPC to Yielding, unbind it, or trigger a knockout
  or yield-expiry probability roll.
- At post-damage health zero or below, allow eligible engine death instead of
  intercepting the hit as another defeat. Enter Dead on Skyrim's Death notification;
  then remove binding/peaceful overrides. Preserve essential-NPC protections.

Hit-driven timer restart applies **only to bound states**, including FollowingBound. It does not
restart timers in Yielding, AvoidingCombat, Wandering, unbound Kneeling, Sitting or
Unconscious. A fatal hit takes priority over hold refresh; it must not extend a
dead NPC's timer. A hit near expiry while binding remains owned restarts the hold.

Use actual post-damage actor health for this hit rule. The meaningful injury-health
snapshot and probabilistic resolution below belong to yield expiry, not bound hits.

This damage policy is **planned**. Current `IsDamageImmune` tests defeat ownership,
not peaceful binding, so binding itself does not confer defeat damage immunity.
However, damage hooks can still register a new defeat, and `DefeatActor` removes
peaceful ownership. No bound-specific bypass currently prevents that diversion.
Hit-triggered hold restart is also unimplemented: current peaceful events have no
Hit event, and ordinary `Refresh` changes wander budget rather than the hold.
State/pose retention and correct timer restart under hits need runtime checks.
The existing renewed-defeat Observe edge remains a lifecycle fallback for externally
forced defeat; ordinary hits must not use it once this policy is implemented.

## Yield expiry: one decision

Agreed trigger: **yield timer ending**, once per yield episode. Current code still
calls `RescueActor(actor, true)` at recovery expiry. Probabilistic resolution and
knockout below are planned replacements, not implemented behavior. Current and
planned expiry paths in JSON are alternatives, never concurrent handlers.

1. Confirm same living, eligible yielded NPC and a due, unresolved deadline.
2. Snapshot meaningful injury health, including healing received while yielding.
   Use stored injury health, not Acheron's artificial defeated-health clamp `0.05`.
3. Compute exclusive probabilities; draw one random value; record chosen outcome.
4. Persist result before applying its effects. Repeated updates or save/load resume
   the recorded result; they cannot reroll this episode.
5. Route the recorded death, unconscious, fight, flee or peaceful outcome below.

Manual Rescue/healing, Surrender, Kneel or planned Sit ends yielding and cancels
pending expiry resolution.
Death removes the episode. A later defeat creates a new episode with its own
deadline and one permitted decision. Preserve existing essential-NPC protections;
zero-health guaranteed death applies to NPCs eligible to die. Protected-NPC
resolution remains to be specified before implementation.

## Unattended yield: survivor behavior

This **planned** policy applies when the NPC remains Yielding until its deadline;
commands that already ended yielding cancel the resolution. Preserve the agreed
death/unconscious probabilities. Split the remaining living, conscious probability
among three mutually exclusive behaviors:

| Recorded outcome | Destination | Behavior |
| --- | --- | --- |
| fight | Normal, then Combat if vanilla AI engages | End defeat/pacification and return control to ordinary Skyrim AI |
| flee | Fleeing | End defeat and use temporary finite flight without healing |
| peaceful, nearby combat active | AvoidingCombat | Begin unbound pacification with the configured peaceful budget |
| peaceful, no nearby combat | Wandering | Begin unbound pacification with the configured peaceful budget |

The stat is Skyrim's **Confidence** actor value: Cowardly, Cautious, Average, Brave,
Foolhardy. Our earlier design already names it; the current Acheron recovery path
does not implement Confidence-weighted outcomes. For the same meaningful health,
higher Confidence increases the chance of selecting fight. Preserve the earlier
injury constraint: critical injury can suppress fighting despite high Confidence.

**Agreed baseline weights**, conditional on living, conscious survival:

| Confidence value | Vanilla classification | Fight | Flee | Peaceful (Avoid/Wander) |
| --- | --- | --- | --- | --- |
| 0 | Cowardly | 5% | 15% | 80% |
| 1 | Cautious | 15% | 65% | 20% |
| 2 | Average | 40% | 45% | 15% |
| 3 | Brave | 70% | 25% | 5% |
| 4 | Foolhardy | 90% | 10% | 0% |

Classifications/values are vanilla; percentages are our custom policy. Lowest
Confidence mostly accepts defeat, low Confidence mostly escapes, and high Confidence
mostly returns to vanilla AI. Verify the native classification in
[ACTOR_CONFIDENCE](../lib/CommonLibSSE-NG/include/RE/T/TESAIForm.h).

Apply the agreed injury adjustment separately: critical injury lowers fight weight
and redistributes the removed weight between flee and peaceful in their existing
ratio. Let baseline fractions be `b`, `f`, `p`; an injury factor `m(h)` in `[0, 1]`
gives:

```text
qFight = m(h) * b
removed = b - qFight
qFlee = f + removed * f / (f + p)
qPeaceful = p + removed * p / (f + p)
```

All agreed rows have `f + p > 0`. The same injury factor at equal meaningful health
keeps fight chance increasing with Confidence; full suppression makes all fight
weights zero. The exact injury-factor curve and critical-health cutoff remain
undecided. This adjustment changes only survivor behavior, not death/unconscious
probabilities. Ally healing below bypasses the weights and injury adjustment.

Let `S = 1 - D - U` retain its meaning as living, conscious survival. Define
conditional behavior weights `qFight`, `qFlee`, `qPeaceful`:

```text
qFight + qFlee + qPeaceful = 1
B = S * qFight
F = S * qFlee
P = S * qPeaceful
D + U + B + F + P = 1
```

All weights/probabilities lie in `[0, 1]`. Sample one value at expiry using cumulative
thresholds for death, unconscious, fight, flee, peaceful; persist the final outcome
before effects. No second behavior timer, independent roll or repeated retries.
Save/load reuses the result. Confidence and meaningful health are inputs to that
one decision, not separate transition guards that roll again.

Both peaceful destinations set the existing 1-600-second budget (default 60).
Record automatic-recovery origin and standing-wander choice; this is not Surrender
and does not enter its random Resting pool. AvoidingCombat later routes to Wandering
when combat ends. No healing, binding or commanded hold is added.

The fight route restores vanilla AI rather than forcing a target. A living NPC
only enters Combat if ordinary AI selects a valid hostile target; with combat over
it may resume its normal routine. The Normal -> Combat edge represents that engine
behavior, not another owned peaceful phase.

## Ally healing while Yielding

**Agreed bypass; implementation planned and not validated in-game.** Feasible from
source/API inspection. Native
health-effect hooks already compare actual health before/after applying an allowed
restoration effect. `RE::ActiveEffect` exposes its caster via `GetCasterActor()` and
`caster`; see [CommonLib API](https://po3.commonlib.dev/class_r_e_1_1_active_effect.html).
Actor APIs expose faction reaction and hostility, allowing an allied NPC caster to
be distinguished from the player, self-healing and a merely neutral actor.

Current eligible desktop healing calls `Pacification::ObserveHealing`, which does
not retain caster identity and routes all such healing into peaceful movement.
It cannot currently apply the requested allied-healer exception. The planned branch
must carry caster/episode identity from the same health effect, require positive
restored health and a distinct confirmed allied NPC caster, then end defeat and
pacification through the ordinary-AI recovery path. Positive ally/friend reaction
and no hostility provide ally evidence; non-hostility alone is insufficient.

Accepted ally healing immediately cancels the pending yield deadline/outcome and
returns to Normal/vanilla AI, without rolling Confidence or mortality, adding extra
healing, or beginning peaceful movement. It also bypasses the survivor injury
adjustment. Death/ended ownership and stale queued
callbacks take priority. This applies only while Yielding; healing cannot undo an
accepted Kneel/Bind/Surrender command through a delayed callback.

The current broad Rescue/healing edges and planned Ally healing edge are alternate
handlers for qualifying allied healing. Classify the source before dispatch and
consume the recovery once; do not run both handlers. Player Rescue and non-ally
healing retain their existing peaceful routing.

Validation still needed: an allied NPC's targeted and concentration healing really
restores health on a yielded enemy; that NPC stands up, loses defeat/protection and
peaceful overrides, and naturally resumes combat when a valid enemy remains.
Compare player Rescue, non-ally healing, self-healing, excluded/failed effects,
essential NPCs and healing at the expiry boundary. Existing healing fixtures use
player-cast spells/potions; they do not prove allied NPC behavior. NPCs autonomously
choosing to heal a defeated ally is a separate AI/spell-availability question; this
policy responds to healing received and does not order allies to cast it.

## Exclusive probabilities

Let `h` be meaningful injury health divided by maximum health, clamped to `[0, 1]`.
Define final probabilities `D(h)` for death, `U(h)` for unconsciousness, and `S(h)`
for other survival:

```text
0 <= D(h), U(h), S(h) <= 1
D(h) + U(h) + S(h) = 1
S(h) = 1 - D(h) - U(h)
```

Death chance increases as health falls; `D(0) = 1`. Near zero, death chance exceeds
unconscious chance. Therefore `U(0) = S(0) = 0`: final unconscious probability
cannot increase all the way to zero health. It may rise, peak, then fall as death
takes probability away. Exact nonlinear curves and crossover remain undecided.

Equivalent parameterization lets knockout chance **among survivors** keep rising:

```text
D = deathChance(h)
K = knockoutChanceGivenSurvival(h)
U = (1 - D) * K
S = (1 - D) * (1 - K)
```

`K` is conditional, not overall knockout probability. The discussed example of
50% overall unconscious probability at 10% health means `U(0.10) = 0.50`; it
requires `D(0.10) <= 0.50`. If using conditional curves, choose
`K(0.10) = 0.50 / (1 - D(0.10))`. This does not set the remaining curve anchors.

The mortality partition for one draw `r` from `[0, 1)` remains:

```text
if r < D:         outcome = death
else if r < D+U:  outcome = unconscious
else:             outcome = survival
```

For the complete unattended-yield decision, subdivide that survival interval into
the saved fight/flee/peaceful outcomes above using the same draw. `B`, `F` and `P`
are conditional-survival weights multiplied by `S`; they do not take probability
from death/unconsciousness or change `D(0) = 1`.

No independent death/knockout rolls, repeated tick rolls, or extra resolution timer.
Older mortality anchors in [yield.md](../yield.md) are earlier proposals; this
document records the latest exclusive-outcome policy without adopting those
anchors or selecting curve constants.

## Death notification and cleanup

Death outcome requests eligible engine death. NPC enters Dead only when Skyrim
reports `Death` (`TESDeathEvent`). Cleanup removes ownership and overrides;
cleanup itself does not kill or revive the NPC. Same Death event label applies
from Combat, Yielding, and all peaceful phases.

JSON shows expiry decision and pending death request as Yielding self edges;
no extra long-lived state is needed merely to calculate a result. Outcome guards
read the persisted result, never perform another roll.

Unconscious recovery and later wound-mortality timing remain separate planned
policy. They must not re-run the same yield-expiry lottery. Existing planned
hit-triggered knockout is separate from this health-based expiry roll; its attack
eligibility remains undecided.

Code references: [peaceful decisions](../src/Acheron/PacificationState.h),
[peaceful adapter](../src/Acheron/Pacification.cpp),
[damage/recovery hooks](../src/Acheron/Hooks/Hooks.cpp),
[death notification](../src/Acheron/EventSink.cpp).

## Deterministic Test dialogue

Desktop managed NPCs expose native `Test` dialogue while Yielding, AvoidingCombat,
Wandering, Kneeling or KneelingBound. Its linked choices select Normal, Combat,
Yielding, Avoiding combat, Wandering, Kneel (Regular), Kneel (Blessing), Kneeling bound
or Dead (kill NPC). These are development commands, not ordinary gameplay transitions.
Unmanaged Normal/Combat actors and corpses do not acquire a global Test dialogue.

Commands bypass gameplay transition restrictions, retain eligibility/lifecycle guards,
and finish held furniture exits before changing markers/packages. Exact kneeling
families never roll randomness or silently substitute another family. Placement/entry
failure is logged; normal gameplay retains its existing random selection/fallback.
Child sit/kneel and other planned states remain excluded.

Owned destinations use normal pacification, talkability, rescued movement markers and
packages. Avoidance/wandering refresh the configured peaceful budget; command holds
preserve it and restart the shared 1800-real-second timer. Health is untouched by
peaceful commands. Yielding uses existing defeat behavior; Normal/Combat/Dead release
ownership, with Combat calling StartCombat(player) and Dead calling native Kill(player).
These engine destinations retain Skyrim's own rules; Dead is an actual lethal command.
Regular observation resumes after entry: without nearby combat AvoidingCombat becomes
Wandering, and renewed nearby combat sends Wandering back to AvoidingCombat.
