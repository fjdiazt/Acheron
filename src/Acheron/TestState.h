#pragma once
#include "Acheron/PacificationState.h"

namespace Acheron::Peaceful
{
    // Order matches native Test dialogue INFOs; append commands, never reorder IDs.
    enum class TestState : std::uint8_t { Normal, Combat, Yielding, AvoidingCombat, Wandering, KneelingRegular, KneelingBlessing, KneelingBound, Dead, Count };

    inline std::optional<State> SelectTestState(TestState command, State previous, float duration)
    {
        if (!ValidState(previous) || !ValidDuration(duration)) return std::nullopt;
        switch (command) {
        case TestState::AvoidingCombat: previous.phase = Phase::AvoidingCombat; previous.remaining = duration; break;
        case TestState::Wandering: previous.phase = Phase::Wandering; previous.remaining = duration; break;
        case TestState::KneelingRegular: previous.phase = Phase::Kneeling; previous.selectedKneelingVariant = KneelingVariant::Regular; break;
        case TestState::KneelingBlessing: previous.phase = Phase::Kneeling; previous.selectedKneelingVariant = KneelingVariant::Blessing; break;
        case TestState::KneelingBound: previous.phase = Phase::KneelingBound; break;
        default: return std::nullopt; // Engine/defeat states use their existing lifecycle API.
        }
        previous.commandHoldRemaining = IsCommandHold(previous.phase) ? CommandHoldDurationSeconds : 0;
        return previous;
    }
}
