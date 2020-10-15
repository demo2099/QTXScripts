/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
body={
  "ret": "0",
  "data": {
    "image": "",
    "amount": 372,
    "alert": false,
    "sysId": 0,
    "nickName": "账户",
    "chargeTotal": 0,
    "stars": 0,
    "userName": "",
    "vip": 365,
    "userId": 77230,
    "login_sum": 0
  }
};
body = JSON.stringify(body);
$done({
    body
});
