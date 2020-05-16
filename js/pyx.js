var body = $response.body; // 声明一个变量body并以响应消息体赋

//body=body.replace(/vipLevel\":\d/g,'vipLevel":1').replace(/is_vip\":\d/g,'is_vip":1').replace(/code\":\d+/g,'code":0');
body=body.replace(/is_vip\":\d/g,'is_vip":1').replace(/vipLevel\":\d/g,'vipLevel":1').replace(/msg\":\"请先开通会员~/g,'msg":"0').replace(/code\":\d+/g,'code":0');
$done(body);  //结束修改



