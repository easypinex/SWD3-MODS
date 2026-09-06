using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;

namespace Swd3ModStudio.Desktop
{
    public static class Entry
    {
        [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr handle);
        [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool ShowWindow(IntPtr handle,int command);
        [STAThread] public static int Main(string[] args)
        {
            if(args.Length>0 && (args[0]=="--test-child" || args[0]=="--self-test" || args[0]=="--steam-entry")) {
                Console.SetOut(new StreamWriter(Console.OpenStandardOutput(),Data.Utf8){AutoFlush=true});
                Console.SetError(new StreamWriter(Console.OpenStandardError(),Data.Utf8){AutoFlush=true});
            }
            if (args.Length > 0 && args[0] == "--test-child") return DesktopTests.Child(args);
            if (args.Length > 0 && args[0] == "--self-test") return DesktopTests.Run().GetAwaiter().GetResult();
            if (args.Length > 0 && args[0] == "--steam-entry") {
                try {
                    if(args.Length!=3)throw new ArgumentException("--steam-entry status|install|restore <game-root>");
                    if(args[1]=="install")SteamEntry.Install(args[2],AppDomain.CurrentDomain.BaseDirectory);
                    else if(args[1]=="restore")SteamEntry.Restore(args[2]);
                    else if(args[1]!="status")throw new ArgumentException("Unknown entry command");
                    Console.WriteLine(Data.Encode(new{kind="steam-entry",status=SteamEntry.Status(args[2])}));return 0;
                }catch(Exception ex){Console.WriteLine(Data.Encode(new{kind="steam-entry-error",error=ex.Message}));return 1;}
            }
            if(args.Length==2 && args[0]=="--steam-entry-game") {
                try {SteamEntry.Game(args[1]);Data.Save(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"SWD3ModStudio","Desktop","steam-entry-settings.json"),new{GameRoot=Path.GetFullPath(args[1])});}catch(Exception){}
            }
            bool first;
            using (var mutex = new Mutex(true,"Local\\SWD3ModStudio-Desktop",out first))
            {
                if (!first) {
                    foreach(var process in Process.GetProcessesByName(Process.GetCurrentProcess().ProcessName))using(process) {
                        if(process.Id==Process.GetCurrentProcess().Id||process.MainWindowHandle==IntPtr.Zero)continue;
                        ShowWindow(process.MainWindowHandle,9);SetForegroundWindow(process.MainWindowHandle);return 0;
                    }
                    MessageBox.Show("MOD Studio 已在執行，請切換到已開啟的視窗。","MOD Studio"); return 0;
                }
                try
                {
                    var app = new Application();
                    Window window;
                    using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("MainWindow.xaml")) window=(Window)XamlReader.Load(stream);
                    var shell=new StudioShell(window,AppDomain.CurrentDomain.BaseDirectory);
                    app.DispatcherUnhandledException += delegate(object sender,DispatcherUnhandledExceptionEventArgs e) { shell.ShowError(e.Exception); e.Handled=true; };
                    return app.Run(window);
                }
                catch(Exception ex) { MessageBox.Show("無法開啟 MOD Studio：\n"+ex.Message,"MOD Studio",MessageBoxButton.OK,MessageBoxImage.Error); return 1; }
                finally { mutex.ReleaseMutex(); }
            }
        }
    }

    public sealed class StudioShell
    {
        readonly Window window;
        readonly WorkerClient worker;
        readonly string dataRoot;
        readonly string studioRoot;
        readonly DispatcherTimer saveTimer=new DispatcherTimer();
        readonly DispatcherTimer clock=new DispatcherTimer();
        readonly List<WorkRow> works=new List<WorkRow>();
        readonly List<string> externalOperations=new List<string>();
        readonly List<CheckRow> checks=new List<CheckRow>();
        readonly Stopwatch watch=new Stopwatch();
        string account="", persona="", operation=null, stage="就緒", lastLog="";
        Draft draft;
        bool busy, loadingForm, dirty, connected;
        int uiTicks;
        CancellationTokenSource cancellation;
        readonly string[] actionNames={"TakeoverButton","RestoreEntryButton","OriginalToolButton","StartGameButton","PickGameButton","RefreshButton","NewButton","ImportItemButton","PickPackageButton","RecoverPackageButton","ReloadTextButton","PickPreviewButton","ReviewButton","FilesButton","HistoryButton","HealthButton","ResumeButton","RetryReviewButton","CloseOperationButton","ImportOperationButton","ImportDraftButton"};
        public StudioShell(Window window,string root)
        {
            this.window=window; studioRoot=root; worker=new WorkerClient(Path.Combine(root,"worker"));
            dataRoot=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"SWD3ModStudio","Desktop");
            Directory.CreateDirectory(dataRoot);
            if(File.Exists(Path.Combine(dataRoot,"settings.json"))) { try {var settings=Data.Read(Path.Combine(dataRoot,"settings.json")); account=Data.WorkshopId(Data.Text(settings,"Account")); persona=Data.Text(settings,"Persona");} catch(Exception){account="";} }
            worker.OnEvent=record=>{if(!window.Dispatcher.HasShutdownStarted)window.Dispatcher.BeginInvoke(new Action(()=>HandleEvent(record)));};
            Nav("NavLibrary","Library"); Nav("NavEditor","Editor"); Nav("NavOperations","Operations"); Nav("NavSettings","Settings");
            Bind("RefreshButton",Refresh); Bind("HealthButton",Connect); Bind("NewButton",async delegate { SaveDraft(); NewDraft(); await Task.FromResult(0); });
            Bind("ImportItemButton",async delegate { await LoadItem(Data.WorkshopId(Box("ImportIdBox").Text)); });
            Bind("PickPackageButton",PickPackage); Bind("PickPreviewButton",PickPreview); Bind("ReviewButton",PrepareReview);
            Bind("RecoverPackageButton",RecoverPackage); Bind("ReloadTextButton",ReloadText);
            Bind("PublishButton",Publish); Bind("VerifyButton",Verify); Bind("FilesButton",Files); Bind("HistoryButton",History);
            Bind("ResumeButton",async delegate { var row=Control<DataGrid>("OperationGrid").SelectedItem as OperationRow; if(row==null) throw new InvalidOperationException("請先選取一筆發佈紀錄。"); OpenOperation(row.DirectoryPath); await Task.FromResult(0); });
            Bind("RetryReviewButton",RetryReview); Bind("ImportOperationButton",ImportOperation); Bind("ImportDraftButton",ImportDraft);
            Bind("CloseOperationButton",async delegate { var row=Control<DataGrid>("OperationGrid").SelectedItem as OperationRow; if(row==null)throw new InvalidOperationException("請先選取已被拒絕的操作。");OpenOperation(row.DirectoryPath);await Call("close-release",OpOptions(),"release-closed");RenderReview(operation);Notice("已確認 Steam 內容未變更並結案。可重新準備下一次更新。",false); });
            Button("SaveDraftButton").Click+=delegate { try { SaveDraft(); Notice("草稿已保存。",false); } catch(Exception ex){ShowError(ex);} };
            Button("ExportDraftButton").Click+=delegate { try { ExportDraft(); } catch(Exception ex){ShowError(ex);} };
            Button("ReportButton").Click+=delegate { try { ExportReport(); } catch(Exception ex){ShowError(ex);} };
            Button("DataFolderButton").Click+=delegate { Process.Start(new ProcessStartInfo(dataRoot){UseShellExecute=true}); };
            Button("CopyLogButton").Click+=delegate { try { Clipboard.SetText(Box("LogBox").Text); Notice("診斷紀錄已複製。",false); } catch(Exception ex){ShowError(ex);} };
            Button("PickGameButton").Click+=delegate {try {
                var picker=new OpenFileDialog{Title="選擇 Steam 高清版的 swd3.exe",Filter="遊戲程式|swd3.exe"};
                if(picker.ShowDialog(window)==true){Box("GameRootBox").Text=Path.GetDirectoryName(picker.FileName);SaveEntrySettings();RefreshEntry();}
            }catch(Exception ex){ShowError(ex);} };
            Button("EntryStatusButton").Click+=delegate {try{RefreshEntry();}catch(Exception ex){ShowError(ex);} };
            Bind("TakeoverButton",async delegate {SaveEntrySettings();SteamEntry.Install(Box("GameRootBox").Text,studioRoot);RefreshEntry();Notice("已接管 Steam 啟動入口，原工具已備份。",false);await Task.FromResult(0);});
            Bind("RestoreEntryButton",async delegate {SteamEntry.Restore(Box("GameRootBox").Text);RefreshEntry();Notice("已還原原版 Steam 入口，備份與草稿均保留。",false);await Task.FromResult(0);});
            Bind("OriginalToolButton",async delegate {string game=SteamEntry.Game(Box("GameRootBox").Text);SteamEntry.Start(SteamEntry.Original(game),game,new string[0]);await Task.FromResult(0);});
            Bind("StartGameButton",async delegate {string game=SteamEntry.Game(Box("GameRootBox").Text);SteamEntry.RequireGameStopped();SteamEntry.Start(Path.Combine(game,"swd3.exe"),game,new string[0]);Notice("已送出啟動要求；請以遊戲視窗出現為準。",false);await Task.FromResult(0);});
            try {string entrySettings=Path.Combine(dataRoot,"steam-entry-settings.json");if(File.Exists(entrySettings)){Box("GameRootBox").Text=Data.Text(Data.Read(entrySettings),"GameRoot");RefreshEntry();}}catch(Exception ex){Text("EntryStatus").Text=ex.Message;}
            Button("OpenOperationFolder").Click+=delegate { var row=Control<DataGrid>("OperationGrid").SelectedItem as OperationRow; if(row!=null) Process.Start(new ProcessStartInfo(row.DirectoryPath){UseShellExecute=true}); };
            Button("StopButton").Click+=delegate { if(cancellation!=null) { cancellation.Cancel(); Notice("已停止本機等待；請稍後由發佈紀錄重新核對，Steam 不一定已取消。",true); } };
            Box("SearchBox").TextChanged+=delegate { FilterWorks(); };
            Control<ListBox>("WorkList").MouseDoubleClick+=async delegate { var row=Control<ListBox>("WorkList").SelectedItem as WorkRow; if(row!=null) await RunUi(()=>LoadItem(row.Id)); };
            Control<ListBox>("DraftList").MouseDoubleClick+=delegate { if(busy)return; var row=Control<ListBox>("DraftList").SelectedItem as Draft; if(row!=null) { SaveDraft(); SetDraft(row); Page("Editor"); } };
            foreach(string name in new[]{"TitleBox","DescriptionBox","ChangeNoteBox","PackageBox","PreviewBox"}) Box(name).TextChanged+=delegate { MarkDirty(); };
            Control<ComboBox>("LanguageBox").SelectionChanged+=delegate { MarkDirty(); };
            Control<ComboBox>("VisibilityBox").SelectionChanged+=delegate { MarkDirty(); };
            saveTimer.Interval=TimeSpan.FromMilliseconds(900); saveTimer.Tick+=delegate { saveTimer.Stop(); try { SaveDraft(); }catch(Exception ex){ShowError(ex);} };
            clock.Interval=TimeSpan.FromMilliseconds(250); clock.Tick+=delegate { uiTicks++; Text("ActivityText").Text=stage+(busy?"  ·  "+watch.Elapsed.ToString(@"mm\:ss"):""); }; clock.Start();
            window.Closing+=delegate(object sender,System.ComponentModel.CancelEventArgs e) {
                if(busy && MessageBox.Show(window,"目前仍在處理中。關閉後必須重新核對結果，是否關閉？","關閉 MOD Studio",MessageBoxButton.YesNo,MessageBoxImage.Question)!=MessageBoxResult.Yes){e.Cancel=true;return;}
                try{SaveDraft();}catch(Exception ex){MessageBox.Show(window,"草稿保存失敗："+ex.Message);e.Cancel=true;return;}
                if(cancellation!=null)cancellation.Cancel(); clock.Stop(); saveTimer.Stop();
            };
            window.Loaded+=async delegate { LoadCache(); LoadDrafts(); ReloadOperations(); Page("Library"); await RunUi(Refresh); };
            Text("SettingsInfo").Text="Steam 遊戲：軒轅劍參高清版（1638230）\n工作者："+worker.Root+"\n草稿與發佈紀錄："+dataRoot+"\n每階段等候上限：120 秒。沒有保存 Steam 密碼。";
        }
        void SaveEntrySettings(){string game=SteamEntry.Game(Box("GameRootBox").Text);Data.Save(Path.Combine(dataRoot,"steam-entry-settings.json"),new{GameRoot=game});}
        void RefreshEntry(){Text("EntryStatus").Text=SteamEntry.Status(Box("GameRootBox").Text);}
        T Control<T>(string name) where T:class { return window.FindName(name) as T; }
        Button Button(string name){return Control<Button>(name);} TextBox Box(string name){return Control<TextBox>(name);} TextBlock Text(string name){return Control<TextBlock>(name);}
        void Nav(string name,string page){Button(name).Click+=delegate { Page(page); };}
        void Page(string name)
        {
            foreach(string page in new[]{"Library","Editor","Operations","Settings"}) {
                Control<Grid>(page+"Page").Visibility=page==name?Visibility.Visible:Visibility.Collapsed;
                Button("Nav"+page).Background=(Brush)new BrushConverter().ConvertFromString(page==name?"#2D5960":"Transparent");
            }
            Text("PageTitle").Text=new Dictionary<string,string>{{"Library","我的作品"},{"Editor","發佈編輯"},{"Operations","發佈紀錄"},{"Settings","設定與診斷"}}[name];
            Text("PageSubtitle").Text=name=="Library"?"找回已發佈的作品，讓每次更新都有跡可循。":name=="Editor"?"編輯、核對、發佈，再確認 Steam 實際收到的內容。":name=="Operations"?"查看進度、驗證結果與中斷的操作。":"連線狀態與完整診斷紀錄。";
            if(name=="Editor" && draft==null) NewDraft();
            if(name=="Operations") ReloadOperations();
        }
        string AccountRoot { get { return Path.Combine(dataRoot,String.IsNullOrEmpty(account)?"offline":account); } }
        string NewLog(string label){string dir=Path.Combine(AccountRoot,"logs");Directory.CreateDirectory(dir);lastLog=Path.Combine(dir,DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+"-"+label+"-"+Guid.NewGuid().ToString("N").Substring(0,5)+".jsonl");return lastLog;}
        void Bind(string name,Func<Task> action){Button(name).Click+=async delegate {await RunUi(action);};}
        async Task RunUi(Func<Task> action)
        {
            if(busy)return;
            busy=true; watch.Restart(); cancellation=new CancellationTokenSource(); SetEnabled();
            Control<ProgressBar>("Progress").IsIndeterminate=true;
            try { await action(); stage="就緒"; }
            catch(Exception ex){ShowError(ex); stage=ex is OperationCanceledException?"已停止等待，結果待確認":"操作未完成";}
            finally{busy=false;watch.Stop();cancellation.Dispose();cancellation=null;Control<ProgressBar>("Progress").IsIndeterminate=false;Control<ProgressBar>("Progress").Value=0;ReloadOperations();SetEnabled();}
        }
        void SetEnabled()
        {
            foreach(string name in actionNames)Button(name).IsEnabled=!busy;
            Control<Grid>("EditForm").IsEnabled=!busy;
            Button("StopButton").IsEnabled=busy;
            bool hasState=operation!=null && File.Exists(Path.Combine(operation,"state.json"));
            string phase="";if(hasState)try{phase=Data.Text(Data.Read(Path.Combine(operation,"state.json")),"Phase");}catch(Exception ex){Notice("操作紀錄無法讀取；已停用發佈。"+ex.Message,true);hasState=false;}
            Button("PublishButton").IsEnabled=!busy && connected && phase=="reviewed";
            Button("VerifyButton").IsEnabled=!busy && connected && hasState && phase!="reviewed";
            Button("ReportButton").IsEnabled=!busy && checks.Count>0;
            Button("SaveDraftButton").IsEnabled=!busy;
            Button("ExportDraftButton").IsEnabled=!busy;
        }
        void HandleEvent(Dictionary<string,object> record)
        {
            string kind=Data.Text(record,"kind"); object data=Data.Get(record,"data");
            if(kind=="progress")stage="正在上傳至 Steam";
            else if(kind=="download-progress")stage="正在下載並核對實際檔案";
            else if(kind=="release-state")stage=Data.Phase(Data.Text(data,"phase"));
            else if(kind=="page")stage="正在取得已發佈作品";
            else if(kind=="default-language-result")stage="預設語言同步完成，正在核對";
            if(kind=="progress" || kind=="download-progress") {
                double current,total; Double.TryParse(Data.Text(data,kind=="progress"?"processed":"current"),out current);Double.TryParse(Data.Text(data,"total"),out total);
                var bar=Control<ProgressBar>("Progress");bar.IsIndeterminate=total<=0;if(total>0)bar.Value=Math.Min(100,current/total*100);
            }
            string line=DateTime.Now.ToString("HH:mm:ss")+"  "+Data.Encode(record)+Environment.NewLine;
            var log=Box("LogBox");if(log.Text.Length>250000)log.Text=log.Text.Substring(log.Text.Length-180000);log.AppendText(line);log.ScrollToEnd();
        }
        void Notice(string message,bool error){Text("NoticeText").Text=message;Control<Border>("NoticePanel").Background=(Brush)new BrushConverter().ConvertFromString(error?"#FFF0DB":"#E4F0ED");}
        public void ShowError(Exception ex)
        {
            string message=ex.Message;
            if(message.Contains("Steam account changed")){connected=false;message="Steam 帳號已切換。請重新連線，再開啟該帳號的作品。";}
            else if(message.Contains("Steam client is not running")||message.Contains("SteamAPI.Init")){connected=false;Text("AccountId").Text="離線 · 顯示本機快取";message="無法連接 Steam，請開啟 Steam 並登入後按「重新整理」。本機草稿仍已保留。";}
            else if(message.Contains("Submission requires reconciliation"))message="Steam 拒絕本次提交。已保留操作紀錄與查回結果，請到「發佈紀錄」選取本次操作並重新審閱。";
            else if(message.Contains("Remote changed"))message="Steam 上的內容已在核對後改變。請重新開啟作品並準備新的更新，避免覆蓋較新的內容。";
            else if(message.Contains("newer MODVersion"))message="封包內容已變更，但版本沒有提高。請更新封包內的 MODVersion 後重新選取。";
            else if(message.Contains("Wrong Workshop")||message.Contains("Wrong item owner"))message="這個作品不屬於目前帳號或軒轅劍參，無法進行維護。";
            Notice(message,true); Box("LogBox").AppendText(ex+Environment.NewLine);
            if(operation!=null && File.Exists(Path.Combine(operation,"state.json")))RenderReview(operation);
        }
        async Task<RunResult> Call(string command,Dictionary<string,string> options,string expected)
        {
            options=options??new Dictionary<string,string>(); options["timeout"]="120";
            if(command!="inspect-package"){if(!options.ContainsKey("language"))options["language"]=draft==null?"tchinese":draft.Language;if(!String.IsNullOrEmpty(account)&&command!="health")options["expected-account"]=account;}
            var result=await worker.Run(command,options,NewLog(command),cancellation.Token);
            if(result.ExitCode!=0){var error=result.Payload("error");throw new InvalidOperationException(error==null?"工作者沒有完成（"+result.ExitCode+"）。"+result.Error:Data.Text(error,"message"));}
            if(expected!=null&&result.Payload(expected)==null)throw new InvalidOperationException("工作者未回傳完整結果，不能當作操作成功。");
            return result;
        }
        async Task Connect()
        {
            stage="連接 Steam";
            var result=await Call("health",null,"health");var session=result.Payload("session");string next=Data.Text(session,"steamId");
            if(String.IsNullOrEmpty(next))throw new InvalidOperationException("Steam 未回傳帳號資料。");
            if(next!=account){SaveDraft();if(draft!=null&&String.IsNullOrEmpty(draft.SteamId)){draft.SteamId=next;dirty=true;}else{draft=null;operation=null;}works.Clear();checks.Clear();}
            account=next;persona=Data.Text(session,"persona");connected=true;
            Data.Save(Path.Combine(dataRoot,"settings.json"),new{Account=account,Persona=persona});
            Text("AccountName").Text=persona;Text("AccountId").Text="● 已連線  ·  "+account;
            LoadDrafts();ReloadOperations();Notice("已連接 Steam："+persona+"。",false);
        }
        async Task Refresh()
        {
            await Connect();stage="讀取我的作品";
            var result=await Call("list",new Dictionary<string,string>{{"language","tchinese"}},"published");var payload=Data.Map(result.Payload("published"));
            if(!Object.Equals(Data.Get(payload,"complete"),true))throw new InvalidOperationException("作品清單尚未取得完整，保留先前資料。");
            Data.Save(Path.Combine(AccountRoot,"published.json"),payload);FillWorks(payload);
            Notice("已從 Steam 找回 "+works.Count+" 個作品。雙擊作品即可開始維護。",false);
        }
        void LoadCache(){if(File.Exists(Path.Combine(AccountRoot,"published.json"))){FillWorks(Data.Read(Path.Combine(AccountRoot,"published.json")));Notice("顯示上次保存的作品清單，正在重新連線。",false);}}
        void FillWorks(object payload)
        {
            works.Clear();foreach(var item in Data.Rows(Data.Get(payload,"items")))works.Add(new WorkRow{Id=Data.Text(item,"Id"),Title=Data.Text(item,"Title"),Version=Data.Text(item,"Version"),Visibility=VisibilityLabel(Data.Text(item,"Visibility")),Raw=Data.Map(item)});FilterWorks();
        }
        static string VisibilityLabel(string value){if(value.EndsWith("Private"))return "私人";if(value.EndsWith("Public"))return "公開";if(value.EndsWith("FriendsOnly"))return "僅限好友";if(value.EndsWith("Unlisted"))return "不公開列出";return value;}
        void FilterWorks(){string query=Box("SearchBox").Text.Trim();Control<ListBox>("WorkList").ItemsSource=works.Where(w=>w.Title.IndexOf(query,StringComparison.OrdinalIgnoreCase)>=0||w.Id.Contains(query)).ToList();Text("WorkCount").Text=works.Count+" 個作品";Text("LibraryEmpty").Visibility=works.Count==0?Visibility.Visible:Visibility.Collapsed;}
        async Task LoadItem(string id)
        {
            if(!connected)await Connect();SaveDraft();
            var result=await Call("details",new Dictionary<string,string>{{"id",id},{"language","tchinese"}},"details");var item=Data.Map(result.Payload("details"));
            if(Data.Text(item,"Owner")!=account||Data.Text(item,"AppId")!="1638230")throw new InvalidOperationException("這個作品不屬於目前帳號或軒轅劍參。");
            var saved=ReadDrafts().Where(d=>d.WorkshopId==id).OrderByDescending(d=>d.SavedAt).FirstOrDefault();
            SetDraft(saved??new Draft{Key=Guid.NewGuid().ToString("N"),SteamId=account,WorkshopId=id,Title=Data.Text(item,"Title"),Description=Data.Text(item,"Description"),Language="tchinese",Visibility="preserve"});
            Page("Editor");Notice(saved==null?"已載入 Steam 目前的標題與說明，請選擇新版封包。":"已載入本機草稿與封包綁定；發佈前會重新核對 Steam 目前資料。",false);
        }
        void NewDraft(){SetDraft(new Draft{Key=Guid.NewGuid().ToString("N"),SteamId=account,Language="tchinese",Visibility="private",Title=""});Page("Editor");Notice("新作品預設為私人。選擇封包、預覽圖片並填寫說明後即可準備發佈。",false);}
        void SetDraft(Draft value)
        {
            Guid key;if(!Guid.TryParseExact(value.Key,"N",out key))throw new InvalidOperationException("草稿識別碼無效，請使用匯入功能重新建立草稿。");
            draft=value;operation=null;loadingForm=true;
            Box("TitleBox").Text=value.Title??"";Box("DescriptionBox").Text=value.Description??"";Box("PackageBox").Text=value.Package??"";Box("PreviewBox").Text=value.PreviewFile??"";Box("ChangeNoteBox").Text=value.ChangeNote??"";
            SetCombo("LanguageBox",value.Language??"tchinese");SetCombo("VisibilityBox",value.Visibility??"private");loadingForm=false;dirty=false;
            Text("EditIdentity").Text=String.IsNullOrEmpty(value.WorkshopId)?"新作品 · 尚未發佈":"更新既有作品  ·  "+value.WorkshopId;
            Text("DraftStatus").Text=String.IsNullOrEmpty(value.SavedAt)?"草稿會自動保存到本機。":"已載入本機草稿 · "+value.SavedAt;
            Text("PackageSummary").Text="準備時會從成品重新讀取實際版本與完整雜湊。";Preview();checks.Clear();Control<DataGrid>("CheckGrid").ItemsSource=null;Control<DataGrid>("FileGrid").ItemsSource=null;Control<DataGrid>("HistoryGrid").ItemsSource=null;Control<TabControl>("EditorTabs").SelectedIndex=0;SetEnabled();
            window.Dispatcher.BeginInvoke(DispatcherPriority.Loaded,new Action(()=>Control<ScrollViewer>("EditorScroll").ScrollToTop()));
        }
        string Combo(string name){var item=Control<ComboBox>(name).SelectedItem as ComboBoxItem;return item==null?"":Convert.ToString(item.Tag);}
        void SetCombo(string name,string value){foreach(ComboBoxItem item in Control<ComboBox>(name).Items)if(Convert.ToString(item.Tag)==value){Control<ComboBox>(name).SelectedItem=item;return;}}
        void MarkDirty(){if(loadingForm||draft==null)return;dirty=true;operation=null;checks.Clear();Button("PublishButton").IsEnabled=false;Button("VerifyButton").IsEnabled=false;Button("ReportButton").IsEnabled=false;Text("DraftStatus").Text="編輯中…";saveTimer.Stop();saveTimer.Start();}
        void ReadForm(){if(draft==null)return;draft.Title=Box("TitleBox").Text;draft.Description=Box("DescriptionBox").Text;draft.Package=Box("PackageBox").Text.Trim();draft.PreviewFile=Box("PreviewBox").Text.Trim();draft.ChangeNote=Box("ChangeNoteBox").Text;draft.Language=Combo("LanguageBox");draft.Visibility=Combo("VisibilityBox");}
        void SaveDraft()
        {
            if(draft==null||(!dirty&&!String.IsNullOrEmpty(draft.SavedAt)))return;ReadForm();if(String.IsNullOrWhiteSpace(draft.Title)&&String.IsNullOrWhiteSpace(draft.Package)&&String.IsNullOrWhiteSpace(draft.Description))return;
            draft.SavedAt=DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");Data.Save(Path.Combine(AccountRoot,"drafts",draft.Key+".json"),draft);dirty=false;Text("DraftStatus").Text="已保存 · "+draft.SavedAt;LoadDrafts();
        }
        List<Draft> ReadDrafts(){var result=new List<Draft>();string dir=Path.Combine(AccountRoot,"drafts");if(Directory.Exists(dir))foreach(string file in Directory.GetFiles(dir,"*.json")){try{result.Add(Data.Serializer().Deserialize<Draft>(File.ReadAllText(file,Data.Utf8)));}catch(Exception ex){Box("LogBox").AppendText("無法讀取草稿 "+file+": "+ex.Message+Environment.NewLine);}}return result;}
        void LoadDrafts(){Control<ListBox>("DraftList").ItemsSource=ReadDrafts().OrderByDescending(d=>d.SavedAt).ToList();}
        async Task PickPackage(){var dialog=new OpenFileDialog{Filter="MOD 封包 (*.ssmod)|*.ssmod",Title="選擇發佈成品"};if(dialog.ShowDialog(window)!=true)return;Box("PackageBox").Text=dialog.FileName;await InspectSelected();}
        async Task InspectSelected(){var result=await Call("inspect-package",new Dictionary<string,string>{{"package",Path.GetFullPath(Box("PackageBox").Text)}},"package");var info=result.Payload("package");Text("PackageSummary").Text="版本 "+Data.Text(info,"Version")+"  ·  "+Data.Text(info,"Size")+" bytes\n"+Data.Text(info,"Name");}
        async Task ReloadText(){if(draft==null||String.IsNullOrEmpty(draft.WorkshopId))throw new InvalidOperationException("新作品尚無遠端文字。");SaveDraft();var result=await Call("details",new Dictionary<string,string>{{"id",draft.WorkshopId}},"details");var item=result.Payload("details");if(Data.Text(item,"Owner")!=account)throw new InvalidOperationException("作品不屬於目前帳號。");Box("TitleBox").Text=Data.Text(item,"Title");Box("DescriptionBox").Text=Data.Text(item,"Description");Notice("已載入 Steam 目前的標題與說明。",false);}
        async Task RecoverPackage()
        {
            if(draft==null||String.IsNullOrEmpty(draft.WorkshopId))throw new InvalidOperationException("新作品尚無可取回的 Steam 封包。");
            var result=await Call("files",new Dictionary<string,string>{{"id",draft.WorkshopId}},"files");var payload=result.Payload("files");
            if(Data.Text(Data.Get(payload,"item"),"Owner")!=account)throw new InvalidOperationException("作品不屬於目前帳號。");
            var files=Data.Rows(Data.Get(payload,"files")).ToList();
            if(files.Count!=1||Data.Get(files[0],"Package")==null)throw new InvalidOperationException("遠端必須含單一可辨識的 .ssmod 封包。");
            string name=Data.Text(files[0],"FileName"),hash=Data.Text(files[0],"Sha256");if(Path.GetFileName(name)!=name)throw new InvalidOperationException("無法直接綁定子目錄內的封包。");
            string folder=Data.Text(result.Payload("downloaded"),"folder");string destination=Path.Combine(AccountRoot,"recovered",draft.WorkshopId,hash,name);
            Directory.CreateDirectory(Path.GetDirectoryName(destination));
            if(!File.Exists(destination))File.Copy(Path.Combine(folder,name),destination);
            if(Data.Hash(destination)!=hash)throw new InvalidOperationException("取回的本機封包與 Steam 下載結果不同。");
            Box("PackageBox").Text=destination;await InspectSelected();SaveDraft();Notice("已取回並綁定目前 Steam 封包。可維護刊登文字；要修改內容請選擇已提高版本的新成品。",false);
        }
        async Task PickPreview(){var dialog=new OpenFileDialog{Filter="預覽圖片|*.png;*.jpg;*.jpeg;*.gif",Title="選擇預覽圖片"};if(dialog.ShowDialog(window)==true){Box("PreviewBox").Text=dialog.FileName;Preview();}await Task.FromResult(0);}
        void Preview(){Control<Image>("PreviewImage").Source=null;string path=Box("PreviewBox").Text;if(!File.Exists(path))return;try{var image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.DecodePixelWidth=512;image.UriSource=new Uri(Path.GetFullPath(path));image.EndInit();image.Freeze();Control<Image>("PreviewImage").Source=image;}catch(Exception ex){Text("DraftStatus").Text="預覽圖片無法讀取："+ex.Message;}}
        async Task PrepareReview()
        {
            if(!connected)await Connect();ReadForm();
            if(draft==null)throw new InvalidOperationException("請先開啟作品或建立草稿。");
            if(!String.IsNullOrEmpty(draft.SteamId)&&draft.SteamId!=account)throw new InvalidOperationException("草稿屬於不同 Steam 帳號。");draft.SteamId=account;
            if(String.IsNullOrWhiteSpace(draft.Title)||String.IsNullOrWhiteSpace(draft.Description)||String.IsNullOrWhiteSpace(draft.ChangeNote))throw new InvalidOperationException("請填寫標題、內容說明及本次更新說明。");
            if(!File.Exists(draft.Package))throw new InvalidOperationException("找不到封包，請重新選擇 .ssmod 成品。");
            if(String.IsNullOrEmpty(draft.WorkshopId)&&(!File.Exists(draft.PreviewFile)||draft.Visibility=="preserve"))throw new InvalidOperationException("新作品必須選擇預覽圖片及明確的可見度。");
            SaveDraft();stage="建立本次發佈快照";
            string path=Path.Combine(AccountRoot,"operations",DateTime.Now.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(Path.Combine(path,"content"));
            string source=Path.GetFullPath(draft.Package),target=Path.Combine(path,"content",Path.GetFileName(source));
            await Task.Run(()=>{using(var input=new FileStream(source,FileMode.Open,FileAccess.Read,FileShare.Read))using(var output=new FileStream(target,FileMode.CreateNew,FileAccess.Write,FileShare.None)){input.CopyTo(output);output.Flush(true);}});
            var inspected=await Call("inspect-package",new Dictionary<string,string>{{"package",target}},"package");var info=inspected.Payload("package");
            string preview=null,previewHash=null;
            if(!String.IsNullOrEmpty(draft.PreviewFile)){preview=Path.Combine(path,"preview"+Path.GetExtension(draft.PreviewFile));File.Copy(draft.PreviewFile,preview);previewHash=Data.Hash(preview);}
            var plan=new Dictionary<string,object>{{"Schema",3},{"AppId",1638230},{"OperationId",Guid.NewGuid().ToString("N")},{"WorkshopId",String.IsNullOrEmpty(draft.WorkshopId)?null:draft.WorkshopId},{"Version",Data.Text(info,"Version")},{"ContentDirectory",Path.Combine(path,"content")},{"FileName",Data.Text(info,"FileName")},{"ContentSha256",Data.Text(info,"Sha256")},{"ContentSize",Data.Get(info,"Size")},{"Title",draft.Title},{"Description",draft.Description},{"Language",draft.Language},{"Visibility",draft.Visibility},{"ChangeNote",draft.ChangeNote},{"PreviewFile",preview},{"PreviewSha256",previewHash}};
            Data.Save(Path.Combine(path,"plan.json"),plan);Data.Save(Path.Combine(path,"draft.json"),draft);operation=path;
            await Call("review-release",OpOptions(),"release-review");RenderReview(path);Control<TabControl>("EditorTabs").SelectedIndex=1;
            Notice("準備完成。請核對下表，確認後按「確認發佈到 Steam」。",false);
        }
        Dictionary<string,string> OpOptions(){if(operation==null)throw new InvalidOperationException("請先準備並核對發佈內容。");return new Dictionary<string,string>{{"plan",Path.Combine(operation,"plan.json")},{"state",Path.Combine(operation,"state.json")}};}
        async Task Publish(){if(operation==null)throw new InvalidOperationException("請先準備並核對。");string captured=operation;await Call("publish-release",OpOptions(),"release-verified");Complete(captured);}
        async Task Verify(){string captured=operation;await Call("verify-release",OpOptions(),"release-verified");Complete(captured);}
        void Complete(string path)
        {
            var state=Data.Read(Path.Combine(path,"state.json"));if(Data.Text(state,"Phase")!="verified")throw new InvalidOperationException("尚未完成全部驗證。");
            RenderReview(path);if(draft!=null){draft.WorkshopId=Data.Text(state,"WorkshopId");draft.SteamId=account;dirty=true;SaveDraft();Text("EditIdentity").Text="更新既有作品  ·  "+draft.WorkshopId;}
            Control<TabControl>("EditorTabs").SelectedIndex=1;Notice("已驗證更新完成：標題、說明、版本及實際下載檔案全部一致。",false);
        }
        void RenderReview(string path)
        {
            if(!File.Exists(Path.Combine(path,"state.json")))return;
            var plan=Data.Read(Path.Combine(path,"plan.json"));var state=Data.Read(Path.Combine(path,"state.json"));var before=Data.Get(state,"Before");var after=Data.Get(state,"After");
            var oldFile=Data.Rows(Data.Get(state,"BeforeFiles")).FirstOrDefault();var actualFile=Data.Rows(Data.Get(state,"AfterFiles")).FirstOrDefault();bool verified=Data.Text(state,"Phase")=="verified";
            checks.Clear();
            AddCheck("標題",Data.Text(before,"Title"),Data.Text(plan,"Title"),Data.Text(after,"Title"),verified);
            AddCheck("內容說明",Data.Text(before,"Description"),Data.Text(plan,"Description"),Data.Text(after,"Description"),verified);
            AddCheck("版本",Data.Text(Data.Get(oldFile,"Package"),"Version"),Data.Text(plan,"Version"),Data.Text(Data.Get(actualFile,"Package"),"Version"),verified);
            AddCheck("檔名",Data.Text(oldFile,"FileName"),Data.Text(plan,"FileName"),Data.Text(actualFile,"FileName"),verified);
            AddCheck("檔案大小",Data.Text(oldFile,"Size"),Data.Text(plan,"ContentSize"),Data.Text(actualFile,"Size"),verified);
            AddCheck("檔案 SHA-256",Data.Text(oldFile,"Sha256"),Data.Text(plan,"ContentSha256"),Data.Text(actualFile,"Sha256"),verified);
            AddCheck("可見度",VisibilityLabel(Data.Text(before,"Visibility")),VisibilityLabel(Data.Text(state,"Visibility")),VisibilityLabel(Data.Text(after,"Visibility")),verified);
            if(Data.Text(plan,"Schema")=="3"&&Data.Text(plan,"Language")!="english"){
                AddCheck("預設語言標題",Data.Text(Data.Get(state,"BeforeDefault"),"Title"),Data.Text(plan,"Title"),Data.Text(Data.Get(state,"AfterDefault"),"Title"),verified);
                AddCheck("預設語言說明",Data.Text(Data.Get(state,"BeforeDefault"),"Description"),Data.Text(plan,"Description"),Data.Text(Data.Get(state,"AfterDefault"),"Description"),verified);
            }
            Control<DataGrid>("CheckGrid").ItemsSource=null;Control<DataGrid>("CheckGrid").ItemsSource=checks;
            Text("ReviewHeading").Text=Data.Phase(Data.Text(state,"Phase"))+"  ·  v"+Data.Text(plan,"Version")+"  ·  "+(String.IsNullOrEmpty(Data.Text(state,"WorkshopId"))?"即將新建":Data.Text(state,"WorkshopId"));
        }
        void AddCheck(string field,string before,string expected,string actual,bool verified){checks.Add(new CheckRow{Field=field,Before=before,Expected=expected,Actual=actual,Status=verified&&expected==actual?"一致":String.IsNullOrEmpty(actual)?"待提交":expected==actual?"已查回":"有差異"});}
        async Task Files(){if(draft==null||String.IsNullOrEmpty(draft.WorkshopId))throw new InvalidOperationException("新作品尚未有可查詢的遠端檔案。");var result=await Call("files",new Dictionary<string,string>{{"id",draft.WorkshopId}},"files");Control<DataGrid>("FileGrid").ItemsSource=Data.Rows(Data.Get(result.Payload("files"),"files")).Select(f=>new{FileName=Data.Text(f,"FileName"),Version=Data.Text(Data.Get(f,"Package"),"Version"),Size=Data.Text(f,"Size"),Sha256=String.IsNullOrEmpty(Data.Text(f,"PackageError"))?Data.Text(f,"Sha256"):Data.Text(f,"PackageError")}).ToList();Notice("已查詢 Steam 實際下載檔案。",false);}
        async Task History(){if(draft==null||String.IsNullOrEmpty(draft.WorkshopId))throw new InvalidOperationException("新作品尚無版本歷史。");var result=await Call("history",new Dictionary<string,string>{{"id",draft.WorkshopId}},"release-history");Control<DataGrid>("HistoryGrid").ItemsSource=Data.Rows(Data.Get(result.Payload("release-history"),"entries")).Select(e=>new{Version=Data.Text(Data.Get(e,"plan"),"Version"),Title=Data.Text(Data.Get(e,"plan"),"Title"),Time=Data.Text(Data.Get(e,"result"),"VerifiedAt"),Note=Data.Text(Data.Get(e,"plan"),"ChangeNote")}).OrderByDescending(e=>e.Time).ToList();Notice("已取得本機成功驗證的版本歷史。",false);}
        void ReloadOperations()
        {
            var dirs=new List<string>();string root=Path.Combine(AccountRoot,"operations");if(Directory.Exists(root))dirs.AddRange(Directory.GetDirectories(root));
            string references=Path.Combine(AccountRoot,"operation-references.json");externalOperations.Clear();if(File.Exists(references))externalOperations.AddRange(Data.Rows(Data.Get(Data.Read(references),"Paths")).Select(Convert.ToString));dirs.AddRange(externalOperations);
            var rows=new List<OperationRow>();foreach(string dir in dirs.Distinct(StringComparer.OrdinalIgnoreCase))try{
                string planPath=Path.Combine(dir,"plan.json"),statePath=Path.Combine(dir,"state.json");if(!File.Exists(planPath))continue;var plan=Data.Read(planPath);var state=File.Exists(statePath)?Data.Read(statePath):new Dictionary<string,object>();
                if(!String.IsNullOrEmpty(Data.Text(state,"SteamId"))&&Data.Text(state,"SteamId")!=account)continue;
                rows.Add(new OperationRow{DirectoryPath=dir,Title=Data.Text(plan,"Title"),WorkshopId=Data.Text(state,"WorkshopId"),Version=Data.Text(plan,"Version"),Status=Data.Phase(Data.Text(state,"Phase")),Time=File.GetLastWriteTime(File.Exists(statePath)?statePath:planPath).ToString("yyyy-MM-dd HH:mm:ss")});
            }catch(Exception ex){Box("LogBox").AppendText("讀取操作失敗："+dir+" "+ex.Message+Environment.NewLine);}
            Control<DataGrid>("OperationGrid").ItemsSource=rows.OrderByDescending(r=>r.Time).ToList();
        }
        void OpenOperation(string path)
        {
            SaveDraft();var plan=Data.Read(Path.Combine(path,"plan.json"));var state=Data.Read(Path.Combine(path,"state.json"));
            if(Data.Text(state,"SteamId")!=account)throw new InvalidOperationException("這筆操作屬於其他 Steam 帳號。");
            SetDraft(new Draft{Key=Guid.NewGuid().ToString("N"),SteamId=account,WorkshopId=Data.Text(state,"WorkshopId"),Title=Data.Text(plan,"Title"),Description=Data.Text(plan,"Description"),Package=Path.Combine(Data.Text(plan,"ContentDirectory"),Data.Text(plan,"FileName")),PreviewFile=Data.Text(plan,"PreviewFile"),ChangeNote=Data.Text(plan,"ChangeNote"),Language=Data.Text(plan,"Language"),Visibility=Data.Text(plan,"Visibility")});
            operation=path;RenderReview(path);Page("Editor");Control<TabControl>("EditorTabs").SelectedIndex=1;SetEnabled();Notice("已開啟既有操作。核對結果會沿用原作品 ID，不會重複建立。",false);
        }
        async Task ImportOperation(){var dialog=new OpenFileDialog{Filter="操作狀態 (state.json)|state.json",Title="選擇原有 state.json"};if(dialog.ShowDialog(window)!=true)return;string path=Path.GetDirectoryName(dialog.FileName);OpenOperation(path);if(!externalOperations.Contains(path))externalOperations.Add(path);Data.Save(Path.Combine(AccountRoot,"operation-references.json"),new{Paths=externalOperations});await Task.FromResult(0);}
        async Task RetryReview(){var row=Control<DataGrid>("OperationGrid").SelectedItem as OperationRow;if(row==null)throw new InvalidOperationException("請先選取被 Steam 拒絕的操作。");OpenOperation(row.DirectoryPath);await Call("review-release",OpOptions(),"release-review");RenderReview(operation);Notice("已重新取得 Steam 實際狀態。請確認差異後再發佈。",false);}
        void ExportDraft(){ReadForm();if(draft==null)return;var dialog=new SaveFileDialog{Filter="草稿 JSON|*.json",FileName="mod-studio-draft.json"};if(dialog.ShowDialog(window)==true){Data.Save(dialog.FileName,draft);Notice("草稿已匯出，不含 Steam 登入憑證。",false);}}
        async Task ImportDraft(){var dialog=new OpenFileDialog{Filter="草稿 JSON|*.json"};if(dialog.ShowDialog(window)!=true)return;var value=Data.Serializer().Deserialize<Draft>(File.ReadAllText(dialog.FileName,Data.Utf8));if(value==null||String.IsNullOrEmpty(value.Language))throw new InvalidOperationException("不是 MOD Studio 草稿。");if(!String.IsNullOrEmpty(value.SteamId)&&value.SteamId!=account)throw new InvalidOperationException("這份草稿屬於其他 Steam 帳號。");if(!String.IsNullOrEmpty(value.WorkshopId))value.WorkshopId=Data.WorkshopId(value.WorkshopId);SaveDraft();value.Key=Guid.NewGuid().ToString("N");value.SavedAt=null;SetDraft(value);dirty=true;SaveDraft();Page("Editor");await Task.FromResult(0);}
        void ExportReport()
        {
            if(checks.Count==0)return;var dialog=new SaveFileDialog{Filter="HTML 核對報告|*.html",FileName="mod-studio-verification.html"};if(dialog.ShowDialog(window)!=true)return;
            Func<string,string> e=System.Net.WebUtility.HtmlEncode;
            string rows=String.Join("",checks.Select(c=>"<tr><th>"+e(c.Field)+"</th><td>"+e(c.Before)+"</td><td>"+e(c.Expected)+"</td><td>"+e(c.Actual)+"</td><td>"+e(c.Status)+"</td></tr>"));
            string html="<!doctype html><html lang='zh-Hant'><meta charset='utf-8'><title>MOD Studio 核對報告</title><style>body{font:15px/1.7 'Segoe UI','Microsoft JhengHei',sans-serif;background:#f4f6f8;color:#243c48;margin:40px}main{max-width:1280px;margin:auto}table{width:100%;border-collapse:collapse;table-layout:fixed;background:white}td,th{padding:16px;border:1px solid #dce5e8;white-space:pre-wrap;overflow-wrap:anywhere;text-align:left}h1{color:#147e73}</style><main><h1>發佈與更新核對</h1><p>"+e(Text("ReviewHeading").Text)+"</p><p>匯出時間："+e(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"))+"。此為本機操作紀錄，非即時頁面。</p><table><tr><th>項目</th><th>更新前</th><th>本次內容</th><th>Steam 查回</th><th>狀態</th></tr>"+rows+"</table></main></html>";
            File.WriteAllText(dialog.FileName,html,Data.Utf8);Notice("核對報告已匯出："+dialog.FileName,false);
        }
    }
}
