/*
软件地址 INS、TUI特、油管，FB，海外常用网站，亲测有效 https://www.bee233.com/user/53YAP5
[rewrite_local]
#蜜蜂加速器
https:\/\/www\.09898434\.xyz\/myapi\/apinodelist url script-response-body js/mfjsq.js
[mitm]
hostname = www.09898434.xyz
 */



//const path = "/api/public/";

//const url = $request.url;
var body = $response.body.replace(/enable\":0/g,'enable":1');
       // $notify("经纬度", "", body.replace(/enable\":0/g,'enable":1'));
/*
.replace(/'enable\": 0'/g,'enable\": 
var obj = JSON.parse(body);
obj.data.vip_time = 1612586869;

body = JSON.stringify(obj);

*/
$done({body});

