#pragma once

namespace Acheron
{
    struct GameForms
    {
#define LOOKUPFORM(form, formid)                                                                                             \
    form = RE::TESDataHandler::GetSingleton()->LookupForm<std::remove_pointer<decltype(form)>::type>(formid, "Acheron.esm"); \
    if (!form) { logger::error("Missing game form {} ({:06X})", #form, formid);                                                  \
        return false; }

        // Vanilla Game
        static inline RE::TESFaction* GuardDiaFac;
        static inline RE::TESGlobal* KillMove;
        static inline RE::TESIdleForm* BleedoutStart;
        static inline RE::TESIdleForm* BleedoutStop;

        // Acheron Forms
        static inline RE::BGSKeyword* Defeated;
        static inline RE::BGSKeyword* Pacified;

        static inline RE::TESQuest* DefaultCommon;
        static inline RE::TESQuest* DefaultGuard;

        static inline RE::SpellItem* HunterPride;
        static inline RE::EffectSetting* HunterPrideEffect;

        static inline RE::TESPackage* BlankPackage;

        static inline RE::TESFaction* IgnoredFaction;

        static inline RE::BGSPerk* InteractionPerk;
        static inline RE::BGSKeyword* PeacefulAnchor;
        static inline RE::BGSKeyword* PeacefulGoal;
        static inline RE::TESPackage* PeacefulAvoid;
        static inline RE::TESPackage* PeacefulWander;
        static inline RE::TESPackage* PeacefulKneel;
        static inline RE::TESPackage* PeacefulKneelBound;
        static inline RE::TESFurniture* PeacefulBoundMarker;
        static inline RE::FormID KneelDialogueInfoID;
        static inline RE::FormID YieldKneelDialogueInfoID;
        static inline RE::FormID BindDialogueInfoID;
        static inline RE::FormID StandDialogueInfoID;
        static inline std::array<RE::FormID, 2> TestRootInfoIDs{};
        static inline std::array<RE::FormID, 9> TestDialogueInfoIDs{};
        static inline std::array<RE::FormID, 4> DefeatedDialogueInfoIDs{};
        static inline RE::TESQuest* MainQuest;
        static inline RE::TESQuest* PeacefulDialogue;
        static inline RE::TESFaction* RescuedWounded;
        static inline RE::TESFaction* KneelingPose;


        [[nodiscard]] static bool LoadForms()
        {
            GuardDiaFac = RE::TESForm::LookupByID<RE::TESFaction>(0x0002BE3B);
            if (!GuardDiaFac)
                return false;

            KillMove = RE::TESForm::LookupByID<RE::TESGlobal>(0x00100F19);
            if (!KillMove)
                return false;

            BleedoutStart = RE::TESForm::LookupByID<RE::TESIdleForm>(0x00013ECC);
            if (!BleedoutStart)
                return false;
            BleedoutStop = RE::TESForm::LookupByID<RE::TESIdleForm>(0x00013ECE);
            if (!BleedoutStop)
                return false;

            LOOKUPFORM(Defeated, 0x801);
            LOOKUPFORM(Pacified, 0x802);

            LOOKUPFORM(DefaultCommon, 0x805);
            LOOKUPFORM(DefaultGuard, 0x809);

            LOOKUPFORM(HunterPride, 0x807);
            LOOKUPFORM(HunterPrideEffect, 0x806);

            LOOKUPFORM(BlankPackage, 0x804);

            LOOKUPFORM(IgnoredFaction, 0x80C);

            LOOKUPFORM(InteractionPerk, 0x803);
            if (!REL::Module::IsVR()) {
                LOOKUPFORM(PeacefulAnchor, 0x811);
                LOOKUPFORM(PeacefulGoal, 0x812);
                LOOKUPFORM(PeacefulAvoid, 0x813);
                LOOKUPFORM(PeacefulWander, 0x814);
                LOOKUPFORM(PeacefulDialogue, 0x818);
                YieldKneelDialogueInfoID = RE::TESDataHandler::GetSingleton()->LookupFormID(0x830, "Acheron.esm");
                if (!YieldKneelDialogueInfoID) return false;
                LOOKUPFORM(MainQuest, 0x800);
                for (std::size_t i = 0; i < DefeatedDialogueInfoIDs.size(); ++i) {
                    DefeatedDialogueInfoIDs[i] = RE::TESDataHandler::GetSingleton()->LookupFormID(static_cast<RE::FormID>(0x826 + i * 3), "Acheron.esm");
                    if (!DefeatedDialogueInfoIDs[i]) return false;
                }
                LOOKUPFORM(RescuedWounded, 0x819);
                LOOKUPFORM(KneelingPose, 0x84D);
                LOOKUPFORM(PeacefulKneel, 0x81A);
                LOOKUPFORM(PeacefulKneelBound, 0x81E);
                LOOKUPFORM(PeacefulBoundMarker, 0x822);
                KneelDialogueInfoID = RE::TESDataHandler::GetSingleton()->LookupFormID(0x81C, "Acheron.esm");
                BindDialogueInfoID = RE::TESDataHandler::GetSingleton()->LookupFormID(0x820, "Acheron.esm");
                StandDialogueInfoID = RE::TESDataHandler::GetSingleton()->LookupFormID(0x833, "Acheron.esm");
                if (!KneelDialogueInfoID || !BindDialogueInfoID || !StandDialogueInfoID) return false;
                for (std::size_t i = 0; i < TestRootInfoIDs.size(); ++i) {
                    TestRootInfoIDs[i] = RE::TESDataHandler::GetSingleton()->LookupFormID(static_cast<RE::FormID>(0x836 + i), "Acheron.esm");
                    if (!TestRootInfoIDs[i]) return false;
                }
                for (std::size_t i = 0; i < TestDialogueInfoIDs.size(); ++i) {
                    TestDialogueInfoIDs[i] = RE::TESDataHandler::GetSingleton()->LookupFormID(static_cast<RE::FormID>(0x839 + 2 * i), "Acheron.esm");
                    if (!TestDialogueInfoIDs[i]) return false;
                }
            }

            return true;
        }
    };

}  // namespace Acheron
