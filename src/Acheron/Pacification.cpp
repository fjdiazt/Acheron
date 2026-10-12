#include "Acheron/Pacification.h"
#include "Acheron/PacificationState.h"
#include "Acheron/Defeat.h"
#include "Acheron/Misc.h"
#include "shared/KrisV/Script.h"

namespace Acheron::Pacification
{
    bool EnsureDialogue()
    {
        if (!GameForms::PeacefulDialogue || REL::Module::IsVR()) return false;
        if (!GameForms::PeacefulDialogue->IsStopped()) return true;
        const auto script = Script::GetScriptObject(GameForms::PeacefulDialogue, "Quest", true);
        return script && Script::DispatchMethodCall(script, "Start", nullptr);
    }
    namespace
    {
        using Peaceful::Phase;
        struct Record
        {
            RE::ActorHandle actor;
            RE::ObjectRefHandle anchor, goal;
            Peaceful::State state;
            std::uint64_t generation{};
            float aggression{}, aggressionModifierBefore{};
            bool hadTalk{}, talk{}, ready{}, pending{}, requested{}, combat{}, rescued{}, exitingForBind{};
            float applyAge{};
            float encounterAge{ 1.0f };
            std::chrono::steady_clock::time_point realObserved{ std::chrono::steady_clock::now() };
        };
        std::map<RE::FormID, Record> records;
        // Workers only touch this mailbox; Skyrim effects and records belong to the main thread.
        std::mutex mailboxMutex;
        struct Pending { std::uint64_t generation; float delta{}; std::uint32_t frame{}; };
        std::map<RE::FormID, Pending> mailbox;
        bool queued{};
        std::uint64_t generation{};
        std::atomic<std::uint64_t> epoch{};

        void Flush();
        bool Loaded(const RE::Actor* actor)
        {
            const auto cell = actor->GetParentCell();
            return actor->Is3DLoaded() && cell && cell->IsAttached();
        }
        RE::TESPackage* Package(Phase phase)
        {
            switch (phase) {
            case Phase::AvoidingCombat: return GameForms::PeacefulAvoid;
            case Phase::Wandering: return GameForms::PeacefulWander;
            case Phase::Kneeling: return GameForms::PeacefulKneel;
            case Phase::KneelingBound: return GameForms::PeacefulKneelBound;
            }
            return nullptr;
        }
        void Observe(RE::FormID id, std::uint64_t stamp)
        {
            const std::lock_guard lock(mailboxMutex);
            mailbox[id] = { stamp, 0.0f };
        }
        void Destroy(RE::ObjectRefHandle handle)
        {
            if (const auto ref = handle.get()) { ref->Disable(); ref->SetDelete(true); }
        }
        RE::NiPoint3 LocalGoal(RE::TESObjectREFR* anchor, RE::NiPoint3 desired)
        {
            auto selected = anchor->GetPosition();
            auto best = std::numeric_limits<float>::max();
            const auto cell = anchor->GetParentCell();
            const auto meshes = cell ? cell->GetRuntimeData().navMeshes : nullptr;
            if (!meshes) return selected;
            for (const auto& mesh : meshes->navMeshes) {
                if (!mesh || mesh->IsDeleted()) continue;
                for (const auto& triangle : mesh->triangles) {
                    if (triangle.triangleFlags.any(RE::BSNavmeshTriangle::TriangleFlag::kDeleted)) continue;
                    if (triangle.vertices[0] >= mesh->vertices.size() || triangle.vertices[1] >= mesh->vertices.size() || triangle.vertices[2] >= mesh->vertices.size()) continue;
                    const auto a = mesh->vertices[triangle.vertices[0]].location;
                    const auto b = mesh->vertices[triangle.vertices[1]].location;
                    const auto c = mesh->vertices[triangle.vertices[2]].location;
                    // Interior samples leave a margin for the actor capsule; native AI still owns pathfinding.
                    for (const auto point : { (a+b+c)/3.0f, a*0.7f+(b+c)*0.15f, b*0.7f+(a+c)*0.15f, c*0.7f+(a+b)*0.15f }) {
                        if (point.GetDistance(anchor->GetPosition()) > 700.0f || std::abs(point.z-anchor->GetPosition().z) > 128.0f) continue;
                        const auto score = point.GetDistance(desired);
                        if (std::isfinite(score) && score < best) { best = score; selected = point; }
                    }
                }
            }
            return selected;
        }
        bool Encounter(Record& record)
        {
            const auto anchor = record.anchor.get();
            const auto subject = record.actor.get();
            if (!anchor || !subject) return false;
            RE::NiPoint3 threats{};
            unsigned count{};
            const auto visit = [&](RE::Actor* other) {
                if (other != subject.get() && !other->IsDead() && other->IsInCombat() &&
                    other->GetParentCell() == anchor->GetParentCell() &&
                    other->GetPosition().GetDistance(anchor->GetPosition()) <= 1500.0f) {
                    threats += other->GetPosition(); ++count;
                }
                return RE::BSContainer::ForEachResult::kContinue;
            };
            RE::ProcessLists::GetSingleton()->ForEachHighActor(visit);
            visit(RE::PlayerCharacter::GetSingleton());
            if (count && !Peaceful::IsCommandHold(record.state.phase)) {
                if (const auto goal = record.goal.get()) {
                    auto away = anchor->GetPosition() - threats / static_cast<float>(count);
                    away.z = 0;
                    const auto length = away.Length();
                    away = length > 1.0f ? away * (350.0f / length) : RE::NiPoint3{ 0, 350, 0 };
                    goal->SetPosition(LocalGoal(anchor.get(), anchor->GetPosition() + away));
                }
            }
            return count != 0;
        }

        struct EvaluateCallback final : RE::BSScript::IStackCallbackFunctor
        {
            RE::ActorHandle actor;
            std::uint64_t world{ epoch };
            explicit EvaluateCallback(RE::Actor* subject) : actor(subject->GetHandle()) {}
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}
            void operator()(RE::BSScript::Variable) override
            {
                const auto handle = actor; const auto expected = world;
                SKSE::GetTaskInterface()->AddTask([handle, expected]() {
                    if (expected == epoch) if (const auto subject = handle.get()) subject->EvaluatePackage();
                });
            }
        };

        struct PackageCallback final : RE::BSScript::IStackCallbackFunctor
        {
            RE::ActorHandle actor;
            RE::FormID id;
            std::uint64_t stamp;
            Phase phase;
            std::uint64_t world{ epoch };
            PackageCallback(const Record& record) : actor(record.actor), id(record.actor.get()->GetFormID()), stamp(record.generation), phase(record.state.phase) {}
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}
            void operator()(RE::BSScript::Variable) override
            {
                const auto handle = actor; const auto key = id; const auto version = stamp; const auto desired = phase; const auto expected = world;
                logger::info("[PeacefulPackage] actor={:08X} generation={} stage=add-complete", key, version);
                SKSE::GetTaskInterface()->AddTask([handle, key, version, desired, expected]() {
                    if (expected != epoch) return;
                    const auto subject = handle.get();
                    if (!subject) return;
                    const auto found = records.find(key);
                    if (found == records.end() || found->second.generation != version || found->second.state.phase != desired) {
                        // An already dispatched add cannot be cancelled; remove it unless a new owner uses it.
                        if (found == records.end() || found->second.state.phase != desired)
                            Script::DispatchStaticCall("ActorUtil", "RemovePackageOverride", nullptr, subject.get(), Package(desired));
                        return;
                    }
                    if (subject->IsDead() || Defeat::IsDefeated(subject.get())) { End(key); return; }
                    subject->EvaluatePackage();
                    found->second.pending = false;
                });
            }
        };

        struct RemovePhaseCallback final : RE::BSScript::IStackCallbackFunctor
        {
            RE::FormID id;
            std::uint64_t stamp;
            unsigned next{};
            std::uint64_t world{ epoch };
            RemovePhaseCallback(RE::FormID key, std::uint64_t version, unsigned index = 0) : id(key), stamp(version), next(index) {}
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}
            void operator()(RE::BSScript::Variable) override
            {
                const auto key = id; const auto version = stamp; const auto expected = world; const auto index = next;
                logger::info("[PeacefulPackage] actor={:08X} generation={} stage=remove-complete", key, version);
                SKSE::GetTaskInterface()->AddTask([key, version, expected, index]() {
                    if (expected != epoch) return;
                    const auto found = records.find(key);
                    if (found == records.end() || found->second.generation != version) return;
                    const auto actor = found->second.actor.get();
                    if (!actor || !IsEligible(actor.get()) || Defeat::IsDefeated(actor.get())) { End(key); return; }
                    const std::array phases{ Phase::AvoidingCombat, Phase::Wandering, Phase::Kneeling, Phase::KneelingBound };
                    for (auto i = index; i < phases.size(); ++i) {
                        if (phases[i] == found->second.state.phase) continue;
                        Script::CallbackPtr callback(new RemovePhaseCallback(key, version, i + 1));
                        if (!Script::DispatchStaticCall("ActorUtil", "RemovePackageOverride", callback, actor.get(), Package(phases[i]))) End(key);
                        return;
                    }
                    Script::CallbackPtr callback(new PackageCallback(found->second));
                    if (!Script::DispatchStaticCall("ActorUtil", "AddPackageOverride", callback, actor.get(), Package(found->second.state.phase), 31, 1)) End(key);
                });
            }
        };

        bool Apply(Record& record, Phase phase)
        {
            const auto actor = record.actor.get();
            if (!actor) return false;
            record.state.phase = phase;
            if (record.rescued) {
                if (Peaceful::IsCommandHold(phase)) actor->RemoveFromFaction(GameForms::RescuedWounded);
                else actor->AddToFaction(GameForms::RescuedWounded, 0);
            }
            record.generation = ++generation;
            record.ready = false;
            record.pending = true;
            record.requested = true;
            record.applyAge = 0;
            Observe(actor->GetFormID(), record.generation);
            // Remove only our other phases, in order, before adding the requested package.
            Script::CallbackPtr callback(new RemovePhaseCallback(actor->GetFormID(), record.generation));
            (*callback)(RE::BSScript::Variable{});
            return true;
        }
        void Flush()
        {
            std::vector<std::pair<RE::FormID, Pending>> work;
            {
                const std::lock_guard lock(mailboxMutex);
                for (auto& [id, pending] : mailbox) {
                    if (pending.delta > 0) { work.emplace_back(id, pending); pending.delta = 0; }
                }
                queued = false;
            }
            for (const auto& [id, pending] : work) {
                const auto found = records.find(id);
                if (found == records.end() || found->second.generation != pending.generation) continue;
                auto& record = found->second;
                const auto actor = record.actor.get();
                if (!actor) { End(id); continue; }
                if ((!record.ready || GameForms::PeacefulDialogue->IsStopped()) && Loaded(actor.get()) && !RE::UI::GetSingleton()->GameIsPaused()) {
                    record.applyAge += pending.delta;
                    if (record.applyAge >= (Peaceful::IsCommandHold(record.state.phase) ? 15.0f : 5.0f)) { logger::warn("Peaceful package/dialogue did not become ready for {:08X}", id); End(id); continue; }
                }
                if (record.exitingForBind) {
                    if (!IsEligible(actor.get()) || Defeat::IsDefeated(actor.get())) { End(id); continue; }
                    if (Loaded(actor.get()) && !RE::UI::GetSingleton()->GameIsPaused() && actor->AsActorState()->GetSitSleepState() == RE::SIT_SLEEP_STATE::kNormal) RequestKneel(actor.get(), true);
                    continue;
                }
                if (!record.ready && !record.pending && actor->Is3DLoaded()) {
                    if (!record.requested) { if (!Apply(record, record.state.phase)) End(id); continue; }
                    if (actor->GetCurrentPackage() == Package(record.state.phase)) {
                        if (record.state.phase == Phase::KneelingBound) {
                            // Enter working kneel furniture first; the bound pose is a native graph event.
                            if (actor->AsActorState()->GetSitSleepState() != RE::SIT_SLEEP_STATE::kIsSitting) continue;
                            if (!actor->NotifyAnimationGraph("IdleBoundKneesEnterInstant")) { End(id); continue; }
                        }
                        record.ready = true;
                        logger::info("[PeacefulState] actor={:08X} phase={} remaining={} generation={} tickMs={}", id,
                            static_cast<unsigned>(record.state.phase), record.state.remaining, record.generation,
                            std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count());
                    } else {
                        continue;
                    }
                }
                Peaceful::Facts facts;
                facts.alive = !actor->IsDead(); facts.eligible = IsEligible(actor.get());
                facts.defeated = Defeat::IsDefeated(actor.get()); facts.loaded = Loaded(actor.get());
                facts.paused = RE::UI::GetSingleton()->GameIsPaused() || !record.ready;
                const auto topicManager = RE::MenuTopicManager::GetSingleton();
                facts.dialogue = topicManager && topicManager->menuOpen && topicManager->speaker.get().get() == actor.get();
                facts.delta = pending.delta;
                const auto now = std::chrono::steady_clock::now();
                facts.realDelta = std::chrono::duration<float>(now - record.realObserved).count();
                record.realObserved = now;
                if (facts.loaded && !facts.paused) {
                    record.encounterAge += pending.delta;
                    if (record.encounterAge >= 1.0f) { record.combat = Encounter(record); record.encounterAge = 0; }
                }
                facts.nearbyCombat = record.combat;
                const auto next = Peaceful::Decide(record.state, {}, facts);
                if (!next) {
                    // A valid lifecycle plus Observe can exit only through expiry; preserve its resolved time for evidence.
                    if (Peaceful::CanRemainManaged(facts) && Peaceful::ValidState(record.state)) record.state.remaining = 0;
                    End(id); continue;
                }
                if (next->phase != record.state.phase) {
                    if (Peaceful::IsCommandHold(record.state.phase)) actor->NotifyAnimationGraph("IdleChairExitStart");
                    record.state.remaining = next->remaining;
                    record.state.commandHoldRemaining = next->commandHoldRemaining;
                    if (!Apply(record, next->phase)) End(id);
                } else record.state = *next;
            }
        }
    }

    bool IsEligible(const RE::Actor* actor)
    {
        return actor && !actor->IsPlayerRef() && !actor->IsPlayerTeammate() && !actor->IsCommandedActor() &&
            !actor->IsDead() && IsNPC(actor) && !actor->GetCurrentScene();
    }
    bool IsActive(const RE::Actor* actor)
    {
        if (!actor) return false;
        const std::lock_guard lock(mailboxMutex);
        const auto found = mailbox.find(actor->GetFormID());
        return found != mailbox.end() && found->second.generation != 0;
    }
    bool Begin(RE::Actor* actor, int seconds, bool rescued)
    {
        if (REL::Module::IsVR() || !IsEligible(actor) || !Loaded(actor) || Defeat::IsDefeated(actor) ||
            !Peaceful::ValidDuration(static_cast<float>(seconds)) || !GameForms::PeacefulAvoid || !GameForms::PeacefulWander || !GameForms::PeacefulKneel || !GameForms::PeacefulKneelBound || !GameForms::PeacefulDialogue) return false;
        const auto id = actor->GetFormID();
        if (auto found = records.find(id); found != records.end()) {
            auto& record = found->second;
            if (rescued) {
                record.rescued = true;
                if (!Peaceful::IsCommandHold(record.state.phase)) actor->AddToFaction(GameForms::RescuedWounded, 0);
            }
            Peaceful::Facts facts;
            record.combat = facts.nearbyCombat = Encounter(record);
            const auto next = Peaceful::Decide(record.state, { Peaceful::EventKind::Refresh, static_cast<float>(seconds) }, facts);
            if (!next) { End(id); return false; }
            const bool change = !record.ready || next->phase != record.state.phase;
            record.state.remaining = next->remaining;
            if (change) return Apply(record, next->phase);
            record.generation = ++generation;
            Observe(id, record.generation);
            return true;
        }
        if (Defeat::IsPacified(actor) || actor->GetLinkedRef(GameForms::PeacefulAnchor) || actor->GetLinkedRef(GameForms::PeacefulGoal)) return false;
        Record record;
        record.actor = actor->GetHandle(); record.state = { Phase::Wandering, static_cast<float>(seconds) };
        const auto marker = RE::TESForm::LookupByID<RE::TESBoundObject>(0x3B);
        if (!marker) return false;
        const auto anchor = actor->PlaceObjectAtMe(marker, true);
        const auto goal = actor->PlaceObjectAtMe(marker, true);
        if (!anchor || !goal) {
            if (anchor) Destroy(anchor->GetHandle()); if (goal) Destroy(goal->GetHandle()); return false;
        }
        record.anchor = anchor->GetHandle(); record.goal = goal->GetHandle();
        const auto talk = actor->extraList.GetByType<RE::ExtraCanTalkToPlayer>();
        record.hadTalk = talk != nullptr; record.talk = talk && talk->talk;
        record.aggression = actor->AsActorValueOwner()->GetActorValue(RE::ActorValue::kAggression);
        record.aggressionModifierBefore = actor->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression);
        actor->AsActorValueOwner()->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression, -record.aggression);
        actor->AllowPCDialogue(true);
        actor->extraList.SetLinkedRef(anchor.get(), GameForms::PeacefulAnchor);
        actor->extraList.SetLinkedRef(goal.get(), GameForms::PeacefulGoal);
        Defeat::Pacify(actor);
        record.combat = Encounter(record);
        record.state.phase = record.combat ? Phase::AvoidingCombat : Phase::Wandering;
        records.emplace(id, record);
        if (rescued) {
            records.at(id).rescued = true;
            actor->AddToFaction(GameForms::RescuedWounded, 0);
        }
        if (!EnsureDialogue()) { End(id); return false; }
        if (!Apply(records.at(id), record.state.phase)) { End(id); return false; }
        return true;
    }
    void RequestBegin(RE::Actor* actor, int seconds)
    {
        const auto handle = actor->GetHandle(); const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([handle, seconds, world]() {
            if (world != epoch) return;
            if (const auto subject = handle.get(); subject && !Begin(subject.get(), seconds))
                logger::warn("Peaceful request rejected for {:08X}", subject->GetFormID());
        });
    }
    void RequestKneel(RE::Actor* actor, bool bind)
    {
        const auto handle = actor->GetHandle(); const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([handle, world, bind]() {
            if (world != epoch || REL::Module::IsVR()) return;
            const auto subject = handle.get();
            if (!subject || !IsEligible(subject.get()) || !Loaded(subject.get())) return;
            if (bind) {
                const auto owner = records.find(subject->GetFormID());
                if (owner == records.end() || owner->second.state.phase != Phase::Kneeling) return;
            }
            if (Defeat::IsDefeated(subject.get())) {
                Defeat::RescueActor(subject.get(), false);
                if (Defeat::IsDefeated(subject.get())) return;
                Defeat::UndoPacify(subject.get());
                if (!Begin(subject.get(), std::clamp(Settings::iPeacefulWanderDuration, 1, 600))) return;
            }
            const auto found = records.find(subject->GetFormID());
            if (found == records.end() || (!bind && Peaceful::IsCommandHold(found->second.state.phase))) return;
            auto& record = found->second;
            if (bind && !record.exitingForBind) {
                // Finish the old furniture exit before replacing its marker and starting another pose.
                record.exitingForBind = true;
                record.ready = false;
                record.applyAge = 0;
                subject->NotifyAnimationGraph("IdleChairExitStart");
                Script::CallbackPtr callback(new EvaluateCallback(subject.get()));
                if (!Script::DispatchStaticCall("ActorUtil", "RemovePackageOverride", callback, subject.get(), Package(Phase::Kneeling))) End(subject->GetFormID());
                return;
            }
            if (bind && subject->AsActorState()->GetSitSleepState() != RE::SIT_SLEEP_STATE::kNormal) return;
            // Native BoundCaptiveMarker does not enter under SitTarget; use working kneel geometry.
            const auto marker = bind ? GameForms::PeacefulBoundMarker : RE::TESForm::LookupByID<RE::TESFurniture>(0xE8E4E);
            const auto point = marker ? subject->PlaceObjectAtMe(marker, true) : nullptr;
            if (!point) return;
            record.exitingForBind = false;
            point->SetAngle(subject->GetAngle());
            const auto old = record.goal;
            record.goal = point->GetHandle();
            subject->extraList.SetLinkedRef(point.get(), GameForms::PeacefulGoal);
            Destroy(old);
            Peaceful::Facts facts;
            const auto next = Peaceful::Decide(record.state, { bind ? Peaceful::EventKind::Bind : Peaceful::EventKind::Kneel }, facts);
            if (!next) { End(subject->GetFormID()); return; }
            record.state.commandHoldRemaining = next->commandHoldRemaining;
            record.realObserved = std::chrono::steady_clock::now();
            if (!Apply(record, next->phase)) End(subject->GetFormID());
        });
    }
    void RequestResume(RE::Actor* actor)
    {
        const auto handle = actor->GetHandle(); const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([handle, world]() {
            if (world != epoch) return;
            const auto subject = handle.get(); if (!subject) return;
            const auto found = records.find(subject->GetFormID());
            if (found == records.end() || !Peaceful::IsCommandHold(found->second.state.phase)) return;
            found->second.exitingForBind = false;
            Peaceful::Facts facts;
            found->second.combat = facts.nearbyCombat = Encounter(found->second);
            const auto next = Peaceful::Decide(found->second.state, { Peaceful::EventKind::Resume }, facts);
            subject->NotifyAnimationGraph("IdleChairExitStart");
            if (!next) { End(subject->GetFormID()); return; }
            found->second.state.commandHoldRemaining = next->commandHoldRemaining;
            if (!Apply(found->second, next->phase)) End(subject->GetFormID());
        });
    }
    void End(RE::FormID id, bool reset)
    {
        const auto found = records.find(id);
        { const std::lock_guard lock(mailboxMutex); mailbox.erase(id); }
        if (found == records.end()) return;
        const auto record = found->second;
        records.erase(found);
        if (const auto actor = record.actor.get()) {
            if (record.rescued) actor->RemoveFromFaction(GameForms::RescuedWounded);
            if (Peaceful::IsCommandHold(record.state.phase)) actor->NotifyAnimationGraph("IdleChairExitStart");
            for (const auto phase : { Phase::AvoidingCombat, Phase::Wandering, Phase::Kneeling, Phase::KneelingBound }) {
                Script::CallbackPtr callback(new EvaluateCallback(actor.get()));
                Script::DispatchStaticCall("ActorUtil", "RemovePackageOverride", callback, actor.get(), Package(phase));
            }
            if (actor->GetLinkedRef(GameForms::PeacefulAnchor) == record.anchor.get().get()) actor->extraList.SetLinkedRef(nullptr, GameForms::PeacefulAnchor);
            if (actor->GetLinkedRef(GameForms::PeacefulGoal) == record.goal.get().get()) actor->extraList.SetLinkedRef(nullptr, GameForms::PeacefulGoal);
            if (!reset) actor->AsActorValueOwner()->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression, record.aggression);
            if (const auto talk = actor->extraList.GetByType<RE::ExtraCanTalkToPlayer>(); talk && talk->talk) {
                if (record.hadTalk) talk->talk = record.talk;
                else actor->extraList.RemoveByType(RE::ExtraDataType::kCanTalkToPlayer);
            }
            if (!Defeat::IsDefeated(actor.get()) && Defeat::IsPacified(actor.get())) Defeat::UndoPacify(actor.get());
            actor->EvaluatePackage();
        }
        Destroy(record.anchor); Destroy(record.goal);
        logger::info("[PeacefulState] actor={:08X} phase=0 remaining={} generation={} tickMs={}", id, record.state.remaining, record.generation,
            std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count());
    }
    void RequestEnd(RE::FormID id, bool reset)
    {
        const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([id, reset, world]() { if (world == epoch) End(id, reset); });
    }
    void RequestRelease(RE::Actor* actor)
    {
        const auto handle = actor->GetHandle(); const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([handle, world]() {
            if (world != epoch) return;
            if (const auto subject = handle.get()) {
                if (IsActive(subject.get())) End(subject->GetFormID());
                else Defeat::UndoPacify(subject.get());
            }
        });
    }
#ifdef ACHERON_YIELD_TESTS
    void Trace(RE::Actor* actor)
    {
        if (!actor) return;
        const auto handle = actor->GetHandle(); const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([handle, world]() {
            if (world != epoch) return;
            const auto subject = handle.get(); if (!subject) return;
            const auto manager = RE::MenuTopicManager::GetSingleton();
            const auto menu = RE::UI::GetSingleton()->GetMenu(RE::DialogueMenu::MENU_NAME);
            const auto speaker = manager ? manager->speaker.get() : nullptr;
            const auto crosshair = RE::CrosshairPickData::GetSingleton();
            const auto pick = crosshair ? crosshair->GetActiveTarget().get() : nullptr;
            const auto selected = manager ? manager->lastSelectedDialogue : nullptr;
            const auto data = RE::TESDataHandler::GetSingleton();
            const auto topic = data->LookupForm<RE::TESTopic>(0x816, "Acheron.esm");
            const auto info = data->LookupForm<RE::TESTopicInfo>(0x817, "Acheron.esm");
            json dialogue{
                { "actor", std::format("0x{:08X}", subject->GetFormID()) },
                { "speaker", std::format("0x{:08X}", speaker ? speaker->GetFormID() : 0) },
                { "crosshair", std::format("0x{:08X}", pick ? pick->GetFormID() : 0) },
                { "selectedInfo", std::format("0x{:08X}", selected && selected->parentTopicInfo ? selected->parentTopicInfo->GetFormID() : 0) },
                { "selectedTopic", std::format("0x{:08X}", selected && selected->parentTopic ? selected->parentTopic->GetFormID() : 0) },
                { "menuOpen", manager && manager->menuOpen },
                { "greeting", manager && manager->isGreetingPlayer },
                { "speaking", manager && manager->currentTopicInfo },
                { "questStopped", GameForms::PeacefulDialogue->IsStopped() },
                { "canTalk", subject->CanTalkToPlayer() },
                { "infos", topic ? topic->numTopicInfos : 0 },
                { "infoValid", info && info->objConditions.IsTrue(subject.get(), RE::PlayerCharacter::GetSingleton()) },
                { "inCombat", subject->IsInCombat() },
                { "weaponDrawn", subject->IsWeaponDrawn() },
                { "activationBlocked", subject->IsActivationBlocked() },
                { "goodbye", manager && manager->forceGoodbye },
                { "choices", json::array() }
            };
            if (menu && menu->uiMovie) {
                for (const auto& [key, path] : std::initializer_list<std::pair<const char*, const char*>>{
                    { "visible", "_root.DialogueMenu_mc.TopicListHolder._visible" },
                    { "fadedIn", "_root.DialogueMenu_mc.bFadedIn" },
                    { "menuState", "_root.DialogueMenu_mc.eMenuState" },
                    { "allowProgress", "_root.DialogueMenu_mc.bAllowProgress" },
                    { "selectedIndex", "_root.DialogueMenu_mc.TopicListHolder.List_mc.selectedIndex" } }) {
                    RE::GFxValue value;
                    if (menu->uiMovie->GetVariable(&value, path)) {
                        if (value.IsBool()) dialogue[key] = value.GetBool();
                        else if (value.IsNumber()) dialogue[key] = value.GetNumber();
                    }
                }
                RE::GFxValue choices;
                if (menu->uiMovie->GetVariable(&choices, "_root.DialogueMenu_mc.TopicListHolder.List_mc.entryList") && choices.IsArray() && choices.GetArraySize() <= 256) {
                    for (std::uint32_t row = 0; row < choices.GetArraySize(); ++row) {
                        RE::GFxValue entry, text, index;
                        if (choices.GetElement(row, &entry) && entry.GetMember("text", &text) && text.IsString() &&
                            entry.GetMember("topicIndex", &index) && index.IsNumber()) {
                            dialogue["choices"].push_back({ { "row", row }, { "topicIndex", index.GetNumber() }, { "text", text.GetString() } });
                        }
                    }
                }
            }
            logger::info("[PeacefulDialogue] {}", dialogue.dump());
            const auto found = records.find(subject->GetFormID()); if (found == records.end()) return;
            const auto& record = found->second;
            const auto anchor = record.anchor.get(), goal = record.goal.get();
            logger::info("[PeacefulSnapshot] actor={:08X} phase={} remaining={} generation={} anchor={:08X} goal={:08X} ready={} loaded={} commandHoldRemaining={}", subject->GetFormID(), static_cast<unsigned>(record.state.phase), record.state.remaining, record.generation, anchor ? anchor->GetFormID() : 0, goal ? goal->GetFormID() : 0, record.ready, Loaded(subject.get()), record.state.commandHoldRemaining);
        });
    }
#endif
    void Update(RE::Actor* actor, float delta)
    {
        if (!actor || !std::isfinite(delta) || delta <= 0 || !Loaded(actor) || RE::UI::GetSingleton()->GameIsPaused()) return;
        const std::lock_guard lock(mailboxMutex);
        if (const auto found = mailbox.find(actor->GetFormID()); found != mailbox.end()) {
            const auto frame = RE::BSTimer::GetSingleton()->runTimeMS;
            if (found->second.frame == frame) return;
            found->second.frame = frame;
            found->second.delta += delta;
            if (!queued) { queued = true; SKSE::GetTaskInterface()->AddTask(Flush); }
        }
    }
    void ObserveHealing(RE::Actor* actor, float before)
    {
        if (REL::Module::IsVR() || !IsEligible(actor) || !Defeat::IsDefeated(actor)) return;
        const auto handle = actor->GetHandle();
        const auto victim = Defeat::GetVictimData(actor->GetFormID());
        const auto world = epoch.load();
        SKSE::GetTaskInterface()->AddTask([handle, victim, before, world]() {
            if (world != epoch) return;
            const auto subject = handle.get();
            if (!subject || !IsEligible(subject.get()) || Defeat::GetVictimData(subject->GetFormID()) != victim) return;
            if (!Defeat::IsDefeated(subject.get()) || subject->IsDead()) return;
            logger::info("[PeacefulHealing] actor={:08X} before={} after={}", subject->GetFormID(), before,
                subject->AsActorValueOwner()->GetActorValue(RE::ActorValue::kHealth));
            Defeat::RescueActor(subject.get(), false);
            if (!Defeat::IsDefeated(subject.get())) {
                Defeat::UndoPacify(subject.get());
                Begin(subject.get(), std::clamp(Settings::iPeacefulWanderDuration, 1, 600), true);
            }
        });
    }

    void Save(SKSE::SerializationInterface* stream)
    {
        const auto count = static_cast<std::uint32_t>(records.size());
        if (!stream->WriteRecordData(count)) { logger::error("Unable to save peaceful count"); return; }
        for (const auto& [id, record] : records) {
            const auto anchor = record.anchor.get(), goal = record.goal.get();
            const RE::FormID anchorId = anchor ? anchor->GetFormID() : 0, goalId = goal ? goal->GetFormID() : 0;
            const auto phase = static_cast<std::uint8_t>(record.state.phase);
            const std::uint8_t talk = static_cast<std::uint8_t>((record.hadTalk ? 1 : 0) | (record.talk ? 2 : 0) | (record.rescued ? 4 : 0));
            const auto commandHoldRemaining = Peaceful::IsCommandHold(record.state.phase) ? std::max(0.0f,
                record.state.commandHoldRemaining - std::chrono::duration<float>(std::chrono::steady_clock::now() - record.realObserved).count()) : 0.0f;
            if (!stream->WriteRecordData(id) || !stream->WriteRecordData(anchorId) || !stream->WriteRecordData(goalId) ||
                !stream->WriteRecordData(phase) || !stream->WriteRecordData(record.state.remaining) ||
                !stream->WriteRecordData(record.aggression) || !stream->WriteRecordData(record.aggressionModifierBefore) || !stream->WriteRecordData(talk) ||
                !stream->WriteRecordData(commandHoldRemaining)) {
                logger::error("Unable to save peaceful actor {:08X}", id); return;
            }
        }
    }
    void Load(SKSE::SerializationInterface* stream, std::uint32_t version)
    {
        std::uint32_t count{};
        if (!stream->ReadRecordData(count) || count > 4096) { logger::error("Invalid peaceful record count"); return; }
        for (std::uint32_t index = 0; index < count; ++index) {
            RE::FormID id{}, anchorId{}, goalId{}; std::uint8_t phase{}, talk{}; Record record;
            if (!stream->ReadRecordData(id) || !stream->ReadRecordData(anchorId) || !stream->ReadRecordData(goalId) ||
                !stream->ReadRecordData(phase) || !stream->ReadRecordData(record.state.remaining) ||
                !stream->ReadRecordData(record.aggression) || !stream->ReadRecordData(record.aggressionModifierBefore) || !stream->ReadRecordData(talk) ||
                (version >= 2 && !stream->ReadRecordData(record.state.commandHoldRemaining))) {
                logger::error("Truncated peaceful record"); return;
            }
            record.state.phase = static_cast<Phase>(phase);
            if (!Peaceful::ValidState(record.state) || !std::isfinite(record.aggression) || std::abs(record.aggression) > 1000 ||
                !std::isfinite(record.aggressionModifierBefore) || std::abs(record.aggressionModifierBefore) > 1000 || talk > 7) {
                logger::warn("Invalid peaceful state for {:08X}", id); continue;
            }
            RE::FormID resolved{}, resolvedAnchor{}, resolvedGoal{};
            stream->ResolveFormID(id, resolved);
            stream->ResolveFormID(anchorId, resolvedAnchor);
            stream->ResolveFormID(goalId, resolvedGoal);
            const auto actor = RE::TESForm::LookupByID<RE::Actor>(resolved);
            const auto anchor = RE::TESForm::LookupByID<RE::TESObjectREFR>(resolvedAnchor);
            const auto goal = RE::TESForm::LookupByID<RE::TESObjectREFR>(resolvedGoal);
            const auto marker = [](RE::TESObjectREFR* ref) { return ref && ref->GetBaseObject() && ref->GetBaseObject()->GetFormID() == 0x3B; };
            const auto destinationMarker = [marker](RE::TESObjectREFR* ref) { return marker(ref) ||
                (ref && ref->GetBaseObject() && (ref->GetBaseObject()->GetFormID() == 0xE8E4E || ref->GetBaseObject() == GameForms::PeacefulBoundMarker)); };
            if (!actor) {
                // No actor remains to release; only typed markers from this record may be discarded.
                const auto point = marker(anchor) ? anchor->GetHandle() : RE::ObjectRefHandle{};
                const auto destination = destinationMarker(goal) ? goal->GetHandle() : RE::ObjectRefHandle{};
                const auto world = epoch.load();
                SKSE::GetTaskInterface()->AddTask([point, destination, world]() { if (world == epoch) { Destroy(point); Destroy(destination); } });
                logger::warn("Missing peaceful actor {:08X}", id); continue;
            }
            record.actor = actor->GetHandle();
            if (marker(anchor)) record.anchor = anchor->GetHandle();
            if (destinationMarker(goal) && goal != anchor) record.goal = goal->GetHandle();
            record.hadTalk = (talk & 1) != 0; record.talk = (talk & 2) != 0; record.rescued = (talk & 4) != 0; record.generation = ++generation;
            records.try_emplace(resolved, record);
        }
    }
    void Reconcile()
    {
        const auto version = epoch.load();
        SKSE::GetTaskInterface()->AddTask([version]() {
            if (version != epoch || REL::Module::IsVR()) return;
            std::vector<RE::FormID> invalid;
            for (auto& [id, record] : records) {
                const auto actor = record.actor.get();
                if (!actor || !record.anchor.get() || !record.goal.get() || !IsEligible(actor.get()) || Defeat::IsDefeated(actor.get()) ||
                    actor->GetLinkedRef(GameForms::PeacefulAnchor) != record.anchor.get().get() ||
                    actor->GetLinkedRef(GameForms::PeacefulGoal) != record.goal.get().get()) { invalid.push_back(id); continue; }
                if (!Defeat::IsPacified(actor.get())) Defeat::Pacify(actor.get());
                if (record.rescued) actor->AddToFaction(GameForms::RescuedWounded, 0);
                if (actor->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression) == record.aggressionModifierBefore)
                    actor->AsActorValueOwner()->ModActorValue(RE::ACTOR_VALUE_MODIFIER::kTemporary, RE::ActorValue::kAggression, -record.aggression);
                Observe(id, record.generation);
                if (actor->Is3DLoaded()) {
                    record.combat = Encounter(record);
                    if (!Apply(record, Peaceful::IsCommandHold(record.state.phase) ? record.state.phase :
                        (record.combat ? Phase::AvoidingCombat : Phase::Wandering))) invalid.push_back(id);
                }
            }
            for (const auto id : invalid) End(id);
            if (!records.empty() && !EnsureDialogue()) {
                for (const auto& [id, record] : records) invalid.push_back(id);
                for (const auto id : invalid) End(id);
            }
        });
    }
    void Revert()
    {
        // Engine and PapyrusUtil restore their own save data; old-world handles must not edit the new world.
        ++epoch;
        records.clear();
        const std::lock_guard lock(mailboxMutex); mailbox.clear(); queued = false;
    }
}
