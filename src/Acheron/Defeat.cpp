#include "Acheron/Defeat.h"

#include "Acheron/EventSink.h"
#include "Acheron/Misc.h"
#include "Acheron/Pacification.h"
#include "Serialization/EventManager.h"
#include "shared/KrisV/Script.h"

namespace Acheron
{
    void Defeat::SetEnemyRelationship(RE::Actor* actor)
    {
        if (REL::Module::IsVR() || !actor || actor->IsPlayerRef() || actor->IsPlayerTeammate() ||
            actor->IsCommandedActor() || !IsNPC(actor) || !actor->IsHostileToActor(RE::PlayerCharacter::GetSingleton())) return;
        // Release deliberately retains personal resentment.
        const auto script = Script::GetScriptObject(actor, "Actor", true);
        if (!script || !Script::DispatchMethodCall(script, "SetRelationshipRank", nullptr,
                RE::PlayerCharacter::GetSingleton(), std::int32_t{ -3 }))
            logger::error("Unable to set enemy relationship for {:08X}", actor->GetFormID());
    }

    std::uint8_t Defeat::CaptureDialogue(RE::Actor* actor)
    {
        const auto talk = actor->extraList.GetByType<RE::ExtraCanTalkToPlayer>();
        return static_cast<std::uint8_t>((talk ? 1 : 0) | (talk && talk->talk ? 2 : 0) |
            (actor->GetActorRuntimeData().boolFlags.any(RE::Actor::BOOL_FLAGS::kCanSpeakToEssentialDown) ? 4 : 0));
    }
    float Defeat::RestoreLegacyAggression(RE::Actor* actor, float amount, float before)
    {
        if (!amount || REL::Module::IsVR()) return 0.0f;
        const auto current = actor->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression);
        if (current == before - amount) {
            actor->AsActorValueOwner()->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression, amount);
        } else if (current != before) {
            logger::warn("Ambiguous legacy aggression ownership for {:08X}; preserving modifier {}", actor->GetFormID(), current);
            return amount;
        }
        return 0.0f;
    }
    void Defeat::RestoreDialogue(RE::Actor* actor, const VictimData& data)
    {
        const auto flags = data.dialogueFlags;
        RestoreLegacyAggression(actor, data.dialogueAggression, data.dialogueAggressionModifierBefore);
        actor->AllowBleedoutDialogue((flags & 4) != 0);
        if (const auto talk = actor->extraList.GetByType<RE::ExtraCanTalkToPlayer>(); talk && talk->talk) {
            if (flags & 1) talk->talk = (flags & 2) != 0;
            else actor->extraList.RemoveByType(RE::ExtraDataType::kCanTalkToPlayer);
        }
    }
    struct PackageOverrideCallback : public RE::BSScript::IStackCallbackFunctor
    {
      public:
        PackageOverrideCallback(RE::Actor* a_actor) :
          _actor(a_actor->GetHandle()) {}
        ~PackageOverrideCallback() = default;

        virtual void operator()(RE::BSScript::Variable) override { _actor.get()->EvaluatePackage(); }
        virtual void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) {}

      private:
        RE::ActorHandle _actor;
    };

    ///
    ///	Defeat
    ///

    void Defeat::DefeatActor(RE::Actor* a_victim)
    {
        if (a_victim->IsPlayerRef()) {
            logger::warn("Player defeat is disabled in this NPC-only build");
            return;
        }
        const auto state = a_victim->AsActorState()->GetLifeState();
        if (state == RE::ACTOR_LIFE_STATE::kDying || state == RE::ACTOR_LIFE_STATE::kDead) {
            logger::error("{:X} ({}) is dead and cannot be defeated", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            return;
        }
        auto data = std::make_shared<VictimData>(RE::Calendar::GetSingleton()->GetDaysPassed());
        {
            std::unique_lock lock{ _m };
            if (!Victims.emplace(a_victim->GetFormID(), data).second) {
                logger::error("{:X} ({}) is already defeated", a_victim->GetFormID(), a_victim->GetDisplayFullName());
                return;
            } else if (auto ref = a_victim->GetObjectReference(); !ref) {
                logger::warn("{:X} ({}) has no associated reference, keywords will NOT be added", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            } else {
                ref->As<RE::BGSKeywordForm>()->AddKeyword(GameForms::Defeated);
            }
        }

        Pacification::End(a_victim->GetFormID());
        SetEnemyRelationship(a_victim);
        data->dialogueFlags = CaptureDialogue(a_victim);
        if (!REL::Module::IsVR()) {
            a_victim->AllowPCDialogue(true);
            a_victim->AllowBleedoutDialogue(true);
            if (!Pacification::EnsureDialogue()) logger::error("Unable to start defeated dialogue quest");
        }
        if (a_victim->IsPlayerRef()) {
            const auto cmap = RE::ControlMap::GetSingleton();
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kActivate, false, true);
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kJumping, false, true);
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kMainFour, false, true);
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kPOVSwitch, false, true);
            a_victim->AddAnimationGraphEventSink(EventHandler::GetSingleton());
            RE::PlayerCamera::GetSingleton()->ForceThirdPerson();

            PacifyUnsafe(a_victim);
        } else {
            if (a_victim->IsPlayerTeammate()) {
                a_victim->AsActorValueOwner()->SetActorValue(RE::ActorValue::kWaitingForPlayer, 1);
            }
            PacifyUnsafe(a_victim);
            Script::CallbackPtr callback(new PackageOverrideCallback(a_victim));
            if (!Script::DispatchStaticCall("ActorUtil", "AddPackageOverride", callback, std::move(a_victim), std::move(GameForms::BlankPackage), std::move(31), std::move(1))) {
                logger::error("Failed to dispatch static call [ActorUtil::AddPackageOverride]. PapyrusUtil missing?");
            }
        }

        a_victim->GetActorRuntimeData().boolFlags.set(RE::Actor::BOOL_FLAGS::kNoBleedoutRecovery);
        const auto& process = a_victim->GetActorRuntimeData().currentProcess;
        if (a_victim->Is3DLoaded()) {
            if (process) {
                process->PlayIdle(a_victim, GameForms::BleedoutStart, nullptr);
            } else {
                a_victim->NotifyAnimationGraph("BleedoutStart");
            }
        }
        const auto middlehigh = process ? process->middleHigh : nullptr;
        if (middlehigh) {
            for (auto& commandedActorData : middlehigh->commandedActors) {
                if (const auto summon = commandedActorData.activeEffect) {
                    summon->Dispel(true);
                }
            }
        }
        const auto health = a_victim->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth);
        if (health > 0.05f) a_victim->AsActorValueOwner()->DamageActorValue(RE::ActorValue::kHealth, health - 0.05f);
        else a_victim->AsActorValueOwner()->RestoreActorValue(RE::ActorValue::kHealth, 0.05f - health);
        data->injuryDamageBaseline = a_victim->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth);

        data->state.store(VictimState::Defeated);

        logger::info("{:X} ({}) has been defeated", a_victim->GetFormID(), a_victim->GetDisplayFullName());
        Serialization::EventManager::GetSingleton()->_actordefeated.QueueEvent(a_victim);
    }

    void Defeat::RescueActor(RE::Actor* a_victim, bool undo_pacify)
    {
        if (auto data = GetVictimData(a_victim->GetFormID()); !data) {
            logger::error("{:X} ({}) is not a defeated actor and cannot be rescued", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            return;
        } else if (auto expected = VictimState::Defeated; !data->state.compare_exchange_strong(expected, VictimState::Rescuing)) {
            switch (expected) {
            case VictimState::Defeating:
                logger::info("{:X} ({}) is still being defeated, delaying rescue", a_victim->GetFormID(), a_victim->GetDisplayFullName());
                {
                    auto victim = a_victim->GetHandle();
                    std::thread{ [victim, undo_pacify]() {
                        std::this_thread::sleep_for(100ms);
                        SKSE::GetTaskInterface()->AddTask([=]() {
                            RescueActor(victim.get().get(), undo_pacify);
                        });
                    } }.detach();
                }
                return;
            case VictimState::Rescuing:
                logger::error("{:X} ({}) is already being rescued", a_victim->GetFormID(), a_victim->GetDisplayFullName());
                return;
            }
        }

        if (a_victim->IsPlayerRef()) {
            auto cmap = RE::ControlMap::GetSingleton();
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kActivate, true, true);
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kJumping, true, true);
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kMainFour, true, true);
            cmap->ToggleControls(RE::UserEvents::USER_EVENT_FLAG::kPOVSwitch, true, true);
            a_victim->RemoveAnimationGraphEventSink(EventHandler::GetSingleton());
        } else {
            if (a_victim->IsPlayerTeammate()) {
                a_victim->AsActorValueOwner()->SetActorValue(RE::ActorValue::kWaitingForPlayer, 0);
            }
            Script::CallbackPtr callback(new PackageOverrideCallback(a_victim));
            if (!Script::DispatchStaticCall("ActorUtil", "RemovePackageOverride", callback, std::move(a_victim), std::move(GameForms::BlankPackage))) {
                logger::error("Unable to dispatch static call [ActorUtil::RemovePackageOverride]. PapyrusUtil missing?");
            }
        }


        if (const auto data = GetVictimData(a_victim->GetFormID()); data && !REL::Module::IsVR()) RestoreDialogue(a_victim, *data);
        a_victim->GetActorRuntimeData().boolFlags.reset(RE::Actor::BOOL_FLAGS::kNoBleedoutRecovery);
        if (a_victim->Is3DLoaded() && !a_victim->IsDead()) {
            if (const auto& process = a_victim->GetActorRuntimeData().currentProcess) {
                process->PlayIdle(a_victim, GameForms::BleedoutStop, a_victim);
            } else {
                a_victim->NotifyAnimationGraph("BleedoutStop");
            }
        }

        if (undo_pacify) {
            UndoPacify(a_victim);
        }

        {
            std::unique_lock lock{ _m };
            if (auto ref = a_victim->GetObjectReference(); !ref) {
                logger::warn("{:X} ({}) has no associated reference, keywords will not be removed", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            } else {
                ref->As<RE::BGSKeywordForm>()->RemoveKeyword(GameForms::Defeated);
            }
            Victims.erase(a_victim->GetFormID());
        }

        logger::info("{:X} ({}) has been rescued", a_victim->GetFormID(), a_victim->GetDisplayFullName());
        Serialization::EventManager::GetSingleton()->_actorrescued.QueueEvent(a_victim);
    }

    void Defeat::RescueDelayed(RE::Actor* a_victim, bool a_undo_pacify)
    {
        RescueActor(a_victim, false);
        if (a_undo_pacify) {
            auto victim = a_victim->GetHandle();
            std::thread([victim]() {
                std::this_thread::sleep_for(4s);
                SKSE::GetTaskInterface()->AddTask([=]() {
                    UndoPacify(victim.get().get());
                });
            }).detach();
        }
    }

    void Defeat::Pacify(RE::Actor* a_victim)
    {
        if (a_victim->IsPlayerRef()) {
            logger::warn("Player pacification is disabled in this NPC-only build");
            return;
        }
        const auto state = a_victim->AsActorState()->GetLifeState();
        if (state == RE::ACTOR_LIFE_STATE::kDying || state == RE::ACTOR_LIFE_STATE::kDead) {
            logger::error("{:X} ({}) is dead and cannot be pacified", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            return;
        } else if (IsPacified(a_victim)) {
            logger::error("{:X} ({}) is already pacified", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            return;
        }
        PacifyUnsafe(a_victim);
    }

    void Defeat::PacifyUnsafe(RE::Actor* a_victim)
    {
        {
            std::unique_lock lock{ _m };
            if (auto ref = a_victim->GetObjectReference(); !ref) {
                logger::warn("{:X} ({}) has no associated reference, keywords will NOT be added", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            } else {
                ref->As<RE::BGSKeywordForm>()->AddKeyword(GameForms::Pacified);
            }
            if (!Pacified.insert(a_victim->GetFormID()).second) {
                return;
            }
        }
        const auto process = RE::ProcessLists::GetSingleton();
        const auto detection = process->runDetection;
        process->runDetection = false;
        process->ClearCachedFactionFightReactions();
        process->StopCombatAndAlarmOnActor(a_victim, false);
        process->runDetection = detection;
        logger::info("{:X} ({}) has been pacified", a_victim->GetFormID(), a_victim->GetDisplayFullName());
    }

    void Defeat::UndoPacify(RE::Actor* a_victim)
    {
        {
            std::unique_lock lock{ _m };
            if (!Pacified.contains(a_victim->GetFormID())) {
                logger::error("{:X} ({}) is not a pacified actor and cannot be released", a_victim->GetFormID(), a_victim->GetDisplayFullName());
                return;
            } else if (auto ref = a_victim->GetObjectReference(); !ref) {
                logger::warn("{:X} ({}) has no associated reference, keywords will not be removed", a_victim->GetFormID(), a_victim->GetDisplayFullName());
            } else {
                ref->As<RE::BGSKeywordForm>()->RemoveKeyword(GameForms::Pacified);
            }
            Pacified.erase(a_victim->GetFormID());
        }
        logger::info("{:X} ({}) has been released", a_victim->GetFormID(), a_victim->GetDisplayFullName());
    }

    bool Defeat::IsDefeated(const RE::Actor* a_victim)
    {
        const auto key = a_victim->GetFormID();
        std::shared_lock lock{ _m };
        return Victims.contains(key) && Pacified.contains(key);
    }

    bool Defeat::IsPacified(const RE::Actor* a_victim)
    {
        std::shared_lock lock{ _m };
        return Pacified.contains(a_victim->GetFormID());
    }

    bool Defeat::IsDamageImmune(RE::Actor* a_victim)
    {
        std::shared_lock lock{ _m };
        return Victims.contains(a_victim->GetFormID());
    }

    ///
    /// Utility
    ///

    std::vector<RE::Actor*> Defeat::GetAllPacified(bool a_loadedonly)
    {
        std::vector<RE::Actor*> ret;
        std::shared_lock lock{ _m };
        return std::accumulate(Pacified.begin(), Pacified.end(), std::vector<RE::Actor*>{}, [&](auto acc, const auto& formId) {
            auto actor = RE::TESForm::LookupByID<RE::Actor>(formId);
            if (actor && (!a_loadedonly || actor->Is3DLoaded())) {
                acc.push_back(actor);
            }
            return acc;
        });
    }

    std::vector<RE::Actor*> Defeat::GetAllDefeated(bool a_loadedonly)
    {
        std::shared_lock lock{ _m };
        return std::accumulate(Victims.begin(), Victims.end(), std::vector<RE::Actor*>{}, [&](auto acc, const auto& pair) {
            auto actor = RE::TESForm::LookupByID<RE::Actor>(pair.first);
            if (actor && (!a_loadedonly || actor->Is3DLoaded())) {
                acc.push_back(actor);
            }
            return acc;
        });
    }

    void Defeat::ForEachVictim(std::function<VictimVistor(RE::FormID a_victimid, std::shared_ptr<VictimData> a_data)> a_visitor)
    {
        std::vector<std::pair<RE::FormID, std::shared_ptr<VictimData>>> v;
        {
            std::shared_lock lock{ _m };
            v.assign(Victims.begin(), Victims.end());
        }
        for (auto& [formid, data] : v) {
            if (a_visitor(formid, data) == VictimVistor::Break)
                break;
        }
    }

    std::shared_ptr<Defeat::VictimData> Defeat::GetVictimData(RE::FormID a_formid)
    {
        std::shared_lock lock{ _m };
        const auto where = Victims.find(a_formid);
        if (where == Victims.end()) {
            return {};
        }
        return where->second;
    }

    void Defeat::DisableRecovery(bool a_loadedonly)
    {
        std::unique_lock lock{ _m };
        for (auto&& [formid, data] : Victims) {
            if (a_loadedonly) {
                auto victim = RE::TESForm::LookupByID<RE::Actor>(formid);
                if (victim && !victim->Is3DLoaded()) {
                    continue;
                }
            }
            data->allow_recovery = false;
        }
    }


    float Defeat::VictimData::GetSecondsDefeated() const
    {
        const auto calendar = RE::Calendar::GetSingleton();
        const auto dayPassed = calendar->GetDaysPassed() - registered_at;
        return dayPassed * 24 * 60 * 60;
    }

    ///
    /// Serialization
    ///

    void Defeat::Load(SKSE::SerializationInterface* a_intfc, uint32_t a_type, uint32_t version)
    {
        std::unique_lock lock{ _m };
        switch (a_type) {
        case Serialization::Serialize::_Defeated:
            {
                Victims.clear();
                std::size_t numRegs;
                a_intfc->ReadRecordData(numRegs);

                RE::FormID formID;
                float time;
                for (size_t i = 0; i < numRegs; i++) {
                    std::uint8_t dialogueFlags{};
                    float aggression{}, aggressionBefore{};
                    std::uint8_t baselineKnown{};
                    float baseline{};
                    if (!a_intfc->ReadRecordData(formID) || !a_intfc->ReadRecordData(time) ||
                        (version >= 2 && (!a_intfc->ReadRecordData(dialogueFlags) || !a_intfc->ReadRecordData(aggression) || !a_intfc->ReadRecordData(aggressionBefore))) ||
                        (version >= 3 && (!a_intfc->ReadRecordData(baselineKnown) || !a_intfc->ReadRecordData(baseline))) ||
                        baselineKnown > 1 || !std::isfinite(baseline) || dialogueFlags > 7 || !std::isfinite(aggression) || std::abs(aggression) > 1000 || !std::isfinite(aggressionBefore) || std::abs(aggressionBefore) > 1000) {
                        logger::error("Invalid defeated dialogue cosave record"); return;
                    }
                    if (!a_intfc->ResolveFormID(formID, formID)) {
                        logger::warn("Error reading formID ({:X})", formID);
                        continue;
                    }
                    auto victim = RE::TESForm::LookupByID<RE::Actor>(formID);
                    if (victim) {
                        if (victim->IsPlayerRef()) {
                            victim->AddAnimationGraphEventSink(EventHandler::GetSingleton());
                        }
                        auto ref = victim->GetObjectReference();
                        if (!ref) {
                            logger::warn("Unable to apply keyword to {:X}, form has no associated referece", victim->GetFormID());
                            return;
                        }
                        ref->As<RE::BGSKeywordForm>()->AddKeyword(GameForms::Defeated);
                    }
                    auto data = std::make_shared<VictimData>(time);
                    if (baselineKnown) data->injuryDamageBaseline = baseline;
                    else if (version < 3 && victim) {
                        // Old saves lack the floor sample; only migration uses the legacy rounding tolerance.
                        const auto health = victim->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth);
                        data->injuryDamageBaseline = victim->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kDamage, RE::ActorValue::kHealth) -
                            (health <= 0.051f ? 0.0f : health);
                    }
                    data->dialogueFlags = version >= 2 ? dialogueFlags : victim ? CaptureDialogue(victim) : 0;
                    data->dialogueAggression = aggression;
                    data->dialogueAggressionModifierBefore = aggressionBefore;
                    if (victim && !REL::Module::IsVR()) {
                        const auto handle = victim->GetHandle();
                        SKSE::GetTaskInterface()->AddTask([handle, data]() {
                            const auto actor = handle.get();
                            if (!actor || GetVictimData(actor->GetFormID()) != data) return;
                            data->dialogueAggression = RestoreLegacyAggression(actor.get(), data->dialogueAggression, data->dialogueAggressionModifierBefore);
                            actor->AllowPCDialogue(true); actor->AllowBleedoutDialogue(true);
                            Pacification::EnsureDialogue();
                        });
                    }
                    data->state.store(VictimState::Defeated);
                    Victims.emplace(formID, data);
                }
                logger::info("Loaded {} Victims from cosave", Victims.size());
            }
            break;
        case Serialization::Serialize::_Pacified:
            {
                Pacified.clear();
                std::size_t numRegs;
                a_intfc->ReadRecordData(numRegs);

                RE::FormID formID;
                for (size_t i = 0; i < numRegs; i++) {
                    a_intfc->ReadRecordData(formID);
                    if (!a_intfc->ResolveFormID(formID, formID)) {
                        logger::warn("Error reading formID ({:X})", formID);
                        continue;
                    }
                    auto victim = RE::TESForm::LookupByID<RE::Actor>(formID);
                    if (victim) {
                        auto ref = victim->GetObjectReference();
                        if (!ref) {
                            logger::warn("Unable to apply keyword to {:X}, form has no associated referece", victim->GetFormID());
                            return;
                        }
                        ref->As<RE::BGSKeywordForm>()->AddKeyword(GameForms::Pacified);
                    }
                    Pacified.insert(formID);
                }
                logger::info("Loaded {} Pacified from cosave", Pacified.size());
            }
            break;
        }
    }

    void Defeat::Save(SKSE::SerializationInterface* a_intfc, uint32_t a_type)
    {
        std::shared_lock lock{ _m };
        switch (a_type) {
        case Serialization::Serialize::_Defeated:
            {
                const std::size_t numRegs = Victims.size();
                if (!a_intfc->WriteRecordData(numRegs)) {
                    logger::error("Failed to save number of regs ({})", numRegs);
                    return;
                }
                for (auto&& [formID, data] : Victims) {
                    if (!a_intfc->WriteRecordData(formID)) {
                        logger::error("Failed to save reg ({:X})", formID);
                        continue;
                    }
                    if (!a_intfc->WriteRecordData(data->registered_at)) {
                        logger::error("Failed to save reg ({})", data->registered_at);
                        continue;
                    }
                    if (!a_intfc->WriteRecordData(data->dialogueFlags) || !a_intfc->WriteRecordData(data->dialogueAggression) ||
                        !a_intfc->WriteRecordData(data->dialogueAggressionModifierBefore)) { logger::error("Failed to save defeated dialogue state"); return; }
                    const std::uint8_t baselineKnown = data->injuryDamageBaseline.has_value();
                    const auto baseline = data->injuryDamageBaseline.value_or(0);
                    if (!a_intfc->WriteRecordData(baselineKnown) || !a_intfc->WriteRecordData(baseline)) {
                        logger::error("Failed to save defeated injury baseline"); return;
                    }
                }
            }
            break;
        case Serialization::Serialize::_Pacified:
            {
                const std::size_t numRegs = Pacified.size();
                if (!a_intfc->WriteRecordData(numRegs)) {
                    logger::error("Failed to save number of regs ({})", numRegs);
                    return;
                }
                for (auto&& formID : Pacified) {
                    if (!a_intfc->WriteRecordData(formID)) {
                        logger::error("Failed to save reg ({:X})", formID);
                        continue;
                    }
                }
            }
            break;
        }
    }

    void Defeat::Revert(SKSE::SerializationInterface*)
    {
        std::unique_lock lock{ _m };
        for (auto&& [formid, data] : Victims) {
            auto actor = RE::TESForm::LookupByID<RE::Actor>(formid);
            if (!actor)
                continue;
            if (!REL::Module::IsVR()) RestoreDialogue(actor, *data);
            if (actor->IsPlayerRef())
                actor->RemoveAnimationGraphEventSink(EventHandler::GetSingleton());
            if (auto ref = actor->GetObjectReference()) {
                ref->As<RE::BGSKeywordForm>()->RemoveKeywords({ GameForms::Defeated, GameForms::Pacified });
            }
        }
        for (auto&& formid : Pacified) {
            if (Victims.contains(formid))
                continue;
            auto actor = RE::TESForm::LookupByID<RE::Actor>(formid);
            if (!actor)
                continue;
            if (auto ref = actor->GetObjectReference()) {
                ref->As<RE::BGSKeywordForm>()->RemoveKeyword(GameForms::Pacified);
            }
        }
        Victims.clear();
        Pacified.clear();
    }

    void Defeat::Delete(RE::FormID a_formid)
    {
        std::unique_lock lock{ _m };
        if (Pacified.erase(a_formid) > 0) {
            Victims.erase(a_formid);
            logger::info("Form {:X} has been deleted and removed from Pacified & Victim lists", a_formid);
        }
    }


}  // namespace Acheron
