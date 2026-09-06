using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using Steamworks;

namespace Swd3ModStudio.Prototype
{
    public sealed class TestPlan
    {
        public int Schema { get; set; }
        public uint AppId { get; set; }
        public string TestKey { get; set; }
        public int Revision { get; set; }
        public string ContentDirectory { get; set; }
        public string ContentSha256 { get; set; }
        public string PreviewFile { get; set; }
        public string PreviewSha256 { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string ChangeNote { get; set; }
    }

    public sealed class TestState
    {
        public int Schema { get; set; }
        public uint AppId { get; set; }
        public string SteamId { get; set; }
        public string TestKey { get; set; }
        public string WorkshopId { get; set; }
        public string Phase { get; set; }
        public int ConfirmedRevision { get; set; }
        public int PendingRevision { get; set; }
        public bool NeedsAgreement { get; set; }
    }

    public sealed class Item
    {
        public string Id { get; set; }
        public string Owner { get; set; }
        public uint AppId { get; set; }
        public uint CreatorAppId { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string Visibility { get; set; }
        public uint Updated { get; set; }
        public string Metadata { get; set; }
        public string PreviewUrl { get; set; }
        public ulong FileSize { get; set; }
        public bool OwnedByCurrentUser { get; set; }
        public string ContentHandle { get; set; }
        public Dictionary<string, List<string>> KeyValues { get; set; }
        public string Version { get { return Program.TagValue(this, "Version"); } }
        public string ContentFileName { get { return Program.TagValue(this, "FileName"); } }
        public string ContentSha256 { get { return Program.TagValue(this, "Sha256"); } }
    }

    public static partial class Program
    {
        public const uint App = 1638230;
        const string PackageName = "studio_m0_fixture.ssmod";
        const string Marker = "swd3-mod-studio:m0:";
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 16777216 };
        static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);
        static readonly Dictionary<string, string> Options = new Dictionary<string, string>();
        static readonly List<string> Commands = new List<string> { "health", "list", "details", "files", "history", "inspect-package", "review-release", "publish-release", "verify-release", "close-release", "create-test", "update-test", "verify-test", "download-test", "self-test" };
        static string Account;
        static int TimeoutSeconds = 60;
        static volatile bool Cancelled;

        static void Emit(string kind, object data)
        {
            Console.WriteLine(Json.Serialize(new { at = DateTime.UtcNow.ToString("o"), kind = kind, data = data }));
        }

        static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

        static string Option(string name)
        {
            string value;
            if (!Options.TryGetValue(name, out value)) throw new ArgumentException("Missing --" + name);
            return value;
        }

        static string Hash(Stream stream)
        {
            stream.Position = 0;
            using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
        }

        public static string HashFile(string path)
        {
            using (var stream = File.OpenRead(path)) return Hash(stream);
        }

        static void AtomicSave(string path, object value)
        {
            path = Path.GetFullPath(path);
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    byte[] bytes = Utf8.GetBytes(Json.Serialize(value));
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }
                if (File.Exists(path)) File.Replace(temp, path, path + ".bak");
                else File.Move(temp, path);
            }
            finally { if (File.Exists(temp)) File.Delete(temp); }
        }

        static T Read<T>(string path) { return Json.Deserialize<T>(File.ReadAllText(path, Utf8)); }

        static FileStream StateLock(string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path)));
            return new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        }

        static void SaveState(string path, TestState state, string phase)
        {
            state.Phase = phase;
            AtomicSave(path, state);
            Emit("state", new { phase = phase, workshopId = state.WorkshopId, confirmedRevision = state.ConfirmedRevision, pendingRevision = state.PendingRevision });
        }

        static T Wait<T>(SteamAPICall_t call, string phase, Action progress) where T : struct
        {
            Require(call != SteamAPICall_t.Invalid, phase + ": invalid API call; remote result not confirmed.");
            bool done = false;
            bool io = false;
            T result = default(T);
            using (var callback = CallResult<T>.Create(delegate(T value, bool failure) { result = value; io = failure; done = true; }))
            {
                callback.Set(call);
                PumpUntil(delegate { return done; }, phase, progress);
            }
            Require(!io, phase + ": IO failure; remote result not confirmed.");
            return result;
        }

        static void PumpUntil(Func<bool> done, string phase, Action progress)
        {
            var watch = Stopwatch.StartNew();
            long last = -2000;
            while (!done())
            {
                if (Cancelled) throw new OperationCanceledException(phase + ": stopped waiting; remote action may still complete.");
                if (watch.Elapsed.TotalSeconds >= TimeoutSeconds) throw new TimeoutException(phase + ": result unknown after " + TimeoutSeconds + " seconds; do not blindly retry creation.");
                SteamAPI.RunCallbacks();
                if (done()) break;
                if (progress != null && watch.ElapsedMilliseconds - last >= 2000) { progress(); last = watch.ElapsedMilliseconds; }
                Thread.Sleep(25);
            }
        }

        static List<Item> Query(UGCQueryHandle_t handle, out uint total)
        {
            Require(handle != UGCQueryHandle_t.Invalid, "Invalid query handle.");
            try
            {
                Require(SteamUGC.SetReturnMetadata(handle, true), "Cannot request metadata.");
                Require(SteamUGC.SetReturnLongDescription(handle, true), "Cannot request descriptions.");
                Require(SteamUGC.SetReturnKeyValueTags(handle, true), "Cannot request version tags.");
                Require(SteamUGC.SetAllowCachedResponse(handle, 0), "Cannot disable query cache.");
                string language = Options.ContainsKey("language") ? Options["language"] : "tchinese";
                Require(SteamUGC.SetLanguage(handle, language), "Cannot select query language.");
                var result = Wait<SteamUGCQueryCompleted_t>(SteamUGC.SendQueryUGCRequest(handle), "query", null);
                Require(result.m_eResult == EResult.k_EResultOK, "Query result: " + result.m_eResult);
                Require(result.m_handle == handle, "Query handle mismatch.");
                total = result.m_unTotalMatchingResults;
                var items = new List<Item>();
                for (uint index = 0; index < result.m_unNumResultsReturned; index++)
                {
                    SteamUGCDetails_t d;
                    Require(SteamUGC.GetQueryUGCResult(handle, index, out d), "Missing query row.");
                    Require(d.m_eResult == EResult.k_EResultOK, "Item " + d.m_nPublishedFileId + ": " + d.m_eResult);
                    string metadata;
                    string preview;
                    SteamUGC.GetQueryUGCMetadata(handle, index, out metadata, 5000);
                    SteamUGC.GetQueryUGCPreviewURL(handle, index, out preview, 4096);
                    var tags = new Dictionary<string, List<string>>(StringComparer.Ordinal);
                    uint tagCount = SteamUGC.GetQueryUGCNumKeyValueTags(handle, index);
                    for (uint t = 0; t < tagCount; t++)
                    {
                        string key, value;
                        Require(SteamUGC.GetQueryUGCKeyValueTag(handle, index, t, out key, 256, out value, 4096), "Cannot read version tag.");
                        if (!tags.ContainsKey(key)) tags.Add(key, new List<string>());
                        tags[key].Add(value);
                    }
                    items.Add(new Item { Id = d.m_nPublishedFileId.ToString(), Owner = d.m_ulSteamIDOwner.ToString(CultureInfo.InvariantCulture),
                        AppId = d.m_nConsumerAppID.m_AppId, CreatorAppId = d.m_nCreatorAppID.m_AppId, Title = d.m_rgchTitle,
                        Description = d.m_rgchDescription, Visibility = d.m_eVisibility.ToString(), Updated = d.m_rtimeUpdated,
                        Metadata = metadata, PreviewUrl = preview, FileSize = (ulong)Math.Max(0, d.m_nFileSize),
                        ContentHandle = d.m_hFile.ToString(), KeyValues = tags,
                        OwnedByCurrentUser = d.m_ulSteamIDOwner.ToString(CultureInfo.InvariantCulture) == Account });
                }
                return items;
            }
            finally { SteamUGC.ReleaseQueryUGCRequest(handle); }
        }

        static Item Details(string id)
        {
            var fileId = ParseId(id);
            uint total;
            var items = Query(SteamUGC.CreateQueryUGCDetailsRequest(new[] { fileId }, 1), out total);
            Require(items.Count == 1 && items[0].Id == id, "Expected exactly the requested Workshop ID.");
            return items[0];
        }

        static PublishedFileId_t ParseId(string id)
        {
            ulong value;
            Require(UInt64.TryParse(id, NumberStyles.None, CultureInfo.InvariantCulture, out value) && value != 0, "Invalid Workshop ID.");
            return new PublishedFileId_t(value);
        }

        static void ListPublished()
        {
            var items = new List<Item>();
            var seen = new HashSet<string>();
            uint page = Options.ContainsKey("page") ? UInt32.Parse(Options["page"], CultureInfo.InvariantCulture) : 1;
            Require(page > 0 && page <= 1000, "Page must be 1..1000.");
            uint total = 0;
            bool complete = false;
            for (; page <= 1000; page++)
            {
                var handle = SteamUGC.CreateQueryUserUGCRequest(SteamUser.GetSteamID().GetAccountID(), EUserUGCList.k_EUserUGCList_Published,
                    EUGCMatchingUGCType.k_EUGCMatchingUGCType_Items, EUserUGCListSortOrder.k_EUserUGCListSortOrder_LastUpdatedDesc,
                    new AppId_t(0), new AppId_t(App), page);
                var rows = Query(handle, out total);
                Emit("page", new { page = page, returned = rows.Count, total = total });
                foreach (var row in rows)
                {
                    Require(row.OwnedByCurrentUser && row.AppId == App, "Author query returned wrong owner/app.");
                    if (seen.Add(row.Id)) items.Add(row);
                }
                if (Options.ContainsKey("page")) { complete = page == 1 && items.Count >= total; break; }
                if (items.Count >= total) { complete = true; break; }
                Require(rows.Count > 0, "Incomplete author list; empty page before total reached.");
            }
            if (!Options.ContainsKey("page")) Require(complete, "Author list exceeded page limit.");
            var output = new { appId = App, steamId = Account, complete = complete, total = total, items = items };
            if (Options.ContainsKey("out")) AtomicSave(Options["out"], output);
            Emit("published", output);
        }

        public static void ValidatePlan(TestPlan p)
        {
            Require(p != null && p.Schema == 1 && p.AppId == App, "Unsupported plan/app.");
            Guid key;
            Require(Guid.TryParseExact(p.TestKey, "N", out key), "Invalid test key.");
            Require(p.Revision == 1 || p.Revision == 2, "M0 supports revisions 1 and 2 only.");
            Require(p.Title != null && p.Title.StartsWith("[PRIVATE M0 TEST] SWD3 MOD Studio ", StringComparison.Ordinal) && Encoding.UTF8.GetByteCount(p.Title) <= 128, "Only the private test title is allowed.");
            Require(!String.IsNullOrWhiteSpace(p.Description) && Encoding.UTF8.GetByteCount(p.Description) < 7000, "Invalid description.");
            Require(!String.IsNullOrWhiteSpace(p.ChangeNote), "Missing change note.");
            Require(Path.IsPathRooted(p.ContentDirectory) && Path.IsPathRooted(p.PreviewFile), "Test paths must be absolute.");
            Require(Directory.Exists(p.ContentDirectory), "Missing content directory.");
            var files = Directory.GetFiles(p.ContentDirectory, "*", SearchOption.AllDirectories);
            Require(files.Length == 1 && Path.GetFullPath(files[0]) == Path.GetFullPath(Path.Combine(p.ContentDirectory, PackageName)), "Content must contain only the M0 fixture package at its root.");
            Require(String.Equals(HashFile(files[0]), p.ContentSha256, StringComparison.OrdinalIgnoreCase), "Content hash mismatch.");
            Require(File.Exists(p.PreviewFile) && new FileInfo(p.PreviewFile).Length < 1000000, "Missing/oversized preview.");
            Require(String.Equals(HashFile(p.PreviewFile), p.PreviewSha256, StringComparison.OrdinalIgnoreCase), "Preview hash mismatch.");
        }

        static TestState LoadState(string path, TestPlan plan)
        {
            var state = Read<TestState>(path);
            Require(state != null && state.Schema == 1 && state.AppId == App && state.SteamId == Account, "State belongs to a different account/app or schema.");
            Require(state.TestKey == plan.TestKey && !String.IsNullOrEmpty(state.WorkshopId), "Missing/mismatched test identity; creation must not be retried.");
            return state;
        }

        static void CheckRemote(Item remote, TestState state, bool requireMarker)
        {
            Require(remote.Id == state.WorkshopId && remote.OwnedByCurrentUser && remote.AppId == App, "Wrong item owner/app/ID; write blocked.");
            if (requireMarker)
            {
                Require(remote.Visibility == ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityPrivate.ToString(), "Test is not private; write blocked.");
                Require(remote.Metadata != null && remote.Metadata.StartsWith(Marker + state.TestKey + ":", StringComparison.Ordinal), "Missing remote test marker; write blocked.");
            }
        }

        static void Submit(TestPlan plan, TestState state, string statePath)
        {
            string file = Path.Combine(plan.ContentDirectory, PackageName);
            using (var contentLock = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var previewLock = new FileStream(plan.PreviewFile, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                Require(Hash(contentLock) == plan.ContentSha256.ToUpperInvariant() && Hash(previewLock) == plan.PreviewSha256.ToUpperInvariant(), "Snapshot changed before submit.");
                var handle = SteamUGC.StartItemUpdate(new AppId_t(App), ParseId(state.WorkshopId));
                Require(handle != UGCUpdateHandle_t.Invalid, "Invalid update handle.");
                Require(SteamUGC.SetItemUpdateLanguage(handle, "english"), "Set language failed.");
                Require(SteamUGC.SetItemTitle(handle, plan.Title), "Set title failed.");
                Require(SteamUGC.SetItemDescription(handle, plan.Description), "Set description failed.");
                Require(SteamUGC.SetItemVisibility(handle, ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityPrivate), "Set private failed.");
                Require(SteamUGC.SetItemMetadata(handle, Marker + plan.TestKey + ":r" + plan.Revision + ":" + plan.ContentSha256), "Set metadata failed.");
                Require(SteamUGC.SetItemContent(handle, plan.ContentDirectory), "Set content failed.");
                Require(SteamUGC.SetItemPreview(handle, plan.PreviewFile), "Set preview failed.");
                state.PendingRevision = plan.Revision;
                SaveState(statePath, state, "submit-intent");
                var result = Wait<SubmitItemUpdateResult_t>(SteamUGC.SubmitItemUpdate(handle, plan.ChangeNote), "submit", delegate
                {
                    ulong processed, total;
                    var status = SteamUGC.GetItemUpdateProgress(handle, out processed, out total);
                    Emit("progress", new { status = status.ToString(), processed = processed.ToString(), total = total.ToString(), workshopId = state.WorkshopId });
                });
                state.NeedsAgreement = result.m_bUserNeedsToAcceptWorkshopLegalAgreement;
                Emit("submit-result", new { result = result.m_eResult.ToString(), workshopId = state.WorkshopId, callbackId = result.m_nPublishedFileId.ToString(), needsAgreement = state.NeedsAgreement });
                Require(result.m_nPublishedFileId.ToString() == state.WorkshopId, "Submit callback ID mismatch.");
                if (result.m_eResult != EResult.k_EResultOK)
                {
                    SaveState(statePath, state, "submit-failed");
                    throw new InvalidOperationException("Submit result: " + result.m_eResult);
                }
                if (state.NeedsAgreement)
                {
                    SaveState(statePath, state, "needs-agreement");
                    throw new InvalidOperationException("Steam requires the Workshop agreement; no automatic acceptance.");
                }
                SaveState(statePath, state, "remote-confirmed");
            }
        }

        static void CreateTest(TestPlan plan, string path)
        {
            Require(plan.Revision == 1, "Creation requires revision 1.");
            Require(!File.Exists(path) && !File.Exists(path + ".bak"), "State already exists; do not recreate. Inspect it and reconcile instead.");
            var state = new TestState { Schema = 1, AppId = App, SteamId = Account, TestKey = plan.TestKey, Phase = "create-intent" };
            SaveState(path, state, "create-intent");
            var result = Wait<CreateItemResult_t>(SteamUGC.CreateItem(new AppId_t(App), EWorkshopFileType.k_EWorkshopFileTypeCommunity), "create", null);
            Emit("create-result", new { result = result.m_eResult.ToString(), workshopId = result.m_nPublishedFileId.ToString(), needsAgreement = result.m_bUserNeedsToAcceptWorkshopLegalAgreement });
            if (result.m_eResult != EResult.k_EResultOK)
            {
                SaveState(path, state, "create-failed");
                throw new InvalidOperationException("Create result: " + result.m_eResult);
            }
            state.WorkshopId = result.m_nPublishedFileId.ToString();
            ParseId(state.WorkshopId);
            state.NeedsAgreement = result.m_bUserNeedsToAcceptWorkshopLegalAgreement;
            SaveState(path, state, state.NeedsAgreement ? "needs-agreement" : "created");
            Require(!state.NeedsAgreement, "Steam requires the Workshop agreement; ID saved, do not recreate.");
            Submit(plan, state, path);
            Verify(plan, state, path);
        }

        static void UpdateTest(TestPlan plan, string path)
        {
            var state = LoadState(path, plan);
            Require(plan.Revision == 2 && state.ConfirmedRevision == 1 && state.Phase == "verified", "Update requires verified revision 1; reconcile unresolved operation first.");
            CheckRemote(Details(state.WorkshopId), state, true);
            Submit(plan, state, path);
            Verify(plan, state, path);
        }

        static void Verify(TestPlan plan, TestState state, string path)
        {
            var remote = Details(state.WorkshopId);
            CheckRemote(remote, state, true);
            Require(remote.Title == plan.Title && remote.Description == plan.Description, "Remote title/description differ; result remains pending verification.");
            Require(remote.Metadata == Marker + plan.TestKey + ":r" + plan.Revision + ":" + plan.ContentSha256, "Remote revision/content marker differs.");
            Require(!String.IsNullOrWhiteSpace(remote.PreviewUrl), "Remote preview is missing.");
            state.ConfirmedRevision = plan.Revision;
            state.PendingRevision = 0;
            SaveState(path, state, "verified");
            Emit("verified", new { item = remote, revision = plan.Revision, verification = "remote-details; content bytes require download-test" });
        }

        static void DownloadTest(TestPlan plan, TestState state)
        {
            CheckRemote(Details(state.WorkshopId), state, true);
            var id = ParseId(state.WorkshopId);
            bool done = false;
            DownloadItemResult_t result = default(DownloadItemResult_t);
            using (var callback = Callback<DownloadItemResult_t>.Create(delegate(DownloadItemResult_t value)
            {
                if (value.m_unAppID.m_AppId == App && value.m_nPublishedFileId == id) { result = value; done = true; }
            }))
            {
                Require(SteamUGC.DownloadItem(id, true), "DownloadItem was rejected.");
                PumpUntil(delegate { return done; }, "download", null);
            }
            Require(result.m_eResult == EResult.k_EResultOK, "Download result: " + result.m_eResult);
            ulong size;
            string folder;
            uint stamp;
            Require(SteamUGC.GetItemInstallInfo(id, out size, out folder, 4096, out stamp), "Downloaded item install info unavailable.");
            var files = Directory.GetFiles(folder, "*", SearchOption.AllDirectories);
            Require(files.Length == 1 && Path.GetFileName(files[0]) == PackageName, "Unexpected files in downloaded test item.");
            string actual = HashFile(files[0]);
            Require(actual == plan.ContentSha256.ToUpperInvariant(), "Downloaded content hash mismatch.");
            Emit("download-verified", new { workshopId = state.WorkshopId, revision = plan.Revision, sha256 = actual, size = size.ToString(), folder = folder, subscribed = (SteamUGC.GetItemState(id) & 1) != 0 });
        }

        static void SelfTest()
        {
            string tempRoot = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            string dir = Path.GetFullPath(Path.Combine(tempRoot, "swd3-m0-tests-" + Guid.NewGuid().ToString("N")));
            Directory.CreateDirectory(dir);
            string path = Path.Combine(dir, "state.json");
            int tests = 0;
            try
            {
                AtomicSave(path, new { revision = 1 }); AtomicSave(path, new { revision = 2 });
                Require(Read<Dictionary<string, object>>(path)["revision"].ToString() == "2", "Atomic replace failed."); tests++;
                Require(Read<Dictionary<string, object>>(path + ".bak")["revision"].ToString() == "1", "Previous state not backed up."); tests++;
                using (StateLock(path))
                {
                    bool blocked = false;
                    try { using (StateLock(path)) { } } catch (IOException) { blocked = true; }
                    Require(blocked, "Concurrent writer not blocked."); tests++;
                }
                Require(ParseId("18446744073709551615").ToString() == "18446744073709551615", "64-bit ID precision lost."); tests++;
                bool invalid = false;
                try { ParseId("-1"); } catch (InvalidOperationException) { invalid = true; }
                Require(invalid, "Invalid ID accepted."); tests++;
                Account = "42";
                var state = new TestState { Schema = 1, AppId = App, SteamId = "42", TestKey = Guid.NewGuid().ToString("N"), WorkshopId = "123" };
                var remote = new Item { Id = "123", AppId = App, OwnedByCurrentUser = true, Visibility = "public", Metadata = Marker + state.TestKey + ":r1" };
                bool protectedItem = false;
                try { CheckRemote(remote, state, true); } catch (InvalidOperationException) { protectedItem = true; }
                Require(protectedItem, "Public item not protected."); tests++;
                remote.Visibility = ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityPrivate.ToString();
                remote.Metadata = "another-item";
                protectedItem = false;
                try { CheckRemote(remote, state, true); } catch (InvalidOperationException) { protectedItem = true; }
                Require(protectedItem, "Unmarked item not protected."); tests++;
                AtomicSave(path, state);
                bool duplicate = false;
                try { CreateTest(new TestPlan { Revision = 1 }, path); } catch (InvalidOperationException) { duplicate = true; }
                Require(duplicate, "Existing creation journal not protected."); tests++;
                state.Phase = "submit-intent"; state.ConfirmedRevision = 1;
                AtomicSave(path, state);
                bool unresolved = false;
                try { UpdateTest(new TestPlan { TestKey = state.TestKey, Revision = 2 }, path); } catch (InvalidOperationException) { unresolved = true; }
                Require(unresolved, "Unresolved operation allowed another submit."); tests++;
                state.SteamId = "another-account";
                AtomicSave(path, state);
                bool wrongAccount = false;
                try { LoadState(path, new TestPlan { TestKey = state.TestKey }); } catch (InvalidOperationException) { wrongAccount = true; }
                Require(wrongAccount, "Cross-account state was accepted."); tests++;
                string contentDir = Path.Combine(dir, "content"); Directory.CreateDirectory(contentDir);
                string package = Path.Combine(contentDir, PackageName); File.WriteAllText(package, "offline hash fixture");
                string preview = Path.Combine(dir, "preview.png"); File.WriteAllText(preview, "offline preview hash fixture");
                var plan = new TestPlan { Schema = 1, AppId = App, TestKey = state.TestKey, Revision = 1,
                    ContentDirectory = contentDir, ContentSha256 = HashFile(package), PreviewFile = preview, PreviewSha256 = HashFile(preview),
                    Title = "[PRIVATE M0 TEST] SWD3 MOD Studio offline", Description = "Offline test", ChangeNote = "test" };
                ValidatePlan(plan); tests++;
                using (var locked = new FileStream(package, FileMode.Open, FileAccess.Read, FileShare.Read))
                {
                    bool protectedSnapshot = false;
                    try { File.WriteAllText(package, "changed"); } catch (IOException) { protectedSnapshot = true; }
                    Require(protectedSnapshot, "Snapshot can be modified while submitting."); tests++;
                }
                File.WriteAllText(package, "changed");
                bool hashRejected = false;
                try { ValidatePlan(plan); } catch (InvalidOperationException) { hashRejected = true; }
                Require(hashRejected, "Changed content passed preflight."); tests++;
                plan.ContentSha256 = HashFile(package);
                File.WriteAllText(Path.Combine(contentDir, "extra.txt"), "unexpected");
                bool extraRejected = false;
                try { ValidatePlan(plan); } catch (InvalidOperationException) { extraRejected = true; }
                Require(extraRejected, "Unexpected upload content passed preflight."); tests++;
                Emit("self-test", new { passed = tests, steamInitialized = false });
            }
            finally
            {
                Require(dir.StartsWith(tempRoot, StringComparison.OrdinalIgnoreCase) && Path.GetFileName(dir).StartsWith("swd3-m0-tests-", StringComparison.Ordinal), "Refusing cleanup outside the test directory.");
                Directory.Delete(dir, true);
            }
        }

        public static int Main(string[] args)
        {
            Console.OutputEncoding = Utf8;
            bool initialized = false;
            try
            {
                if (args.Length == 0 || args[0] == "--help")
                {
                    Console.WriteLine("SteamPrototype: health | list [--out FILE] | details/files/history --id ID [--out FILE] | review-release/publish-release/verify-release/close-release --plan FILE --state FILE | create-test/update-test/verify-test/download-test --plan FILE --state FILE | inspect-package --package FILE | self-test; optional --timeout 5..600 --language tchinese --expected-account ID");
                    return 0;
                }
                Require(Commands.Contains(args[0]), "Unknown command.");
                for (int i = 1; i < args.Length; i += 2)
                {
                    Require(args[i].StartsWith("--") && i + 1 < args.Length, "Options require --name value.");
                    string key = args[i].Substring(2);
                    Require(new[] { "timeout", "language", "page", "out", "id", "plan", "state", "package", "expected-account" }.Contains(key) && !Options.ContainsKey(key), "Unknown/duplicate option.");
                    Options.Add(key, args[i + 1]);
                }
                if (Options.ContainsKey("timeout")) TimeoutSeconds = Int32.Parse(Options["timeout"], CultureInfo.InvariantCulture);
                Require(TimeoutSeconds >= 5 && TimeoutSeconds <= 600, "Timeout must be 5..600 seconds.");
                if (args[0] == "self-test") { SelfTest(); ReleaseSelfTest(); return 0; }
                if (args[0] == "inspect-package") { Output("package", InspectPackage(Option("package"))); return 0; }
                ReleasePlan release = null;
                if (args[0].EndsWith("-release", StringComparison.Ordinal))
                {
                    release = Read<ReleasePlan>(Option("plan")); ValidateRelease(release);
                    Options["language"] = release.Language; Option("state");
                }
                TestPlan plan = null;
                if (args[0].EndsWith("-test", StringComparison.Ordinal)) { plan = Read<TestPlan>(Option("plan")); ValidatePlan(plan); Options["language"] = "english"; Option("state"); }
                Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e) { e.Cancel = true; Cancelled = true; };
                Require(!Environment.Is64BitProcess, "This prototype requires the paired x86 Steam API.");
                Require(Packsize.Test() && DllCheck.Test(), "Steamworks.NET/native ABI check failed.");
                Require(SteamAPI.IsSteamRunning(), "Steam client is not running.");
                initialized = SteamAPI.Init();
                Require(initialized, "SteamAPI.Init failed. Keep Steam logged in; check paired DLLs and app ID.");
                Require(SteamUtils.GetAppID().m_AppId == App && SteamUser.BLoggedOn(), "Wrong AppID or Steam is offline.");
                Account = SteamUser.GetSteamID().m_SteamID.ToString(CultureInfo.InvariantCulture);
                if (Options.ContainsKey("expected-account")) Require(Account == Options["expected-account"], "Steam account changed; reconnect before continuing.");
                Emit("session", new { version = "0.3.0", appId = App, steamId = Account, persona = SteamFriends.GetPersonaName(), runtime = Environment.Version.ToString(), x64 = Environment.Is64BitProcess, steamworks = typeof(SteamAPI).Assembly.FullName });
                switch (args[0])
                {
                    case "health": Emit("health", new { ok = true }); break;
                    case "list": ListPublished(); break;
                    case "details": Output("details", Details(Option("id"))); break;
                    case "files": InspectFiles(Option("id")); break;
                    case "history": ReleaseHistory(Option("id")); break;
                    case "review-release": case "publish-release": case "verify-release": case "close-release":
                        RunRelease(args[0], release, Path.GetFullPath(Option("state"))); break;
                    default:
                        string statePath = Path.GetFullPath(Option("state"));
                        using (StateLock(statePath))
                        {
                            if (args[0] == "create-test") CreateTest(plan, statePath);
                            else if (args[0] == "update-test") UpdateTest(plan, statePath);
                            else if (args[0] == "verify-test") Verify(plan, LoadState(statePath, plan), statePath);
                            else DownloadTest(plan, LoadState(statePath, plan));
                        }
                        break;
                }
                Emit("completed", new { command = args[0] });
                return 0;
            }
            catch (Exception ex)
            {
                Emit("error", new { type = ex.GetType().Name, message = ex.Message, stack = ex.StackTrace });
                return ex is TimeoutException || ex is OperationCanceledException ? 3 : 1;
            }
            finally { if (initialized) { SteamAPI.Shutdown(); Emit("shutdown", new { ok = true }); } }
        }
    }
}
