// Alpine Faction's FactionFiles stats stream ("afstats", event schema 2) -> LANCommander matches.
//
// Alpine Faction reports a server's games to FactionFiles as batches of events, each event
// stamped with the session (one per server process), a sequence number and the game (one per
// level played) it belongs to. Each game becomes one LANCommander match:
//
//   game_start  -> the match starts, with the level, the game type and the rules. Players in
//                  its roster join at 0
//   player_*    -> joins, leaves and name changes. Players are keyed by name ("name:<name>",
//                  "bot:<name>"); Alpine Faction's own keys are per-connection
//   kill, award, flag/point/bag events, Gun Game levels, rounds, votes, team changes
//               -> match events
//   game_end    -> each player's totals from Alpine Faction's scoreboard summary, the team
//                  scores, the standings, and the end of the match
//
// Alpine Faction's demos of the games (demo_auto_record) are attached to their matches.
//
// A game is only reported once enough human players have been in it (MinPlayers); until then
// its calls are held, and a game that never gets there is dropped, so an empty server cycling
// through its rotation records nothing.

#pragma once

#include "reporter.h"

#include <nlohmann/json.hpp>

#include <cstdint>
#include <functional>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <vector>

namespace rfstats
{

struct TranslatorSettings
{
    int  minPlayers   = 1;     // human players in a game before it is reported
    bool recordBots   = true;
    bool recordSpawns = false;
    bool recordItems  = false;
    bool recordVotes  = true;
};

class Translator
{
public:
    Translator(Reporter& reporter, TranslatorSettings settings);

    // One events.php body. Events already seen (a batch resent after a lost ack) are skipped.
    void OnEnvelope(const nlohmann::json& envelope);

    // The server is going away: end the open game, if any, as abandoned, and wait up to
    // timeoutMs for delivery.
    void Shutdown(unsigned timeoutMs);

    // An uploaded demo of game `game` of `session`, saved at `path`: attached to the game's
    // match, now or, while the game is still being held back, once it is reported. None when
    // it isn't one of this session's reported games: the file isn't needed then.
    enum class Demo { None, Attached, Held };
    Demo AttachDemo(const std::string& session, std::uint32_t game, const std::string& path);

    // The level of one of this session's games, for naming its demo; "" when unknown.
    std::string LevelOf(const std::string& session, std::uint32_t game) const;

    // Whether a demo given to AttachDemo still has to stay on disk: its game is waiting to be
    // reported, or the Interposer hasn't finished uploading it.
    bool DemoInUse(const std::string& path);

    // The server name from server_hello, once known; for the reporter name.
    std::function<void(const std::string& serverName)> onServerName;

    // Status lines for the console.
    std::function<void(const std::string& line)> log;

private:
    struct Player
    {
        std::string statsKey;
        std::string name;
        bool        bot = false;
        int         team = 2;      // 0 red, 1 blue, 2 none
        std::string matchKey;      // the key in the current game, fixed once given
    };

    struct Totals
    {
        std::map<std::string, double> sums;
        double highestStreak = 0;
        double pingWeighted = 0;   // avg_ping * time_played_ms, to average over stints
        double pingTime = 0;
        std::string team;
        double score = 0;
        bool   present = false;    // in the game at its end
    };

    struct Game
    {
        std::uint32_t id = 0;
        std::uint64_t startT = 0;
        bool          teamGame = false;
        bool          modded = false;     // weapon ids may not be stock weapons.tbl order
        MatchInfo     info;
        MatchHandle   match = 0;
        bool          recording = false;
        std::vector<std::function<void(MatchHandle)>> held;
        std::set<std::string> humans;           // match keys of the humans seen in this game
        std::map<std::string, Totals> totals;   // by match key
        std::vector<std::string> demos;         // attached once the game is reported
    };

    struct Reported
    {
        MatchHandle match = 0;
        std::string level;
    };

    void HandleEvent(const nlohmann::json& e);
    void OnGameStart(const nlohmann::json& e);
    void OnGameEnd(const nlohmann::json& e);
    void OnPlayerJoin(const nlohmann::json& e);
    void OnPlayerLeave(const nlohmann::json& e);
    void OnPlayerRename(const nlohmann::json& e);
    void OnPlayerRemediate(const nlohmann::json& e);
    void OnStatus(const nlohmann::json& e);
    void OnKill(const nlohmann::json& e);

    void EndGame(const std::string& reason, bool abandoned);
    void Report(std::function<void(MatchHandle)> call);
    void NoteHuman(const std::string& matchKey);
    void AddSummary(const std::string& matchKey, const nlohmann::json& summary, bool present);

    Player*     FindPlayer(const nlohmann::json& statsKey);
    std::string KeyOf(const nlohmann::json& statsKey);   // "" for unknown/null or unrecorded bots
    std::string EnsureMatchKey(Player& p);
    long long   GameTime(const nlohmann::json& e) const;
    void        SimpleEvent(const nlohmann::json& e, const std::string& type, const char* actorField,
                            const char* subjectField, nlohmann::json payload);

    Reporter&          m_reporter;
    TranslatorSettings m_settings;

    std::string   m_session;
    std::uint64_t m_lastSeq = 0;
    bool          m_anySeq = false;

    std::string m_serverName;
    std::string m_version;
    int         m_port = 0;

    std::map<std::string, Player> m_players;   // by Alpine Faction stats key
    std::optional<Game>           m_game;

    std::map<std::uint32_t, Reported> m_reported;   // this session's ended, reported games
    std::map<std::string, MatchHandle> m_demos;     // demo path -> match, 0 while held
};

} // namespace rfstats
