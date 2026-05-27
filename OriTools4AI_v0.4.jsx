//----------------------------------------------------------//
//  Writer: Kucha                                           //
//          https://space.bilibili.com/28181671             //
//          www.twitter.com/kucha_Mai                       //
//----------------------------------------------------------//
#target illustrator
#targetengine com.adobe.illustrator.demo.flashplayer//旧版本预留
app.preferences.setBooleanPreference("ShowExternalJSXWarning", false);//不显示脚本警告

{//基础函数
    var ScriptName = decodeURI(new File($.fileName).name);
    var ScriptFolder = new Folder(Folder.myDocuments + "/OriTools4AI");

    function FindFunSTR(NamSTR, isTip) {
        var isChina = app.locale !== "zh_CN" || app.locale !== "zh_TW"
        //isChina = !isChina
        if(!isTip){
            return isChina 
                ? NamSTR 
                : FuncLst[NamSTR].eng
        }else{
            return isChina 
                ? FuncLst[NamSTR].cntip
                : FuncLst[NamSTR].entip;
        }
    }//根据中英文环境输出字符串
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
    function DoFunc(func) {
        //var target = "illustrator-" + app.version.split('.')[0] + ".0" + "64";
        var target = BridgeTalk.getSpecifier("illustrator")
        if (typeof func == 'function'){//函数
            var funcCode = func.toString().replace(/(?<!['"])(?:\/\/.*$)/gm, "");//正则：匹配不在单双引号内的 // 到行尾
            // 拼接目标版本
            var b = new BridgeTalk();
                b.target = target;
                b.body = "(" + funcCode + ")();";// 核心：自执行函数写法，永不依赖 func.name
                b.send();
        }else{//二进制
            var b = new BridgeTalk();
                b.target = target;
                b.body = func;
                b.send();
        }
    }//执行函数
    var FuncLst = {
        "展开" : {
            eng   : "Expand",
            cntip : "",
            entip : ""
        },
        "主功能" : {
            eng   : "MainFun",
            cntip : "",
            entip : ""
        },
        "子功能" : {
            eng   : "SubFunc",
            cntip : "",
            entip : ""
        },
        "文件保存" : {
            eng   : "SaveFile",
            cntip : "",
            entip : ""
        },
        "一键快捷" : {
            eng   : "Do_MostFunc",
            cntip : "依次运行下方子功能",
            entip : "Run the <SubFunc> below in sequence"
        },

        "一键快捷含子功能01-06" : {
            eng   : "MostFunc includes 01-06",
            cntip : "",
            entip : ""
        },

        "最新版本" : {
            eng   : "LatestVer",
            cntip : "打开Github的项目地址",
            entip : "Open the Github project"
        },

        "视频指南" : {
            eng   : "VideoGuide",
            cntip : "打开OriTools使用教程",
            entip : "Open the OriTools tutorial"
        },

        "选线型层对象" : {
            eng   : "SltLineType",
            cntip : "在描边面板：虚线与边角和路径终端对齐",
            entip : "Align dashes to path ends in Stroke panel"
        },

        "整理专色色板" : {
            eng   : "Fix_SpotCol",
            cntip : "转CMYK，同时整理颜色",
            entip : "Convert to CMYK and adjust the colors"
        },

        "修改颜色配置" : {
            eng   : "Col_Profile",
            cntip : "改变CMYK颜色配置",
            entip : "Change the CMYK color profile"
        },

        "01-解除层异常" : {
            eng   : "01-FixLayError",
            cntip : "全解锁全打开",
            entip : "Unlock and show all layers"
        },

        "02-可见层排序" : {
            eng   : "02-Sort_Layers",
            cntip : "按字母或数字，从小到大排",
            entip : "Sort visible layers by name or number"
        },

        "03-分解可见组" : {
            eng   : "03-UnGroup_All",
            cntip : "忽略剪切蒙版",
            entip : "Ignore clipping masks"
        },

        "04-矩形转画板" : {
            eng   : "04-RecArtboard",
            cntip : "只识别图框层内的矩形",
            entip : "Collect only rectangles inside the <D-16-Page>"
        },

        "05-文字置顶层" : {
            eng   : "05-TextMoveTop",
            cntip : "端头改平头+不透明度调整",
            entip : "Caps flat and adjust opacity"
        },

        "06-白色置底层" : {
            eng   : "06-WhiteToBack",
            cntip : "只处理层D-03-SymStd",
            entip : "Process only <D-03-SymStd>"
        },

        "打开文件夹" : {
            eng   : "Open_Folder",
            cntip : "打开文件所在路径",
            entip : "Open file location"
        },

        "存PDF和AI" : {
            eng   : "SaveAS_AiPDF",
            cntip : "在桌面文件夹OriExport存档",
            entip : "Save to <OriExport> folder on desktop"
        },

        "另存为SVG" : {
            eng   : "SaveAs_SVG",
            cntip : "每个画板单独导出",
            entip : "Export each artboard separately"
        },

        "另存为JPG" : {
            eng   : "SaveAs_JPG",
            cntip : "等比例DPI120输出",
            entip : "Export at DPI 120 with proportional scale"
        }

    };//功能表

}
{//定义窗口
        {//基础参数
            var WWid = 200
                WHgt = 525
                WGap = 5
                WRow = 20
                WGrp = WRow+WGap
        }
        {//新建面板和折叠按钮
            var OriWin = new Window("palette", "OriTools4AI", [0, 0, WWid, WHgt]);//

            var FoldChk = OriWin.add("checkbox", [WGap*2, WGap, 80, WRow],FindFunSTR("展开", false));
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
        MainPnl = OriWin.add("panel",[WGap, WGap+WGrp, WWid-WGap, PnlHgt01], FindFunSTR("主功能", false));
            bt001 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], FindFunSTR("一键快捷", false));
                bt001.helpTip = FindFunSTR("一键快捷", true);
            tt001 = MainPnl.add("statictext", [WGap*2, WGap*2+WGrp*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], FindFunSTR("一键快捷含子功能01-06", false));
                tt001.enabled = false;
            bt002 = MainPnl.add("button",     [WGap*1+(WWid-WGap*4)/2*0, WGap*2+WGrp*2, (WWid-WGap*4)/2*1, WGap*2+WRow*1+WGrp*2], FindFunSTR("最新版本", false));
                bt002.helpTip = FindFunSTR("最新版本", true);
            bt003 = MainPnl.add("button",     [WGap*1+(WWid-WGap*4)/2*1, WGap*2+WGrp*2, (WWid-WGap*4)/2*2, WGap*2+WRow*1+WGrp*2], FindFunSTR("视频指南", false));
                bt003.helpTip = FindFunSTR("视频指南", true);
            bt004 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], FindFunSTR("选线型层对象", false));
                bt004.helpTip = FindFunSTR("选线型层对象", true);
            bt005 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*4, WWid-WGap*4, WGap*2+WRow*1+WGrp*4], FindFunSTR("整理专色色板", false));
                bt005.helpTip = FindFunSTR("整理专色色板", true);
            bt006 = MainPnl.add("button",     [WGap*1, WGap*2+WGrp*5, WWid-WGap*4, WGap*2+WRow*1+WGrp*5], FindFunSTR("修改颜色配置", false));
                bt006.helpTip = FindFunSTR("修改颜色配置", true);

        var PnlHgt02 = PnlHgt01+WGap*1+(WGap*2+WRow*1+WGrp*5)+WGap*3
        SubfPnl = OriWin.add("panel",         [WGap*1, PnlHgt01+WGap*1, WWid-WGap, PnlHgt02], FindFunSTR("子功能", false));
            bt101 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], FindFunSTR("01-解除层异常", false));
                bt101.helpTip = FindFunSTR("01-解除层异常", true);
            bt102 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], FindFunSTR("02-可见层排序", false));
                bt102.helpTip = FindFunSTR("02-可见层排序", true);
            bt103 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*2, WWid-WGap*4, WGap*2+WRow*1+WGrp*2], FindFunSTR("03-分解可见组", false));
                bt103.helpTip = FindFunSTR("03-分解可见组", true);
            bt104 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], FindFunSTR("04-矩形转画板", false));
                bt104.helpTip = FindFunSTR("04-矩形转画板", true);
            bt105 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*4, WWid-WGap*4, WGap*2+WRow*1+WGrp*4], FindFunSTR("05-文字置顶层", false));
                bt105.helpTip = FindFunSTR("05-文字置顶层", true);
            bt106 = SubfPnl.add("button",     [WGap*1, WGap*2+WGrp*5, WWid-WGap*4, WGap*2+WRow*1+WGrp*5], FindFunSTR("06-白色置底层", false));
                bt106.helpTip = FindFunSTR("06-白色置底层", true);

        var PnlHgt03 = PnlHgt02+WGap*1+(WGap*2+WRow*1+WGrp*3)+WGap*3
        FilePnl = OriWin.add("panel",         [WGap*1, PnlHgt02+WGap*1, WWid-WGap, PnlHgt03], FindFunSTR("文件保存", false));
            bt201 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], FindFunSTR("打开文件夹", false));
                bt201.helpTip = FindFunSTR("打开文件夹", true);
            bt202 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], FindFunSTR("存PDF和AI", false));
                bt202.helpTip = FindFunSTR("存PDF和AI", true);
            bt203 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*2, WWid-WGap*4, WGap*2+WRow*1+WGrp*2], FindFunSTR("另存为SVG", false));
                bt203.helpTip = FindFunSTR("另存为SVG", true);
            bt204 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], FindFunSTR("另存为JPG", false));
                bt204.helpTip = FindFunSTR("另存为JPG", true);

        tt002 = OriWin.add('statictext',      [WGap*2, PnlHgt03, WWid-WGap, WHgt-WGap], "\u00A9 Kucha 2026");
            tt002.enabled = false;
        OriWin.center();
        OriWin.show();
}
{//定义按钮功能
    bt001.onClick = function () {
        function OpSaveFolder (){
            var SavePath = "~/Desktop/OriExport/"
            if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建
            Folder(SavePath).execute();//打开路径 
        }
        if (confirm('是否调整好：虚线对齐+整理专色+颜色配置？' + String.fromCharCode(10) + String.fromCharCode(10) +'-->处理时短暂卡死，完成后打开文件夹')) {
            var funcList = [FixLayError, Sort_Layers, UnGroup_All, RecArtboard, TextMoveTop, WhiteToBack, SaveAS_AiPDF, OpSaveFolder];
            for(var i = 0; i < funcList.length; i++){
                try {
                    DoFunc(funcList[i]);
                    $.sleep(500);//休眠等待
                }catch (err) {
                    // 嵌入失败也不会卡死
                }
            }
        }
    };//一键快捷
    bt002.onClick = function () {Web_OpenUrl(["https://github.com/kucha0609/AutoCAD-Origami-Diagram"]);};//最新版本
    bt003.onClick = function () {Web_OpenUrl(["https://www.bilibili.com/video/BV1Lq4y1K77Y/"]);};//视频指南
    bt004.onClick = function () {DoFunc(SltLineType)}//选线型层对象
    bt005.onClick = function () {DoFunc(Fix_SpotCol)}//整理专色色板
    bt006.onClick = function () {DoFunc(Col_Profile)}//修改颜色配置
    //-----------------------------------------------------
    bt101.onClick = function () {DoFunc(FixLayError)}//解除层异常
    bt102.onClick = function () {DoFunc(Sort_Layers)}//可见层排序
    bt103.onClick = function () {DoFunc(UnGroup_All)}//分解可见组

    bt104.onClick = function () {DoFunc(RecArtboard)}//矩形转画板
    bt105.onClick = function () {DoFunc(TextMoveTop)}//文字置顶层
    bt106.onClick = function () {DoFunc(WhiteToBack)}//白色置底层

    //-----------------------------------------------------
    bt201.onClick = function () {DoFunc(Open_Folder)}//打开文件夹
    bt202.onClick = function () {DoFunc(SaveAS_AiPDF)}//存PDF和AI
    bt203.onClick = function () {DoFunc(SaveAs_SVG)}//另存为SVG
    bt204.onClick = function () {DoFunc(SaveAs_JPG)}//另存为JPG/
}
{//主功能
    function SltLineType() {
        function GetTgtLay(LayNam) {
            try {
                return app.activeDocument.layers.getByName(LayNam);
            } catch(err) {
                return null;
            }
        }//获取目标图层
        app.activeDocument.selection = null; //取消全选
        var LayLst = ["D-05-Auxiliary", "D-06-Mountain", "D-07-MtnHide", "D-08-Valley", "D-09-VayHide", "D-10-BdrRef"];
        for (var i = 0; i < LayLst.length; i++) {
            try {
                var TgtLay = GetTgtLay(LayLst[i]);
                if (TgtLay){
                    TgtLay.hasSelectedArtwork = true;
                }
            } catch (e) {}
        }//只选特定图层  
        /*
        if (app.activeDocument.selection.length > 0) {
            alert('请打开描边面板，将虚线对齐改为：' + String.fromCharCode(10) + String.fromCharCode(10) +'-->使虚线与边角和路径终端对齐，并调整到适合长度')
        }
            */
    }//选线型层对象//在描边面板：虚线与边角和路径终端对齐
    function Fix_SpotCol() {
        {//基础函数
            function matchColNam(TgtCol, ColorLst) {
                if (TgtCol.typename !== "RGBColor") return null;
                var r = Math.round(TgtCol.red);
                var g = Math.round(TgtCol.green);
                var b = Math.round(TgtCol.blue);
                for (var i = 0; i < ColorLst.length; i++) {
                    var c = ColorLst[i].rgb;
                    if (r === c[0] && g === c[1] && b === c[2]) {
                        return ColorLst[i].name;
                    }
                }// 遍历颜色表
                return null;
            }//匹配专色名
            function RGB2SpotCol() {
                function obj4Lay(CurLays) {
                    {//基础功能
                        function SubFunc(element) {
                            for (var i = 0; i < element.length; i++) {
                                try {
                                    var l = element[i].locked;
                                    var h = element[i].hidden;
                                    if (l) element[i].locked = false;
                                    if (h) element[i].hidden = false;

                                    var Item = element[i]
                                    if (element[i].typename === "TextFrame") {
                                        var Item = element[i].textRange.characterAttributes;
                                    }// 判断是不是文字类型
                                    if (Item.fillColor.typename !== "NoColor") {
                                        var SptNam = matchColNam(Item.fillColor, ColorLst);
                                        if(SptNam){
                                            var c = new SpotColor();
                                                c.spot = app.activeDocument.spots.getByName(SptNam);
                                            Item.fillColor = c;
                                        } 
                                    }
                                    if (Item.strokeColor.typename !== "NoColor") {
                                        var SptNam = matchColNam(Item.strokeColor, ColorLst);
                                        if(SptNam){
                                            var c = new SpotColor();
                                                c.spot = app.activeDocument.spots.getByName(SptNam);
                                            Item.strokeColor = c;
                                        } 
                                    }
                                    
                                    element[i].locked = l;
                                    element[i].hidden = h;
                                } catch (e) {}
                            }
                        }
                        function DoFun4Grp(element) {
                            for (var i = 0; i < element.length; i++) {
                                try {
                                    var l = element[i].locked;
                                    if (l) { element[i].locked = false; }
                                    var h = element[i].hidden;
                                    if (h) { element[i].hidden = false; }

                                    SubFunc(element[i].pageItems);
                                    if (element[i].groupItems.length > 0) {
                                        DoFun4Grp(element[i].groupItems);
                                    }
                                    element[i].locked = l;
                                    element[i].hidden = h;
                                } catch (e) {}
                            }
                        }
                    }
                    for (var i = 0; i < CurLays.length; i++) {
                        try {
                            var l = CurLays[i].locked;
                                if (CurLays[i].locked) { CurLays[i].locked = false; }
                            var v = CurLays[i].visible;
                                if (!v) { CurLays[i].visible = true;}

                            SubFunc(CurLays[i].pageItems);
                            if (CurLays[i].layers.length > 0) {
                                obj4Lay(CurLays[i].layers);
                            }//子图层内
                            if (CurLays[i].groupItems.length > 0) {
                                DoFun4Grp(CurLays[i].groupItems);
                            }//组内

                            CurLays[i].locked = l;
                            CurLays[i].visible = v;
                        } catch (e) {}
                    }
                }
                var CurDoc = app.activeDocument;
                var CurLays = CurDoc.layers; //所有图层
                obj4Lay(CurLays);
            }//对象匹配专色
            function GetTgtLay(LayNam) {
                try {
                    return app.activeDocument.layers.getByName(LayNam);
                } catch(err) {
                    return null;
                }
            }//获取目标图层
            function GetAllRGB(TgtLay) {
                var CurDoc = app.activeDocument;
                var ColorMap = {};//哈希去重
                
                function getKey(col) {
                    if (!col) return null;
                    if (col.typename !== "RGBColor") return null;
                    return (
                        Math.round(col.red) + "," +
                        Math.round(col.green) + "," +
                        Math.round(col.blue)
                    );
                }//RGB转唯一key
                function AddSpot(col) {
                    function OneSpotNam(baseName) {
                        var num = 1;
                        var testName;

                        while (true) {testName = baseName + num;
                            try {app.activeDocument.spots.getByName(testName);// 能获取到说明已存在
                                num++;
                            } catch (e) {
                                break;
                            }
                        }
                        return testName;
                    }//获取唯一Spot名称
                    if(col.typename == "SpotColor"){
                        var spot = app.activeDocument.spots.getByName(col.spot.name)
                        if(spot.name.indexOf("DarkF") !== 0 && spot.name !== "Gray173"){
                            spot.name = OneSpotNam("DarkF");// 自动避免重名
                        }
                        ColorMap[key] = spot;// 保存映射
                    }else{
                        var key = getKey(col);
                        if (!key) return null;

                        if (ColorMap[key]) {
                            return ColorMap[key];
                        }// 已存在

                        var spot = CurDoc.spots.add();// 新建 Spot
                            spot.name = OneSpotNam("DarkF");// 自动避免重名

                        // 必须复制 RGBColor
                        var rgb = new RGBColor();
                            rgb.red = Math.round(col.red);
                            rgb.green = Math.round(col.green);
                            rgb.blue = Math.round(col.blue);

                        spot.color = rgb;

                        ColorMap[key] = spot;// 保存映射
                    }
                    return spot;
                }//创建Spot
                function applySpot(item, isFill) {
                    var col = isFill ? item.fillColor : item.strokeColor;
                    if (!col) return;

                    var spot = AddSpot(col);
                    if (!spot) return;
                    var spCol = new SpotColor();
                        spCol.spot = spot;

                    if (isFill) {
                        item.fillColor = spCol;
                    } else {
                        item.strokeColor = spCol;
                    }
                }//应用专色
                function SubFunc(path) {
                    if (path.hidden) return;
                    if (path.filled) { applySpot(path, true);}
                    if (path.stroked) {applySpot(path, false);}
                }//处理PathItem
                function DoFun4Item(item) {
                    if (item.hidden) return;

                    if (item.typename === "PathItem") {
                        SubFunc(item);
                    }// 普通路径
                    else if (item.typename === "CompoundPathItem") {

                        for (var i = 0; i < item.pathItems.length; i++) {
                            SubFunc(item.pathItems[i]);
                        }
                    }// 复合路径
                    else if (item.typename === "GroupItem") {
                        for (var j = 0; j < item.pageItems.length; j++) {
                            DoFun4Item(item.pageItems[j]);
                        }
                    }//组
                }// 递归处理对象
                function DoFun4Lay(layer) {
                    // 当前图层对象
                    for (var i = 0; i < layer.pageItems.length; i++) {
                        DoFun4Item(layer.pageItems[i]);
                    }
                    // 子图层
                    for (var j = 0; j < layer.layers.length; j++) {
                        DoFun4Lay(layer.layers[j]);
                    }
                }// 递归处理图层

                DoFun4Lay(TgtLay);
            }//收集某图层的RGB色并生成色板
        }
        var ColorLst = [
            { name: "Red255",       rgb: [255, 0, 0],       cmyk: [0, 100, 100, 0] },
            { name: "Black000",     rgb: [0, 0, 0],         cmyk: [0, 0, 0, 100] },
            { name: "Black001",     rgb: [0, 0, 1],         cmyk: [0, 0, 0, 100] },
            { name: "White255",     rgb: [255, 255, 255],   cmyk: [0, 0, 0, 0] },
            { name: "White254",     rgb: [255, 255, 254],   cmyk: [0, 0, 0, 0] },

            { name: "Gray051",      rgb: [51, 51, 51],      cmyk: [0, 0, 0, 90] },
            { name: "Gray091",      rgb: [91, 91, 91],      cmyk: [0, 0, 0, 70] },
            { name: "Gray132",      rgb: [132, 132, 132],   cmyk: [0, 0, 0, 60] },
            { name: "Gray173",      rgb: [173, 173, 173],   cmyk: [0, 0, 0, 45] }//面层
        ];//颜色表
        var CurDoc = app.activeDocument;
        var CurMde = CurDoc.documentColorSpace;//颜色空间
        var NonLst = [];//空的表
        /*
            if (CurMde == DocumentColorSpace.CMYK) {
                if (confirm('只能在<RGB模式>下使用' + String.fromCharCode(10) + String.fromCharCode(10) +'-->是否先转RGB然后继续？')) {
                    app.executeMenuCommand('doc-color-rgb');
                    app.redraw();
                }else{
                    return; // 结束程序
                }
            }//转换空间
        */
        if (CurMde == DocumentColorSpace.RGB) {
            for (var i = CurDoc.spots.length - 1; i >= 0; i--){//spots是动态数组，需要倒序修改
                try{
                    var CurSpt = CurDoc.spots[i];
                    var SptNam = matchColNam(CurSpt.color, ColorLst);
                    if(SptNam){
                        CurSpt.name = SptNam;
                        NonLst.push(SptNam);
                    }
                } catch (e) {}
            }//RGB专色匹配改名
            
            if (ColorLst.length !== NonLst.length){
                var NonMap = {};
                for (var i = 0; i < NonLst.length; i++) {
                    NonMap[NonLst[i]] = true;
                }//转成哈希表，加快判断速度
                for (var i = 0; i < ColorLst.length; i++) {
                    try{
                        if (!NonMap[ColorLst[i].name]) {
                            var c = new RGBColor();
                                c.red   = ColorLst[i].rgb[0];
                                c.green = ColorLst[i].rgb[1];
                                c.blue  = ColorLst[i].rgb[2];

                            try {var spot = app.activeDocument.spots.getByName(ColorLst[i].name)
                                spot.color = c;
                            } catch (e) { 
                                var spot = CurDoc.spots.add();
                                    spot.name = ColorLst[i].name;
                                    spot.color = c;
                            }//存在就改色，不存在就新建
                        }
                    } catch (e) {}
                }//循环创建色板

                $.sleep(500);//休眠等待
                RGB2SpotCol();//匹配色板颜色
            };//低版本添加色板，并匹配色板颜色
            

            GetAllRGB(GetTgtLay('D-14-FaceDark'));//填充层添加色板
            
            app.executeMenuCommand('doc-color-cmyk');//;转换为CMYK色彩空间
            app.redraw();
            for (var i = CurDoc.spots.length - 1; i >= 0; i--){//spots是动态数组，需要倒序修改
                var CurSpt = CurDoc.spots[i];
                var SptCol = CurSpt.color;
                try{
                    if(SptCol.typename !== "CMYKColor"){continue;}//非CMYK跳过
                    // 遍历颜色表
                    for(var j = 0; j < ColorLst.length; j++){
                        var c = ColorLst[j].cmyk;
                        if( ColorLst[j].name === CurSpt.name){
                            SptCol.cyan     = c[0];
                            SptCol.magenta  = c[1];
                            SptCol.yellow   = c[2];
                            SptCol.black    = c[3];
                            break;
                        }
                    }
                } catch (e) {}
            }//CMYK根据名称，改对应专色色板的颜色
            
        }else{
            alert('只能在<RGB模式>下使用');
        }
    }//整理专色色板//模型转CMYK，同时会调整颜色
    function Col_Profile(){
        if (app.activeDocument.documentColorSpace == DocumentColorSpace.CMYK){
            alert('请在接下来的窗口中' + String.fromCharCode(10) + '切换配置文件为：PSO Coated v3')
            app.executeMenuCommand('assignprofile')//打开配置面板
        }else {
            //app.redraw();
            alert('颜色模式请先转CMYK' + String.fromCharCode(10) + String.fromCharCode(10) + '-->整理专色色板')
        }
    }//修改颜色配置//改变CMYK颜色配置
}
{//子功能
    function FixLayError(){
        var CurDoc = app.activeDocument;
        var CurLays = CurDoc.layers; //所有图层
        for (i = 0; i < CurLays.length; i++) {
            CurLays[i].locked = false;//解锁图层
            CurLays[i].visible = true;//显示图层
        }//全开全解
        app.redraw();
    };//解除层异常//全解锁全打开
    function UnGroup_All() {
        function getChildAll(Item) {
            var childsArr = [];
            if (Object.prototype.toString.call(Item) === '[object Array]') {
                childsArr.push.apply(childsArr, Item);
            } else {
                for (var i = 0; i < Item.pageItems.length; i++) {
                    childsArr.push(Item.pageItems[i]);
                }
            }
            if (Item.layers) {
                for (var l = 0; l < Item.layers.length; l++) {
                    childsArr.push(Item.layers[l]);
                }
            }
            return childsArr;
        }//收集所有子元素（包括子图层）
        function ungroup(Item) {
            if (Item.clipped){return;}//保留剪切蒙版
            var childArr = getChildAll(Item);//获取当前对象的所有子元素
            if (childArr.length < 1) {
                Item.remove();return;//如果没有子元素，删除这个空对象并退出
            }else{
                for (var i = 0; i < childArr.length; i++) {
                    var element = childArr[i];
                    try {
                        if (element.parent.typename !== 'Layer') {
                            element.move(Item, ElementPlacement.PLACEBEFORE);
                            /*
                                if ((element.typename === 'PathItem' && !element.filled && !element.stroked) ||
                                    (element.typename === 'CompoundPathItem' && !element.pathItems[0].filled && !element.pathItems[0].stroked) ||
                                    (element.typename === 'TextFrame' && element.textRange.fillColor == '[NoColor]' && element.textRange.strokeColor == '[NoColor]')
                                ){
                                    clearArr.push(element);
                                }//收集剪切蒙版的数组(Push empty paths in array)

                                //删除剪切蒙版的方法
                                for (var i = 0; i < clearArr.length; i++) {
                                    clearArr[i].remove();
                                }
                            */
                        }
                        if (element.typename === 'GroupItem' || element.typename === 'Layer') {
                            ungroup(element);
                        }
                    } catch (e) {}
                }
            }
        }//解组（支持嵌套组）
        var CurDoc = app.activeDocument;
        var CurLays = CurDoc.layers;
        var clearArr = []; 
        for (var i = 0; i < CurLays.length; i++) {
            if (CurLays[i].groupItems.length > 0 && CurLays[i].visible) {
                var Lay_Locked = CurLays[i].locked;
                    CurLays[i].locked = false;//解锁图层
                ungroup(CurLays[i]);

                CurLays[i].locked = Lay_Locked; //恢复图层状态
            }
        }
    };//分解可见组//忽略剪切蒙版
    function Sort_Layers(){
        function sortArrys(abcLayers) {	
            var abcLayers = abcLayers.sort(function (a, b) { return a > b });//按字母或数字，从小到大排序
            // 循环遍历每一个图层：从第0个到最后一个
            for (var j=0; j<abcLayers.length;j++) {
                // 把当前遍历到的图层，**移到最底层（最背面）**
                abcLayers[j].zOrder(ZOrderMethod.SENDTOBACK);
            };
        }
        var CurDoc = app.activeDocument;
        var CurLays = CurDoc.layers; //所有图层
        var visibleLays = [];  
        for (i = 0; i < CurLays.length; i++) {
            if(CurLays[i].visible){
                visibleLays.push(CurLays[i]);
            }
        }//收集可见层
        if(!visibleLays.length == 0){sortArrys(visibleLays);}//存在可见层则排序
        app.redraw();
    };//可见层排序//按字母或数字，从小到大排
    function RecArtboard() {
        function GetTgtLay(LayNam) {
            try {
                return app.activeDocument.layers.getByName(LayNam);
            } catch(err) {
                return null;
            }
        }//获取目标图层
        function GetAllRec4Lay(TgtLay) {// 收集图层中所有矩形对象（支持嵌套组）
            // 判断对象是否为矩形
            function isRectangle(obj) {
                if (obj.typename === 'PathItem' && obj.closed && obj.pathPoints.length === 4) {//4点的闭合路径
                    var pathPoints = obj.pathPoints;
                    var p01 = pathPoints[0].anchor;
                    var p02 = pathPoints[1].anchor;
                    var p03 = pathPoints[2].anchor;

                    var Dis01 = Math.sqrt(Math.pow(p02[0] - p01[0], 2) + Math.pow(p02[1] - p01[1], 2));
                    var Dis02 = Math.sqrt(Math.pow(p03[0] - p02[0], 2) + Math.pow(p03[1] - p02[1], 2));
                    return Math.abs(Math.abs(Dis01 * Dis02) - Math.abs(obj.area)) < 1e-6;
                }
                return false;
            }
            // 递归函数：进入组内查找矩形
            function Rec4Group(item) {
                if (isRectangle(item)) {RecLst.push(item);}
                if (item.typename === 'GroupItem') {
                    for (var j = 0; j < item.pageItems.length; j++) {
                        Rec4Group(item.pageItems[j]);
                    }
                }
            }
            var RecLst = [];
            // 遍历图层所有元素
            for (var i = 0; i < TgtLay.pageItems.length; i++) {
                var element = TgtLay.pageItems[i];
                Rec4Group(element); // 调用递归遍历
            }
            return RecLst;
        };//收集图层中所有矩形对象（支持嵌套组）
        function CompareRecBox(R1, R2) {
            var R1Box = R1.geometricBounds;
            var R2Box = R2.geometricBounds;
            if ((Math.round(Math.abs(R1Box[1] - R2Box[1]) * 0.35277778)) < 30) {//Y差小于30mm算同一行
                return R1Box[0] - R2Box[0];//X小的先出(先左后右)
            } else {
                return R2Box[1] - R1Box[1];//Y大的先出(先上后下)
            }//按先上下后左右的顺序重新排列对象的顺序
        };//比较函数
        function DltEmptyArt() {
            //https://community.adobe.com/t5/illustrator-discussions/is-it-possible-to-remove-all-the-empty-artboards-using-script/td-p/8850778
            var CurDoc = app.activeDocument;
            var CurArt = CurDoc.artboards;
            CurDoc.selection = null;//取消当前所有选择
            for (var i = 0; i < CurArt.length; i++) {
                if (CurArt.length > 1) {//保留至少 1 个画板
                    CurArt.setActiveArtboardIndex(i);// 激活当前遍历到的画板
                    CurDoc.selectObjectsOnActiveArtboard();// 选中该画板上的所有元素
                    if (CurDoc.selection.length === 0) {
                        CurArt[i].remove();
                    }//删除画板
                }
            }
            CurDoc.selection = null;//取消当前所有选择
        };//删除空画板

        var CurDoc = app.activeDocument;
        var CurArt = CurDoc.artboards;

        var oldArtCnt = CurDoc.artboards.length;//旧画板数量
        var TgtLay = GetTgtLay('D-16-Page');//获取图框图层
        if (TgtLay) {
            TgtLay.visible = true;//显示图层
            var RecLst = GetAllRec4Lay(TgtLay);//收集图层中的矩形
                RecLst.sort(CompareRecBox);//排序
            for (var i = 0; i < RecLst.length; i++) {
                try {
                    var newArt = CurArt.add(RecLst[i].geometricBounds);
                        newArt.name = "Ori" + (i+1 < 10 ? "0" : "") + (i+1);//可能会出现重名错误
                } catch (err) {}
            }//逐个选择矩形对象并新增画板
            for (var i = oldArtCnt - 1; i >= 0; i--) {
                if (CurDoc.artboards.length > 1) {// 至少保留1个画板
                    CurDoc.artboards[i].remove();
                }
            }//倒序删除旧画板（从后往前删，避免删错）
            DltEmptyArt()//移除空画板

            TgtLay.visible = false;//关闭图框图层
            (TgtLay = GetTgtLay('0')) && (TgtLay.visible = false);//关闭0图层
            (TgtLay = GetTgtLay('Defpoints')) && (TgtLay.visible = false);//关闭Defpoints图层
        }
        app.redraw();
    }//矩形转画板//只识别图框层内的矩形
    function TextMoveTop() {
        function Txt4Lay(CurLays) {
            {//基础功能
                function isAllText4Grp(groupItem) {
                    for (var i = 0; i < groupItem.pageItems.length; i++) {
                        var item = groupItem.pageItems[i];
                        if (item.typename === "GroupItem") {
                            if (!isAllText4Grp(item)) {
                                return false;
                            }
                        }// 如果还是组，递归判断
                        else if (item.typename !== "TextFrame") {
                            return false;
                        }//只要不是 TextFrame
                    }
                    return true;
                }//组内是否都是文字？
                function SubFunc(element, LayNam) {
                    for (var i = 0; i < element.length; i++) {
                        try {
                            var l = element[i].locked;
                                if (l) { element[i].locked = false; }
                            var h = element[i].hidden;
                                if (h) { element[i].hidden = false; }
                            if(element[i].typename === 'TextFrame'){
                                element[i].zOrder(ZOrderMethod.BRINGTOFRONT);//置顶
                            }

                            if(element[i].typename === 'PathItem' && LayNam !== 'D-10-BdrRef'){
                                element[i].strokeCap = StrokeCap.BUTTENDCAP;// 设置描边端头为平头
                            }
                            if(element[i].typename === 'PathItem' && LayNam == 'D-13-FaceOth'){
                                if(element[i].filled) element[i].opacity = 50;// 不透明度
                            }else{
                                if(element[i].filled) element[i].opacity = 100;// 不透明度
                            }
                            element[i].locked = l;
                            element[i].hidden = h;
                        } catch (e) {}
                    }
                }
                function DoFun4Grp(element, LayNam) {
                    for (var i = 0; i < element.length; i++) {
                        try {
                            var l = element[i].locked;
                            if (l) { element[i].locked = false; }
                            var h = element[i].hidden;
                            if (h) { element[i].hidden = false; }

                            SubFunc(element[i].pathItems, LayNam);
                            SubFunc(element[i].textFrames, LayNam);
                            if (element[i].groupItems.length > 0) {
                                DoFun4Grp(element[i].groupItems, LayNam);
                            }

                            element[i].locked = l;
                            element[i].hidden = h;
                        } catch (e) {}
                    }
                }
            }
            for (var i = 0; i < CurLays.length; i++) {
                try {
                    var l = CurLays[i].locked;
                        if (CurLays[i].locked) { CurLays[i].locked = false; }
                    var v = CurLays[i].visible;
                        if (!v) { CurLays[i].visible = true;}

                    SubFunc(CurLays[i].pathItems, CurLays[i].name);
                    SubFunc(CurLays[i].textFrames, CurLays[i].name);
                    if (CurLays[i].layers.length > 0) {
                        Txt4Lay(CurLays[i].layers);
                    }//子图层内
                    if (CurLays[i].groupItems.length > 0) {
                        DoFun4Grp(CurLays[i].groupItems, CurLays[i].name);
                        for (var j = 0; j < CurLays[i].groupItems.length; j++) {
                            CurLays[i].groupItems[j].opacity = 100;// 不透明度
                            if (isAllText4Grp(CurLays[i].groupItems[j])) {
                                CurLays[i].groupItems[j].zOrder(ZOrderMethod.BRINGTOFRONT);//置顶
                            }//纯文字组
                        }
                    }//组内

                    CurLays[i].locked = l;
                    CurLays[i].visible = v;
                } catch (e) {}
            }
        }
        var CurDoc = app.activeDocument;
        var CurLays = CurDoc.layers; //所有图层
        Txt4Lay(CurLays);
    }//文字置顶层//端头改平头+不透明度调整
    function WhiteToBack() {
        function GetTgtLay(LayNam) {
            try {
                return app.activeDocument.layers.getByName(LayNam);
            } catch(err) {
                return null;
            }
        }//获取目标图层
        function ColorMatch(element, rgbLst, cmykLst){
            if(element.typename == "RGBColor"){
                var r = Math.round(element.red);
                var g = Math.round(element.green);
                var b = Math.round(element.blue);
                for(var i=0;i<rgbLst.length;i++){
                    var t = rgbLst[i];
                    if(r===t[0] && g===t[1] && b===t[2]){
                        return true;
                    }
                }
            }
            if(element.typename == "CMYKColor"){
                var c = Math.round(element.cyan);
                var m = Math.round(element.magenta);
                var y = Math.round(element.yellow);
                var k = Math.round(element.black);
                for(var i=0;i<cmykLst.length;i++){
                    var t = cmykLst[i];
                    if(c===t[0] && m===t[1] && y===t[2] && k===t[3]){
                        return true;
                    }
                }
            }
            return null;
        }//颜色匹配函数
        function GetMatchSpot(rgbLst, cmykLst){
            var CurDoc = app.activeDocument;
            var sptLst = [];
            for(var i=0; i<CurDoc.spots.length; i++){
                var CurSpt = CurDoc.spots[i];
                if(CurSpt.color.typename == "RGBColor"  && (ColorMatch(CurSpt.color, rgbLst, rgbLst)))  sptLst.push(CurSpt.name);
                if(CurSpt.color.typename == "CMYKColor" && (ColorMatch(CurSpt.color, rgbLst, cmykLst))) sptLst.push(CurSpt.name);
            }// 遍历所有专色色板
            return sptLst;
        }//获取匹配的专色板名称
        function ObjColMatch(colorObj, rgbLst, cmykLst, sptLst) {
            // 空值防护
            if(!colorObj) return false;
            if (colorObj.typename === "SpotColor"){// 专色：匹配名称
                for(var i = 0; i < sptLst.length; i++){
                    if(colorObj.spot.name === sptLst[i]){
                        return true;
                    }
                }
                return false;
            }else{
                return ColorMatch(colorObj, rgbLst, cmykLst);
            }//颜色：匹配色值
            return false;
        }//对象颜色匹配

        var CurDoc = app.activeDocument;

        var rgbLst = [[255,255,255], [255,255,254]];
        var cmykLst = [[0,0,0,0], [0,0,0,1], [0,0,0,2]];
        var sptLst = GetMatchSpot(rgbLst, cmykLst)//匹配的专色板名称

        var TgtLay = GetTgtLay('D-03-SymStd')
        try {
            var foundLst = [];
            for (var i = 0; i < TgtLay.pathItems.length; i++) {
                var item = TgtLay.pathItems[i];
                if (item.filled && ObjColMatch(item.fillColor, rgbLst, cmykLst, sptLst)) {//填充
                    foundLst.push(item);
                }
            }
            if (foundLst.length > 0) {
                CurDoc.selection = null;//取消选择
                CurDoc.selection = foundLst;//选择对象
                for (var k = 0; k < foundLst.length; k++) {
                    foundLst[k].zOrder(ZOrderMethod.SENDTOBACK);
                }
                CurDoc.selection = null;//取消选择
            }//后置
        } catch (e) {}
    }//白色置底层//只处理层D-03-SymStd
}
{//保存文件
    function Open_Folder(){
        if (app.documents.length == 0) {//不在欢迎界面
            alert("请先打开任一文档!", "错误", true);
        } else {
            var CurDoc = app.activeDocument;
            if (!new File(CurDoc.fullName).exists) {
                alert("文件未保存!", "错误", true);
            } else {
                SavePath = decodeURI(new File(CurDoc.path));//文件路径
                Folder(SavePath).execute();//打开路径
            }
        }
    }//打开文件夹//打开文件所在路径
    function SaveAS_AiPDF(){
            var CurDoc = app.activeDocument;
            /*获取脚本路径
                var scriptFile = new File($.fileName);
                var SavePath = scriptFile.parent.fsName + "\\OriExport";
            */
            var SavePath = "~/Desktop/OriExport/"
            if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建
            
            var PDFOpt = new PDFSaveOptions();
                PDFOpt.preserveEditability = true;
                CurDoc.saveAs(new File(SavePath), PDFOpt);

            CurDoc.saveAs(new File(SavePath), new IllustratorSaveOptions());//另存为AI
            app.redraw();
    }//存PDF和AI
    function SaveAs_SVG() {
        var CurDoc = app.activeDocument;
        var CurArt = CurDoc.artboards;
        var SavePath = "~/Desktop/OriExport/SVG/"
        if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建

        for(var i = 0; i < CurArt.length; i++) {
            try{
                CurArt.setActiveArtboardIndex(i);//设置活动画板
                var SVGOpt = new ExportOptionsSVG();
                    SVGOpt.saveMultipleArtboards = true;
                    SVGOpt.artboardRange = (i + 1).toString();

                    SVGOpt.embedRasterImages = true;
                    SVGOpt.cssProperties = SVGCSSPropertyLocation.STYLEATTRIBUTES;
                    SVGOpt.fontSubsetting = SVGFontSubsetting.None;
                    SVGOpt.documentEncoding = SVGDocumentEncoding.UTF8;

                CurDoc.exportFile(new File(SavePath), ExportType.SVG, SVGOpt); 
            }catch(e){}
        }
        app.redraw();
    }//另存为SVG//每个画板单独导出
    function SaveAs_JPG() {
        function GetfileNam(fileName) {
            var lastDotIndex = fileName.lastIndexOf("."); // 找最后一个点的位置
            // 如果找到小数点, 并且不是文件名第一个字符（避免 .bashrc 这种）
            if (lastDotIndex > 0) {
                return fileName.substring(0, lastDotIndex);
            }
            // 没有扩展名, 直接返回原文件名
            return fileName;
        }//文件名(不带扩展)——非正则
        var CurDoc = app.activeDocument;
        var CurArt = CurDoc.artboards;
        var SavePath = "~/Desktop/OriExport/JPEG/"
        if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建

        for(var i = 0; i < CurArt.length; i++) {// 循环遍历文档中的所有画板
            try{
                CurArt.setActiveArtboardIndex(i);//设置活动画板
                var JPGOpt = new ExportOptionsJPEG();
                    JPGOpt.antiAliasing = true; //抗锯齿（平滑边缘）
                    JPGOpt.artBoardClipping = true //剪切到画板
                    JPGOpt.optimization = true  // 优化以便于在web上查看
                    JPGOpt.qualitySetting = 100;//质量
                    JPGOpt.horizontalScale = JPGOpt.verticalScale = 120 / 0.72;//DPI120
                
                var jpgName = new File(SavePath + CurDoc.name.split('.')[0] + (i+1 < 10 ? "_0" : "_") + (i+1));
                CurDoc.exportFile(jpgName, ExportType.JPEG, JPGOpt); 
            }catch(e){}
        }
        app.redraw();
    }//另存为JPG//等比例DPI120输出
}

/*
    {//一些变量的写法
        var CurDoc = app.activeDocument;
        var CurSlt = CurDoc.selection;//当前选择
        var CurArt = CurDoc.artboards;//所有画板
        var CurLays = CurDoc.layers;//所有图层
        var CurMde = CurDoc.documentColorSpace;//颜色空间 DocumentColorSpace.RGB DocumentColorSpace.CMYK
        var DocFleNam = CurDoc.name.replace(/\.[^\.]+$/, '')//文件名(不带扩展)
        //if (CurDoc.spots.length > 1) { CurDoc.spots.removeAll(); }//移除专色色板(高版本)
    }
*/

