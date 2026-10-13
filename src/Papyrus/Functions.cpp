#include "Papyrus/Functions.h"

#include "Acheron/Animation/Animation.h"
#include "Acheron/Defeat.h"
#include "Acheron/Pacification.h"
#include "Acheron/GodMode.h"
#include "Acheron/PacificationState.h"
#include "Acheron/Interface/CustomMenu.h"
#include "Acheron/Resolution.h"
#include "shared/KrisV/Util/String.h"

namespace Papyrus
{
    void Utility::ApplyGodPreset(RE::StaticFunctionTag*) { Acheron::GodMode::Apply(); }
    bool Defeat::KneelActor(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        if (REL::Module::IsVR() || !Acheron::Pacification::IsEligible(actor) ||
            (!Acheron::Defeat::IsDefeated(actor) && !Acheron::Pacification::IsActive(actor))) return false;
        Acheron::Pacification::RequestKneel(actor);
        return true;
    }
    bool Defeat::BindActor(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        if (REL::Module::IsVR() || !Acheron::Pacification::IsEligible(actor) || !Acheron::Pacification::IsActive(actor)) return false;
        Acheron::Pacification::RequestKneel(actor, true);
        return true;
    }
    bool Defeat::ResumePeacefulState(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        if (REL::Module::IsVR() || !Acheron::Pacification::IsEligible(actor) || !Acheron::Pacification::IsActive(actor)) return false;
        Acheron::Pacification::RequestResume(actor);
        return true;
    }
    bool Defeat::BeginPeacefulState(RE::StaticFunctionTag*, RE::Actor* actor, int seconds)
    {
        if (REL::Module::IsVR() || !Acheron::Pacification::IsEligible(actor) || !Acheron::Peaceful::ValidDuration(static_cast<float>(seconds))) return false;
        Acheron::Pacification::RequestBegin(actor, seconds);
        return true;
    }
    bool Defeat::IsPeacefulState(RE::StaticFunctionTag*, RE::Actor* actor) { return Acheron::Pacification::IsActive(actor); }
    bool Defeat::SupportsPeacefulRescue(RE::StaticFunctionTag*, RE::Actor* actor) { return !REL::Module::IsVR() && Acheron::Pacification::IsEligible(actor); }
#ifdef ACHERON_YIELD_TESTS
    void Defeat::ProbeCommandHold(RE::StaticFunctionTag*, RE::Actor* actor, float seconds) { Acheron::Pacification::ProbeCommandHold(actor, seconds); }
    void Defeat::ProbePeacefulState(RE::StaticFunctionTag*, RE::Actor* actor) { Acheron::Pacification::Trace(actor); }
    bool Defeat::ProbeNativeDialogue(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        const auto eligible = [](RE::Actor* subject) {
            return !REL::Module::IsVR() && subject && !subject->IsPlayerRef() && !subject->IsDead() &&
                subject->Is3DLoaded() && !subject->IsInCombat() && subject->CanTalkToPlayer() &&
                Acheron::Defeat::IsPacified(subject) &&
                (Acheron::Defeat::IsDefeated(subject) || Acheron::Pacification::IsActive(subject));
        };
        if (!eligible(actor)) return false;
        const auto handle = actor->GetHandle();
        SKSE::GetTaskInterface()->AddTask([handle, eligible]() {
            const auto subject = handle.get();
            if (!eligible(subject.get())) return;
            const auto aggression = subject->AsActorValueOwner()->GetActorValue(RE::ActorValue::kAggression);
            const auto result = Acheron::Pacification::OpenDialogue(subject.get());
            logger::info("[NativeDialogueProbe] actor={:08X} aggression={} nativeResult={}", subject->GetFormID(), aggression, result);
        });
        return true;
    }
    void Defeat::ProbeLegacyDialogueAggression(RE::StaticFunctionTag*, RE::Actor* actor) { Acheron::Pacification::ProbeLegacyAggression(actor); }
    void Defeat::ProbePeacefulLinks(RE::StaticFunctionTag*, RE::Actor* actor, RE::TESObjectREFR* anchor, RE::TESObjectREFR* threat)
    {
        if (!actor || !anchor || !threat || actor->IsPlayerRef()) { return; }
        const auto subjectHandle = actor->GetHandle();
        const auto anchorHandle = anchor->GetHandle();
        const auto threatHandle = threat->GetHandle();
        SKSE::GetTaskInterface()->AddTask([=]() {
            const auto subject = subjectHandle.get();
            const auto point = anchorHandle.get();
            const auto opponent = threatHandle.get();
            const auto forms = RE::TESDataHandler::GetSingleton();
            const auto anchorKey = forms->LookupForm<RE::BGSKeyword>(0x811, "Acheron.esm");
            const auto threatKey = forms->LookupForm<RE::BGSKeyword>(0x812, "Acheron.esm");
            if (!subject || !point || !opponent || !anchorKey || !threatKey) { return; }
            subject->extraList.SetLinkedRef(point.get(), anchorKey);
            subject->extraList.SetLinkedRef(opponent.get(), threatKey);
            logger::info("[PeacefulProbe] actor={:08X} anchor={:08X} threat={:08X}", subject->GetFormID(), point->GetFormID(), opponent->GetFormID());
            const auto player = RE::PlayerCharacter::GetSingleton();
            const auto info = forms->LookupForm<RE::TESTopicInfo>(0x817, "Acheron.esm");
            const auto topic = forms->LookupForm<RE::TESTopic>(0x816, "Acheron.esm");
            const auto manager = RE::MenuTopicManager::GetSingleton();
            const auto branch = forms->LookupForm<RE::BGSDialogueBranch>(0x815, "Acheron.esm");
            const auto originalTopic = forms->LookupForm<RE::TESTopic>(0x80E, "Acheron.esm");
            logger::info("[PeacefulTalkForms] info={} topic={} branch={} originalTopic={} originalInfos={} topicQuest={:08X} topicBranch={:08X}",
                info != nullptr, topic != nullptr, branch != nullptr, originalTopic != nullptr,
                originalTopic ? originalTopic->numTopicInfos : 0,
                topic && topic->ownerQuest ? topic->ownerQuest->GetFormID() : 0,
                topic && topic->ownerBranch ? topic->ownerBranch->GetFormID() : 0);
            logger::info("[PeacefulTalkProbe] actor={:08X} canTalk={} infoValid={} infos={} sharedInfo={:08X} menu={} goodbye={} branches={} playerCombat={}",
                subject->GetFormID(), subject->CanTalkToPlayer(), info && info->objConditions.IsTrue(subject.get(), player),
                topic ? topic->numTopicInfos : 0, info && info->dataInfo ? info->dataInfo->GetFormID() : 0,
                manager && manager->menuOpen, manager && manager->forceGoodbye, manager ? manager->topLevelBranches.size() : 0,
                player && player->IsInCombat());
        });
    }
#endif

    void Defeat::DefeatActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot Defeat a none Actor", a_stackID);
            return;
        }
        auto actor = a_actor->GetHandle();
        SKSE::GetTaskInterface()->AddTask([=]() {
            Acheron::Defeat::DefeatActor(actor.get().get());
        });
    }

    void Defeat::RescueActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, bool undopacify)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot Rescue a none Actor", a_stackID);
            return;
        }
        auto actor = a_actor->GetHandle();
        SKSE::GetTaskInterface()->AddTask([=]() {
            Acheron::Defeat::RescueActor(actor.get().get(), undopacify);
        });
    }

    void Defeat::PacifyActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot Pacify a none Actor", a_stackID);
            return;
        }
        Acheron::Defeat::Pacify(a_actor);
    }

    void Defeat::ReleaseActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot reset Pacification. Actor is none.", a_stackID);
            return;
        }
        Acheron::Pacification::RequestRelease(a_actor);
    }

    bool Defeat::IsDefeated(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot check Defeat Status. Actor is none", a_stackID);
            return false;
        }
        return Acheron::Defeat::IsDefeated(a_actor);
    }

    bool Defeat::IsPacified(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot check Pacification. Actor is none", a_stackID);
            return false;
        }
        return Acheron::Defeat::IsPacified(a_actor);
    }

    std::vector<RE::Actor*> Defeat::GetDefeated(RE::StaticFunctionTag*, bool a_loadedonly)
    {
        return Acheron::Defeat::GetAllDefeated(a_loadedonly);
    }

    std::vector<RE::Actor*> Defeat::GetPacified(RE::StaticFunctionTag*, bool a_loadedonly)
    {
        return Acheron::Defeat::GetAllPacified(a_loadedonly);
    }

    void ObjectRef::SetLinkedRef(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::TESObjectREFR* object, RE::TESObjectREFR* target, RE::BGSKeyword* keyword)
    {
        if (!object) {
            a_vm->TraceStack("Cannot set Linked Ref. Source is none", a_stackID);
            return;
        }
        object->extraList.SetLinkedRef(target, keyword);
    }

    std::vector<RE::TESObjectARMO*> Actor::GetWornArmor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, uint32_t ignoredmasks)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot get worn armor from a none reference", a_stackID);
            return {};
        }
        return Acheron::GetWornArmor(a_actor, ignoredmasks);
    }

    std::vector<RE::TESObjectARMO*> Actor::StripActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, uint32_t ignoredmasks)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot strip a none reference", a_stackID);
            return {};
        }
        const auto em = RE::ActorEquipManager::GetSingleton();
        const auto armors = Acheron::GetWornArmor(a_actor, ignoredmasks);
        std::vector<RE::TESObjectARMO*> ret{};
        for (auto& armor : armors) {
            if (armor->ContainsKeywordString("NoStrip")) {
                continue;
            }
            em->UnequipObject(a_actor, armor);
            ret.push_back(armor);
        }
        return ret;
    }

    std::vector<RE::TESForm*> ObjectRef::GetItemsByKeywords(
        VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*,
        RE::TESObjectREFR* a_container,
        std::vector<RE::BGSKeyword*> a_kywds,
        int32_t a_minvalue,
        bool a_qstitms)
    {
        if (!a_container) {
            a_vm->TraceStack("Cannot retrieve Items from a none reference", a_stackID);
            return {};
        }
        std::vector<RE::TESForm*> ret{};

        auto inventory = a_container->GetInventory();
        for (const auto& [form, data] : inventory) {
            if (!form->GetPlayable() || form->GetName()[0] == '\0')
                continue;
            if (!a_qstitms && data.second->IsQuestObject())
                continue;
            if (form->GetGoldValue() < a_minvalue)
                continue;
            if (!a_kywds.empty() && !form->HasKeywordInArray(a_kywds, false))
                continue;

            ret.push_back(form);
        }

        return ret;
    }

    void ObjectRef::RemoveAllItems(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::TESObjectREFR* from, RE::TESObjectREFR* to, bool excludeworn)
    {
        if (!from) {
            a_vm->TraceStack("Cannot remove Items from a none reference", a_stackID);
            return;
        }
        const auto reason = [&]() {
            using REASON = RE::ITEM_REMOVE_REASON;
            if (!to)
                return REASON::kRemove;
            else if (auto actor = to->As<RE::Actor>(); actor)
                return actor->IsPlayerTeammate() ? REASON::kStoreInTeammate : REASON::kSteal;
            else
                return REASON::kStoreInContainer;
        }();

        auto inventory = from->GetInventory();
        for (const auto& [form, data] : inventory) {
            if (!form->GetPlayable() || form->GetName()[0] == '\0')
                continue;
            if (data.second->IsQuestObject())
                continue;
            if (data.second->IsWorn()) {
                if (excludeworn) {
                    continue;
                }
                const auto kywdform = form->As<RE::BGSKeywordForm>();
                if (kywdform && kywdform->ContainsKeywordString("NoStrip")) {
                    continue;
                }
            }
            from->RemoveItem(form, data.first, reason, nullptr, to, 0, 0);
        }
    }

    RE::AlchemyItem* Actor::GetMostEfficientPotion(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, RE::TESObjectREFR* container)
    {
        using Flag = RE::EffectSetting::EffectSettingData::Flag;
        if (!a_actor) {
            a_vm->TraceStack("Actor is none", a_stackID);
            return nullptr;
        } else if (!container) {
            a_vm->TraceStack("Container Reference is none", a_stackID);
            return nullptr;
        }
        const auto actorValueOwner = a_actor->AsActorValueOwner();
        const float tmphp = a_actor->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kHealth);
        const float maxhp = actorValueOwner->GetPermanentActorValue(RE::ActorValue::kHealth) + tmphp;
        const float missinghp = maxhp - actorValueOwner->GetActorValue(RE::ActorValue::kHealth);
        RE::AlchemyItem* ret = nullptr;
        float closest = FLT_MAX;
        const auto inventory = container->GetInventory();
        for (const auto& [form, data] : inventory) {
            if (data.first <= 0 || data.second->IsQuestObject() || !form->Is(RE::FormType::AlchemyItem))
                continue;
            const auto potion = form->As<RE::AlchemyItem>();
            if (potion->IsFood())
                continue;

            const float healing = [&potion]() {
                float ret = 0.0f;
                for (auto& e : potion->effects) {
                    const auto base = e->baseEffect;
                    if (!base)
                        continue;

                    const auto& effectdata = base->data;
                    if (effectdata.flags.any(Flag::kDetrimental, Flag::kHostile)) {
                        ret = 0.0f;
                        break;
                    } else if (effectdata.flags.none(Flag::kRecover)) {
                        if (effectdata.primaryAV == RE::ActorValue::kHealth)
                            ret += e->effectItem.magnitude;
                        else if (effectdata.secondaryAV == RE::ActorValue::kHealth)
                            ret += e->effectItem.magnitude * effectdata.secondAVWeight;
                    }
                }
                return ret;
            }();
            if (healing > 0.0f) {
                const auto result = fabs(missinghp - healing);
                if (result < closest) {
                    closest = result;
                    ret = potion;
                }
            }
        }
        return ret;
    }

    std::vector<RE::Actor*> Actor::GetFollowers(RE::StaticFunctionTag*)
    {
        return Acheron::GetFollowers();
    }

    std::string Actor::GetRaceType(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor)
    {
        if (!a_actor) {
            a_vm->TraceStack("Cannot get racetype from a none reference", a_stackID);
            return ""s;
        }
        return Acheron::Animation::GetRaceType(a_actor);
    }

    bool Utility::OpenCustomMenu(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, std::string_view a_filepath)
    {
        if (REL::Module::IsVR()) {
            logger::warn("Custom Menu is not supported in VR Edition");
            return false;
        }
        if (a_filepath.empty()) {
            a_vm->TraceStack("File path to swf file is empty", a_stackID);
            return false;
        } else if (!fs::exists(std::format("Data\\Interface\\{}.swf", a_filepath))) {
            a_vm->TraceStack("File path does not lead to a valid file", a_stackID);
            return false;
        }

        if (Acheron::Interface::CustomMenu::IsOpen()) {
            return false;
        }

        Acheron::Interface::CustomMenu::SetSwfPath(a_filepath);
        Acheron::Interface::CustomMenu::Show();
        return true;
    }

    void Utility::CloseCustomMenu(RE::StaticFunctionTag*)
    {
        if (REL::Module::IsVR()) {
            logger::warn("Custom Menu is not supported in VR Edition");
            return;
        }
        Acheron::Interface::CustomMenu::Hide();
    }

}  // namespace Papyrus
