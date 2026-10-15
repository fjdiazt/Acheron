#include "Acheron/EventSink.h"

#include "Acheron/Defeat.h"
#include "Acheron/Pacification.h"
#include "Acheron/GodMode.h"
#include "shared/KrisV/Script.h"

namespace Acheron
{
    EventResult EventHandler::ProcessEvent(const RE::TESTopicInfoEvent* event, RE::BSTEventSource<RE::TESTopicInfoEvent>*)
    {
        if (REL::Module::IsVR() || !event || !event->speakerRef) return EventResult::kContinue;
        static_assert(GameForms::TestDialogueInfoIDs.size() == static_cast<std::size_t>(Peaceful::TestState::Count));
        if (event->type.underlying() == 0) {
            for (std::size_t i = 0; i < GameForms::TestDialogueInfoIDs.size(); ++i) {
                if (event->topicInfoFormID == GameForms::TestDialogueInfoIDs[i])
                    Pacification::RequestTestState(event->speakerRef->As<RE::Actor>(), static_cast<Peaceful::TestState>(i));
            }
        }
        if ((event->topicInfoFormID == GameForms::KneelDialogueInfoID || event->topicInfoFormID == GameForms::YieldKneelDialogueInfoID) && event->type.underlying() == 0) {
            const auto actor = event->speakerRef->As<RE::Actor>();
            if (actor && (Pacification::IsActive(actor) || Defeat::IsDefeated(actor))) Pacification::RequestKneel(actor);
        }
        if (GameForms::BindDialogueInfoID && event->topicInfoFormID == GameForms::BindDialogueInfoID && event->type.underlying() == 0) {
            const auto actor = event->speakerRef->As<RE::Actor>();
            if (actor && Pacification::IsActive(actor)) Pacification::RequestKneel(actor, true);
        }
        if (event->type.underlying() == 0 && std::ranges::find(GameForms::SitDialogueInfoIDs, event->topicInfoFormID) != GameForms::SitDialogueInfoIDs.end())
            Pacification::RequestSit(event->speakerRef->As<RE::Actor>());
        if (event->type.underlying() == 0 && event->topicInfoFormID == GameForms::HealSittingDialogueInfoID) {
            const auto actor = event->speakerRef->As<RE::Actor>();
            if (Pacification::NeedsHealing(actor)) {
                const auto script = Script::GetScriptObject(GameForms::MainQuest, "AcheronHunterPride", true);
                if (!script || !Script::DispatchMethodCall(script, "HealTarget", nullptr, static_cast<RE::Actor*>(actor)))
                    logger::error("Unable to dispatch sitting Heal");
            }
        }
        if (GameForms::StandDialogueInfoID && event->topicInfoFormID == GameForms::StandDialogueInfoID && event->type.underlying() == 0) {
            const auto actor = event->speakerRef->As<RE::Actor>();
            if (actor && Pacification::IsActive(actor)) Pacification::RequestResume(actor);
        }
        if (event->type.underlying() == 0) {
            for (std::size_t i = 0; i < GameForms::DefeatedDialogueInfoIDs.size(); ++i) {
                if (event->topicInfoFormID != GameForms::DefeatedDialogueInfoIDs[i]) continue;
                const auto actor = event->speakerRef->As<RE::Actor>();
                if (actor && Defeat::IsDefeated(actor)) {
                    const auto script = Script::GetScriptObject(GameForms::MainQuest, "AcheronHunterPride", true);
                    if (!script || !Script::DispatchMethodCall(script, "PerformAction", nullptr, static_cast<std::int32_t>(i), static_cast<RE::Actor*>(actor)))
                        logger::error("Unable to dispatch defeated dialogue action {}", i);
                }
            }
        }
#ifdef ACHERON_YIELD_TESTS
        const auto subject = event->speakerRef->As<RE::Actor>();
        if (subject && (Pacification::IsActive(subject) || Defeat::IsDefeated(subject))) {
            const auto spoken = RE::TESForm::LookupByID<RE::TESTopicInfo>(event->topicInfoFormID);
            const auto topic = spoken ? spoken->parentTopic : nullptr;
            logger::info("[ManagedSpeech] actor={:08X} info={:08X} topic={:08X} subtype={} begin={}",
                subject->GetFormID(), event->topicInfoFormID, topic ? topic->GetFormID() : 0,
                topic ? topic->data.subtype.underlying() : 0, event->type.underlying() == 0);
        }
        if (subject && (subject->GetFormID() & 0xFF000000) == 0xFF000000 && !Pacification::IsActive(subject) && !Defeat::IsDefeated(subject)) {
            const auto spoken = RE::TESForm::LookupByID<RE::TESTopicInfo>(event->topicInfoFormID);
            const auto topic = spoken ? spoken->parentTopic : nullptr;
            logger::info("[UnmanagedSpeech] actor={:08X} info={:08X} subtype={} begin={}",
                subject->GetFormID(), event->topicInfoFormID, topic ? topic->data.subtype.underlying() : 0, event->type.underlying() == 0);
        }
        const auto info = RE::TESDataHandler::GetSingleton()->LookupForm<RE::TESTopicInfo>(0x817, "Acheron.esm");
        if ((info && event->topicInfoFormID == info->GetFormID()) || (GameForms::KneelDialogueInfoID && event->topicInfoFormID == GameForms::KneelDialogueInfoID) ||
            (GameForms::YieldKneelDialogueInfoID && event->topicInfoFormID == GameForms::YieldKneelDialogueInfoID) ||
            (GameForms::BindDialogueInfoID && event->topicInfoFormID == GameForms::BindDialogueInfoID) ||
            (GameForms::StandDialogueInfoID && event->topicInfoFormID == GameForms::StandDialogueInfoID) ||
            std::ranges::find(GameForms::SitDialogueInfoIDs, event->topicInfoFormID) != GameForms::SitDialogueInfoIDs.end() ||
            event->topicInfoFormID == GameForms::HealSittingDialogueInfoID ||
            std::ranges::find(GameForms::TestRootInfoIDs, event->topicInfoFormID) != GameForms::TestRootInfoIDs.end() ||
            std::ranges::find(GameForms::TestDialogueInfoIDs, event->topicInfoFormID) != GameForms::TestDialogueInfoIDs.end() ||
            std::ranges::find(GameForms::DefeatedDialogueInfoIDs, event->topicInfoFormID) != GameForms::DefeatedDialogueInfoIDs.end()) {
            logger::info("[PeacefulTopic] actor={:08X} info={:08X} begin={}", event->speakerRef->GetFormID(), event->topicInfoFormID,
                event->type.underlying() == 0);
        }
#endif
        return EventResult::kContinue;
    }
    EventResult EventHandler::ProcessEvent(const RE::BSAnimationGraphEvent* a_event, RE::BSTEventSource<RE::BSAnimationGraphEvent>*)
    {
        if (!a_event || a_event->holder->IsNot(RE::FormType::ActorCharacter))
            return EventResult::kContinue;

        auto source = const_cast<RE::Actor*>(a_event->holder->As<RE::Actor>());
        // constexpr std::array events{ "MTState", "IdleStop", "JumpLandEnd" };
        if (a_event->tag == "MTState") {
            if (auto process = source->GetActorRuntimeData().currentProcess) {
                process->PlayIdle(source, GameForms::BleedoutStart, source);
            } else {
                source->NotifyAnimationGraph("BleedoutStart");
            }
        }
        return EventResult::kContinue;
    }

    EventResult EventHandler::ProcessEvent(const RE::TESActorLocationChangeEvent* a_event, RE::BSTEventSource<RE::TESActorLocationChangeEvent>*)
    {
        if (!a_event || !a_event->actor || !a_event->actor->IsPlayerRef())
            return EventResult::kContinue;
        // Dont process playing loading game
        const auto player = RE::PlayerCharacter::GetSingleton();
        if (!player->GetPlayerRuntimeData().playerFlags.isLoading)
            if (RE::UI::GetSingleton()->IsMenuOpen(RE::InterfaceStrings::GetSingleton()->loadingMenu))
                return EventResult::kContinue;
        // Dont process loading child/parent locs
        if (a_event->newLoc && a_event->oldLoc)
            if (a_event->newLoc->IsChild(a_event->oldLoc) || a_event->newLoc->IsParent(a_event->oldLoc))
                return EventResult::kContinue;

        std::vector<RE::Actor*> rescuethis{};
        Defeat::ForEachVictim([&](RE::FormID a_formid, std::shared_ptr<Defeat::VictimData> a_data) {
            RE::Actor* victim = RE::TESForm::LookupByID<RE::Actor>(a_formid);
            if (!victim || !victim->Is3DLoaded()) {
                a_data->mark_for_recovery = true;
            } else if (Settings::iFollowerRescue == 2 && victim->IsPlayerTeammate()) {
                if (!victim->Is3DLoaded() || victim->GetPosition().GetDistance(a_event->actor->GetPosition()) > 4096)
                    rescuethis.push_back(victim);
            }
            return Defeat::VictimVistor::Continue;
        });
        for (auto& rescue : rescuethis) {
            Defeat::RescueActor(rescue, true);
        }
        return EventResult::kContinue;
    }

    EventResult EventHandler::ProcessEvent(const RE::TESCombatEvent* a_event, RE::BSTEventSource<RE::TESCombatEvent>*)
    {
        if (!a_event || a_event->newState != RE::ACTOR_COMBAT_STATE::kNone)
            return EventResult::kContinue;

        const auto worn = ExtractCachedArmor(a_event->actor->GetFormID());
        const auto actor = a_event->actor->As<RE::Actor>();
        if (actor && actor->Is3DLoaded() && !actor->IsDead() && !Defeat::IsDefeated(actor)) {
            if (!worn.empty()) {
                const auto em = RE::ActorEquipManager::GetSingleton();
                for (auto& gear : worn) {
                    em->EquipObject(actor, gear);
                }
            }
        }
        return EventResult::kContinue;
    }

    EventResult EventHandler::ProcessEvent(const RE::TESFormDeleteEvent* a_event, RE::BSTEventSource<RE::TESFormDeleteEvent>*)
    {
        if (a_event) {
            const auto id = a_event->formID;
            Pacification::RequestEnd(id);
            Defeat::Delete(a_event->formID);
        }

        return EventResult::kContinue;
    }

    EventResult EventHandler::ProcessEvent(const RE::TESDeathEvent* a_event, RE::BSTEventSource<RE::TESDeathEvent>*)
    {
        if (!a_event || !a_event->actorDying)
            return EventResult::kContinue;

        auto dying = a_event->actorDying->As<RE::Actor>();
        if (!dying)
            return EventResult::kContinue;

        const auto id = dying->GetFormID();
        Pacification::RequestEnd(id);

        if (Defeat::IsDefeated(dying)) {
            Defeat::RescueActor(dying, true);
            logger::info("Form {:X} died and has been removed from the Victims list", dying->GetFormID());
        } else if (Defeat::IsPacified(dying)) {
            Defeat::UndoPacify(dying);
            logger::info("Form {:X} died and has been removed from the Pacified list", dying->GetFormID());
        }

        return EventResult::kContinue;
    }

    EventResult EventHandler::ProcessEvent(const RE::TESResetEvent* a_event, RE::BSTEventSource<RE::TESResetEvent>*)
    {
        if (!a_event || !a_event->object)
            return EventResult::kContinue;

        auto reset = a_event->object->As<RE::Actor>();
        if (!reset)
            return EventResult::kContinue;

        const auto id = reset->GetFormID();
        Pacification::RequestEnd(id, true);

        if (Defeat::IsDefeated(reset)) {
            Defeat::RescueActor(reset, true);
            logger::info("Form {:X} has been reset and thus been removed from the Victims list", reset->GetFormID());
        } else if (Defeat::IsPacified(reset)) {
            Defeat::UndoPacify(reset);
            logger::info("Form {:X} has been reset and thus been removed from the Pacified list", reset->GetFormID());
        }

        return EventResult::kContinue;
    }


    EventResult EventHandler::ProcessEvent(RE::InputEvent* const* a_event, RE::BSTEventSource<RE::InputEvent*>*)
    {
        if (!a_event || (Settings::iHunterPrideKey == -1 && Settings::iGodKey == -1))
            return EventResult::kContinue;

        const auto intfcStr = RE::InterfaceStrings::GetSingleton();
        const auto ui = RE::UI::GetSingleton();
        if (ui->IsMenuOpen(intfcStr->console) || ui->GameIsPaused())
            return EventResult::kContinue;

        const auto controlMap = RE::ControlMap::GetSingleton();
        if (!controlMap->IsMovementControlsEnabled())
            return EventResult::kContinue;

        const auto getKey = [&](int key) {
            if (key >= SKSE::InputMap::kMacro_GamepadOffset) {
                return SKSE::InputMap::GamepadKeycodeToMask(key);
            } else {
                return static_cast<uint32_t>(key);
            }
        };

        const auto hpkey = getKey(Settings::iHunterPrideKey);
        for (const RE::InputEvent* input = *a_event; input; input = input->next) {
            const auto event = input->AsButtonEvent();
            if (!event || !event->IsDown()) {
                continue;
            }
            const auto idcode = event->GetIDCode();
            const auto inputDevice = input->GetDevice();
            const auto macro = inputDevice == RE::INPUT_DEVICE::kGamepad ? SKSE::InputMap::GamepadMaskToKeycode(idcode) :
                inputDevice == RE::INPUT_DEVICE::kMouse ? idcode + SKSE::InputMap::kMacro_MouseButtonOffset : idcode;
            if (!REL::Module::IsVR() && Settings::iGodKey >= 0 && macro == static_cast<uint32_t>(Settings::iGodKey)) {
                GodMode::Apply();
                break;
            }
            if (!Settings::ProcessingEnabled || Settings::iHunterPrideKey == -1) continue;
            if (idcode == hpkey) {
                if (Settings::iHunterPrideKeyMod > -1) {
                    RE::BSInputDevice* device;
                    auto dmanager = RE::BSInputDeviceManager::GetSingleton();
                    switch (input->GetDevice()) {
                    case RE::INPUT_DEVICE::kGamepad:
                        device = dmanager->GetGamepad();
                        break;
                    case RE::INPUT_DEVICE::kKeyboard:
                        device = dmanager->GetKeyboard();
                        break;
                    case RE::INPUT_DEVICE::kFlatVirtualKeyboard:
                    case RE::INPUT_DEVICE::kVRVirtualKeyboard:
                        device = dmanager->GetVirtualKeyboard();
                        break;
                    default:
                        device = nullptr;
                        break;
                    }
                    if (device) {
                        const auto modkey = getKey(Settings::iHunterPrideKeyMod);
                        if (!device->IsPressed(modkey)) {
                            continue;
                        }
                    }
                }
                auto player = RE::PlayerCharacter::GetSingleton();
                if (idcode == hpkey) {
                    if (player->HasSpell(GameForms::HunterPride)) {
                        player->RemoveSpell(GameForms::HunterPride);
                        RE::SendHUDMessage::ShowHUDMessage("$Achr_HunterPrideRemoved");
                    } else {
                        player->AddSpell(GameForms::HunterPride);
                        RE::SendHUDMessage::ShowHUDMessage("$Achr_HunterPrideAdded");
                    }
                }
                break;
            }
        }
        return EventResult::kContinue;
    }

    void EventHandler::CacheWornArmor(const RE::FormID a_form, RE::TESObjectARMO* a_armor)
    {
        std::scoped_lock _lock{ cache_lock };
        worn_cache[a_form].push_back(a_armor);
    }

    std::vector<RE::TESObjectARMO*> EventHandler::ExtractCachedArmor(const RE::FormID a_form)
    {
        std::scoped_lock _lock{ cache_lock };
        if (auto node = worn_cache.extract(a_form); !node.empty())
            return std::move(node.mapped());
        return {};
    }

}  // namespace Acheron
