#pragma once

#include "Acheron/Misc.h"
#include "Acheron/Validation.h"
#include "GameForms.h"
#include "shared/KrisV/Util/Console.h"

namespace Papyrus
{
    namespace Status
    {
        inline void DisableProcessing(RE::StaticFunctionTag*, bool a_disable)
        {
            Settings::ProcessingEnabled = !a_disable;
            if (a_disable) {
                auto player = RE::PlayerCharacter::GetSingleton();
                if (player->HasSpell(Acheron::GameForms::HunterPride))
                    player->RemoveSpell(Acheron::GameForms::HunterPride);
            }
        }
        inline void DisableConsequence(RE::StaticFunctionTag*, bool a_disable) { Settings::ConsequenceEnabled = !a_disable; }
        inline bool IsProcessingDisabled(RE::StaticFunctionTag*) { return !Settings::ProcessingEnabled; }
        inline bool IsConsequenceDisabled(RE::StaticFunctionTag*) { return !Settings::ConsequenceEnabled; }
        inline bool IsTeleportAllowed(RE::StaticFunctionTag*) { return Acheron::Validation::AllowTeleport(); }

        inline void Register(VM* a_vm)
        {
            REGISTERFUNC(DisableProcessing, "Acheron");
            REGISTERFUNC(IsProcessingDisabled, "Acheron");
            REGISTERFUNC(DisableConsequence, "Acheron");
            REGISTERFUNC(IsConsequenceDisabled, "Acheron");
            REGISTERFUNC(IsTeleportAllowed, "Acheron");
        }
    }  // namespace Status

    namespace Defeat
    {
        bool BeginPeacefulState(RE::StaticFunctionTag*, RE::Actor*, int);
        bool KneelActor(RE::StaticFunctionTag*, RE::Actor*);
        bool BindActor(RE::StaticFunctionTag*, RE::Actor*);
        bool ResumePeacefulState(RE::StaticFunctionTag*, RE::Actor*);
        bool IsPeacefulState(RE::StaticFunctionTag*, RE::Actor*);
        bool SupportsPeacefulRescue(RE::StaticFunctionTag*, RE::Actor*);
#ifdef ACHERON_YIELD_TESTS
        void ProbePeacefulState(RE::StaticFunctionTag*, RE::Actor*);
        void ProbePeacefulLinks(RE::StaticFunctionTag*, RE::Actor*, RE::TESObjectREFR*, RE::TESObjectREFR*);
#endif
        void DefeatActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor);
        void RescueActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, bool undo_pacify);
        void PacifyActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor);
        void ReleaseActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor);
        bool IsDefeated(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor);
        bool IsPacified(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor);

        std::vector<RE::Actor*> GetDefeated(RE::StaticFunctionTag*, bool a_loadedonly);
        std::vector<RE::Actor*> GetPacified(RE::StaticFunctionTag*, bool a_loadedonly);

        inline void Register(VM* a_vm)
        {
            REGISTERFUNC(BeginPeacefulState, "Acheron");
            REGISTERFUNC(KneelActor, "Acheron");
            REGISTERFUNC(BindActor, "Acheron");
            REGISTERFUNC(ResumePeacefulState, "Acheron");
            REGISTERFUNC(IsPeacefulState, "Acheron");
            REGISTERFUNC(SupportsPeacefulRescue, "Acheron");
#ifdef ACHERON_YIELD_TESTS
            REGISTERFUNC(ProbePeacefulState, "Acheron");
            REGISTERFUNC(ProbePeacefulLinks, "Acheron");
#endif
            REGISTERFUNC(DefeatActor, "Acheron");
            REGISTERFUNC(RescueActor, "Acheron");
            REGISTERFUNC(PacifyActor, "Acheron");
            REGISTERFUNC(ReleaseActor, "Acheron");
            REGISTERFUNC(IsDefeated, "Acheron");
            REGISTERFUNC(IsPacified, "Acheron");

            REGISTERFUNC(GetDefeated, "Acheron");
            REGISTERFUNC(GetPacified, "Acheron");
        }
    }

    namespace ObjectRef
    {
        void SetLinkedRef(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::TESObjectREFR* object, RE::TESObjectREFR* target, RE::BGSKeyword* keyword);
        std::vector<RE::TESForm*> GetItemsByKeywords(
            VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::TESObjectREFR* a_container, std::vector<RE::BGSKeyword*> a_kywds, int32_t a_minvalue, bool a_qstitms);
        void RemoveAllItems(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::TESObjectREFR* a_from, RE::TESObjectREFR* a_to, bool a_excludeworn);

        inline void Register(VM* a_vm)
        {
            REGISTERFUNC(SetLinkedRef, "Acheron");
            REGISTERFUNC(GetItemsByKeywords, "Acheron");
            REGISTERFUNC(RemoveAllItems, "Acheron");
        }
    }

    namespace Actor
    {
        std::vector<RE::TESObjectARMO*> GetWornArmor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, uint32_t ignoredmasks);
        std::vector<RE::TESObjectARMO*> StripActor(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, uint32_t ignoredmasks);
        RE::AlchemyItem* GetMostEfficientPotion(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor, RE::TESObjectREFR* container);
        std::vector<RE::Actor*> GetFollowers(RE::StaticFunctionTag*);
        std::string GetRaceType(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, RE::Actor* a_actor);

        inline void Register(VM* a_vm)
        {
            REGISTERFUNC(GetWornArmor, "Acheron");
            REGISTERFUNC(StripActor, "Acheron");
            REGISTERFUNC(GetMostEfficientPotion, "Acheron");
            REGISTERFUNC(GetFollowers, "Acheron");
            REGISTERFUNC(GetRaceType, "Acheron");
        }
    }

    namespace Utility
    {
        inline void PrintConsole(RE::StaticFunctionTag*, RE::BSFixedString a_msg) { Util::PrintConsole(a_msg.c_str()); }
        bool OpenCustomMenu(VM* a_vm, StackID a_stackID, RE::StaticFunctionTag*, std::string_view a_filepath);
        void CloseCustomMenu(RE::StaticFunctionTag*);
        void ApplyGodPreset(RE::StaticFunctionTag*);

        inline void Register(VM* a_vm)
        {
            REGISTERFUNC(PrintConsole, "Acheron");
            REGISTERFUNC(OpenCustomMenu, "Acheron");
            REGISTERFUNC(CloseCustomMenu, "Acheron");
            REGISTERFUNC(ApplyGodPreset, "Acheron");
        }
    }

    inline bool RegisterFuncs(VM* a_vm)
    {
        Status::Register(a_vm);
        Defeat::Register(a_vm);
        ObjectRef::Register(a_vm);
        Actor::Register(a_vm);
        Utility::Register(a_vm);

        logger::info("Registered Papyrus Functions");
        return true;
    }
}  // namespace Papyrus
