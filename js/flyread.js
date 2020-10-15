var body = $response.body; // 声明一个变量body并以响应消息体赋

//body=body.replace(/vipLevel\":\d/g,'vipLevel":1').replace(/is_vip\":\d/g,'is_vip":1').replace(/code\":\d+/g,'code":0');
body=body.replace(/vipEndTime\":\d+/g,'vipEndTime":4092579678000').replace(/isVip\":\w+/g,'isVip":true').replace(/privilegeStatus\":\d/g,'privilegeStatus":2');
$done(body);  //结束修改



