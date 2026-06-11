//分解所选的组或空选分解所有组

function UnGroup_All() {
    function UnGroupItem(GrpItem) {
        if (GrpItem.clipped) return;//剪切组跳过
        if (GrpItem.hidden)  return;//隐藏就跳过
        for (var i = GrpItem.groupItems.length - 1; i >= 0; i--) {
            UnGroupItem(GrpItem.groupItems[i]);
        }//先递归处理子组

        var items = [];
        for (var j = GrpItem.pageItems.length - 1; j >= 0; j--) {
            items.push(GrpItem.pageItems[j]);
        }//保存当前组中的所有元素
        for (var k = items.length - 1; k >= 0; k--) {
            try {
                items[k].move(GrpItem, ElementPlacement.PLACEBEFORE);//移到父级前面
                if (GrpItem.clipped) {
                    if ((items[k].typename === 'PathItem' && !items[k].filled && !items[k].stroked) ||//不存在填充和描边的路径
                        (items[k].typename === 'CompoundPathItem' && !items[k].pathItems[0].filled && !items[k].pathItems[0].stroked) || //不存在填充和描边的复合路径
                        (items[k].typename === 'TextFrame' && items[k].textRange.characterAttributes.fillColor == '[NoColor]' && items[k].textRange.characterAttributes.strokeColor == '[NoColor]') 
                    ){
                        clearArr.push(items[k]);
                    }//收集剪切蒙版的数组(Push empty paths in array)
                }//收集空对象后面删除
            } catch (e) {}
        }//把子元素移出组
        try {GrpItem.remove();} catch (e) {}//删除空组
    }//递归解组组对象
    function UnGroupLayer(layers) {
            for (var i = layers.length - 1; i >= 0; i--) {
                try {
                    var layer = layers[i];
                    //保存状态
                    var l = layer.locked;
                        layer.locked = false;

                    if(!layer.visible) return; //层不可见就跳过

                    if (layer.layers.length > 0) {
                        UnGroupLayer(layer.layers);
                    }//先处理子图层
                    for (var j = layer.groupItems.length - 1; j >= 0; j--) {
                        UnGroupItem(layer.groupItems[j]);
                    }//再处理当前图层中的组
                    //恢复状态
                    layer.locked = l;
                } catch (e) {}
            }
    }//递归处理图层
    var clearArr = [];
    UnGroupLayer(app.activeDocument.layers);

    for (var i = 0; i < clearArr.length; i++) {
        clearArr[i].remove();
    }
};//分解所有组//忽略剪切蒙版

UnGroup_All()