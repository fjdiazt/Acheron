#pragma once
#include "Acheron/PacificationState.h"
#include "Acheron/TestState.h"

namespace Acheron::Pacification
{
    bool EnsureDialogue();
    bool OpenDialogue(RE::Actor* actor);
    bool Begin(RE::Actor* actor, int seconds, bool rescued = false, Peaceful::Phase entry = Peaceful::Phase::Wandering);
    void RequestBegin(RE::Actor* actor, int seconds);
    void RequestKneel(RE::Actor* actor, bool bind = false);
    void RequestSit(RE::Actor* actor);
    bool CanFlee(RE::Actor* actor);
    void RequestFlee(RE::Actor* actor);
    bool NeedsHealing(RE::Actor* actor);
    void RequestResume(RE::Actor* actor);
    void RequestTestState(RE::Actor* actor, Peaceful::TestState command);
    void End(RE::FormID actorId, bool reset = false);
    void RequestEnd(RE::FormID actorId, bool reset = false);
    void RequestRelease(RE::Actor* actor);
#ifdef ACHERON_YIELD_TESTS
    void ProbeCommandHold(RE::Actor* actor, float seconds);
    void ProbeFleeDuration(RE::Actor* actor, float seconds);
    void ProbeLegacyAggression(RE::Actor* actor);
    void Trace(RE::Actor* actor);
#endif
    bool IsActive(const RE::Actor* actor);
    bool IsEligible(const RE::Actor* actor);
    void Update(RE::Actor* actor, float delta);
    void ObserveHealing(RE::Actor* actor, float before);
    void Save(SKSE::SerializationInterface* stream);
    void Load(SKSE::SerializationInterface* stream, std::uint32_t version);
    void Reconcile();
    void Revert();
}
