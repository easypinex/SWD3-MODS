using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace Swd3ModStudio.Desktop
{
    public static class Data
    {
        public static readonly UTF8Encoding Utf8 = new UTF8Encoding(false);
        public static JavaScriptSerializer Serializer() { return new JavaScriptSerializer { MaxJsonLength = 33554432 }; }
        public static Dictionary<string, object> Map(object value) { return value as Dictionary<string, object> ?? new Dictionary<string, object>(); }
        public static object Get(object obj, string key) { object value; return Map(obj).TryGetValue(key, out value) ? value : null; }
        public static string Text(object obj, string key) { return Convert.ToString(Get(obj, key), System.Globalization.CultureInfo.InvariantCulture) ?? ""; }
        public static IEnumerable<object> Rows(object value) { var array = value as IEnumerable; if (array == null || value is string) yield break; foreach (var row in array) yield return row; }
        public static Dictionary<string, object> Read(string path) { return Map(Serializer().DeserializeObject(File.ReadAllText(path, Utf8))); }
        public static string Encode(object value) { return Serializer().Serialize(value); }
        public static string Hash(string path) { using (var stream = File.OpenRead(path)) using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", ""); }
        public static void Save(string path, object value)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path)));
            string temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                { byte[] bytes = Utf8.GetBytes(Encode(value)); stream.Write(bytes, 0, bytes.Length); stream.Flush(true); }
                if (File.Exists(path)) File.Replace(temp, path, path + ".bak"); else File.Move(temp, path);
            }
            finally { if (File.Exists(temp)) File.Delete(temp); }
        }
        public static string WorkshopId(string input)
        {
            string value = (input ?? "").Trim();
            Uri uri;
            if (Uri.TryCreate(value, UriKind.Absolute, out uri))
            {
                if (uri.Scheme != "https" || uri.Host != "steamcommunity.com") throw new InvalidOperationException("請輸入 Steam 工作坊網址或數字 ID。");
                var query = System.Web.HttpUtility.ParseQueryString(uri.Query); value = query["id"];
            }
            ulong id;
            if (!UInt64.TryParse(value, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out id) || id == 0)
                throw new InvalidOperationException("作品 ID 必須是大於零的十進位數字。");
            return id.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }
        public static string Quote(string value)
        {
            // Windows CRT argv escaping, including trailing backslashes and quotes.
            var result = new StringBuilder("\""); int slashes = 0;
            foreach (char c in value)
            {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') { result.Append('\\', slashes * 2 + 1); result.Append(c); }
                else { result.Append('\\', slashes); result.Append(c); }
                slashes = 0;
            }
            result.Append('\\', slashes * 2); result.Append('"'); return result.ToString();
        }
        public static string Phase(string value)
        {
            switch (value)
            {
                case "reviewed": return "等待確認發佈";
                case "create-intent": return "正在建立作品，結果待確認";
                case "created": return "作品 ID 已保存，尚待提交";
                case "submit-intent": return "正在上傳，結果待確認";
                case "default-submit-intent": return "同步預設語言中";
                case "verification-pending": case "remote-confirmed": return "已送出，等待核對";
                case "verified": return "已驗證完成";
                case "submit-rejected": case "default-submit-rejected": return "Steam 拒絕提交，請重新核對";
                case "needs-agreement": return "需要在 Steam 接受工作坊協議";
                case "closed-unchanged": return "已結案，遠端沒有變更";
                default: return String.IsNullOrEmpty(value) ? "尚未送出" : value;
            }
        }
    }

    public sealed class Draft
    {
        public string Key { get; set; }
        public string SteamId { get; set; }
        public string WorkshopId { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string Package { get; set; }
        public string PreviewFile { get; set; }
        public string Language { get; set; }
        public string Visibility { get; set; }
        public string ChangeNote { get; set; }
        public string SavedAt { get; set; }
        public string Summary { get { return String.IsNullOrEmpty(WorkshopId) ? "新作品草稿" : "更新作品 " + WorkshopId; } }
    }
    public sealed class WorkRow
    {
        public string Id { get; set; }
        public string Title { get; set; }
        public string Version { get; set; }
        public string Visibility { get; set; }
        public Dictionary<string, object> Raw { get; set; }
        public string Summary { get { return Id + "   ·   " + (String.IsNullOrEmpty(Version) ? "版本待查詢" : "v" + Version) + "   ·   " + Visibility; } }
    }
    public sealed class OperationRow
    {
        public string DirectoryPath { get; set; }
        public string Title { get; set; }
        public string WorkshopId { get; set; }
        public string Version { get; set; }
        public string Status { get; set; }
        public string Time { get; set; }
    }
    public sealed class CheckRow
    {
        public string Field { get; set; }
        public string Before { get; set; }
        public string Expected { get; set; }
        public string Actual { get; set; }
        public string Status { get; set; }
    }
    public sealed class RunResult
    {
        public int ExitCode;
        public string Error;
        public readonly List<Dictionary<string, object>> Events = new List<Dictionary<string, object>>();
        public object Payload(string kind) { return Events.Where(e => Data.Text(e, "kind") == kind).Select(e => Data.Get(e, "data")).LastOrDefault(); }
    }
    public sealed class WorkerClient
    {
        public string Root;
        public Action<Dictionary<string, object>> OnEvent;
        public WorkerClient(string root) { Root = root; }
        public void VerifyBuild()
        {
            var fingerprint = Data.Read(Path.Combine(Root, "build-fingerprint.json"));
            var expected = new Dictionary<string, string> {
                { "SteamPrototype.exe", Data.Text(fingerprint,"ExecutableSHA256") },
                { "SteamReleasePackage.py", Data.Text(fingerprint,"PackageInspectorSHA256") },
                { "package-runtime.json", Data.Text(fingerprint,"PackageRuntimeSHA256") } };
            foreach (var dep in Data.Rows(Data.Get(fingerprint,"Dependencies"))) expected.Add(Data.Text(dep,"Name"), Data.Text(dep,"SHA256"));
            foreach (var pair in expected) if (Data.Hash(Path.Combine(Root,pair.Key)) != pair.Value) throw new InvalidOperationException("工具檔案與建置紀錄不符，請重新建置：" + pair.Key);
        }
        public async Task<RunResult> Run(string command, IDictionary<string, string> options, string log, CancellationToken token)
        {
            VerifyBuild();
            var args = new List<string> { command };
            foreach (var pair in options) { args.Add("--" + pair.Key); args.Add(pair.Value); }
            return await RunProcess(Path.Combine(Root,"SteamPrototype.exe"), args, Root, log, token, OnEvent);
        }
        public static async Task<RunResult> RunProcess(string exe, IEnumerable<string> args, string cwd, string log, CancellationToken token, Action<Dictionary<string,object>> callback)
        {
            return await Task.Run(async delegate
            {
                Directory.CreateDirectory(Path.GetDirectoryName(log));
                var result = new RunResult(); var gate = new object();
                using (var writer = new StreamWriter(new FileStream(log,FileMode.CreateNew,FileAccess.Write,FileShare.Read),Data.Utf8))
                using (var process = new Process())
                using (var limit = CancellationTokenSource.CreateLinkedTokenSource(token))
                {
                    limit.CancelAfter(TimeSpan.FromMinutes(30));
                    process.StartInfo = new ProcessStartInfo(exe, String.Join(" ", args.Select(Data.Quote))) {
                        WorkingDirectory=cwd, UseShellExecute=false, CreateNoWindow=true,
                        RedirectStandardOutput=true, RedirectStandardError=true, StandardOutputEncoding=Data.Utf8, StandardErrorEncoding=Data.Utf8 };
                    if (!process.Start()) throw new IOException("無法啟動背景工作者。");
                    using (limit.Token.Register(delegate { try { if (!process.HasExited) process.Kill(); } catch (InvalidOperationException) { } }))
                    {
                        Func<StreamReader,bool,Task> read = async (reader, error) => {
                            string line;
                            while ((line = await reader.ReadLineAsync()) != null)
                            {
                                Dictionary<string,object> record = null;
                                lock(gate) { writer.WriteLine(line); writer.Flush(); if(error) result.Error = line; }
                                if (!error && line.StartsWith("{",StringComparison.Ordinal))
                                {
                                    try { record=Data.Map(Data.Serializer().DeserializeObject(line)); }
                                    catch (ArgumentException) { }
                                    if(record != null)
                                    {
                                        lock(gate) result.Events.Add(record);
                                        if(callback != null) callback(record);
                                    }
                                }
                            }
                        };
                        await Task.WhenAll(read(process.StandardOutput,false),read(process.StandardError,true));
                        process.WaitForExit(); result.ExitCode=process.ExitCode;
                    }
                    if(limit.IsCancellationRequested) throw new OperationCanceledException("已停止等待。Steam 可能仍在處理，請由發佈紀錄重新核對結果。",limit.Token);
                }
                return result;
            });
        }
    }
}
