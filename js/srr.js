var body = $response.body; // 声明一个变量body并以响应消息体赋值


//方式二
//body=body.replace(/port\":4500/g,'port":12333'); 
//body=body.replace(/location\":\"tw/g,'location":"China');

var obj = JSON.parse(body); // JSON.parse()将json形式的body转变成对象处理
//方式一
//obj.data.gateways[1].ip="111111";

//方式三
obj.data.gateways.forEach(function (item, idnex, array) {

item.port=5050;
item.ip="145678888";
    console.log(item);     // 1 2 3 4 5 6
    console.log(array);    // [1, 2, 3, 4, 5, 6]
})

obj.data.gateways.map(function (item, idnex) {


    return item.location="China";
})


body = JSON.stringify(obj); // 重新打包回json字符串
$done(body); // 结束修改