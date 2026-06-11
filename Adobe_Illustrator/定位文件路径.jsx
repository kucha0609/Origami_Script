// a 没选择链接图定位AI图档路径， 
// b 选中了链接图的情况下，定位所选链接路径。

app.preferences.setBooleanPreference("ShowExternalJSXWarning", false)


      var FileArr = [];     // 用于存最终路径数组
      var FileHash = {};    // 哈希表，用于路径去重
      var LostCnt = 0;      // 丢失路径的链接数量
      var CurSlt = app.activeDocument.selection;

      if (CurSlt.length == 0) {
         if (app.documents.length == 0) {
            alert("请先打开任一文档!", "错误", true);
         } else {
            if (!new File(app.activeDocument.fullName).exists) {
               alert("文件未保存!", "错误", true);
            } else {
               var SavePath = decodeURI(app.activeDocument.path); // 文件夹路径字符串
               Folder(SavePath).execute();                        // 打开路径
            }
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
            for (var i = 0; i < FileArr.length; i++) { FileArr[i].execute(); }// 打开所有收集到的文件夹
         } else if (LostCnt > 0) {
            alert("所选链接不存在路径", "错误", true);
         }else{
               if (app.documents.length == 0) {
                  alert("请先打开任一文档!", "错误", true);
               } else {
                  if (!new File(app.activeDocument.fullName).exists) {
                     alert("文件未保存!", "错误", true);
                  } else {
                     var SavePath = decodeURI(app.activeDocument.path); // 文件夹路径字符串
                     Folder(SavePath).execute();                        // 打开路径
                  }
               }
         }
      }