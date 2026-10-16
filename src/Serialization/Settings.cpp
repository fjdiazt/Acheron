#include "Settings.h"
#include "Acheron/PacificationState.h"

#include <SimpleIni.h>

int Settings::ClampIntSetting(const std::string& key, int value)
{
    if (_strcmpi(key.c_str(), "iPeacefulWanderDuration") == 0) return std::clamp(value, 1, 600);
    if (_strcmpi(key.c_str(), "iCommandHoldDuration") == 0) return std::clamp(value, 1, static_cast<int>(Acheron::Peaceful::MaxCommandHoldDurationSeconds));
    if (_strcmpi(key.c_str(), "iFleeDuration") == 0) return std::clamp(value, 1, static_cast<int>(Acheron::Peaceful::MaxFleeDurationSeconds));
    if (_strcmpi(key.c_str(), "iFleeDistance") == 0) return std::clamp(value, 128, static_cast<int>(Acheron::Peaceful::FleeDistance));
    return value;
}

void Settings::Initialize()
{
    const auto& path = CONFIGPATH("Settings.yaml");
    if (!fs::exists(path))
        return;

    try {
        const auto yaml = YAML::LoadFile(path);

        const auto ReadMCM = [&yaml]<typename T>(const char* a_key, T& a_out) {
            if (!yaml[a_key].IsDefined())
                return;
            const auto val = yaml[a_key].as<T>();
            if constexpr (std::is_same_v<T, int>) a_out = ClampIntSetting(a_key, val);
            else a_out = val;
        };
#define MCM_SETTING(STR, DEFAULT) ReadMCM(#STR, STR);
#include "mcm.def"
#undef MCM_SETTING

        logger::info("Finished loading user settings");
    } catch (const std::exception& e) {
        logger::error("Unable to laod settings, error: {}", e.what());
    }
}

void Settings::Save()
{
    YAML::Node settings{};
#define MCM_SETTING(STR, DEFAULT) settings[#STR] = STR;
#include "mcm.def"
#undef MCM_SETTING

    std::ofstream fout(CONFIGPATH("Settings.yaml"));
    fout << settings;
    logger::info("Finished saving user settings");
}
