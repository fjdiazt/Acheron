#include "Serialization/Serialize.h"

#include "Acheron/Defeat.h"
#include "Acheron/Pacification.h"
#include "Acheron/EventSink.h"
#include "Serialization/EventManager.h"

namespace Serialization
{
    void Serialize::SaveCallback(SKSE::SerializationInterface* a_intfc)
    {
        EventManager::GetSingleton()->Save(a_intfc, _Version);

        if (!a_intfc->OpenRecord(_Defeated, _DefeatedVersion))
            logger::error("Failed to open record <Defeated>");
        else
            Acheron::Defeat::Save(a_intfc, _Defeated);

        if (!a_intfc->OpenRecord(_Pacified, _Version))
            logger::error("Failed to open record <Pacified>");
        else
            Acheron::Defeat::Save(a_intfc, _Pacified);

        if (!a_intfc->OpenRecord(_Processing, _Version))
            logger::error("Failed to open record <Processing>");
        else if (!a_intfc->WriteRecordData(Settings::ProcessingEnabled))
            logger::error("Failed to serialize record <Processing>");

        if (!a_intfc->OpenRecord(_Consequence, _Version))
            logger::error("Failed to open record <Processing>");
        else if (!a_intfc->WriteRecordData(Settings::ConsequenceEnabled))
            logger::error("Failed to serialize record <Processing>");

        if (a_intfc->OpenRecord(_Peaceful, _PeacefulVersion)) Acheron::Pacification::Save(a_intfc);
        else logger::error("Unable to open peaceful cosave record");
        logger::info("Finished writing data to cosave");
    }

    void Serialize::LoadCallback(SKSE::SerializationInterface* a_intfc)
    {
        uint32_t type;
        uint32_t version;
        uint32_t length;
        while (a_intfc->GetNextRecordInfo(type, version, length)) {
            if (type == _HunterPride || type == EventManager::HunterPrideSelect) continue; // Discard obsolete custom-menu data.
            if (type == _Defeated) {
                if (version >= 1 && version <= _DefeatedVersion) Acheron::Defeat::Load(a_intfc, type, version);
                else logger::warn("Unsupported defeated cosave version {}", version);
                continue;
            }
            if (type == _Peaceful) {
                if (version >= 1 && version <= _PeacefulVersion) Acheron::Pacification::Load(a_intfc, version);
                else logger::warn("Unsupported peaceful cosave version {}", version);
                continue;
            }
            const auto ty = GetTypeName(type);
            if (version != _Version) {
                logger::info("Invalid Version for loaded Data of Type = {}. Expected = {}; Got = {}", ty, static_cast<uint32_t>(_Version), version);
                continue;
            }
            logger::info("Loading record {}", ty);
            switch (type) {
            case _Pacified:
                Acheron::Defeat::Load(a_intfc, type);
                break;
            case _Processing:
                a_intfc->ReadRecordData(Settings::ProcessingEnabled);
                break;
            case _Consequence:
                a_intfc->ReadRecordData(Settings::ConsequenceEnabled);
                break;
            default:
                EventManager::GetSingleton()->Load(a_intfc, type);
                break;
            }
        }

        logger::info("Finished loading data from cosave");
        Acheron::Pacification::Reconcile();
    }

    void Serialize::RevertCallback(SKSE::SerializationInterface* a_intfc)
    {
        Acheron::Pacification::Revert();
        EventManager::GetSingleton()->Revert(a_intfc);
        Acheron::Defeat::Revert(a_intfc);
    }

    void Serialize::FormDeleteCallback(RE::VMHandle a_handle)
    {
        EventManager::GetSingleton()->FormDelete(a_handle);
    }

    inline std::string GetTypeName(uint32_t a_type)
    {
        constexpr auto size = sizeof(uint32_t);
        std::string ret{};
        ret.resize(size);
        const char* it = reinterpret_cast<char*>(&a_type);
        for (size_t i = 0, j = size - 1; i < size; i++, j--)
            ret[j] = std::isprint(it[i]) ? it[i] : '_';

        return ret;
    }

}  // namespace Serialization
