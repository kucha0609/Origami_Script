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

