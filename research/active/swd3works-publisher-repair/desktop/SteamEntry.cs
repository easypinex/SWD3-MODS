using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;

namespace Swd3ModStudio.Desktop
{
    // Only the known publisher executable is replaced. All backups stay beside it
    // so its original StartupPath-based resource and Tools lookups still work.
    public static class SteamEntry
    {
        public const string OriginalHash="756D9E2F9866EC335F8A536B9ED0DE2869BBE83FF3D5BF468E0F8A2E3C0330FA";
        public const string RecordName="SWD3ModStudio.entry.json";
        public const string BackupName="SWD3Works.original.exe";
        static string Full(string path) { return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar); }
        static void Plain(string path)
        {
            for(string p=Path.GetFullPath(path);!String.IsNullOrEmpty(p);p=Path.GetDirectoryName(p))
                if((File.Exists(p)||Directory.Exists(p))&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)
                    throw new IOException("接管路徑不能經過連結或接合點："+p);
        }
        public static string Game(string path)
        {
            string game=Full(path); Plain(game);
            if(!File.Exists(Path.Combine(game,"swd3.exe"))) throw new IOException("請選擇含 swd3.exe 的遊戲資料夾。");
            return game;
        }
        static string ReadHash(string path) { return File.Exists(path)?Data.Hash(path):""; }
        static bool Owned(object state,string hash)
        {
            return !String.IsNullOrEmpty(hash) && Data.Rows(Data.Get(state,"EntryHashes")).Any(x=>String.Equals(Convert.ToString(x),hash,StringComparison.OrdinalIgnoreCase));
        }
        static void CopyOnce(string source,string destination)
        {
            Plain(destination);
            if(File.Exists(destination)) { if(Data.Hash(source)!=Data.Hash(destination)) throw new IOException("備份與目前原檔不同，已停止，保留現有備份："+destination); return; }
            File.Copy(source,destination,false);
            if(Data.Hash(source)!=Data.Hash(destination)) throw new IOException("備份核對失敗。");
        }
        static void Replace(string source,string destination)
        {
            string temp=destination+"."+Guid.NewGuid().ToString("N")+".tmp";
            try { File.Copy(source,temp,false); if(Data.Hash(source)!=Data.Hash(temp))throw new IOException("入口副本核對失敗。"); File.Replace(temp,destination,null); }
            finally { if(File.Exists(temp))File.Delete(temp); }
        }
        public static string Status(string path)
        {
            string game=Game(path), exe=Path.Combine(game,"SWD3Works.exe"), record=Path.Combine(game,RecordName);
            string hash=ReadHash(exe);
            if(hash==OriginalHash) return File.Exists(record)?"原版入口（尚未接管、已還原或被 Steam 還原）":"原版入口，尚未接管";
            if(File.Exists(record)) {
                var state=Data.Read(record);
                if(Owned(state,hash)) {
                    string target=Data.Text(state,"StudioPath");
                    return File.Exists(target)?"已接管 → "+target:"已接管，但找不到桌面程式；請還原或重新接管";
                }
            }
            return "入口版本不符或已被其他程式修改；不會覆蓋";
        }
        public static void Install(string path,string studioRoot)
        {
            string game=Game(path), root=Full(studioRoot); Plain(root);
            if(root.Equals(game,StringComparison.OrdinalIgnoreCase)||root.StartsWith(game+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new IOException("請將完整桌面程式放在遊戲以外的固定資料夾。");
            string target=Path.Combine(root,"SWD3ModStudio.exe"), shim=Path.Combine(root,"SteamEntry.exe");
            var build=Data.Read(Path.Combine(root,"desktop-fingerprint.json"));
            if(ReadHash(target)!=Data.Text(build,"ExecutableSHA256")||ReadHash(shim)!=Data.Text(build,"SteamEntrySHA256")||!File.Exists(target)||!File.Exists(shim)) throw new IOException("桌面程式或啟動轉接程式的指紋不符，請重新解壓。");
            new WorkerClient(Path.Combine(root,"worker")).VerifyBuild();
            using(var gate=new Mutex(false,"Local\\SWD3ModStudio-Entry-"+Data.Hash(Path.Combine(game,"swd3.exe")).Substring(0,16))) {
                bool held=false;
                try { try{held=gate.WaitOne(0);}catch(AbandonedMutexException){held=true;} if(!held)throw new IOException("另一個接管操作正在執行。");
                    string exe=Path.Combine(game,"SWD3Works.exe"), record=Path.Combine(game,RecordName), backup=Path.Combine(game,BackupName);
                    foreach(string p in new[]{exe,record,record+".bak",backup,backup+".config"})Plain(p);
                    var state=File.Exists(record)?Data.Read(record):Data.Map(null);
                    string current=ReadHash(exe), shimHash=Data.Hash(shim);
                    if(current!=OriginalHash&&!Owned(state,current))throw new IOException("原工具版本不符或入口被修改，已停止接管。");
                    if(current==OriginalHash)CopyOnce(exe,backup);
                    if(ReadHash(backup)!=OriginalHash)throw new IOException("原版備份缺失或雜湊不符，已停止。");
                    string config=exe+".config";
                    if(File.Exists(config)) { Plain(config); CopyOnce(config,backup+".config"); }
                    var hashes=Data.Rows(Data.Get(state,"EntryHashes")).Select(Convert.ToString).Concat(new[]{shimHash}).Distinct().ToArray();
                    // Persist the launch target and both old/new shim hashes before the
                    // atomic swap. Interrupted installs remain restorable/re-runnable.
                    Data.Save(record,new{Schema=1,OriginalSHA256=OriginalHash,EntryHashes=hashes,StudioPath=target,InstalledAt=DateTime.UtcNow.ToString("o")});
                    if(current!=shimHash)Replace(shim,exe);
                    if(Data.Hash(exe)!=shimHash)throw new IOException("入口替換後核對失敗。");
                } finally {if(held)gate.ReleaseMutex();}
            }
        }
        public static void Restore(string path)
        {
            string game=Game(path), exe=Path.Combine(game,"SWD3Works.exe"), backup=Path.Combine(game,BackupName), record=Path.Combine(game,RecordName);
            foreach(string p in new[]{exe,backup,record})Plain(p);
            using(var gate=new Mutex(false,"Local\\SWD3ModStudio-Entry-"+Data.Hash(Path.Combine(game,"swd3.exe")).Substring(0,16))) {
                bool held=false;
                try {try{held=gate.WaitOne(0);}catch(AbandonedMutexException){held=true;}if(!held)throw new IOException("另一個接管操作正在執行。");
                    string hash=ReadHash(exe);
                    if(hash==OriginalHash)return;
                    if(!File.Exists(record)||!Owned(Data.Read(record),hash))throw new IOException("目前入口並非已登記的轉接程式，拒絕覆蓋。");
                    if(ReadHash(backup)!=OriginalHash)throw new IOException("原版備份缺失或已變更，拒絕還原。");
                    Replace(backup,exe);
                    if(Data.Hash(exe)!=OriginalHash)throw new IOException("原版還原核對失敗。");
                    // Keep verified backups and journal for repair/reinstallation.
                } finally {if(held)gate.ReleaseMutex();}
            }
        }
        public static string Original(string path)
        {
            RequireGameStopped();
            string game=Game(path), normal=Path.Combine(game,"SWD3Works.exe"), backup=Path.Combine(game,BackupName);
            if(ReadHash(normal)==OriginalHash)return normal;
            if(ReadHash(backup)==OriginalHash)return backup;
            throw new IOException("找不到已驗證的原工具，請從 Steam 還原遊戲檔案。");
        }
        public static void RequireGameStopped()
        {
            foreach(string name in new[]{"Xuan-Yuan Sword Mists Beyond the Mountains","Xuan-Yuan Sword Mists Beyond the Mountains(1999)"}) {
                Mutex active;
                if(Mutex.TryOpenExisting(name,out active)) {active.Dispose();throw new IOException("遊戲仍在執行，請先正常關閉遊戲。原工具在遊戲執行時會自行退出；不會重複啟動遊戲。");}
            }
        }
        public static Process Start(string executable,string workingDirectory,string[] args)
        {
            return Process.Start(new ProcessStartInfo(executable,String.Join(" ",args.Select(Data.Quote))){WorkingDirectory=workingDirectory,UseShellExecute=false});
        }
    }
}
