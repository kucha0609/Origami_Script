#target photoshop

function GetTgtDPI(DefDPI) {
    DefDPI = DefDPI || 72; // 默认值
    var result = false; // 保存返回值

    var win = new Window("dialog", "请输入目标DPI：");// 创建对话框

    // 输入框
    var input = win.add("edittext", undefined, DefDPI.toString());
        input.characters = 8;
        input.active = true; // 默认焦点在输入

    // 按钮组
    var group = win.add("group");
        group.alignment = "center";
    var NoBtn = group.add("button", undefined, "取消");
    var okBtn = group.add("button", undefined, "确定");

    // 验证函数
    function validate() {
        var txt = input.text.replace(/^\s+|\s+$/g, "");
        if (txt !== "" && !isNaN(Number(txt))) {
            result = Number(txt); // 保存数值
            win.close();
        } else {
            alert("请输入正确的数字！");
        }
    }
    okBtn.onClick = validate;// 点击确认按钮
    input.onEnterKey = validate;// 按回车键
    NoBtn.onClick = function () {
        result = false;
        win.close();
    };// 取消按钮
    
    win.show();//显示窗口
    return result;
}//获取DPI
function ExpNewFile(SavePath, TgtDoc, TgtDPI){
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
        function scaleDPI(TgtDoc, TgtDPI) {
            //切换到使用像素作为单位，无视文件设置
            var oriUnits = app.preferences.rulerUnits;
                app.preferences.rulerUnits = Units.PIXELS;

            //var TgtDPI = 30 //目标分辨率
            var Nwith = TgtDoc.width.value*TgtDPI/TgtDoc.resolution//新宽度
            var Nhght = TgtDoc.height.value*TgtDPI/TgtDoc.resolution//新高度

            if (TgtDoc.width.value >= Nwith || TgtDoc.height.value >= Nhght){//大于等于新值
                TgtDoc.resizeImage(Nwith, Nhght, TgtDPI, ResampleMethod.BICUBIC);//修改分辨率
            }
            //完成后，切换回原始文件的单位。
            app.preferences.rulerUnits = oriUnits;
        }//等比缩小
    }

    var DocNam = GetfileNam(TgtDoc.name);//文件名数组
    // 核心：根据【原文件格式】自动匹配保存方法
    try {
        TgtDoc.convertProfile("sRGB IEC61966-2.1", Intent.RELATIVECOLORIMETRIC, true, false);//转换色彩空间RGB
        
        scaleDPI(TgtDoc, TgtDPI);//缩小文件
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
        else {
            var psdOptions = new PhotoshopSaveOptions();
                psdOptions.alphaChannels = true;
                psdOptions.layers = true;
            TgtDoc.saveAs(new File(SavePath + DocNam[0] + ".psd"), psdOptions, true);
        }//未知都存PSD格式
        TgtDoc.close(SaveOptions.DONOTSAVECHANGES);//关闭文档
    } catch (e) {
    //nothing//
    }
}//处理文件：转RGB+缩小DPI导出

if (app.documents.length == 0) {
    var TgtDPI = GetTgtDPI(false);
    if(TgtDPI !== false){
        var AllDoc = File.openDialog("请选择图片文件", '*.PSB;*.PSD;*.TIF;*.TIFF;*.PNG;*.JPG;*.JPEG;*.BMP', true);//'*.PSD;*.PNG'
        if (AllDoc !== null) {//选择了文件
            var SavePath = "~/Desktop/textures/"
            if (!Folder(SavePath).exists) { Folder(SavePath).create() }//如果文件夹不存在则新建

            for (var i = 0; i < AllDoc.length; i++) {
                var TgtDoc = app.open(AllDoc[i]);
                ExpNewFile(SavePath, TgtDoc, TgtDPI)
            }
            if (confirm("打开导出的文件夹？")) {
                Folder(SavePath).execute();//打开文件夹 
            }
        }
    }
} else {//
}

