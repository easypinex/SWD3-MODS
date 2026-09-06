using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;

namespace Swd3ModStudio.Desktop
{
    public static class DesktopTests
    {
        public static int Child(string[] args)
        {
            string mode=args.Length>1?args[1]:"success";
            if(mode=="hang"){Console.WriteLine(Data.Encode(new{kind="started",data=new{ok=true}}));Thread.Sleep(30000);return 0;}
            if(mode=="failure"){Console.WriteLine(Data.Encode(new{kind="error",data=new{message="測試用拒絕"}}));return 7;}
            for(int i=0;i<100;i++){Console.Error.WriteLine("diagnostic "+i);Console.WriteLine(Data.Encode(new{kind="progress",data=new{current=i}}));}
            Console.WriteLine(Data.Encode(new{kind="completed",data=new{value=args.Length>2?args[2]:"繁體中文"}}));return 0;
        }
        static void Require(bool value,string message){if(!value)throw new Exception(message);}
        public static async Task<int> Run()
        {
            string parent=Path.GetFullPath(Path.GetTempPath());string root=Path.GetFullPath(Path.Combine(parent,"swd3-desktop-tests-"+Guid.NewGuid().ToString("N")));Directory.CreateDirectory(root);int count=0;
            try
            {
                Require(Data.WorkshopId("https://steamcommunity.com/sharedfiles/filedetails/?id=3796691396")=="3796691396","URL ID parsing");count++;
                Require(Data.WorkshopId("18446744073709551615")=="18446744073709551615","64-bit ID precision");count++;
                foreach(string invalid in new[]{"0","-1","https://example.com/?id=123","https://steamcommunity.com.evil.test/?id=123"}){
                    bool failed=false;try{Data.WorkshopId(invalid);}catch(InvalidOperationException){failed=true;}Require(failed,"Invalid ID accepted");count++;
                }
                string state=Path.Combine(root,"草稿.json");Data.Save(state,new{Title="繁體中文",Version=1});Data.Save(state,new{Title="更新標題",Version=2});
                Require(Data.Text(Data.Read(state),"Title")=="更新標題","UTF-8 atomic save");count++;
                Require(Data.Text(Data.Read(state+".bak"),"Title")=="繁體中文","backup");count++;
                string exe=Assembly.GetExecutingAssembly().Location;
                string tricky="D:\\中文 空格\\\"quoted\"\\";
                int events=0;var run=await WorkerClient.RunProcess(exe,new[]{"--test-child","success",tricky},root,Path.Combine(root,"success.jsonl"),CancellationToken.None,r=>Interlocked.Increment(ref events));
                Require(run.ExitCode==0 && Data.Text(run.Payload("completed"),"value")==tricky,"argv/Unicode round trip: "+Data.Encode(new {actual=run.Payload("completed"),expected=tricky,exitCode=run.ExitCode,error=run.Error,events=events}));count++;
                Require(events==101 && File.ReadAllText(Path.Combine(root,"success.jsonl")).Contains("diagnostic 99"),"both output streams drained");count++;
                run=await WorkerClient.RunProcess(exe,new[]{"--test-child","failure"},root,Path.Combine(root,"failure.jsonl"),CancellationToken.None,null);
                Require(run.ExitCode==7 && Data.Text(run.Payload("error"),"message")=="測試用拒絕","failure preserved");count++;
                bool cancelled=false;var watch=Stopwatch.StartNew();using(var stop=new CancellationTokenSource()){
                    stop.CancelAfter(250);try{await WorkerClient.RunProcess(exe,new[]{"--test-child","hang"},root,Path.Combine(root,"cancel.jsonl"),stop.Token,null);}catch(OperationCanceledException){cancelled=true;}
                }
                Require(cancelled && watch.ElapsedMilliseconds<10000,"stop waiting hangs");count++;
                run=await WorkerClient.RunProcess(exe,new[]{"--test-child","success"},root,Path.Combine(root,"after-cancel.jsonl"),CancellationToken.None,null);
                Require(run.ExitCode==0,"cannot run after cancellation");count++;
                Console.WriteLine(Data.Encode(new{kind="desktop-self-test",passed=count,steamInitialized=false}));return 0;
            }
            catch(Exception ex){Console.WriteLine(Data.Encode(new{kind="desktop-self-test-failed",passed=count,error=ex.ToString()}));return 1;}
            finally{if(root.StartsWith(parent.TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)&&Path.GetFileName(root).StartsWith("swd3-desktop-tests-",StringComparison.Ordinal))Directory.Delete(root,true);}
        }
    }
}
