using System;
using System.IO;
using System.Windows.Forms;

namespace Swd3ModStudio.Desktop
{
    public static class SteamEntryMain
    {
        [STAThread] public static int Main(string[] args)
        {
            string game=AppDomain.CurrentDomain.BaseDirectory;
            try {
                var state=Data.Read(Path.Combine(game,SteamEntry.RecordName));
                string target=Data.Text(state,"StudioPath");
                if(!Path.IsPathRooted(target)||!File.Exists(target)||!String.Equals(Path.GetFileName(target),"SWD3ModStudio.exe",StringComparison.OrdinalIgnoreCase))throw new IOException("找不到 MOD Studio，請重新設定接管位置。");
                using(var child=SteamEntry.Start(target,Path.GetDirectoryName(target),new[]{"--steam-entry-game",game})) { return child==null?1:0; }
            } catch(Exception ex) {
                if(MessageBox.Show("無法開啟 MOD Studio：\n"+ex.Message+"\n\n是否開啟保留的原工具？","Steam 啟動入口",MessageBoxButtons.YesNo,MessageBoxIcon.Warning)==DialogResult.Yes) {
                    try {using(var original=SteamEntry.Start(SteamEntry.Original(game),game,new string[0])){original.WaitForExit();return original.ExitCode;}}
                    catch(Exception fallback){MessageBox.Show(fallback.Message,"原工具無法開啟");}
                }
                return 1;
            }
        }
    }
}
