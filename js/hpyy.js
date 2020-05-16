//^https:\/\/api3\.henpi\.vip\/app\/user\/get_userinfo url script-response-body  demo/js/hpyy.js

var body = $response.body; // 声明一个变量body并以响应消息体赋值
var obj = JSON.parse(body); // JSON.parse()将json形式的body转变成对象处理

obj.data.userinfo.vip_endtime=1741615722;
obj.data.userinfo.vip_type=1;
obj.data.userinfo.is_music_pay_member="6666no";
body = JSON.stringify(obj); // 重新打包回json字符串
$done(body); // 结束修改