#pragma once
#include "Acheron/PacificationState.h"
#include "Acheron/SittingPose.h"

namespace Acheron::Peaceful
{
    // Order matches native Test dialogue INFOs; append commands, never reorder IDs.
    enum class TestState : std::uint8_t { Normal, Combat, Yielding, AvoidingCombat, Wandering, KneelingRegular, KneelingBlessing, KneelingBound, Dead, KneelingChild,
        SitCrossLegged, SitLedge, SitSeat1, SitSeat2, SitSeat3Ledge, SitSeat3CrossLegged, SitSeat4, SitSeat5, SitSeat6, SitSeat7,
        SitWoundedBeggar, SitWounded1, SitWounded2, SitWounded3, SitFemaleLaydown, SitFemaleLaydownMirrored, Count };

    inline std::optional<State> SelectTestState(TestState command, State previous, float duration)
    {
        if (!ValidState(previous) || !ValidDuration(duration)) return std::nullopt;
        switch (command) {
        case TestState::AvoidingCombat: previous.phase = Phase::AvoidingCombat; previous.remaining = duration; break;
        case TestState::Wandering: previous.phase = Phase::Wandering; previous.remaining = duration; break;
        case TestState::KneelingRegular: previous.phase = Phase::Kneeling; previous.selectedKneelingVariant = KneelingVariant::Regular; break;
        case TestState::KneelingBlessing: previous.phase = Phase::Kneeling; previous.selectedKneelingVariant = KneelingVariant::Blessing; break;
        case TestState::KneelingChild: previous.phase = Phase::Kneeling; previous.selectedKneelingVariant = KneelingVariant::ChildSitKneel; break;
        case TestState::KneelingBound: previous.phase = Phase::KneelingBound; break;
        default:
            if (command < TestState::SitCrossLegged || command >= TestState::Count) return std::nullopt;
            previous.selectedSittingVariant = static_cast<std::uint8_t>(command) - static_cast<std::uint8_t>(TestState::SitCrossLegged);
            previous.phase = previous.selectedSittingVariant < NormalSittingPoseCount ? Phase::Sitting : Phase::SittingWounded;
            break;
        }
        previous.commandHoldRemaining = IsCommandHold(previous.phase) ? CommandHoldDurationSeconds : 0;
        return previous;
    }
}
