/**
 * name: 任意轴镜像_v1
 * description: 【Kucha开发】先选路径保存镜像轴
 * version: 1.1
 * author: Kucha
*/

const { app }                                     = require('/application');
const { FileSystemApi, File }                     = require('/fs');
const { Document }                                = require('/document');
const { Transform }                               = require('/geometry');
const { DocumentCommand, CompoundCommandBuilder } = require('/commands');
const { Selection }                               = require('/selections');

// ── 1. 文件路径 ────────────────────────────────────────────────────────────────
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
}//加载面板状态对象(失败使用默认值)
function saveState(state) {
    try {
        var file = new File(PanelState, "wb");
        file.writeString(JSON.stringify(state, null, 2));
        file.close();
    } catch(e) {}
}//保存面板状态对象


/* 读取 Transform buffer 的 6 个 float64 矩阵元素
 * ★ 重要：buffer 是行主序（row-major），布局为：
 *     [m00, m01, tx,  m10, m11, ty]
 *      [0]  [1]  [2]  [3]  [4]  [5]
 *
 * 正确变换公式：
 *     x' = m[0]*x + m[1]*y + m[2]
 *     y' = m[3]*x + m[4]*y + m[5]
 *
 */
function readMatrix(xf) {
    var dv = new DataView(xf.buffer);
    return [0,1,2,3,4,5].map(function(i) { return dv.getFloat64(i * 8, true); });
}
/* 用矩阵 m 变换点 (px, py)
 * 行主序布局: x' = m[0]*x + m[1]*y + m[2]
 *             y' = m[3]*x + m[4]*y + m[5]
 */
function applyMatrix(m, px, py) {
    return {
        x: m[0]*px + m[1]*py + m[2],
        y: m[3]*px + m[4]*py + m[5]
    };
}
function makeReflectXf(x1, y1, x2, y2) {
    var angle    = Math.atan2(y2 - y1, x2 - x1);
    var toOrigin = Transform.createTranslate(-x1, -y1);
    var rotBack  = Transform.createRotate(-angle);
    var flipY    = Transform.createScale(1, -1);
    var rotFwd   = Transform.createRotate(angle);
    var toP1     = Transform.createTranslate(x1, y1);
    return toP1.multiply(rotFwd).multiply(flipY).multiply(rotBack).multiply(toOrigin);
}//构造 (x1,y1)→(x2,y2) 直线的反射变换
function doMirror(CurDoc, nodes, count) {
    var state = loadState({ p1: null, p2: null });

    if (!state.p1 || !state.p2) {
        app.alert("尚未保存镜像轴。\n请先选中一条路径运行脚本，保存起点/终点坐标。");
        return;
    }

    var x1 = state.p1.x, y1 = state.p1.y;
    var x2 = state.p2.x, y2 = state.p2.y;

    if (Math.abs(x1 - x2) < 1e-6 && Math.abs(y1 - y2) < 1e-6) {
        app.alert("已保存的两个端点重合，无法确定镜像轴。");
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

            // 新变换矩阵 newM = reflM * cm（行主序乘法）
            // newM[0] = reflM[0]*cm[0] + reflM[1]*cm[3]
            // newM[1] = reflM[0]*cm[1] + reflM[1]*cm[4]
            // newM[2] = reflM[0]*cm[2] + reflM[1]*cm[5] + reflM[2]
            // newM[3] = reflM[3]*cm[0] + reflM[4]*cm[3]
            // newM[4] = reflM[3]*cm[1] + reflM[4]*cm[4]
            // newM[5] = reflM[3]*cm[2] + reflM[4]*cm[5] + reflM[5]
            var na  = reflM[0]*cm[0] + reflM[1]*cm[3];
            var nb  = reflM[0]*cm[1] + reflM[1]*cm[4];
            var ntx = reflM[0]*cm[2] + reflM[1]*cm[5] + reflM[2];
            var nc  = reflM[3]*cm[0] + reflM[4]*cm[3];
            var nd  = reflM[3]*cm[1] + reflM[4]*cm[4];
            var nty = reflM[3]*cm[2] + reflM[4]*cm[5] + reflM[5];

            // 增量变换 deltaM = newM * inv(cm)（行主序）
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

            // 极分解 deltaM → T * R * S
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

        } catch(e) {
            //app.alert("处理第 " + i + " 个对象时出错：" + e.message);
        }
    }
    var errCNT = count - mirrored
    if (errCNT > 0) {
        app.alert("镜像失败 " + errCNT + " 个对象, 请检查！");
    }
    if (mirrored > 0) {
        CurDoc.executeCommand(builder.createCommand());
        /*
        app.alert("已镜像 " + mirrored + " 个对象。\n"
            + "轴：P1(" + x1.toFixed(1) + ", " + y1.toFixed(1) + ")"
            + " → P2(" + x2.toFixed(1) + ", " + y2.toFixed(1) + ")");
        */
    } else {
        app.alert("没有可镜像的对象。");
    }
}// 镜像执行函数

var CurDoc = Document.current;
if (!CurDoc) {
    app.alert("没有打开的文档。");
} else {
    var CurSlt = CurDoc.selection;
    var nodes  = CurSlt.nodes;
    var count  = nodes.length;

    if (count === 0) {
        app.alert("没有选中任何对象，请先选择对象后再运行。");
    } else if (count === 1) {
        var node    = nodes.at(0);
        var isCurve = false;
        var p1 = null, p2 = null;
        try {
            if (node.isPolyCurveNode || node.isVectorNode) {//只处理“矢量路径类对象”
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

                        // 行主序读取，x'=m[0]*x+m[1]*y+m[2], y'=m[3]*x+m[4]*y+m[5]
                        var m   = readMatrix(node.transformInterface.transform);
                        var sp1 = applyMatrix(m, ptF.x, ptF.y);
                        var sp2 = applyMatrix(m, ptL.x, ptL.y);

                        if (Math.abs(sp1.x - sp2.x) > 1e-6 || Math.abs(sp1.y - sp2.y) > 1e-6) {
                            p1 = { x: sp1.x, y: sp1.y };
                            p2 = { x: sp2.x, y: sp2.y };
                            isCurve = true;
                        } else {
                            app.alert("路径起点与终点重合，无法保存为镜像轴。");
                        }
                    } else {
                        app.alert("路径节点不足 2 个。");
                    }
                }
            }
        } catch(e) {
            app.alert("读取路径端点时出错：" + e.message);
        }
        if (isCurve && p1 && p2) {
            saveState({ p1: p1, p2: p2 });
            app.alert("已保存镜像轴：\n"
                + "P1(" + p1.x.toFixed(2) + ", " + p1.y.toFixed(2) + ")\n"
                + "P2(" + p2.x.toFixed(2) + ", " + p2.y.toFixed(2) + ")");
        } else if (!isCurve) {
            doMirror(CurDoc, nodes, 1);
        }
    } else {
        doMirror(CurDoc, nodes, count);
    }
}
