using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace Swd3ModStudio.Desktop
{
    public static class DeveloperBridge
    {
        [STAThread] public static int Main()
        {
            try {
                string game=AppDomain.CurrentDomain.BaseDirectory;
                var state=Data.Read(Path.Combine(game,"SWD3ModStudio.developer.json"));
                string target=Data.Text(state,"StudioPath");
                if(Data.Text(state,"Scope")!="DeveloperMenu"||!Path.IsPathRooted(target)||!File.Exists(target)||!String.Equals(Path.GetFileName(target),"SWD3ModStudio.exe",StringComparison.OrdinalIgnoreCase))throw new IOException("找不到 MOD Studio，請從新版桌面重新設定開發工具入口，或還原原版開發工具。");
                using(var child=Process.Start(new ProcessStartInfo(target,"--steam-entry-game "+Data.Quote(game)){UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(target)})){return child==null?1:0;}
            }catch(Exception ex){MessageBox.Show(ex.Message,"Steam 模組開發工具",MessageBoxButtons.OK,MessageBoxIcon.Warning);return 1;}
        }
    }
}
