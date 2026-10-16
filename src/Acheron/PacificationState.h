#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <optional>

namespace Acheron::Peaceful
{
    enum class Phase : std::uint8_t { AvoidingCombat = 1, Wandering = 2, Kneeling = 3, KneelingBound = 4, Sitting = 5, SittingWounded = 6, Fleeing = 7 };
    enum class EventKind { Observe, Refresh, Kneel, Bind, Resume, Release, Test, Sit, Healed, Flee };
    enum class KneelingVariant : std::uint8_t { Regular, Blessing, ChildSitKneel };
    inline constexpr float CommandHoldDurationSeconds = 1800.0f;
    inline constexpr float FleeDurationSeconds = 30.0f;
    inline constexpr float FleeDistance = 4096.0f;
    inline constexpr float MaxCommandHoldDurationSeconds = 7200.0f;
    inline constexpr float MaxFleeDurationSeconds = 300.0f;
    inline float InjuryHealth(float currentDamage, float damageBaseline) { return std::max(0.0f, currentDamage - damageBaseline); }
    inline bool IsSitting(Phase phase) { return phase == Phase::Sitting || phase == Phase::SittingWounded; }
    inline bool IsCommandHold(Phase phase) { return phase == Phase::Kneeling || phase == Phase::KneelingBound || IsSitting(phase); }
    inline bool UsesWoundedLocomotion(Phase phase) { return phase == Phase::AvoidingCombat || phase == Phase::Wandering; }

    struct State
    {
        Phase phase;
        float remaining;
        float commandHoldRemaining{};
        KneelingVariant selectedKneelingVariant{ KneelingVariant::Regular };
        std::uint8_t selectedSittingVariant{};
        float fleeRemaining{};
    };

    struct Event
    {
        EventKind kind{ EventKind::Observe };
        float duration{};
    };

    struct Facts
    {
        bool alive{ true };
        bool eligible{ true };
        bool defeated{};
        bool loaded{ true };
        bool paused{};
        bool nearbyCombat{};
        bool dialogue{};
        float delta{};
        float realDelta{};
        float injuryHealth{ 1.0f };
        float distanceFromPlayer{};
        float commandHoldDurationSeconds{ CommandHoldDurationSeconds };
        float fleeDurationSeconds{ FleeDurationSeconds };
        float fleeDistance{ FleeDistance };
    };

    inline bool ValidDuration(float seconds) { return std::isfinite(seconds) && seconds >= 1.0f && seconds <= 600.0f; }
    inline bool ValidState(State state)
    {
        return (state.phase == Phase::AvoidingCombat || state.phase == Phase::Wandering || state.phase == Phase::Fleeing || IsCommandHold(state.phase)) &&
               std::isfinite(state.remaining) && state.remaining >= 0.0f && state.remaining <= 600.0f &&
               std::isfinite(state.commandHoldRemaining) && state.commandHoldRemaining >= 0.0f && state.commandHoldRemaining <= MaxCommandHoldDurationSeconds &&
               std::isfinite(state.fleeRemaining) && state.fleeRemaining >= 0.0f && state.fleeRemaining <= MaxFleeDurationSeconds &&
               (state.selectedKneelingVariant == KneelingVariant::Regular || state.selectedKneelingVariant == KneelingVariant::Blessing ||
                state.selectedKneelingVariant == KneelingVariant::ChildSitKneel) && state.selectedSittingVariant < 16;
    }
    inline bool CanRemainManaged(const Facts& facts) { return facts.alive && facts.eligible && !facts.defeated; }
    inline bool ValidTuning(const Facts& facts)
    {
        return std::isfinite(facts.commandHoldDurationSeconds) && facts.commandHoldDurationSeconds >= 1 && facts.commandHoldDurationSeconds <= MaxCommandHoldDurationSeconds &&
            std::isfinite(facts.fleeDurationSeconds) && facts.fleeDurationSeconds >= 1 && facts.fleeDurationSeconds <= MaxFleeDurationSeconds &&
            std::isfinite(facts.fleeDistance) && facts.fleeDistance >= 128 && facts.fleeDistance <= FleeDistance;
    }
    inline void AdvanceCommandHold(State& state, float seconds)
    {
        if (IsCommandHold(state.phase) && std::isfinite(seconds) && seconds >= 0)
            state.commandHoldRemaining = std::max(0.0f, state.commandHoldRemaining - seconds);
    }

    inline void AdvanceRealTimers(State& state, float seconds)
    {
        AdvanceCommandHold(state, seconds);
        if (state.phase == Phase::Fleeing && std::isfinite(seconds) && seconds >= 0)
            state.fleeRemaining = std::max(0.0f, state.fleeRemaining - seconds);
    }

    inline std::optional<State> Decide(State state, Event event, const Facts& facts)
    {
        if (!ValidState(state) || !CanRemainManaged(facts) || event.kind == EventKind::Release) return std::nullopt;
        if (!ValidTuning(facts)) return state;
        if (event.kind == EventKind::Refresh) {
            if (!ValidDuration(event.duration)) return state;
            state.remaining = event.duration;
        }
        if (event.kind == EventKind::Observe) AdvanceRealTimers(state, facts.realDelta);
        if (state.phase == Phase::Fleeing) {
            if (state.fleeRemaining == 0 || (std::isfinite(facts.distanceFromPlayer) && facts.distanceFromPlayer >= facts.fleeDistance)) return std::nullopt;
            if (event.kind != EventKind::Kneel && event.kind != EventKind::Sit) return state;
        }
        if (!facts.loaded || facts.paused) return state;
        if (state.phase == Phase::Fleeing) state.fleeRemaining = 0;
        if (event.kind == EventKind::Flee) {
            if (state.phase == Phase::KneelingBound) return state;
            state.phase = Phase::Fleeing; state.fleeRemaining = facts.fleeDurationSeconds; state.commandHoldRemaining = 0;
            return state;
        }
        const auto previous = state.phase;
        if (event.kind == EventKind::Bind) {
            if (state.phase == Phase::Kneeling || IsSitting(state.phase)) {
                state.phase = Phase::KneelingBound;
                state.commandHoldRemaining = facts.commandHoldDurationSeconds;
            }
        } else if (event.kind == EventKind::Kneel) {
            if (state.phase == Phase::Kneeling || state.phase == Phase::KneelingBound) return state;
            state.commandHoldRemaining = facts.commandHoldDurationSeconds;
            state.phase = Phase::Kneeling;
        } else if (event.kind == EventKind::Sit) {
            if (IsSitting(state.phase) || state.phase == Phase::KneelingBound) return state;
            state.commandHoldRemaining = facts.commandHoldDurationSeconds;
            state.phase = facts.injuryHealth > 0 ? Phase::Sitting : Phase::SittingWounded;
        } else if (event.kind == EventKind::Healed) {
            if (state.phase == Phase::SittingWounded && facts.injuryHealth > 0) state.phase = Phase::Sitting;
        } else if (!IsCommandHold(state.phase) || event.kind == EventKind::Resume ||
            (state.commandHoldRemaining == 0 && !facts.dialogue)) {
            state.phase = facts.nearbyCombat ? Phase::AvoidingCombat : Phase::Wandering;
            state.commandHoldRemaining = 0;
        }
        if (state.phase == Phase::Wandering && previous == Phase::Wandering && event.kind == EventKind::Observe &&
            std::isfinite(facts.delta) && facts.delta >= 0.0f) {
            state.remaining = std::max(0.0f, state.remaining - facts.delta);
        }
        if (state.phase == Phase::Wandering && state.remaining == 0.0f && !facts.dialogue) return std::nullopt;
        return state;
    }
}
