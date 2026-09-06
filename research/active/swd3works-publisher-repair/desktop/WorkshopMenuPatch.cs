using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using Mono.Cecil;
using Mono.Cecil.Cil;

namespace Swd3ModStudio.Desktop
{
    public static class WorkshopMenuPatch
    {
        const string TargetType="SWD3Works.GameTools";
        const string TargetMethod="button_SteamWorkshop_Click";
        static IEnumerable<TypeDefinition> Types(IEnumerable<TypeDefinition> types)
        { foreach(var type in types){yield return type;foreach(var child in Types(type.NestedTypes))yield return child;} }
        static string Body(MethodDefinition method)
        {
            if(!method.HasBody)return "<no-body>";
            return method.Body.InitLocals+"|"+String.Join(";",method.Body.Variables.Select(v=>v.VariableType.FullName))+"|"+
                String.Join(";",method.Body.Instructions.Select(i=>i.OpCode.Code+":"+Convert.ToString(i.Operand)))+"|"+
                String.Join(";",method.Body.ExceptionHandlers.Select(e=>e.HandlerType+":"+e.TryStart+":"+e.TryEnd+":"+e.HandlerStart+":"+e.HandlerEnd+":"+e.FilterStart+":"+e.CatchType));
        }
        static string Hash(byte[] bytes){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-","");}
        public static object Create(string original,string output,string bridge)
        {
            if(Data.Hash(original)!=SteamEntry.OriginalHash)throw new IOException("原工具不符合已驗證版本，拒絕修補。");
            if(File.Exists(output))throw new IOException("修補輸出必須是新檔案。");
            using(var assembly=AssemblyDefinition.ReadAssembly(original)) {
                if(assembly.Name.HasPublicKey)throw new IOException("不支援帶強式名稱的原工具。");
                var all=Types(assembly.MainModule.Types).ToArray();
                var target=all.Single(t=>t.FullName==TargetType).Methods.Single(m=>m.Name==TargetMethod);
                if(target.IsStatic||target.ReturnType.FullName!="System.Void"||target.Parameters.Count!=2||target.Parameters[0].ParameterType.FullName!="System.Object"||target.Parameters[1].ParameterType.FullName!="System.EventArgs")throw new IOException("開發工具按鈕簽章不符。");
                var instructions=target.Body.Instructions.Where(i=>i.OpCode!=OpCodes.Nop).ToArray();
                if(instructions.Length!=4||instructions[0].OpCode!=OpCodes.Newobj||((MethodReference)instructions[0].Operand).DeclaringType.FullName!="SWD3Works.PALWorkshopForm"||((MethodReference)instructions[1].Operand).Name!="ShowDialog"||instructions[2].OpCode!=OpCodes.Pop||instructions[3].OpCode!=OpCodes.Ret)throw new IOException("開發工具原處理流程不符。");
                var before=all.SelectMany(t=>t.Methods).ToDictionary(m=>m.FullName,Body);
                var resources=assembly.MainModule.Resources.OfType<EmbeddedResource>().ToDictionary(r=>r.Name,r=>Hash(r.GetResourceData()));
                string entry=assembly.EntryPoint.FullName, identity=assembly.Name.FullName;
                // Replace only this event handler; keep Program.Main, every other
                // method, forms, resources, and the original assembly identity.
                target.Body=new MethodBody(target);
                var il=target.Body.GetILProcessor();
                il.Append(il.Create(OpCodes.Ldstr,Path.GetFullPath(bridge)));
                il.Append(il.Create(OpCodes.Call,assembly.MainModule.ImportReference(typeof(System.Diagnostics.Process).GetMethod("Start",new[]{typeof(string)}))));
                il.Append(il.Create(OpCodes.Pop));il.Append(il.Create(OpCodes.Ret));
                string expected=Body(target), changed=target.FullName;
                assembly.Write(output);
                using(var verify=AssemblyDefinition.ReadAssembly(output)) {
                    var after=Types(verify.MainModule.Types).SelectMany(t=>t.Methods).ToDictionary(m=>m.FullName,Body);
                    if(verify.EntryPoint.FullName!=entry||verify.Name.FullName!=identity||after.Count!=before.Count)throw new IOException("修補改變原版入口或組件結構。");
                    foreach(var method in before)if(after[method.Key]!=(method.Key==changed?expected:method.Value))throw new IOException("修補波及其他函式："+method.Key);
                    var afterResources=verify.MainModule.Resources.OfType<EmbeddedResource>().ToDictionary(r=>r.Name,r=>Hash(r.GetResourceData()));
                    if(resources.Count!=afterResources.Count||resources.Any(r=>!afterResources.ContainsKey(r.Key)||afterResources[r.Key]!=r.Value))throw new IOException("修補改變原版介面資源。");
                    return new{Scope="DeveloperMenu",Method=changed,EntryPoint=entry,UnchangedMethods=before.Count-1,UnchangedResources=resources.Count,OriginalSHA256=Data.Hash(original),PatchedSHA256=Data.Hash(output)};
                }
            }
        }
    }
}
