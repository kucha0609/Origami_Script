#target photoshop

function GetRtnDATA(DefVar) {
    DefVar = DefVar || 50;

    var result = null;

    var win = new Window("dialog", "请输入参数");
        win.alignChildren = "left";

    var inputGroup = win.add("group");
        inputGroup.alignChildren = "left";
        inputGroup.add("statictext", undefined, "数值:");

    var input = inputGroup.add("edittext", undefined, DefVar.toString());
        input.characters = 10;
        input.active = true;

    // ================= 转RGB =================
    var rgbGroup = win.add("group");
        rgbGroup.alignChildren = "left";

    var rgbCheck = rgbGroup.add("checkbox", undefined, "尝试转到RGB色彩空间");
        rgbCheck.value = true; // 默认勾选

    // ================= 保存格式 =================
    var fmtGroup = win.add("group");
        fmtGroup.alignChildren = "left";
        fmtGroup.add("statictext", undefined, "保存:");
    var fmtOriginal = fmtGroup.add("radiobutton", undefined, "原格式");
    var fmtJpg = fmtGroup.add("radiobutton", undefined, "JPG");
        fmtOriginal.value = true;
    

    // ================= 模式 =================
    var modeGroup = win.add("group");
        modeGroup.alignChildren = "left";
        modeGroup.add("statictext", undefined, "模式:");
    var modePercent = modeGroup.add("radiobutton", undefined, "百分比");
    var modeDPI = modeGroup.add("radiobutton", undefined, "DPI");
        modePercent.value = true;

    // ================= 按钮 =================
    var btnGroup = win.add("group");
        btnGroup.alignment = "center";
    var cancelBtn = btnGroup.add("button", undefined, "取消");
    var okBtn = btnGroup.add("button", undefined, "确定");

    function validate() {
        var txt = input.text.replace(/^\s+|\s+$/g, "");

        if (txt === "" || isNaN(Number(txt))) {
            alert("请输入正确的数字！");
            return;
        }

        result = {
            val: Number(txt),
            rgb: rgbCheck.value,
            fmt: fmtOriginal.value ? "ORI" : "JPG",
            mde: modeDPI.value ? "DPI" : "PER"
        };

        win.close();
    }

    okBtn.onClick = validate;
    input.onEnterKey = validate;

    cancelBtn.onClick = function () {
        result = false;
        win.close();
    };

    win.show();

    return result;
}//获取数据
function ExpNewFile(SavePath, TgtDoc, RtnDATA){
    {//基础函数
        function GetfileNam(fileName) {
            var lastDotIndex = fileName.lastIndexOf(".");
            if (lastDotIndex > 0) {
                var nameOnly = fileName.substring(0, lastDotIndex);
                var extOnly = fileName.substring(lastDotIndex + 1).toUpperCase(); // 转大写
                return [nameOnly, extOnly];
            }
            return [fileName, ""];
        }//文件名拆分
        function scaleDPI(TgtDoc, RtnDATA) {
            //切换到使用像素作为单位，无视文件设置
            var oriUnits = app.preferences.rulerUnits;
                app.preferences.rulerUnits = Units.PIXELS;

            if (RtnDATA.mde === "DPI") {
                //var TgtDPI = 30 //目标分辨率
                var TgtDPI = RtnDATA.val
                var Nwith = TgtDoc.width.value * TgtDPI / TgtDoc.resolution//新宽度
                var Nhght = TgtDoc.height.value * TgtDPI / TgtDoc.resolution//新高度

                if (TgtDoc.width.value >= Nwith || TgtDoc.height.value >= Nhght) {//大于等于新值
                    TgtDoc.resizeImage(Nwith, Nhght, TgtDPI, ResampleMethod.BICUBIC);//修改分辨率
                }
            } 
            else if (RtnDATA.mde === "PER") {
                //var TgtPER = 50 / 100 //目标分辨率
                var TgtPER = RtnDATA.val / 100
                var Nwith = TgtDoc.width.value * TgtPER //新宽度
                var Nhght = TgtDoc.height.value * TgtPER //新高度

                TgtDoc.resizeImage(Nwith, Nhght, TgtDoc.resolution, ResampleMethod.BICUBIC);//修改分辨率
            }

            //完成后，切换回原始文件的单位。
            app.preferences.rulerUnits = oriUnits;

        }//等比缩小
    }

    var DocNam = GetfileNam(TgtDoc.name);//文件名数组
    try {
        if (RtnDATA.rgb === true){
            TgtDoc.convertProfile("sRGB IEC61966-2.1", Intent.RELATIVECOLORIMETRIC, true, false);//转换色彩空间到RGB
        }
        scaleDPI(TgtDoc, RtnDATA);//缩小文件
        if (RtnDATA.fmt === "ORI") {
            var ExtNam = DocNam[1].toUpperCase()//大写的扩展名
            if (ExtNam == "PSD"){
                var psdOptions = new PhotoshopSaveOptions();
                    psdOptions.alphaChannels = true;// 保存 Alpha 通道（透明通道、选区通道等都会保留下来）
                    psdOptions.layers = true;// 保留所有图层（不合并图层，下次打开还能编辑）
                    psdOptions.embedColorProfile = true;// 嵌入颜色配置文件（保留图片的颜色模式、色彩配置，保证颜色不变）
                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), psdOptions, true);
            }//PSD格式
            else if (ExtNam == "PSB"){
                var psbOptions = new PhotoshopSaveOptions();
                    psbOptions.layers = true;               // 保留图层（必需）
                    psbOptions.alphaChannels = true;       // 保留透明/蒙版
                    psbOptions.annotations = false;        // 无注释
                    psbOptions.spotColors = false;         // 无专色
                    psbOptions.embedColorProfile = true;   // 嵌入色彩配置
                    psbOptions.maximizeCompatibility = false; // 不兼容（文件更小）
                    
                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), psbOptions, true);
            }
            else if (ExtNam == "PNG"){
                var pngOptions = new PNGSaveOptions();
                    pngOptions.compression = 6; // 0-9，数值越小文件越大质量越高
                    pngOptions.interlaced = false;//不隔行扫描（渐进加载）
                    pngOptions.transparency = true;//保留透明
                    pngOptions.embedColorProfile = true;// 嵌入色彩配置

                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), pngOptions, true);
            }
            else if ((ExtNam == "JPG") || (ExtNam == "JPEG")){
                var jpgOptions = new JPEGSaveOptions();
                    jpgOptions.quality = 10; // 0-12，最高12
                    jpgOptions.formatOptions = FormatOptions.STANDARDBASELINE;//标准基线（普通通用 JPG，默认）
                    jpgOptions.embedColorProfile = true;//// 嵌入色彩配置文件

                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), jpgOptions, true);
            }//JPG / JPEG 格式
            else if ((ExtNam == "TIFF") || (ExtNam == "TIF")){
                var tiffOptions = new TiffSaveOptions();
                    tiffOptions.transparent = true;             // 保留透明/ 嵌入ICC

                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), tiffOptions, true);
            }//TIFF 格式
            else if (ExtNam == "BMP"){
                var bmpOptions = new BMPSaveOptions();
                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), bmpOptions, true);
            }//BMP 格式
            else if (ExtNam == "TGA"){
                var tgaOptions = new TargaSaveOptions();
                    //tgaOptions.resolution = 32;       // 32=带Alpha透明，24=无透明，16=低色深
                    //tgaOptions.rleCompression = false;// false=无压缩(引擎通用)，true=RLE无损压缩
                    // tgaOptions.transparency = true; // 32位自动携带Alpha通道
                    
                TgtDoc.saveAs(new File(SavePath + TgtDoc.name), tgaOptions, true);
            }//TGA 格式
            else {
                var psdOptions = new PhotoshopSaveOptions();
                    psdOptions.alphaChannels = true;
                    psdOptions.layers = true;
                TgtDoc.saveAs(new File(SavePath + DocNam[0] + ".psd"), psdOptions, true);
            }//未知都存PSD格式
        } // 核心:根据【原文件格式】自动匹配保存方法
        else if (RtnDATA.fmt === "JPG") {
            var jpgOptions = new JPEGSaveOptions();
                jpgOptions.quality = 10; // 0-12，最高12
                jpgOptions.formatOptions = FormatOptions.STANDARDBASELINE;//标准基线（普通通用 JPG，默认）
                jpgOptions.embedColorProfile = true;//// 嵌入色彩配置文件

            TgtDoc.saveAs(new File(SavePath + TgtDoc.name), jpgOptions, true);
        }//始终存JPG格式
        TgtDoc.close(SaveOptions.DONOTSAVECHANGES);//关闭文档
    } catch (e) {
        TgtDoc.close(SaveOptions.DONOTSAVECHANGES);//关闭文档
    }
    
}//处理文件:转RGB+缩小DPI导出

if (app.documents.length == 0) {
    var RtnDATA = GetRtnDATA(false);
    if(RtnDATA !== false){
        var AllDoc = File.openDialog("请选择图片文件", '*.PSB;*.PSD;*.TIF;*.TIFF;*.PNG;*.JPG;*.JPEG;*.BMP;*.TGA', true);//'*.PSD;*.PNG'
        if (AllDoc !== null) {//选择了文件
            var SavePath = "~/Desktop/textures/"
            if (!Folder(SavePath).exists) { Folder(SavePath).create() }//如果文件夹不存在则新建

            for (var i = 0; i < AllDoc.length; i++) {
                var TgtDoc = app.open(AllDoc[i]);//打开文件
                ExpNewFile(SavePath, TgtDoc, RtnDATA);
            }
            if (confirm("打开导出的文件夹？")) {
                Folder(SavePath).execute();//打开文件夹 
            }
        }
    }
} else {//
}

