/*
软件地址 支持电脑，电视，手机，三端同步。全网最牛的影视软件欢迎下载体验：：http://web.ymsj168.com/app/index/invitation?code=369786
[rewrite_local]
#影迷联萌
http:\/\/web\.ymsj168\.com\/\/app\/api\/MembershipInformation\.html url script-response-body js/ymlm.js
[mitm]
hostname = web.ymsj168.com

  "id": 386641,
  "username": "liavailable",
  "countryCode": "CN",
  "customerId": null,
  "firstName": "mt",
  "lastName": "li",
  "email": "hao1454507493@gmail.com",
 */



//^https:\/\/api-v5\.cercube\.com\/account

//api-v5.cercube.com
var body = $response.body;
var   user = {};

 


var obj = JSON.parse(body);
obj.status="E_OKAY";
obj.code=0;

obj.user={



  "blocked": false,
  "roleId": 1,
  "didMigrate": true,
  "createdAt": "2020-02-22T05:28:53.541Z",
  "updatedAt": "2020-03-01T22:08:26.046Z"
 

 }

body = JSON.stringify(obj);


$done({body});

