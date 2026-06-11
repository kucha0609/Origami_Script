
function Img_linksExp(){
    function SubFunc (ChgPath, SaveFile, OpenPath) {
        //辅助函数：生成唯一文件名
        function OnlyFileNam(SavePath, fileName, usedNam) {
            var dot = fileName.lastIndexOf(".");//精准分离主文件名和后缀
            var Name = dot >= 0 ? fileName.substring(0, dot) : fileName;
            var Ext = dot >= 0 ? fileName.substring(dot) : "";

            var NewName = fileName;
            var Index = 1;
            while (usedNam[NewName] || new File(SavePath.fsName + "/" + NewName).exists) {
                NewName = Name + "_" + Index + Ext;
                Index++;
            }//直到文件名不重复
            usedNam[NewName] = true;//存哈希表

            return new File(SavePath.fsName + "/" + NewName);
        }

        var CurDoc = app.activeDocument;

        if (!new File(CurDoc.fullName).exists || !CurDoc.saved) {
            alert("请先保存文件", "错误", true);
            return;
        }
        var SavePath = new Folder(decodeURI(new File(CurDoc.path).fsName) + (ChgPath ? "/Links" : "/Links_Tmp"));

        if (!SavePath.exists) SavePath.create();//不存在则新建

        var Copyed = {};   // 源路径 -> 新文件对象
        var usedNam = {}; //  已用目标文件名 -> true
        var CopyCnt = 0;   // 复制文件数
        var LinkCnt = 0;   // 更新链接数
        var LostCnt = 0;   // 丢失文件的链接

        for (var i = 0; i < CurDoc.placedItems.length; i++) {
            var item = CurDoc.placedItems[i];

            if (item.embedded) continue;       //文件已嵌入
            try {item.file;} catch (err) {LostCnt++; continue;}//伪嵌入：剪贴/拖入图片，无外部源文件
            if (!new File(item.file.fsName).exists) {LostCnt++ ; continue;}//源文件未找到

            var Key = item.file.fsName;
            var HasL = new File(SavePath.fsName + "/" + decodeURI(item.file.name));
            if (!Copyed[Key] && (Key !== HasL.fsName)) {
                var NewItem = OnlyFileNam(SavePath, decodeURI(item.file.name), usedNam);
                try {
                    item.file.copy(NewItem, true); // 复制
                    CopyCnt++;
                } catch (e) {
                    continue;
                }
                Copyed[Key] = NewItem;
            }// 如果此源文件尚未复制
            if(ChgPath){
                try {item.file = Copyed[Key];  LinkCnt++;} catch (e) { }// 更新链接到新复制的文件
            }
            CurDoc.selection = null;//取消选择
        }
        
        if (CopyCnt === 0) {
            alert("没有导出任何链接图", "错误", true);
        } else {
            var CFSTR = "共复制< " + CopyCnt + " >个文件" + String.fromCharCode(10) +
                        (LostCnt == 0 ? "" : "未找到< " + LostCnt + " >个链接");
            alert(CFSTR);
            if (SaveFile) { app.activeDocument.save();}//保存文件
            if (OpenPath) { Folder(SavePath).execute();}//打开路径
        }
    }//链接图转存
    
    var ExpWin = new Window("dialog", '链接图转存');
        ExpWin.orientation = "column"; //主窗口纵向排列
        ExpWin.alignChildren = "center"; //所有控件水平居中


    var Grp01 = ExpWin.add('group');
        Grp01.orientation = 'column'; //纵向排列
        Grp01.alignChildren = "left"; //左对齐

    var Exp01 = Grp01.add('radiobutton', undefined, "仅转存链接图");
    var Exp02 = Grp01.add('radiobutton', undefined, "转存后并重新链接");
        Exp01.value = true; //默认选中Exp01
    var SaveF = Grp01.add('checkbox', undefined, "重链后保存文件");
        SaveF.value = true; // 默认勾选
        SaveF.enabled = Exp02.value; // 仅当Exp02选中时可用
    var OpenP = Grp01.add('checkbox', undefined, "转存后打开文件夹");
        OpenP.value = false; // 默认不勾选

    var Grp02 = ExpWin.add('group');
        Grp02.orientation = "row";//横向排列
        Grp02.alignment = "center"; //按钮组整体居中

    var OkBtn = Grp02.add("button", undefined, "确定");
    var NoBtn = Grp02.add("button", undefined, "取消");

    // 点击事件
    Exp01.onClick = function() { SaveF.enabled = false;}; // 禁用复选框
    Exp02.onClick = function() { SaveF.enabled = true; }; // 启用复选框
    OkBtn.onClick = function () {
        SubFunc(Exp02.value, SaveF.value, OpenP.value);//执行命令
        ExpWin.close();//关闭窗口
    };
    NoBtn.onClick = function () { ExpWin.close();};
    //ExpWin.defaultElement = OkBtn;// 设置默认按钮（Enter键触发确定）
    ExpWin.onClose = function () { return true; }// 窗口关闭事件

    ExpWin.center();
    ExpWin.show();
}//链接图转存

Img_linksExp()