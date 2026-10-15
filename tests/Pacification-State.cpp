#include "Acheron/PacificationState.h"
#include "Acheron/TestState.h"
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
    for (const auto phase : { Phase::AvoidingCombat, Phase::Wandering, Phase::Kneeling, Phase::KneelingBound }) {
        const State previous{ phase, 37, 12, KneelingVariant::Blessing };
        for (const auto command : { TestState::KneelingRegular, TestState::KneelingBlessing, TestState::KneelingChild, TestState::KneelingBound }) {
            const auto next = SelectTestState(command, previous, 60);
            Require(next && next->remaining == 37 && next->commandHoldRemaining == CommandHoldDurationSeconds, "Test hold changed peaceful budget or failed to restart hold");
            Require(next->phase == (command == TestState::KneelingBound ? Phase::KneelingBound : Phase::Kneeling), "Test transition restriction not bypassed");
            if (command != TestState::KneelingBound)
                Require(next->selectedKneelingVariant == (command == TestState::KneelingRegular ? KneelingVariant::Regular : command == TestState::KneelingBlessing ? KneelingVariant::Blessing : KneelingVariant::ChildSitKneel), "Test variant not deterministic");
        }
        for (const auto command : { TestState::AvoidingCombat, TestState::Wandering }) {
            const auto next = SelectTestState(command, previous, 60);
            Require(next && next->remaining == 60 && next->commandHoldRemaining == 0, "Test movement timer incorrect");
            Require(next->phase == (command == TestState::AvoidingCombat ? Phase::AvoidingCombat : Phase::Wandering), "Test movement destination incorrect");
        }
    }
    Require(!SelectTestState(TestState::KneelingRegular, { Phase::Wandering, 37 }, 0), "Test invalid duration accepted");
    Require(!SelectTestState(TestState::Normal, { Phase::Wandering, 37 }, 60), "Engine state became peaceful owner");
    Require(!SelectTestState(static_cast<TestState>(99), { Phase::Wandering, 37 }, 60), "Invalid Test command accepted");
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
    auto enteringBound = *bound;
    enteringBound.phase = Phase::Kneeling;
    AdvanceCommandHold(enteringBound, 7.0f);
    enteringBound.phase = Phase::KneelingBound;
    Require(enteringBound.commandHoldRemaining == 1793.0f && enteringBound.remaining == 37,
        "Bind exit/entry time restarted hold or consumed peaceful budget");
    for (float invalid : { -1.0f, std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity() }) {
        AdvanceCommandHold(enteringBound, invalid);
        Require(enteringBound.commandHoldRemaining == 1793.0f, "Invalid elapsed hold time applied");
    }
    for (const auto event : { EventKind::Kneel, EventKind::Bind, EventKind::Resume }) {
        for (bool blockedPause : { false, true }) {
            Facts blocked{}; blocked.paused = blockedPause; blocked.loaded = blockedPause;
            const auto rejected = Decide(state, { event }, blocked);
            Require(rejected && rejected->phase == state.phase && rejected->commandHoldRemaining == state.commandHoldRemaining,
                "Paused/unloaded command changed phase or restarted hold");
        }
    }
    Facts chatting{}; chatting.dialogue = true;
    const auto talkingResume = Decide({ Phase::Kneeling, 0, 50 }, { EventKind::Resume }, chatting);
    Require(talkingResume && talkingResume->phase == Phase::Wandering, "Resume lost live zero-budget dialogue guard");
    Require(!Decide(*talkingResume, {}, {}), "Zero-budget dialogue owner remained after close");
    const auto refreshed = Decide({ Phase::Kneeling, 0, 0 }, { EventKind::Refresh, 60 }, chatting);
    Require(refreshed && refreshed->phase == Phase::Kneeling && refreshed->remaining == 60, "Refresh interrupted expired held dialogue");
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
    state = { Phase::Kneeling, 37.0f, 50.0f, KneelingVariant::Blessing };
    for (const auto event : { Event{}, Event{ EventKind::Refresh, 60.0f }, Event{ EventKind::Kneel }, Event{ EventKind::Bind } }) {
        Require(Decide(state, event, facts)->selectedKneelingVariant == KneelingVariant::Blessing,
            "Existing kneeling selection changed during observation/refresh/ignored kneel/bind");
    }
    for (bool combat : { false, true }) {
        facts.nearbyCombat = combat;
        const auto resumed = Decide(state, { EventKind::Resume }, facts);
        Remaining(resumed, combat ? Phase::AvoidingCombat : Phase::Wandering, 37.0f);
        Require(resumed->commandHoldRemaining == 0, "On your feet retained command hold");
    }
    Require(!ValidState({ Phase::Kneeling, 37.0f, 50.0f, static_cast<KneelingVariant>(99) }), "Unknown saved kneeling variant accepted");
    std::cout << "PASS: FSM transitions, lifecycle priority, timers, refresh and validation\n";
}
