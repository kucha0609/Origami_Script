//----------------------------------------------------------//
//  Writer: Kucha                                           //
//          https://space.bilibili.com/28181671             //
//          www.twitter.com/kucha_Mai                       //
//----------------------------------------------------------//
function UseAI() {
    #target illustrator
    #targetengine com.adobe.illustrator.demo.flashplayer//持久化脚本引擎
    app.preferences.setBooleanPreference("ShowExternalJSXWarning", false);//不显示脚本警告
    /*一些变量的写法
        var CurDoc = app.activeDocument;
        var CurSlt = CurDoc.selection;//选择集
        var CurArt = CurDoc.artboards;//画板

        var DocLayers = CurDoc.layers; //所有图层
        var DocArtbds = CurDoc.artboards;//所有画板
        var DocFleNam = CurDoc.name.replace(/\.[^\.]+$/, '')//文件名(不带扩展)
        //if (CurDoc.spots.length > 1) { CurDoc.spots.removeAll()};//移除专色色板(高版本)
    */

    var ScriptName = decodeURI(new File($.fileName).name);
    var SysFolder = new Folder(Folder.myDocuments + "/AdobeKu");
    if (!SysFolder.exists) {SysFolder.create()};//创建文件夹
    var configFilePath = SysFolder + "/panelSys.xml";//默认配置文件完整路径

    {//基础函数
        function DoFunc(func, args, cb) {
            cb = cb || function(){}; // 无cb则赋值空函数，调用不会报错
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
            
            bt.onResult = function(resObj) {
                var result = eval(resObj.body);
                cb(result, null);
            };// 正常收到结果
            bt.send(10);
        }
        function OpenNow () {
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
                return false;
            } else {
                return true;
            }
        };//打开文件
        function SavedNow () {
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
                return false;
            } else {
                var CurDoc = app.activeDocument;
                if (!new File(CurDoc.fullName).exists) {
                    alert("请先保存文件!", "ExTools", true);
                    return false;
                } else {
                    if (!CurDoc.saved) {
                        alert("请先保存文件!", "ExTools", true);
                        return false;
                    } else {
                        return true;
                    }
                }
            }
        };//打开并保存文件
        function SavedNoLost (OneFlag) {
            function GetfileNam(fileName) {
                var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
                return dot >= 0 ? fileName.substring(0, dot) : fileName;
            };//文件名(不带扩展)——非正则
            
            var LostCnt = 0;   // 丢失文件的链接
            var SaveFlag = false;//默认没打开没保存
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
                var SaveFlag = false;
            } else {
                var CurDoc = app.activeDocument;
                if (!new File(CurDoc.fullName).exists) {
                    alert("请先保存文件!", "ExTools", true);
                    var SaveFlag = false;
                } else {
                    if (CurDoc.saved) {//文件保存了
                        for (var i = 0; i < CurDoc.placedItems.length; i++) {
                            var item = CurDoc.placedItems[i];
                            if (item.embedded) continue;       //文件已嵌入
                            try {item.file;} catch (err) {LostCnt++; continue};//伪嵌入：剪贴/拖入图片，无外部源文件
                            if (!new File(item.file.fsName).exists) {LostCnt++ ; continue};//源文件未找到
                        }
                        if (LostCnt > 0) {
                            alert("链接图缺失< " + LostCnt + " >个"+ String.fromCharCode(10) + String.fromCharCode(10) +"-->请检查打开的链接面板" , "ExTools", true);
                            app.executeMenuCommand("Adobe LinkPalette Menu Item");
                        }
                        var SaveFlag = true;
                    } else {
                        var SaveFlag = false;
                        if (confirm(
                                "文件未保存，是否先保存?" +
                                (OneFlag 
                                    ? String.fromCharCode(10) + String.fromCharCode(10) + "-->保存后请再点击【一键快捷】"
                                    : ""
                                )
                        )) {
                            
                            var aiSaveOpts = new IllustratorSaveOptions();
                                aiSaveOpts.compatibility = Compatibility.ILLUSTRATOR24;//保存为2020
                                aiSaveOpts.embedICCProfile = true;//勾选【嵌入ICC配置文件】
                                aiSaveOpts.pdfCompatible = false;//不保存PDF兼容

                            var SavePath = CurDoc.path.fsName + "/" + GetfileNam(CurDoc.name) + ".ai";
                                CurDoc.saveAs(new File(SavePath), aiSaveOpts);//保存为AI
                            
                        }
                        
                    }
                }
            }
            
            return (SaveFlag && LostCnt == 0);
        };//文件保存+链接图未缺失
    }
    {//配置函数
        //当配置文件不存在时，写入默认参数。
        function createXml(filePath) {
            SysXml = new XML("<KuchaData></KuchaData>");
            SysXml.DimSca = 1;       //选择的比例
            SysXml.DimCol = 3;       //选择的颜色
            SysXml.TxtSize = 50;     //默认字高
            SysXml.UnitChk = 1 ;     //显示单位
            SysXml.VisibleChk = 0;   //标注考虑描边

            readwriteXml("w", filePath, SysXml);
        }
        //将输入值保存到配置文件
        function save2Xml() {
            SysXml.UnitChk = glb_UnitChk.value - 0;
            SysXml.VisibleChk = glb_VisibleChk.value - 0;

            SysXml.DimSca = glb_DimSca.selection.index;
            SysXml.DimCol = glb_DimCol.selection.index;
            SysXml.TxtSize = glb_TxtSize.text;

            readwriteXml("w", configFilePath, SysXml);
        }
        /*读取或写入XML配置文件。
            mode  "r" 读取，"w" 写入
            filePath 配置文件路径
            content  待写入内容（仅write模式使用）
            returns 返回文件内容字符串（仅read模式下）
        */
        function readwriteXml(mode, filePath, content) {
            var configFile = new File(filePath);

            if (mode == "r") {
                configFile.open("r");
                configFile.lineFeed = "Windows";   // 统一使用 Windows 换行符，保证跨平台一致性
                return configFile.read();
            }
            if (mode == "w") {
                configFile.encoding = "UTF-8";
                configFile.open("w", "TEXT");
                configFile.lineFeed = "Windows";
                configFile.write(content);
                configFile.close();
            }
        }

    }
    {//定义窗口
            //基础参数
            var WWid = 200 //宽度
                WHgt = 455-25 //高度（一行+25）
                WGap = 5    //间隙
                WRow = 20   //按钮高度
                WGrp = WRow+WGap //层高度
            //配置文件不存在时，先创建默认
            var configFile = new File(configFilePath);
            if (configFile.exists == false) {createXml(configFilePath);}

            // 读取配置文件内容并解析为 XML 对象
            var xmlContentStr = readwriteXml("r", configFilePath);
                SysXml = new XML(xmlContentStr);
        
            {//新建面板和折叠按钮
                try {
                    if ($.global.ExToolsPalette) {
                        $.global.ExToolsPalette.close();
                        $.global.ExToolsPalette = null;
                    }
                }catch (e) {}// 关闭之前的面板
                var OriWin = new Window("palette", "ExTools \u00A9 Kucha", [0, 0, WWid, WHgt]);//[x, y, width, height](xy是指左上角)
                    $.global.ExToolsPalette = OriWin;

                var FoldBtn = OriWin.add("button",[WGap*2, WGap, WGap*2+60, WGrp],"折叠");
                var ReSetDf = OriWin.add("button", [WWid-WGap*2-60, WGap, WWid-WGap*2, WGrp], "重置");//重置参数
                    ReSetDf.helpTip = "标注比例、颜色、高度恢复默认";

                var isFold = false;//默认为展开状态
                OriWin.bounds.height = WHgt;// 默认展开
                FoldBtn.onClick = function () {
                    isFold = !isFold;
                    if (isFold) {
                        OriWin.bounds.height = WGap + WGrp;
                        FoldBtn.text = "展开";
                    } else {
                        OriWin.bounds.height = WHgt;
                        FoldBtn.text = "折叠";
                    }
                };//展开或折叠
                ReSetDf.onClick = function () {
                    isFold = false;
                    FoldBtn.text = "折叠";
                    OriWin.bounds.height = WHgt;

                    glb_UnitChk.value = 1;
                    glb_VisibleChk.value = 0;
                    glb_DimSca.selection = 1;
                    glb_DimCol.selection = 3;
                    glb_TxtSize.text = "50.0";
                    save2Xml();// 保存到配置文件
                };//重置参数

            }

            //下方面板--------------------------------------------
            var PnlHgt01 = (WGap+WGrp)+(WGap*2+WRow*1+WGrp*4)+WGap*3
            MainPnl = OriWin.add("panel", [WGap, WGap+WGrp, WWid-WGap, PnlHgt01], "主功能");
                bt001 = MainPnl.add("button", [WGap*1, WGap*2+WRow*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], ">>> 一键快捷 <<<");
                    bt001.helpTip = "运行下方的功能01、功能02";
                bt002 = MainPnl.add("button", [WGap*1, WGap*2+WGrp*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], "01-文字转曲");
                    bt002.helpTip = "所选字/全部文字";
                bt003 = MainPnl.add("button", [WGap*1, WGap*2+WGrp*2, WWid-WGap*4, WGap*2+WRow*1+WGrp*2], "02-嵌入另存");
                    bt003.helpTip = "加前缀另存，并嵌入链接图";
                bt004 = MainPnl.add("button", [WGap*1, WGap*2+WGrp*3, WWid-WGap*4, WGap*2+WRow*1+WGrp*3], "导出JPEG预览");
                    bt004.helpTip = "按对象或按画板导出指定分辨率";
                bt005 = MainPnl.add("button", [WGap*1+(WWid-WGap*4) / 3*0, WGap*2+WGrp*4, (WWid-WGap*4) / 3*1, WGap*2+WRow*1+WGrp*4], "计算器");
                    bt005.helpTip = "提取数值求和或打开计算器";
                bt006 = MainPnl.add("button", [WGap*1+(WWid-WGap*4) / 3*1, WGap*2+WGrp*4, (WWid-WGap*4) / 3*2, WGap*2+WRow*1+WGrp*4], "找图标");
                    bt006.helpTip = "icons8+阿里图标";
                bt007 = MainPnl.add("button", [WGap*1+(WWid-WGap*4) / 3*2, WGap*2+WGrp*4, (WWid-WGap*4) / 3*3, WGap*2+WRow*1+WGrp*4], "识字体");
                    bt007.helpTip = "识字体+求字体";

            var PnlHgt02 = PnlHgt01+WGap*1+(WGap*2+WRow*1+WGrp*4)+WGap*3
            SubfPnl = OriWin.add("panel", [WGap*1, PnlHgt01+WGap*1, WWid-WGap, PnlHgt02], "标注");
                bt101 = SubfPnl.add("button", [WGap*1+(WWid-WGap*4) / 3*0, WGap*2+WGrp*0, (WWid-WGap*4) / 3*1, WGap*2+WRow*1+WGrp*0], "横向");
                    bt101.helpTip = "下方标: 横向尺寸";
                bt102 = SubfPnl.add("button", [WGap*1+(WWid-WGap*4) / 3*1, WGap*2+WGrp*0, (WWid-WGap*4) / 3*2, WGap*2+WRow*1+WGrp*0], "竖向");
                    bt102.helpTip = "右侧标: 竖向尺寸";
                bt103 = SubfPnl.add("button", [WGap*1+(WWid-WGap*4) / 3*2, WGap*2+WGrp*0, (WWid-WGap*4) / 3*3, WGap*2+WRow*1+WGrp*0], "编号");
                    bt103.helpTip = "编号+材料+数量";
                bt104 = SubfPnl.add("button", [WGap*1, WGap*2+WGrp*1, WWid-WGap*4, WGap*2+WRow*1+WGrp*1], "标注线长");
                    bt104.helpTip = "仅支持路径";
                var glb_UnitChk = SubfPnl.add("checkbox", [WGap*1+(WWid-WGap*4) / 2*0, WGap*2+WGrp*2, (WWid-WGap*4) / 2*1, WGap*2+WRow*1+WGrp*2], "显示单位");
                    glb_UnitChk.helpTip = "标注值带单位后缀cm";
                    glb_UnitChk.value = SysXml.UnitChk - 0;

                var glb_VisibleChk = SubfPnl.add("checkbox", [WGap*1+(WWid-WGap*4) / 2*1, WGap*2+WGrp*2, (WWid-WGap*4) / 2*2, WGap*2+WRow*1+WGrp*2], "考虑描边");
                    glb_VisibleChk.helpTip = "标注的尺寸考虑描边";
                    glb_VisibleChk.value = SysXml.VisibleChk - 0;
                glb_UnitChk.onClick = function () {
                    save2Xml();// 保存到配置文件
                };//单位
                glb_VisibleChk.onClick = function () {
                    save2Xml();// 保存到配置文件
                };//单位


                var DimScaLst = [
                    { ori: "1",   tgt: 1/10 },
                    { ori: "10",  tgt: 10/10 },
                    { ori: "20",  tgt: 20/10 },
                    { ori: "30",  tgt: 30/10 },
                    { ori: "40",  tgt: 40/10 },
                    { ori: "50",  tgt: 50/10 },
                    { ori: "60",  tgt: 60/10 },
                    { ori: "70",  tgt: 70/10 },
                    { ori: "80",  tgt: 80/10 },
                    { ori: "90",  tgt: 90/10 },
                    { ori: "100", tgt: 100/10},
                    { ori: "110", tgt: 110/10},
                    { ori: "120", tgt: 120/10},
                    { ori: "130", tgt: 130/10},
                    { ori: "140", tgt: 140/10},
                    { ori: "150", tgt: 150/10}
                ];//比例总表
                var DimColLst = [
                    { ori: "0 红", tgt: "ff0000" },
                    { ori: "1 橙", tgt: "ff8000" },
                    { ori: "2 黄", tgt: "ffff00" },
                    { ori: "3 绿", tgt: "00ff00" },
                    { ori: "4 青", tgt: "00ffff" },
                    { ori: "5 蓝", tgt: "0000ff" },
                    { ori: "6 紫", tgt: "ff00ff" },
                    { ori: "7 黑", tgt: "000000" },
                    { ori: "8 白", tgt: "ffffff" },
                    { ori: "9 灰", tgt: "808080" },
                ];//颜色总表

                var AllDimSca = []; var AllDimCol = [];
                for (var i = 0; i < DimScaLst.length; i++) { AllDimSca.push(DimScaLst[i].ori)};//收集所有比例
                for (var i = 0; i < DimColLst.length; i++) { AllDimCol.push(DimColLst[i].ori)};//收集所有颜色

                tt101 = SubfPnl.add("statictext", 
                    [WGap*1+(WWid-WGap*4) / 2*0, WGap*2+WGrp*3, WGap*1+30, WGap*2+WRow*1+WGrp*3], "倍率");//左侧文字
                    //tt101.enabled = false;
                var glb_DimSca = SubfPnl.add("dropdownlist",
                    [WGap*1+(WWid-WGap*4) / 2*0+30, WGap*2+WGrp*3, (WWid-WGap*4)/2 *1-WGap*1, WGap*2+WRow*1+WGrp*3],
                    AllDimSca
                );//右侧下拉框
                glb_DimSca.selection = parseInt(SysXml.DimSca, 10);
                tt102 = SubfPnl.add("statictext", 
                    [(WWid-WGap*4) / 2*1, WGap*2+WGrp*3, (WWid-WGap*4) / 2*1+30, WGap*2+WRow*1+WGrp*3], "颜色");//左侧文字
                    //tt102.enabled = false;
                var glb_DimCol = SubfPnl.add("dropdownlist",
                    [(WWid-WGap*4) / 2*1+30, WGap*2+WGrp*3, (WWid-WGap*4) / 2*2, WGap*2+WRow*1+WGrp*3],
                    AllDimCol
                );//右侧下拉框
                glb_DimCol.selection = parseInt(SysXml.DimCol, 10);

                tt103 = SubfPnl.add("statictext", 
                    [WGap*1, WGap*2+WGrp*4, WGap*1+30, WGap*2+WRow*1+WGrp*4], "大小");// 文本大小输入
                    //tt103.enabled = false;
                var glb_TxtSize = SubfPnl.add(
                    "edittext",
                    [WGap*1+30, WGap*2+WGrp*4, WWid-WGap*4-65, WGap*2+WRow*1+WGrp*4],
                    Number(SysXml.TxtSize).toFixed(1)
                );// 输入框
                var GetTxtSize = SubfPnl.add("button", [WWid-WGap*4-60, WGap*2+WGrp*4, WWid-WGap*4, WGap*2+WRow*1+WGrp*4], "取字号");
                GetTxtSize.helpTip = "获取所选文字字号";


            var PnlHgt03 = PnlHgt02+WGap*1+(WGap*2+WRow*1+WGrp*2)+WGap*3
            FilePnl = OriWin.add("panel",         [WGap*1, PnlHgt02+WGap*1, WWid-WGap, PnlHgt03],'其它');
                bt201 = FilePnl.add("button",     [WGap*1, WGap*2+WGrp*0, WWid-WGap*4, WGap*2+WRow*1+WGrp*0], "定位文件夹");
                    bt201.helpTip = "打开文件/链接所在路径";
                bt202 = FilePnl.add("button",     [WGap*1+(WWid-WGap*4)/2*0, WGap*2+WGrp*1, (WWid-WGap*4)/2*1, WGap*2+WRow*1+WGrp*1], "画板排序");
                    bt202.helpTip = "先上下后左右(5mm高度内视为同一行)";
                bt203 = FilePnl.add("button",     [WGap*1+(WWid-WGap*4)/2*1, WGap*2+WGrp*1, (WWid-WGap*4)/2*2, WGap*2+WRow*1+WGrp*1], "画板改名");
                    bt203.helpTip = "根据模式修改全部画板名称";
                bt204 = FilePnl.add("button",     [WGap*1+(WWid-WGap*4)/2*0, WGap*2+WGrp*2, (WWid-WGap*4)/2*1, WGap*2+WRow*1+WGrp*2], "解除编组");
                    bt204.helpTip = "所选组/全部可见组(忽略剪切蒙版)";
                bt205 = FilePnl.add("button",     [WGap*1+(WWid-WGap*4)/2*1, WGap*2+WGrp*2, (WWid-WGap*4)/2*2, WGap*2+WRow*1+WGrp*2], "链接打包");
                    bt205.helpTip = "打包到当前文件路径下";

            OriWin.center();
            OriWin.show();
    }
    {//按钮功能
        var SltDimSca = DimScaLst[glb_DimSca.selection.index].tgt;//默认参数
        glb_DimSca.onChange = function () {
            SltDimSca = DimScaLst[this.selection.index].tgt;
            save2Xml();// 保存到配置文件
        };
        var SltDimCol = DimColLst[glb_DimCol.selection.index].tgt;//默认参数
        glb_DimCol.onChange = function () {
            SltDimCol = DimColLst[this.selection.index].tgt;
            save2Xml();// 保存到配置文件
        };

        var LastTxtSize = glb_TxtSize.text;//默认值
        glb_TxtSize.onChange = function () {
            var num = Number(glb_TxtSize.text);
            // 判断是否为有效正数
            if (isNaN(num) || num <= 0) {
                alert("请输入大于 0 的正数！", "ExTools", true);
                glb_TxtSize.text = LastTxtSize;// 恢复上一次正确输入的值
                glb_TxtSize.active = true; // 重新激活输入框
            } else {
                LastTxtSize = glb_TxtSize.text;// 更新记录正确值
                save2Xml();// 保存到配置文件
            }
        };//失去焦点时检测
        GetTxtSize.onClick = function () {
            function UpTxtSizeInp () {
                var TxtSize = null;
                if (app.documents.length == 0) {
                    alert("请先打开任一文档!", "ExTools", true);
                    return TxtSize;
                }else{
                    var CurSlt = app.activeDocument.selection;
                    if (CurSlt.length !== 0) {
                        for (var i = CurSlt.length - 1; i >= 0; i--) {
                            if (CurSlt[i].typename === "TextFrame") {
                                var OriSize = CurSlt[i].textRange.characterAttributes.size;
                                if (TxtSize === null) {
                                    var TxtSize = OriSize;
                                }else {
                                    var TxtSize = (TxtSize + OriSize) * 0.5;
                                }
                            }
                        };// 遍历所有选中项，逐个递归处理
                        app.activeDocument.selection = null;//取消选择
                        return TxtSize;
                    }
            }
            }
            DoFunc(UpTxtSizeInp, [], function (val, err) {
                if (!err && val != null) {
                    LastTxtSize = glb_TxtSize.text = val.toFixed(1);
                    save2Xml();// 保存到配置文件
                }
            });
            
        };//回去并更新文字高度
        OriWin.onClose = function () {
            $.global.ExToolsPalette = null;
            return true;
        };
        //-----------------------------------------------------
        bt001.onClick = function () {
            DoFunc(SavedNoLost, [true], 
                function (val, err) {
                    //if (val && confirm("小概率会崩溃, 请做好备份!"))
                    if (val){
                        var funcList = [
                            [Txt_OutLine, [false]],
                            [Sv_aiFormat, [true]]
                        ];
                        for (var i = 0; i < funcList.length; i++) {
                            try {
                                DoFunc(funcList[i][0], funcList[i][1]);
                                $.sleep(500);
                            } catch (err) {
                                // 嵌入失败也不会卡死
                            }
                        }
                    }
                }
            )
        };
        bt002.onClick = function () {
            DoFunc(Txt_OutLine, [true])
        };//文字转曲
        bt003.onClick = function () {
            DoFunc(SavedNoLost, [false], 
                function (val) {
                    if (val && confirm("文件名增加前缀【嵌入】后另存？" + String.fromCharCode(10) + String.fromCharCode(10) + "一键快捷时，前缀为【下印】")) {
                        DoFunc(Sv_aiFormat, [false])
                    }
                }
            )
        };//嵌入另存
        bt004.onClick = function () {
            function GetDPI4JPG(TgtDPI) {
                var DPIWin = new Window("dialog", "输入分辨率");
                var input = DPIWin.add("edittext", undefined, String(TgtDPI));
                    input.characters = 10;
                    input.active = true;//激活输入
                var OkBtn = DPIWin.add("button", undefined, "确定");
                
                OkBtn.onClick = function () {
                    var num = Number(input.text);
                    if (isNaN(num) || num <= 0 || num > 558) {
                        alert("请输入1~558的正数！", "ExTools", true);// 弹出警告
                        //input.active = true;
                    } else {
                        DPIWin.close(1);
                    }
                }

                DPIWin.defaultElement = OkBtn;//默认启用回车
                if (DPIWin.show() == 1) {
                    return Number(input.text);
                }
                return null;
            };//返回DPI
            DoFunc(OpenNow, [], function (val) {if (val){
                DoFunc(SaveAs_JPG, [GetDPI4JPG(300)])
            }})
        };//导出JPEG预览
        bt005.onClick = function () {DoFunc(OpenCalSum)};//计算器
        bt006.onClick = function () {Web_OpenUrl(SysFolder.fsName, ["https://icons8.com/", "https://www.iconfont.cn/"]);};//图标
        bt007.onClick = function () {Web_OpenUrl(SysFolder.fsName, ["https://www.likefont.com/", "https://www.qiuziti.com/"]);};//识字
        //-----------------------------------------------------
        
        bt101.onClick = function () {DoFunc(Dim_horizonta, [glb_UnitChk.value, glb_VisibleChk.value, SltDimSca, SltDimCol, LastTxtSize])};//横向尺寸
        bt102.onClick = function () {DoFunc(Dim_vertical,  [glb_UnitChk.value, glb_VisibleChk.value, SltDimSca, SltDimCol, LastTxtSize])};//竖向尺寸
        bt103.onClick = function () {DoFunc(Dim_TxtNote,   [SysFolder.fsName, LastTxtSize])};//编号
        bt104.onClick = function () {DoFunc(Dim_LineLen,   [glb_UnitChk.value, SltDimSca, SltDimCol, LastTxtSize])};//标注线长

        bt201.onClick = function () {DoFunc(Doc_CurPath)};//打开文件夹
        bt202.onClick = function () {DoFunc(SortArtOrder)};//画板重排序
        bt203.onClick = function () {DoFunc(ReAllArtbNam)};//画板全改名
        bt204.onClick = function () {DoFunc(UnGroup_All)};//解除可见组
        bt205.onClick = function () {
            DoFunc(SavedNow, [], function (val) {if (val){ DoFunc(Img_linksExp)}})
        };//链接图打包
        
    }

    {//子功能
        function Txt_OutLine(SaveFlag) {
            {//基础函数
                function GetfileNam(fileName) {
                    var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
                    return dot >= 0 ? fileName.substring(0, dot) : fileName;
                };//文件名(不带扩展)——非正则
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
                };//转曲文字数组
                function OutlineGroup(GrpItem) {
                    //先处理组内文字
                    if (GrpItem.textFrames.length > 0) {
                        OutlineText(GrpItem.textFrames);
                    }
                    //递归子组
                    for (var i = GrpItem.groupItems.length - 1; i >= 0; i--) {
                        OutlineGroup(GrpItem.groupItems[i]);
                    }
                };//递归处理组
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
                            };//处理当前图层文字
                            if (layers[i].layers.length > 0) {
                                OutlineLayer(layers[i].layers);
                            };//先递归子图层
                            for (var j = layers[i].groupItems.length - 1; j >= 0; j--) {
                                OutlineGroup(layers[i].groupItems[j]);
                            };//再递归组

                            //恢复状态
                            layers[i].locked = l;
                            layers[i].visible = v;

                        } catch (e) {}
                    }
                };//递归处理图层
                function DoSltItem (item) {
                    if (item.typename === "TextFrame") {
                        OutlineText([item]);
                        return;
                    };//当前对象如果是文字，直接转曲
                    if (item.typename === "GroupItem") {
                        if (item.textFrames.length > 0) {
                            OutlineText(item.textFrames);
                        }
                        for (var i = item.groupItems.length - 1; i >= 0; i--) {
                            DoSltItem(item.groupItems[i]);
                        };// 遍历嵌套子组/子对象
                    };//当前对象是组，先处理组内所有文字，再递归子组
                };// 递归处理任意对象（组、文字、嵌套组）
            }
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
                return false;
            }else{
                var CurDoc = app.activeDocument
                var CurSlt = CurDoc.selection;
                if (CurSlt.length === 0) {
                    if (!new File(CurDoc.fullName).exists) {
                        alert("请先保存文件!", "ExTools", true);
                        return false;
                    } else {
                        if (!CurDoc.saved) {
                            alert("请先保存文件!", "ExTools", true);
                            return false;
                        } else {
                                OutlineLayer(CurDoc.layers);//文件全转曲

                                if(SaveFlag){
                                    var aiSaveOpts = new IllustratorSaveOptions();
                                        aiSaveOpts.compatibility = Compatibility.ILLUSTRATOR24;//保存为2020
                                        aiSaveOpts.embedLinkedFiles = true;//勾选【包含链接的文件】
                                        aiSaveOpts.embedICCProfile = true;//勾选【嵌入ICC配置文件】
                                        aiSaveOpts.pdfCompatible = false;//不保存PDF兼容

                                    var FileName = GetfileNam(CurDoc.name)
                                    if(FileName.indexOf("【转曲】") === 0 || FileName.indexOf("【嵌入】") === 0 || FileName.indexOf("【下印】") === 0){
                                        FileName = FileName.substring(4);
                                    }//清除前缀
                                    var SavePath = CurDoc.path.fsName + "/【转曲】" + FileName + ".ai";
                                        CurDoc.saveAs(new File(SavePath), aiSaveOpts);//保存为AI
                                    alert("文字已全部转曲" + String.fromCharCode(10) + String.fromCharCode(10) + "文件名增加前缀【转曲】后另存", "ExTools", false)
                                }
                        }
                    }
                    return true;
                }else{
                    for (var k = CurSlt.length - 1; k >= 0; k--) {
                        DoSltItem(CurSlt[k]);
                        //alert("所选文字已全部转曲", "ExTools", false)
                    };// 遍历所有选中项，逐个递归处理
                    return true;
                }
            }
            
        };//文字转曲//所选字/全部文字
        function Sv_aiFormat(OutTxt){
            function GetfileNam(fileName) {
                var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
                return dot >= 0 ? fileName.substring(0, dot) : fileName;
            };//文件名(不带扩展)——非正则
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
            }else{
                var CurDoc = app.activeDocument;
                var CurLink = CurDoc.placedItems;

                if (CurLink.length !== 0) {
                    var OkCnt = 0; var NoCnt = 0;
                    for (var i = CurLink.length - 1; i >= 0; i--) {
                        try {
                            CurLink[i].embed();
                            OkCnt++;
                        } catch (e) {
                            NoCnt++;
                        }
                    }// 必须从后往前遍历，因为嵌⼊操作会改变链接列表的⻓度
                    CurDoc.selection = null;//取消选择
                }//嵌入链接图
                try {//另存文件
                    var aiSaveOpts = new IllustratorSaveOptions();
                        aiSaveOpts.compatibility = Compatibility.ILLUSTRATOR24;//保存为2020
                        aiSaveOpts.embedLinkedFiles = true;//勾选【包含链接的文件】
                        aiSaveOpts.embedICCProfile = true;//勾选【嵌入ICC配置文件】
                        aiSaveOpts.pdfCompatible = false;//不保存PDF兼容

                    var FileName = GetfileNam(CurDoc.name)
                    if(FileName.indexOf("【转曲】") === 0 || FileName.indexOf("【嵌入】") === 0 || FileName.indexOf("【下印】") === 0){
                        FileName = FileName.substring(4);
                    }//清除前缀

                    var SavePath = CurDoc.path.fsName + (OutTxt ? "/【下印】" : "/【嵌入】") + FileName + ".ai";
                        CurDoc.saveAs(new File(SavePath), aiSaveOpts);//保存为AI
                } catch (e) {}
            }
        };//嵌入保存//加前缀另存，并嵌入链接图
        function SaveAs_JPG(TgtDPI) {
            {//基础函数
                function GetfileNam(fileName) {
                    var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
                    return dot >= 0 ? fileName.substring(0, dot) : fileName;
                };//文件名(不带扩展)——非正则
                function CleanFileNam(name) {
                    name = String(name);
                    name = name.replace(/^\s+|\s+$/g, "");// 去除首尾空格
                    name = name.replace(/[\r\n]+/g, " ");// 换行替换为空格
                    name = name.replace(/[*]/g, "x");// * 替换为 x
                    //name = name.replace(/[\/:?"<>|]/g, " ");// 特殊字符替换为空格
                    return name;
                };//整理字符串
                function Exp2JPEG(TgtDoc, TgtDPI, TgtFile) {
                    var options = new ExportOptionsJPEG();
                        options.antiAliasing = true;// 启用抗锯齿：文字、斜线等边缘更加平滑
                        options.artBoardClipping = true;// 按照画板范围进行裁切
                        options.optimization = true;//针对 Web 显示进行优化
                        options.blurAmount = 0;// 导出时不添加额外模糊

                        options.qualitySetting = 100;// 图像质量
                        options.horizontalScale = options.verticalScale = TgtDPI / 0.72;// DPI缩放

                        //options.matte = false;// 底色默认为白
                        //options.saveAsHTML = false;// 导出时不生成HTML

                    TgtDoc.exportFile(TgtFile, ExportType.JPEG, options);
                };//导出JPEG
            }
            if (TgtDPI >= 0){CurDoc.path.fsNam
                var CurDoc = app.activeDocument;
                var CurArt = CurDoc.artboards;
                var CurSlt = CurDoc.selection;//选择集
                var FileName = GetfileNam(CurDoc.name)
                if(FileName.indexOf("【转曲】") === 0 || FileName.indexOf("【嵌入】") === 0 || FileName.indexOf("【下印】") === 0){
                    FileName = FileName.substring(4);
                }//清除前缀
                
                if (CurSlt.length === 0) {
                    if (CurArt.length === 1) {
                        var SavePath = new Folder(CurDoc.path.absoluteURI);
                        try {
                            var jpgFile = new File(
                                SavePath.absoluteURI
                                + "//【预览】"
                                + FileName
                                + ".jpg"
                            );
                            Exp2JPEG(CurDoc, TgtDPI, jpgFile);
                        } catch (e) {}
                    } else {
                        var SavePath = new Folder(
                                decodeURI(CurDoc.path.absoluteURI)
                                + "//【预览】"
                                + FileName
                        );
                        if (!SavePath.exists) SavePath.create();//不存在则新建

                        var OldArt = CurArt.getActiveArtboardIndex();
                        try {
                            var NamLst = {};
                            for (var i = 0; i < CurArt.length; i++) {// 循环遍历文档中的所有画板
                                try {

                                    CurArt.setActiveArtboardIndex(i);//设置活动画板
                                    var FileNam = CleanFileNam(CurArt[i].name)

                                    var TestNam = FileNam;
                                    var Index = 1;
                                    while (NamLst[TestNam]) {
                                        TestNam = FileNam + "_" + Index;
                                        Index++;
                                    };//直到文件名不重复
                                    NamLst[TestNam] = true;//存哈希表
                                    var jpgFile = new File(SavePath + "//" + TestNam + ".jpg");
                                    Exp2JPEG(CurDoc, TgtDPI, jpgFile);

                                } catch (e) { }
                            }
                        } finally {
                            CurArt.setActiveArtboardIndex(OldArt);// 恢复执行脚本之前的活动画板
                        }

                        Folder(SavePath).execute();// 打开路径
                    }
                }else{
                        var SavePath = new Folder(decodeURI(CurDoc.path.absoluteURI));
                        try {
                                // 获取选择对象整体边界
                                var bounds = CurSlt[0].visibleBounds;
                                var L_Art = bounds[0];
                                var T_Art = bounds[1];
                                var R_Art = bounds[2];
                                var B_Art = bounds[3];
                                for (var i = 1; i < CurSlt.length; i++) {
                                    var b = CurSlt[i].visibleBounds;
                                    if (b[0] < L_Art) L_Art = b[0];
                                    if (b[1] > T_Art) T_Art = b[1];
                                    if (b[2] > R_Art) R_Art = b[2];
                                    if (b[3] < B_Art) B_Art = b[3];
                                }

                                // 创建临时画板
                                var TgtCnt = CurArt.length;
                                var OldArt = CurArt.getActiveArtboardIndex();
                                var tempAB = CurArt.add([L_Art, T_Art, R_Art, B_Art]);
                                    CurArt.setActiveArtboardIndex(TgtCnt);// 激活临时画板

                                var jpgFile = new File(
                                    SavePath.absoluteURI
                                    + "//【预览】"
                                    + GetfileNam(CurDoc.name)
                                    + ".jpg"
                                );
                                Exp2JPEG(CurDoc, TgtDPI, jpgFile);

                                CurArt.setActiveArtboardIndex(OldArt);// 激活之前的画板
                                CurDoc.artboards.remove(TgtCnt);// 删除临时画板
                                
                        } catch (e) {alert(e)}
                }
            }
            //app.redraw();
        };//导出JPEG预览//按对象或按画板导出指定分辨率
        function OpenCalSum() {
            if (app.documents.length == 0) {
                new File("C:/Windows/System32/calc.exe").execute();
            } else {
                var CurDoc = app.activeDocument;
                var CurSlt = CurDoc.selection;//选择集
                if (CurSlt.length == 0) {
                    new File("C:/Windows/System32/calc.exe").execute();
                } else {
                    var txtCnt = 0;     // 文字对象数量
                    var numCnt = 0;     // 成功提取数字数量
                    var NumSum = 0;     // 总和

                    for (var i = 0; i < CurSlt.length; i++) {
                        var obj = CurSlt[i];
                        // 判断是否是文字对象
                        if (obj.typename == "TextFrame") {
                            txtCnt++;
                            var content = obj.contents;

                            var num = "";
                            var started = false;
                            var hasDot = false;
                            for (var k = 0; k < content.length; k++) {
                                var c = content.charAt(k);
                                // 第一个数字开始
                                if (!started) {
                                    // 正常数字
                                    if (c >= "0" && c <= "9") {
                                        num += c;
                                        started = true;
                                    }
                                    // 负数，判断后面必须是数字
                                    else if (c == "-") {
                                        var next = content.charAt(k + 1);
                                        if (next >= "0" && next <= "9") {
                                            num += c;
                                            started = true;
                                        }
                                    }
                                } else {
                                    // 数字继续
                                    if (c >= "0" && c <= "9") {
                                        num += c;
                                    }
                                    // 小数点
                                    else if (c == "." && !hasDot) {
                                        // 小数点后必须还有数字
                                        var next = content.charAt(k + 1);
                                        if (next >= "0" && next <= "9") {
                                            num += c;
                                            hasDot = true;
                                        } else {
                                            break;
                                        }
                                    }
                                    else {
                                        break;
                                    }

                                }
                            }
                            if (num != "" && num != "-") {
                                NumSum += Number(num);
                                numCnt++;
                            }
                        }
                    }
                    // 判断是否包含文字
                    if (txtCnt == 0 || numCnt == 0) {
                        new File("C:/Windows/System32/calc.exe").execute();
                    } else {
                        alert(
                            "读取到【"+ txtCnt + "】个文字"
                            + (txtCnt !== numCnt
                                ? String.fromCharCode(10) + "其中有【" + (txtCnt - numCnt) + "】个未提取到数字"
                                : ""
                            )
                            + String.fromCharCode(10) + String.fromCharCode(10) + "求和结果【" + NumSum + "】"
                            , "ExTools", false
                        );
                    }
                }
            }
        };//计算器//提取数值求和或打开计算器
        function Web_OpenUrl(SysPath, Urls) {
            // 循环打开每个网址
            for (var i = 0; i < Urls.length; i++) {
                try {
                    var wd = File(SysPath + "/openURL.url");
                        wd.open("w");
                        wd.write("[InternetShortcut]\rURL=" + Urls[i] + "\r");
                        wd.close();
                        wd.execute();
                        $.sleep(500);//休眠等待
                } catch (e) {}
            }
        };//创建网页并打开
    } 
    {//标注功能
        function Dim_horizonta(UseUnit, UseVis, TgtSca, TgtCol, TxtSize) {
            {//基础函数
                function NOClipBound(Tobj, isVis) {
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
                    };//收集可视边界对象
                    var TgtLst = [];
                        getAllobjs_NoClip(Tobj);//收集

                    var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
                    for (var i = 0; i < TgtLst.length; i++) {
                        var TmpBox = isVis ? TgtLst[i].visibleBounds : TgtLst[i].geometricBounds;
                        // 几何边界
                        tmpL = Math.min(tmpL, TmpBox[0]);
                        tmpT = Math.max(tmpT, TmpBox[1]);
                        tmpR = Math.max(tmpR, TmpBox[2]);
                        tmpB = Math.min(tmpB, TmpBox[3]);
                    };//返回直接返回结果
                    return [tmpL, tmpT, tmpR, tmpB];
                };//获取对象外框
                function Hex2RGBCol(HexStr){
                    HexStr = HexStr.replace("#","");
                    var r = parseInt(HexStr.substr(0,2),16);
                    var g = parseInt(HexStr.substr(2,2),16);
                    var b = parseInt(HexStr.substr(4,2),16);
                    var c = new RGBColor();
                    c.red = r;
                    c.green = g;
                    c.blue = b;
                    return c;
                };//HEX颜色转RGBCol色
            }
            var CurDoc = app.activeDocument;
                CurSlt = CurDoc.selection;   
            {//创建标注图层
                var UseCol = Hex2RGBCol(TgtCol);
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
                alert("未选择对象", "ExTools", true);
            }else{
                CurLay = CurDoc.activeLayer; // 记录当前图层
                app.redraw = false;//关闭刷新
                try {//你的程序
                    for (var i = 0; i < CurSlt.length; i += 1) {
                        var bound = NOClipBound(CurSlt[i], UseVis);
                        var L = bound[0];
                        var T = bound[1];
                        var W = bound[2] - bound[0];
                        var H = bound[1] - bound[3];
                        if (W <= 0) {continue};//如果宽度为0跳过

                        var LDis = TxtSize * 0.8;//标注线与对象的间距
                        var dimline = dimLay.pathItems.add();//创建水平标注线
                            dimline.setEntirePath(new Array(new Array(L, (T - H) - LDis), new Array(L + W, (T - H) - LDis)));
                            dimline.filled = false;// 必须！否则线宽可能不生效
                            dimline.stroked = true;//开启线宽
                            dimline.strokeWidth = TxtSize * 0.1;//线条宽度
                            dimline.strokeColor = UseCol;
                        var DimNum = (Math.round(UnitValue(W, "pt").as("mm") * 10) / 10) * TgtSca
                        var dimText = dimLay.textFrames.add();//创建标注文字
                            dimText.contents = DimNum + (UseUnit ? " cm" : "");//pt → 毫米
                            dimText.textRange.characterAttributes.size = TxtSize;
                            if (UseUnit) {
                                var Start = DimNum.toString().length;
                                for (var i = Start; i < dimText.contents.length; i++) {
                                    dimText.textRange.characters[i]
                                        .characterAttributes.size = TxtSize * 1.0;
                                }
                            }//单独字号
                            dimText.textRange.characterAttributes.fillColor = UseCol;
                            dimText.textRange.justification = Justification.CENTER;//文字居中
                            //文字放置
                            dimText.left = (L + (W / 2)) - (dimText.width / 2);
                            dimText.top = ((T - H) - LDis) - (LDis / 5);

                            dimline.name = "Dim_Line";//名称
                            dimText.name = "Dim_Text";//名称
                    }
                } catch (e) {//nothing
                } finally {
                    CurDoc.activeLayer = CurLay; // 恢复原先图层
                    app.redraw = true;//恢复更新
                    app.redraw(); // 最终刷新一次
                }
            }
        };//横向尺寸
        function Dim_vertical(UseUnit, UseVis, TgtSca, TgtCol, TxtSize) {
            {//基础函数
                function NOClipBound(Tobj, isVis) {
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
                    };//收集可视边界对象
                    var TgtLst = [];
                        getAllobjs_NoClip(Tobj);//收集

                    var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
                    for (var i = 0; i < TgtLst.length; i++) {
                        var TmpBox = isVis ? TgtLst[i].visibleBounds : TgtLst[i].geometricBounds;
                        // 几何边界
                        tmpL = Math.min(tmpL, TmpBox[0]);
                        tmpT = Math.max(tmpT, TmpBox[1]);
                        tmpR = Math.max(tmpR, TmpBox[2]);
                        tmpB = Math.min(tmpB, TmpBox[3]);
                    };//返回直接返回结果
                    return [tmpL, tmpT, tmpR, tmpB];
                };//获取对象外框
                function Hex2RGBCol(HexStr){
                    HexStr = HexStr.replace("#","");
                    var r = parseInt(HexStr.substr(0,2),16);
                    var g = parseInt(HexStr.substr(2,2),16);
                    var b = parseInt(HexStr.substr(4,2),16);
                    var c = new RGBColor();
                    c.red = r;
                    c.green = g;
                    c.blue = b;
                    return c;
                };//HEX颜色转RGBCol色
            }
            var CurDoc = app.activeDocument;
                CurSlt = CurDoc.selection;
            if (CurSlt.length < 1) {alert("未选择对象", "ExTools", true); return;}
            {//创建标注图层
                var UseCol = Hex2RGBCol(TgtCol);
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
                    var bound = NOClipBound(CurSlt[i], UseVis);
                    var L = bound[0];
                    var T = bound[1];
                    var W = bound[2] - bound[0];
                    var H = bound[1] - bound[3];
                    if (H <= 0) {continue};//如果高度为0跳过

                    LDis = TxtSize * 0.8;// 标注线与对象的间距
                    var dimline = dimLay.pathItems.add();
                        dimline.setEntirePath(new Array(new Array(L + W + LDis, T), new Array(L + W + LDis, T - H)));
                        dimline.filled = false;// 必须！否则线宽可能不生效
                        dimline.stroked = true;//开启线宽
                        dimline.strokeWidth = TxtSize * 0.1;//线条宽度
                        dimline.strokeColor = UseCol;

                    var DimNum = (Math.round(UnitValue(H,"pt").as("mm") * 10) / 10) * TgtSca
                    var dimText = dimLay.textFrames.add();
                        dimText.contents = DimNum + (UseUnit ? " cm" : "");//pt → 毫米
                        dimText.textRange.characterAttributes.size = TxtSize;
                        if (UseUnit) {
                            var Start = DimNum.toString().length;
                            for (var i = Start; i < dimText.contents.length; i++) {
                                dimText.textRange.characters[i]
                                    .characterAttributes.size = TxtSize * 1.0;
                            }
                        }//单独字号
                        dimText.textRange.characterAttributes.fillColor = UseCol;
                        dimText.textRange.justification = Justification.CENTER;//文字居中
                        //文字放置
                        dimText.left = L + W + LDis*2 - (dimText.width / 2);
                        dimText.top = (T - (H / 2)) + (dimText.height / 2);
                        dimText.rotate(90);

                        dimline.name = "Dim_Line";//名称
                        dimText.name = "Dim_Text";//名称
                }
            } catch (e) {//nothing
            } finally {
                CurDoc.activeLayer = CurLay; // 恢复原先图层
                app.redraw = true;//恢复更新
                app.redraw(); // 最终刷新一次
            }
        };//竖向尺寸
        function Dim_TxtNote(XmlFolder, TxtSize) {
            {//基础函数
                function GetStartN(Txt) {
                    var Key = "{N=";
                    var Pos1 = Txt.indexOf(Key);
                    if (Pos1 < 0) { return null; }// 没有找到 {N=
                    var Pos2 = Txt.indexOf("}",
                        Pos1 + Key.length
                    );// 从 {N= 后面开始寻找 }

                    if (Pos2 < 0) { return null; }// 没有找到结束符
                    var NumStr = Txt.substring(
                        Pos1 + Key.length,
                        Pos2
                    );// 取得数字部分

                    if (NumStr === "") { return null; }// 没有数字
                    var Num = Number(NumStr);

                    if (isNaN(Num)) { return null; }// 不是有效数字
                    return {
                        value: Num,
                        start: Pos1,
                        end: Pos2 + 1
                    };
                }//解析占位符数字
                function RepStartN(Txt, NewN) {
                    var Info = GetStartN(Txt);
                    if (Info === null) { return Txt; }

                    return Txt.substring(0, Info.start)
                        + String(NewN)
                        + Txt.substring(Info.end);
                }//替换占位符为数字
                function UpdStartN(Txt, NewN) {
                    /*
                        A{N=2}雪弗板字*1套
                        更新为：
                        /A{N=4}雪弗板字*1套
                    */
                    var Info = GetStartN(Txt);
                    if (Info === null) { return Txt; }


                    return Txt.substring(0, Info.start)
                        + "{N="
                        + String(NewN)
                        + "}"
                        + Txt.substring(Info.end);
                }//更新占位符数字
                function CreateText(Tsize, TgtTxt, TgtCol, TgtPos) {
                    {//基础函数
                        function NOClipBound(Tobj, isVis) {
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
                            };//收集可视边界对象
                            var TgtLst = [];
                                getAllobjs_NoClip(Tobj);//收集

                            var tmpL = Infinity, tmpT = -Infinity, tmpR = -Infinity, tmpB = Infinity; // 初始化极值
                            for (var i = 0; i < TgtLst.length; i++) {
                                var TmpBox = isVis ? TgtLst[i].visibleBounds : TgtLst[i].geometricBounds;
                                // 几何边界
                                tmpL = Math.min(tmpL, TmpBox[0]);
                                tmpT = Math.max(tmpT, TmpBox[1]);
                                tmpR = Math.max(tmpR, TmpBox[2]);
                                tmpB = Math.min(tmpB, TmpBox[3]);
                            };//返回直接返回结果
                            return [tmpL, tmpT, tmpR, tmpB];
                        };//获取对象外框
                        function Hex2RGBCol(HexStr){
                            HexStr = HexStr.replace("#","");
                            var r = parseInt(HexStr.substr(0,2),16);
                            var g = parseInt(HexStr.substr(2,2),16);
                            var b = parseInt(HexStr.substr(4,2),16);
                            var c = new RGBColor();
                            c.red = r;
                            c.green = g;
                            c.blue = b;
                            return c;
                        };//HEX颜色转RGBCol色
                    }
                    {//创建标注图层
                        var UseCol = Hex2RGBCol(TgtCol);

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
                    if (CurSlt.length == 0) {
                        alert("未选择对象", "ExTools", true); 
                        return 0;
                    }


                    // ========================================================
                    // 读取 StartN
                    //
                    // 不使用正则表达式
                    //
                    // 例如：
                    //
                    // A{N=2}雪弗板字*1套
                    //
                    // StartN = 2
                    // ========================================================


                    var StartN = 1;
                    var StartInfo = GetStartN(TgtTxt);// 读取 StartN
                    if (StartInfo !== null) { StartN = StartInfo.value; }
                    var HasStartN = StartInfo !== null;//是否存在 StartN
                    // 建立对象信息数组
                    var ObjLst = [];
                    for ( var s = 0; s < CurSlt.length;s++) {
                        var ObjBound = NOClipBound( CurSlt[s], false);
                        ObjLst.push(
                            {
                                obj: CurSlt[s],
                                left: ObjBound[0],
                                top: ObjBound[1],
                                right: ObjBound[2],
                                bottom: ObjBound[3]
                            }
                        );
                    }
                    ObjLst.sort(
                        function(a, b){
                            // top差值绝对值 ≤10mm → 同一行，按left升序（从左往右）
                            if(Math.abs(a.top - b.top) <= UnitValue(5,"mm").as("pt")){
                                return a.left - b.left;
                            }
                            //不同行：从上到下，top小的排前面（AI坐标系）
                            return b.top - a.top;
                        }
                    );

                    var CreateCnt = 0;//记录实际创建成功的标注数量
                    app.redraw = false;// 关闭刷新
                    try {
                        for ( var i = 0; i < ObjLst.length; i += 1) {
                            var bound = [ObjLst[i].left, ObjLst[i].top, ObjLst[i].right, ObjLst[i].bottom];
                            var L = bound[0];
                            var T = bound[1];
                            var W = bound[2] - bound[0];
                            var H = bound[1] - bound[3];

                            var CurTxt = TgtTxt;
                            if (HasStartN) {
                                CurTxt = RepStartN(CurTxt, StartN + CreateCnt);
                            }
                            // 创建文字
                            var dimText = DimLay.textFrames.add();
                                dimText.contents = CurTxt;
                                dimText.textRange.characterAttributes.size = Tsize;
                                dimText.textRange.characterAttributes.fillColor = UseCol;
                                dimText.name = "Dim_Text";
                            // 标注位置
                            if (TgtPos === "T") {
                                dimText.textRange.justification = Justification.CENTER;
                                dimText.left = (L + (W / 2)) - (dimText.width / 2);
                                dimText.top = T + Tsize * 2;
                            }
                            else if (TgtPos === "B") {
                                dimText.textRange.justification = Justification.CENTER;
                                dimText.left = (L + (W / 2)) - (dimText.width / 2);
                                dimText.top = T - H - Tsize * 1;
                            }
                            else if (TgtPos === "R") {
                                dimText.textRange.justification = Justification.LEFT;
                                dimText.left = L + W + Tsize * 1;
                                dimText.top = T - (H / 2) + (dimText.height / 2);
                            }
                            else if (TgtPos === "L") {
                                dimText.textRange.justification = Justification.RIGHT;
                                dimText.left = L - dimText.width - Tsize * 1;
                                dimText.top = T - (H / 2) + (dimText.height / 2);
                            }
                            //成功创建文字后增加计数
                            CreateCnt++;
                        }
                    }catch (e) {
                    }finally {
                        app.redraw = true;
                        app.redraw();
                    }
                    return CreateCnt;// 返回本次实际标注数量
                };//编号
                {//配置函数
                    //当配置文件不存在时，写入默认参数。
                    function createXml(filePath) {
                        NumXml = new XML("<KuchaData></KuchaData>");
                        NumXml.Txt = "A{N=1}雪弗板字*1套";       //选择的比例
                        NumXml.Col = 1;       //选择的颜色
                        NumXml.Pos = "L";     //选择的位置
                        readwriteXml("w", filePath, NumXml);
                    }
                    //将输入值保存到配置文件
                    function save2Xml() {
                        NumXml.Txt = glb_Txt.text;
                        NumXml.Col = glb_Col.selection.index;
                        if (Pos_T.value) NumXml.Pos = "T";
                        else if (Pos_B.value) NumXml.Pos = "B";
                        else if (Pos_L.value) NumXml.Pos = "L";
                        else if (Pos_R.value) NumXml.Pos = "R";

                        readwriteXml("w", configFilePath, NumXml);
                    }
                    /*读取或写入XML配置文件。
                        mode  "r" 读取，"w" 写入
                        filePath 配置文件路径
                        content  待写入内容（仅write模式使用）
                        returns 返回文件内容字符串（仅read模式下）
                    */
                    function readwriteXml(mode, filePath, content) {
                        var configFile = new File(filePath);

                        if (mode == "r") {
                            configFile.open("r");
                            configFile.lineFeed = "Windows";   // 统一使用 Windows 换行符，保证跨平台一致性
                            return configFile.read();
                        }
                        if (mode == "w") {
                            configFile.encoding = "UTF-8";
                            configFile.open("w", "TEXT");
                            configFile.lineFeed = "Windows";
                            configFile.write(content);
                            configFile.close();
                        }
                    }
                }
            }
            // 检查当前是否选择对象
            if (app.activeDocument.selection.length < 1) {
                alert("未选择对象", "ExTools",true);
                return;
            }

            try {
                if ($.global.DimNumPalette) {
                    $.global.DimNumPalette.close();
                    $.global.DimNumPalette = null;
                }
            }catch (e) {}// 关闭之前的面板

            // 配置文件
            var configFilePath = XmlFolder + "/NumSys.xml";
            var configFile =new File(configFilePath);
            if (configFile.exists == false) {
                createXml(configFilePath);
            }

            // 读取配置文件
            var xmlContentStr =readwriteXml("r", configFilePath);
                NumXml =new XML(xmlContentStr);
            {//定义窗口
                var NumWin = new Window("dialog", "编号设置");
                    $.global.DimNumPalette = NumWin;
                    
                    NumWin.alignChildren = ["fill", "top"];
                    NumWin.spacing = 15;
                    NumWin.margins = 10;

                // 文字内容
                var Grp01 = NumWin.add("group");
                    Grp01.orientation = "row";
                    Grp01.add("statictext", undefined, "内容：");
                var glb_Txt = Grp01.add("edittext", undefined, NumXml.Txt);
                    glb_Txt.characters = 20;
                
                
                var NumColLst = [
                    { ori: "0 红", tgt: "ff0000" },
                    { ori: "1 橙", tgt: "ff8000" },
                    { ori: "2 黄", tgt: "ffff00" },
                    { ori: "3 绿", tgt: "00ff00" },
                    { ori: "4 青", tgt: "00ffff" },
                    { ori: "5 蓝", tgt: "0000ff" },
                    { ori: "6 紫", tgt: "ff00ff" },
                    { ori: "7 黑", tgt: "000000" },
                    { ori: "8 白", tgt: "ffffff" },
                    { ori: "9 灰", tgt: "808080" },
                ];//颜色总表
                AllNumCol = [];
                for (var i = 0; i < NumColLst.length; i++) {AllNumCol.push(NumColLst[i].ori)};//收集所有颜色

                var Grp02 = NumWin.add("group");
                    Grp02.orientation = "row";
                    Grp02.add("statictext", undefined, "颜色：");
                var glb_Col = Grp02.add("dropdownlist", undefined, AllNumCol);//右侧下拉框
                    //glb_Col.characters = 20;
                    glb_Col.selection = parseInt(NumXml.Col, 10);
                var ReSet = Grp02.add("button", undefined, "重置");//重置参数
                    ReSet.helpTip = "参数恢复默认";
            
                // 标注位置
                var Grp03 = NumWin.add("group");
                    Grp03.orientation = "row";
                    Grp03.add("statictext", undefined, "位置：");
                var Pos_T = Grp03.add("radiobutton", undefined, "上"),
                    Pos_B = Grp03.add("radiobutton", undefined, "下"),
                    Pos_L = Grp03.add("radiobutton", undefined, "左"),
                    Pos_R = Grp03.add("radiobutton", undefined, "右");
                    if (String(NumXml.Pos) === "T") Pos_T.value = true;
                    else if (String(NumXml.Pos) === "B") Pos_B.value = true;
                    else if (String(NumXml.Pos) === "L") Pos_L.value = true;
                    else if (String(NumXml.Pos) === "R") Pos_R.value = true;


                // 按钮区域
                var BtnGrp = NumWin.add("group");
                    BtnGrp.orientation = "row";
                    BtnGrp.alignment = "center";
                var OkBtn = BtnGrp.add("button", undefined, "确定"),
                    NoBtn = BtnGrp.add("button", undefined, "取消");
                    OkBtn.preferredSize =  NoBtn.preferredSize = [80, 24];
            }

            glb_Col.onChange = save2Xml;// 保存颜色
            OkBtn.onClick = function () {
                save2Xml();
                var CreateCnt = CreateText(TxtSize, glb_Txt.text, NumColLst[glb_Col.selection.index].tgt, String(NumXml.Pos));
                if (CreateCnt > 0) {
                    var StartInfo = GetStartN(glb_Txt.text);
                    if (StartInfo !== null) {
                        var OldStartN = StartInfo.value;
                        var NewStartN = OldStartN + CreateCnt;
                        glb_Txt.text = UpdStartN(glb_Txt.text, NewStartN);
                    }
                }
                save2Xml();
                NumWin.close();
            };
            ReSet.onClick = function () {
                var StartInfo = GetStartN(glb_Txt.text);
                if (StartInfo !== null) {
                    glb_Txt.text = UpdStartN(glb_Txt.text, 1);
                }else{
                    glb_Txt.text = "A{N=1}雪弗板字*1套";
                }
                glb_Col.selection = 1;
                Pos_L.value = true;
                save2Xml();
            };
            NoBtn.onClick = function () {
                save2Xml();
                NumWin.close();
            };
            NumWin.onClose = function () {
                $.global.DimNumPalette = null;
                return true;
            };

            // 显示窗口
            NumWin.layout.layout(true);
            NumWin.center();
            NumWin.show();
        };//编号
        function Dim_LineLen(UseUnit, TgtSca, TgtCol, TxtSize) {
            {//基础函数
                function DimSegLen(LArray, div_num) {
                    var Linelen = getBezierLen(LArray, div_num);
                    var MidPT = getBezierMid(LArray)
                    {// 起点X较小+Y较小
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
                    var DimNum = (Math.round(UnitValue(Linelen,"pt").as("mm") * 10) / 10) * TgtSca
                    var dimText = dimLay.textFrames.add();//创建标注文字
                        dimText.contents = DimNum + (UseUnit ? " cm" : "");//pt → 毫米
                        dimText.textRange.characterAttributes.size = TxtSize;
                        if (UseUnit) {
                            var Start = DimNum.toString().length;
                            for (var i = Start; i < dimText.contents.length; i++) {
                                dimText.textRange.characters[i]
                                    .characterAttributes.size = TxtSize * 1.0;

                            }
                        }//单独字号

                        dimText.textRange.characterAttributes.fillColor = UseCol;
                        dimText.textRange.justification = Justification.CENTER;

                        dimText.position = [MidPT[0] - dimText.width / 2, MidPT[1] + dimText.height*1.2];
                        dimText.rotate(LineAng, true, true, true, true, Transformation.BOTTOM);

                        dimText.name = "Dim_Text";//名称 
                };//标注单独一段
                function extractPaths(AllSlt, Limit, pArray) {
                    for (var i = 0; i < AllSlt.length; i += 1) {
                        if (((AllSlt[i].typename == "PathItem") && (!AllSlt[i].guides)) && (!AllSlt[i].clipping)) {
                            if ((Limit) && (AllSlt[i].pathPoints.length <= Limit)) {
                                continue;
                            };// 跳过点数量太少的路径
                            pArray.push(AllSlt[i]);// 普通路径：不是参考线、不是剪切路径
                        }else if (AllSlt[i].typename == "GroupItem") {
                            extractPaths(AllSlt[i].pageItems, Limit, pArray);// 组对象：递归提取
                        }else {
                            if (AllSlt[i].typename == "CompoundPathItem") {
                                extractPaths(AllSlt[i].pathItems, Limit, pArray);
                            };// 复合路径：递归提取
                        }
                    }
                };//递归提取有效路径：排除：参考线、剪切路径、只含Limit个点的无效路径
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
                };//核心：贝塞尔曲线长度计算（数值积分）
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
                };//曲线中点
                function Hex2RGBCol(HexStr){
                    HexStr = HexStr.replace("#","");
                    var r = parseInt(HexStr.substr(0,2),16);
                    var g = parseInt(HexStr.substr(2,2),16);
                    var b = parseInt(HexStr.substr(4,2),16);
                    var c = new RGBColor();
                    c.red = r;
                    c.green = g;
                    c.blue = b;
                    return c;
                };//HEX颜色转RGBCol色
            }
            var CurDoc = app.activeDocument;
            var CurSlt = CurDoc.selection;
            if (CurSlt.length < 1) {alert("未选择对象", "ExTools", true); return;}
            {//创建标注图层
                var UseCol = Hex2RGBCol(TgtCol);
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
                    alert("不含路径对象", "ExTools", true);
                } else {
                    for (var m = 0; m < pArray.length; m += 1) {
                        PTLst = pArray[m].pathPoints;// 获取当前路径的所有锚点列表
                        for (var n = 0; n < PTLst.length; n += 1) {
                            if (n == (PTLst.length - 1)) {//最后一个点
                                if (pArray[m].closed) {k = 0;}else{break};//闭合路径：连回第一个点/开放路径中断
                            }else {k = n + 1};//非最后一个点：连向下一个点

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
                };//路径数量为 0 弹出警告
            } catch (e) {//nothing
            } finally {
                CurDoc.activeLayer = CurLay; // 恢复原先图层
                app.redraw = true;//恢复更新
                app.redraw(); // 最终刷新一次
            }
            //CurDoc.selection = null;//取消选择
        };//标注线长
    }
    {//其它功能
        function Doc_CurPath(){
            var FileArr = [];     // 用于存最终路径数组
            var FileHash = {};    // 哈希表，用于路径去重
            var LostCnt = 0;      // 丢失路径的链接数量
            
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
            }else{
                var CurDoc = app.activeDocument;
                var CurSlt = CurDoc.selection;//选择集
                if (CurSlt.length == 0) {//未选择对象
                    if (!new File(CurDoc.fullName).exists) {
                        alert("请先保存文件!", "ExTools", true);
                    } else {
                        var SavePath = decodeURI(CurDoc.path); // 文件夹路径字符串
                        Folder(SavePath).execute();// 打开路径
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
                        for (var i = 0; i < FileArr.length; i++) { FileArr[i].execute()};//打开所有收集到的文件夹
                    } else {
                        if (LostCnt > 0) {
                        alert("所选链接有些不存在", "ExTools", true);
                        }else{//未选择链接
                            if (new File(CurDoc.fullName).exists) {
                                var SavePath = decodeURI(CurDoc.path); // 文件夹路径字符串
                                Folder(SavePath).execute();// 打开路径
                            }
                        }
                    }
                }
            }
        };//定位文件夹//打开文件/链接所在路径
        function SortArtOrder() {
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
            }else{
                var CurDoc = app.activeDocument;
                var CurArt = CurDoc.artboards;

                var artInfo = [];
                for (var i = 0; i < CurArt.length; i++) {
                    var TmpRec = CurArt[i].artboardRect;
                    var TmpNam = CurArt[i].name;
                    artInfo.push(
                        {
                            left: TmpRec[0],
                            top:  TmpRec[1],
                            rect: TmpRec,
                            name: TmpNam
                        }
                    );
                };// 收集画板：边界坐标+原始索引+名称
                artInfo.sort(
                    function(a, b){
                        // top差值绝对值 ≤10mm → 同一行，按left升序（从左往右）
                        if(Math.abs(a.top - b.top) <= UnitValue(5,"mm").as("pt")){
                            return a.left - b.left;
                        }
                        //不同行：从上到下，top小的排前面（AI坐标系）
                        return b.top - a.top;
                    }
                );

                var recLst = [];
                for (var k = 0; k < artInfo.length; k++) {
                    recLst.push(artInfo[k].rect);
                };// 提取排序后画板尺寸

                // 清空原有画板，按新顺序重建
                while (CurArt.length > 1) CurArt.remove(0);
                    CurArt[0].artboardRect = recLst[0];
                    CurArt[0].name = artInfo[0].name;
                for (var j = 1; j < recLst.length; j++) {
                    var newArt = CurArt.add(recLst[j]);
                        newArt.name = artInfo[j].name;
                }
            }
        };//画板重排序//先上下后左右(5mm高度内视为同一行)
        function ReAllArtbNam() {
            {//基础函数
                function RenameArtboards(mode, customText) {
                    var CurDoc = app.activeDocument;
                    var DocNam = GetfileNam(CurDoc.name);

                    for (var i = 0; i < CurDoc.artboards.length; i++) {
                        var CurArt = CurDoc.artboards[i];
                        var ArtNam = CleanFileNam(CurDoc.artboards[i].name)
                        var ArtNum = ("0" + (i + 1)).slice(-2);
                        var ArtSize = GetArtbSizeMM(CurArt);
                        

                        var NewNam = "";
                        if (mode == "doc") {
                            NewNam = DocNam;
                        } else if (mode == "size") {
                            NewNam = ArtSize;
                        } else if (mode == "docsize") {
                            NewNam = DocNam + "_" + ArtSize;
                        } else if (mode == "custom") {
                            NewNam = customText;
                            NewNam = NewNam.replace(/[*]/g, ArtNam);
                            NewNam = NewNam.replace(/[@]/g, ArtNum);
                            NewNam = NewNam.replace(/[#]/g, DocNam);
                            NewNam = NewNam.replace(/[$]/g, ArtSize);
                        }

                        CurArt.name = CleanFileNam(NewNam);
                    }
                };// 批量修改画板名称
                function GetfileNam(fileName) {
                    var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
                    return dot >= 0 ? fileName.substring(0, dot) : fileName;
                };//文件名(不带扩展)——非正则
                function GetArtbSizeMM(artboard) {
                    var Rec = artboard.artboardRect;//[左, 上, 右, 下]
                    var Wid = UnitValue(Number(Rec[2]) - Number(Rec[0]),"pt").as("mm");//Illustrator 内部单位为 pt
                    var Hgt = UnitValue(Number(Rec[1]) - Number(Rec[3]),"pt").as("mm");//Illustrator 内部单位为 pt

                    Wid = Math.round(Wid * 100) / 100;//保留2位小数
                    Hgt = Math.round(Hgt * 100) / 100;//保留2位小数

                    return Wid + "x" + Hgt;
                    //return Wid + "*" + Hgt + "mm";
                };//获取画板尺寸
                function CleanFileNam(name) {
                    name = String(name);
                    name = name.replace(/^\s+|\s+$/g, "");// 去除首尾空格
                    name = name.replace(/[\r\n]+/g, " ");// 换行替换为空格
                    name = name.replace(/[*]/g, "x");// * 替换为 x
                    //name = name.replace(/[\/:?"<>|]/g, " ");// 特殊字符替换为空格
                    return name;
                };//整理字符串
            }
            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
                return false;
            } else {
                {//定义窗口
                    var ArtWin = new Window("dialog", "画板全改名", undefined, { closeButton: true });
                        ArtWin.alignChildren = "fill";

                    // 模式选择
                    var Grp01 = ArtWin.add("group");
                        Grp01.orientation = "row";
                        Grp01.alignment = "left";

                    var RB_Doc = Grp01.add("radiobutton", undefined, "文件名");
                    var RB_Size = Grp01.add("radiobutton", undefined, "画板尺寸");
                    var RB_DocSize = Grp01.add("radiobutton", undefined, "文件名+画板尺寸");
                        RB_Doc.value = true;

                    // 自定义名称
                    var Grp02 = ArtWin.add("group");
                    var RB_Custom = Grp02.add("radiobutton", undefined,"自定义名:");
                    var input = Grp02.add("edittext", undefined, "画板@_$");
                        input.characters = 20;
                        input.enabled = false;

                    // 自定义说明
                    var Grp03 = ArtWin.add("group");
                    var TT01 = Grp03.add("statictext", undefined, "占位：*原画板名、@序号、#文件名、$画板尺寸");
                        TT01.enabled = false;
                    // 按钮
                    var BtnGrp = ArtWin.add("group");
                        BtnGrp.alignment = "center";
                    var OkBtn = BtnGrp.add("button", undefined, "确定");
                    var NoBtn = BtnGrp.add("button", undefined, "取消");
                        OkBtn.size = NoBtn.size =[80, 25];
                }
                {//定义按钮功能
                    //设置RB模式
                    RB_Doc.onClick = function () {
                        RB_Doc.value = true;
                        RB_Size.value = RB_DocSize.value = RB_Custom.value = false;
                        input.enabled = false;
                    };
                    RB_Size.onClick = function () {
                        RB_Size.value = true;
                        RB_Doc.value = RB_DocSize.value = RB_Custom.value = false;
                        input.enabled = false;
                    };
                    RB_DocSize.onClick = function () {
                        RB_DocSize.value = true;
                        RB_Doc.value = RB_Size.value = RB_Custom.value = false;
                        input.enabled = false;
                    };
                    RB_Custom.onClick = function () {
                        RB_Custom.value = true;
                        RB_Doc.value = RB_Size.value = RB_DocSize.value = false;
                        input.enabled = true;
                        input.active = true;
                    };

                    OkBtn.onClick = function () {
                        //模式
                        var mode = "doc";
                        if (RB_Doc.value) {
                            mode = "doc";
                        } else if (RB_Size.value) {
                            mode = "size";
                        } else if (RB_DocSize.value) {
                            mode = "docsize";
                        } else if (RB_Custom.value) {
                            mode = "custom";
                        }
                        // 自定义模式
                        if (mode == "custom") {
                            if (input.text == "") {
                                alert( "请输入自定义名称!", "ExTools", true);
                                input.active = true;
                                return;
                            }
                        }
                        (RenameArtboards(mode, input.text));//重命名
                        ArtWin.close();
                    };
                    NoBtn.onClick = function () { ArtWin.close();};
                }
                ArtWin.center();
                ArtWin.show();
            }
        };//画板全改名//根据模式修改全部画板名称
        function UnGroup_All() {
            function UnGroupItem(GrpItem) {
                if (GrpItem.clipped) return;//剪切组跳过
                if (GrpItem.hidden)  return;//隐藏就跳过
                for (var i = GrpItem.groupItems.length - 1; i >= 0; i--) {
                    UnGroupItem(GrpItem.groupItems[i]);
                };//先递归处理子组

                var items = [];
                for (var j = GrpItem.pageItems.length - 1; j >= 0; j--) {
                    items.push(GrpItem.pageItems[j]);
                };//保存当前组中的所有元素
                for (var k = items.length - 1; k >= 0; k--) {
                    try {
                        items[k].move(GrpItem, ElementPlacement.PLACEBEFORE);//移到父级前面
                        if (GrpItem.clipped) {
                            if ((items[k].typename === 'PathItem' && !items[k].filled && !items[k].stroked) ||//不存在填充和描边的路径
                                (items[k].typename === 'CompoundPathItem' && !items[k].pathItems[0].filled && !items[k].pathItems[0].stroked) || //不存在填充和描边的复合路径
                                (items[k].typename === 'TextFrame' && items[k].textRange.characterAttributes.fillColor == '[NoColor]' && items[k].textRange.characterAttributes.strokeColor == '[NoColor]') 
                            ){
                                clearArr.push(items[k]);
                            };//收集剪切蒙版的数组(Push empty paths in array)
                        };//收集空对象后面删除
                    } catch (e) {}
                };//把子元素移出组
                try {GrpItem.remove();} catch (e) {};//删除空组
            };//递归解组组对象
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
                            };//先处理子图层
                            for (var j = layer.groupItems.length - 1; j >= 0; j--) {
                                UnGroupItem(layer.groupItems[j]);
                            };//再处理当前图层中的组
                            //恢复状态
                            layer.locked = l;
                        } catch (e) {}
                    }
            };//递归处理图层

            if (app.documents.length == 0) {
                alert("请先打开任一文档!", "ExTools", true);
            }else{
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
                    };// 遍历所有选中项，逐个递归处理
                }

                for (var i = 0; i < clearArr.length; i++) {
                    clearArr[i].remove();
                }
            }

        };//分解可见组//所选组/全部可见组(忽略剪切蒙版)
        function Img_linksExp(){
            function SubFunc (ChgPath, SaveFile, OpenPath, PrefixNam) {
                //辅助函数：生成唯一文件名
                function OnlyFileNam(NamLst, SavePath, fileName) {
                    var dot = fileName.lastIndexOf(".");//精准分离主文件名和后缀
                    var Name = dot >= 0 ? fileName.substring(0, dot) : fileName;
                    var Ext = dot >= 0 ? fileName.substring(dot) : "";

                    var NewName = Name + Ext;
                    var Index = 1;
                    while (NamLst[NewName] || new File(SavePath.fsName + "/" + NewName).exists) {
                        NewName = Name + "_" + Index + Ext;
                        Index++;
                    };//直到文件名不重复
                    NamLst[NewName] = true;//存哈希表
                    return new File(SavePath.fsName + "/" + NewName);
                }

                var CurDoc = app.activeDocument;
                /*
                if (!new File(CurDoc.fullName).exists || !CurDoc.saved) {
                    alert("请先保存文件", "ExTools", true);
                    return;
                }
                */
                var SavePath = new Folder(
                        decodeURI(CurDoc.path.absoluteURI)
                        + "/" +
                        (ChgPath ? 
                            (PrefixNam === "" ? "Links"  : PrefixNam + "-Links")
                            : "Tmp_Links"
                        )
                    );
                if (!SavePath.exists) SavePath.create();//不存在则新建

                var Copyed = {};   // 源路径 -> 新文件对象
                var NamLst = {}; //  已用目标文件名 -> true
                var CopyCnt = 0;   // 复制文件数
                var LinkCnt = 0;   // 更新链接数
                var LostCnt = 0;   // 丢失文件的链接

                for (var i = 0; i < CurDoc.placedItems.length; i++) {
                    var item = CurDoc.placedItems[i];

                    if (item.embedded) continue;       //文件已嵌入
                    try {item.file;} catch (err) {LostCnt++; continue};//伪嵌入：剪贴/拖入图片，无外部源文件
                    if (!new File(item.file.fsName).exists) {LostCnt++ ; continue};//源文件未找到

                    var Key = item.file.fsName;
                    var HasL = new File(SavePath.fsName + "/" + decodeURI(item.file.name));
                    if (!Copyed[Key] && (Key !== HasL.fsName)) {
                        var NewItem = OnlyFileNam(NamLst, SavePath, decodeURI(item.file.name),);
                        try {
                            item.file.copy(NewItem, true); // 复制
                            CopyCnt++;
                        } catch (e) {
                            continue;
                        }
                        Copyed[Key] = NewItem;
                    };// 如果此源文件尚未复制
                    if(ChgPath){
                        try {item.file = Copyed[Key];  LinkCnt++;} catch (e) { };// 更新链接到新复制的文件
                    }
                    CurDoc.selection = null;//取消选择
                }
                
                if (CopyCnt === 0) {
                    alert("没有导出任何链接图", "ExTools", true);
                } else {
                    var CFSTR = "共复制< " + CopyCnt + " >个文件" + String.fromCharCode(10) +
                                (LostCnt == 0 ? "" : "未找到< " + LostCnt + " >个链接");
                    alert(CFSTR);
                    if (SaveFile) { 
                        try {
                            var CurDoc = app.activeDocument;

                            var aiSaveOpts = new IllustratorSaveOptions();
                                aiSaveOpts.compatibility = Compatibility.ILLUSTRATOR24;//保存为2020
                                aiSaveOpts.embedICCProfile = true; // 嵌入ICC配置文件
                                aiSaveOpts.pdfCompatible = false; // 不保存PDF兼容

                            CurDoc.saveAs(CurDoc.fullName, aiSaveOpts);
                        } catch (e) {
                            //alert("保存失败：" + e.message, "ExTools", true);
                        }
                    };//保存文件
                    if (OpenPath) { Folder(SavePath).execute()};//打开路径
                }
            };//链接图打包
            function GetfileNam(fileName) {
                var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
                return dot >= 0 ? fileName.substring(0, dot) : fileName;
            };//文件名(不带扩展)——非正则
            
            var LinkWin = new Window("dialog", '链接图打包');
                LinkWin.alignChildren = "center"; //所有控件水平居中


            var GrpSlt = LinkWin.add('group');
                GrpSlt.orientation = 'column'; //纵向排列
                GrpSlt.alignChildren = "left"; //左对齐

            var Exp01 = GrpSlt.add('radiobutton', undefined, "仅打包图片");
                Exp01.helpTip = "仅复制链接图到新文件夹";
            var Exp02 = GrpSlt.add('radiobutton', undefined, "打包后重链");
                Exp02.helpTip = "复制链接图，并更新路径";
                Exp02.value = true; //默认选中

            var SaveF = GrpSlt.add('checkbox', undefined, "重链后保存当前文件");
                SaveF.helpTip = "保存时嵌入ICC配置，且不兼容PDF";
                SaveF.value = true; // 默认勾选
                SaveF.enabled = Exp02.value; // 仅当Exp02选中时可用
            var OpenP = GrpSlt.add('checkbox', undefined, "打包后打开文件夹");
                OpenP.helpTip = "打包完成后，打开包含链接图的文件夹";
                OpenP.value = true; // 默认勾选

            //填充前缀
            var grpName = LinkWin.add('group');
                grpName.orientation = 'row';
                grpName.spacing = 8;
                grpName.alignChildren = ["left", "center"];

                grpName.add('statictext', undefined, "前缀：");
            var PreNam = grpName.add('edittext', undefined, "");
                PreNam.preferredSize.width = 100;

                var GetNam = grpName.add('button', undefined, "取名");
                    GetNam.helpTip = "提取文档名称作为前缀"
                    GetNam.preferredSize.width = 40;
                    GetNam.preferredSize.height = 20;

                // 按钮点击事件：填充当前文档名称
                PreNam.text = "";// 默认为空
                GetNam.onClick = function () {
                    if (app.documents.length > 0) {
                        PreNam.text = GetfileNam(app.activeDocument.name);
                    } else {
                        PreNam.text = ""; // 没有打开文档清空
                    }
                };

            var GrpBtn = LinkWin.add('group');
                GrpBtn.orientation = "row";//横向排列
                GrpBtn.alignment = "center"; //按钮组整体居中

            var NoBtn = GrpBtn.add("button", undefined, "取消");
            var OkBtn = GrpBtn.add("button", undefined, "确定");

            // 点击事件
            Exp01.onClick = function() { SaveF.enabled = false;}; // 禁用复选框
            Exp02.onClick = function() { SaveF.enabled = true; }; // 启用复选框
            OkBtn.onClick = function () {
                SubFunc(Exp02.value, SaveF.value, OpenP.value, PreNam.text);//执行命令
                LinkWin.close();//关闭窗口
            };
            NoBtn.onClick = function () { LinkWin.close();};
            //LinkWin.defaultElement = OkBtn;// 设置默认按钮（Enter键触发确定）
            LinkWin.onClose = function () { return true};// 窗口关闭事件

            LinkWin.center();
            LinkWin.show();
        };//链接图打包//打包到当前文件路径下
    }
}
function UsePS() {
    displayDialogs = DialogModes.NO;//禁止 Photoshop 显示大多数可由脚本控制的交互式对话框，让脚本尽可能自动执行
    {//导出选区的程序
        function GetfileNam(fileName) {
            var dot = fileName.lastIndexOf("."); // 找最后一个点的位置
            return dot >= 0 ? fileName.substring(0, dot) : fileName;
        };//文件名(不带扩展)——非正则
        function GetUNQNam(NamLst, FileLst) {
            //SavePath, Name, Ext
            var NewNam = FileLst[1] + "." + FileLst[2];
            var Index = 1;
            while (NamLst[NewNam] || new File(FileLst[0].fsName + "//" + NewNam).exists) {
                NewNam = FileLst[1] + "_" + Index + "." + FileLst[2];
                Index++;
            };//直到文件名不重复
            NamLst[NewNam] = true;//存哈希表
            return new File(FileLst[0].fsName + "//" + NewNam);
        }//生成唯一文件名
        function dupLayer() {
            var desc1 = new ActionDescriptor();
            var ref1 = new ActionReference();

            ref1.putClass(charIDToTypeID('Dcmn'));
            desc1.putReference(charIDToTypeID('null'), ref1);

            desc1.putString(
                charIDToTypeID('Nm  '),
                app.activeDocument.activeLayer.name
            );

            var ref2 = new ActionReference();

            ref2.putEnumerated(
                charIDToTypeID('Lyr '),
                charIDToTypeID('Ordn'),
                charIDToTypeID('Trgt')
            );

            desc1.putReference(charIDToTypeID('Usng'), ref2);
            desc1.putInteger(charIDToTypeID('Vrsn'), 5);

            executeAction(
                charIDToTypeID('Mk  '),
                desc1,
                DialogModes.NO
            );

            // 返回新建的目标文档
            return app.activeDocument;
        }//复制活动图层到新文件
        function selectLayerXQ(TgtLay) {
            var s2t = stringIDToTypeID;
            var c2t = charIDToTypeID;

            var desc = new ActionDescriptor();

            // 目标：当前选区
            var refSelection = new ActionReference();
                refSelection.putProperty(c2t("Chnl"), c2t("fsel"));
                desc.putReference(c2t("null"), refSelection);

            // 来源：指定图层的透明度通道
            var refTransparency = new ActionReference();
                refTransparency.putEnumerated(
                    c2t("Chnl"),
                    c2t("Chnl"),
                    c2t("Trsp")
                );
                refTransparency.putIdentifier(c2t("Lyr "), TgtLay.id);

            desc.putReference(c2t("T   "), refTransparency);
            executeAction(c2t("setd"), desc, DialogModes.NO);
        }// 根据指定图层的透明度创建选区
        function Lay2PNGSVG (OriDoc, NoSVG) {
            var TgtDoc = dupLayer();
                TgtDoc.trim(TrimType.TRANSPARENT, true, true, true, true);// 裁剪四周透明像素
            
            var NamLst = {}; //  已用目标文件名 -> true
            if(!NoSVG){
                TgtDoc.selection.selectAll();//复制整个画布的合并可见结果
                TgtDoc.selection.copy(true); // true = 复制合并结果
                TgtDoc.selection.deselect();

                var EffectLayer = TgtDoc.paste();//粘贴为新图层
                selectLayerXQ(EffectLayer);//建立选区
                TgtDoc.selection.makeWorkPath(1);//选区转换为工作路径
                TgtDoc.selection.deselect();//清除选区，保留工作路径

                var SVGfile = GetUNQNam(NamLst, [SavePath, GetfileNam(OriDoc.name), "svg"])
                //切换到使用像素作为单位，无视文件设置
                var oriUnits = app.preferences.rulerUnits;
                app.preferences.rulerUnits = Units.PIXELS;
                writeToFile(SVGfile, formPathCollectionSVG(TgtDoc.pathItems));//转换所有路径并将它们写入文件
                app.preferences.rulerUnits = oriUnits;//完成后，切换回原始文件的单位。
            }//导出SVG
            {
                var PNGfile = GetUNQNam(NamLst, [SavePath, GetfileNam(OriDoc.name), "png"])
                TgtDoc.convertProfile("sRGB IEC61966-2.1", Intent.RELATIVECOLORIMETRIC, true, false);//色彩空间RGB
                var pngSave = new PNGSaveOptions();
                    pngSave.compression = 9;
                    pngSave.interlaced = false;
                TgtDoc.saveAs(PNGfile, pngSave, false, Extension.LOWERCASE);
            }//导出PNG

            TgtDoc.close(SaveOptions.DONOTSAVECHANGES);//关闭文档
            return true
        }//输出文件为SVG路径或其它
    }
    {//导出SVG的基础函数@Pomax
        //https://github.com/Pomax/photoshop-paths-to-SVG/blob/master/pathtosvg.jsx
        Array.prototype.map = function (f) {
            var retArr = [];
            for (var i = 0, e = this.length; i < e; i++) {
                retArr[i] = f(this[i], i);
            }
            return retArr;
        };
        Array.prototype.forEach = function (f) {
            this.map(f);
        };
        Array.from = function (iterable) {
            var retArr = [];
            for (var i = 0, e = iterable.length; i < e; i++) {
                retArr.push(iterable[i]);
            }
            return retArr;
        }
        // Also we'll need some custom objects.
        var Point = function (kind, x, y) {
            this.kind = kind;
            this.x = x;
            this.y = y;
        }
        Point.prototype = {
            toString: function () {
                var base = [this.kind];
                if (this.in) {
                    base = base.concat(['(', this.in.x, this.in.y, ')']);
                }
                base = base.concat([this.x, this.y]);
                if (this.out) {
                    base = base.concat(['(', this.out.x, this.out.y, ')']);
                }
                return base.join(' ');
            }
        }

        var BBox = function () {
            this.mx = 9999999;
            this.my = 9999999;
            this.MX = -9999999;
            this.MY = -9999999;
        };

        BBox.prototype = {
            grow: function (p) {
                if (!p) return;
                if (p.x < this.mx) { this.mx = p.x; }
                if (p.y < this.my) { this.my = p.y; }
                if (p.x > this.MX) { this.MX = p.x; }
                if (p.y > this.MY) { this.MY = p.y; }
                this.grow(p.in);
                this.grow(p.out);
            }
        }
        var pointTypes = {
            'PointKind.CORNERPOINT': 'P',
            'PointKind.SMOOTHPOINT': 'C'
        };


        function improvePoint(point) {
            var kind = pointTypes[point.kind];
            var coord = point.anchor;
            var x = Math.round(coord[0]);
            var y = Math.round(coord[1]);
            var obj = new Point(kind, x, y);

            if (kind === 'C') {
                var d;
                if (point.leftDirection) {
                    d = point.leftDirection.map(Math.round);
                    obj.out = { x: d[0], y: d[1] };
                }
                if (point.rightDirection) {
                    d = point.rightDirection.map(Math.round);
                    obj.in = { x: d[0], y: d[1] };
                }
            }

            return obj;
        }//将 PathPoint 转换为实际对象。
        function handleSubPath(subpath) {
            var pathPoints = Array.from(subpath.pathPoints);
            return pathPoints.map(improvePoint);
        };//将子路径中的所有点转换为更易于解析的形式
        function handlePath(path) {
            var subPaths = Array.from(path.subPathItems);
            return subPaths.map(handleSubPath);
        };//将路径中的所有子路径转换为更易于行走的形式
        function convertPaths(pathItems) {
            var paths = Array.from(pathItems);
            return paths.map(handlePath);
        }//将文档中的所有路径转换成更容易行走的形式。
        function formPathCollectionSVG(pathItems) {
            var pathCollection = convertPaths(pathItems);
            var svg = [];
            var bbox = new BBox();
            pathCollection.forEach(function (path) {
                var d = '';
                path.forEach(function (subpath) {
                    d += formSVGpath(subpath, bbox);
                });
                svg.push('<path fill="black" stroke="black" fill-rule="evenodd" d="' + d + '"/>');
            });
            svg.push('</svg>');
            var w = bbox.MX - bbox.mx;
            var h = bbox.MY - bbox.my;
            var header = '<svg xmlns="http://www.w3.org/2000/svg" width="' + w + '" height="' + w + '" viewBox="' + [bbox.mx, bbox.my, w, h].join(' ') + '">';
            svg = [header].concat(svg);
            return svg.join('\n');;
        }//将改进路径转换为 SVG 字符串
        function formSVGpath(subpath, bbox) {
            var p0 = subpath[0];
            var path = ['M', p0.x, p0.y];
            // we want to close this path:
            subpath.push(p0);
            subpath.forEach(function (p, i) {
                if (i === 0) return;
                bbox.grow(p);

                if (p0.kind === 'P' && p.kind === 'P') {
                    path = path.concat(['L', p.x, p.y]);
                }
                else if (p0.kind === 'P' && p.kind === 'C') {
                    path = path.concat(['C', p0.x, p0.y, p.in.x, p.in.y, p.x, p.y]);
                }
                else if (p0.kind === 'C' && p.kind === 'P') {
                    path = path.concat(['C', p0.out.x, p0.out.y, p.x, p.y, p.x, p.y]);
                }
                else if (p0.kind === 'C' && p.kind === 'C') {
                    path = path.concat(['C', p0.out.x, p0.out.y, p.in.x, p.in.y, p.x, p.y]);
                }
                p0 = p;
            });
            path.push('z');
            return path.join(' ');
        }//将改进点的子路径转化为 SVG 路径
        function writeToFile(SVGfile, data) {
            var mode = 'w';
            SVGfile.open(mode);
            SVGfile.write(data);
            SVGfile.close(mode);
            return SVGfile.toString();
        }//文件写入功能
    }

    if (app.documents.length == 0) {
        //alert("请先打开任一文档!", "ExTools", true);
        var SltFiles = File.openDialog("请选择图片文件", '*.PNG;', true);
        if (SltFiles !== null) {
            var SavePath = new Folder("~/Desktop" + "//PNG&SVG");
            if (!SavePath.exists) SavePath.create();//不存在则新建

            for (var i = 0; i < SltFiles.length; i++) {
                var CurDoc = app.open(SltFiles[i]);
                try {
                    var artbs = CurDoc.layerSets;
                    if (artbs.length <= 0) {
                        Lay2PNGSVG(CurDoc, false);// 导出当前活动图层
                    } else {
                        // 逐个导出图层组
                        for (var n = 0; n < artbs.length; n++) {
                            CurDoc.activeLayer = artbs[n];
                            Lay2PNGSVG(CurDoc, false);
                        }
                    }
                } finally {
                    CurDoc.close(SaveOptions.DONOTSAVECHANGES);
                }
            }
            Folder(SavePath).execute();//打开文件夹 
        }
    } else {
        var CurDoc = app.activeDocument
        var TgtLay = CurDoc.activeLayer;
        
        if (TgtLay.typename == "ArtLayer" && TgtLay.visible == true) {
            var SavePath = new Folder(decodeURI(CurDoc.path.absoluteURI) + "//PNG&SVG");
            if (!SavePath.exists) SavePath.create();//不存在则新建

            if (Lay2PNGSVG(CurDoc, confirm("不提取SVG路径? "))){
                Folder(SavePath).execute();//打开文件夹
            }
        } else {
            alert("非图层或图层未显示!", "ExTools", true);
        }
    }
}

var GetUseApp = BridgeTalk.appName;
switch (GetUseApp) {
    case "illustrator":
        UseAI();
        break;
    case "photoshop":
        UsePS();
        break;
    default:
        alert("当前软件不受支持：" + GetUseApp);
        break;
}