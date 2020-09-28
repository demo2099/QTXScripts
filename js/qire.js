/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
body=body.replace(/type\":\"\d/g,'type":"4').replace(/vip_expire\":\"\d+/g,'vip_expire":"5201314007').replace(/vip\":\d/g,'type":1').replace(/nickname\":\"\w+/g,'nickname":"呆猫demo');
var obj = JSON.parse(body); 
obj.data.="https://s1.ax1x.com/2020/09/20/w7lOEQ.gif";

body = JSON.stringify(body);
$done({
    body
});
