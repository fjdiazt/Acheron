#pragma once
#include "Acheron/PacificationState.h"
#include <array>

namespace Acheron::Peaceful
{
    struct PosePlayback { bool sourceExit{ true }; bool destinationEnter{ true }; };
    struct PoseSequence { bool sourceExit; bool destinationEnter; bool destinationHold; };
    struct PoseRule { Phase source; Phase destination; PosePlayback playback; };
    inline constexpr std::array PoseRules{
        PoseRule{ Phase::Kneeling, Phase::KneelingBound, { false, false } },
        PoseRule{ Phase::SittingWounded, Phase::Sitting, { false, false } }
    };
    inline PosePlayback PosePolicy(Phase source, Phase destination)
    {
        for (const auto& rule : PoseRules)
            if (rule.source == source && rule.destination == destination) return rule.playback;
        return {};
    }
    inline PoseSequence PoseSteps(Phase source, Phase destination, PosePlayback playback)
    {
        return { IsCommandHold(source) && playback.sourceExit,
            IsCommandHold(destination) && playback.destinationEnter, IsCommandHold(destination) };
    }
}
