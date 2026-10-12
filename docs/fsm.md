# NPC finite-state machine

Diagram: [fsm.json](fsm.json), renamed from `fms.json`. Documentation only;
event labels contain readable guards and actions describe effects. `planned`
metadata distinguishes proposals from current code.

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

`Rescued` is a status spanning AvoidingCombat and Wandering. Combat ending changes
phase, not pacification. Wander budget pauses during avoidance and command holds.
Kneeling and bound states use a separate 1800-real-second hold; Bind restarts it.
Current Kneeling/KneelingBound expiry returns to avoidance/wandering, or ends
ownership when no combat and no wander budget remain. Planned StandingBound and
FollowingBound expiry unbinds and starts fleeing. Automatic expiry waits for
dialogue to close.

## Yielding: Surrender command

| Source | Event / guard | Destination |
| --- | --- | --- |
| Yielding | Surrender, nearby combat active | AvoidingCombat |
| Yielding | Surrender, no nearby combat | Wandering |

This NPC command is **planned**; current native dialogue has Rescue and On your
knees., not Surrender. Rescue already reaches these movement states through its
healing path. Surrender is a separate command without potion consumption or added
healing: end defeat/bleedout protection, exit yielding and begin temporary peaceful
movement. Keep the NPC unbound and talkable; use the configured rescued wandering
budget (1-600 seconds, default 60), not a commanded 1800-second hold. Combat ending
then changes AvoidingCombat to Wandering through the existing edge.

A successful Surrender cancels the pending yield-expiry resolution/deadline;
do not apply or roll a delayed death/knockout result after leaving Yielding.
Preserve normal eligibility and essential protections. This supersedes the older
withdrawal of a stand-up-without-Rescue NPC action; player surrender stays disabled.
On your knees. remains a separate command into Kneeling.

## Binding destinations

| Source | Event | Destination |
| --- | --- | --- |
| Kneeling | Bind | KneelingBound (current) |
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

`On your knees.` is context-sensitive: Yielding, AvoidingCombat and Wandering enter
unbound Kneeling; StandingBound enters KneelingBound. The bound path must never
route through unbound Kneeling. `On your feet.` here applies only to KneelingBound,
not Surrender from Yielding into peaceful movement.

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
restart timers in Yielding, AvoidingCombat, Wandering, unbound Kneeling or
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
5. Route recorded outcome. Survivor flight versus ordinary AI is separate pending
   policy; JSON uses Normal/unmanaged as the provisional survival destination.

Manual Rescue/healing, Surrender or Kneel ends yielding and cancels pending expiry resolution.
Death removes the episode. A later defeat creates a new episode with its own
deadline and one permitted decision. Preserve existing essential-NPC protections;
zero-health guaranteed death applies to NPCs eligible to die. Protected-NPC
resolution remains to be specified before implementation.

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

One draw `r` from `[0, 1)` selects exactly one result:

```text
if r < D:         outcome = death
else if r < D+U:  outcome = unconscious
else:             outcome = survival
```

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
