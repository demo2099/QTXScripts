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

  }
};
body = JSON.stringify(body);
$done({
    body
});
