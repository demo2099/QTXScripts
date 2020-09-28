/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
body={
  "status": "success",
  "code": 1,
  "msg": "ok",
  "data": {
    "price": 1.5,
    "vipprice": 0,
    "balance": 10,
    "bookvoucher": 10,
    "enough": 10,
    "priceWord": 0.07
  }
};
body = JSON.stringify(body);
$done({
    body
});
