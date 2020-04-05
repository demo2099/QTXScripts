var body = $response.body; // 声明一个变量body并以响应消息体赋值

body=body.replace(/status\":1/g,'status":0'); 
body=body.replace(/click\":\"https:\/\/url.cn\/54QiZcS/g,'click":"0'); 

var obj = JSON.parse(body); // JSON.parse()将json形式的body转变成对象处理
obj.adUpdateTime=3227009407;
obj.ads[1].adId=1000000;


obj.ads.forEach(function (item, idnex, array) {
    
    item.adType=0;
    console.log(item)     // 1 2 3 4 5 6
    console.log(array)    // [1, 2, 3, 4, 5, 6]
})


obj.ads.map(function (item, idnex) {


    return item.wh="800";
})
body = JSON.stringify(obj); // 重新打包回json字符串
$done(body); // 结束修改