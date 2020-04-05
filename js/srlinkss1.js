var body = $response.body; // 声明一个变量body并以响应消息体赋值
//body=body.replace(/port\":4500/g,'port":1234'); 

var obj = JSON.parse(body); // JSON.parse()将json形式的body转变成对象处理

obj.data.vipEndTime="2029-04-05 19:28:43";
obj.data.userType="novip";

obj.data.gateways[0].ip="11111";
obj.data.gateways[0].location="China";

obj.data.gateways.map(function(item,index){
item.ip="55555";
return item.location="China";
});



body = JSON.stringify(obj); // 重新打包回json字符串
$done(body); // 结束修改