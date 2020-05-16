var body = $response.body; // 声明一个变量body并以响应消息体赋值
let url = $request.url;
const yurl = '/Api/User/SetTool';
const yurl2 = '/Api/User/GetTools';
const yurl3 = '/Api/user/GetMyInfo';


if (url.indexOf(yurl) != -1) {


//body=body.replace(/code\":\d+/g,'code":0');
var obj = JSON.parse(body); //JSON。paese（）将json形式的body转变成对象处理

obj.code=0;

body= JSON.stringify(obj);    //重新打包回json字符串


}else if(url.indexOf(yurl2) != -1){


body=body.replace(/vipLevel\":\d/g,'vipLevel":1');

}else if(url.indexOf(yurl3) != -1){


body=body.replace(/is_vip\":\d/g,'is_vip":1');

}

$done(body);  //结束修改