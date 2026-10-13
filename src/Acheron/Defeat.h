#pragma once

#include <shared_mutex>

namespace Acheron
{
    class Defeat
    {
      public:
        enum class VictimVistor
        {
            Continue,
            Break
        };

        enum class VictimState
        {
            Defeating,
            Defeated,
            Rescuing
        };

        struct VictimData
        {
            VictimData(float a_registertime) :
              registered_at(a_registertime) {}
            ~VictimData() = default;

            float GetSecondsDefeated() const;

            float registered_at;              // GameDaysPassed at construction
            bool allow_recovery{ true };      // if this actor may passively recover
            bool mark_for_recovery{ false };  // Rescue this actor the next time they load in?
            std::uint8_t dialogueFlags{};     // Prior extra-talk presence/value and bleedout dialogue flag.
            float dialogueAggression{}, dialogueAggressionModifierBefore{}; // Legacy cosave ownership; new actors never suppress aggression.
            std::atomic<VictimState> state{ VictimState::Defeating };
        };

      public:
        static std::vector<RE::Actor*> GetAllPacified(bool a_loadedonly);
        static std::vector<RE::Actor*> GetAllDefeated(bool a_loadedonly);

        static void ForEachVictim(std::function<VictimVistor(RE::FormID a_victimid, std::shared_ptr<VictimData> a_data)> a_visitor);
        static std::shared_ptr<Defeat::VictimData> GetVictimData(RE::FormID a_formid);
        static void DisableRecovery(bool a_loadedonly);

        static void DefeatActor(RE::Actor* a_victim);
        static void RescueActor(RE::Actor* a_victim, bool undo_pacify);
        static void RescueDelayed(RE::Actor* a_victim, bool undo_pacify);
        static bool IsDefeated(const RE::Actor* a_victim);
        static bool IsDamageImmune(RE::Actor* a_victim);

        static void Pacify(RE::Actor* a_victim);
        static void UndoPacify(RE::Actor* a_victim);
        static bool IsPacified(const RE::Actor* a_victim);
        static void SetEnemyRelationship(RE::Actor* actor);
        static float RestoreLegacyAggression(RE::Actor* actor, float amount, float before);

      public:
        static void Load(SKSE::SerializationInterface* a_intfc, uint32_t a_type, uint32_t version = 1);
        static void Save(SKSE::SerializationInterface* a_intfc, uint32_t a_type);
        static void Revert(SKSE::SerializationInterface* a_intfc);
        static void Delete(RE::FormID a_formid);

      private:
        static void PacifyUnsafe(RE::Actor* a_victim);
        static std::uint8_t CaptureDialogue(RE::Actor* actor);
        static void RestoreDialogue(RE::Actor* actor, const VictimData& data);

      private:
        static inline std::map<RE::FormID, std::shared_ptr<VictimData>> Victims;
        static inline std::set<RE::FormID> Pacified;
        static inline std::shared_mutex _m;
    };

}  // namespace Defeat
