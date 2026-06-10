/**
 * name: 重排步骤_v7
 * description: 【Kucha开发】仅可在标准A4纸中重排步骤
 * version: 1.7
 * author: Kucha
*/

/*[使用说明]
    1-该功能仅支持在标准A4纸中, 重新排列步骤(210*297mmH)
    2-排序范围：[左上角, 右下角] = [(15mm, 6mm),(210mm, 270mm)]
    3-相邻对象四周的空隙均大于2mm, 视为不同步骤。否则视相同步骤
    4-步骤从指定画板开始排序, 直到排满最后的画板后：
        从最后的画板右侧持续偏移210mm继续排剩余步骤
    5-参数自动保存至桌面 Reorder_state.json
*/

const { app }      = require("/application");
const { Document } = require("/document");
const { Selection } = require("/selections");
const { Transform } = require("/geometry");
const { UnitType }  = require("/units");
const { Dialog, DialogResult } = require("/dialog");
const { DocumentCommand, CompoundCommandBuilder, NodeMoveType, AddChildNodesCommandBuilder, NodeChildType } = require("/commands");
const { File, FileSystemApi } = require("/fs");
const { StoryBuilder }       = require('/storybuilder');
const { StoryDelta }         = require('/storydelta');
const { GlyphAttDoubleType } = require('/glyphatts');
const { ParagraphAlignXType } = require('/paragraphatts');
const { ArtTextNodeDefinition } = require('/nodes');


function px2mm(px) { return px * 25.4 / Document.current.dpi; }
function mm2px(mm) { return mm * Document.current.dpi / 25.4; }
function px2pt(px) { return px * 72 / Document.current.dpi; }
function pt2px(pt) { return pt * Document.current.dpi / 72; }
function GetNoArtboard(CurDoc){
    function isArtboard(node) {
        try {
            return node.artboardInterface.isArtboardEnabled === true;
        } catch(e) {
            return false;
        }
    };//判断是否为画板

    var SltAry = CurDoc.selection.nodes.toArray(); //选中的对象
    var CurSlt = [];
    for (var i = 0; i < SltAry.length; i++) {
        if (!isArtboard(SltAry[i])) {CurSlt.push(SltAry[i]);}
    }
    return CurSlt
};//从选择级集中排除收集非画板对象
function GetGridLst(MdeSlt, Area, xNum, yNum) {
    var llpt = [15.0, 270.0];//区域的左下角坐标
    var xDis = Area[0] / xNum;
    var yDis = Area[1] / yNum;
    var gridLst = [];

    if (MdeSlt == 0) {
        for (var y = yNum - 1; y >= 0; y--) {       // 从上到下
            var Ny = llpt[1] - y * yDis
            for (var x = 0; x < xNum; x++) {        // 从左到右
                var Nx = llpt[0] + x * xDis;
                gridLst.push([mm2px(Nx), mm2px(Ny)]);
            }
        }
    } else {
        for (var y = 0; y < yNum; y++) {       // 从上到下
            var Ny = (297 - llpt[1]) + y * yDis
            for (var x = 0; x < xNum; x++) {        // 从左到右
                var Nx = llpt[0] + x * xDis;
                gridLst.push([mm2px(Nx), mm2px(Ny)]);
            }
        }
    }
    return gridLst;
}//网格坐标列表(Y向下, px单位)：左下角点+区域范围+列数+行数//网格坐标列表(Y向下, px单位)
function RtnBox4Group(MdeSlt, items, xTol, yTol) {
    function IsRectTouch(rectA, rectB, xTol, yTol) {
        return !(
            rectA[2] < rectB[0] - xTol ||  // A右 < B左 - xTol → A在B左侧
            rectB[2] < rectA[0] - xTol ||  // B右 < A左 - xTol → B在A左侧
            rectA[3] < rectB[1] - yTol ||  // A底 < B顶 - yTol → A在B上方
            rectB[3] < rectA[1] - yTol     // B底 < A顶 - yTol → B在A上方
        );
    }
    function MergeRect(rectA, rectB) {
        return [
            Math.min(rectA[0], rectB[0]),
            Math.min(rectA[1], rectB[1]),
            Math.max(rectA[2], rectB[2]),
            Math.max(rectA[3], rectB[3])
        ];
    }
    function GetBounds(hasTxt, MdeSlt, item) {
        var Tmp = item.getSpreadBaseBox(false);
        var Top = Tmp.y;
        var Bot = Tmp.y + Tmp.height;
        if (item.isTextNode && hasTxt) {
            if (MdeSlt == 0) {//底
                var Top = Top - mm2px(6);
            } else {
                var Bot = Bot + mm2px(6);
            }
        }//文字则更新
        return [Tmp.x, Top, Tmp.x + Tmp.width, Bot];
    }

    var rects = items.map(item => GetBounds(true, MdeSlt, item));
    var visited = new Array(items.length).fill(false);
    var result = [];

    for (var i = 0; i < items.length; i++) {
        if (visited[i]) continue;

        visited[i] = true;
        var stack = [i];
        var groupItems = [];
        var groupBounds = rects[i].slice();

        while (stack.length > 0) {
            var cur = stack.pop();
            groupItems.push(items[cur]);
            groupBounds = MergeRect(groupBounds, rects[cur]);
            for (var j = 0; j < items.length; j++) {
                if (visited[j]) continue;
                if (IsRectTouch(groupBounds, rects[j], xTol, yTol)) {
                    visited[j] = true;
                    groupBounds = MergeRect(groupBounds, rects[j]);
                    stack.push(j);
                }
            }
        }

        result.push([groupBounds, groupItems]);
    }

    return result;
}//对象分堆成组(文字特殊处理)
function FixGrpBox(MdeSlt, OldArr) {
    function GetNoTextBox (nodes){
        try {
            var noText = nodes.filter(function (item) { return !item.isTextNode; });// 过滤掉文字对象，只保留非文字对象
            if (noText.length > 0) {
                var first = noText[0].getSpreadBaseBox(false);
                var FBox = {
                    x: first.x,
                    y: first.y,
                    right: first.x + first.width,
                    bottom: first.y + first.height
                };//第一个
                for (var i = 1; i < noText.length; i++) {
                    var Tmp = noText[i].getSpreadBaseBox(false);
                    if (Tmp.x < FBox.x) FBox.x = Tmp.x;
                    if (Tmp.y < FBox.y) FBox.y = Tmp.y;
                    if (Tmp.x + Tmp.width > FBox.right) FBox.right = Tmp.x + Tmp.width;
                    if (Tmp.y + Tmp.height > FBox.bottom) FBox.bottom = Tmp.y + Tmp.height;
                }//从第二个开始
                return [FBox.x, FBox.y, FBox.right, FBox.bottom];
            } else {
                return false;
            }
        } catch (e) {
            return false;
        }
    }//返回非文字对象的边界框(如果存在)
    try {
        var NewArr = [];
        for (var i = 0; i < OldArr.length; i++) {
            var Box = OldArr[i][0];
            var nodes = OldArr[i][1];

            var NTB = GetNoTextBox(nodes);
            if (NTB === false) {//全是文字
                var Top = Box[3];
                var Bot = Box[3];

                if (MdeSlt == 0) {//底
                    var Bot = Bot - mm2px(6);
                } else {
                    var Top = Top - mm2px(4);
                }
                var NTB = [Box[0], Top, Box[2], Bot]
            };//更新坐标
            NewArr.push([NTB, nodes]);
        }
        return NewArr;
    } catch (e) { return OldArr; }
}//针对文字的二次分堆
function ArtboardLst(CurDoc) {
    var raw = [];
    //var CurDoc = Document.current;
    for (var layer of CurDoc.layers) {
        try {
            if (layer.artboardInterface && layer.artboardInterface.isArtboardEnabled) {
                raw.push({ ab: layer.artboardInterface, node: layer });
            }
        } catch(e) {
            return [];
        }
    }
    return raw.reverse();
}//返回画板列表和nodes



var ScriptNam = "Reorder";
var StateFolder = app.userDesktopPath + "\\OriKucha";// 文件夹路径
if (!FileSystemApi.exists(StateFolder)) { FileSystemApi.createDirectory(StateFolder); }// 如果文件夹不存在，则创建
var PanelState = StateFolder + "\\" + ScriptNam + "_state.json";// 面板状态文件

function loadState(defaults) {
    try {
        if (FileSystemApi.exists(PanelState)) {//判断文件存在
            var buf  = File.readAll(PanelState);// 读取整个文件内容（返回二进制缓冲区）
            var text = buf.toString("utf8");// 将缓冲区转换为 UTF-8 编码的字符串
            var parsed = JSON.parse(text);
            var defaultKeys = Object.keys(defaults);
            // 检查 parsed 是否包含所有 defaults 的 key
            var isValid = defaultKeys.every(function(k) {
                return Object.prototype.hasOwnProperty.call(parsed, k);
            });
            if (!isValid) return Object.assign({}, defaults);
            return Object.assign({}, defaults, parsed);
        }
    } catch(e) {}
    return Object.assign({}, defaults);
};//加载面板状态对象(失败使用默认值)
function saveState(state) {
    try {
        var file = new File(PanelState, "wb");// 创建文件对象："wb" 表示写入二进制模式(覆盖写入)
            file.writeString(JSON.stringify(state, null, 2));//对象转成JSON字符串并写入文件(格式化缩进为 2 空格)
            file.close();// 关闭文件, 确保数据写入完成
    } catch(e) {}
};//保存面板状态对象

function SortFun(MdeSlt, CurIdx, X, Y, G, N) {
    function findArtboardAncestor(node) {
        var current = node.parent;
        while (current && current.constructor.name !== 'SpreadNode') {
            try {
                if (current.artboardInterface.isArtboardEnabled) return current;
            } catch(e) {}
            current = current.parent;
        }
        return false;
    }// 目标点在画板外，向上递归查找对象所在画板的父级
    var CurDoc = Document.current;
    var CurSlt = GetNoArtboard(CurDoc);
    var ArtLst = ArtboardLst(CurDoc);
    var MaxIdx  = ArtLst.length - 1;

    if (CurSlt.length === 0) {
        //app.alert("请先选择要排版的对象", "提示");
        return N;
    }
    var key = (MdeSlt == 0) ? 3 : 1 //底边bottom/顶边Top
    var sortArr = RtnBox4Group(MdeSlt, CurSlt, mm2px(2), mm2px(2));//分堆合并
        sortArr = FixGrpBox(MdeSlt, sortArr);//修复文字问题
        sortArr.sort(function(a, b) {
            var dy = a[0][key] - b[0][key];
            return Math.abs(dy) <= mm2px(G) ? a[0][0]-b[0][0] : dy;
        });//先上下后左右排序(Y向下)

    var GridLst = GetGridLst(MdeSlt, [195, 260], X, Y);
    var StaNum = parseFloat(N); // 起始序号

    try {
        var builder = CompoundCommandBuilder.create();
        for (var i = 0; i < sortArr.length; i++) {
            var Box   = sortArr[i][0];
            var nodes = sortArr[i][1];

            var PagNum   = Math.floor((StaNum-1) / GridLst.length);// 原始页码（绝对不能修改）
            var CurNth = (StaNum-1) % GridLst.length;// 当前页中的位置
            var TgtIdx = CurIdx + PagNum;// 实际画板索引
            
            var OverPg = 0;
            if (TgtIdx > MaxIdx) {
                OverPg = TgtIdx - MaxIdx;
                TgtIdx = MaxIdx; 
            }//超出最后画板后的偏移页数

            var ArtBox = ArtLst[TgtIdx].ab.spreadBaseBox;
            var abNode = ArtLst[TgtIdx].node;//目标画板
            var GridPt  = GridLst[CurNth];//网格点坐标

            var dx = ArtBox.x + GridPt[0] + OverPg * mm2px(210) - Box[0];//目标-起始
            var dy = ArtBox.y + GridPt[1] - Box[key];//满足底或顶

            builder.addCommand(
                DocumentCommand.createTransform(
                    Selection.create(CurDoc, nodes),
                    Transform.createTranslate(dx, dy)
                )
            );//移动对象位置
            if (OverPg == 0) {//移动对象到目标画板内
                builder.addCommand(
                    DocumentCommand.createMoveNodes(
                        Selection.create(CurDoc, nodes),
                        abNode,
                        NodeMoveType.Inside,
                        NodeChildType.Main
                    )
                );
            } else {
                for (var j = 0; j < nodes.length; j++) {
                    var ancestor = findArtboardAncestor(nodes[j]);
                    if (ancestor) {
                        builder.addCommand(
                            DocumentCommand.createMoveNodes(
                                Selection.create(CurDoc, nodes[j]),
                                ancestor,
                                NodeMoveType.After,
                                NodeChildType.Main
                            )
                        );
                    }
                }// nodes 是数组，需逐个处理每个节点
            }

            StaNum++;
        }
        CurDoc.executeCommand(builder.createCommand());
    } catch(e) {}
    
    return StaNum;
}//排序函数
function TextFun(MdeSlt, CurIdx, X, Y, T, N) {
    var CurDoc  = Document.current;
    var ArtLst  = ArtboardLst(CurDoc);

    var GridLst = GetGridLst(MdeSlt, [195, 260], X, Y);
    var StaNum  = parseFloat(N);
    var ArtBox  = ArtLst[CurIdx].ab.spreadBaseBox;
    var abNode  = ArtLst[CurIdx].node;

    // 所有节点加入同一个 builder + setInsertionTarget，一次执行一次撤销
    var acnBuilder = AddChildNodesCommandBuilder.create();
    acnBuilder.setInsertionTarget(abNode);

    var defs = []; // 先收集所有节点定义
    for (var i = 0; i < X * Y; i++) {
        var GridPt = GridLst[i];
        var dx = ArtBox.x + GridPt[0];
        var dt = MdeSlt == 0 ? mm2px(6) : -mm2px(4)//下6mm,上4mm
        var dy = ArtBox.y + GridPt[1] + dt;

        var sb = StoryBuilder.create();
            sb.setToArtisticTextDefaultStyle(CurDoc.dpi, CurDoc.rasterFormat);
            sb.applyGlyphDelta(
                StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, pt2px(T))
            );// 字号（px，等同于 pt 在对应 dpi 下）
            sb.applyParagraphDelta(
                StoryDelta.createAlignX(ParagraphAlignXType.Left)
            );// 对齐方式：Left / Centre / Right / JustifyLeft / JustifyCentre / JustifyRight / JustifyAll
            sb.addText((StaNum <= 9 ? "0" : "") + StaNum + ".");//文字内容
            defs.push(
                ArtTextNodeDefinition.createFromStoryBuilder(
                    { x: dx, y: dy },
                    sb
                )// 创建节点（x/y 为左上角坐标，单位 px）
            );

        StaNum++;
    }
    
    for (var i = defs.length - 1; i >= 0; i--) {
        acnBuilder.addNode(defs[i]);
    }// 倒序添加到builder(这样图层堆叠顺序就反过来符合视觉)

    CurDoc.executeCommand(acnBuilder.createCommand(false, NodeChildType.Main));
    return StaNum;
}//在指定画板生成递增序号
function MainFun() {
    var CurDoc  = Document.current;
    var ArtLst  = ArtboardLst(CurDoc);////总的画板列表
    var defaults = {
        M: 0, 
        G: 30, 
        Y: 4, 
        X: 3, 
        N: 1, 
        NE: true, 
        R: false, 
        A: 0, 
        T: 10
    };

    if (ArtLst.length === 0) {
        app.alert("无画板文档：请先创建或转换！", "提示");
    }else{
        while (true) {
            var state   = loadState(defaults);
            var MaxIdx  = ArtLst.length - 1;
            var abItems = ArtLst.map(function(item, i) { return "[" + i + "] " + item.ab.description; });//画板表

            var win = Dialog.create("重排步骤/" + ScriptNam);
                win.initialWidth = 250;//默认宽度
                win.isResizable = true;//可调整大小

            var winCol = win.addColumn();
            var Grp01 = winCol.addGroup("参数/Setting");
            var MdeSlt = Grp01.addButtonSet('', ['底部/Bottom', '顶部/Top'], state.M);
                MdeSlt.isFullWidth = true;//布满面板
                MdeSlt.onValueChangedHandler = function () {
                    if(MdeSlt.selectedIndex == 0){
                        app.alert("排序和序号均在：底部bottom", "Mode→ OriTools");
                    }else{
                        app.alert("排序和序号均在：顶部Top", "Mode→ Affinity");
                    }
                };//切换选项时

            var G_Input = Grp01.addUnitValueEditor("分行/Row_Limit", UnitType.Millimetre, UnitType.Millimetre, state.G, 10, 50);
                G_Input.precision = 0; G_Input.showPopupSlider = true;
                G_Input.setDescription("Y方向的差值小于设定值为同一行(受上方影响)");
            var Y_Input = Grp01.addUnitValueEditor("行数/Y_Number", UnitType.Number, UnitType.Number, state.Y, 1, 10);
                Y_Input.precision = 0; Y_Input.showPopupSlider = true;
                Y_Input.setDescription("Y方向的划分数量");
            var X_Input = Grp01.addUnitValueEditor("列数/X_Number", UnitType.Number, UnitType.Number, state.X, 1, 10);
                X_Input.precision = 0; X_Input.showPopupSlider = true;
                X_Input.setDescription("X方向的划分数量");
            var N_Input = Grp01.addUnitValueEditor("起始/Start_Num", UnitType.Number, UnitType.Number, state.N, 1, 999);
                N_Input.precision = 0; N_Input.showPopupSlider = true;
                N_Input.setDescription("步骤起始序号(相对于起始画板)");
            var ResetChk  = Grp01.addCheckBox("起始重置/Reset 1", state.R);
                ResetChk.isFullWidth = true; N_Input.isEnabled = state.NE
                ResetChk.setDescription("立即将起始序号重置为 1 并锁定");
                ResetChk.onValueChangedHandler = function() {
                    if (ResetChk.value === true) {
                        N_Input.value     = 1;
                        N_Input.isEnabled = false;
                        saveState({
                            M: MdeSlt.selectedIndex,
                            G: G_Input.value,
                            Y: Y_Input.value,
                            X: X_Input.value,
                            N: N_Input.value,
                            NE: N_Input.isEnabled,
                            R: ResetChk.value,
                            A: A_Input.selectedIndex,
                            T: TextSize.value
                        });
                    } else {
                        N_Input.isEnabled = true;
                    }
                };
            var A_Input = Grp01.addComboBox("画板/Artboard", abItems, Math.min(state.A, MaxIdx));
                A_Input.setDescription("排序起始画板，超出最大画板后向右侧不断平移210mm继续排序");

            var Grp02 = winCol.addGroup("文字/Text");
            var TextSize = Grp02.addUnitValueEditor("大小/Size", UnitType.Point, UnitType.Point, state.T, 8, 50);
                TextSize.precision = 0; TextSize.showPopupSlider = true;
                TextSize.setDescription("实际高度受字体影响，看着调吧");
            var TextChk   = Grp02.addCheckBox("添加递增序号(不排序步骤)", false);
                TextChk.isFullWidth = true;
                TextChk.setDescription("勾选后, 点击确定添加序号");

            var res = win.runModal();
            if (res.value !== DialogResult.Ok.value) { break; }
            if (TextChk.value === true && res.value === DialogResult.Ok.value) {
                var TmpVar = TextFun(MdeSlt.selectedIndex, A_Input.selectedIndex, X_Input.value, Y_Input.value, TextSize.value, N_Input.value);
                if (ResetChk.value === true) {var TmpVar = 1}
                saveState({
                    M: MdeSlt.selectedIndex,
                    G: G_Input.value,
                    Y: Y_Input.value,
                    X: X_Input.value,
                    N: TmpVar,
                    NE: N_Input.isEnabled,
                    R: ResetChk.value,
                    A: A_Input.selectedIndex,
                    T: TextSize.value
                });
                break;
            }// 优先判断操作
            if (res.value === DialogResult.Ok.value) {
                var TmpVar = SortFun(MdeSlt.selectedIndex, A_Input.selectedIndex, X_Input.value, Y_Input.value, G_Input.value, N_Input.value);
                if (ResetChk.value === true) {var TmpVar = 1}
                saveState({
                    M: MdeSlt.selectedIndex,
                    G: G_Input.value,
                    Y: Y_Input.value,
                    X: X_Input.value,
                    N: TmpVar,
                    NE: N_Input.isEnabled,
                    R: ResetChk.value,
                    A: A_Input.selectedIndex,
                    T: TextSize.value
                });
            }// 正常 OK：执行排序并保存
            break;
        }
    }
}//参数

MainFun();