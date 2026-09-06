using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using Steamworks;

namespace Swd3ModStudio.Prototype
{
    public sealed class ReleasePlan
    {
        public int Schema { get; set; }
        public uint AppId { get; set; }
        public string OperationId { get; set; }
        public string WorkshopId { get; set; }
        public string Version { get; set; }
        public string ContentDirectory { get; set; }
        public string FileName { get; set; }
        public string ContentSha256 { get; set; }
        public long ContentSize { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string Language { get; set; }
        public string Visibility { get; set; }
        public string ChangeNote { get; set; }
        public string PreviewFile { get; set; }
        public string PreviewSha256 { get; set; }
    }

    public sealed class PackageInfo
    {
        public string Version { get; set; }
        public string Name { get; set; }
        public string FileName { get; set; }
        public long Size { get; set; }
        public string Sha256 { get; set; }
        public string ManifestSha256 { get; set; }
    }

    public sealed class DownloadedFile
    {
        public string FileName { get; set; }
        public long Size { get; set; }
        public string Sha256 { get; set; }
        public PackageInfo Package { get; set; }
        public string PackageError { get; set; }
    }

    public sealed class ReleaseState
    {
        public int Schema { get; set; }
        public string SteamId { get; set; }
        public string PlanHash { get; set; }
        public string WorkshopId { get; set; }
        public string Phase { get; set; }
        public string Visibility { get; set; }
        public Item Before { get; set; }
        public List<DownloadedFile> BeforeFiles { get; set; }
        public Item After { get; set; }
        public List<DownloadedFile> AfterFiles { get; set; }
        public string LastError { get; set; }
        public string VerifiedAt { get; set; }
        public bool NeedsAgreement { get; set; }
        public string SubmitResult { get; set; }
        public Item BeforeDefault { get; set; }
        public Item AfterDefault { get; set; }
        public string DefaultSubmitResult { get; set; }
        public ReleasePlan ReviewedPlan { get; set; }
    }

    public static partial class Program
    {
        const string TagPrefix = "SWD3Studio_";
        static readonly string[] ReleaseKeys = { "Version", "FileName", "Sha256", "Operation", "Language" };

        public static string TagValue(Item item, string suffix)
        {
            List<string> values;
            if (item.KeyValues != null && item.KeyValues.TryGetValue(TagPrefix + suffix, out values) && values.Count == 1) return values[0];
            return null;
        }

        static void Output(string kind, object data)
        {
            if (Options.ContainsKey("out")) AtomicSave(Options["out"], data);
            Emit(kind, data);
        }

        static string ObjectHash(object data)
        {
            using (var stream = new MemoryStream(Utf8.GetBytes(Json.Serialize(data)))) return Hash(stream);
        }

        static bool SyncDefault(ReleasePlan plan) { return plan.Schema >= 3 && plan.Language != "english"; }

        static Item DetailsInLanguage(string id, string language)
        {
            string previous = Options.ContainsKey("language") ? Options["language"] : "tchinese";
            try { Options["language"] = language; return Details(id); }
            finally { Options["language"] = previous; }
        }

        static string QuoteArgument(string value)
        {
            // File paths cannot contain a quote; no shell is involved.
            Require(value != null && !value.Contains("\""), "Invalid argument path.");
            return "\"" + value.TrimEnd('\\') + "\"";
        }

        static PackageInfo InspectPackage(string path)
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            var runtime = Read<Dictionary<string, string>>(Path.Combine(root, "package-runtime.json"));
            string helper = Path.Combine(root, "SteamReleasePackage.py");
            Require(HashFile(helper) == runtime["HelperSha256"], "Package inspector differs from build.");
            var output = new StringBuilder();
            var error = new StringBuilder();
            using (var process = new Process())
            {
                process.StartInfo = new ProcessStartInfo(runtime["Python"], QuoteArgument(helper) + " inspect " + QuoteArgument(Path.GetFullPath(path)))
                { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
                process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) output.AppendLine(e.Data); };
                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) error.AppendLine(e.Data); };
                Require(process.Start(), "Cannot start package inspector.");
                process.BeginOutputReadLine(); process.BeginErrorReadLine();
                if (!process.WaitForExit(30000)) { process.Kill(); throw new TimeoutException("Package inspection timed out."); }
                process.WaitForExit();
                Require(process.ExitCode == 0, "Package inspection failed: " + error);
            }
            return Json.Deserialize<PackageInfo>(output.ToString());
        }

        static System.Version ParseVersion(string value)
        {
            System.Version version;
            Require(System.Version.TryParse(value, out version) && version.Build == -1 && version.Revision == -1 && version.ToString() == value,
                "Version must be canonical major.minor from MODVersion.");
            return version;
        }

        static ERemoteStoragePublishedFileVisibility Visibility(string value)
        {
            switch (value)
            {
                case "private": return ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityPrivate;
                case "public": return ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityPublic;
                case "friends": return ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityFriendsOnly;
                case "unlisted": return ERemoteStoragePublishedFileVisibility.k_ERemoteStoragePublishedFileVisibilityUnlisted;
                default: throw new InvalidOperationException("Unsupported visibility.");
            }
        }

        static void CheckPackage(ReleasePlan plan, PackageInfo actual)
        {
            Require(actual != null && actual.Version == plan.Version && actual.FileName == plan.FileName &&
                actual.Size == plan.ContentSize && actual.Sha256 == plan.ContentSha256, "Package version/name/size/hash differs from plan.");
        }

        static void ValidateRelease(ReleasePlan plan)
        {
            Require(plan != null && (plan.Schema == 2 || plan.Schema == 3) && plan.AppId == App, "Unsupported release plan/app.");
            Guid operation;
            Require(Guid.TryParseExact(plan.OperationId, "N", out operation), "Invalid operation ID.");
            ParseVersion(plan.Version);
            if (!String.IsNullOrEmpty(plan.WorkshopId)) ParseId(plan.WorkshopId);
            Require(!String.IsNullOrWhiteSpace(plan.Title) && Utf8.GetByteCount(plan.Title) < 129, "Title must be 1..128 UTF-8 bytes.");
            Require(!String.IsNullOrWhiteSpace(plan.Description) && Utf8.GetByteCount(plan.Description) < 8000, "Description must be 1..7999 UTF-8 bytes.");
            Require(!String.IsNullOrWhiteSpace(plan.ChangeNote) && Utf8.GetByteCount(plan.ChangeNote) < 8000, "Change note required (under 8000 bytes).");
            Require(new[] { "english", "tchinese", "schinese" }.Contains(plan.Language), "Supported language: english/tchinese/schinese.");
            if (plan.Visibility == "preserve") Require(!String.IsNullOrEmpty(plan.WorkshopId), "New item cannot preserve visibility.");
            else Visibility(plan.Visibility);
            Require(Path.IsPathRooted(plan.ContentDirectory) && Directory.Exists(plan.ContentDirectory), "Absolute content directory required.");
            var files = Directory.GetFiles(plan.ContentDirectory, "*", SearchOption.AllDirectories);
            Require(files.Length == 1 && Directory.GetDirectories(plan.ContentDirectory).Length == 0 && Path.GetFileName(files[0]) == plan.FileName &&
                String.Equals(Path.GetExtension(plan.FileName), ".ssmod", StringComparison.OrdinalIgnoreCase), "Content must contain exactly the planned root .ssmod.");
            Require(Utf8.GetByteCount(plan.FileName) <= 255, "File name exceeds Workshop tag limit.");
            CheckPackage(plan, InspectPackage(files[0]));
            if (!String.IsNullOrEmpty(plan.PreviewFile))
            {
                Require(Path.IsPathRooted(plan.PreviewFile) && File.Exists(plan.PreviewFile) && new FileInfo(plan.PreviewFile).Length < 1048576 &&
                    HashFile(plan.PreviewFile) == plan.PreviewSha256, "Preview path/size/hash differs from plan.");
            }
            else Require(!String.IsNullOrEmpty(plan.WorkshopId), "New item requires a preview.");
        }

        static List<DownloadedFile> DownloadFiles(string itemId)
        {
            var id = ParseId(itemId);
            bool done = false;
            DownloadItemResult_t result = default(DownloadItemResult_t);
            using (var callback = Callback<DownloadItemResult_t>.Create(delegate(DownloadItemResult_t value)
            {
                if (value.m_unAppID.m_AppId == App && value.m_nPublishedFileId == id) { result = value; done = true; }
            }))
            {
                Require(SteamUGC.DownloadItem(id, true), "DownloadItem rejected; verification pending.");
                PumpUntil(delegate { return done; }, "download", delegate
                {
                    ulong current, total;
                    SteamUGC.GetItemDownloadInfo(id, out current, out total);
                    Emit("download-progress", new { workshopId = itemId, current = current.ToString(), total = total.ToString() });
                });
            }
            Require(result.m_eResult == EResult.k_EResultOK, "Download result: " + result.m_eResult);
            ulong size; string folder; uint timestamp;
            Require(SteamUGC.GetItemInstallInfo(id, out size, out folder, 4096, out timestamp), "No installed download information.");
            string prefix = Path.GetFullPath(folder).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            var files = new List<DownloadedFile>();
            foreach (string path in Directory.GetFiles(folder, "*", SearchOption.AllDirectories).OrderBy(p => p, StringComparer.Ordinal))
            {
                var file = new DownloadedFile { FileName = Path.GetFullPath(path).Substring(prefix.Length).Replace('\\', '/'), Size = new FileInfo(path).Length, Sha256 = HashFile(path) };
                if (String.Equals(Path.GetExtension(path), ".ssmod", StringComparison.OrdinalIgnoreCase))
                {
                    try { file.Package = InspectPackage(path); }
                    catch (Exception ex) { file.PackageError = ex.Message; }
                }
                files.Add(file);
            }
            Emit("downloaded", new { workshopId = itemId, folder = folder, subscribed = (SteamUGC.GetItemState(id) & 1) != 0, files = files });
            return files;
        }

        static void InspectFiles(string id)
        {
            var remote = Details(id);
            Require(remote.AppId == App, "Wrong consumer app.");
            var files = DownloadFiles(id);
            Output("files", new { item = remote, files = files, verifiedAgainstReleasePlan = false });
        }

        static object StableItem(Item item)
        {
            if (item == null) return null;
            return new { item.Id, item.Owner, item.AppId, item.Title, item.Description, item.Visibility, item.Updated, item.Metadata,
                item.ContentHandle, tags = item.KeyValues.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => new { p.Key, Values = p.Value.OrderBy(v => v, StringComparer.Ordinal).ToArray() }).ToArray() };
        }

        static void CheckOwner(Item remote, string id)
        {
            Require(remote.Id == id && remote.AppId == App && remote.OwnedByCurrentUser && remote.Owner == Account, "Wrong Workshop owner/app/ID; write blocked.");
        }

        static void CheckVersionAdvance(ReleasePlan plan, List<DownloadedFile> previous)
        {
            Require(previous != null && previous.Count == 1 && previous[0].Package != null, "Existing item must have one readable .ssmod; cannot infer previous version.");
            int comparison = ParseVersion(plan.Version).CompareTo(ParseVersion(previous[0].Package.Version));
            Require(comparison > 0 || (comparison == 0 && plan.ContentSha256 == previous[0].Sha256), "Changed package requires a newer MODVersion; version rollback is blocked.");
        }

        static string StoreRoot()
        {
            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "SWD3ModStudio", "releases", App.ToString(CultureInfo.InvariantCulture), Account);
            Directory.CreateDirectory(path); return path;
        }

        static string PendingPath(string id) { return Path.Combine(StoreRoot(), "pending-" + id + ".json"); }

        static void ReleaseHistory(string id)
        {
            ParseId(id);
            var entries = Directory.GetFiles(StoreRoot(), "history-" + id + "-*.json").OrderBy(p => p, StringComparer.Ordinal)
                .Select(p => Read<Dictionary<string, object>>(p)).ToArray();
            Output("release-history", new { appId = App, steamId = Account, workshopId = id, scope = "verified releases recorded on this computer", entries = entries });
        }

        static void CheckPending(string id, string statePath)
        {
            string path = PendingPath(id);
            if (!File.Exists(path)) return;
            var pending = Read<Dictionary<string, string>>(path);
            if (pending["StatePath"] == statePath) return;
            Require(File.Exists(pending["StatePath"]) && new[] { "verified", "closed-unchanged" }.Contains(Read<ReleaseState>(pending["StatePath"]).Phase), "Another release is unresolved: " + pending["StatePath"]);
        }

        static void SaveRelease(string path, ReleaseState state, string phase)
        {
            state.Phase = phase; AtomicSave(path, state);
            Emit("release-state", new { workshopId = state.WorkshopId, phase = phase, statePath = path });
        }

        static void RunRelease(string command, ReleasePlan plan, string statePath)
        {
            // The operation registry prevents changing journal paths from bypassing
            // duplicate-create protection. The account lock serializes local workers.
            bool ownsMutex = false;
            using (var mutex = new Mutex(false, "Local\\SWD3ModStudio-Releases-" + App + "-" + Account))
            {
                try
                {
                    try { ownsMutex = mutex.WaitOne(0); } catch (AbandonedMutexException) { ownsMutex = true; }
                    Require(ownsMutex, "Another release command is running for this account.");
                    using (StateLock(statePath))
                    {
                        string registry = Path.Combine(StoreRoot(), "operation-" + plan.OperationId + ".json");
                        if (File.Exists(registry)) Require(Read<Dictionary<string, string>>(registry)["StatePath"] == statePath, "Operation already belongs to another journal; do not recreate.");
                        else AtomicSave(registry, new { StatePath = statePath });
                        if (command == "review-release") { ReviewRelease(plan, statePath); return; }
                        var state = Read<ReleaseState>(statePath);
                        Require(state.Schema == 2 && state.SteamId == Account && state.PlanHash == ObjectHash(plan), "Plan/account differs from the reviewed journal.");
                        if (command == "close-release") CloseRelease(plan, state, statePath);
                        else if (command == "verify-release") VerifyRelease(plan, state, statePath);
                        else PublishRelease(plan, state, statePath);
                    }
                }
                finally { if (ownsMutex) mutex.ReleaseMutex(); }
            }
        }

        static void ReviewRelease(ReleasePlan plan, string path)
        {
            string itemId = plan.WorkshopId;
            if (File.Exists(path))
            {
                var previous = Read<ReleaseState>(path);
                bool rejected = (!String.IsNullOrEmpty(previous.SubmitResult) && previous.SubmitResult != EResult.k_EResultOK.ToString()) ||
                    (!String.IsNullOrEmpty(previous.DefaultSubmitResult) && previous.DefaultSubmitResult != EResult.k_EResultOK.ToString());
                Require(previous.Schema == 2 && previous.SteamId == Account && previous.PlanHash == ObjectHash(plan) && rejected &&
                    new[] { "submit-rejected", "default-submit-rejected", "verification-pending" }.Contains(previous.Phase), "Existing journal is not an explicitly rejected submission; verify instead of retrying.");
                itemId = previous.WorkshopId;
                Require(!String.IsNullOrEmpty(itemId), "Rejected submission must retain its Workshop ID.");
                AtomicSave(path + ".attempt-" + Guid.NewGuid().ToString("N") + ".json", previous);
            }
            else Require(!File.Exists(path + ".bak"), "Journal backup exists; restore/reconcile it before creating another operation.");
            Item before = null;
            List<DownloadedFile> files = null;
            if (!String.IsNullOrEmpty(itemId))
            {
                CheckPending(itemId, path);
                before = Details(itemId); CheckOwner(before, itemId);
                files = DownloadFiles(itemId); CheckVersionAdvance(plan, files);
                Require(ObjectHash(StableItem(before)) == ObjectHash(StableItem(Details(itemId))), "Remote changed during review; prepare review again.");
            }
            var state = new ReleaseState { Schema = 2, SteamId = Account, WorkshopId = itemId, PlanHash = ObjectHash(plan), Before = before,
                BeforeFiles = files, Visibility = plan.Visibility == "preserve" ? before.Visibility : Visibility(plan.Visibility).ToString(),
                BeforeDefault = SyncDefault(plan) && before != null ? DetailsInLanguage(itemId, "english") : null, ReviewedPlan = plan };
            SaveRelease(path, state, "reviewed");
            Output("release-review", new { before = before, beforeFiles = files, beforeDefaultLanguage = state.BeforeDefault, proposed = plan, effectiveVisibility = state.Visibility,
                effectiveLanguages = SyncDefault(plan) ? new[] { plan.Language, "english" } : new[] { plan.Language },
                verification = "title, description, version, file name, size, SHA-256, actual downloaded manifest and bytes" });
        }

        static void PublishRelease(ReleasePlan plan, ReleaseState state, string path)
        {
            Require(state.Phase != "closed-unchanged", "This rejected operation was closed; prepare a new release.");
            if (state.Phase != "reviewed" && state.Phase != "created")
            {
                Require(!String.IsNullOrEmpty(state.WorkshopId), "Create result unresolved; inspect author list, never automatically create again.");
                Emit("reconcile-only", new { phase = state.Phase, workshopId = state.WorkshopId });
                VerifyRelease(plan, state, path); return;
            }
            if (!String.IsNullOrEmpty(state.WorkshopId))
            {
                CheckPending(state.WorkshopId, path);
                var current = Details(state.WorkshopId); CheckOwner(current, state.WorkshopId);
                if (state.Before != null)
                {
                    Require(ObjectHash(StableItem(current)) == ObjectHash(StableItem(state.Before)), "Remote changed since review; submission blocked. Prepare a fresh review.");
                    Require(ObjectHash(DownloadFiles(state.WorkshopId)) == ObjectHash(state.BeforeFiles), "Remote files changed since review; submission blocked.");
                    Require(ObjectHash(StableItem(Details(state.WorkshopId))) == ObjectHash(StableItem(state.Before)), "Remote changed during final preflight; submission blocked.");
                    if (SyncDefault(plan)) Require(ObjectHash(StableItem(DetailsInLanguage(state.WorkshopId, "english"))) == ObjectHash(StableItem(state.BeforeDefault)), "Default-language page changed since review; submission blocked.");
                }
            }
            var locks = new List<FileStream>();
            try
            {
                locks.Add(new FileStream(Path.Combine(plan.ContentDirectory, plan.FileName), FileMode.Open, FileAccess.Read, FileShare.Read));
                if (!String.IsNullOrEmpty(plan.PreviewFile)) locks.Add(new FileStream(plan.PreviewFile, FileMode.Open, FileAccess.Read, FileShare.Read));
                ValidateRelease(plan);
                if (String.IsNullOrEmpty(state.WorkshopId))
                {
                    SaveRelease(path, state, "create-intent");
                    var created = Wait<CreateItemResult_t>(SteamUGC.CreateItem(new AppId_t(App), EWorkshopFileType.k_EWorkshopFileTypeCommunity), "create", null);
                    Emit("create-result", new { result = created.m_eResult.ToString(), workshopId = created.m_nPublishedFileId.ToString() });
                    Require(created.m_eResult == EResult.k_EResultOK, "Create result: " + created.m_eResult);
                    state.WorkshopId = created.m_nPublishedFileId.ToString(); ParseId(state.WorkshopId);
                    state.NeedsAgreement = created.m_bUserNeedsToAcceptWorkshopLegalAgreement;
                    SaveRelease(path, state, state.NeedsAgreement ? "needs-agreement" : "created");
                    Require(!state.NeedsAgreement, "Accept Workshop agreement in Steam; ID retained, do not recreate.");
                }
                AtomicSave(PendingPath(state.WorkshopId), new { StatePath = path });
                var handle = SteamUGC.StartItemUpdate(new AppId_t(App), ParseId(state.WorkshopId));
                Require(handle != UGCUpdateHandle_t.Invalid, "Invalid update handle.");
                Require(SteamUGC.SetItemUpdateLanguage(handle, plan.Language), "Set language failed.");
                Require(SteamUGC.SetItemTitle(handle, plan.Title), "Set title failed.");
                Require(SteamUGC.SetItemDescription(handle, plan.Description), "Set description failed.");
                var visibility = (ERemoteStoragePublishedFileVisibility)Enum.Parse(typeof(ERemoteStoragePublishedFileVisibility), state.Visibility);
                Require(SteamUGC.SetItemVisibility(handle, visibility), "Set visibility failed.");
                // AppData may be virtualized when launched by a packaged desktop host.
                // Use a normal user-profile copy that the external Steam client can read.
                string steamContent = plan.ContentDirectory;
                if (steamContent.StartsWith(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), StringComparison.OrdinalIgnoreCase))
                {
                    steamContent = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "SWD3ModStudio", "uploads", plan.OperationId);
                    Directory.CreateDirectory(steamContent);
                    string uploadFile = Path.Combine(steamContent, plan.FileName);
                    if (!File.Exists(uploadFile)) File.Copy(Path.Combine(plan.ContentDirectory, plan.FileName), uploadFile);
                    locks.Add(new FileStream(uploadFile, FileMode.Open, FileAccess.Read, FileShare.Read));
                    Require(Directory.GetFiles(steamContent, "*", SearchOption.AllDirectories).Length == 1 && HashFile(uploadFile) == plan.ContentSha256, "Upload copy differs from reviewed snapshot.");
                    Emit("upload-copy", new { folder = steamContent, sha256 = plan.ContentSha256 });
                }
                Require(SteamUGC.SetItemContent(handle, steamContent), "Set content failed.");
                if (!String.IsNullOrEmpty(plan.PreviewFile)) Require(SteamUGC.SetItemPreview(handle, plan.PreviewFile), "Set preview failed.");
                string[] values = { plan.Version, plan.FileName, plan.ContentSha256, plan.OperationId, plan.Language };
                for (int index = 0; index < ReleaseKeys.Length; index++)
                {
                    string key = TagPrefix + ReleaseKeys[index];
                    Require(SteamUGC.RemoveItemKeyValueTags(handle, key), "Cannot clear previous " + key);
                    Require(SteamUGC.AddItemKeyValueTag(handle, key, values[index]), "Cannot set " + key);
                }
                SaveRelease(path, state, "submit-intent");
                var result = Wait<SubmitItemUpdateResult_t>(SteamUGC.SubmitItemUpdate(handle, plan.ChangeNote), "submit", delegate
                {
                    ulong processed, total;
                    var status = SteamUGC.GetItemUpdateProgress(handle, out processed, out total);
                    Emit("progress", new { status = status.ToString(), processed = processed.ToString(), total = total.ToString(), workshopId = state.WorkshopId });
                });
                Emit("submit-result", new { result = result.m_eResult.ToString(), workshopId = result.m_nPublishedFileId.ToString(), needsAgreement = result.m_bUserNeedsToAcceptWorkshopLegalAgreement });
                Require(result.m_nPublishedFileId.ToString() == state.WorkshopId, "Submit callback item mismatch.");
                state.NeedsAgreement = result.m_bUserNeedsToAcceptWorkshopLegalAgreement;
                state.SubmitResult = result.m_eResult.ToString();
                SaveRelease(path, state, result.m_eResult == EResult.k_EResultOK ? "verification-pending" : "submit-rejected");
                if (result.m_eResult != EResult.k_EResultOK)
                {
                    try { state.After = Details(state.WorkshopId); state.AfterFiles = DownloadFiles(state.WorkshopId); }
                    catch (Exception ex) { state.LastError = "Rejected submission; remote inspection incomplete: " + ex.Message; }
                    SaveRelease(path, state, "submit-rejected");
                    Emit("release-rejected", new { expected = plan, actual = state.After, files = state.AfterFiles, result = state.SubmitResult });
                }
                Require(result.m_eResult == EResult.k_EResultOK && !state.NeedsAgreement, "Submission requires reconciliation: " + result.m_eResult);
            }
            finally { foreach (var stream in locks) stream.Dispose(); }
            if (SyncDefault(plan)) SubmitDefaultLanguage(plan, state, path);
            VerifyRelease(plan, state, path);
        }

        static void SubmitDefaultLanguage(ReleasePlan plan, ReleaseState state, string path)
        {
            var handle = SteamUGC.StartItemUpdate(new AppId_t(App), ParseId(state.WorkshopId));
            Require(handle != UGCUpdateHandle_t.Invalid && SteamUGC.SetItemUpdateLanguage(handle, "english"), "Cannot start default-language update.");
            Require(SteamUGC.SetItemTitle(handle, plan.Title) && SteamUGC.SetItemDescription(handle, plan.Description), "Cannot set default-language title/description.");
            SaveRelease(path, state, "default-submit-intent");
            var result = Wait<SubmitItemUpdateResult_t>(SteamUGC.SubmitItemUpdate(handle, null), "default-language-submit", null);
            Require(result.m_nPublishedFileId.ToString() == state.WorkshopId, "Default-language callback ID mismatch.");
            state.DefaultSubmitResult = result.m_eResult.ToString();
            state.NeedsAgreement = result.m_bUserNeedsToAcceptWorkshopLegalAgreement;
            SaveRelease(path, state, result.m_eResult == EResult.k_EResultOK ? "verification-pending" : "default-submit-rejected");
            Emit("default-language-result", new { result = state.DefaultSubmitResult, workshopId = state.WorkshopId, needsAgreement = state.NeedsAgreement });
            Require(result.m_eResult == EResult.k_EResultOK && !state.NeedsAgreement, "Default-language update needs reconciliation.");
        }

        static void CloseRelease(ReleasePlan plan, ReleaseState state, string path)
        {
            Require(state.Before != null && !String.IsNullOrEmpty(state.SubmitResult) && state.SubmitResult != EResult.k_EResultOK.ToString(),
                "Only an explicitly rejected update can be closed; unknown results cannot be assumed cancelled.");
            var remote = Details(state.WorkshopId); CheckOwner(remote, state.WorkshopId);
            var files = DownloadFiles(state.WorkshopId);
            Require(ObjectHash(StableItem(remote)) == ObjectHash(StableItem(state.Before)) && ObjectHash(files) == ObjectHash(state.BeforeFiles),
                "Remote differs from the previous release; cannot close as unchanged.");
            state.After = remote; state.AfterFiles = files;
            SaveRelease(path, state, "closed-unchanged");
            Output("release-closed", new { workshopId = state.WorkshopId, rejectedResult = state.SubmitResult, remoteUnchanged = true });
        }

        static void VerifyFields(ReleasePlan plan, ReleaseState state, Item remote, List<DownloadedFile> files)
        {
            CheckOwner(remote, state.WorkshopId);
            Require(remote.Title == plan.Title, "Remote title mismatch.");
            Require(remote.Description == plan.Description, "Remote description mismatch.");
            Require(remote.Visibility == state.Visibility, "Remote visibility mismatch.");
            string[] values = { plan.Version, plan.FileName, plan.ContentSha256, plan.OperationId, plan.Language };
            for (int index = 0; index < ReleaseKeys.Length; index++) Require(TagValue(remote, ReleaseKeys[index]) == values[index], "Remote " + ReleaseKeys[index] + " mismatch.");
            Require(files != null && files.Count == 1 && files[0].FileName == plan.FileName && files[0].Size == plan.ContentSize && files[0].Sha256 == plan.ContentSha256, "Downloaded files/name/size/SHA-256 mismatch.");
            CheckPackage(plan, files[0].Package);
            if (state.Before != null)
            {
                Require(remote.Metadata == state.Before.Metadata, "Original metadata unexpectedly changed.");
                foreach (var tag in state.Before.KeyValues.Where(t => !ReleaseKeys.Select(k => TagPrefix + k).Contains(t.Key)))
                {
                    List<string> valuesAfter;
                    Require(remote.KeyValues.TryGetValue(tag.Key, out valuesAfter) && tag.Value.OrderBy(v => v).SequenceEqual(valuesAfter.OrderBy(v => v)), "Original custom tags unexpectedly changed.");
                }
            }
            Require(!String.IsNullOrEmpty(remote.PreviewUrl), "Remote preview missing.");
        }

        static void VerifyRelease(ReleasePlan plan, ReleaseState state, string path)
        {
            Require(!String.IsNullOrEmpty(state.WorkshopId), "No Workshop ID to verify; inspect author list before any further create.");
            // A reviewed but unsubmitted plan cannot be promoted or block another operation.
            Require(state.Phase != "reviewed", "Release has not been submitted.");
            try
            {
                state.ReviewedPlan = plan;
                var remote = Details(state.WorkshopId); CheckOwner(remote, state.WorkshopId);
                var files = DownloadFiles(state.WorkshopId);
                state.After = remote; state.AfterFiles = files;
                VerifyFields(plan, state, remote, files);
                if (SyncDefault(plan))
                {
                    state.AfterDefault = DetailsInLanguage(state.WorkshopId, "english");
                    CheckDefaultLanguage(plan, state, state.AfterDefault);
                }
                Require(ObjectHash(StableItem(remote)) == ObjectHash(StableItem(Details(state.WorkshopId))), "Remote changed during download verification.");
                state.LastError = null; state.VerifiedAt = DateTime.UtcNow.ToString("o");
                SaveRelease(path, state, "verified");
                AtomicSave(Path.Combine(StoreRoot(), "history-" + state.WorkshopId + "-" + plan.OperationId + ".json"), new { plan = plan, result = state });
                Output("release-verified", new { workshopId = state.WorkshopId, version = plan.Version, item = remote, files = files, defaultLanguage = state.AfterDefault,
                    verifiedLanguages = SyncDefault(plan) ? new[] { plan.Language, "english" } : new[] { plan.Language },
                    checks = new[] { "title", "description", "visibility", "version", "file-name", "file-size", "file-sha256", "downloaded-MODVersion", "operation", "preserved-metadata" }, verifiedAt = state.VerifiedAt });
            }
            catch (Exception ex)
            {
                state.LastError = ex.Message; SaveRelease(path, state, "verification-pending");
                Emit("release-verification-failed", new { expected = plan, actual = state.After, files = state.AfterFiles, error = ex.Message });
                throw;
            }
        }

        static void CheckDefaultLanguage(ReleasePlan plan, ReleaseState state, Item remote)
        {
            CheckOwner(remote, state.WorkshopId);
            Require(remote.Title == plan.Title && remote.Description == plan.Description,
                "Default-language title/description mismatch; update is not fully verified.");
        }

        static void ReleaseSelfTest()
        {
            int passed = 0;
            Action<Action> rejects = action => { bool rejected = false; try { action(); } catch (InvalidOperationException) { rejected = true; } Require(rejected, "Release guard accepted invalid input."); passed++; };
            rejects(() => ParseVersion("1.2.3")); rejects(() => ParseVersion("01.2"));
            Require(ParseVersion("0.12") > ParseVersion("0.9"), "Version compared lexically."); passed++;
            var plan = new ReleasePlan { Version = "0.3", FileName = "fixture.ssmod", ContentSize = 50, ContentSha256 = "HASH", Title = "Title", Description = "Description", OperationId = "operation", Language = "tchinese" };
            var package = new PackageInfo { Version = plan.Version, FileName = plan.FileName, Size = plan.ContentSize, Sha256 = plan.ContentSha256 };
            var files = new List<DownloadedFile> { new DownloadedFile { FileName = plan.FileName, Size = plan.ContentSize, Sha256 = plan.ContentSha256, Package = package } };
            var state = new ReleaseState { WorkshopId = "123", Visibility = "private" };
            Account = "42";
            var remote = new Item { Id = "123", Owner = Account, OwnedByCurrentUser = true, AppId = App, Title = plan.Title, Description = plan.Description,
                Visibility = state.Visibility, PreviewUrl = "preview", KeyValues = new Dictionary<string, List<string>>() };
            string[] values = { plan.Version, plan.FileName, plan.ContentSha256, plan.OperationId, plan.Language };
            for (int i = 0; i < ReleaseKeys.Length; i++) remote.KeyValues.Add(TagPrefix + ReleaseKeys[i], new List<string> { values[i] });
            VerifyFields(plan, state, remote, files); passed++;
            remote.Title = "old"; rejects(() => VerifyFields(plan, state, remote, files)); remote.Title = plan.Title;
            remote.Description = "old"; rejects(() => VerifyFields(plan, state, remote, files)); remote.Description = plan.Description;
            remote.Title = "old default"; rejects(() => CheckDefaultLanguage(plan, state, remote)); remote.Title = plan.Title;
            remote.Description = "old default"; rejects(() => CheckDefaultLanguage(plan, state, remote)); remote.Description = plan.Description;
            files[0].FileName = "old.ssmod"; rejects(() => VerifyFields(plan, state, remote, files)); files[0].FileName = plan.FileName;
            files[0].Size = 49; rejects(() => VerifyFields(plan, state, remote, files)); files[0].Size = plan.ContentSize;
            files[0].Sha256 = "OLD"; rejects(() => VerifyFields(plan, state, remote, files)); files[0].Sha256 = plan.ContentSha256;
            package.Version = "0.2"; rejects(() => VerifyFields(plan, state, remote, files)); package.Version = plan.Version;
            remote.KeyValues[TagPrefix + "Version"].Add("0.2"); rejects(() => VerifyFields(plan, state, remote, files)); remote.KeyValues[TagPrefix + "Version"].RemoveAt(1);
            remote.Owner = "other"; rejects(() => VerifyFields(plan, state, remote, files)); remote.Owner = Account;
            files[0].Sha256 = "OLD"; rejects(() => CheckVersionAdvance(plan, files)); files[0].Sha256 = plan.ContentSha256;
            package.Version = "0.4"; rejects(() => CheckVersionAdvance(plan, files)); package.Version = "0.2";
            CheckVersionAdvance(plan, files); passed++;
            var original = ObjectHash(plan); plan.Title += " changed"; Require(original != ObjectHash(plan), "Reviewed plan mutation undetected."); passed++;
            Emit("release-self-test", new { passed = passed, steamInitialized = false });
        }
    }
}
