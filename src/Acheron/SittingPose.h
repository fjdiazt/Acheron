#pragma once
#include <cstdint>

namespace Acheron::Peaceful
{
    inline constexpr std::uint8_t NormalSittingPoseCount = 10;
    inline constexpr std::uint8_t SittingPoseCount = 16;
    inline bool FemaleOnlySittingPose(std::uint8_t pose) { return pose == 9 || pose >= 14; }
    inline bool SittingPoseAllowed(std::uint8_t pose, bool wounded, bool female)
    {
        return pose < SittingPoseCount && (pose >= NormalSittingPoseCount) == wounded &&
            (female || !FemaleOnlySittingPose(pose));
    }
}
