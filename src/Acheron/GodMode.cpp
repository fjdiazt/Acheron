#include "Acheron/GodMode.h"

namespace Acheron::GodMode
{
    void Apply()
    {
        // Apply on the game thread; Papyrus and input share this action.
        SKSE::GetTaskInterface()->AddTask([] {
            if (REL::Module::IsVR()) return;
            auto player = RE::PlayerCharacter::GetSingleton();
            auto data = RE::TESDataHandler::GetSingleton();
            if (!player || !player->Is3DLoaded() || player->IsDead() || !data) return;
            player->SetGodMode(true);
            if (player->GetLevel() < 252) {
                std::unique_ptr<RE::Script> command(RE::IFormFactory::Create<RE::Script>());
                if (!command) return;
                command->SetCommand("player.setlevel 252");
                command->CompileAndRun(player);
            }
            auto values = player->AsActorValueOwner();
            for (int skill = 6; skill <= 23; ++skill) {
                const auto av = static_cast<RE::ActorValue>(skill);
                values->SetBaseActorValue(av, std::max(100.0f, values->GetBaseActorValue(av)));
            }
            for (auto av : {RE::ActorValue::kHealth, RE::ActorValue::kMagicka, RE::ActorValue::kStamina, RE::ActorValue::kCarryWeight}) {
                values->SetBaseActorValue(av, std::max(100000.0f, values->GetBaseActorValue(av)));
                if (av != RE::ActorValue::kCarryWeight) values->RestoreActorValue(av, std::max(0.0f, -player->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kDamage, av)));
            }
            int perks = 0, spells = 0, shouts = 0;
            for (auto perk : data->GetFormArray<RE::BGSPerk>()) {
                if (perk && !perk->IsDeleted() && !perk->IsIgnored() && perk->data.playable && !perk->data.hidden && !player->HasPerk(perk)) {
                    player->AddPerk(perk);
                    ++perks;
                }
            }
            const auto learn = [&](RE::SpellItem* spell) {
                if (spell && !spell->IsDeleted() && !spell->IsIgnored() && !player->HasSpell(spell) && player->AddSpell(spell)) ++spells;
            };
            // Tomes and PC-start flags identify learnable spells across the installed load order.
            for (auto book : data->GetFormArray<RE::TESObjectBOOK>()) {
                if (book && !book->IsDeleted() && !book->IsIgnored() && book->TeachesSpell()) learn(book->GetSpell());
            }
            for (auto spell : data->GetFormArray<RE::SpellItem>()) {
                if (spell && spell->GetSpellType() == RE::MagicSystem::SpellType::kSpell && spell->data.flags.all(RE::SpellItem::SpellFlag::kPCStartSpell)) learn(spell);
            }
            // shortcut: powers/abilities lack a playable flag; reviewed vanilla/DLC catalog only. Review added mods before extending.
            for (auto id : {0xE40D5,0xE40D4,0xE40CF,0xE40CE,0xE40CA,0xE40C8,0xE40C3,0xAA026,0xAA022,0xAA01D,
                            0x17122,0xF1987,0xF1986,0x618C6,0xE732A,0xE7329,0xE5F61,
                            0xAA025,0xAA023,0xAA021,0xAA020,0xAA01F,0xAA01E,0xAA01B,0x104ACF,0x105F16,
                            0xF5FFA,0xCC79A,0x10A766,0xD397F,0xF20BE,0x10EB60}) learn(data->LookupForm<RE::SpellItem>(id, "Skyrim.esm"));
            for (auto id : {0x322B2,0x31844,0x31842,0x29F12,0x1FF21,0x1EEC6,0x1EDA2,0x1EDA0,0x1ED9A,
                            0x1E7F5,0x1E7F3,0x1E7EF,0x34838,0x34837,0x34834,
                            0x1DFAB,0x1DFA7,0x1DFA5,0x1DFA4,0x1DF9F,0x1DF9C}) learn(data->LookupForm<RE::SpellItem>(id, "Dragonborn.esm"));
            const auto unlock = [&](RE::FormID id, const char* plugin) {
                auto shout = data->LookupForm<RE::TESShout>(id, plugin);
                if (!shout || shout->IsDeleted() || shout->IsIgnored()) return;
                if (!player->HasShout(shout) && player->AddShout(shout)) ++shouts;
                for (const auto& variation : shout->variations) {
                    if (variation.word) {
                        std::unique_ptr<RE::Script> command(RE::IFormFactory::Create<RE::Script>());
                        if (!command) continue;
                        command->SetCommand(std::format("teachword {:08X}", variation.word->GetFormID()));
                        command->CompileAndRun(player);
                        player->UnlockWord(variation.word);
                    }
                }
            };
            for (auto id : {0x70981,0x70980,0x7097F,0x7097E,0x7097D,0x7097C,0x7097B,0x2395A,0x5FC77,0x5D16B,
                            0x5196A,0x48AC9,0x46B8C,0x44250,0x3F9EA,0x3CD34,0x32921,0x32920,0x2F7BA,0x13E07}) unlock(id, "Skyrim.esm");
            for (auto id : {0x7CB6,0x30D2,0x8A62}) unlock(id, "Dawnguard.esm");
            for (auto id : {0x2AD09,0x200C0,0x1DF92,0x179D8}) unlock(id, "Dragonborn.esm");
            logger::info("[GodPreset] level={} skills=100 stats=100000 god={} addedPerks={} addedSpells={} addedShouts={}",
                player->GetLevel(), RE::PlayerCharacter::IsGodMode(), perks, spells, shouts);
            RE::SendHUDMessage::ShowHUDMessage("God preset applied: level 252+, skills 100, stats 100,000.");
        });
    }
}
