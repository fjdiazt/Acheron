# NPC yielding requirements

Requirements gathered on 2026-10-10 for the Acheron fork at
`C:\src\gaming\skyrim-acheron-mod`.

## Gameplay

Fight enemies until they yield instead of immediately dying. Downed NPCs use
Acheron's existing bleedout/crawling state. Followers should focus on remaining
active enemies. Player may approach a downed NPC and choose an action, finish
them with ordinary attacks, or leave their fate to automatic resolution.
Automatic outcomes avoid having to process every defeated enemy individually.

Use Acheron as the baseline. Target Skyrim VR with the current Mad God Overhaul
profile, PLANCK, and Nether's Follower Framework. Prefer existing Acheron and
Skyrim mechanisms; keep interactions simple.

## NPC-only scope

- Disable player defeat, player pacification, surrender, and player consequence
  quests. Player uses God mode; player defeat features are unnecessary.
- Retain NPC and follower defeat/protection. Preserve essential NPC restrictions.
- Keep player-only MCM controls hidden. Saved settings or API calls must not
  re-enable player defeat.

### Who can cause yielding

- Player and follower defeating attacks yield eligible enemies instead of killing
  them. Unrelated NPC-versus-NPC fights remain normally lethal.
- Use existing settings: `bNPCDefeat=false`, `bHunterPrideFollower=true`,
  `bFollowerDefeat=true`, and `fLethalNPC=100`. No additional protection controls.
- Enable Hunter Pride automatically on new game/load when processing is enabled
  and general NPC defeat is disabled. Its existing manual toggle remains usable;
  turning it off also disables player/party Hunter Pride defeat.
- Ordinary NPCs, including guards, may kill standing enemies. Once the player or
  party downs an enemy, existing Acheron protection applies to every non-player.
- Follower victims retain their separate defeat protection. Commanded attackers
  retain upstream party attribution for causing defeat; they are not direct
  player sources for finishing attacks.
- The planned health-based entry ramp must respect this same eligibility policy.

## Health-based entry into yielding

Add an MCM **Yield Health Threshold**, default **20%**, configurable to values
such as 20%, 25%, or 50%. Evaluate predicted remaining health **after an incoming
damaging hit**, before Acheron intercepts damage or substitutes its defeated
health value.

Let `h` be predicted remaining health as a percentage of maximum health and `T`
the configured threshold:

| Predicted health | Health-based yield chance |
| --- | --- |
| Above `T` | 0% |
| At `T` | 50% |
| Between zero and `T` | `100 - 50 * h / T` percent |
| Zero or below | 100% |

For the default `T = 20`, chances are 50% at 20% health, 75% at 10%, 87.5% at
5%, and 100% at zero. Changing `T` rescales the same linear ramp; it does not
change the 50% and 100% endpoints.

- Make one probability check per damaging hit, not repeated idle/frame checks.
- Failed check: apply ordinary damage. Successful check: enter yielding and
  retain the predicted injury health for later outcomes.
- Support player attacks reaching this nonlethal entry path; Hunter Pride's
  existing lethal-only path must not prevent it.
- This entry probability is separate from the later chance of dying from wounds.

## Damage to already yielded NPCs

Player can finish an eligible downed NPC through ordinary attacks, without a
special finishing mechanic or mandatory menu execution. Allowed damage must not
put an already downed target through defeat again.

Reuse Acheron's existing defeat pacification and damage immunity for protection
from followers and other NPCs. No additional targeting suppression, protection
system, or follower/NPC damage-block MCM checkboxes are required. This supersedes
the earlier two-checkbox requirement, per the user's decision on 2026-10-11.

Desktop discovery confirmed that both a Lydia teammate copy and a normal
Whiterun Guard stopped attacking after the bandit was defeated/pacified. The
user also confirmed this visually. See [test evidence](test-plan.md#pacification-discovery-normal-guard-versus-bandit).
Both scenarios are now routine harness regressions: `follower-pacification`
and `npc-pacification`, requiring verified attack cessation to pass.
Keep the existing damage guards; these observations do not establish safety
against every collateral/in-flight damage source or VR integration.

The direct-player finishing exception uses existing
physical and magic hooks, without re-defeating the target. Preserve normal
combat, non-player protection and essential NPC restrictions. Use the actual
attacker/caster; a player's summoned actor is not a direct player attack.
Keep protection and pacification until native death cleanup clears the target's
defeated/pacified flags. A nonfatal player hit must not rescue or expose the NPC
to other attackers. Essentials remain immune; protected actors keep Skyrim's
ordinary player-only killing rule.

## Native dialogue in VR

Desktop implementation also uses standard dialogue for defeated actors.
Retire the original Hunter Pride menu, activation override, SWFs, menu option
APIs and selection events. Keep Hunter Pride attack eligibility and the existing
Rescue/Plunder/Execute/Drain action logic independent of UI. Enable native
bleedout dialogue only while defeated; restore prior flags on recovery/reset.
Defeated Rescue, planned Surrender and On your knees. must be selected through real dialogue in
regression tests, never solely by calling their action functions.

Approach a downed NPC and use the normal **Talk/Activate** control. Open standard
Skyrim dialogue choices for the Hunter Pride actions. No custom Scaleform menu,
radial menu, or extra interaction hotkey. Ordinary NPC dialogue must keep working;
rescued NPCs must remain talkable during their temporary peaceful state.

Yielded-target menu choices are conditional on the target:

| Target category | Rescue | Get out of here. |
| --- | --- | --- |
| Civilian/noncombatant | Available when potion requirements are met | Hidden |
| Enemy/aggressive NPC | Available when potion requirements are met | Available |

Rescue is available to both groups; **Get out of here.** is restricted to
enemy/aggressive NPCs. This supersedes the earlier civilian-only Rescue restriction.
Keep relevant hostility information from before defeat/pacification; a yielded
enemy must not become classified as a civilian merely because Acheron pacified
them. Exact classification for ambiguous actors remains to be defined.

### Rescue

- While rescued and managed in **AvoidingCombat** or **Wandering**, use wounded
  walk/run/sprint animations regardless of current health. Scope this override to
  the rescued actor, not every NPC avoiding combat. Clear it with the peaceful
  owner on expiry, release, death, or renewed defeat. Health remains unchanged by
  animation selection; the ordinary injury pack keeps its separate health rule.
- Offer to both civilians/noncombatants and enemy/aggressive NPCs.
- Apply a temporary **Rescued** status to the individual NPC to govern the
  peaceful wandering and local combat-avoidance behavior below. This is a gameplay state;
  its implementation may reuse a suitable effect, keyword, or AI mechanism.
- Consume the most effective available healing potion, following Acheron's
  existing selection behavior; healing must match the potion's actual effect.
- End the downed state and remove downed damage protection.
- Both groups stand up, become/remain nonhostile, avoid combat, and move a short
  distance clear of active fighting.
- During combat, stay clear of fighting locally. When combat ends, wander around
  nearby peacefully and remain available for conversation rather than run far away.
- Combat ending does not restore ordinary hostile behavior or end the Rescued
  status. Until its effect expires, do not initiate combat with the player,
  civilians, or other actors. A rescued bandit must not immediately attack civilians.
- Reuse the specific vanilla combat-avoidance behavior seen in noncombatant
  escorted NPCs: move around locally to stay clear of fighting, remain close
  enough for interaction when combat ends. This is a behavioral reference, not
  a requirement to turn rescued NPCs into followers. Identify the existing
  vanilla AI/package setup that produces it before choosing an implementation.
- Expose one configurable MCM **Peaceful Wander Duration** (`iPeacefulWanderDuration`),
  replacing the provisional Rescue Effect Duration label. Default **60 seconds**,
  range **1–600**, step **1**; zero rejected. Same setting for enemies and civilians,
  separate from yield minimum/maximum timers.
- Countdown starts after nearby combat ends, using loaded, unpaused gameplay
  time. New nearby combat pauses it; wandering resumes the remaining time afterward.
  Unloading pauses it, and save/load preserves remaining time. Reapplying Rescue
  refreshes the existing state rather than stacking another timer. Defer expiry
  while the NPC is in player dialogue.
- Use a small explicit FSM with one per-NPC owner, named guards, centralized
  transitions/cleanup, and independently testable decisions. Implement avoidance
  and wandering first; add other states and conditions with their features.
- When the temporary effect expires, release its pacification/movement overrides
  and restore normal AI. Restore ordinary behavior at effect expiry, not merely
  because combat ended. Former enemies may become hostile again.
- Prefer that existing vanilla AI behavior plus suitable Acheron mechanisms.
  Earlier fear/pacify suggestions are secondary; a fear effect that sends them
  far away does not satisfy Rescue. Avoid permanent faction/relationship changes.

### Get out of here.

- Use **Get out of here.** as the second dialogue option, in the slot formerly
  used by Plunder. This replaces the provisional Flee action label.
- Offer only to enemy/aggressive NPCs. Eligible targets stand up and flee far
  from the encounter temporarily. Never offer this action to civilians, to avoid
  sending quest/escort NPCs away.
- This differs from Rescue, which keeps the target nearby and talkable.
- Suitable existing fear/pacify effects or Acheron mechanisms may be reused.
- Effect expiry restores normal AI without permanent relationship/faction changes.
- Do not assume this command consumes a potion or heals the target; those rules
  are open.

### Surrender

- Planned native-dialogue command while the NPC is Yielding. End yielding and
  defeat/bleedout protection without consuming a potion or adding healing.
- Enter AvoidingCombat while combat remains nearby. At the first no-combat
  routing, choose once between automatic Resting and standing Wandering. Both
  have a nonzero chance; exact resting percentage remains undecided. Store the
  choice and reuse it after combat interruptions and save/load. Rescue keeps its
  existing wandering route; this selection applies to surrendered enemies.
- Remain unbound, pacified and talkable; use the configured rescued peaceful
  budget (1-600 seconds, default 60), counting during Resting or Wandering and
  paused during combat avoidance. No automatic binding or 1800-second hold.
- Resting randomly selects any verified compatible bookmarked sitting family,
  including compatible sitting variants in bookmarked groups/folders. Previously
  agreed unbound kneeling/crouched families remain candidates. Use matched
  entry/idle/exit from the [Resting variants catalog](docs/animations-bookmarks.md#resting-variants).
  Store the chosen family; do not reroll on ticks, combat interruption or load.
  Pose exit precedes combat avoidance or commands. Missing/failed playback falls
  back to Wandering without resetting the peaceful budget. Exact playback mapping
  and compatibility remain unverified; bound kneeling is outside this unbound pool.
- Successful Surrender cancels the pending yield-expiry deadline/outcome;
  leaving Yielding must not allow a delayed expiry death/knockout roll.
- Rescue remains the healing/potion command. On your knees. remains separate.
  This restores Surrender as a distinct NPC action, superseding its earlier removal
  and the withdrawn stand-up-without-Rescue proposal. Player surrender stays disabled.
  Existing actor eligibility and essential protections remain applicable.

### On your knees.

- Use **On your knees.** to enter our own `Kneeling` FSM state from Yielding,
  AvoidingCombat, Wandering, Sitting or SittingWounded, and planned Resting, without healing. From Resting,
  exit the automatic pose first; explicit Kneel supersedes its saved automatic
  choice. This replaces the earlier kneeling
  action's provisional Bind label; Surrender is now separate. Earlier
  handcuff/tie-up wording is superseded.
- Use a kneeling idle animation with hands unbound; this action does not bind or
  execute the NPC. Entry randomly selects blessing, regular kneeling or
  child sit/kneel from the [three-family catalog](docs/animations-bookmarks.md#commanded-kneeling-variants).
  Choose uniformly among verified compatible families; all three eligible means
  1/3 each. Store selected variant; play matching enter -> idle/loop -> exit.
  Preserve selection on ticks, Refresh and save/load; choose again only on a new
  commanded Kneeling entry. Child-family adult compatibility has desktop male/female
  coverage; VR remains unverified. Missing/failed variants use native
  kneeling fallback without random retries or timer reset. Bound kneeling and
  automatic Resting retain their separate animation policies.
- While kneeling, remain talkable with the applicable conversation options,
  including **Get out of here.** where eligible and **Bind**.
  Kneeling must not itself change civilian/enemy action restrictions.
- Unbound Kneeling also exposes **On your feet.**: finish the selected pose's
  exit, then resume AvoidingCombat if nearby combat exists, otherwise Wandering.
  Preserve health, pacification and frozen peaceful budget; clear the command
  hold without restarting it. Bound posture commands remain separate.
- Choosing **Bind** while kneeling transitions to our `KneelingBound` state,
  using the native hands-bound kneeling pose. This replaces the earlier prisoner
  command wording for this kneeling transition.
  Shared transition phase policy skips kneeling exit and bound entry,
  directly selecting bound held idle without standing or re-kneeling. Native
  marker/package ownership remains intact. Bind still restarts
  the 1800-real-second hold on acceptance, unlike healing's preserved hold.
- Planned **On your knees.** from StandingBound instead enters KneelingBound:
  play kneeling entry, then bound-kneeling entry/idle. Retain binding and
  pacification; restart the hold at 1800 real seconds when the command is accepted
  and preserve frozen wander budget. Do not route through unbound Kneeling.
- Exact menu position and civilian/enemy eligibility remain open. This NPC action
  is separate from the disabled player surrender feature.
- **Commanded Hold Duration** is a separate constant,
  `CommandHoldDurationSeconds = 1800`: 30 real minutes. Combat does not pause or
  reset it. **Bind restarts it at 1800 real seconds.** Kneeling, KneelingBound and
  planned StandingBound/FollowingBound share this duration.
  Expose through MCM later.
- Freeze the existing peaceful wandering budget while kneeling. Hold expiry or
  explicit resume returns to AvoidingCombat if combat remains nearby, otherwise
  Wandering. Explicit release removes our ownership and restores normal AI.
  Defer automatic exit while dialogue is open. Paused/unloaded time catches up
  when processing resumes; time with the game closed does not count.
- Native `KneelingMarker` and `SitTarget` hold the unbound pose. Pacification
  remains active; yield entry removes bleedout protection without healing.
  Automatic wound outcomes and future binding interactions remain separate work.
- Reference is **Combat Surrender SSE**, whose features include making yielded
  actors kneel for execution. Reuse the kneeling behavior alone; this command must
  not kill the actor. Speechcraft and Yielding is a different reference.

### On the ground. / Sitting

- Desktop command enters owned, unbound `Sitting` at positive meaningful injury
  health or `SittingWounded` at zero, from Yielding, AvoidingCombat, Wandering,
  Kneeling, and planned Resting. Use tracked injury health including healing, not the
  artificial defeated-health clamp `0.05`. Same eligibility, pacification, dialogue and
  1800-real-second hold as commanded Kneeling; peaceful budget stays frozen.
- Kneeling -> Sitting and Sitting -> Kneeling start the destination hold on command
  acceptance. Repeating the command in the same posture does not reset it. No healing
  or unbound-hit timer refresh. Both sitting states are separate from Surrender's automatic Resting.
- Show **Heal** only in `SittingWounded` while injury health is zero. Failed or
  cancelled healing leaves its pose/timers intact. Any actual healing above zero
  automatically enters `Sitting`, retaining remaining hold, peaceful budget,
  pacification and dialogue. Hide Heal afterward; do not force full health.
- Use shared per-transition animation phase policy, not a Heal-specific bypass:
  play applicable source exit/destination enter by default, or skip either through
  transition data. Healing sets both to skip and directly swaps the held wounded
  idle to normal sitting idle; no stand-up or sit-down transition. Ordinary cleanup,
  stale-callback and death guards remain. Native compatibility has desktop regression
  coverage; visual quality needs user testing. No seamless interpolation assumed.
- Sit adds no healing and must retain untreated injury context and wound/death
  risk, transferring any pending wound deadline instead of curing through posture.
  Wound scheduling remains open; no new mortality curve or timer is specified.
- **On your feet.** resumes avoidance/wandering after sitting exit, preserving health
  and peaceful budget, clearing the hold. Zero-budget/dialogue expiry rules stay the
  same as Kneeling. **On your knees.** changes either sitting state to unbound Kneeling.
- **Bind from Sitting or SittingWounded -> KneelingBound**: exit sitting, enter kneeling interaction,
  then bound pose. No SittingBound state or intermediate owned Kneeling phase. Bind
  restarts the 1800-second hold on acceptance; animation completion does not reset it.
- Preserve selected sitting state/pose/hold and injury context through save/load; existing death, release,
  renewed-defeat and eligibility cleanup cancels stale pose callbacks. Exact sitting
  visual continuity and VR remain unqualified. Mortality scheduling remains planned. See
  [commanded Sitting policy](docs/fsm.md#commanded-sitting).

### On your feet.

- Planned command for KneelingBound: play kneeling exit/stand-up first, wait for
  completion, then start standing-bound entry/idle and settle in StandingBound.
- Remain bound, pacified and talkable throughout. Neither heal nor recruit.
  Restart the hold at 1800 real seconds when the command is accepted; preserve
  frozen wander budget. The hold counts during the sequence; animation completion
  does not reset it again. Nonfatal bound hits still restart it.
- Death, Let go, expiry or ownership loss cancels pending choreography. Reject
  stale callbacks; failure/timeout must not leave an endless animation wait.
  Actual clips/events and completion/failure handling need qualification.
- This applies only to already-bound kneeling NPCs. Yielding NPCs instead use
  Surrender for no-heal peaceful movement, or Rescue for healing.

### Bind

- Current **Bind** topic appears only in an owned, unbound Kneeling NPC's native
  dialogue. Planned standing binding uses **You're my prisoner now.** below;
  both commands map to the FSM's Bind event.
- Transition to `KneelingBound`, reusing Skyrim's `IdleBoundKneesEnterInstant` event via
  our SitTarget package and owned `AcheronPeacefulBoundMarker` (`000822`). It
  enters working KneelingMarker geometry before triggering the native bound-pose
  graph event. Native BoundCaptiveMarker (`000A19DF`) did not enter under SitTarget
  in desktop tests; direct clip logs distinguish pose entry from an assigned target.
- Remain alive, pacified, stationary and talkable; neither heal nor execute.
- Bound NPCs take ordinary hit damage. Nonfatal hits retain binding and restart
  Commanded Hold Duration at 1800 real seconds; preserve frozen wander budget.
  This hit-driven restart applies only to bound states, including planned
  StandingBound and FollowingBound.
  No renewed yielding or knockout roll. At zero health, allow eligible
  engine death and clean up on Death notification. Preserve essential protections.
  This bound-hit policy remains planned; see [FSM rules](docs/fsm.md).
- Restart Commanded Hold Duration at 1800 real seconds. Preserve the separate
  wandering budget. Combat does not pause or reset the hold countdown.
- Hold expiry/resume returns to avoidance or wandering; explicit release removes
  ownership and exits the pose. Do not offer Bind again or silently unbind through
  On your knees. while already bound. Planned **Let go** unbinds and sends the NPC
  fleeing; current cleanup APIs remain separate. Standing binding remains planned.

### Rescued-enemy dialogue

- Rescued enemies remain available through normal Talk/Activate, with a different
  conversation set from the yielded-state menu.
- First option: **On your knees.** Reuse the kneeling behavior already specified
  for yielded NPCs; the actor remains alive.
- Additional standing option: **You're my prisoner now.** Replaces the provisional Bind
  label. From owned Wandering or AvoidingCombat enemies, Bind enters planned
  `StandingBound` using a standing bound animation without healing. While already
  kneeling, use **Bind** to enter KneelingBound as specified above.
- Bound posture options: **On your feet.** from KneelingBound enters StandingBound;
  **On your knees.** from StandingBound enters KneelingBound. Both retain binding
  and restart the hold at 1800 real seconds, using the ordered animation sequences
  specified above.
- Keep other applicable conversation options available while kneeling, including
  **Get out of here.** for eligible enemies; posing alone does not end dialogue.
- Reuse the existing standing/kneeling bound animations described by the user,
  subject to identifying their actual forms/events and checking VR behavior.
- StandingBound shares KneelingBound's 1800-real-second Commanded Hold Duration.
  Binding starts the hold; each nonfatal hit restarts it at 1800. Freeze the
  separate wandering budget; nearby combat does not pause or reset the hold.
  Fatal hits follow eligible engine death, with cleanup on Death notification.
- **Follow** from StandingBound enters planned FollowingBound, following the
  player while bound and pacified without follower recruitment. **Stay** from
  FollowingBound returns to StandingBound. Both preserve the remaining hold;
  neither restarts it. Nonfatal bound hits still restart the hold.
- **Let go** from a bound state removes binding and prisoner controls and enters
  Fleeing. StandingBound/FollowingBound hold expiry also unbinds and starts fleeing,
  replacing their earlier avoidance/wandering expiry proposal. Defer automatic
  exit while dialogue is open. Preserve remaining hold across save/load; account
  for paused elapsed time when processing resumes. Record due release even for
  unloaded NPCs; defer physical cleanup/flee movement until loaded. Process pending
  release before reapplying a waiting/bound pose. Game-closed time does not count.
- Fleeing retains only temporary flee AI/pacification, with a safe-distance or
  finite-time end condition, then releases to ordinary Skyrim AI. No prisoner
  timer or follow/stay order survives release. Preserve quest-owned AI on cleanup.
- Exact standing/following bound animations, flee distance/time limit and whether duration is configurable
  remain open. Civilian eligibility
  for this additional conversation set has not been specified.
- Yielding NPCs use the separate Surrender command for no-heal peaceful movement;
  On your feet. applies to KneelingBound.

### Other actions

- **Knockout\*:** add a native-dialogue option for a yielded NPC immediately before
  Execute if Execute is retained. Selecting it forces the living unconscious
  state without relying on automatic knockout selection or a finishing attack.
  Keep the option if Execute is removed; it shares the same knockout-state
  feasibility review, wound-survival rules, and identification behavior below.
- **Execute\*:** optional explicit menu execution, preserving essential NPC
  restrictions if retained. Review reported execution bugs and actual VR behavior
  during implementation; reports are not yet confirmed defects in this fork.
  May remove this action entirely because normal player finishing attacks remain
  required. No special execution animation or extra VR mechanic is mandated.
- **Drain:** retain the eligible vampire-feeding action and its restrictions.
- **Plunder\*:** retain existing inventory/looting behavior. Vanilla assault/crime
  reactions are acceptable. Do not add a custom alarm or witness subsystem.
  Final menu position remains open because the new command takes its original slot.

\* Plunder alarm review: the existing Acheron handler explicitly calls
`OpenInventory(true)` and then `SendAssaultAlarm()`. Both are native Skyrim Actor
functions, confirmed in the installed `SKSE Scripts/Scripts/Source/Actor.psc`;
there is no custom alarm subsystem in this handler. The deliberate call is
Acheron's policy, rather than evidence that opening inventory alone triggers an
assault. Flag any additional framework-specific alarm complexity for possible
omission. Check interaction with pacified targets before deciding whether to
retain or omit the explicit alarm during implementation; native Skyrim behavior
is provisionally acceptable. No removal agreed yet.

## Yield duration and automatic outcomes

Expose two MCM duration sliders: **minimum 15 seconds**, **maximum 90 seconds** by
default. The existing NPC recovery timer becomes the maximum. Choose one random
duration between the configured limits for each defeat; preserve its deadline
across save/load. No separate resolution timer or percentage-variance slider.

NPCs crawl until their own deadline unless the player intervenes or an agreed
recovery rule applies. Different NPCs resolve at different times; they do not all
wait for the maximum. Effect durations for Rescue and **Get out of here.** are
separate from yield time.

At resolution:

1. Evaluate death from wounds using meaningful injury health plus subsequent
   healing. A would-be fatal hit means death unless treatment saves the actor.
2. For living, conscious survivors, combine current meaningful health with Skyrim's
   **Confidence** actor value to choose return to vanilla AI/fighting, finite fleeing,
   or temporary AvoidingCombat/Wandering. Higher Confidence increases fight chance
   at the same injury health, using the agreed FSM weights.
3. Critical injury overrides bravery: a confident enemy at 1% health should flee
   unless they have healed enough to fight. Actors returning to combat may yield
   again on later hits.

Confidence levels available for this decision are Cowardly, Cautious, Average,
Brave, and Foolhardy. Agreed fight/flee/peaceful percentages are respectively
`5/15/80`, `15/65/20`, `40/45/15`, `70/25/5`, `90/10/0`. Critical injury lowers
fight weight and redistributes it between flee and peaceful in their existing
ratio; the exact injury-factor curve/cutoff remains open.

The latest [FSM survivor policy](docs/fsm.md#unattended-yield-survivor-behavior)
preserves the death/unconscious lottery and subdivides conscious survival into
fight/flee/peaceful outcomes using one persisted draw. Peaceful automatic recovery
uses the existing budget and standing wandering, not Surrender's random Resting pool.
The agreed [allied NPC healing bypass](docs/fsm.md#ally-healing-while-yielding) is
feasible from source/API inspection: actual received healing from a confirmed allied
NPC cancels yield resolution and restores vanilla AI immediately, bypassing mortality,
Confidence weights and survivor injury adjustment. Current desktop
healing instead enters peaceful movement regardless of caster. Caster-aware routing,
actual allied spell delivery and natural combat resumption need in-game validation;
autonomous ally healing AI is a separate requirement.

### Knockout\* (optional)

- Add unconscious knockout as another possible automatic outcome after enemies
  spend time crawling/yielding, alongside dying from wounds, fleeing, or returning
  to combat. Actor should lie unconscious but alive, not merely stagger briefly.
- Add an MCM toggle for nonlethal finishing: an eligible follow-up player attack
  that would otherwise reduce an already yielded enemy to zero health knocks them
  unconscious instead of killing them. Toggle off retains normal lethal finishing.
- Attack eligibility needs clarification: the spoken request may mean unarmed
  punches; do not assume all weapon attacks or all damage qualify.
- Mark this requirement with an asterisk, pending implementation feasibility and
  VR review. Inspect how the VR-supporting
  [Knockout - Health and Stealth-Based KOs](https://www.nexusmods.com/skyrimspecialedition/mods/133432)
  produces its living unconscious state; exact implementation is not yet verified.
- Automatic knockout selection/chance, priority versus wound death, recovery
  duration/behavior, toggle default, and effects of further attacks remain open.
  Also provide the explicit Knockout dialogue option above. This supersedes the
  earlier note that no knockout menu action was requested. Preserve essential
  protections. Exact civilian/enemy eligibility for this action remains open.
- Knocked-out enemies can die from wounds or survive using the same meaningful
  health, healing, mortality ramp, and related percentage settings as yielded
  enemies. Knockout is not guaranteed survival. Do not introduce a separate
  knockout mortality curve. Evaluation timing and handling of the transition from
  yielding to knockout remain open; avoid repeated per-frame mortality checks.

### Knockout identification\* (if feasible)

- When pointing at an unconscious enemy, distinguish them from a dead enemy
  through the normal Skyrim/VR targeting or activation label.
- Prefer a **Knocked out** label beside the displayed name. A simple asterisk
  beside the name is acceptable if that is the smallest practical solution.
- Reuse native/VR UI mechanisms; no custom menu or separate inspection workflow
  is required. Mark feasibility with an asterisk pending implementation review.
- Indicator follows the actual state: show only while alive and knocked out;
  remove when they recover or die. Preserve the original actor name and avoid
  changing other instances of the same NPC base.

### Knockout sounds (feasibility note)

- Check whether living knocked-out NPCs can emit sounds while unconscious.
- If feasible, trigger existing Skyrim hurt/pain or moaning/groaning sounds as
  an audible indication of knockout. Reuse suitable existing NPC sounds rather
  than require new recordings.
- Sounds must stop when the actor wakes or dies. Sound selection, frequency,
  unconscious-state playback, and VR behavior remain to be investigated.

### Wound survival probability

Use one shared continuous health-dependent probability for both yielded and
knocked-out enemies, with these previously discussed anchors:

| Meaningful health | Survival chance |
| --- | --- |
| 0% or below | 0%, unless treatment overrides |
| 25% | 50% |

The proposed linear segment is `survivalChancePct = 2 * healthPercent` from 0%
through 25% health: 5% health gives 10% survival; 12.5% gives 25% survival.
The curve above 25% remains open. The latest 20% default yield-entry threshold
does not redefine this separate wound-survival anchor.
When extending mortality to knockout, the user recalled approximately 20% as the
low-health boundary; confirm the final mortality boundary/anchors before coding.
Do not silently substitute the yield-entry ramp for the wound-survival ramp.

Apply the health-derived probability once at resolution. Retain enough state
across save/load to prevent repeated outcome rolls. Manual Rescue should provide
a way to save a wounded NPC before resolution; its exact treatment override needs
definition.

## State and integration constraints

- Acheron forces defeated health to `0.05`; this is not the actor's injury severity.
  Capture meaningful health, expected incoming damage, and defeat cause before
  that substitution. Account for healing while yielded.
- Persist injury information, the chosen deadline, and necessary outcome state.
  Clean up state on death, manual action, or recovery.
- Reconcile Acheron's healing recovery, follower combat-end recovery, location
  reload recovery, and consequence handling with these deadlines and outcomes.
- Avoid lingering damage from the original defeat hit immediately killing the
  target when player finishing damage becomes available.
- Essential NPCs remain protected from execution and wound death.

## Remaining decisions

- MCM threshold range and whether zero means lethal-only entry or is disallowed.
- Whether the new health-entry rule replaces, supplements, or disables Trauma
  and Exposed conditions; whether it also governs follower victims.
- Survival curve above 25%; health/Confidence cutoffs for fleeing versus fighting.
- Exact treatment override for fatal wounds and how healing updates stored injury.
- Exact civilian versus enemy/aggressive classification, including followers,
  quest actors, and other ambiguous cases. Civilian automatic outcomes also need
  review so automatic fleeing does not bypass the menu's quest/escort concern.
- **Get out of here.** effect duration and
  whether it is configurable; movement distances and its healing/potion rules.
- Rescue wandering implementation and handling of existing quest/escort packages
  while the peaceful status is active.
- Final Plunder placement, explicit assault-alarm review, and precedence of
  the dismissal command and Plunder over automatic outcomes.
- Keep or remove Execute after reviewing reported bugs, duplication with normal
  player finishing attacks, and actual VR behavior.
- Optional Knockout feasibility and selection rules; nonlethal finishing attack
  type, toggle default, menu eligibility, unconscious recovery, and subsequent
  damage policy.
- Shared yielding/knockout mortality boundary (previous 25% anchor versus latest
  approximate 20% reference), evaluation timing, and transition/reroll policy.
- Native/VR knockout label feasibility and exact marker; actual knockout state
  must remain distinguishable from death when aiming at a target.
- Feasibility of existing Skyrim pain/groan playback while unconscious, including
  sound choice and frequency as an audible knockout indication.
- Kneeling command position, actor eligibility, animation, release,
  duration, damage protection, and automatic-outcome behavior.
- Rescued-enemy standing/following bound animations, bound posture entry/exit
  completion events and failure timeout, flee distance/time limit,
  configurability and civilian eligibility. Bound hold duration, hit restart,
  Follow/Stay preserving remaining time, unbind-and-flee expiry and frozen Rescue
  wandering budget are agreed; see [FSM rules](docs/fsm.md).
- Surrender resting percentage and verified unbound resting pose families,
  matching entry/loop/exit events, actor compatibility and playback failure timeout.
- Commanded Kneeling's three-family entry/idle/exit playback, adult compatibility
  of child sit/kneel, saved selection and native fallback qualification.
- Interaction of existing recovery/consequence paths with the chosen deadline.

## Acceptance checks

- Configured threshold rescales the yield ramp; health after damage determines
  the chance. Successful yielding records injury before the artificial clamp.
- Existing Acheron pacification/protection remains for non-player attackers,
  without new blocking controls. Player finishing attacks work for physical and
  magic paths; essential NPC restrictions remain.
- Normal VR Talk/Activate opens native dialogue. Rescue and **Get out of here.**
  behave differently as specified, then release their temporary AI effects.
- Civilian dialogue offers Rescue and hides the dismissal command; enemy/aggressive
  dialogue offers both. Defeat pacification does not erase target classification.
- MCM Peaceful Wander Duration controls rescued enemies' and civilians' temporary
  peaceful behavior independently of yielding timers; combat/unload pauses it,
  and save/load preserves remaining time.
- Rescued actors avoid active combat, then wander peacefully nearby after combat
  ends. They remain talkable and do not attack civilians during the status;
  ordinary AI returns only at effect expiry.
- Surrendered enemies may instead rest with a randomly selected sitting/kneeling
  family after combat ends, or remain standing and wander. Choices survive
  interruptions/load; shared peaceful budget counts during resting and wandering.
  No suitable pose or playback failure falls back to wandering without timer reset.
- Deadlines remain within configured min/max and survive save/load without rerolls.
- Wound outcomes account for healing; critically injured survivors flee despite
  high Confidence. Temporary behavior expires back to normal AI.
- If optional Knockout is retained, automatic knockout leaves enemies alive and
  unconscious. Nonlethal finishing follows the agreed attack filter and MCM toggle.
- Knockout dialogue on a yielded NPC forces the unconscious state. It appears
  before Execute if present, and remains available if Execute is omitted.
- Yielded and knocked-out enemies share the same health/healing-based mortality
  rule and related settings; unconscious enemies are not exempt from wound death.
- If Knockout identification is feasible, normal pointing/activation label
  distinguishes unconscious living enemies from corpses and updates on recovery
  or death without altering unrelated actors' names.
- **On your knees.** makes a yielded NPC kneel while remaining alive; verify
  animation and eventual release behavior in VR.
- Kneeling idle is unbound and keeps applicable dialogue available. Selecting
  **Bind** from it uses the kneeling bound pose; selecting the
  prisoner command while standing uses the standing bound pose.
- Rescued-enemy conversation offers **On your knees.** first and the separate
  **You're my prisoner now.** option. The prisoner state uses the appropriate
  standing/kneeling hands-bound pose and releases after its agreed finite duration; it must not
  leave the actor permanently bound.
- Verify follower targeting and these interactions in the active Mad God Overhaul
  profile with PLANCK/NFF. Static/build checks do not establish headset behavior.

## References

### Speechcraft and Yielding

- [Nexus description, FAQ, compatibility/troubleshooting, and changelog](https://www.nexusmods.com/skyrimspecialedition/mods/133442)
- [Downloads](https://www.nexusmods.com/skyrimspecialedition/mods/133442?tab=files)

Documentation comparison, reviewed 2026-10-10:

| Our requirement | Documented behavior |
| --- | --- |
| Enemies stop fighting | Flee for 30 seconds, then remain calmed for up to an hour |
| Followers switch targets | Ignore calmed enemies; FAQ admits possible kills during initial fleeing |
| Normal dialogue choices | Loot, dismiss, recruit; potion-based Rescue not documented |
| Health-based yield ramp | Vanilla surrender lines, generally below ~10% health; heavy hits can kill first |
| Confidence affects outcomes | Filters surrender eligibility rather than deciding recovery outcomes |
| Wound death and knockout | Our mortality ramp not documented; Knockout is separate |

Hidden Demoralize, followed by hidden Calm, drives movement and pacification.
Nearby-only Rescue movement is not established. Custom voices lacking surrender
lines may never trigger yielding. Dismissal can satisfy quest objectives without
killing. Extras include begging, robbery, brawls, recruitment, perk changes,
animal aggression/crime changes, and stolen-item fencing. Perk overhauls can
affect features; stolen-item stacking has a workaround-related caveat.

Assessment: useful reference for dialogue and temporary pacification; not a
documented replacement for reliable yielding, injury tracking, and automatic
outcomes. VR support documented; scripts and Mad God compatibility unchecked.

### Combat Surrender SSE

- [Nexus description](https://www.nexusmods.com/skyrimspecialedition/mods/16729)
- [Original Combat Surrender](https://www.nexusmods.com/skyrim/mods/79059/)

Features include making yielded actors kneel for execution, releasing them,
requesting loot, and making them fight each other. This is the reference for our
**On your knees.** command's kneeling behavior only; execution and the other features
are not implied requirements. The SSE page explicitly says its port is no longer
supported. Animation source, implementation, and VR compatibility remain unchecked.

### Acheron

- [Nexus documentation and changelog](https://www.nexusmods.com/skyrimspecialedition/mods/108159)
- [GitHub source](https://github.com/KrisV-777/Acheron)
- [Author's documentation wiki](https://krisv-777.github.io/Acheron/)
- [Reported bugs](https://www.nexusmods.com/skyrimspecialedition/mods/108159?tab=bugs)

Baseline implementation notes from the cloned source at upstream commit
`ade7d95`; the fork's NPC-only restrictions are described separately above:

- Intercepts would-be lethal damage and can substitute defeat. Optional Trauma
  and Exposed triggers also lead to defeat. Hunter Pride attack processing uses
  lethal conditions only, so our earlier health-based entry needs a new path.
- Defeated actors are pacified, enter bleedout/crawling, and receive damage
  immunity. Actual health is forced to `0.05`; original injury/cause must be
  captured before that value for our survival decisions.
- Existing physical and magic hooks provide places for attacker-specific damage
  permissions. Ordinary attacks on defeated targets are blocked upstream;
  explicit menu execution is separate. Immunity is not proof against every
  damage source: the source review identified a falling-damage limitation.
- Built-in Hunter Pride actions are Rescue, Plunder, Execute, and vampire feeding.
  Rescue uses a potion and releases defeat/pacification; it returns normal AI
  without the temporary peaceful/local movement behavior we want. Its fallback
  healing of 25 also needs reconciling with actual potion healing.
- Plunder explicitly opens inventory and calls Skyrim's native
  `SendAssaultAlarm()`. Keep the alarm review marked above. Execute uses an
  animation or direct kill; reported execution problems and VR suitability still
  require investigation.
- NPC timer defaults to 90 seconds. Existing MCM range reaches 600 seconds;
  followers can recover when combat ends, and healing/location recovery can
  resolve defeat earlier. These paths must be reconciled with our min/max timer.
- VR support is advertised, but this source skips custom Hunter Pride menu
  registration in VR. Native dialogue is our planned replacement.
- Injury-based mortality, confidence-based recovery outcomes, optional knockout,
  and its identification label are extensions to this baseline.

Useful local entry points: `src/Acheron/Hooks/Hooks.cpp`,
`src/Acheron/Defeat.cpp`, `src/main.cpp`, `src/Serialization/mcm.def`, and
`dist/Source/Scripts/AcheronHunterPride.psc`.

Bug reports guide investigation; their claimed causes are not confirmed here.
Source inspection does not establish Mad God, PLANCK/NFF, or headset behavior.

Issue tracking remains in Beads in the sibling `skyrim` repository:
`skyrim-ise`, `skyrim-8r9`, `skyrim-dre`, `skyrim-6a1`, `skyrim-yek`,
`skyrim-6cl`, `skyrim-tpm`, `skyrim-e6q`, and `skyrim-hvc`.

## Manual Test commands

Expose a native `Test` dialogue subtree in each talkable managed state. Every currently
implemented destination has its own command; each supported random kneeling family
has an explicit command. Apply full state effects/timers, bypass gameplay transition
restrictions, preserve lifecycle guards. Planned states/child animations stay excluded.
See docs/native-dialogue.md and docs/fsm.md for commands and timer semantics.
