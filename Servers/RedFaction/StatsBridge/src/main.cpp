// rf-stats-bridge: stands in for FactionFiles' stats API (link.factionfiles.com) so an Alpine
// Faction dedicated server's stats go to LANCommander instead.
//
// Alpine Faction reports to https://link.factionfiles.com/afstats/v1/ when its config has an
// fflink_gsk. The image resolves that host to 127.0.0.1 and makes Wine trust a certificate for
// it, and this answers in FactionFiles' place:
//
//   session.php     the server's key exchange: any key is accepted
//   events.php      the event batches: translated into LANCommander matches (translator.h) and
//                   acknowledged, so Alpine Faction moves on to the next batch
//   demoticket.php  a demo upload (demo_auto_record): answered with a ticket to PUT it here,
//   demoupload.php  then saved and attached to its game's match
//   anything else   404 (achievements)
//
// The matches are delivered by the LANCommander Interposer, embedded: it batches, retries and
// keeps undelivered matches on disk under $INTERPOSER_BASE_DIRECTORY/.interposer/Matches/.
//
// Settings come from the environment:
//
//   MATCH_STATS_SERVER_URL, MATCH_STATS_TOKEN, MATCH_STATS_GAME_ID, MATCH_STATS_SERVER_ID,
//   MATCH_STATS_REPORTER_NAME (default: the server name), MATCH_STATS_FLUSH_INTERVAL (ms),
//   MATCH_STATS_MIN_PLAYERS, MATCH_STATS_RECORD_BOTS, MATCH_STATS_RECORD_SPAWNS,
//   MATCH_STATS_RECORD_ITEMS, MATCH_STATS_RECORD_VOTES
//   RF_STATS_BRIDGE_CERT, RF_STATS_BRIDGE_KEY   the certificate and key to serve (PEM)
//   RF_STATS_BRIDGE_ADDRESS, RF_STATS_BRIDGE_PORT   where to listen (127.0.0.1:443)
//   RF_STATS_BRIDGE_READY   a file to create once listening
//   RF_STATS_BRIDGE_DEMOS   where to keep demos until the Interposer has uploaded them; demo
//                           uploads are refused without it
//
// rf-stats-bridge --dry-run <file>... reads events.php bodies (one JSON envelope per line, or a
// file of one) and prints what would be reported instead of listening.

#define CPPHTTPLIB_OPENSSL_SUPPORT
#include "httplib.h"

#include "reporter.h"
#include "translator.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <array>
#include <atomic>
#include <cctype>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <mutex>
#include <random>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>

using nlohmann::json;

namespace
{

std::string Env(const char* name, const char* fallback = "")
{
    const char* value = std::getenv(name);
    return value && *value ? std::string(value) : std::string(fallback);
}

int EnvInt(const char* name, int fallback)
{
    const std::string value = Env(name);

    try
    {
        return value.empty() ? fallback : std::stoi(value);
    }
    catch (...)
    {
        return fallback;
    }
}

bool EnvBool(const char* name, bool fallback)
{
    std::string value = Env(name);

    for (char& c : value)
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));

    if (value == "true" || value == "1" || value == "yes" || value == "on")
        return true;
    if (value == "false" || value == "0" || value == "no" || value == "off")
        return false;
    return fallback;
}

void Log(const std::string& line)
{
    std::fprintf(stdout, "[rf-stats-bridge] %s\n", line.c_str());
    std::fflush(stdout);
}

std::string RandomKey()
{
    static const char alphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    std::random_device random;
    std::string key;

    for (int i = 0; i < 32; ++i)
        key += alphabet[random() % (sizeof(alphabet) - 1)];

    return key;
}

// zlib's CRC-32, which Alpine Faction sends with each demo
class Crc32
{
public:
    void Update(const char* data, std::size_t length)
    {
        static const std::array<std::uint32_t, 256> table = [] {
            std::array<std::uint32_t, 256> t{};

            for (std::uint32_t i = 0; i < 256; ++i)
            {
                std::uint32_t c = i;

                for (int k = 0; k < 8; ++k)
                    c = c & 1 ? 0xEDB88320u ^ (c >> 1) : c >> 1;

                t[i] = c;
            }

            return t;
        }();

        for (std::size_t i = 0; i < length; ++i)
            m_crc = table[(m_crc ^ static_cast<unsigned char>(data[i])) & 0xFF] ^ (m_crc >> 8);
    }

    std::uint32_t Value() const { return m_crc ^ 0xFFFFFFFFu; }

private:
    std::uint32_t m_crc = 0xFFFFFFFFu;
};

bool IsSessionId(const std::string& text)
{
    return text.size() == 16 &&
        std::all_of(text.begin(), text.end(), [](char c) { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'); });
}

// A demo Alpine Faction has been given a ticket to upload
struct DemoTicket
{
    std::string   session;
    std::uint32_t game = 0;
    std::uint64_t bytes = 0;
    std::uint32_t crc = 0;
    std::string   path;
    std::chrono::steady_clock::time_point issued;
};

constexpr std::uint64_t kMaxDemoBytes = 100ull << 20;   // FactionFiles' own limit, which AF keeps to

// Whether a match a previous run left in the Interposer's spool still has this file to upload
bool SpoolMentions(const std::string& spool, const std::string& fileName)
{
    namespace fs = std::filesystem;
    std::error_code error;

    for (const auto& entry : fs::directory_iterator(spool, error))
    {
        std::ifstream state(entry.path() / "state.json");
        std::stringstream text;
        text << state.rdbuf();

        if (text.str().find(fileName) != std::string::npos)
            return true;
    }

    return false;
}

// Deletes the demos nothing needs any more: uploaded (or given up on) by the Interposer, or of
// a game that wasn't reported. At startup, also the remains of uploads cut off midway.
void SweepDemos(const std::string& directory, const std::string& spool, std::mutex& lock,
                rfstats::Translator& translator, bool startup)
{
    namespace fs = std::filesystem;
    std::error_code error;

    for (const auto& entry : fs::directory_iterator(directory, error))
    {
        const fs::path path = entry.path();
        std::error_code removeError;

        if (path.extension() == ".part")
        {
            if (startup)
                fs::remove(path, removeError);
            continue;
        }

        if (path.extension() != ".afd")
            continue;

        bool inUse;

        {
            std::lock_guard guard(lock);
            inUse = translator.DemoInUse(path.string());
        }

        if (!inUse && !SpoolMentions(spool, path.filename().string()))
            fs::remove(path, removeError);
    }
}

rfstats::TranslatorSettings ReadSettings()
{
    rfstats::TranslatorSettings s;
    s.minPlayers   = std::max(0, EnvInt("MATCH_STATS_MIN_PLAYERS", 1));
    s.recordBots   = EnvBool("MATCH_STATS_RECORD_BOTS", true);
    s.recordSpawns = EnvBool("MATCH_STATS_RECORD_SPAWNS", false);
    s.recordItems  = EnvBool("MATCH_STATS_RECORD_ITEMS", false);
    s.recordVotes  = EnvBool("MATCH_STATS_RECORD_VOTES", true);
    return s;
}

int DryRun(int argc, char** argv)
{
    rfstats::Translator translator(rfstats::PrintingReporter(), ReadSettings());
    translator.log = Log;

    for (int i = 2; i < argc; ++i)
    {
        std::ifstream file(argv[i]);
        std::stringstream text;
        text << file.rdbuf();

        // A whole-file envelope, or one per line
        try
        {
            translator.OnEnvelope(json::parse(text.str()));
            continue;
        }
        catch (const json::exception&)
        {
        }

        std::string line;
        std::istringstream lines(text.str());

        while (std::getline(lines, line))
        {
            if (line.find_first_not_of(" \t\r") == std::string::npos)
                continue;

            translator.OnEnvelope(json::parse(line));
        }
    }

    translator.Shutdown(0);
    return 0;
}

// The games a previous run was recording when it was killed (docker stop kills the whole
// container without warning the server): resumed under their own id and ended as abandoned,
// so LANCommander gets an end instead of waiting for its housekeeping to close them. The
// Interposer delivers what they already had.
void CloseLeftovers(rfstats::Reporter& reporter, const std::string& baseDirectory)
{
    namespace fs = std::filesystem;

    std::error_code error;
    const fs::path spool = fs::path(baseDirectory) / ".interposer" / "Matches";

    for (const auto& entry : fs::directory_iterator(spool, error))
    {
        try
        {
            std::ifstream matchFile(entry.path() / "match.json");
            std::ifstream stateFile(entry.path() / "state.json");

            if (!matchFile || !stateFile)
                continue;

            const json match = json::parse(matchFile);
            const json state = json::parse(stateFile);
            const std::string id = match.value("externalId", "");

            if (id.rfind("af:", 0) != 0 || state.value("ended", false))
                continue;

            rfstats::MatchInfo info;
            info.externalId = id;

            if (const rfstats::MatchHandle handle = reporter.Start(info))
            {
                reporter.End(handle, "server_shutdown", true);
                Log("Match " + id + " was left open by the last run; ended it as abandoned");
            }
        }
        catch (const std::exception&)
        {
        }
    }
}

httplib::SSLServer* g_server = nullptr;
std::atomic<bool>   g_stopping{false};

void OnSignal(int)
{
    g_stopping = true;

    if (g_server)
        g_server->stop();
}

} // namespace

int main(int argc, char** argv)
{
    if (argc >= 2 && std::string(argv[1]) == "--dry-run")
        return DryRun(argc, argv);

    const std::string cert    = Env("RF_STATS_BRIDGE_CERT", "/etc/rf-stats-bridge/server.crt");
    const std::string key     = Env("RF_STATS_BRIDGE_KEY", "/etc/rf-stats-bridge/server.key");
    const std::string address = Env("RF_STATS_BRIDGE_ADDRESS", "127.0.0.1");
    const int         port    = EnvInt("RF_STATS_BRIDGE_PORT", 443);
    const std::string ready   = Env("RF_STATS_BRIDGE_READY");
    const std::string demos   = Env("RF_STATS_BRIDGE_DEMOS");
    const std::string spool   = (std::filesystem::path(Env("INTERPOSER_BASE_DIRECTORY", ".")) / ".interposer" / "Matches").string();

    rfstats::DeliverySettings delivery;
    delivery.serverUrl       = Env("MATCH_STATS_SERVER_URL");
    delivery.token           = Env("MATCH_STATS_TOKEN");
    delivery.gameId          = Env("MATCH_STATS_GAME_ID");
    delivery.serverId        = Env("MATCH_STATS_SERVER_ID");
    delivery.reporterName    = Env("MATCH_STATS_REPORTER_NAME");
    delivery.flushIntervalMs = EnvInt("MATCH_STATS_FLUSH_INTERVAL", 0);

    rfstats::AttachInterposer();
    rfstats::Reporter& reporter = rfstats::InterposerReporter();

    if (!reporter.Configure(delivery))
        Log("the Interposer refused the MATCH_STATS_* settings; see its log in .interposer/Logs/");
    else if (const std::string base = Env("INTERPOSER_BASE_DIRECTORY"); !base.empty())
        CloseLeftovers(reporter, base);

    std::mutex          lock;
    rfstats::Translator translator(reporter, ReadSettings());
    translator.log = Log;

    // Without a reporter name of its own, the server reports as the name it gives players
    const bool namedReporter = !delivery.reporterName.empty();
    translator.onServerName = [&](const std::string& name) {
        if (namedReporter || name.empty() || name == delivery.reporterName)
            return;

        delivery.reporterName = name;
        reporter.Configure(delivery);
    };

    httplib::SSLServer server(cert.c_str(), key.c_str());

    if (!server.is_valid())
    {
        Log("could not load the certificate " + cert + " and key " + key);
        return 1;
    }

    g_server = &server;
    std::signal(SIGTERM, OnSignal);
    std::signal(SIGINT, OnSignal);

    const auto reply = [](httplib::Response& res, int status, const json& body) {
        res.status = status;
        res.set_content(body.dump(), "application/json");
    };

    server.Post("/afstats/v1/session.php", [&](const httplib::Request&, httplib::Response& res) {
        Log("Alpine Faction connected; reporting its games to " +
            (delivery.serverUrl.empty() ? std::string("nobody (MATCH_STATS_SERVER_URL is empty)") : delivery.serverUrl));
        reply(res, 200, {{"gssk", RandomKey()}, {"server_id", 1}});
    });

    server.Post("/afstats/v1/events.php", [&](const httplib::Request& req, httplib::Response& res) {
        json envelope;

        try
        {
            envelope = json::parse(req.body);
        }
        catch (const json::exception&)
        {
            reply(res, 400, {{"error", "invalid_json"}});
            return;
        }

        const auto batch = envelope.value("batch", std::uint64_t{0});

        {
            std::lock_guard guard(lock);
            translator.OnEnvelope(envelope);
        }

        reply(res, 200, {{"ok", true}, {"batch", batch}});
    });

    std::unordered_map<std::string, DemoTicket> tickets;

    if (!demos.empty())
    {
        std::error_code error;
        std::filesystem::create_directories(demos, error);

        server.Post("/afstats/v1/demoticket.php", [&](const httplib::Request& req, httplib::Response& res) {
            json body;

            try
            {
                body = json::parse(req.body);
            }
            catch (const json::exception&)
            {
                reply(res, 400, {{"error", "invalid_json"}});
                return;
            }

            DemoTicket ticket;
            ticket.session = body.value("session", "");
            ticket.game    = body.value("game", 0u);
            ticket.bytes   = body.value("bytes", std::uint64_t{0});
            ticket.crc     = body.value("crc32", 0u);
            ticket.issued  = std::chrono::steady_clock::now();

            if (!IsSessionId(ticket.session) || ticket.game < 1)
            {
                reply(res, 400, {{"error", "invalid_game"}});
                return;
            }

            if (ticket.bytes == 0 || ticket.bytes > kMaxDemoBytes)
            {
                reply(res, 400, {{"error", ticket.bytes ? "demo_too_large" : "invalid_bytes"}});
                return;
            }

            if (body.value("format", "") != "afd")
            {
                reply(res, 400, {{"error", "unsupported_format"}});
                return;
            }

            const std::string id = RandomKey();

            {
                std::lock_guard guard(lock);

                std::string level = translator.LevelOf(ticket.session, ticket.game);
                level.erase(std::remove_if(level.begin(), level.end(), [](char c) {
                    return !std::isalnum(static_cast<unsigned char>(c)) && c != '-' && c != '_';
                }), level.end());

                ticket.path = (std::filesystem::path(demos) / ((level.empty() ? std::string("game") : level) + "_" +
                    ticket.session + "_" + std::to_string(ticket.game) + ".afd")).string();

                // Tickets that were never used
                for (auto it = tickets.begin(); it != tickets.end();)
                    it = ticket.issued - it->second.issued > std::chrono::hours(1) ? tickets.erase(it) : std::next(it);

                tickets[id] = ticket;
            }

            reply(res, 200, {{"ticket", id}, {"upload_url", "https://link.factionfiles.com/afstats/v1/demoupload.php"}});
        });

        server.Put("/afstats/v1/demoupload.php",
            [&](const httplib::Request& req, httplib::Response& res, const httplib::ContentReader& content) {
                const auto discard = [&] { content([](const char*, std::size_t) { return true; }); };

                std::string id = req.get_header_value("Authorization");
                if (id.rfind("Bearer ", 0) == 0)
                    id.erase(0, 7);

                DemoTicket ticket;

                {
                    std::lock_guard guard(lock);
                    const auto it = tickets.find(id);

                    if (it == tickets.end())
                    {
                        discard();
                        reply(res, 401, {{"error", "invalid_ticket"}});
                        return;
                    }

                    ticket = it->second;
                }

                if (req.get_header_value_u64("Content-Length") != ticket.bytes)
                {
                    discard();
                    reply(res, 400, {{"error", "size_mismatch"}});
                    return;
                }

                const std::string part = ticket.path + ".part";
                std::ofstream file(part, std::ios::binary | std::ios::trunc);
                Crc32 crc;
                std::uint64_t received = 0;

                content([&](const char* data, std::size_t length) {
                    received += length;
                    crc.Update(data, length);
                    file.write(data, static_cast<std::streamsize>(length));
                    return received <= ticket.bytes;
                });

                file.close();
                std::error_code error;

                if (!file)
                {
                    std::filesystem::remove(part, error);
                    Log("could not save a demo to " + part);
                    reply(res, 500, {{"error", "internal_error"}});
                    return;
                }

                if (received != ticket.bytes || crc.Value() != ticket.crc)
                {
                    std::filesystem::remove(part, error);
                    reply(res, 400, {{"error", received != ticket.bytes ? "size_mismatch" : "crc_mismatch"}});
                    return;
                }

                const std::string matchId = "af:" + ticket.session + ":" + std::to_string(ticket.game);
                const std::string name = std::filesystem::path(ticket.path).filename().string();
                auto outcome = rfstats::Translator::Demo::None;

                {
                    std::lock_guard guard(lock);
                    tickets.erase(id);
                    std::filesystem::rename(part, ticket.path, error);

                    if (!error)
                        outcome = translator.AttachDemo(ticket.session, ticket.game, ticket.path);
                }

                switch (outcome)
                {
                case rfstats::Translator::Demo::Attached:
                    Log("Demo " + name + " attached to match " + matchId);
                    break;
                case rfstats::Translator::Demo::Held:
                    Log("Demo " + name + " kept for match " + matchId + ", attached if the game is reported");
                    break;
                case rfstats::Translator::Demo::None:
                    std::filesystem::remove(error ? part : ticket.path, error);
                    Log("Demo of " + matchId + " not attached: the game wasn't reported");
                    break;
                }

                reply(res, 200, {{"ok", true}, {"game_id", matchId}});
            });
    }

    server.set_error_handler([&](const httplib::Request& req, httplib::Response& res) {
        if (res.status == 404)
            reply(res, 404, {{"error", "not_supported"}});
        else if (res.body.empty())
            reply(res, res.status, {{"error", "error"}});
        (void)req;
    });

    if (!server.bind_to_port(address, port))
    {
        Log("could not listen on " + address + ":" + std::to_string(port));
        return 1;
    }

    if (!ready.empty())
        std::ofstream(ready) << "ready\n";

    Log("listening on " + address + ":" + std::to_string(port) + " for link.factionfiles.com");

    // Demos are kept until the Interposer has uploaded them
    std::thread sweeper;

    if (!demos.empty())
    {
        sweeper = std::thread([&] {
            SweepDemos(demos, spool, lock, translator, true);

            for (int second = 1; !g_stopping; ++second)
            {
                std::this_thread::sleep_for(std::chrono::seconds(1));

                if (second % 30 == 0)
                    SweepDemos(demos, spool, lock, translator, false);
            }
        });
    }

    server.listen_after_bind();
    g_stopping = true;

    if (sweeper.joinable())
        sweeper.join();

    // Stopped: close out the game in progress and give the Interposer a moment to send it
    {
        std::lock_guard guard(lock);
        translator.Shutdown(5000);
    }

    rfstats::DetachInterposer();
    Log("stopped");
    return 0;
}
