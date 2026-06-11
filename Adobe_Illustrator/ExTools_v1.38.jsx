//----------------------------------------------------------//
//  Writer: Kucha                                           //
//          https://space.bilibili.com/28181671             //
//          www.twitter.com/kucha_Mai                       //
//----------------------------------------------------------//
#target illustrator
#targetengine com.adobe.illustrator.demo.flashplayer//持久化脚本引擎
app.preferences.setBooleanPreference("ShowExternalJSXWarning", false);//不显示脚本警告
{//基础函数
    var ScriptName = decodeURI(new File($.fileName).name);
    var ScriptFolder = new Folder(Folder.myDocuments + "/ExTools");
    function Web_OpenUrl(Urls) {
        if (!ScriptFolder.exists) {ScriptFolder.create();}//创建文件夹
        // 循环打开每个网址
        for (var i = 0; i < Urls.length; i++) {
            try {
                var wd = File(ScriptFolder.fsName + "/aiOpURL.url");
                    wd.open("w");
                    wd.write("[InternetShortcut]\rURL=" + Urls[i] + "\r");
                    wd.close();
                    wd.execute();
                    $.sleep(500);//休眠等待
            } catch (e) {}
        }
    }//创建网页并打开
    function DoFunc(func, args) {
        var target = BridgeTalk.getSpecifier("illustrator");
        var bt = new BridgeTalk();
            bt.target = target;   
        if (typeof func === "function") {
            var funcCode = func.toString();
            var argList = [];
            if (args instanceof Array) {
                for (var i = 0; i < args.length; i++) {
                    var v = args[i];
                    if (typeof v === "string") {
                        argList.push('"' + v.replace(/"/g, '\\"') + '"');
                    } else {
                        argList.push(v);
                    }
                }
            }
            bt.body = "(" + funcCode + ")(" + argList.join(",") + ");";
        } else {//二进制代码
            bt.body = func;
        }
        bt.send();
    }
}
{//定义窗口
        {//基础参数
            var WWid = 200
                WHgt = 500
                WGap = 5
                WRow = 20
                WGrp = WRow+WGap
        }
        {//新建面板和折叠按钮
            var OriWin = new Window("palette", "ExTools", [0, 0, WWid, WHgt]);//
            var FoldChk = OriWin.add("checkbox", [WGap*2, WGap, 80, WRow],"展开");
            FoldChk.value = true;
            FoldChk.onClick = function () {
                if (FoldChk.value) {
                    OriWin.bounds.height = WHgt;
                } else {
                    OriWin.bounds.height = WGap + WGrp;
                }
            };//展开/折叠面板
        }

        //下方面板--------------------------------------------
        var PnlHgt01 = (WGap+WGrp)+(WGap*2+WRow*1+WGrp*5)+WGap*3
        MainPnl = OriWin.add("panel",[WGap, WGap+WGrp, WWid-WGap, PnlHgt01],"主功能");
            bt001 = MainPnl.add("button",     [WGap*1, WGap*2+WRow*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], "一键快捷");
                bt001.helpTip = "依次运行功能01、02、03";
            tt001 = MainPnl.add("statictext", [WGap*2, WGap*2+WRow*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], "一键快捷含功能01-03");//文字占用？
                tt001.enabled = false;
            bt002 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*2, WWid-WGap*4, WGap*2+WRow*1+WGrp*2], "01-删空画板");
                bt002.helpTip = "删除无对象的画板";
            bt003 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], "02-文字转曲");
                bt003.helpTip = "所选字/全部文字";
            bt004 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*4, WWid-WGap*4, WGap*2+WRow*1+WGrp*4], "03-嵌入另存");
                bt004.helpTip = "另存时嵌入链接图片";
            bt005 = MainPnl.add("button",     [WGap*1+(WWid-WGap*4)/4*0, WGap*2+WGrp*5, (WWid-WGap*4)/4*1, WGap*2+WRow*1+WGrp*5], "豆包");
                bt005.helpTip = "豆包AI";
            bt006 = MainPnl.add("button",     [WGap*1+(WWid-WGap*4)/4*1, WGap*2+WGrp*5, (WWid-WGap*4)/4*2, WGap*2+WRow*1+WGrp*5], "图标");
                bt006.helpTip = "icons8 + 阿里图标";
            bt007 = MainPnl.add("button",     [WGap*1+(WWid-WGap*4)/4*2, WGap*2+WGrp*5, (WWid-WGap*4)/4*3, WGap*2+WRow*1+WGrp*5], "寻字"); 
                bt007.helpTip = "谷歌字体 + 猫啃网";
            bt008 = MainPnl.add("button",     [WGap*1+(WWid-WGap*4)/4*3, WGap*2+WGrp*5, (WWid-WGap*4)/4*4, WGap*2+WRow*1+WGrp*5], "识字"); 
                bt008.helpTip = "识字体 + 求字体";

        var PnlHgt02 = PnlHgt01+WGap*1+(WGap*2+WRow*1+WGrp*3)+WGap*3
        SubfPnl = OriWin.add("panel",         [WGap*1, PnlHgt01+WGap*1, WWid-WGap, PnlHgt02], "标注: 放大10倍");
            bt101 = SubfPnl.add("button",     [WGap*1, WGap*2+WRow*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], "编号文字");
                bt101.helpTip = "左侧标：编号+材料+数量";
            bt102 = SubfPnl.add("button",     [WGap*1+(WWid-WGap*4)/2*0, WGap*2+WGrp*1, (WWid-WGap*4)/2*1, WGap*2+WRow*1+WGrp*1], "横向");
                bt102.helpTip = "下方标: 边界横向尺寸";
            bt103 = SubfPnl.add("button",     [WGap*1+(WWid-WGap*4)/2*1, WGap*2+WGrp*1, (WWid-WGap*4)/2*2, WGap*2+WRow*1+WGrp*1], "竖向");
                bt103.helpTip = "右侧标: 边界竖向尺寸";
            bt104 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*2, WWid-WGap*4, WGap*2+WRow*1+WGrp*2], "对象/画板尺寸");
                bt104.helpTip = "选对象则标对象尺寸";
            bt105 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], "标注线长");
                bt105.helpTip = "仅支持路径";

        var PnlHgt03 = PnlHgt02+WGap*1+(WGap*2+WRow*1+WGrp*4)+WGap*3
        FilePnl = OriWin.add("panel",         [WGap*1, PnlHgt02+WGap*1, WWid-WGap, PnlHgt03],'其它功能');
            bt201 = FilePnl.add("button",     [WGap*1, WGap*2+WRow*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], "定位文件夹");
                bt201.helpTip = "打开文件/链接所在路径";
            bt202 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], "对象重排列");
                bt202.helpTip = "先上下后左右获取对象";
            bt203 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*2, WWid-WGap*4, WGap*2+WRow*1+WGrp*2], "画板重排序");
                bt203.helpTip = "先上下后左右(同时命名)";
            bt204 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], "解除可见组");
                bt204.helpTip = "所选组/全部可见组(忽略剪切蒙版)";
            bt205 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*4, WWid-WGap*4, WGap*2+WRow*1+WGrp*4], "链接图转存");
                bt205.helpTip = "转存到当前文件路径下";

        tt002 = OriWin.add('statictext',      [WGap*2, PnlHgt03, WWid-WGap, WHgt-WGap], "\u00A9 Kucha 2026");
            tt002.enabled = false;
        OriWin.center();
        OriWin.show();
}
{//定义按钮功能
    bt001.onClick = function () {
        if (confirm("文件会短暂卡死, 是否做好了备份?\n\n-->链接图嵌入后, 重开文件生效")) {
            var funcList = [Art_DelEmpty, Txt_OutLine, Sv_aiFormat];
            for(var i = 0; i < funcList.length; i++){
                try {
                    DoFunc(funcList[i]);
                    $.sleep(500);//休眠等待
                }catch (err) {
                    // 嵌入失败也不会卡死
                }
            } 
        }
    };
    bt002.onClick = function () {DoFunc(Art_DelEmpty);}//删空画板
    bt003.onClick = function () {DoFunc(Txt_OutLine)}//文字转曲
    bt004.onClick = function () {
        if (confirm("后缀增加(转曲)后, 另存文件？\n\n-->链接图嵌入后, 重开文件生效")) {
            DoFunc(Sv_aiFormat);
        }
    }//嵌入另存
    bt005.onClick = function () {Web_OpenUrl(["https://www.doubao.com/"]);};//豆包
    bt006.onClick = function () {Web_OpenUrl(["https://icons8.com/", "https://www.iconfont.cn/"]);};//图标
    bt007.onClick = function () {Web_OpenUrl(["https://fonts.google.com/", "https://www.maoken.com/"]);};//寻字
    bt008.onClick = function () {Web_OpenUrl(["https://www.likefont.com/", "https://www.qiuziti.com/"]);};//识字
    //-----------------------------------------------------
    bt101.onClick = function () {DoFunc(Dim_TxtNote)}//编号文字
    bt102.onClick = function () {DoFunc(Dim_horizonta)}//横向尺寸
    bt103.onClick = function () {DoFunc(Dim_vertical)}//竖向尺寸
    bt104.onClick = function () {DoFunc(Dim_ArtSize)}//对象尺寸/画板尺寸
    bt105.onClick = function () {DoFunc(Dim_LineText)}//标注线长

    //-----------------------------------------------------
    bt201.onClick = function () {DoFunc(Doc_CurPath)}//打开文件夹
    bt202.onClick = function () {DoFunc(Arrange4Grid)}//对象重排列
    bt203.onClick = function () {DoFunc(SortArtOrder)}//画板重排序
    bt204.onClick = function () {DoFunc(UnGroup_All)};//解除可见组
    bt205.onClick = function () {DoFunc(Img_linksExp)}//链接图转存
}
{//子功能
    function Art_DelEmpty() {
        //https://community.adobe.com/t5/illustrator-discussions/is-it-possible-to-remove-all-the-empty-artboards-using-script/td-p/8850778
        var CurDoc = app.activeDocument;
            CurDoc.selection = null;//取消选择
        for (var i = CurDoc.artboards.length - 1; i >= 0; i--) {
            if (CurDoc.artboards.length > 1) {
                CurDoc.artboards.setActiveArtboardIndex(i);
                selectedObjects = CurDoc.selectObjectsOnActiveArtboard();
                if (CurDoc.selection.length < 1 || CurDoc.selection == null) {
                    CurDoc.artboards[i].remove();
                }
            }
        }
            CurDoc.selection = null;//取消选择
    }//删空画板
    function Txt_OutLine() {
        function OutlineText(text) {
            for (var i = text.length - 1; i >= 0; i--) {
                try {
                    //保存状态
                    var l = text[i].locked;
                    var h = text[i].hidden;
                        text[i].locked = false;
                        text[i].hidden = false;

                    var g = text[i].createOutline();//转曲

                    //恢复状态
                    g.locked = l;
                    g.hidden = h;
                } catch (e) {}
            }
        }//转曲文字数组
        function OutlineGroup(GrpItem) {
            //先处理组内文字
            if (GrpItem.textFrames.length > 0) {
                OutlineText(GrpItem.textFrames);
            }
            //递归子组
            for (var i = GrpItem.groupItems.length - 1; i >= 0; i--) {
                OutlineGroup(GrpItem.groupItems[i]);
            }
        }//递归处理组
        function OutlineLayer(layers) {
            for (var i = layers.length - 1; i >= 0; i--) {
                try {
                    //保存状态
                    var l = layers[i].locked;
                    var v = layers[i].visible;
                        layers[i].locked = false;
                        layers[i].visible = true;

                    if (layers[i].textFrames.length > 0) {
                        OutlineText(layers[i].textFrames);
                    }//处理当前图层文字
                    if (layers[i].layers.length > 0) {
                        OutlineLayer(layers[i].layers);
                    }//先递归子图层
                    for (var j = layers[i].groupItems.length - 1; j >= 0; j--) {
                        OutlineGroup(layers[i].groupItems[j]);
                    }//再递归组

                    //恢复状态
                    layers[i].locked = l;
                    layers[i].visible = v;

                } catch (e) {}
            }
        }//递归处理图层
        function DoSltItem (item) {
            if (item.typename === "TextFrame") {
                OutlineText([item]);
                return;
            }//当前对象如果是文字，直接转曲
            if (item.typename === "GroupItem") {
                if (item.textFrames.length > 0) {
                    OutlineText(item.textFrames);
                }
                for (var i = item.groupItems.length - 1; i >= 0; i--) {
                    DoSltItem(item.groupItems[i]);
                }// 遍历嵌套子组/子对象
            }//当前对象是组，先处理组内所有文字，再递归子组
        }// 递归处理任意对象（组、文字、嵌套组）

        var CurSlt = app.activeDocument.selection;
        if (CurSlt.length === 0) {
            OutlineLayer(app.activeDocument.layers);//文件全转曲
            return;
        }else{
            for (var k = CurSlt.length - 1; k >= 0; k--) {
                DoSltItem(CurSlt[k]);
            }// 遍历所有选中项，逐个递归处理
        }
    }//文字转曲//所选字/全部文字
    function Sv_aiFormat(){
        function GetfileNam(fileName) {
            var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
            return dot >= 0 ? fileName.substring(0, dot) : fileName;
        }//文件名(不带扩展)——非正则
        var CurDoc = app.activeDocument;
        try {
            var aiSaveOpts = new IllustratorSaveOptions();
                aiSaveOpts.compatibility = Compatibility.ILLUSTRATOR16;//CS6
                aiSaveOpts.embedLinkedFiles = true;//勾选【包含链接的文件】
                aiSaveOpts.pdfCompatible = true;//PDF兼容

            var SavePath = CurDoc.path.fsName + "/" + GetfileNam(CurDoc.name) + "(转曲).ai";
                CurDoc.saveAs(new File(SavePath), aiSaveOpts);//保存为AI
        } catch (e) {
            //alert("保存失败：" + e.message);
        }
    }//嵌入保存
}
{//标注功能
    function Dim_TxtNote() {
        {//基础函数
            function DoFunc(func, args) {
                var target = BridgeTalk.getSpecifier("illustrator");
                var bt = new BridgeTalk();
                    bt.target = target;   
                if (typeof func === "function") {
                    var funcCode = func.toString();
                    var argList = [];
                    if (args instanceof Array) {
                        for (var i = 0; i < args.length; i++) {
                            var v = args[i];
                            if (typeof v === "string") {
                                argList.push('"' + v.replace(/"/g, '\\"') + '"');
                            } else {
                                argList.push(v);
                            }
                        }
                    }
                    bt.body = "(" + funcCode + ")(" + argList.join(",") + ");";
                } else {//二进制代码
                    bt.body = func;
                }
                bt.send();
            }
            function CreateText(Tsize,Tconm,Tpos) {
                function NOClipBound(Tobj, isGB) {
                    function getAllobjs_NoClip(Tobj) {
                        try {
                            if (Tobj.constructor.name === "GroupItem") {
                                if (Tobj.clipped) {// 剪贴蒙版：只取第一个子项
                                    TgtLst.push(Tobj.pageItems[0]);
                                    return;
                                } else {// 普通组：递归遍历内部所有元素
                                    for (var i = 0; i < Tobj.pageItems.length; i++) {
                                        try {
                                            getAllobjs_NoClip(Tobj.pageItems[i]);
                                        } catch (e) {}
                                    }
                                }
                            } else {// 非组对象：直接加入数组
                                TgtLst.push(Tobj);
                            }
                        } catch (err) {
                        }
                        return;
                    }//收集可视边界对象
                    var TgtLst = [];
                        getAllobjs_NoClip(Tobj);//收集

                    var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
                    for (var i = 0; i < TgtLst.length; i++) {
                        var TmpBox = isGB ? TgtLst[i].geometricBounds : TgtLst[i].visibleBounds;
                        // 几何边界
                        tmpL = Math.min(tmpL, TmpBox[0]);
                        tmpT = Math.max(tmpT, TmpBox[1]);
                        tmpR = Math.max(tmpR, TmpBox[2]);
                        tmpB = Math.min(tmpB, TmpBox[3]);
                    }//返回直接返回结果
                    return [tmpL, tmpT, tmpR, tmpB];
                }//获取对象外框

                {//创建标注图层
                    var LayerNam = "标注层Ku";
                    try {
                        DimLay = app.activeDocument.layers.getByName(LayerNam);//置为当前
                    } catch (e) {
                        DimLay = app.activeDocument.layers.add();
                        DimLay.name = LayerNam;
                    } finally{
                        DimLay.locked = false;//解锁图层
                        DimLay.visible = true;// 强制开启图层显示（不管之前是否隐藏）
                        DimLay.zOrder(ZOrderMethod.BRINGTOFRONT);//图层置顶
                    }
                }

                var CurSlt = app.activeDocument.selection;
                if (CurSlt.length == 0) {alert("未选择对象", "错误", true); return;}
                
                app.redraw = false;//关闭刷新
                try {//你的程序
                    for (var i = 0; i < CurSlt.length; i += 1) {
                        var bound = NOClipBound(CurSlt[i], true);
                        var L = bound[0];
                        var T = bound[1];
                        var W = bound[2] - bound[0];
                        var H = bound[1] - bound[3];

                        var DimCol = new CMYKColor();//颜色
                            DimCol.cyan = 0;
                            DimCol.magenta = 60;
                            DimCol.yellow = 90;
                            DimCol.black = 0;
                            
                        var dimText = DimLay.textFrames.add();
                            dimText.contents = Tconm;//文字内容
                            dimText.textRange.characterAttributes.size = Tsize;//文字大小
                            dimText.textRange.characterAttributes.fillColor = DimCol;

                        if (Tpos === "T") {
                            dimText.textRange.justification = Justification.CENTER;//文字居中
                            dimText.left = (L + (W / 2)) - (dimText.width / 2);
                            dimText.top = T + Tsize*2;

                        }
                        else if (Tpos === "B") {
                            dimText.textRange.justification = Justification.CENTER;//文字居中
                            dimText.left = (L + (W / 2)) - (dimText.width / 2);
                            dimText.top = T - H - Tsize*1;
                        }
                        else if (Tpos === "R") {
                            dimText.textRange.justification = Justification.LEFT;//文字左对齐
                            dimText.left = L + W + Tsize*1;
                            dimText.top = T - (H / 2) + (dimText.height / 2);
                        }
                        else if (Tpos === "L") {
                            dimText.textRange.justification = Justification.RIGHT;//文字右对齐
                            dimText.left = L - dimText.width - Tsize*1;//减字的高度
                            dimText.top = T - (H / 2) + (dimText.height / 2);
                        }

                    } 
                } catch (e) {//nothing
                } finally {
                    app.redraw = true;//恢复更新
                    app.redraw(); // 刷新一次
                }
            }//编号文字
        }
        try {//关闭之前的面板
            if ($.global.DimPalette) {
                $.global.DimPalette.close();
                $.global.DimPalette = null;
            }
        } catch (e) {}

        var OriWin = new Window("palette", "标注设置");
            $.global.DimPalette = OriWin;

            OriWin.orientation = "column";
            OriWin.alignChildren = ["fill", "top"];
            OriWin.spacing = 15;
            OriWin.margins = 10;

        // 文字高度 + 上下按钮
        var sizeGroup = OriWin.add("group");
            sizeGroup.orientation = "row";
            sizeGroup.add("statictext", undefined, "高度：");
        var sizeInput = sizeGroup.add("edittext", undefined, "70");
            sizeInput.characters = 5;
        var UpBtn = sizeGroup.add("button", undefined, "▲");
        var DwBtn = sizeGroup.add("button", undefined, "▼");
            UpBtn.preferredSize = DwBtn.preferredSize = [20, 20];
            
        // 文字内容
        var textGroup = OriWin.add("group");
            textGroup.orientation = "row";
            textGroup.add("statictext", undefined, "内容：");
        var textInput = textGroup.add("edittext", undefined, "A1雪弗板字*1套");
            textInput.characters = 20;

        // 标注位置
        var posGroup = OriWin.add("group");
            posGroup.orientation = "row";
            posGroup.add("statictext", undefined, "位置：");
        var Pos_T = posGroup.add("radiobutton", undefined, "上"),
            Pos_B = posGroup.add("radiobutton", undefined, "下"),
            Pos_L = posGroup.add("radiobutton", undefined, "左"),
            Pos_R = posGroup.add("radiobutton", undefined, "右");
            Pos_L.value = true;

        // 按钮区域
        var BtnGroup = OriWin.add("group");
            BtnGroup.orientation = "row";
            BtnGroup.alignment = "center";
        var OkBtn = BtnGroup.add("button", undefined, "确定"),
            NoBtn = BtnGroup.add("button", undefined, "取消");
            OkBtn.preferredSize =  NoBtn.preferredSize = [90, 24];

        OkBtn.onClick = function () {
            var sizeVal = parseFloat(sizeInput.text);
            if (!isFinite(sizeVal) || sizeVal <= 0) {
                alert("文字的高度必须>0！\n\n-->请重新输入文字高度");
                sizeInput.text = "70";      // 恢复默认值
                sizeInput.active = true;    // 焦点回到输入框
                return;
            }else{sizeInput.text = sizeVal;}
            var posVar = "L";
                if (Pos_T.value) posVar = "T";
                else if (Pos_B.value) posVar = "B";
                else if (Pos_R.value) posVar = "R";

            var DimSet = {
                size: sizeVal,
                text: textInput.text,
                pos: posVar
            };
            DoFunc(CreateText,[DimSet.size, DimSet.text, DimSet.pos])
        };
        NoBtn.onClick = function () {
            OriWin.close();
        };
        sizeInput.onChange = function () {
            var sizeVal = parseFloat(this.text);
            if (!isFinite(sizeVal) || sizeVal <= 0) {
                alert("文字的高度必须>0！\n\n-->请重新输入文字高度");
                this.text = "70";      // 恢复默认值
                this.active = true;    // 焦点回到输入框
            }else{
                this.text = sizeVal; 
            }
        };//输入时验证
        UpBtn.onClick = function () {
            var sizeVal = parseFloat(sizeInput.text);
            if (!isFinite(sizeVal) || sizeVal <= 0) {
                sizeVal = 0;
            }
            sizeVal += 5;
            sizeInput.text = sizeVal;
        };
        DwBtn.onClick = function () {
            var sizeVal = parseFloat(sizeInput.text);
            if (!isFinite(sizeVal) || sizeVal <= 0) {
                sizeVal = 0;
            }
            sizeVal -= 5;
            if (sizeVal < 0) sizeVal = 0; // 防止负数
            sizeInput.text = sizeVal;
        };
        OriWin.onClose = function () {
            $.global.DimPalette = null;
            return true;
        };

        OriWin.layout.layout(true);//UI 布局刷新
        OriWin.center();
        OriWin.show();
    }//编号文字
    function Dim_horizonta() {
        function NOClipBound(Tobj, isGB) {
            function getAllobjs_NoClip(Tobj) {
                try {
                    if (Tobj.constructor.name === "GroupItem") {
                        if (Tobj.clipped) {// 剪贴蒙版：只取第一个子项
                            TgtLst.push(Tobj.pageItems[0]);
                            return;
                        } else {// 普通组：递归遍历内部所有元素
                            for (var i = 0; i < Tobj.pageItems.length; i++) {
                                try {
                                    getAllobjs_NoClip(Tobj.pageItems[i]);
                                } catch (e) {}
                            }
                        }
                    } else {// 非组对象：直接加入数组
                        TgtLst.push(Tobj);
                    }
                } catch (err) {
                }
                return;
            }//收集可视边界对象
            var TgtLst = [];
                getAllobjs_NoClip(Tobj);//收集

            var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
            for (var i = 0; i < TgtLst.length; i++) {
                var TmpBox = isGB ? TgtLst[i].geometricBounds : TgtLst[i].visibleBounds;
                // 几何边界
                tmpL = Math.min(tmpL, TmpBox[0]);
                tmpT = Math.max(tmpT, TmpBox[1]);
                tmpR = Math.max(tmpR, TmpBox[2]);
                tmpB = Math.min(tmpB, TmpBox[3]);
            }//返回直接返回结果
            return [tmpL, tmpT, tmpR, tmpB];
        }//获取对象外框
        var CurDoc = app.activeDocument;
            CurSlt = CurDoc.selection;   
        {//创建标注图层
            var glbCol = new CMYKColor();//颜色
                glbCol.cyan = 60;
                glbCol.magenta = 0;
                glbCol.yellow = 90;
                glbCol.black = 0;

            var LayerNam = "标注层Ku";
            try {
                dimLay = CurDoc.layers.getByName(LayerNam);
            } catch (e) {
                dimLay = CurDoc.layers.add();
                dimLay.name = LayerNam;//置为当前
            } finally{
                dimLay.locked = false;//解锁图层
                dimLay.visible = true;// 强制开启图层显示（不管之前是否隐藏）
                dimLay.zOrder(ZOrderMethod.BRINGTOFRONT);//图层置顶
            }
        }
        if (CurSlt.length < 1) {
            alert("未选择对象", "错误", true);
        }else{
            CurLay = CurDoc.activeLayer; // 记录当前图层
            app.redraw = false;//关闭刷新
            try {//你的程序
                for (var i = 0; i < CurSlt.length; i += 1) {
                    var bound = NOClipBound(CurSlt[i], true);
                    var L = bound[0];
                    var T = bound[1];
                    var W = bound[2] - bound[0];
                    var H = bound[1] - bound[3];
                    if (W <= 0) {continue;}//如果宽度为0跳过

                    var LDis = 50;//标注线与对象的间距
                    var TDis = 70;//文字大小
                    var dimline = dimLay.pathItems.add();//创建水平标注线
                        dimline.setEntirePath(new Array(new Array(L, (T - H) - LDis), new Array(L + W, (T - H) - LDis)));
                        dimline.filled = false;// 必须！否则线宽可能不生效
                        dimline.stroked = true;//开启线宽
                        dimline.strokeWidth = 5;//线条宽度5pt
                        dimline.strokeColor = glbCol;
                    var dimText = dimLay.textFrames.add();//创建标注文字
                        dimText.contents = (Math.round(W * 0.35277778 * 10) / 10) + " cm";//pt → 毫米（0.35277778是换算系数）
                        dimText.textRange.characterAttributes.size = TDis;
                        dimText.textRange.characterAttributes.fillColor = glbCol;
                        dimText.textRange.justification = Justification.CENTER;//文字居中
                        //文字放置
                        dimText.left = (L + (W / 2)) - (dimText.width / 2);
                        dimText.top = ((T - H) - LDis) - (LDis / 5);
                }
            } catch (e) {//nothing
            } finally {
                CurDoc.activeLayer = CurLay; // 恢复原先图层
                app.redraw = true;//恢复更新
                app.redraw(); // 最终刷新一次
            }
        }
    }//横向尺寸
    function Dim_vertical() {
        function NOClipBound(Tobj, isGB) {
            function getAllobjs_NoClip(Tobj) {
                try {
                    if (Tobj.constructor.name === "GroupItem") {
                        if (Tobj.clipped) {// 剪贴蒙版：只取第一个子项
                            TgtLst.push(Tobj.pageItems[0]);
                            return;
                        } else {// 普通组：递归遍历内部所有元素
                            for (var i = 0; i < Tobj.pageItems.length; i++) {
                                try {
                                    getAllobjs_NoClip(Tobj.pageItems[i]);
                                } catch (e) {}
                            }
                        }
                    } else {// 非组对象：直接加入数组
                        TgtLst.push(Tobj);
                    }
                } catch (err) {
                }
                return;
            }//收集可视边界对象
            var TgtLst = [];
                getAllobjs_NoClip(Tobj);//收集

            var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
            for (var i = 0; i < TgtLst.length; i++) {
                var TmpBox = isGB ? TgtLst[i].geometricBounds : TgtLst[i].visibleBounds;
                // 几何边界
                tmpL = Math.min(tmpL, TmpBox[0]);
                tmpT = Math.max(tmpT, TmpBox[1]);
                tmpR = Math.max(tmpR, TmpBox[2]);
                tmpB = Math.min(tmpB, TmpBox[3]);
            }//返回直接返回结果
            return [tmpL, tmpT, tmpR, tmpB];
        }//获取对象外框
        var CurDoc = app.activeDocument;
            CurSlt = CurDoc.selection;
        if (CurSlt.length < 1) {alert("未选择对象", "错误", true); return;}
        {//创建标注图层
            var glbCol = new CMYKColor();//颜色
                glbCol.cyan = 60;
                glbCol.magenta = 0;
                glbCol.yellow = 90;
                glbCol.black = 0;

            var LayerNam = "标注层Ku";
            try {
                dimLay = CurDoc.layers.getByName(LayerNam);
            } catch (e) {
                dimLay = CurDoc.layers.add();
                dimLay.name = LayerNam;//置为当前
            } finally{
                dimLay.locked = false;//解锁图层
                dimLay.visible = true;// 强制开启图层显示（不管之前是否隐藏）
                dimLay.zOrder(ZOrderMethod.BRINGTOFRONT);//图层置顶
            }
        }

        CurLay = CurDoc.activeLayer; // 记录当前图层
        app.redraw = false;//关闭刷新
        try {//你的程序
            for (var i = 0; i < CurSlt.length; i += 1) {
                var bound = NOClipBound(CurSlt[i], true);
                var L = bound[0];
                var T = bound[1];
                var W = bound[2] - bound[0];
                var H = bound[1] - bound[3];
                if (H <= 0) {continue;}//如果高度为0跳过

                LDis = 50;// 标注线与对象的间距
                TDis = 70;//文字高度

                var dimline = dimLay.pathItems.add();
                    dimline.setEntirePath(new Array(new Array(L + W + LDis, T), new Array(L + W + LDis, T - H)));
                    dimline.filled = false;// 必须！否则线宽可能不生效
                    dimline.stroked = true;//开启线宽
                    dimline.strokeWidth = 5;//线条宽度5pt
                    dimline.strokeColor = glbCol;
                var dimText = dimLay.textFrames.add();
                    dimText.contents = (Math.round(H * 0.35277778 * 10) / 10)  + " cm";//pt → 毫米（0.35277778是换算系数）
                    dimText.textRange.characterAttributes.size = TDis;
                    dimText.textRange.characterAttributes.fillColor = glbCol;
                    dimText.textRange.justification = Justification.CENTER;//文字居中
                    //文字放置
                    dimText.left = L + W + LDis*2 - (dimText.width / 2);
                    dimText.top = (T - (H / 2)) + (dimText.height / 2);
                    dimText.rotate(90);
            }
        } catch (e) {//nothing
        } finally {
            CurDoc.activeLayer = CurLay; // 恢复原先图层
            app.redraw = true;//恢复更新
            app.redraw(); // 最终刷新一次
        }
    }//竖向尺寸
    function Dim_ArtSize() {
        {//基础函数
            function NOClipBound(Tobj, isGB) {
                function getAllobjs_NoClip(Tobj) {
                    try {
                        if (Tobj.constructor.name === "GroupItem") {
                            if (Tobj.clipped) {// 剪贴蒙版：只取第一个子项
                                TgtLst.push(Tobj.pageItems[0]);
                                return;
                            } else {// 普通组：递归遍历内部所有元素
                                for (var i = 0; i < Tobj.pageItems.length; i++) {
                                    try {
                                        getAllobjs_NoClip(Tobj.pageItems[i]);
                                    } catch (e) {}
                                }
                            }
                        } else {// 非组对象：直接加入数组
                            TgtLst.push(Tobj);
                        }
                    } catch (err) {
                    }
                    return;
                }//收集可视边界对象
                var TgtLst = [];
                    getAllobjs_NoClip(Tobj);//收集

                var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
                for (var i = 0; i < TgtLst.length; i++) {
                    var TmpBox = isGB ? TgtLst[i].geometricBounds : TgtLst[i].visibleBounds;
                    // 几何边界
                    tmpL = Math.min(tmpL, TmpBox[0]);
                    tmpT = Math.max(tmpT, TmpBox[1]);
                    tmpR = Math.max(tmpR, TmpBox[2]);
                    tmpB = Math.min(tmpB, TmpBox[3]);
                }//返回直接返回结果
                return [tmpL, tmpT, tmpR, tmpB];
            }//获取对象外框
            function ArtNote(Bound, txtCol){//[左, 上, 右, 下]
                var TDis = 70;// 文字大小
                var W = Bound[2] - Bound[0];
                var H = Bound[1] - Bound[3];
                var dimText = dimLay.textFrames.add();
                    dimText.contents = "材料、数量" + String.fromCharCode(10) + (Math.round(W * 0.35277778 * 10) / 10) + "w*" + (Math.round(H * 0.35277778 * 10) / 10) + "cm" ;//pt → 毫米（0.35277778是换算系数）
                // 文字样式
                    dimText.textRange.characterAttributes.size = TDis;
                    dimText.textRange.characterAttributes.fillColor = txtCol;
                    dimText.textRange.justification = Justification.LEFT; // 左对齐更适合看尺寸

                // 放在左上角
                    dimText.left = Bound[0] + 0;
                    dimText.top = Bound[1] + TDis*3;
            }
        }
        var CurDoc = app.activeDocument;
            CurSlt = CurDoc.selection;
            CurArt = CurDoc.artboards;
        {//创建标注图层
            var glbCol = new CMYKColor();//颜色
                glbCol.cyan = 0;
                glbCol.magenta = 60;
                glbCol.yellow = 90;
                glbCol.black = 0;

            var LayerNam = "标注层Ku";
            try {
                dimLay = CurDoc.layers.getByName(LayerNam);//置为当前
            } catch (e) {
                dimLay = CurDoc.layers.add();
                dimLay.name = LayerNam;
            } finally{
                dimLay.locked = false;//解锁图层
                dimLay.visible = true;// 强制开启图层显示（不管之前是否隐藏）
                dimLay.zOrder(ZOrderMethod.BRINGTOFRONT);//图层置顶
            }
        }

        CurLay = CurDoc.activeLayer; // 记录当前图层
        app.redraw = false;//关闭刷新
        try {//你的程序
            if (CurSlt.length < 1) {
                for (var i = 0; i < CurArt.length; i++) {
                    var bound = CurArt[i].artboardRect; // [左, 上, 右, 下]
                        ArtNote(bound, glbCol)
                }
            }else{
                for (var i = 0; i < CurSlt.length; i += 1) {
                    var bound = NOClipBound(CurSlt[i], true);
                        ArtNote(bound, glbCol)
                }
            }
        } catch (e) {//nothing
        } finally {
            CurDoc.activeLayer = CurLay; // 恢复原先图层
            app.redraw = true;//恢复更新
            app.redraw(); // 最终刷新一次
        }
    }//对象/画板尺寸
    function Dim_LineText() {
        {//基础函数
            function DimSegLen(LArray, div_num) {
                var tsize = 70;
                var Linelen = getBezierLen(LArray, div_num);
                var MidPT = getBezierMid(LArray)
                {// 确保起点X更小,X相等时取Y更小（文字方向正常）
                    var StaPT = LArray[0];
                    var EndPT = LArray[3];
                    if (StaPT[0] > EndPT[0] || 
                        (StaPT[0] == EndPT[0] && StaPT[1] > EndPT[1])) {
                        var temp = StaPT;
                            StaPT = EndPT;
                            EndPT = temp;
                    }
                }

                // 长度 & 角度
                var dx = EndPT[0] - StaPT[0];
                var dy = EndPT[1] - StaPT[1];
                var LineAng = Math.atan2(dy, dx) * 180 / Math.PI;
                //var Linelen = Math.sqrt(dx * dx + dy * dy);

                // 创建文字
                var dimText = dimLay.textFrames.add();
                    dimText.contents = (Math.round(Linelen * 0.35277778 * 10) / 10) + " cm";
                    dimText.textRange.characterAttributes.size = tsize;
                    dimText.textRange.characterAttributes.fillColor = glbCol;
                    dimText.textRange.justification = Justification.CENTER;

                    dimText.position = [MidPT[0] - dimText.width / 2, MidPT[1] + dimText.height*1.2];
                    dimText.rotate(LineAng, true, true, true, true, Transformation.BOTTOM);
            }//标注单独一段
            function extractPaths(AllSlt, Limit, pArray) {
                for (var i = 0; i < AllSlt.length; i += 1) {
                    if (((AllSlt[i].typename == "PathItem") && (!AllSlt[i].guides)) && (!AllSlt[i].clipping)) {
                        if ((Limit) && (AllSlt[i].pathPoints.length <= Limit)) {
                            continue;
                        }// 跳过点数量太少的路径
                        pArray.push(AllSlt[i]);// 普通路径：不是参考线、不是剪切路径
                    }else if (AllSlt[i].typename == "GroupItem") {
                        extractPaths(AllSlt[i].pageItems, Limit, pArray);// 组对象：递归提取
                    }else {
                        if (AllSlt[i].typename == "CompoundPathItem") {
                            extractPaths(AllSlt[i].pathItems, Limit, pArray);
                        }// 复合路径：递归提取
                    }
                }
            }//递归提取有效路径：排除：参考线、剪切路径、只含Limit个点的无效路径
            function getBezierLen(LArray, div_num) {
                // 分段步长
                var div_unit = 1 / div_num;
                // 曲线参数 X 轴系数
                var m = [(LArray[3][0] - LArray[0][0]) + (3 * (LArray[1][0] - LArray[2][0])), (LArray[0][0] - (2 * LArray[1][0])) + LArray[2][0], LArray[1][0] - LArray[0][0]];
                // 曲线参数 Y 轴系数
                var n = [(LArray[3][1] - LArray[0][1]) + (3 * (LArray[1][1] - LArray[2][1])), (LArray[0][1] - (2 * LArray[1][1])) + LArray[2][1], LArray[1][1] - LArray[0][1]];
                // 积分公式系数
                var k = [(m[0] * m[0]) + (n[0] * n[0]), 4 * ((m[0] * m[1]) + (n[0] * n[1])), 2 * ((m[0] * m[2]) + (n[0] * n[2]) + (2 * ((m[1] * m[1]) + (n[1] * n[1])))), 4 * ((m[1] * m[2]) + (n[1] * n[2])), (m[2] * m[2]) + (n[2] * n[2])];
                // 积分函数：计算某一点的曲线导数长度
                var fc = function (t, k) {
                    return (Math.sqrt((t * ((t * ((t * ((t * k[0]) + k[1])) + k[2])) + k[3])) + k[4])) || (0);
                };

                var total = 0;
                // 辛普森积分（奇数项）
                for (var i = 1; i < div_num; i += 2) {
                    total += fc(i * div_unit, k);
                }
                total *= 2;
                // 辛普森积分（偶数项）
                for (var i = 2; i < div_num; i += 2) {
                    total += fc(i * div_unit, k);
                }

                // 最终曲线长度
                return (fc(0, k) + fc(1, k) + (total * 2)) * div_unit;
            }//核心：贝塞尔曲线长度计算（数值积分）
            function getBezierMid(LArray) {
                // 从数组中直接解出 4 个控制点
                var p0 = LArray[0];  // 起点 anchor
                var p1 = LArray[1];  // 起点右手柄
                var p2 = LArray[2];  // 终点左手柄
                var p3 = LArray[3];  // 终点 anchor

                // 固定 t = 0.5，取曲线正中间
                var t = 0.5;
                var mt = 1 - t;
                var mt2 = mt * mt;
                var mt3 = mt2 * mt;
                var t2 = t * t;
                var t3 = t2 * t;

                // 贝塞尔公式计算坐标
                var x = mt3 * p0[0] + 3 * mt2 * t * p1[0] + 3 * mt * t2 * p2[0] + t3 * p3[0];
                var y = mt3 * p0[1] + 3 * mt2 * t * p1[1] + 3 * mt * t2 * p2[1] + t3 * p3[1];
                
                return [x, y];
            }//曲线中点
        }
        var CurDoc = app.activeDocument;
            CurSlt = CurDoc.selection;
        if (CurSlt.length < 1) {alert("未选择对象", "错误", true); return;}
        {//创建标注图层
            var glbCol = new CMYKColor();//颜色
            glbCol.cyan = 60;
            glbCol.magenta = 0;
            glbCol.yellow = 90;
            glbCol.black = 0;

            var LayerNam = "标注层Ku";
            try {
                dimLay = CurDoc.layers.getByName(LayerNam);//置为当前
            } catch (e) {
                dimLay = CurDoc.layers.add();
                dimLay.name = LayerNam;
            } finally{
                dimLay.locked = false;//解锁图层
                dimLay.visible = true;// 强制开启图层显示（不管之前是否隐藏）
                dimLay.zOrder(ZOrderMethod.BRINGTOFRONT);//图层置顶
            }
        }

        CurLay = CurDoc.activeLayer; // 记录当前图层
        app.redraw = false;//关闭刷新
        try {//你的程序
            var pArray = [];
                extractPaths(CurSlt, 1, pArray);//获取有效路径
            if (pArray.length === 0) {
                alert("不含路径对象", "错误", true);
            } else {
                for (var m = 0; m < pArray.length; m += 1) {
                    PTLst = pArray[m].pathPoints;// 获取当前路径的所有锚点列表
                    for (var n = 0; n < PTLst.length; n += 1) {
                        if (n == (PTLst.length - 1)) {//最后一个点
                            if (pArray[m].closed) {k = 0;}else{break;}//闭合路径：连回第一个点/开放路径中断
                        }else {k = n + 1;}//非最后一个点：连向下一个点

                        var LArray = [
                                        PTLst[n].anchor,          // 起点锚点
                                        PTLst[n].rightDirection,  // 起点右手柄
                                        PTLst[k].leftDirection,   // 终点左手柄
                                        PTLst[k].anchor           // 终点锚点
                                    ]
                        var div_num = 512;// 曲线分段计算精度（数值越大越精确）
                        DimSegLen(LArray, div_num);
                    }
                }
            }//路径数量为 0 弹出警告
        } catch (e) {//nothing
        } finally {
            CurDoc.activeLayer = CurLay; // 恢复原先图层
            app.redraw = true;//恢复更新
            app.redraw(); // 最终刷新一次
        }
    }//标注线长
}
{//其它功能
    function Doc_CurPath(){
        var FileArr = [];     // 用于存最终路径数组
        var FileHash = {};    // 哈希表，用于路径去重
        var LostCnt = 0;      // 丢失路径的链接数量
        var CurSlt = app.activeDocument.selection;

        if (CurSlt.length == 0) {
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "错误", true);
            } else {
                if (!new File(app.activeDocument.fullName).exists) {
                alert("文件未保存!", "错误", true);
                } else {
                var SavePath = decodeURI(app.activeDocument.path); // 文件夹路径字符串
                Folder(SavePath).execute();                        // 打开路径
                }
            }
        } else {
            for (var i = 0; i < CurSlt.length; i++) {
                var item = CurSlt[i];
                if (item.typename == "PlacedItem") {
                if (item.embedded) continue;  // 文件已嵌入
                try { item.file; } catch (err) { LostCnt++; continue; } // 无外部源文件
                if (!new File(item.file.fsName).exists) { LostCnt++; continue; }  // 源文件未找到

                var parentFolder = item.file.parent;
                var folderPath = parentFolder.fsName;  // 平台完整路径，作为哈希键

                if (!FileHash[folderPath]) { // 只收集第一次出现的路径
                    FileHash[folderPath] = true;
                    FileArr.push(parentFolder);
                }
                }
            }
            if (FileArr.length > 0) {
                for (var i = 0; i < FileArr.length; i++) { FileArr[i].execute(); }// 打开所有收集到的文件夹
            } else if (LostCnt > 0) {
                alert("所选链接不存在路径", "错误", true);
            }else{
                if (app.documents.length == 0) {
                    alert("请先打开任一文档!", "错误", true);
                } else {
                    if (!new File(app.activeDocument.fullName).exists) {
                        alert("文件未保存!", "错误", true);
                    } else {
                        var SavePath = decodeURI(app.activeDocument.path); // 文件夹路径字符串
                        Folder(SavePath).execute();                        // 打开路径
                    }
                }
            }
        }
    }//定位文件夹//打开文件/链接所在路径
    function Arrange4Grid() {
        var CurDoc = app.activeDocument;
        var CurSlt = CurDoc.selection;
        if (CurSlt.length < 2) {alert("未选择对象 / 数量小于2", "错误", true); return;}

        var maxH = 0;//当前行最大高度
        var RowH = Infinity;//当前行所有对象的最低位置（用于换行）
        var CurX, CurY;
        {//弹窗
            var dlg = new Window("dialog", "排列对象");
                dlg.alignChildren = "left";
                dlg.spacing = 5;
                dlg.margins = 5;

            var grp1 = dlg.add("group");
                grp1.add("statictext", undefined, "分行(mm): ");
            var inRow = grp1.add("edittext", [0, 0, 80, 22], "50");
                inRow.helpTip = "对象上下间距大于值时，分行";

            var grp2 = dlg.add("group");
                grp2.add("statictext", undefined, "间距(mm): ");
            var inGap = grp2.add("edittext", [0, 0, 80, 22], "50");
                inGap.helpTip = "对象上下间隙的最小值";

            var grp3 = dlg.add("group");
                grp3.add("statictext", undefined, "最大列数: ");
            var inCol = grp3.add("edittext", [0, 0, 80, 22], "10");
                inCol.helpTip = "等于0时, 排列成1行";


            var grpBtn = dlg.add("group");
                grpBtn.alignment = "right";
            var btnOK = grpBtn.add("button", undefined, "确定");

            btnOK.onClick = function () { dlg.close(1); };
        }
        {//功能按钮
            if (dlg.show() !== 1) return;//ESC退出
            //取值
            var RowN = Math.round((parseInt(inRow.text) || 50) * 2.834645);//缺省为50
            var GapF = parseFloat(inGap.text);
            var ColN = parseInt(inCol.text);
            if (isNaN(ColN) || ColN <= 0) {ColN = CurSlt.length;}//列数=0 → 排成1行
        }
        {//先分行 → 行内分左右 → 行间分上下
            var sortedArr = [];
            for (var i = 0; i < CurSlt.length; i++) {
                sortedArr.push(CurSlt[i]);
            }
            sortedArr.sort(function (a, b) {
                // 1. 同一行：从左到右
                if (Math.abs(a.top - b.top) <= RowN) {
                    return a.left - b.left;
                }
                // 2. 不同行：从上到下
                else {
                    return b.top - a.top;
                }
            });// 排序后第一个 = 最左上角
            CurX = sortedArr[0].left;
            CurY = sortedArr[0].top;
        }

        for (var i = 0; i < sortedArr.length; i++) {
            var item = sortedArr[i]; // 使用排序后的对象
                item.left = CurX;
                item.top = CurY;
            CurX += item.width + Math.round(GapF * 2.834645);// 计算下一个X位置
            // 记录当前行最低Y
            var itembottom = item.top - item.height;
                RowH = itembottom < RowH ? itembottom : RowH;

            if (i % ColN == ColN - 1) {
                CurX = sortedArr[0].left;
                maxH = RowH;
                CurY = maxH - Math.round(GapF * 2.834645);
                RowH = Infinity;
            }
        }

    }//对象重排列
    function SortArtOrder() {
        var CurDoc = app.activeDocument;
        var CurArt = CurDoc.artboards;

        var artInfo = [];
        for (var i = 0; i < CurArt.length; i++) {
            var Tmp = CurArt[i].artboardRect;
            artInfo.push(
                {
                    left: Tmp[0],
                    top: Tmp[1],
                    rect: Tmp
                }
            );
        }// 收集画板：边界坐标+原始索引
        artInfo.sort(
            function (a, b) {
                if (b.top !== a.top) return b.top - a.top;
                return a.left - b.left;
            }
        );// 核心排序：优先从上到下(top降序)，同高度从左往右(x升序)

        var rectList = [];
        for (var k = 0; k < artInfo.length; k++) {
            rectList.push(artInfo[k].rect);
        }// 提取排序后画板尺寸

        // 清空原有画板，按新顺序重建
        while (CurArt.length > 1) CurArt.remove(0);
        CurArt[0].artboardRect = rectList[0];
        CurArt[0].name = "Ex01";
        for (var j = 1; j < rectList.length; j++) {
            var newArt = CurArt.add(rectList[j]);
                newArt.name = "Ex" + (j + 1 < 10 ? "0" : "") + (j + 1);
        }
    }//画板重排序//先上下后左右(同时命名)
    function UnGroup_All() {
        function UnGroupItem(GrpItem) {
            if (GrpItem.clipped) return;//剪切组跳过
            if (GrpItem.hidden)  return;//隐藏就跳过
            for (var i = GrpItem.groupItems.length - 1; i >= 0; i--) {
                UnGroupItem(GrpItem.groupItems[i]);
            }//先递归处理子组

            var items = [];
            for (var j = GrpItem.pageItems.length - 1; j >= 0; j--) {
                items.push(GrpItem.pageItems[j]);
            }//保存当前组中的所有元素
            for (var k = items.length - 1; k >= 0; k--) {
                try {
                    items[k].move(GrpItem, ElementPlacement.PLACEBEFORE);//移到父级前面
                    if (GrpItem.clipped) {
                        if ((items[k].typename === 'PathItem' && !items[k].filled && !items[k].stroked) ||//不存在填充和描边的路径
                            (items[k].typename === 'CompoundPathItem' && !items[k].pathItems[0].filled && !items[k].pathItems[0].stroked) || //不存在填充和描边的复合路径
                            (items[k].typename === 'TextFrame' && items[k].textRange.characterAttributes.fillColor == '[NoColor]' && items[k].textRange.characterAttributes.strokeColor == '[NoColor]') 
                        ){
                            clearArr.push(items[k]);
                        }//收集剪切蒙版的数组(Push empty paths in array)
                    }//收集空对象后面删除
                } catch (e) {}
            }//把子元素移出组
            try {GrpItem.remove();} catch (e) {}//删除空组
        }//递归解组组对象
        function UnGroupLayer(layers) {
                for (var i = layers.length - 1; i >= 0; i--) {
                    try {
                        var layer = layers[i];
                        //保存状态
                        var l = layer.locked;
                            layer.locked = false;

                        if(!layer.visible) return; //层不可见就跳过

                        if (layer.layers.length > 0) {
                            UnGroupLayer(layer.layers);
                        }//先处理子图层
                        for (var j = layer.groupItems.length - 1; j >= 0; j--) {
                            UnGroupItem(layer.groupItems[j]);
                        }//再处理当前图层中的组
                        //恢复状态
                        layer.locked = l;
                    } catch (e) {}
                }
        }//递归处理图层


        var clearArr = [];

        var CurSlt = app.activeDocument.selection;
        if (CurSlt.length === 0) {
            UnGroupLayer(app.activeDocument.layers);
            return;
        }else{
            for (var k = CurSlt.length - 1; k >= 0; k--) {
                if (CurSlt[k].typename === "GroupItem") {
                    UnGroupItem(CurSlt[k]);
                }
            }// 遍历所有选中项，逐个递归处理
        }

        for (var i = 0; i < clearArr.length; i++) {
            clearArr[i].remove();
        }



    };//分解可见组//所选组/全部可见组(忽略剪切蒙版)
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
        }//转存
        
        var ExpWin = new Window("dialog", '链接转存');
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
    }//链接图转存//转存到当前文件路径下
}
/*
    {//一些变量的写法
        var CurDoc = app.activeDocument;
        var CurSlt = CurDoc.selection;//选择集
        var CurArt = CurDoc.artboards;//画板
        var DocLayers = CurDoc.layers; //所有图层
        var DocArtbds = CurDoc.artboards;//所有画板
        var DocFleNam = CurDoc.name.replace(/\.[^\.]+$/, '')//文件名(不带扩展)
        //if (CurDoc.spots.length > 1) { CurDoc.spots.removeAll(); }//移除专色色板(高版本)
    }
*/

