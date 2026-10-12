#include "Acheron/PacificationState.h"
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>

using namespace Acheron::Peaceful;

static void Require(bool value, const char* message)
{
    if (!value) throw std::runtime_error(message);
}

static void Remaining(const std::optional<State>& state, Phase phase, float seconds)
{
    Require(state && state->phase == phase && std::fabs(state->remaining - seconds) < 0.001f, "Incorrect phase/time");
}

int main()
{
    Facts facts{};
    State state{ Phase::Wandering, 3.0f };
    facts.delta = 1.0f;
    Remaining(Decide(state, {}, facts), Phase::Wandering, 2.0f);
    facts.nearbyCombat = true;
    Remaining(Decide(state, {}, facts), Phase::AvoidingCombat, 3.0f);
    state = { Phase::AvoidingCombat, 2.0f };
    Remaining(Decide(state, {}, facts), Phase::AvoidingCombat, 2.0f);
    facts.nearbyCombat = false;
    Remaining(Decide(state, {}, facts), Phase::Wandering, 2.0f);
    state = { Phase::Wandering, 2.0f };
    facts.paused = true;
    Remaining(Decide(state, {}, facts), Phase::Wandering, 2.0f);
    facts.paused = false;
    facts.loaded = false;
    Remaining(Decide(state, {}, facts), Phase::Wandering, 2.0f);
    facts.loaded = true;
    Remaining(Decide(state, { EventKind::Refresh, 60.0f }, facts), Phase::Wandering, 60.0f);
    facts.delta = 3.0f;
    Require(!Decide(state, {}, facts), "Elapsed timer did not expire");
    facts.dialogue = true;
    Remaining(Decide(state, {}, facts), Phase::Wandering, 0.0f);
    facts.dialogue = false;
    Require(!Decide({ Phase::Wandering, 0.0f }, {}, facts), "Dialogue release did not expire");
    facts.paused = true;
    facts.alive = false;
    Require(!Decide(state, { EventKind::Refresh, 60.0f }, facts), "Refresh overrode death");
    facts.alive = true;
    facts.defeated = true;
    Require(!Decide(state, {}, facts), "New defeat did not relinquish state");
    facts.defeated = false;
    facts.eligible = false;
    Require(!Decide(state, {}, facts), "Ineligible actor retained state");
    facts.eligible = true;
    Require(!Decide(state, { EventKind::Release }, facts), "Release ignored while paused");
    facts.paused = false;
    for (float invalid : { -1.0f, 0.0f, 601.0f, std::numeric_limits<float>::infinity() }) {
        Require(!ValidDuration(invalid), "Invalid duration accepted");
        Remaining(Decide(state, { EventKind::Refresh, invalid }, facts), Phase::Wandering, 2.0f);
    }
    for (float invalid : { -1.0f, std::numeric_limits<float>::quiet_NaN() }) {
        facts.delta = invalid;
        Remaining(Decide(state, {}, facts), Phase::Wandering, 2.0f);
    }
    Require(!ValidState({ static_cast<Phase>(99), 2.0f }), "Unknown persisted phase accepted");
    Require(!ValidState({ Phase::Wandering, 601.0f }), "Invalid persisted time accepted");
    Require(ValidState({ Phase::Wandering, 0.0f }), "Deferred expiry rejected");
    Require(ValidDuration(1.0f) && ValidDuration(600.0f), "Duration boundaries rejected");
    facts = {}; facts.delta = 1.0f;
    for (auto phase : { Phase::AvoidingCombat, Phase::Wandering })
        Remaining(Decide({ phase, 3.0f }, { EventKind::Kneel }, facts), Phase::Kneeling, 3.0f);
    state = { Phase::Kneeling, 3.0f, CommandHoldDurationSeconds };
    facts.realDelta = 2.0f;
    const auto kneeling = Decide(state, {}, facts);
    Remaining(kneeling, Phase::Kneeling, 3.0f);
    Require(kneeling->commandHoldRemaining == 1798.0f, "Kneeling did not use real elapsed seconds");
    facts.nearbyCombat = true;
    Remaining(Decide(state, {}, facts), Phase::Kneeling, 3.0f);
    Require(Decide(state, {}, facts)->commandHoldRemaining == 1798.0f, "Combat paused command hold timer");
    Remaining(Decide(state, { EventKind::Refresh, 60.0f }, facts), Phase::Kneeling, 60.0f);
    Require(Decide(state, { EventKind::Refresh, 60.0f }, facts)->commandHoldRemaining == CommandHoldDurationSeconds, "Wander refresh changed command hold timer");
    Remaining(Decide(state, { EventKind::Resume }, facts), Phase::AvoidingCombat, 3.0f);
    facts.nearbyCombat = false;
    Remaining(Decide(state, { EventKind::Resume }, facts), Phase::Wandering, 3.0f);
    facts.realDelta = CommandHoldDurationSeconds;
    Remaining(Decide(state, {}, facts), Phase::Wandering, 3.0f);
    facts.nearbyCombat = true;
    Remaining(Decide(state, {}, facts), Phase::AvoidingCombat, 3.0f);
    facts.paused = true;
    const auto paused = Decide(state, {}, facts);
    Require(paused->phase == Phase::Kneeling && paused->commandHoldRemaining == 0, "Paused real timer did not elapse");
    facts.paused = false; facts.dialogue = true;
    Require(Decide(state, {}, facts)->phase == Phase::Kneeling, "Expiry interrupted dialogue");
    facts.dialogue = false;
    facts.defeated = true;
    Require(!Decide(state, { EventKind::Kneel }, facts), "Kneeling overrode new defeat");
    facts = {};
    state = { Phase::Kneeling, 37.0f, 50.0f };
    const auto bound = Decide(state, { EventKind::Bind }, facts);
    Remaining(bound, Phase::KneelingBound, 37.0f);
    Require(bound->commandHoldRemaining == CommandHoldDurationSeconds, "Binding did not restart command hold timer");
    Require(ValidState(*bound), "Bound state rejected by persistence validation");
    facts.nearbyCombat = true; facts.realDelta = 3.0f;
    const auto held = Decide(*bound, {}, facts);
    Remaining(held, Phase::KneelingBound, 37.0f);
    Require(held->commandHoldRemaining == 1797.0f, "Bound timer stopped during combat");
    Remaining(Decide(*bound, { EventKind::Resume }, facts), Phase::AvoidingCombat, 37.0f);
    facts.nearbyCombat = false; facts.realDelta = CommandHoldDurationSeconds;
    Remaining(Decide(*bound, {}, facts), Phase::Wandering, 37.0f);
    facts.dialogue = true;
    Require(Decide(*bound, {}, facts)->phase == Phase::KneelingBound, "Bound expiry interrupted dialogue");
    Require(!Decide(*bound, { EventKind::Release }, facts), "Bound release ignored");
    Require(Decide(*bound, { EventKind::Kneel }, facts)->phase == Phase::KneelingBound, "Kneel silently unbound actor");
    facts = {};
    Remaining(Decide({ Phase::Wandering, 10.0f }, { EventKind::Bind }, facts), Phase::Wandering, 10.0f);
    std::cout << "PASS: FSM transitions, lifecycle priority, timers, refresh and validation\n";
}
