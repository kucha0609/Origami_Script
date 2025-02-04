#target "illustrator"
app.preferences.setBooleanPreference("ShowExternalJSXWarning", false);//不显示脚本警告
//----------------------------------------------------------//
//  OriTools for Adobe Illustrator                          //
//  Writer: Kucha                                           //
//          https://space.bilibili.com/28181671             //
//          www.twitter.com/kucha_Mai                       //
//----------------------------------------------------------//


if (!app.homeScreenVisible) {//当前不在欢迎界面
    app.executeMenuCommand('doc-color-rgb');//;默认转换为RGB色彩空间 
//Global:定义全局变量--------------------------------------------------
    var CurDoc = app.activeDocument;
    var DocLayers = CurDoc.layers; 
    var DocArtbds = CurDoc.artboards; 

    if (CurDoc.spots.length > 1) { CurDoc.spots.removeAll(); }//移除专色色板(高版本)
//Global:定义窗口和按钮功能------------------------------------------
    var ScriptVer = "0.3.0";//插件版本
    var OriWin = new Window("dialog", "OriTools4AI_v" + ScriptVer, undefined);
        OriWin.margins = 5;//边距

    var MainPnl = OriWin.add('panel',undefined,'主功能');
    var SubfPnl = OriWin.add('panel',undefined,'子功能');
    var FilePnl = OriWin.add('panel',undefined,'文件保存');
        FilePnl.margins=SubfPnl.margins=MainPnl.margins=10;//边距
        FilePnl.spacing=SubfPnl.spacing=MainPnl.spacing=3;//间隔

    //定义按钮
    var BTM01 = MainPnl.add('button', undefined, '一键快捷');//Fast_DoFunc
    var BTM02 = MainPnl.add('button', undefined, '00-选峰谷辅点');//Slt_MVALine
    var MNote = MainPnl.add('statictext', undefined, '一键快捷包含子功能01～07');
        MNote.justify = 'Left';
        MNote.enabled = false;

    var BTS01 = SubfPnl.add('button', undefined, '01-图层全打开');//Show_AllLay
    var BTS02 = SubfPnl.add('button', undefined, '02-层按名排序');//Sort_AllLay
    var ArtNote01 = SubfPnl.add('checkbox', undefined, '排序前图层全开');
        ArtNote01.value = false ;//不勾选

    var BTS03 = SubfPnl.add('button', undefined, '03-解除所有组');//Ungroup_All
    var MskNote = SubfPnl.add('checkbox', undefined, '解组时保留剪切蒙版');
        MskNote.value = false;//不勾选
    var BTS04 = SubfPnl.add('button', undefined, '04-透明与线端');//Chg_ObjType

    var BTS11 = SubfPnl.add('button', undefined, '05-矩形转画板');//Rec_2Artbd
    var ArtNote04 = SubfPnl.add('checkbox', undefined, '删除空的画板');
        ArtNote04.value = true;//勾选
    var ArtNote02 = SubfPnl.add('checkbox', undefined, '删除旧的画板');
        ArtNote02.value = true;//勾选
    var ArtNote03 = SubfPnl.add('checkbox', undefined, '关闭层Page+Defps+0');
        ArtNote03.value = true;//勾选

    var BTS12 = SubfPnl.add('button', undefined, '06-文字置顶层');//Text_2Front
    var BTS13 = SubfPnl.add('button', undefined, '07-白色置底层');//White_2Back

    var BTF01 = FilePnl.add('button', undefined, '存为AIPDF');//SaveAS_AiPDF
    var BTF02 = FilePnl.add('button', undefined, '另存为SVG');//saveAs_SVG
    var BTF03 = FilePnl.add('button', undefined, '另存为JPE');//saveAs_JPEG

    //按钮尺寸统一，也可分别设置
    BTM01.size = BTM02.size = [200, 20];
    BTS01.size = BTS02.size = BTS03.size = BTS04.size = [200, 20]
    ArtNote01.size = ArtNote04.size = ArtNote02.size = ArtNote03.size = [200, 20]
    BTS11.size = BTS12.size = BTS13.size = [200, 20]
    MskNote.size = [200, 20]
    BTF01.size = BTF02.size = BTF03.size = [200, 20];

    // 版权信息
    var Copyright = OriWin.add('statictext', undefined, '\u00A9 Kucha 2025');
        Copyright.enabled = false;
    //------------------------------------------------------
    BTM01.onClick = function() {//Fast_DoFunc
        OriWin.close();//关闭窗口 
        var functionArray = [
            Show_AllLay(false),
            Sort_AllLay(false), 
            Ungroup_All(), 
            Chg_ObjType(), 
            Rec_2Artbd(),
            Text_2Front(), 
            White_2Back(), 
            SaveAS_AiPDF(false)
            //alert('\n当前文档已处理完毕')
        ]
        for (var i = 0, l = functionArray.length; i < l; i++) {
            $.sleep(500)
            functionArray();
        }//每执行一个函数暂停500s

        app.redraw();
    } 
    BTM02.onClick = function () {//Slt_MVALine
        OriWin.close();//关闭窗口
        Slt_MVALine(); 
        alert('\n此功能用于手动对齐虚线端头\n请在描边面板,手动调整所选虚线');
    }
    //
    BTS01.onClick = function () {Show_AllLay(true)}
    BTS02.onClick = function () {Sort_AllLay(true)}
    BTS03.onClick = function () {OriWin.close(); Ungroup_All(); alert('\n编组对象都已解组') }
    BTS04.onClick = function () {Chg_ObjType(); alert('\n目标层内对象已调整'); }

    BTS11.onClick = function() {Rec_2Artbd()}
    BTS12.onClick = function() {Text_2Front()}
    BTS13.onClick = function() {White_2Back()}
    //
    BTF01.onClick = function() {SaveAS_AiPDF(true)}
    BTF02.onClick = function() {SaveAs_SVG(true)}
    BTF03.onClick = function() {SaveAs_JPG(true)}
    //-----------------------------------------------------

    OriWin.show();//显示窗口

//Global:定义窗口和按钮功能------------------------------------------


//基础函数
    //避免层名不存在而导致错误
    function GetTgtLay(Lst, Nam) {
        try {
            return Lst.getByName(Nam);
        } catch(err) {
            return null;
        }
    }
    //如果父路径是组/复合路径，则收集所有子路径项
    function get_AllPathItems(parent) {
        var list = [];
        for (var i = 0; i < parent.pageItems.length; i++) {
        var item = parent.pageItems[i];
        if (item.pageItems && item.pageItems.length)
            list = [].concat(list, get_AllPathItems(item));
        else if (/path/i.test(item.typename) && !/compound/i.test(item.typename))
            list.push(item);
        }
        return list;
    }
    //收集所有文本框
    function get_AllTextFrames(parent) {
        var list = [];
        for (var i = 0; i < parent.pageItems.length; i++) {
        var item = parent.pageItems[i];
        if (item.pageItems && item.pageItems.length)
            list = [].concat(list, get_AllTextFrames(item));
        else if (item.typename=="TextFrame")
            list.push(item);
        }
        return list;
    }

//~function_01------------------------------------------------------
    function Slt_MVALine() {//~~Select all lines in the special layer
        CurDoc.selection = null; //取消全选
        var TmpLayLst = ["D-05-Auxiliary", "D-06-Mountain", "D-07-MtnHide", "D-08-Valley", "D-09-VayHide", "D-10-BdrRef"];

        for (var i = 0; i < TmpLayLst.length; i++) {
            var TgtLay = GetTgtLay(DocLayers,TmpLayLst[i]);
            if (!TgtLay) continue;
            else {TgtLay.hasSelectedArtwork = true;}
        }//只选特定图层  
    }
    function Show_AllLay(Flag){//~~Adjust layer order (Alphabetized)  
        for (i = 0; i < DocLayers.length; i++) {
            if (!DocLayers[i].visible){
                DocLayers[i].visible = true;//显示
            }
        }//图层全开
        if (Flag){
            if(!visibleLayers.length == 0){
                alert('\n图层已经全部打开');OriWin.close();
            }
        }//弹出提示?

        app.redraw();
    }  
    function Sort_AllLay(Flag){//~~Adjust layer order (Alphabetized)  
        function sortLayers(abcLayers) {	
            for (var ri=0; ri<abcLayers.length;ri++) {
                abcLayers[ri].zOrder(ZOrderMethod.SENDTOBACK);
            };
        } 

        var visibleLayers = [];  
        for (i = 0; i < DocLayers.length; i++) {
            if(ArtNote01.value){
                DocLayers[i].visible = true;//显示图层
            }//图层全开
            if(DocLayers[i].visible){visibleLayers.push(DocLayers[i]);}//图层可见则收集
        }
        if(!visibleLayers.length == 0){
            sortLayers(visibleLayers.sort(function (a, b) { return a > b }));//层按名排序
        }//可见图层存在
        if (Flag){
            if(!visibleLayers.length == 0){
                alert('\n可见层顺序已按名称调整');OriWin.close();
            }else{alert('\n不存在可见层!!');}
        }//弹出提示

        app.redraw();
    }  
    function Ungroup_All() {//~~Ungroup_All in layer
        //https://github.com/rjduran/adobe-scripting
        //收集所有子项
        function get_AllChild(parent) {
            var allChilds = [];
            if (Object.prototype.toString.call(parent) === '[object Array]') {
                allChilds.push.apply(allChilds, parent);
            } else {
                for (var i = 0; i < parent.pageItems.length; i++) {
                    allChilds.push(parent.pageItems[i]);
                }
            }

            if (parent.layers) {
                for (var l = 0; l < parent.layers.length; l++) {
                    childsArr.push(parent.layers[l]);
                }
            }

            return allChilds;
        }
        //解组函数(含嵌套组)
        function ungroup(obj) {//解组
            if (MskNote.value && obj.clipped) {
                return;
            }
            //
            var childArr = get_AllChild(obj);
            if (childArr.length < 1) {
                obj.remove();
                return;
            }
            for (var i = 0; i < childArr.length; i++) {
                var item = childArr[i];
                try {
                    if (item.parent.typename !== 'Layer') {
                        item.move(obj, ElementPlacement.PLACEBEFORE);//移动对象到前面
                        // Push empty paths in array 
                        if ((item.typename === 'PathItem' && !item.filled && !item.stroked) ||
                            (item.typename === 'CompoundPathItem' && !item.pathItems[0].filled && !item.pathItems[0].stroked) ||
                            (item.typename === 'TextFrame' && item.textRange.fillColor == '[NoColor]' && item.textRange.strokeColor == '[NoColor]'))
                            clearArr.push(item);
                    }
                    //
                    if (item.typename === 'GroupItem' || item.typename === 'Layer') {
                        ungroup(item);
                    }
                    //
                } catch (err) { }
            }
        }

        var clearArr = []; 
        for (var i = 0; i < DocLayers.length; i++) {
            
            //记录图层状态
            var LayStatus_Visible = DocLayers[i].visible;
            DocLayers[i].visible = true;//显示图层
            var LayStatus_Locked = DocLayers[i].locked;
            DocLayers[i].locked = false;//解锁图层
            

            // 层内对象解组(All)
            if (DocLayers[i].groupItems.length > 0) {
                ungroup(DocLayers[i]);
            }

            
            //恢复图层状态
            DocLayers[i].visible = LayStatus_Visible;
            DocLayers[i].locked = LayStatus_Locked;
            
        }

        //解组后是否保留剪切蒙版
        if (!MskNote.value) {
            for (var i = 0; i < clearArr.length; i++) {
                clearArr[i].remove();
            }
        }
    } 
    function Chg_ObjType() {//~~Change the color in layer (FillColor and StrokeColor)
        //修改对象特性
        function ChgAll_ObjType(layLst, newColor, chgFill, chgStroke, chgFormat, ColOpacity, Stkpacity) {
            for (var i = 0; i < layLst.length; i++) {
                CurDoc.selection = null; //取消全选
                var TgtLay = GetTgtLay(DocLayers,layLst[i]);
    
                if (!TgtLay) continue;
                else {
                    
                    //记录图层状态
                    var LayStatus_visible = TgtLay.visible;//Recording TgtLay status
                    TgtLay.visible = true;//显示图层
                    
                    var AllPathLst = get_AllPathItems(TgtLay);
                    for (var n = 0; n < AllPathLst.length; n++) {
                        var Pitem = AllPathLst[n];
                        if (chgFill && Pitem.filled) {// Change fillColor
                            if (newColor) { Pitem.fillColor = newColor; }
                            if (ColOpacity) { Pitem.opacity = ColOpacity; }
                        }
                        if (chgStroke && Pitem.stroked) {// Change strokeColor
                            if (newColor) { Pitem.strokeColor = newColor; }
                            if (Stkpacity) { Pitem.opacity = Stkpacity; }
                        }
                        if (chgFormat && Pitem.stroked) {// Change Pitem strokeFormat when it exists
                            Pitem.strokeCap = StrokeCap.BUTTENDCAP; //ROUNDENDCAP, PROJECTINGENDCAP
                            Pitem.strokeJoin = StrokeJoin.ROUNDENDJOIN; //BEVELENDJOIN, MITERENDJOIN
                            Pitem.strokeDashOffset = 0
                            
                        }
                    }
                    var AllTextLst = get_AllTextFrames(TgtLay);
                    for (var n = 0; n < AllTextLst.length; n++) {
                        var Titem = AllTextLst[n].textRange.characterAttributes;
                        if (chgFill && Titem.fillColor.typename != "NoColor") {// Change fillColor
                            if (newColor) {Titem.fillColor = newColor;}
                            //if (ColOpacity != false) { AllTextLst[n].opacity = ColOpacity; }
                        }
                        if (chgStroke && Titem.strokeColor.typename != "NoColor") {// Change strokeColor
                            if (newColor) { Titem.strokeColor = newColor;}
                            //if (Stkpacity) { AllTextLst[n].opacity = Stkpacity; }
                        }
                    }
                    
                    //恢复图层状态
                    TgtLay.visible = LayStatus_visible;//Restore TgtLay state
                    
                }
            }
        }
    
        //线型+透明度
        ChgAll_ObjType(["D-04-SymRef", "D-05-Auxiliary", "D-06-Mountain", "D-07-MtnHide", "D-08-Valley", "D-09-VayHide"], false, true, true, true, 100, 100);//线型
    
        //仅透明度
        ChgAll_ObjType(["D-01-Layout"], false, true, true, true, 20, 100);
        ChgAll_ObjType(["D-13-FaceOth"], false, true, true, false, 50, 100);
        ChgAll_ObjType(["D-02-TextStep","D-03-SymStd", "D-10-BdrRef", "D-11-Border", "D-12-Exist", "D-14-FaceDark", "D-15-FaceLight"], false, true, true, false, 100, 100);
    
        app.redraw();
    }
    function Rec_2Artbd() {//~~Create Artboard from multiple objects
        function Remove_EmptyArtboards() {
            //https://community.adobe.com/t5/illustrator-discussions/is-it-possible-to-remove-all-the-empty-artboards-using-script/td-p/8850778
            CurDoc.selection = null;
            for (var i = CurDoc.artboards.length - 1; i >= 0; i--) {
                if (CurDoc.artboards.length > 1) {
                    CurDoc.artboards.setActiveArtboardIndex(i);
                    selectedObjects = CurDoc.selectObjectsOnActiveArtboard();
        
                    if (CurDoc.selection.length < 1 || CurDoc.selection == null) {
                        CurDoc.artboards[i].remove();
                    }
                }
            }
        };
        function CollectRec4Lay(TgtLay) {// 收集图层中所有矩形对象
            function isRectangle(item) {//判断对象是否为矩形
                if (item.typename === 'PathItem' && item.closed && item.pathPoints.length === 4) {
                    var pathPoints = item.pathPoints;
                    var p01 = pathPoints[0].anchor;
                    var p02 = pathPoints[1].anchor;
                    var p03 = pathPoints[2].anchor;
            
                    var Dis01 = Math.sqrt(Math.pow(p02[0] - p01[0], 2) + Math.pow(p02[1] - p01[1], 2));
                    var Dis02 = Math.sqrt(Math.pow(p03[0] - p02[0], 2) + Math.pow(p03[1] - p02[1], 2));
                    return Math.abs(Math.abs(Dis01 * Dis02) - Math.abs(item.area)) < 1e-6;
                }
                return false;
            }
            var RecLst = [];
            for (var i = 0; i < TgtLay.pageItems.length; i++) {
                var item = TgtLay.pageItems[i];
                if (isRectangle(item)) { RecLst.push(item);}
            }
            if (RecLst) {
                return RecLst;
            } else {
                return null;
            }
        };
        function CompareRecBounds(Rec01, Rec02) {//比较矩形对象的几何边界：先上下后左右
            //[左上角XY和右下角XY]
            var Rec01Bounds = Rec01.geometricBounds;
            var Rec02Bounds = Rec02.geometricBounds;
            //按先上下后左右的顺序重新排列对象的顺序
            if (Math.abs(Rec01Bounds[1] - Rec02Bounds[1]) <= 100) {//左上角Y的之差小于100约等于30mm
                return Rec01Bounds[0] - Rec02Bounds[0];//比较X，小的先出
            } else {
                return Rec02Bounds[1] - Rec01Bounds[1];//比较Y，大的先出
            }
        };

        var TgtLay = GetTgtLay(DocLayers,'D-16-Page')
            TgtLay.visible = true;//显示图层

        var OldArtbdNams = [];
        for (var i = 0; i < DocArtbds.length; i++) {
          OldArtbdNams.push(DocArtbds[i].name);
        }//收集旧画板名称

        var RecLst4Lay = CollectRec4Lay(TgtLay);//收集图层中的矩形
        if (TgtLay && RecLst4Lay[0]) {
            RecLst4Lay.sort(CompareRecBounds);//排序
            //逐个选择矩形对象并新增画板
            for (var i = 0; i < RecLst4Lay.length; i++) {
                DocArtbds.add(RecLst4Lay[i].geometricBounds);
            };//根据所选矩形新建画板
            if (ArtNote02.value) {
                for (var i = DocArtbds.length - 1; i >= 0; i--) {
                    var CurArtbdNam = DocArtbds[i].name;
                    for (var j = 0; j < OldArtbdNams.length; j++) {
                        if (CurArtbdNam === OldArtbdNams[j]) {
                            DocArtbds[i].remove();
                        }
                    }
                }//删除旧画板
            }//根据画板名称，删除原先收集的旧画板
            if(ArtNote03.value){
                TgtLay.visible = false;//关闭图层
                var TgtLay2 = GetTgtLay(DocLayers,'0')
                if (TgtLay2){TgtLay2.visible = false;}//关闭0图层
                var TgtLay3 = GetTgtLay(DocLayers,'Defpoints')
                if (TgtLay3){TgtLay3.visible = false;}//关闭Defpoints图层
            }//关闭图层
            if (ArtNote04.value) {
                Remove_EmptyArtboards()//移除空画板
            }//根据画板名称，删除原先收集的旧画板
        } else {
            alert('\n图层<D-16-Page>不存在\n或不含矩形或矩形已编组');
        };

        app.redraw();
    }
    function Text_2Front() {//~~send Text to front
        CurDoc.selection = null; //取消全选

        app.executeMenuCommand("Text Objects menu item");
        app.executeMenuCommand("sendToFront");

        CurDoc.selection = null; //取消全选
        app.redraw();
    }
    function White_2Back() {//~~send white fill to the back
        CurDoc.selection = null; //取消全选

        var FindCol = new RGBColor();
            FindCol.red = FindCol.green = FindCol.blue = 255;//纯白色

        CurDoc.defaultFillColor = FindCol;//当前色
        CurDoc.defaultStrokeColor = new NoColor();//描边颜色为空

        app.executeMenuCommand("Find Fill & Stroke menu item");
        app.executeMenuCommand("sendToBack");

        CurDoc.selection = null; //取消全选
        app.redraw();
    }
    
//~function_02------------------------------------------------------
    function SaveAS_AiPDF(Flag){
        //获取脚本路径
            //var scriptFile = new File($.fileName);
            //var SavePath = scriptFile.parent.fsName + "\\--Export--\\--JPEG--";
            var SavePath = "~/Desktop/--Export--/"
            if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建
            
            var saveOpts = new PDFSaveOptions();
            saveOpts.preserveEditability = true;
            CurDoc.saveAs(new File(SavePath), saveOpts);

            CurDoc.saveAs(new File(SavePath), new IllustratorSaveOptions());//另存为AI
            app.redraw();
        if (Flag){alert('\n文件导出完成，请查看桌面文件夹!');}
        
    }
    function SaveAs_SVG(Flag) {
        var SavePath = "~/Desktop/--Export--/--SVG--/"
        if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建

        for(var i = 0; i < DocArtbds.length; i++) {
            DocArtbds.setActiveArtboardIndex(i);//设置活动画板
                var SetExp = new ExportOptionsSVG();
                SetExp.saveMultipleArtboards = true;
                SetExp.artboardRange = (i + 1).toString();
                
                SetExp.embedRasterImages = true;
                SetExp.cssProperties = SVGCSSPropertyLocation.STYLEATTRIBUTES;
                SetExp.fontSubsetting = SVGFontSubsetting.None;
                SetExp.documentEncoding = SVGDocumentEncoding.UTF8;
            
            CurDoc.exportFile(new File(SavePath), ExportType.SVG, SetExp);
        }
        app.redraw();
        
        if (Flag){alert('\n文件导出完成，请查看桌面文件夹!'); var Flag = false}
    }
    function SaveAs_JPG(Flag) {
        var SavePath = "~/Desktop/--Export--/-JPEG--/"
        if (!Folder(SavePath).exists){Folder(SavePath).create() }//如果文件夹不存在则新建

        for(var i = 0; i < DocArtbds.length; i++) {// 循环遍历文档中的所有画板
            DocArtbds.setActiveArtboardIndex(i);//设置活动画板
            var SetExp = new ExportOptionsJPEG();// 创建一个导出设置为JPEG格式的对象
                //SetExp.saveMultipleArtboards = true;
                //SetExp.artboardRange = (i+1).toString();

                SetExp.antiAliasing = true;
                SetExp.artBoardClipping = true //剪切到画板
                SetExp.optimization = true  // 优化以便于在web上查看
                SetExp.qualitySetting = 100;
                SetExp.horizontalScale = SetExp.verticalScale = 400;
            
            var DocNam = CurDoc.name.split('.')[0]// 获取当前文档的名称并去掉后缀
            var jpgName = new File(SavePath + "/" + String(DocNam) + "-" + (i+1).toString());// 创建一个包含保存路径和文件名的File对象
            CurDoc.exportFile(jpgName, ExportType.JPEG, SetExp); 
        }
        app.redraw();

        if (Flag){alert('\n文件导出完成，请查看桌面文件夹!'); var Flag = false}
    }
    
} else {
    alert('\n请先打开任一文档！');//Plz open a CurDoc first.
}
