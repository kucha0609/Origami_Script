function DoFunc(func, args, cb) {
    cb = cb || function(){}; // 无cb则赋值空函数，调用不会报错
    var target = BridgeTalk.getSpecifier("illustrator");
    var bt = new BridgeTalk();
    bt.target = target;
    if (typeof func === "function") {
        var funcCode = func.toString();
        var argList = [];
        if (args instanceof Array) {
            for (var i = 0; i < args.length; i++) {
                var v = args[i];
                if (typeof v === "string") {
                    argList.push('"' + v.replace(/"/g, '\\"') + '"');
                } else {
                    argList.push(v);
                }
            }
        }
        bt.body = "(" + funcCode + ")(" + argList.join(",") + ");";
    } else {//二进制代码
        bt.body = func;
    }
    
    bt.onResult = function(resObj) {
        var result = eval(resObj.body);
        cb(result, null);
    };// 正常收到结果
    /*
    bt.onTimeout = function() {
        cb(null, "调用Bridge超时");
    };// 超时

    bt.onError = function(resObj) {
        var errMsg = resObj.body + " | 错误码:" + resObj.headers["Error-Code"];
        cb(null, errMsg);
    };// 脚本异常
    */
    bt.send(10);
}

function bridgeCode() {
    alert("Hello from Bridge!");
    return 155;
}

DoFunc(bridgeCode, [],function(val, err) {if(!err) {alert(val)}});
DoFunc(bridgeCode, []);
