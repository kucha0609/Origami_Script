/**
 * name: 选轴镜像_v2
 * description: 【Kucha开发】先选路径保存镜像轴
 * version: 1.2
 * author: Kucha
*/

const { app }                                     = require('/application');
const { FileSystemApi, File }                     = require('/fs');
const { Document }                                = require('/document');
const { Transform }                               = require('/geometry');
const { DocumentCommand, CompoundCommandBuilder } = require('/commands');
const { Selection }                               = require('/selections');

var ScriptName  = "Mirror";
var StateFolder = app.userDesktopPath + "\\OriKucha";
if (!FileSystemApi.exists(StateFolder)) { FileSystemApi.createDirectory(StateFolder); }
var PanelState  = StateFolder + "\\" + ScriptName + "_state.json";
function loadState(defaults) {
    try {
        if (FileSystemApi.exists(PanelState)) {
            var buf    = File.readAll(PanelState);
            var text   = buf.toString("utf8");
            var parsed = JSON.parse(text);
            var isValid = Object.keys(defaults).every(function(k) {
                return Object.prototype.hasOwnProperty.call(parsed, k);
            });
            if (!isValid) return Object.assign({}, defaults);
            return Object.assign({}, defaults, parsed);
        }
    } catch(e) {}
    return Object.assign({}, defaults);
}
function saveState(state) {
    try {
        var file = new File(PanelState, "wb");
        file.writeString(JSON.stringify(state, null, 2));
        file.close();
    } catch(e) {}
}
function compareVersion(target) {
    /**
     * 比较版本，返回：
     *  -1 = 当前版本 < target
     *   0 = 相等
     *   1 = 当前版本 > target
     * target 可以是字符串 "3.2.0.0" 或数组 [3, 2, 0, 0]
     */
    function getVersion() {
        //例："Affinity 3.2.2.4557 Win32 (Jun 12 2026)" → [3, 2, 2, 4557]
        var m = String(app.version).match(/(\d+\.\d+\.\d+\.\d+)/);
        return m ? m[1].split('.').map(Number) : [0, 0, 0, 0];
    }//四段版本号数组 
    var cur = getVersion();
    var tgt = typeof target === 'string'
        ? target.split('.').map(Number)
        : target;
    for (var i = 0; i < 4; i++) {
        var a = cur[i] || 0, b = tgt[i] || 0;
        if (a !== b) return a > b ? 1 : -1;
    }
    return 0;
}//比较版本号(和当前版本)

function readMatrix(xf) {
    var d = xf.data;
    return [d[0], d[1], d[2], d[3], d[4], d[5]];
}

function makeReflectXf(x1, y1, x2, y2) {
    var angle    = Math.atan2(y2 - y1, x2 - x1);
    var toOrigin = Transform.createTranslate(-x1, -y1);
    var rotBack  = Transform.createRotate(-angle);
    var flipY    = Transform.createScale(1, -1);
    var rotFwd   = Transform.createRotate(angle);
    var toP1     = Transform.createTranslate(x1, y1);
    return toP1.multiply(rotFwd).multiply(flipY).multiply(rotBack).multiply(toOrigin);
}

function doMirror(CurDoc, nodes, count) {
    var state = loadState({ p1: null, p2: null });
    if (!state.p1 || !state.p2) {
        app.alert("请先选中一条路径运行脚本，保存起点/终点坐标", "尚未保存镜像轴");
        return;
    }
    var x1 = state.p1.x, y1 = state.p1.y;
    var x2 = state.p2.x, y2 = state.p2.y;
    if (Math.abs(x1 - x2) < 1e-6 && Math.abs(y1 - y2) < 1e-6) {
        app.alert("已保存的两个端点重合，无法确定镜像轴。", "无法确定镜像轴");
        return;
    }
    var reflXf  = makeReflectXf(x1, y1, x2, y2);
    var reflM   = readMatrix(reflXf);
    var builder = CompoundCommandBuilder.create();
    var mirrored = 0;
    for (var i = 0; i < count; i++) {
        try {
            var node = nodes.at(i);
            if (!node) continue;
            var cm = readMatrix(node.transformInterface.transform);
            var na  = reflM[0]*cm[0] + reflM[1]*cm[3];
            var nb  = reflM[0]*cm[1] + reflM[1]*cm[4];
            var ntx = reflM[0]*cm[2] + reflM[1]*cm[5] + reflM[2];
            var nc  = reflM[3]*cm[0] + reflM[4]*cm[3];
            var nd  = reflM[3]*cm[1] + reflM[4]*cm[4];
            var nty = reflM[3]*cm[2] + reflM[4]*cm[5] + reflM[5];
            var det = cm[0]*cm[4] - cm[1]*cm[3];
            if (Math.abs(det) < 1e-12) continue;
            var invA  =  cm[4] / det;
            var invB  = -cm[1] / det;
            var invC  = -cm[3] / det;
            var invD  =  cm[0] / det;
            var invTx = -(invA*cm[2] + invB*cm[5]);
            var invTy = -(invC*cm[2] + invD*cm[5]);
            var da  = na*invA + nb*invC;
            var db  = na*invB + nb*invD;
            var dtx = na*invTx + nb*invTy + ntx;
            var dc  = nc*invA + nd*invC;
            var dd  = nc*invB + nd*invD;
            var dty = nc*invTx + nd*invTy + nty;
            var sx  = Math.sqrt(da*da + dc*dc);
            var sy  = Math.sqrt(db*db + dd*dd);
            if ((da*dd - db*dc) < 0) sy = -sy;
            var rot = Math.atan2(dc, da);
            var deltaXf = Transform.createTranslate(dtx, dty)
                            .multiply(Transform.createRotate(rot))
                            .multiply(Transform.createScale(sx, sy));
            var nodeSel = Selection.create(CurDoc, node);
            builder.addCommand(DocumentCommand.createTransform(nodeSel, deltaXf));
            mirrored++;
        } catch(e) {}
    }
    var errCNT = count - mirrored;
    if (errCNT > 0) {
        app.alert("镜像失败 " + errCNT + " 个对象, 请检查！", "失败");
    }
    if (mirrored > 0) {
        CurDoc.executeCommand(builder.createCommand());
    } else {
        app.alert("没有可镜像的对象。", "失败");
    }
}

if (compareVersion([3, 2, 2, 4557]) = -1) {
  app.alert("至少需要3.2.2.4557\n当前版本为:" + app.version , "版本过低");
}else {
    var CurDoc = Document.current;
    if (!CurDoc) {
        app.alert("没有打开的文档。", "错误");
    } else {
        var CurSlt = CurDoc.selection;
        var nodes  = CurSlt.nodes;
        var count  = nodes.length;
        if (count === 0) {
            app.alert("没有选中任何对象，请先选择对象后再运行", "失败");
        } else if (count === 1) {
            var node    = nodes.at(0);
            var isCurve = false;
            var p1 = null, p2 = null;
            try {
                if (node.isPolyCurveNode || node.isVectorNode) {
                    var pc = node.curvesInterface && node.curvesInterface.polyCurve;
                    if (pc && pc.curveCount > 0) {
                        var curve = pc.curves.first;
                        var bfd   = node.brushFillDescriptor;
                        var OpenNoFill = !curve.isClosed && bfd && String(bfd.fillType) === 'None';
                        if (!OpenNoFill) {
                            // 闭合或有填充 → 走镜像分支
                        } else if (curve.nodeCount >= 2) {
                            var ptF = curve.points.first;
                            var ptL = curve.points.last;
                            var xf  = node.transformInterface.transform;
                            var sp1 = xf.applyToPoint({ x: ptF.x, y: ptF.y });
                            var sp2 = xf.applyToPoint({ x: ptL.x, y: ptL.y });
                            if (Math.abs(sp1.x - sp2.x) > 1e-6 || Math.abs(sp1.y - sp2.y) > 1e-6) {
                                p1 = { x: sp1.x, y: sp1.y };
                                p2 = { x: sp2.x, y: sp2.y };
                                isCurve = true;
                            } else {
                                app.alert("路径起点与终点重合，无法保存为镜像轴", "失败");
                            }
                        } else {
                            app.alert("路径节点不足 2 个", "失败");
                        }
                    }
                }
            } catch(e) {
                app.alert("读取路径端点时出错：" + e.message , "失败");
            }
            if (isCurve && p1 && p2) {
                saveState({ p1: p1, p2: p2 });
                app.alert(
                    "P1(" + p1.x.toFixed(2) + ", " + p1.y.toFixed(2) + ")\n"
                    + "P2(" + p2.x.toFixed(2) + ", " + p2.y.toFixed(2) + ")"
                    , "已保存镜像轴："
                );
            } else if (!isCurve) {
                doMirror(CurDoc, nodes, 1);
            }
        } else {
            doMirror(CurDoc, nodes, count);
        }
    }
}
