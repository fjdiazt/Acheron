#pragma once

namespace Acheron::Pacification
{
    bool EnsureDialogue();
    bool Begin(RE::Actor* actor, int seconds, bool rescued = false);
    void RequestBegin(RE::Actor* actor, int seconds);
    void RequestKneel(RE::Actor* actor, bool bind = false);
    void RequestResume(RE::Actor* actor);
    void End(RE::FormID actorId, bool reset = false);
    void RequestEnd(RE::FormID actorId, bool reset = false);
    void RequestRelease(RE::Actor* actor);
#ifdef ACHERON_YIELD_TESTS
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
