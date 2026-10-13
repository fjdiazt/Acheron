Scriptname Acheron Hidden

; Desktop testing preset; modifies the current character permanently when saved.
Function ApplyGodPreset() global native

; True means queued; IsPeacefulState confirms the acquired state.
bool Function BeginPeacefulState(Actor akActor, int aiDurationSeconds) native global
; Queued commands; no health restoration. Resume returns to avoidance/wandering.
bool Function KneelActor(Actor akActor) native global
bool Function BindActor(Actor akActor) native global
bool Function ResumePeacefulState(Actor akActor) native global
bool Function IsPeacefulState(Actor akActor) native global
; Selects native healing rescue; legacy fallback remains for VR/followers.
bool Function SupportsPeacefulRescue(Actor akActor) native global
; Test build only; logs the controller's current state without changing it.
Function ProbePeacefulState(Actor akActor) native global
; Test build only; scoped native entry, true means queued. Does not change aggression.
bool Function ProbeNativeDialogue(Actor akActor) native global
; Test build only; emulate pre-bypass owned suppression on a disposable managed actor.
Function ProbeLegacyDialogueAggression(Actor akActor) native global
; Test build only; shorten an owned command hold without changing its phase.
Function ProbeCommandHold(Actor akActor, float afSeconds) native global
{ Global API for Acheron }

; Disable/Enable hit processing
Function DisableProcessing(bool abDisable) native global
bool Function IsProcessingDisabled() native global
; Disable/Enable consequence events
Function DisableConsequence(bool abDisable) native global
bool Function IsConsequenceDisabled() native global
; If teleport events are currently permitted as by Acherons config data
bool Function IsTeleportAllowed() native global

; ================================ Defeat
; A defeated actor is bleeding out and immune to damage
; A defeated actor is always pacified
; A pacified actor is ignoring & ignored by combat
; All defeated actors carry the "AcheronDefeated" keyword
; All pacified actors carry the "AcheronPacified" keyword
Function DefeatActor(Actor akActor) native global
Function RescueActor(Actor akActor, bool abRelease = true) native global
Function PacifyActor(Actor akActor) native global
Function ReleaseActor(Actor akActor) native global
; Diagnostic builds only; disposable actors and markers.
Function ProbePeacefulLinks(Actor akActor, ObjectReference akAnchor, ObjectReference akThreat) native global
bool Function IsDefeated(Actor akActor) native global
bool Function IsPacified(Actor akActor) native global

; get all currently defeated actors
Actor[] Function GetDefeated(bool abLoadedOnly = false) native global
Actor[] Function GetPacified(bool abLoadedOnly = false) native global

; Invoked whenever an actor is defeated
Function RegisterForActorDefeated(Form akForm) native global
Function UnregisterForActorDefeated(Form akForm) native global
Function RegisterForActorDefeated_Alias(ReferenceAlias akAlias) native global
Function UnregisterForActorDefeated_Alias(ReferenceAlias akAlias) native global
Function RegisterForActorDefeated_MgEff(ActiveMagicEffect akEffect) native global
Function UnregisterForActorDefeated_MgEff(ActiveMagicEffect akEffect) native global
Event OnActorDefeated(Actor akVictim)
EndEvent

; Invoked whenever an actor is rescued (recovering from defeat)
Function RegisterForActorRescued(Form akForm) native global
Function UnregisterForActorRescued(Form akForm) native global
Function RegisterForActorRescued_Alias(ReferenceAlias akAlias) native global
Function UnregisterForActorRescued_Alias(ReferenceAlias akAlias) native global
Function RegisterForActorRescued_MgEff(ActiveMagicEffect akEffect) native global
Function UnregisterForActorRescued_MgEff(ActiveMagicEffect akEffect) native global
Event OnActorRescued(Actor akVictim)
EndEvent

; Invoked when a death event is started (these only fire for the player) global native
Function RegisterForPlayerDeathEvent(Form akForm) native global
Function UnregisterForPlayerDeathEvent(Form akForm) native global
Function RegisterForPlayerDeathEvent_Alias(ReferenceAlias akAlias) native global
Function UnregisterForPlayerDeathEvent_Alias(ReferenceAlias akAlias) native global
Function RegisterForPlayerDeathEvent_MgEff(ActiveMagicEffect akEffect) native global
Function UnregisterForPlayerDeathEvent_MgEff(ActiveMagicEffect akEffect) native global
Event OnPlayerDeathEvent()
EndEvent

; ================================ ObjectReference
; Link source to target with the given keyword. Setting 'target' to 'none' unsets the Link
Function SetLinkedRef(ObjectReference akSource, ObjectReference akTarget, Keyword akLink = none) native global
; Similar to ObjectRef.RemoveAll but will always skip quest items & can be set to ignore worn armor
Function RemoveAllItems(ObjectReference akTransferFrom, ObjectReference akTransferTo = none, bool abExcludeWorn = true) native global
; Get a list of all items in the given reference container which have any of the specified keywords AND a value of at least aiMinValue
Form[] Function GetItemsByKeywords(ObjectReference akContainer, Keyword[] akKeywords, int aiMinValue = 0, bool abIgnoreQuestItems = true) native global

; ================================ Actor
; return all armor this actor is currently wearing, excluding those covered by ignored slot masks
Armor[] Function GetWornArmor(Actor akActor, int aiIgnoredMasks = 0) native global
; strip all of this actors worn armor, excluding those covered by ignored slot masks or using a "nostrip" keyword
Armor[] Function StripActor(Actor akActor, int aiIgnoredFlags = 0) global native
; Get the most efficien Potion (= the Potion which gets the Hp closest to max) for this actor from the given container
; The function recognizes all Healing Potions in the container inventory which are purely beneficial
Potion Function GetMostEfficientPotion(Actor akActor, ObjectReference akContainer) native global
; Return all of the Players currently loaded followers
Actor[] Function GetFollowers() native global
; Get the race type of the given Actor. Race Types are used to bundle difference of Races together, 
; Example: Snow, Brown and Cave bears are race type 'Bear', Dogs and Wolves both are race type 'Wolf'
String Function GetRaceType(Actor akActor) native global

; ================================ Utility
; Write a message to the game console
Function PrintConsole(String asMsg) global native
; Similar to SKSE's custom Menu but will not pause the game while open. menuName: 'AcheronCustomMenu'
; Filepath relative to the Interface folder, without extension
bool Function OpenCustomMenu(String asFilePath) native global
; Close the custom menu if its currently open
Function CloseCustomMenu() native global
