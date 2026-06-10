/**
 * name: 修复序号_v1
 * description: 根据起始序号，先上下后左右的修复
 * version: 1.0
 * author: Kucha
*/


const { app }      = require('/application');
const { Document } = require('/document');
const { DocumentCommand, CompoundCommandBuilder } = require('/commands');
const { Selection, TextSelection } = require('/selections');
const { Dialog, DialogResult } = require('/dialog');
const { File, FileSystemApi } = require('/fs');
const { UnitType } = require('/units');


function splitLabel(S, item) {
    var str = item.getText(); // 获取文字内容
    var separators = [' ', '.', '、', '-']; // 定义允许的分隔符
    var searchRange = str.slice(0, S); // 只取前S个字符作为搜索范围

    var splitIndex = -1; // 记录最后一个分隔符的位置

    // 查找前5位中最后出现的分隔符
    for (var i = 0; i < searchRange.length; i++) {
        if (separators.indexOf(searchRange[i]) !== -1) {
            splitIndex = i;
        }
    }

    // 找到了分隔符
    if (splitIndex !== -1) {
        var before = str.slice(0, splitIndex); // 分隔符前面的内容
        var num = parseFloat(before);

        // 使用 parseFloat 宽松判断是否为数字
        if (!isNaN(num)) {
            return [num, str.slice(splitIndex + 1)];
        } else {
            return [false, str.slice(splitIndex + 1)];
        }
    }

    // 未找到分隔符
    return [false, str];
}; // 根据分隔符拆分文字内容(查找前5位，取最后一个分隔符)
function FixStepNum(S, N) {
    var CurDoc = Document.current;
    var CurSlt = CurDoc.selection.nodes.toArray();
    try{
        var TxtGrp = [];
        for (var i = 0; i < CurSlt.length; i++) {
            var item = CurSlt[i];
            if (item.isTextNode) {
                TxtGrp.push([item, splitLabel(S, item)[1]]);
            }
        }
        if (TxtGrp.length === 0) { return; }
        TxtGrp.sort(function (a, b) {
            var aBox = a[0].getSpreadBaseBox(false);
            var bBox = b[0].getSpreadBaseBox(false);
            var dy = aBox.y - bBox.y;//顶
            return Math.abs(dy) <= (30 * Document.current.dpi / 25.4) ? aBox.x - bBox.x : dy;
        });//先上下后左右排序(Y向下)
        var builder = CompoundCommandBuilder.create();
        var StaNum = parseFloat(N); // 起始序号
        for (var j = 0; j < TxtGrp.length; j++) {
            var node    = TxtGrp[j][0];
            var newText = (StaNum <= 9 ? "0" : "") + StaNum + ". " + TxtGrp[j][1];
            var range   = node.storyInterface.storyRange;
            var textSel = TextSelection.create([{ begin: range.begin, end: range.end }]);
            var sel     = Selection.create(CurDoc, node);
            sel.addSubSelectionForNode(node, textSel);
            builder.addCommand(DocumentCommand.createSetText(sel, newText));
            StaNum++;
        }
        CurDoc.executeCommand(builder.createCommand()); // 一次执行，一次撤销
    } catch(e) {
        return N;
    };
    return StaNum;
}//修复序号


var ScriptNam = "StepNum";
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
function MainFun() {
    var defaults = {
        S: 5, 
        N: 1
    };
    while (true) {
        var state   = loadState(defaults);
        var win = Dialog.create("修复序号/" + ScriptNam);
            win.initialWidth = 50;//默认宽度
            win.isResizable = true;//可调整大小

        var winCol = win.addColumn();
        var Grp01 = winCol.addGroup("参数/Setting");
        var S_Input = Grp01.addUnitValueEditor("拆分/Split", UnitType.Number, UnitType.Number, state.S, 5, 10);
            S_Input.precision = 0; S_Input.showPopupSlider = true;
            S_Input.setDescription("序号拆分的位置");
        var N_Input = Grp01.addUnitValueEditor("序号/Number", UnitType.Number, UnitType.Number, state.N, 1, 999);
            N_Input.precision = 0; N_Input.showPopupSlider = true;
            N_Input.setDescription("起始序号");
        var ResetChk  = Grp01.addCheckBox("起始重置/Reset 1", state.R);
            ResetChk.isFullWidth = true; N_Input.isEnabled = true
            ResetChk.setDescription("立即将起始序号重置为1");
            ResetChk.onValueChangedHandler = function() {
                if (ResetChk.value === true) {
                    N_Input.value     = 1;
                }
            };

        var res = win.runModal();
        if (res.value !== DialogResult.Ok.value) { break; }

        if (res.value === DialogResult.Ok.value) {
            var TmpVar = FixStepNum(S_Input.value, N_Input.value);
            saveState({
                S: S_Input.value,
                N: TmpVar
            });
        }// 正常 OK：执行排序并保存
        break;
    }
    
}//参数

MainFun();