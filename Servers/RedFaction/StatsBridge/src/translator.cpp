#include "translator.h"

#include <algorithm>
#include <cctype>

using nlohmann::json;

namespace rfstats
{

namespace
{

// rf::NetGameType
const char* const kGameTypes[] = {
    "dm", "ctf", "tdm", "koth", "dc", "rev", "run", "esc", "bag", "tbag", "pit", "wo", "gg", "sal"};

// Stock weapons.tbl, in table order (the weapon ids in the stream index it). A TC mod or a
// server tbl override can reorder it, so names are only given for unmodded servers.
const char* const kWeapons[] = {
    "remote_charge", "remote_charge_detonator", "riot_stick", "handgun", "undercover_handgun", "shotgun",
    "sniper_rifle", "rocket_launcher", "assault_rifle", "machine_pistol", "machine_pistol_special", "grenade",
    "flamethrower", "riot_shield", "rail_driver", "heavy_machine_gun", "precision_rifle", "fusion_rocket_launcher",
    "vauss", "tankbot_chaingun", "tribeam_laser", "laser", "capek_cane", "reeper_claw", "baby_reeper_claw",
    "rock_snake_smash", "rock_snake_spit", "big_rock_snake_smash", "big_rock_snake_spit",
    "sea_creature_sonar_attack", "drone_smash", "tankbot_smash", "mutant_attack_1", "mutant_attack_2", "heap",
    "torpedo", "apc_minigun", "jeep_gun", "fighter_minigun", "drill", "drone_missile", "tankbot_missile",
    "fighter_rocket", "apc_rocket"};

// rf::DamageType
const char* const kDamageTypes[] = {
    "bash", "bullet", "armor_piercing_bullet", "explosive", "fire", "energy", "electrical", "acid", "scalding",
    "crush"};

// multi/awards.h AwardId
const char* const kAwards[] = {
    "toasty", "massacre", "riot_control", "twofer", "impressive", "excellent", "overkill", "unstoppable",
    "last_stand", "flag_runner", "capture_denied", "area_denied", "bag_check", "revenge", "dominating", "rampage",
    "first_blood", "hat_trick", "airshot", "clean_sweep", "quickdraw", "stonewall", "lockdown", "hazard_pay",
    "last_laugh", "x_ray", "depth_charge", "censored"};

const char* const kGameEndTypes[] = {
    "time_limit", "score_limit", "map_change", "map_vote", "level_logic", "server_shutdown"};

const char* const kLeaveReasons[] = {"quit", "kicked", "banned", "timeout", "vote_kicked"};

const char* const kFlagEvents[] = {
    "flag_stolen", "flag_picked_up", "flag_captured", "flag_dropped", "flag_dropped", "flag_returned",
    "flag_returned", "flag_reset"};

const char* const kPointEvents[] = {"point_captured", "point_contested", "point_uncontested", "point_lock_changed"};

const char* const kBagEvents[] = {"bag_available", "bag_picked_up", "bag_dropped", "bag_returned"};

// The game_end summary fields reported as statistics, as LANCommander names them. Summed over a
// player's stints in the game (a player who leaves and comes back gets a new summary).
const std::pair<const char*, const char*> kSummaryStats[] = {
    {"kills", "kills"},
    {"deaths", "deaths"},
    {"assists", "assists"},
    {"caps", "captures"},
    {"shots_fired", "shots_fired"},
    {"shots_hit", "shots_hit"},
    {"damage_dealt", "damage_dealt"},
    {"damage_taken", "damage_taken"},
    {"damage_potential", "damage_potential"},
    {"efficiency_dealt", "damage_effective"},
    {"time_played_ms", "time_played_ms"},
    {"time_spectating_ms", "time_spectating_ms"},
    {"time_idle_ms", "time_idle_ms"},
};

template <size_t N>
const char* Lookup(const char* const (&table)[N], const json& value)
{
    if (!value.is_number_integer())
        return nullptr;

    const auto i = value.get<long long>();
    return i >= 0 && i < static_cast<long long>(N) ? table[i] : nullptr;
}

const char* TeamName(int team)
{
    return team == 0 ? "red" : team == 1 ? "blue" : "";
}

int TeamOf(const json& value)
{
    return value.is_number_integer() ? value.get<int>() : 2;
}

std::string Str(const json& e, const char* field)
{
    const auto it = e.find(field);
    return it != e.end() && it->is_string() ? it->get<std::string>() : std::string();
}

double Num(const json& e, const char* field)
{
    const auto it = e.find(field);
    return it != e.end() && it->is_number() ? it->get<double>() : 0.0;
}

std::string Lower(std::string text)
{
    std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) { return std::tolower(c); });
    return text;
}

std::string MapName(const std::string& levelFile)
{
    std::string map = Lower(levelFile);

    if (map.size() > 4 && map.compare(map.size() - 4, 4, ".rfl") == 0)
        map.resize(map.size() - 4);

    return map;
}

} // namespace

Translator::Translator(Reporter& reporter, TranslatorSettings settings)
    : m_reporter(reporter), m_settings(settings)
{
}

void Translator::OnEnvelope(const json& envelope)
{
    const std::string session = Str(envelope, "session");

    // A new session is a restarted server: whatever the old one had open is over.
    if (session != m_session)
    {
        if (m_game)
            EndGame("server_restart", true);

        m_session = session;
        m_players.clear();
        m_reported.clear();
        m_anySeq = false;
        m_lastSeq = 0;
    }

    const auto events = envelope.find("events");

    if (events == envelope.end() || !events->is_array())
        return;

    for (const json& e : *events)
    {
        if (!e.is_object() || !e.contains("seq") || !e["seq"].is_number_unsigned())
            continue;

        const auto seq = e["seq"].get<std::uint64_t>();

        // A batch sent again because its ack was lost: already handled.
        if (m_anySeq && seq <= m_lastSeq)
            continue;

        m_anySeq = true;
        m_lastSeq = seq;

        try
        {
            HandleEvent(e);
        }
        catch (const std::exception& ex)
        {
            if (log)
                log("skipped a malformed " + Str(e, "type") + " event: " + ex.what());
        }
    }
}

void Translator::HandleEvent(const json& e)
{
    const std::string type = Str(e, "type");

    if (type == "server_hello")
    {
        m_serverName = Str(e, "server_name");
        m_version    = Str(e, "af_version");
        m_port       = static_cast<int>(Num(e, "port"));

        if (onServerName)
            onServerName(m_serverName);
    }
    else if (type == "game_start")
        OnGameStart(e);
    else if (type == "game_end")
        OnGameEnd(e);
    else if (type == "player_join")
        OnPlayerJoin(e);
    else if (type == "player_leave")
        OnPlayerLeave(e);
    else if (type == "player_rename")
        OnPlayerRename(e);
    else if (type == "player_remediate")
        OnPlayerRemediate(e);
    else if (type == "status")
        OnStatus(e);
    else if (type == "kill")
        OnKill(e);
    else if (type == "gap")
    {
        if (log)
            log("Alpine Faction dropped " + std::to_string(static_cast<long long>(Num(e, "dropped"))) +
                " events (its queue overflowed)");
    }
    else if (!m_game)
        return;
    else if (type == "award")
    {
        json payload;
        if (const char* award = Lookup(kAwards, e.value("award_id", json())))
            payload["award"] = award;
        payload["award_id"] = e.value("award_id", json());
        SimpleEvent(e, "award", "player", "victim", std::move(payload));
    }
    else if (type == "flag_event")
    {
        const json& kind = e.value("kind", json());
        const char* name = Lookup(kFlagEvents, kind);

        if (!name)
            return;

        json payload;
        payload["flag_team"] = TeamName(TeamOf(e.value("team", json())));
        payload["position"] = e.value("pos", json());

        const int k = kind.get<int>();
        if (k == 3)
            payload["death"] = true;
        else if (k == 4)
            payload["manual"] = true;
        else if (k == 6)
            payload["timeout"] = true;

        SimpleEvent(e, name, "player", nullptr, std::move(payload));
    }
    else if (type == "point_event")
    {
        const char* name = Lookup(kPointEvents, e.value("kind", json()));

        if (!name)
            return;

        json players = json::array();
        for (const json& key : e.value("players", json::array()))
        {
            if (std::string k = KeyOf(key); !k.empty())
                players.push_back(k);
        }

        json payload;
        payload["point"] = e.value("hill", json());
        payload["owner"] = TeamName(TeamOf(e.value("owner", json())));
        payload["players"] = std::move(players);
        payload["locked"] = e.value("locked", false);
        SimpleEvent(e, name, nullptr, nullptr, std::move(payload));
    }
    else if (type == "bagman_event")
    {
        const char* name = Lookup(kBagEvents, e.value("kind", json()));

        if (!name)
            return;

        json payload;
        payload["position"] = e.value("pos", json());
        if (e.contains("from"))
            payload["from"] = e["from"] == 0 ? "spawn" : "dropped";
        SimpleEvent(e, name, "player", nullptr, std::move(payload));
    }
    else if (type == "gg_levelup")
    {
        json payload;
        payload["level"] = e.value("level", json());
        if (const char* weapon = Lookup(kWeapons, e.value("weapon", json())))
            payload["weapon"] = weapon;
        SimpleEvent(e, "gungame_level", "player", nullptr, std::move(payload));
    }
    else if (type == "round_start")
    {
        json players = json::array();
        for (const json& key : e.value("participants", json::array()))
        {
            if (std::string k = KeyOf(key); !k.empty())
                players.push_back(k);
        }
        SimpleEvent(e, "round_start", nullptr, nullptr, {{"round", e.value("index", json())}, {"players", players}});
    }
    else if (type == "round_end")
    {
        static const char* const results[] = {"completed", "draw", "canceled"};
        json payload{{"round", e.value("index", json())}, {"duration_ms", e.value("duration_ms", json())}};
        if (const char* result = Lookup(results, e.value("result", json())))
            payload["result"] = result;
        if (const char* team = TeamName(TeamOf(e.value("winner_team", json()))); *team)
            payload["winner_team"] = team;
        SimpleEvent(e, "round_end", "winner_player", nullptr, std::move(payload));
    }
    else if (type == "match_start")
    {
        json players = json::array();
        for (const json& key : e.value("participants", json::array()))
        {
            if (std::string k = KeyOf(key); !k.empty())
                players.push_back(k);
        }
        SimpleEvent(e, "ready_match_start", nullptr, nullptr,
            {{"team_size", e.value("team_size", json())}, {"players", players}});
    }
    else if (type == "match_end")
    {
        json payload{{"result", e.value("result", 0) == 0 ? "completed" : "canceled"}};
        if (const char* team = TeamName(TeamOf(e.value("winner_team", json()))); *team)
            payload["winner_team"] = team;
        SimpleEvent(e, "ready_match_end", "winner_player", nullptr, std::move(payload));
    }
    else if (type == "vote_called" && m_settings.recordVotes)
    {
        SimpleEvent(e, "vote_called", "initiator", "target",
            {{"vote_type", e.value("vote_type", json())}, {"detail", e.value("detail", json())}});
    }
    else if (type == "vote_ended" && m_settings.recordVotes)
    {
        SimpleEvent(e, "vote_ended", nullptr, nullptr,
            {{"vote_type", e.value("vote_type", json())}, {"result", e.value("result", json())},
             {"yes", e.value("yes", json())}, {"no", e.value("no", json())},
             {"eligible", e.value("eligible", json())}});
    }
    else if (type == "spawn" && m_settings.recordSpawns)
    {
        SimpleEvent(e, "spawn", "player", nullptr, {{"position", e.value("pos", json())}});
    }
    else if (type == "item_pickup" && m_settings.recordItems)
    {
        SimpleEvent(e, "item_pickup", "player", nullptr,
            {{"item_id", e.value("item", json())}, {"position", e.value("pos", json())}});
    }

    // Not reported: damage, accuracy and player_pings (windowed aggregates, which come out in
    // the game_end summary), score changes (the final scores are the results), and geomod,
    // clutter and glass destruction.
}

// ── Games ────────────────────────────────────────────────────────────────────

void Translator::OnGameStart(const json& e)
{
    if (m_game)
        EndGame("map_change", true);

    m_game.emplace();
    Game& game = *m_game;
    game.id     = e.value("game", 0u);
    game.startT = e.value("t", std::uint64_t{0});

    const json& gametype = e.value("gametype", json());
    const char* mode     = Lookup(kGameTypes, gametype);
    const bool  modded   = e.value("server_is_modded", false) || !Str(e, "tc_mod").empty();

    json settings;
    settings["time_limit_ms"]    = static_cast<long long>(Num(e, "time_limit_s")) * 1000;
    settings["win_condition"]    = e.value("win_condition", json());
    settings["overtime_enabled"] = e.value("overtime_enabled", json());
    settings["crits_enabled"]    = e.value("crits_enabled", json());
    if (const auto m = e.find("mutators"); m != e.end() && !m->empty())
        settings["mutators"] = *m;
    if (const auto g = e.find("gametype_settings"); g != e.end() && !g->empty())
        settings["gametype_settings"] = *g;
    if (const auto s = e.find("server_settings"); s != e.end())
        settings["server_settings"] = *s;

    json metadata;
    metadata["level_name"]  = Str(e, "level_name");
    metadata["session"]     = m_session;
    metadata["game"]        = game.id;
    metadata["modded"]      = modded;
    game.modded             = modded;
    if (!Str(e, "tc_mod").empty())
        metadata["tc_mod"] = Str(e, "tc_mod");

    game.info.externalId    = "af:" + m_session + ":" + std::to_string(game.id);
    game.info.map           = MapName(Str(e, "level_file"));
    game.info.mode          = mode ? mode : "";
    game.info.gameVersion   = m_version.empty() ? std::string() : "Alpine Faction " + m_version;
    game.info.serverName    = m_serverName;
    game.info.serverAddress = m_port ? ":" + std::to_string(m_port) : std::string();
    game.info.settingsJson  = settings.dump(-1, ' ', false, json::error_handler_t::replace);
    game.info.metadataJson  = metadata.dump(-1, ' ', false, json::error_handler_t::replace);

    for (auto& [statsKey, player] : m_players)
        player.matchKey.clear();

    // The players already on the server
    for (const json& entry : e.value("roster", json::array()))
    {
        const std::string statsKey = Str(entry, "player");

        if (statsKey.empty())
            continue;

        Player& p  = m_players[statsKey];
        p.statsKey = statsKey;
        p.name     = Str(entry, "name");
        p.bot      = (entry.value("flags", 0) & 1) != 0;
        p.team     = TeamOf(entry.value("team", json()));

        if (p.team != 2)
            game.teamGame = true;

        const std::string key = EnsureMatchKey(p);

        if (key.empty())
            continue;

        if (!p.bot)
            NoteHuman(key);

        const std::string team = TeamName(p.team);
        Report([this, key, name = p.name, team](MatchHandle match) {
            m_reporter.PlayerJoined(match, key, name, team, 0);
        });
    }

    // With MinPlayers 0, or the humans already there
    NoteHuman(std::string());
}

void Translator::OnGameEnd(const json& e)
{
    if (!m_game)
        return;

    Game& game = *m_game;

    for (const json& entry : e.value("players", json::array()))
    {
        Player* p = FindPlayer(entry.value("player", json()));

        if (!p)
            continue;

        p->name = Str(entry, "name").empty() ? p->name : Str(entry, "name");
        p->team = TeamOf(entry.value("team", json()));

        if (p->team != 2)
            game.teamGame = true;

        const std::string key = EnsureMatchKey(*p);

        if (key.empty())
            continue;

        AddSummary(key, entry, true);
        game.totals[key].team = TeamName(p->team);
    }

    const double red  = Num(e, "red_score");
    const double blue = Num(e, "blue_score");
    const long long duration = static_cast<long long>(Num(e, "duration_ms"));

    const char* reason = Lookup(kGameEndTypes, e.value("end_type", json()));
    const bool shutdown = e.value("end_type", 0) == 5;

    json payload{{"duration_ms", duration}, {"overtime", e.value("overtime", false)}};
    if (game.teamGame)
    {
        payload["red_score"]  = static_cast<long long>(red);
        payload["blue_score"] = static_cast<long long>(blue);
    }
    SimpleEvent(e, "game_end", nullptr, nullptr, std::move(payload));

    // The totals and the standings, worked out as the other LANCommander server plugins do:
    // in a team game the teams are ranked by score and each player takes their team's place;
    // otherwise the players are ranked by score. A player who wasn't there at the end did not
    // finish.
    Report([this, totals = game.totals, teamGame = game.teamGame, red, blue](MatchHandle match) {
        for (const auto& [key, t] : totals)
        {
            for (const auto& [stat, value] : t.sums)
                m_reporter.SetStatistic(match, key, "", stat, value);

            m_reporter.SetStatistic(match, key, "", "score", t.score);
            m_reporter.SetStatistic(match, key, "", "highest_streak", t.highestStreak);

            if (t.pingTime > 0)
                m_reporter.SetStatistic(match, key, "", "avg_ping", t.pingWeighted / t.pingTime);
        }

        if (teamGame)
        {
            m_reporter.SetStatistic(match, "", "red", "score", red);
            m_reporter.SetStatistic(match, "", "blue", "score", blue);

            const int redRank  = red >= blue ? 1 : 2;
            const int blueRank = blue >= red ? 1 : 2;

            m_reporter.SetResult(match, {"", "red", redRank,
                redRank == 1 ? ResultStatus::Finished : ResultStatus::Defeated, red});
            m_reporter.SetResult(match, {"", "blue", blueRank,
                blueRank == 1 ? ResultStatus::Finished : ResultStatus::Defeated, blue});

            for (const auto& [key, t] : totals)
            {
                if (t.team.empty())
                    continue;

                const int rank = t.team == "red" ? redRank : blueRank;
                const ResultStatus status = !t.present ? ResultStatus::DidNotFinish
                    : rank == 1 ? ResultStatus::Finished : ResultStatus::Defeated;
                m_reporter.SetResult(match, {key, t.team, rank, status, t.score});
            }
        }
        else
        {
            for (const auto& [key, t] : totals)
            {
                int rank = 1;
                for (const auto& [otherKey, other] : totals)
                {
                    if (other.score > t.score)
                        ++rank;
                }

                m_reporter.SetResult(match, {key, "", rank,
                    t.present ? ResultStatus::Finished : ResultStatus::DidNotFinish, t.score});
            }
        }
    });

    EndGame(reason ? reason : "game_over", shutdown);
}

void Translator::EndGame(const std::string& reason, bool abandoned)
{
    if (!m_game)
        return;

    Game& game = *m_game;

    if (game.recording)
    {
        m_reporter.End(game.match, reason, abandoned);

        // Its demo is uploaded after the end, when the next level starts
        m_reported[game.id] = {game.match, game.info.map};

        while (m_reported.size() > 64)
            m_reported.erase(m_reported.begin());

        if (log)
            log("Match " + game.info.externalId + " (" + game.info.map + ") ended: " + reason +
                (abandoned ? ", abandoned" : ""));
    }
    else if (log)
    {
        log("Game " + game.info.externalId + " (" + game.info.map + ") not reported: fewer than " +
            std::to_string(m_settings.minPlayers) + " human players");
    }

    for (const std::string& demo : game.demos)
        if (const auto it = m_demos.find(demo); it != m_demos.end() && it->second == 0)
            m_demos.erase(it);

    m_game.reset();
}

void Translator::Shutdown(unsigned timeoutMs)
{
    MatchHandle match = m_game && m_game->recording ? m_game->match : 0;

    if (m_game)
        EndGame("server_shutdown", true);

    if (match)
        m_reporter.Flush(match, timeoutMs);
}

Translator::Demo Translator::AttachDemo(const std::string& session, std::uint32_t gameId, const std::string& path)
{
    if (session.empty() || session != m_session)
        return Demo::None;

    const auto attach = [this, path](MatchHandle match) {
        if (m_reporter.AttachDemo(match, path))
            m_demos[path] = match;
        else
            m_demos.erase(path);
    };

    if (m_game && m_game->id == gameId)
    {
        if (m_game->recording)
        {
            attach(m_game->match);
            return m_demos.count(path) ? Demo::Attached : Demo::None;
        }

        // Not reported (yet): attached if it gets there, dropped with the game otherwise
        m_demos[path] = 0;
        m_game->demos.push_back(path);
        m_game->held.push_back(attach);
        return Demo::Held;
    }

    const auto reported = m_reported.find(gameId);

    if (reported == m_reported.end())
        return Demo::None;

    attach(reported->second.match);
    return m_demos.count(path) ? Demo::Attached : Demo::None;
}

std::string Translator::LevelOf(const std::string& session, std::uint32_t gameId) const
{
    if (session.empty() || session != m_session)
        return {};

    if (m_game && m_game->id == gameId)
        return m_game->info.map;

    const auto reported = m_reported.find(gameId);
    return reported == m_reported.end() ? std::string() : reported->second.level;
}

bool Translator::DemoInUse(const std::string& path)
{
    const auto it = m_demos.find(path);

    if (it == m_demos.end())
        return false;

    if (it->second == 0 || m_reporter.PendingAttachments(it->second) > 0)
        return true;

    m_demos.erase(it);
    return false;
}

void Translator::Report(std::function<void(MatchHandle)> call)
{
    if (!m_game)
        return;

    if (m_game->recording)
        call(m_game->match);
    else
        m_game->held.push_back(std::move(call));
}

void Translator::NoteHuman(const std::string& matchKey)
{
    if (!m_game)
        return;

    Game& game = *m_game;

    if (!matchKey.empty())
        game.humans.insert(matchKey);

    if (game.recording || static_cast<int>(game.humans.size()) < m_settings.minPlayers)
        return;

    game.match = m_reporter.Start(game.info);

    if (!game.match)
    {
        if (log)
            log("The Interposer refused to start match " + game.info.externalId);
        return;
    }

    game.recording = true;

    if (log)
        log("Recording match " + game.info.externalId + " (" + game.info.map +
            (game.info.mode.empty() ? "" : ", " + game.info.mode) + ")");

    for (auto& call : game.held)
        call(game.match);

    game.held.clear();
}

void Translator::AddSummary(const std::string& matchKey, const json& summary, bool present)
{
    Totals& t = m_game->totals[matchKey];

    for (const auto& [field, stat] : kSummaryStats)
        t.sums[stat] += Num(summary, field);

    t.score += Num(summary, "score");
    t.highestStreak = std::max(t.highestStreak, Num(summary, "highest_streak"));

    const double played = Num(summary, "time_played_ms");
    const double ping   = Num(summary, "avg_ping");

    if (ping >= 0 && played > 0)
    {
        t.pingWeighted += ping * played;
        t.pingTime     += played;
    }

    t.present = present;
}

// ── Players ──────────────────────────────────────────────────────────────────

void Translator::OnPlayerJoin(const json& e)
{
    const std::string statsKey = Str(e, "upssk");

    if (statsKey.empty())
        return;

    Player& p  = m_players[statsKey];
    p          = Player{};
    p.statsKey = statsKey;
    p.name     = Str(e, "name");
    p.bot      = e.value("kind", 0) == 1;

    if (!m_game)
        return;

    const std::string key = EnsureMatchKey(p);

    if (key.empty())
        return;

    const long long t = GameTime(e);
    Report([this, key, name = p.name, t](MatchHandle match) {
        m_reporter.PlayerJoined(match, key, name, "", t);
    });

    if (!p.bot)
        NoteHuman(key);
}

void Translator::OnPlayerLeave(const json& e)
{
    Player* p = FindPlayer(e.value("player", json()));

    if (!p)
        return;

    if (m_game)
    {
        const std::string key = EnsureMatchKey(*p);

        if (!key.empty())
        {
            const long long t = GameTime(e);
            const char* reason = Lookup(kLeaveReasons, e.value("reason", json()));

            if (const auto stats = e.find("stats"); stats != e.end() && stats->is_object())
            {
                AddSummary(key, *stats, false);
                m_game->totals[key].team = TeamName(p->team);
            }

            Report([this, key, t, reason = std::string(reason ? reason : "")](MatchHandle match) {
                m_reporter.Event(match, "disconnect", t, key, "",
                    reason.empty() ? std::string() : json{{"reason", reason}}.dump());
                m_reporter.PlayerLeft(match, key, t);
            });
        }
    }

    m_players.erase(p->statsKey);
}

void Translator::OnPlayerRename(const json& e)
{
    Player* p = FindPlayer(e.value("player", json()));

    if (!p)
        return;

    const std::string from = p->name;
    p->name = Str(e, "name");

    if (!m_game)
        return;

    // The key stays what it was for the rest of this game; the next one uses the new name.
    const std::string key = EnsureMatchKey(*p);

    if (key.empty())
        return;

    const long long t = GameTime(e);
    Report([this, key, from, to = p->name, team = std::string(TeamName(p->team)), t](MatchHandle match) {
        m_reporter.PlayerJoined(match, key, to, team, t);
        m_reporter.Event(match, "name_change", t, key, "", json{{"from", from}, {"to", to}}.dump());
    });
}

void Translator::OnPlayerRemediate(const json& e)
{
    // The player's client delivered its FactionFiles key, which replaces the one the server
    // made up at join in everything that follows.
    const std::string from = Str(e, "upssk");
    const std::string to   = Str(e, "pssk");
    const auto it = m_players.find(from);

    if (it == m_players.end() || to.empty() || from == to)
        return;

    Player p = it->second;
    m_players.erase(it);
    p.statsKey = to;
    m_players[to] = std::move(p);
}

void Translator::OnStatus(const json& e)
{
    Player* p = FindPlayer(e.value("player", json()));

    if (!p || !m_game)
        return;

    const int kind = e.value("kind", -1);
    const std::string key = EnsureMatchKey(*p);

    if (key.empty())
        return;

    const long long t = GameTime(e);

    if (kind == 0 || kind == 1)
    {
        const std::string from = TeamName(p->team);
        p->team = kind;
        m_game->teamGame = true;
        const std::string to = TeamName(kind);

        Report([this, key, name = p->name, from, to, t](MatchHandle match) {
            m_reporter.PlayerJoined(match, key, name, to, t);
            if (!from.empty() && from != to)
                m_reporter.Event(match, "team_change", t, key, "", json{{"from", from}, {"to", to}}.dump());
        });
        return;
    }

    static const char* const kinds[] = {
        nullptr, nullptr, "spectate_start", "spectate_stop", "idle_start", "idle_stop", "participate_start",
        "participate_stop", "handicap"};

    const char* type = Lookup(kinds, e.value("kind", json()));

    if (!type)
        return;

    std::string payload;
    if (kind == 8)
        payload = json{{"percent", e.value("value", json())}}.dump();

    Report([this, key, type = std::string(type), payload, t](MatchHandle match) {
        m_reporter.Event(match, type, t, key, "", payload);
    });
}

void Translator::OnKill(const json& e)
{
    if (!m_game)
        return;

    Player* victim = FindPlayer(e.value("victim", json()));

    if (!victim)
        return;

    const std::string victimKey = EnsureMatchKey(*victim);
    Player* killer = FindPlayer(e.value("killer", json()));
    const std::string killerKey = killer ? EnsureMatchKey(*killer) : std::string();

    if (victimKey.empty())
        return;

    const bool suicide  = !killer || killer == victim;
    const bool teamkill = !suicide && victim->team != 2 && victim->team == killer->team;
    const int  flags    = e.value("flags", 0);

    json payload;

    if (e.contains("weapon") && e["weapon"].is_number_integer())
    {
        payload["weapon_id"] = e["weapon"];

        if (!m_game->modded)
        {
            if (const char* weapon = Lookup(kWeapons, e["weapon"]))
                payload["weapon"] = weapon;
        }
    }

    if (const char* damage = Lookup(kDamageTypes, e.value("damage_type", json())))
        payload["damage_type"] = damage;

    if (flags & 1) payload["headshot"] = true;
    if (flags & 2) payload["splash"]   = true;
    if (flags & 4) payload["melee"]    = true;
    if (suicide)   payload["suicide"]  = true;
    if (!killer)   payload["world"]    = true;
    if (teamkill)  payload["teamkill"] = true;

    json assists = json::array();
    for (const json& key : e.value("assists", json::array()))
    {
        if (std::string k = KeyOf(key); !k.empty())
            assists.push_back(k);
    }
    if (!assists.empty())
        payload["assists"] = std::move(assists);

    if (const auto pos = e.find("victim_pos"); pos != e.end() && pos->is_array())
        payload["victim_position"] = *pos;
    if (const auto pos = e.find("killer_pos"); !suicide && pos != e.end() && pos->is_array())
        payload["attacker_position"] = *pos;

    const long long t = GameTime(e);
    Report([this, actor = suicide ? victimKey : killerKey, victimKey, payload = payload.dump(), t](MatchHandle match) {
        m_reporter.Event(match, "kill", t, actor, victimKey, payload);
    });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

void Translator::SimpleEvent(const json& e, const std::string& type, const char* actorField,
                             const char* subjectField, json payload)
{
    if (!m_game)
        return;

    const std::string actor   = actorField ? KeyOf(e.value(actorField, json())) : std::string();
    const std::string subject = subjectField ? KeyOf(e.value(subjectField, json())) : std::string();
    const long long t = GameTime(e);

    std::string text;
    if (payload.is_object() && !payload.empty())
        text = payload.dump(-1, ' ', false, json::error_handler_t::replace);

    Report([this, type, t, actor, subject, text](MatchHandle match) {
        m_reporter.Event(match, type, t, actor, subject, text);
    });
}

Translator::Player* Translator::FindPlayer(const json& statsKey)
{
    if (!statsKey.is_string())
        return nullptr;

    const auto it = m_players.find(statsKey.get<std::string>());
    return it == m_players.end() ? nullptr : &it->second;
}

std::string Translator::KeyOf(const json& statsKey)
{
    Player* p = FindPlayer(statsKey);
    return p ? EnsureMatchKey(*p) : std::string();
}

std::string Translator::EnsureMatchKey(Player& p)
{
    if (!p.matchKey.empty() || p.name.empty())
        return p.matchKey;

    if (p.bot && !m_settings.recordBots)
        return std::string();

    p.matchKey = (p.bot ? "bot:" : "name:") + p.name;
    return p.matchKey;
}

long long Translator::GameTime(const json& e) const
{
    if (!m_game)
        return 0;

    const auto t = e.value("t", std::uint64_t{0});
    return t > m_game->startT ? static_cast<long long>(t - m_game->startT) : 0;
}

} // namespace rfstats
