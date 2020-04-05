var body = $response.body; // 声明一个变量body并以响应消息体赋值
//body=body.replace(/port\":4500/g,'port":1234'); 

var obj = JSON.parse(body); // JSON.parse()将json形式的body转变成对象处理

obj.adUpdateTime=1869999800

body = JSON.stringify(obj); // 重新打包回json字符串
$done(body); // 结束修改