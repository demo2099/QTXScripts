var body = $response.body; // 声明一个变量body并以响应消息体赋值
var obj = JSON.parse(body); // JSON.parse()将json形式的body转变成对象处理

var user = {};
obj.status = "E_OKAY";
obj.code = 0;
obj.user = {
    "blocked": false,
    "roleId": 1,
    "didMigrate": true,
    "createdAt": "2020-02-22T05:28:53.541Z",
    "updatedAt": "2020-03-01T22:08:26.046Z"
};

body = JSON.stringify(obj); // 重新打包回json字符串
$done(body); // 结束修改