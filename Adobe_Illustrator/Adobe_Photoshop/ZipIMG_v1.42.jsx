#target photoshop

{//配置函数
    //当配置文件不存在时，写入默认参数。
    function createXml(filePath) {
        ZipXml = new XML("<Kucha007></Kucha007>");
        ZipXml.pct = "100",
        ZipXml.dpi = "30",
        ZipXml.pix = "1024",
        ZipXml.opf = "1",//1是true，0是flase
        ZipXml.mgl = "1",//1是true，0是flase

        ZipXml.col = "0", //第1个
        ZipXml.mde = "0", //第1个
        ZipXml.fmt = "0", //第1个
        ZipXml.path = "1", //第2个
        ZipXml.pstr = "C:\\tmp\\ZipIMG\\", 

        readwriteXml("w", filePath, ZipXml);
    }
    //将输入值保存到配置文件
    function save2Xml() {
        ZipXml.pct = vPCT.text,
        ZipXml.dpi = vDPI.text,
        ZipXml.pix = vPIX.text,
        ZipXml.opf = opFold.value ? "1" : "0",
        ZipXml.mgl = MgLays.value ? "1" : "0",

        ZipXml.col = col0.value ? "0" : (col1.value ? "1" : (col2.value ? "2" : "3")),
        ZipXml.mde = mPCT.value ? "0" : (mDPI.value ? "1" : (mMin.value ? "2" : "3")),
        ZipXml.fmt = fORI.value ? "0" : (fJPG.value ? "1" : (fPNG.value ? "2" : "3")),
        ZipXml.path = pORI.value ? "0" : (pCOM.value ? "1" : (pDSK.value ? "2" : "3")),
        ZipXml.pstr = PathSTR.text

        readwriteXml("w", configFilePath, ZipXml);
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
function ExpNewFile(NamLst, SavePath, TgtDoc, RtnDATA){
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
        function scaleDPI(TgtDoc, RtnDATA) {
            var oriUnits = app.preferences.rulerUnits;

            try {
                app.preferences.rulerUnits = Units.PIXELS;//切换到使用像素作为单位，无视文件设置
                if (RtnDATA.mde == "0" && RtnDATA.val !== 100) {
                    //var TgtPER = 50 / 100 //目标百分比
                    var TgtPER = RtnDATA.val / 100
                    var Nwith = TgtDoc.width.value * TgtPER //新宽度
                    var Nhght = TgtDoc.height.value * TgtPER //新高度

                    TgtDoc.resizeImage(Nwith, Nhght, TgtDoc.resolution, ResampleMethod.BICUBIC);//修改分辨率
                } 
                else if (RtnDATA.mde == "1") {
                    //var TgtDPI = 30 //目标分辨率
                    var TgtDPI = RtnDATA.val
                    var Nwith = TgtDoc.width.value * TgtDPI / TgtDoc.resolution//新宽度
                    var Nhght = TgtDoc.height.value * TgtDPI / TgtDoc.resolution//新高度

                    if (TgtDoc.width.value >= Nwith || TgtDoc.height.value >= Nhght) {//大于等于新值
                        TgtDoc.resizeImage(Nwith, Nhght, TgtDPI, ResampleMethod.BICUBIC);//修改分辨率
                    }
                }
                else if (RtnDATA.mde == "2") {
                    var MinLen = Math.min(TgtDoc.width.value, TgtDoc.height.value)
                    if (MinLen > RtnDATA.val){
                        var TgtPER = RtnDATA.val / MinLen
                        var Nwith = TgtDoc.width.value * TgtPER //新宽度
                        var Nhght = TgtDoc.height.value * TgtPER //新高度

                        TgtDoc.resizeImage(Nwith, Nhght, TgtDoc.resolution, ResampleMethod.BICUBIC);//修改分辨率
                    }

                }
                else if (RtnDATA.mde == "3") {
                    var MaxLen = Math.max(TgtDoc.width.value, TgtDoc.height.value)
                    if (MaxLen > RtnDATA.val){
                        var TgtPER = RtnDATA.val / MaxLen
                        var Nwith = TgtDoc.width.value * TgtPER //新宽度
                        var Nhght = TgtDoc.height.value * TgtPER //新高度

                        TgtDoc.resizeImage(Nwith, Nhght, TgtDoc.resolution, ResampleMethod.BICUBIC);//修改分辨率
                    }

                }
            } finally {
                app.preferences.rulerUnits = oriUnits;//完成后，切换回原始文件的单位。
            }
        }//等比缩小
        function MergeLays(TgtDoc) {
            for (var i = TgtDoc.layers.length - 1; i >= 0; i--) {
                if (!TgtDoc.layers[i].visible) {
                    TgtDoc.layers[i].remove();
                }
            }// 删除所有隐藏图层
            if (TgtDoc.layers.length > 1) {
                TgtDoc.mergeVisibleLayers();// 合并所有可见图层
            }
        }//合并可见层并删除隐藏层
        function saveAsPSB(NewFile, asCopy) {
            var s2t = function (s) { return app.stringIDToTypeID(s); };
            var descriptor = new ActionDescriptor();
            var descriptor2 = new ActionDescriptor();
            descriptor.putObject(s2t("as"), s2t("largeDocumentFormat"), descriptor2);
            descriptor.putPath(s2t("in"), NewFile);
            descriptor.putBoolean(s2t("copy"), asCopy);
            descriptor.putBoolean(s2t("lowerCase"), true);
            executeAction(s2t("save"), descriptor, DialogModes.NO); //保存
            //executeAction(s2t("close"), new ActionDescriptor(), DialogModes.NO);//关闭当前文档
        }//保存为psb格式
        function save2WebP(WebPFile, compType, compValue, xmpData, exifData, psData) {
            //saveWebP(new File(Folder.desktop.fsName + "\\" + "cs" + ".webp"), "compressionLossy", 75, true, true, true);
            /*
            自2020年以来，DOM 一直没有更新，因此需要使用动作管理器Action Manager代码来实现
            v1.3 - 10th February 2024, Stephen Marsh
            https://community.adobe.com/t5/photoshop-ecosystem-discussions/saving-webp-image-by-script/td-p/13642577
            */

            function s2t(s) { return app.stringIDToTypeID(s); }
            var dsp1 = new ActionDescriptor();
            var dsp2 = new ActionDescriptor();
                dsp2.putEnumerated(s2t("compression"), s2t("WebPCompression"), s2t(compType)); // 压缩模式参数可选值："compressionLossless"无损 / "compressionLossy"有损
            var WebPCompIsLossless = false; // 设置压缩模式默认标识
            if (WebPCompIsLossless == false) {
                dsp2.putInteger(s2t("quality"), compValue);  // 有损画质取值范围：0（最低画质）~ 100（最高画质）
            }//无损压缩时忽略

            // 元数据配置项
            dsp2.putBoolean(s2t("includeXMPData"), xmpData); // 是否包含XMP元数据
            dsp2.putBoolean(s2t("includeEXIFData"), exifData); // 是否包含EXIF拍摄信息
            dsp2.putBoolean(s2t("includePsExtras"), psData); // 是否保留PS附加数据

            dsp1.putObject(s2t("as"), s2t("WebPFormat"), dsp2);// WebP格式定义
            dsp1.putPath(s2t("in"), WebPFile); //保存路径
            //dsp1.putBoolean(s2t("copy"), asCopy); // 另存副本开关：false=直接保存 / true=另存为副本
            dsp1.putBoolean(s2t("lowerCase"), true);// 文件后缀小写设置
            
            activeDocument.bitsPerChannel = BitsPerChannelType.EIGHT;// 转换通道位深度为8位/通道
            // 执行保存动作
            executeAction(s2t("save"), dsp1, DialogModes.NO); // 将NO改为ALL可弹出保存设置弹窗
        }//保存为Web格式(2022)
    }

    var DocNam = GetfileNam(TgtDoc.name);//文件名数组
    try {
        scaleDPI(TgtDoc, RtnDATA);//缩小文件
        if (RtnDATA.col == "1") {
            TgtDoc.changeMode(ChangeMode.RGB);
        }
        else if (RtnDATA.col == "2") {
            TgtDoc.changeMode(ChangeMode.RGB);
            TgtDoc.convertProfile("sRGB IEC61966-2.1", Intent.RELATIVECOLORIMETRIC, true, false)
        }
        else if (RtnDATA.col == "3") {
            TgtDoc.changeMode(ChangeMode.CMYK);
        }

        if (RtnDATA.fmt == "0") {
            var ExtNam = DocNam[1].toUpperCase()//大写的扩展名
            if (ExtNam == "PSD"){
                var NewFile = new File(SavePath +  "//" + DocNam[0] + ".psd")
                if (RtnDATA.mgl == "1") { MergeLays(TgtDoc); }//合并可见层

                var psdOptions = new PhotoshopSaveOptions();
                    psdOptions.alphaChannels = true;// 保存 Alpha 通道（透明通道、选区通道等都会保留下来）
                    psdOptions.layers = true;// 保留所有图层（不合并图层，下次打开还能编辑）
                    psdOptions.embedColorProfile = true;// 嵌入颜色配置文件（保留图片的颜色模式、色彩配置，保证颜色不变）
                TgtDoc.saveAs(NewFile, psdOptions, true);
            }//PSD格式
            else if (ExtNam == "PSB"){
                var NewFile = new File(SavePath +  "//" + DocNam[0] + ".psb")
                if (RtnDATA.mgl == "1") { MergeLays(TgtDoc); }//合并可见层

                saveAsPSB(NewFile, false)
            }
            else if (ExtNam == "PNG"){
                if (TgtDoc.mode == DocumentMode.RGB){
                    var NewFile = new File(SavePath +  "//" + DocNam[0] + ".png")
                    var pngOptions = new PNGSaveOptions();
                        pngOptions.compression = 6; // 0-9，数值越小文件越大质量越高
                        pngOptions.interlaced = false;//不隔行扫描（渐进加载）
                        //pngOptions.transparency = true;//保留透明？不支持？
                        //pngOptions.embedColorProfile = true;// 嵌入色彩配置？不支持？

                    TgtDoc.saveAs(NewFile, pngOptions, true);
                }else{
                    var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "psb"])
                    saveAsPSB(NewFile, false)
                }
            }
            else if ((ExtNam == "JPG") || (ExtNam == "JPEG")){
                var NewFile = new File(SavePath +  "//" + DocNam[0] + ".jpg")
                var jpgOptions = new JPEGSaveOptions();
                    jpgOptions.quality = 10; // 0-12，最高12
                    jpgOptions.formatOptions = FormatOptions.STANDARDBASELINE;//标准基线（普通通用 JPG，默认）
                    jpgOptions.embedColorProfile = true;//// 嵌入色彩配置文件

                TgtDoc.saveAs(NewFile, jpgOptions, true);
            }//JPG / JPEG 格式
            else if ((ExtNam == "TIF") || (ExtNam == "TIFF")){
                var NewFile = new File(SavePath +  "//" + DocNam[0] + ".tif")
                if (RtnDATA.mgl == "1") { MergeLays(TgtDoc); }//合并可见层

                var tiffOptions = new TiffSaveOptions();
                    tiffOptions.transparency = true;// 保留透明
                    tiffOptions.embedColorProfile = true;//嵌入？不支持？

                TgtDoc.saveAs(NewFile, tiffOptions, true);
            }//TIFF 格式
            else if (ExtNam == "BMP"){
                if (TgtDoc.mode == DocumentMode.RGB){
                    var NewFile = new File(SavePath +  "//" + DocNam[0] + ".bmp")
                    var bmpOptions = new BMPSaveOptions();
                    TgtDoc.saveAs(NewFile, bmpOptions, true);
                }else{
                    var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "psb"])
                    saveAsPSB(NewFile, false)
                }
            }//BMP 格式
            else if (ExtNam == "TGA"){
                if (TgtDoc.mode == DocumentMode.RGB){
                    var NewFile = new File(SavePath +  "//" + DocNam[0] + ".tga")
                    var tgaOptions = new TargaSaveOptions();
                        //tgaOptions.resolution = 32;       // 32=带Alpha透明，24=无透明，16=低色深
                        //tgaOptions.rleCompression = false;// false=无压缩(引擎通用)，true=RLE无损压缩
                        // tgaOptions.transparency = true; // 32位自动携带Alpha通道
                        
                    TgtDoc.saveAs(NewFile, tgaOptions, true);
                }else{
                    var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "psb"])
                    saveAsPSB(NewFile, false)
                }
            }//TGA 格式
            else if (ExtNam == "WEBP"){
                if (TgtDoc.mode == DocumentMode.RGB){
                    var NewFile = new File(SavePath +  "//" + DocNam[0] + ".webp")
                    save2WebP(NewFile, "compressionLossy", 75, true, true, true);
                }else{
                    var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "psb"])
                    saveAsPSB(NewFile, false)
                }
            }//WEBP格式
            else {
                var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "psb"])
                if (RtnDATA.mgl == "1") { MergeLays(TgtDoc); }//合并可见层

                saveAsPSB(NewFile, false)
            }//未知都存PSB格式
        } // 核心:根据【原文件格式】自动匹配保存方法
        else if (RtnDATA.fmt == "1") {
            var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "jpg"])
            var jpgOptions = new JPEGSaveOptions();
                jpgOptions.quality = 10; // 0-12，最高12
                jpgOptions.formatOptions = FormatOptions.STANDARDBASELINE;//标准基线（普通通用 JPG，默认）
                jpgOptions.embedColorProfile = true;//// 嵌入色彩配置文件

            TgtDoc.saveAs(NewFile, jpgOptions, true);
        }//始终存JPG格式
        else if (RtnDATA.fmt == "2") {
            var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "png"])
            TgtDoc.changeMode(ChangeMode.RGB);//转换为RGB模式
            var pngOptions = new PNGSaveOptions();
                pngOptions.compression = 6; // 0-9，数值越小文件越大质量越高
                pngOptions.interlaced = false;//不隔行扫描（渐进加载）
                //pngOptions.transparency = true;//保留透明？不支持？
                //pngOptions.embedColorProfile = true;// 嵌入色彩配置？不支持？

            TgtDoc.saveAs(NewFile, pngOptions, true);
        }//始终存PNG格式
        else if (RtnDATA.fmt == "3") {
            var NewFile = GetUNQNam(NamLst, [SavePath, DocNam[0], "webp"])
            TgtDoc.changeMode(ChangeMode.RGB);//转换为RGB模式
            save2WebP(NewFile, "compressionLossy", 75, true, true, true);
        }//始终存webp格式
        TgtDoc.close(SaveOptions.DONOTSAVECHANGES);//关闭文档
    } catch (e) {
        TgtDoc.close(SaveOptions.DONOTSAVECHANGES);//关闭文档
    }
    
}//处理文件


//配置文件不存在时，先创建默认
var ScriptFolder = new Folder(Folder.myDocuments + "/AdobeKu");
if (!ScriptFolder.exists) {ScriptFolder.create();}//创建文件夹
var configFilePath = ScriptFolder + "/ZipSys.xml";//默认配置文件完整路径
var configFile = new File(configFilePath);
if (configFile.exists == false) {createXml(configFilePath);}

// 读取配置文件内容并解析为 XML 对象
var xmlContentStr = readwriteXml("r", configFilePath);
    ZipXml = new XML(xmlContentStr);

var RtnDATA = null;
{//定义窗口
    var ZipWin = new Window("dialog", "压缩图片 \u00A9 Kucha");
        ZipWin.alignChildren = "left";

    var TipTXT = ZipWin.add("statictext", undefined, "PSD/PSB、TIFF、JPEG、PNG、BMP、TGA、WebP");
        TipTXT.enabled = false; //关闭编辑

    // -- 数值 --
    var GrpVar = ZipWin.add("group");
        GrpVar.alignChildren = "left";

        GrpVar.add("statictext", undefined, "百分比:");
    var vPCT = GrpVar.add("edittext", undefined, ZipXml.pct);
        vPCT.characters = 4;
        vPCT.helpTip = "按百分比等比缩小";

        GrpVar.add("statictext", undefined, "DPI:");
    var vDPI = GrpVar.add("edittext", undefined, ZipXml.dpi);
        vDPI.characters = 4;
        vDPI.helpTip = "转目标DPI\n→目标格式无DPI时,PS默认是72";

        GrpVar.add("statictext", undefined, "像素:");
    var vPIX = GrpVar.add("edittext", undefined, ZipXml.pix);
        vPIX.characters = 5;
        vPIX.helpTip = "短边/长边的目标像素";

        // 根据defaults.mde自动选中对应单选按钮
        vPCT.enabled = vPCT.active = ZipXml.mde == "0";
        vDPI.enabled = vDPI.active = ZipXml.mde == "1";
        vPIX.enabled = vPIX.active = ZipXml.mde == "2" || ZipXml.mde == "3";

    // -- 复选框 --
    var GrpNothing = ZipWin.add("group");
        GrpNothing.alignChildren = "left";
    var opFold = GrpNothing.add("checkbox", undefined, "导出后打开文件夹");
        opFold.value = ZipXml.opf == "1"; // 默认勾选
    var MgLays = GrpNothing.add("checkbox", undefined, "合并可见层");
        MgLays.helpTip = "针对原格式保存PSD/PSB/TIFF";
        MgLays.value = ZipXml.mgl == "1"; // 默认勾选

    var ReSetDf = GrpNothing.add("button", undefined, "重置");
        ReSetDf.onClick = function () {
            vPCT.text = "100";      //ZipXml.pct
            vDPI.text = "30";       //ZipXml.dpi
            vPIX.text = "1024";     //ZipXml.pix
            opFold.value = true;    //ZipXml.opf
            MgLays.value = true;   //ZipXml.mgl

            col0.value = true;//第1个       //ZipXml.col
            vPCT.enabled = vPCT.active = true;
            vDPI.enabled = vDPI.active = false;
            vPIX.enabled = vPIX.active = false;

            mPCT.value = true; //第1个      //ZipXml.mde
            fORI.value = true; //第1个      //ZipXml.fmt
            pCOM.value = true; //第2个      //ZipXml.path
            PathSTR.text = "C:\\tmp\\ZipIMG\\"; //ZipXm1.pstr

            save2Xml();// 保存到配置文件
        };//重置参数
    // -- 模式 --
    var GrpMde = ZipWin.add("group");
        GrpMde.alignChildren = "left";
        GrpMde.add("statictext", undefined, "模式:");
    var mPCT = GrpMde.add("radiobutton", undefined, "百分比");
        mPCT.helpTip = "DPI不变\n→尺寸按数值缩放";
        mPCT.onClick = function () {
            vPCT.enabled = vDPI.enabled = vPIX.enabled = false;
            if (this.value) { // 只有选中时才弹出提示
                vPCT.enabled = true
            }
        };
    var mDPI = GrpMde.add("radiobutton", undefined, "DPI");
        mDPI.helpTip = "尺寸不变\n→DPI按数值缩放";
        mDPI.onClick = function () {
            vPCT.enabled = vDPI.enabled = vPIX.enabled = false;
            if (this.value) { // 只有选中时才弹出提示
                vDPI.enabled = true
            }
        };
    var mMin = GrpMde.add("radiobutton", undefined, "短边");
        mMin.helpTip = "DPI不变\n→短边像素缩小到数值\n";
    var mMax = GrpMde.add("radiobutton", undefined, "长边");
        mMax.helpTip = "DPI不变\n→长边像素缩小到数值\n";
        mMin.onClick = mMax.onClick = function () {
            vPCT.enabled = vDPI.enabled = vPIX.enabled = false;
            if (this.value) { // 只有选中时才弹出提示
                vPIX.enabled = true
            }
        };

        // 根据defaults.mde自动选中对应单选按钮
        mPCT.value = ZipXml.mde == "0";
        mDPI.value = ZipXml.mde == "1";
        mMin.value = ZipXml.mde == "2";
        mMax.value = ZipXml.mde == "3";

    // -- 导出 --
    var Grpfmt = ZipWin.add("group");
        Grpfmt.alignChildren = "left";
        Grpfmt.add("statictext", undefined, "导出:");
    var fORI = Grpfmt.add("radiobutton", undefined, "原格式");
        fORI.helpTip = "搭配转CMYK时\n→PNG+BMP+TGA+WebP存PSB"
        fORI.value = true;

    var fJPG = Grpfmt.add("radiobutton", undefined, "JPG");
        fJPG.helpTip = "全部导出jpg格式";
    var fPNG = Grpfmt.add("radiobutton", undefined, "PNG");
        fPNG.helpTip = "全部导出png格式\n→CMYK不支持，将自动转RGB"; 
    var fWeb = Grpfmt.add("radiobutton", undefined, "WebP");
        fWeb.helpTip = "全部导出WebP格式\n→CMYK不支持，将自动转RGB"; 
        fWeb.onClick = function () {
            function IsNativeWebPSupported() {
                var parts = app.version.split(".");
                var major = parseInt(parts[0], 10);
                var minor = parseInt(parts[1], 10);

                return major > 23 ||
                    (major === 23 && minor >= 2);
            }
            if (this.value && !IsNativeWebPSupported()) {
                alert("原生 WebP 保存需要 Photoshop 23.2 或更高版本。", "ZipIMG", true);
                this.value = false;
            } 
        };
        // 根据defaults.mde自动选中对应单选按钮
        fORI.value = ZipXml.fmt == "0";
        fJPG.value = ZipXml.fmt == "1";
        fPNG.value = ZipXml.fmt == "2";
        fWeb.value = ZipXml.fmt == "3";

    // -- 颜色 --
    var GrpCol = ZipWin.add("group");
        GrpCol.alignChildren = "left";
        GrpCol.add("statictext", undefined, "颜色:");
    var col0 = GrpCol.add("radiobutton", undefined, "不改变");
        col0.helpTip = "不改变";

    var col1 = GrpCol.add("radiobutton", undefined, "RGB");
        col1.helpTip = "仅转RGB";

    var col2 = GrpCol.add("radiobutton", undefined, "sRGB");
        col2.helpTip = "转RGB后\n→颜色配置改为：IEC61966-2.1";
    var col3 = GrpCol.add("radiobutton", undefined, "CMYK");
        col3.helpTip = "仅转CMYK\n→PNG、WebP、BMP、TGA不支持，将转存psb";

        // 根据defaults.mde自动选中对应单选按钮
        col0.value = ZipXml.col == "0";
        col1.value = ZipXml.col == "1";
        col2.value = ZipXml.col == "2";
        col3.value = ZipXml.col == "3";


    // -- 保存 --
    var GrpSave = ZipWin.add("group");
        GrpSave.alignChildren = "left";
        GrpSave.add("statictext", undefined, "保存:");
    var pORI = GrpSave.add("radiobutton", undefined, "原路径");
        pORI.helpTip = "搭配导出'原格式'可能会覆盖源文件，慎用";
        pORI.onClick = function () {
            if (this.value && fORI.value === true) { // 只有选中时才弹出提示
                alert("搭配导出'原格式'将会覆盖源文件", "ZipIMG", true);
            }
        };
    var pCOM = GrpSave.add("radiobutton", undefined, "父级");
        pCOM.helpTip = "父级路径下的'ZipIMG'";
    var pDSK = GrpSave.add("radiobutton", undefined, "桌面");
        pDSK.helpTip = "桌面的'ZipIMG'";
    var pCST = GrpSave.add("radiobutton", undefined, "自定义");
        pCST.helpTip = "默认在C:\\tmp\\ZipIMG";

        // 根据defaults.mde自动选中对应单选按钮
        pORI.value = ZipXml.path == "0";
        pCOM.value = ZipXml.path == "1";
        pDSK.value = ZipXml.path == "2";
        pCST.value = ZipXml.path == "3";

    // -- 自定义路径 --
    var GrpPath = ZipWin.add("group");
        GrpPath.alignChildren = "left";
    var SltPath = GrpPath.add("button", undefined, "修改路径");
        SltPath.helpTip = "点击修改'自定义'路径";
        SltPath.onClick = function() {
            // 弹出文件夹选择窗口
            var selFolder = Folder.selectDialog("选择存放文件夹", Folder(PathSTR.text));
            if (selFolder !== null) {
                PathSTR.text = selFolder.fsName + "\\" ;
            }
        };
    var PathSTR = GrpPath.add("edittext", undefined, ZipXml.pstr);
        PathSTR.characters = 20;
        PathSTR.enabled = false; //关闭编辑
    // -- 执行按钮 --
    var btnGroup = ZipWin.add("group");
        btnGroup.alignment = "center";
    var cancelBtn = btnGroup.add("button", undefined, "取消");
    var okBtn = btnGroup.add("button", undefined, "确定");
}
{//按钮功能
    function TestVar(textStr) {
        var txt = String(textStr).replace(/^\s+|\s+$/g, "");
        var num = Number(txt);
        if (txt === "" || !isFinite(num)) {
            alert("请输入正确的数字！", "ZipIMG", true);
            return false;
        }
        if (num <= 0) {
            alert("数值必须大于0！", "ZipIMG", true);
            return false;
        }
        return num;
    }//校验输入文本，返回合法数字/false
    function doSubmit() {
        // 根据选中模式获取对应输入框文本
        var inputText;
        if (mPCT.value) inputText = vPCT.text;
        else if (mDPI.value) inputText = vDPI.text;
        else inputText = vPIX.text;

        var TgtVar = TestVar(inputText);
        if (TgtVar === false) return; // 校验失败不关闭窗口

        save2Xml();//保存变量
        // 给外层result赋值，不新建局部变量
        RtnDATA = {
            val: TgtVar,
            opf: opFold.value,
            mgl: MgLays.value,

            col: col0.value ? "0" : (col1.value ? "1" : (col2.value ? "2" : "3")),
            mde: mPCT.value ? "0" : (mDPI.value ? "1" : (mMin.value ? "2" : "3")),
            fmt: fORI.value ? "0" : (fJPG.value ? "1" : (fPNG.value ? "2" : "3")),
            path: pORI.value ? "0" : (pCOM.value ? "1" : (pDSK.value ? "2" : "3")),
            pstr: PathSTR.text
        };
        ZipWin.close();
    }//确定按钮统一提交逻辑

    okBtn.onClick = doSubmit;
    vPCT.onEnterKey = doSubmit;
    vDPI.onEnterKey = doSubmit;
    vPIX.onEnterKey = doSubmit;
    cancelBtn.onClick = function () {
        RtnDATA = null;
        ZipWin.close();
    };// 取消按钮清空结果
}
ZipWin.show();

if(RtnDATA !== null){
    var AllDoc = File.openDialog("请选择图片文件", '*.PSD;*.PSB;*.TIF;*.TIFF;*.JPG;*.JPEG;*.PNG;*.BMP;*.TGA;*.WEBP', true);//'*.PSD;*.PNG'
    if (AllDoc !== null) {//选择了文件
        var NamLst = {}; //  已用目标文件名 -> true
        for (var i = 0; i < AllDoc.length; i++) {
            var TgtDoc = app.open(AllDoc[i]);//打开文件
            var DocPath = TgtDoc.path; // 文件夹路径
            if (RtnDATA.path == "0") {
                var SavePath = new Folder(DocPath.fsName + "\\");
            }
            else if (RtnDATA.path == "1") {
                if (DocPath.parent == null) { var TmpVar = DocPath.fsName } else { var TmpVar = DocPath.parent.fsName }//根目录
                var SavePath = new Folder(TmpVar + "\\" + "ZipIMG\\");
            }//父级
            else if (RtnDATA.path == "2") {
                var SavePath = new Folder(Folder.desktop.fsName + "\\ZipIMG\\");
            }//桌面
            else if (RtnDATA.path == "3") {
                var SavePath = new Folder(RtnDATA.pstr);
            }
            if (!SavePath.exists) SavePath.create();//不存在则新建
            if (!Folder(SavePath).exists) { Folder(SavePath).create() }//如果文件夹不存在则新建
            ExpNewFile(NamLst, SavePath, TgtDoc, RtnDATA);
        }
        if (RtnDATA.opf == "1") {
            Folder(SavePath).execute();//打开文件夹 
        }else {
            alert("所选文件已处理完成！", "ZipIMG", false);
        }
    }
}
